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
 * - ocr_then_text：本地 OCR 有效，需再走文字模型
 * - vision：已得到解析结果（本地规则 / 文字 LLM / 视觉）
 * - error：无法继续
 */
export class AIImageParseOutcome {
  kind: string = 'error'
  ocrText: string = ''
  visionResult: ParseResult | null = null
  message: string = ''
  /**
   * 实际路径，供 UI 提示：
   * system_ocr_local | system_ocr_llm | vision_cloud | error
   */
  path: string = ''
}

/**
 * AI 解析编排（无 UI）
 * 对齐鸿蒙端侧 AI：Core Vision OCR + Core Speech 听写 优先；
 * 结构化：本地规则 → 文字 LLM → 视觉多模态兜底。
 */
export class AIParseOrchestrator {
  static readonly MSG_TEXT_KEY_REQUIRED: string =
    '请先在设置中配置「文字解析」API Key'
  static readonly MSG_TEXT_PARSE_REQUIRED: string =
    '请先在设置中配置「文字解析」（键盘、系统听写与 OCR 文本均需使用）'
  static readonly MSG_VISION_REQUIRED: string =
    '未识别到文字。可在设置开启「图片」解析，或更换更清晰的图片。'
  static readonly MSG_IMAGE_ENCODE_FAIL: string = '图片无法打开，请更换后重试'
  static readonly MSG_IMAGE_PARSE_FAIL: string = '图片识别失败，请重试'
  static readonly MSG_EMPTY_IMAGE: string = '未识别到可用的负债、订阅或账户信息'
  static readonly MSG_OCR_LOCAL_ONLY: string =
    '已用系统 OCR 读出文字，但本地规则未完整识别且未配置 AI Key。可补充描述后发送，或到设置接通文字/图片解析。'
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
   * 文字解析：本地规则（秒级）→ 云端文字模型。
   * 无 Key 时：本地规则成功则直接返回；否则引导配置。
   */
  static async parseText(userText: string): Promise<ParseResult> {
    return AIParseOrchestrator.parseTextInternal(userText, false)
  }

  /** OCR 后：本地规则优先，云端用短 prompt */
  static async parseTextFromOcr(userText: string): Promise<ParseResult> {
    return AIParseOrchestrator.parseTextInternal(userText, true)
  }

