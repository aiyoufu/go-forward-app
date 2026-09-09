import { image } from '@kit.ImageKit'
import { AIChannelConfig, UserSettings } from 'common'
import { AIService, ParseResult } from './AIService'
import { LocalBillExtractService } from './LocalBillExtractService'
import { OcrService } from './OcrService'
import { SettingsService } from '../SettingsService'
import { UserService } from '../UserService'
import { CreditAccountService } from '../CreditAccountService'
import { AnalyticsService } from '../AnalyticsService'

/** 文字解析门槛检查结果 */
export class AIReadyCheck {
  ok: boolean = false
  message: string = ''
}

/**
 * 图片解析流水线结果
 * - vision：已得到解析结果（大模型统一解析 / 错误提示）
 * - error：无法继续
 */
export class AIImageParseOutcome {
  kind: string = 'error'
  visionResult: ParseResult | null = null
  message: string = ''
  /**
   * 实际路径，供 UI 提示：
   * vision_cloud | error
   */
  path: string = ''
}

/**
 * AI 解析编排（无 UI）— 统一内容处理架构：
 * 文字与图片共用同一条提示词、同一套大模型处理逻辑（AIService.callUnified），
 * 不做本地 OCR 预处理、不注入端侧信号块；图片直发多模态模型，准确性优先。
 * 本地规则解析（LocalBillExtractService.tryExtract）仅作为文字输入在
 * 无 API Key 或模型失败时的最后兜底。
 */
export class AIParseOrchestrator {
  static readonly MSG_TEXT_KEY_REQUIRED: string =
    '请先在设置中配置「文字解析」API Key'
  static readonly MSG_TEXT_PARSE_REQUIRED: string =
    '请先在设置中配置「文字解析」（键盘与系统听写均需使用）'
  static readonly MSG_IMAGE_KEY_REQUIRED: string =
    '请先在设置中配置「图片」或「文字解析」API Key 后再识图'
  static readonly MSG_IMAGE_ENCODE_FAIL: string = '图片无法打开，请更换后重试'
  static readonly MSG_IMAGE_PARSE_FAIL: string = '图片识别失败，请重试'
  static readonly MSG_EMPTY_IMAGE: string = '未识别到可用的负债、订阅或账户信息'
  /** 视觉模型读超时 / 网关超时 */
  static readonly MSG_VISION_TIMEOUT: string =
    '识别超时：模型长时间未返回，请检查网络或在 AI 设置中换一个响应更快的模型后重试'
  /** 鉴权失败（401/403） */
  static readonly MSG_VISION_AUTH: string =
    '连接失败(401)：API Key 无效或无权限。请到 AI 设置检查 Key，格式选 OpenAI，Base URL 用 …/api/coding/v3'
  /** 选了 Anthropic 但本端未实现该协议 */
  static readonly MSG_FORMAT_ANTHROPIC: string =
    '当前仅支持 OpenAI 兼容协议。请把 API 格式改为 OpenAI（火山请用 …/api/coding/v3），不要选 Anthropic'

  /** 文字解析能否调用（有文字 Key 或可复用的图片 Key） */
  static canParseText(settings: UserSettings): boolean {
    return settings.ai_text_key.trim().length > 0 ||
      settings.ai_vision_key.trim().length > 0
  }

  static async checkTextParseReady(userId?: string): Promise<AIReadyCheck> {
    const uid = userId !== undefined && userId.length > 0 ? userId : UserService.getCurrentUserId()
    const settings = await SettingsService.getSettings(uid)
    const r = new AIReadyCheck()
    if (AIParseOrchestrator.canParseText(settings)) {
      r.ok = true
      return r
    }
    r.ok = false
    r.message = AIParseOrchestrator.MSG_TEXT_KEY_REQUIRED
    return r
  }

  static async loadTextConfig(): Promise<AIChannelConfig> {
    return AIService.loadTextChannelConfig()
  }

  static async loadVisionConfig(): Promise<AIChannelConfig> {
    return AIService.loadVisionChannelConfig()
  }