  private static async parseTextInternal(userText: string, fromOcr: boolean): Promise<ParseResult> {
    const channel = fromOcr ? 'ocr' : 'text'
    try {
      const local = LocalBillExtractService.tryExtract(userText)
      // OCR 场景：只要本地抽出可用金额/期数就立即返回，绝不拖云端
      if (local !== null && LocalBillExtractService.isResultUsable(local)) {
        AnalyticsService.trackAiParseResult(true, channel, local.items.length)
        return local
      }
      const config = await AIParseOrchestrator.resolveTextParseConfig()
      if (config === null) {
        if (local !== null && local.items.length > 0) {
          AnalyticsService.trackAiParseResult(true, channel, local.items.length)
          return local
        }
        const r = new ParseResult()
        r.rawContent = 'TEXT_DISABLED'
        r.clarifyQuestion = AIParseOrchestrator.MSG_TEXT_PARSE_REQUIRED
        AnalyticsService.trackAiParseResult(false, channel, 0, 'no_key')
        return r
      }
      const remote = fromOcr ?
        await AIService.parseDebtTextFast(userText, config) :
        await AIService.parseDebtText(userText, config)
      if (remote.items.length === 0 && local !== null && local.items.length > 0) {
        AnalyticsService.trackAiParseResult(true, channel, local.items.length)
        return local
      }
      AnalyticsService.trackAiParseResult(remote.items.length > 0, channel, remote.items.length,
        remote.items.length > 0 ? '' : 'empty')
      return remote
    } catch (_e) {
      const local = LocalBillExtractService.tryExtract(userText)
      if (local !== null && local.items.length > 0) {
        AnalyticsService.trackAiParseResult(true, channel, local.items.length)
        return local
      }
      const r = new ParseResult()
      r.rawContent = 'HTTP_EXCEPTION: orchestrator'
      r.clarifyQuestion = ''
      AnalyticsService.trackAiParseResult(false, channel, 0, 'exception')
      return r
    }
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
   * 对已选 PixelMap：
   * 1) **强制** Core Vision OCR（不因 isAvailable 短路跳过）
   * 2) OCR 有字 → 本地规则；可用则 **立即返回**，绝不调视觉
   * 3) 规则不够 → 短 prompt 文字 LLM（仍不调视觉）
   * 4) OCR 无字才视觉兜底
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
      // 始终尝试系统 OCR；isAvailable 仅作提示，不得跳过
      let ocrText = ''
      try {
        ocrText = await OcrService.recognizePixelMap(pixelMap)
      } catch (_e) {
        ocrText = ''
      }
      out.ocrText = ocrText

      if (OcrService.isOcrTextUseful(ocrText)) {
        // ① 本地规则（无网络）—— OCR 有字时最高优先
        const local = LocalBillExtractService.tryExtract(ocrText)
        if (local !== null && LocalBillExtractService.isResultUsable(local)) {
          out.kind = 'vision'
          out.visionResult = local
          out.path = 'system_ocr_local'
          // 未走 parseTextInternal，此处补记 ocr 通道
          AnalyticsService.trackAiParseResult(true, 'ocr', local.items.length)
          return out
        }
        // ② 快速文字 LLM（OCR 文本，短 prompt）；有字则 **禁止** 再走视觉
        // 成功/失败由 parseTextInternal 已记 ai_parse_result
        const textResult = await AIParseOrchestrator.parseTextFromOcr(ocrText)
        if (textResult.rawContent === 'TEXT_DISABLED') {
          if (local !== null && local.items.length > 0) {
            out.kind = 'vision'
            out.visionResult = local
            out.path = 'system_ocr_local'
            return out
          }
          // 有 OCR 文本但无 Key：填入引导，绝不静默转视觉拖死
          out.kind = 'error'
          out.message = AIParseOrchestrator.MSG_OCR_LOCAL_ONLY
          out.path = 'system_ocr_need_key'
          return out
        }
        if (textResult.items.length === 0 && textResult.rawContent.length > 0) {
          if (local !== null && local.items.length > 0) {
            out.kind = 'vision'
            out.visionResult = local
            out.path = 'system_ocr_local'
            return out
          }
          if (AIParseOrchestrator.isVisionTimeout(textResult.rawContent)) {
            out.kind = 'error'
            out.message = AIParseOrchestrator.MSG_VISION_TIMEOUT
            out.path = 'system_ocr_llm_timeout'
            return out
          }
          if (textResult.rawContent.indexOf('HTTP_ERROR_401') === 0 ||
            textResult.rawContent.indexOf('HTTP_ERROR_403') === 0) {
            out.kind = 'error'
            out.message = AIParseOrchestrator.MSG_VISION_AUTH
            out.path = 'error'
            return out
          }
          if (textResult.rawContent.indexOf('HTTP_') === 0 ||
            textResult.rawContent.indexOf('PARSING_') === 0 ||
            textResult.rawContent.indexOf('FORMAT_') === 0) {
            out.kind = 'error'
            out.message = textResult.rawContent.indexOf('FORMAT_') === 0 ?
              AIParseOrchestrator.MSG_FORMAT_ANTHROPIC :
              AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL
            out.path = 'error'
            return out
          }
        }
        out.kind = 'vision'
        out.visionResult = textResult
        out.path = textResult.rawContent.indexOf('LOCAL_RULE') === 0 ?
          'system_ocr_local' : 'system_ocr_llm'
        return out
      }

      // ③ 仅 OCR 无有效文字时，才允许视觉多模态
      const visionOut = await AIParseOrchestrator.runVisionFallback(pixelMap, out, ocrText)
      visionOut.path = visionOut.kind === 'error' ? 'error' : 'vision_cloud'
      const vCount = visionOut.visionResult !== null ? visionOut.visionResult.items.length : 0
      AnalyticsService.trackAiParseResult(
        visionOut.kind !== 'error' && vCount > 0,
        'vision',
        vCount,
        visionOut.kind === 'error' ? 'vision_fail' : ''
      )
      return visionOut
    } catch (_e) {
      out.kind = 'error'
      out.message = AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL
      out.path = 'error'
      AnalyticsService.trackAiParseResult(false, 'vision', 0, 'exception')
      return out
    }
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

  /** 视觉多模态兜底（压缩图 + 短 prompt） */
  private static async runVisionFallback(
    pixelMap: image.PixelMap,
    out: AIImageParseOutcome,
    ocrText: string
  ): Promise<AIImageParseOutcome> {
    out.ocrText = ocrText
    const vision = await AIService.loadVisionChannelConfig()
    if (!vision.enabled || vision.key.length === 0) {
      out.kind = 'error'
      out.message = AIParseOrchestrator.MSG_VISION_REQUIRED
      return out
    }
    const b64 = await OcrService.pixelMapToJpegBase64(pixelMap)
    if (b64.length === 0) {
      out.kind = 'error'
      out.message = AIParseOrchestrator.MSG_IMAGE_ENCODE_FAIL
      return out
    }
    const result = await AIService.parseDebtFromImage(b64, vision)
    if (result.items.length === 0 && result.rawContent.length > 0) {
      const failMsg = AIParseOrchestrator.messageForVisionFailure(result.rawContent)
      if (failMsg.length > 0) {
        out.kind = 'error'
        out.message = failMsg
        return out
      }
    }
    out.kind = 'vision'
    out.visionResult = result
    return out
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