  /**
   * 文字解析（统一入口）：大模型统一提示词解析；
   * 无 Key 或模型失败/为空时本地规则兜底；仍无结果且无 Key 时引导配置。
   */
  static async parseText(userText: string): Promise<ParseResult> {
    const config = await AIParseOrchestrator.resolveTextParseConfig()
    let remote: ParseResult | null = null
    if (config !== null) {
      try {
        remote = await AIService.parseDebtText(userText, config)
      } catch (_e) {
        remote = null
      }
    }
    const local = LocalBillExtractService.tryExtract(userText)
    if (remote !== null && remote.items.length > 0) {
      AnalyticsService.trackAiParseResult(true, 'text', remote.items.length)
      return remote
    }
    if (local !== null && local.items.length > 0) {
      // 无 Key 或模型失败/为空：本地规则兜底（最后防线）
      AnalyticsService.trackAiParseResult(true, 'text', local.items.length)
      return local
    }
    if (remote !== null) {
      // 保留模型的澄清问题或错误码（HTTP_/PARSING_/超时等）
      AnalyticsService.trackAiParseResult(false, 'text', 0, 'empty')
      return remote
    }
    const r = new ParseResult()
    r.rawContent = 'TEXT_DISABLED'
    r.clarifyQuestion = AIParseOrchestrator.MSG_TEXT_PARSE_REQUIRED
    AnalyticsService.trackAiParseResult(false, 'text', 0, 'no_key')
    return r
  }

  /**
   * 文字解析配置：优先文字渠道；未配 Key 时复用图片渠道。
   */
  static async resolveTextParseConfig(): Promise<AIChannelConfig | null> {
    const text = await AIService.loadTextChannelConfig()
    if (text.key.trim().length > 0) {
      if (!text.enabled) {
        text.enabled = true
      }
      return text
    }
    const vision = await AIService.loadVisionChannelConfig()
    if (vision.key.trim().length > 0) {
      if (!vision.enabled) {
        vision.enabled = true
      }
      return vision
    }
    return null
  }

  /**
   * 对已选 PixelMap（统一图片解析）：
   * 1) 压缩编码为 JPEG base64
   * 2) 直发多模态大模型（与文字共用同一提示词），不做本地 OCR 预处理
   * 3) 未配置 Key → 引导配置；失败 → 映射可读文案
   */
  static async parsePixelMap(
    pixelMap: image.PixelMap,
    fileName: string = ''
  ): Promise<AIImageParseOutcome> {
    const out = await AIParseOrchestrator.parsePixelMapCore(pixelMap)
    if (fileName.length > 0) {
      await AIParseOrchestrator.applyFileNameFallback(out, fileName)
    }
    return out
  }

  private static async parsePixelMapCore(pixelMap: image.PixelMap): Promise<AIImageParseOutcome> {
    const out = new AIImageParseOutcome()
    try {
      const config = await AIParseOrchestrator.resolveImageParseConfig()
      if (config === null) {
        out.kind = 'error'
        out.message = AIParseOrchestrator.MSG_IMAGE_KEY_REQUIRED
        out.path = 'error'
        AnalyticsService.trackAiParseResult(false, 'vision', 0, 'no_key')
        return out
      }
      const b64 = await OcrService.pixelMapToJpegBase64(pixelMap)
      if (b64.length === 0) {
        out.kind = 'error'
        out.message = AIParseOrchestrator.MSG_IMAGE_ENCODE_FAIL
        out.path = 'error'
        AnalyticsService.trackAiParseResult(false, 'vision', 0, 'encode_fail')
        return out
      }
      const result = await AIService.parseDebtFromImage(b64, config)
      if (result.items.length === 0 && result.rawContent.length > 0) {
        const failMsg = AIParseOrchestrator.messageForVisionFailure(result.rawContent)
        if (failMsg.length > 0) {
          out.kind = 'error'
          out.message = failMsg
          out.path = 'error'
          AnalyticsService.trackAiParseResult(false, 'vision', 0, 'vision_fail')
          return out
        }
      }
      out.kind = 'vision'
      out.visionResult = result
      out.path = 'vision_cloud'
      AnalyticsService.trackAiParseResult(result.items.length > 0, 'vision',
        result.items.length, result.items.length > 0 ? '' : 'empty')
      return out
    } catch (_e) {
      out.kind = 'error'
      out.message = AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL
      out.path = 'error'
      AnalyticsService.trackAiParseResult(false, 'vision', 0, 'exception')
      return out
    }
  }

  /**
   * 图片解析配置：优先图片渠道；未配 Key 时复用文字渠道。
   */
  static async resolveImageParseConfig(): Promise<AIChannelConfig | null> {
    const vision = await AIService.loadVisionChannelConfig()
    if (vision.key.trim().length > 0) {
      if (!vision.enabled) {
        vision.enabled = true
      }
      return vision
    }
    const text = await AIService.loadTextChannelConfig()
    if (text.key.trim().length > 0) {
      if (!text.enabled) {
        text.enabled = true
      }
      return text
    }
    return null
  }

  /**
   * 文件名兜底：识别结果中 platform 仍为 '未知平台' 时，
   * 用文件名与信用账户名做子串/首段 token 匹配，命中则覆盖。
   * 任何异常静默吞掉，绝不阻塞主流程。
   */
  static async applyFileNameFallback(
    out: AIImageParseOutcome,
    fileName: string
  ): Promise<void> {
    try {
      if (out.kind !== 'vision' || out.visionResult === null) {
        return
      }
      let needMatch = false
      for (let i = 0; i < out.visionResult.items.length; i++) {
        const item = out.visionResult.items[i]
        const p = item.parsedFields.get('platform')
        if (typeof p === 'string' && p === '未知平台') {
          needMatch = true
          break
        }
      }
      if (!needMatch) {
        return
      }
      const accounts = await CreditAccountService.getCreditAccounts()
      const matched = CreditAccountService.matchAccountByFileName(fileName, accounts)
      if (matched.length === 0) {
        return
      }
      for (let i = 0; i < out.visionResult.items.length; i++) {
        const item = out.visionResult.items[i]
        const p = item.parsedFields.get('platform')
        if (typeof p === 'string' && p === '未知平台') {
          item.parsedFields.set('platform', matched)
        }
      }
    } catch (_e) {
      // best-effort: 文件名兜底失败不影响主识别结果
    }
  }

  /** rawContent 是否表示请求超时（视觉或文字渠道） */
  static isVisionTimeout(rawContent: string): boolean {
    if (rawContent.length === 0) {
      return false
    }
    if (rawContent.indexOf('VISION_TIMEOUT') === 0) {
      return true
    }
    const lower = rawContent.toLowerCase()
    if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0 ||
      rawContent.indexOf('超时') >= 0) {
      if (rawContent.indexOf('VISION_') === 0 ||
        rawContent.indexOf('HTTP_') === 0) {
        return true
      }
    }
    // 网关 504 / 408
    if (rawContent.indexOf('VISION_HTTP_504') === 0 ||
      rawContent.indexOf('VISION_HTTP_408') === 0 ||
      rawContent.indexOf('HTTP_ERROR_504') === 0 ||
      rawContent.indexOf('HTTP_ERROR_408') === 0) {
      return true
    }
    return false
  }

  /**
   * 将视觉失败 rawContent 映射为用户可读文案；无法识别则返回空串。
   * 鉴权失败不得伪装成「识别超时」。
   */
  static messageForVisionFailure(rawContent: string): string {
    if (rawContent.length === 0) {
      return ''
    }
    if (rawContent === 'FORMAT_UNSUPPORTED_ANTHROPIC' ||
      rawContent.indexOf('FORMAT_UNSUPPORTED_ANTHROPIC') === 0) {
      return AIParseOrchestrator.MSG_FORMAT_ANTHROPIC
    }
    if (rawContent.indexOf('VISION_HTTP_401') === 0 ||
      rawContent.indexOf('VISION_HTTP_403') === 0) {
      return AIParseOrchestrator.MSG_VISION_AUTH
    }
    if (AIParseOrchestrator.isVisionTimeout(rawContent)) {
      return AIParseOrchestrator.MSG_VISION_TIMEOUT
    }
    if (rawContent.indexOf('VISION_') === 0) {
      return AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL
    }
    return ''
  }
}
