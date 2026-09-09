import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AIChannelConfig } from 'common'
import { SettingsService } from '../SettingsService'
import { UserService } from '../UserService'
import { buildUnifiedSystemPrompt, coerceDebtTypeByPeriods, normalizeFlexibleDate } from './ParsePrompts'

export class ParseResultItem {
  tempId: string = ''
  recordType: string = ''
  parsedFields: Map<string, string | number | boolean | null> = new Map()
  confidence: Map<string, string> = new Map()
  isComplete: boolean = false
}

export class ParseResult {
  items: ParseResultItem[] = []
  clarifyQuestion: string = ''
  isComplete: boolean = false
  rawContent: string = ''
}

/** 测试连接结果 */
export class AIConnectionTestResult {
  ok: boolean = false
  message: string = ''
}

export class AIService {
  /**
   * 从本机设置加载「文字解析」渠道（统一内容处理架构下与图片共用同一提示词）
   */
  static async loadTextChannelConfig(userId?: string): Promise<AIChannelConfig> {
    const uid = userId !== undefined && userId.length > 0 ? userId : UserService.getCurrentUserId()
    const settings = await SettingsService.getSettings(uid)
    const config = new AIChannelConfig()
    config.enabled = settings.ai_text_enabled
    config.key = settings.ai_text_key
    config.baseUrl = settings.ai_text_base_url
    config.model = settings.ai_text_model
    config.apiFormat = settings.ai_text_api_format
    return config
  }

  /** 从本机设置加载「图片识别」渠道 */
  static async loadVisionChannelConfig(userId?: string): Promise<AIChannelConfig> {
    const uid = userId !== undefined && userId.length > 0 ? userId : UserService.getCurrentUserId()
    const settings = await SettingsService.getSettings(uid)
    const config = new AIChannelConfig()
    config.enabled = settings.ai_vision_enabled
    config.key = settings.ai_vision_key
    config.baseUrl = settings.ai_vision_base_url
    config.model = settings.ai_vision_model
    config.apiFormat = settings.ai_vision_api_format
    return config
  }

  /**
   * 将配置里的 Base URL（SDK 根地址）解析为实际 POST 地址。
   * - 已含 chat/completions → 原样使用
   * - 否则去掉尾 / 后拼接 /chat/completions
   * - 空 → OpenAI 默认完整地址
   * - 火山 Coding Plan：Anthropic 根地址 /api/coding 自动纠正为 OpenAI 根 /api/coding/v3
   */
  static resolveChatCompletionsUrl(baseUrl: string): string {
    let u = baseUrl.trim()
    if (u.length === 0) {
      return 'https://api.openai.com/v1/chat/completions'
    }
    while (u.endsWith('/') && u.length > 1) {
      u = u.substring(0, u.length - 1)
    }
    // 本应用仅走 OpenAI 兼容协议；纠正火山 Coding Plan 常见误填
    u = AIService.normalizeVolcCodingPlanOpenAiBase(u)
    if (u.endsWith('/chat/completions')) {
      return u
    }
    // 兼容用户误填完整 path 的变体
    if (u.indexOf('/chat/completions') >= 0) {
      return u
    }
    return u + '/chat/completions'
  }

  /**
   * 火山引擎 Coding Plan：
   * - Anthropic 兼容根：https://ark.cn-beijing.volces.com/api/coding
   * - OpenAI 兼容根：  https://ark.cn-beijing.volces.com/api/coding/v3
   * 用户从文档复制 Anthropic 地址后，OpenAI 请求会打到错误 path 并长时间挂起直至超时。
   */
  static normalizeVolcCodingPlanOpenAiBase(baseUrl: string): string {
    let u = baseUrl.trim()
    while (u.endsWith('/') && u.length > 1) {
      u = u.substring(0, u.length - 1)
    }
    const lower = u.toLowerCase()
    const marker = '/api/coding'
    // 仅纠正火山 volces.com 下的 Coding Plan 根
    if (lower.indexOf('volces.com') < 0) {
      return u
    }
    const codingIdx = lower.indexOf(marker)
    if (codingIdx < 0) {
      return u
    }
    const after = u.substring(codingIdx + marker.length)
    // 已是 /v3 或 /v3/...
    if (after === '/v3' || after.indexOf('/v3/') === 0 || after.indexOf('/v3?') === 0) {
      return u
    }
    // .../api/coding → .../api/coding/v3
    // .../api/coding/chat/completions → .../api/coding/v3/chat/completions
    if (after.length === 0) {
      return u + '/v3'
    }
    if (after.charAt(0) === '/') {
      return u.substring(0, codingIdx + marker.length) + '/v3' + after
    }
    return u
  }

  /** 去掉首尾空白与误粘贴的换行，避免鉴权 401 */
  static normalizeApiKey(key: string): string {
    return key.replace(/\s+/g, '').trim()
  }

  /**
   * 本应用实际只发 OpenAI Chat Completions（Bearer + /chat/completions）。
   * 配置里的 anthropic 仅作 UI 标记；火山 Coding Plan 的 /api/coding/v3 必须按 OpenAI 走。
   */
  static isOpenAiCompatibleConfig(baseUrl: string, apiFormat: string): boolean {
    const u = baseUrl.trim().toLowerCase()
    if (u.indexOf('volces.com') >= 0 && u.indexOf('/api/coding') >= 0) {
      // Coding Plan：一律按 OpenAI（含误选 anthropic）
      return true
    }
    if (apiFormat === 'anthropic') {
      return false
    }
    return true
  }

  /**
   * 统一解析入口（文字）：与图片共用同一条提示词与同一套处理逻辑。
   */
  static async parseDebtText(text: string, config: AIChannelConfig): Promise<ParseResult> {
    const key = AIService.normalizeApiKey(config.key)
    if (key.length === 0) {
      return AIService.failureResult('TEXT_DISABLED')
    }
    if (!AIService.isOpenAiCompatibleConfig(config.baseUrl, config.apiFormat)) {
      return AIService.failureResult('FORMAT_UNSUPPORTED_ANTHROPIC')
    }
    const url = AIService.resolveChatCompletionsUrl(config.baseUrl)
    return AIService.callUnified(url, key, config.model, text, '')
  }

  /**
   * 统一解析入口（图片）：图片直发多模态模型，与文字共用同一提示词。
   * @param jpegBase64 不含 data: 前缀的 JPEG base64
   */
  static async parseDebtFromImage(jpegBase64: string, config: AIChannelConfig): Promise<ParseResult> {
    const key = AIService.normalizeApiKey(config.key)
    if (!config.enabled || key.length === 0) {
      return AIService.failureResult('VISION_DISABLED')
    }
    if (jpegBase64.length === 0) {
      return AIService.failureResult('EMPTY_IMAGE')
    }
    if (!AIService.isOpenAiCompatibleConfig(config.baseUrl, config.apiFormat)) {
      return AIService.failureResult('FORMAT_UNSUPPORTED_ANTHROPIC')
    }
    const url = AIService.resolveChatCompletionsUrl(config.baseUrl)
    return AIService.callUnified(url, key, config.model, '', jpegBase64)
  }

  /**
   * 统一调用：文字与图片走同一请求构造、同一提示词、同一解析与校验。
   * jpegBase64 非空时为图片输入（多模态），否则为文字输入。
   */
  private static async callUnified(url: string, key: string, model: string, text: string,
    jpegBase64: string): Promise<ParseResult> {
    const isImage = jpegBase64.length > 0
    const date = new Date()
    const year = date.getFullYear()
    const month = ('0' + (date.getMonth() + 1)).slice(-2)
    const day = ('0' + date.getDate()).slice(-2)
    const currentDate = `${year}-${month}-${day}`
    const modelName = model.length > 0 ? model : 'deepseek-v4-flash'
    const systemPrompt = buildUnifiedSystemPrompt(currentDate)
    let userText = text
    if (!isImage && userText.length > 6000) {
      // 截断标记与提示词约定一致：模型见到后不对缺失部分做确定性结论
      userText = userText.substring(0, 6000) + '\n[输入已截断]'
    }
    const userContent = isImage
      ? '[' +
      '{"type":"text","text":"先判定有无多期还款计划再提取，只返回JSON。"},' +
      '{"type":"image_url","image_url":{"url":"data:image/jpeg;base64,' + jpegBase64 + '","detail":"high"}}' +
      ']'
      : JSON.stringify(userText)
    // 图片直发视觉模型：准确性优先，给足读取时间；文字保持短超时
    const maxTokens = isImage ? 2048 : 1536
    const readTimeout = isImage ? 60000 : 25000
    const bodyStr = '{' +
      '"model":' + JSON.stringify(modelName) + ',' +
      '"messages":[' +
      '{"role":"system","content":' + JSON.stringify(systemPrompt) + '},' +
      '{"role":"user","content":' + userContent + '}' +
      '],' +
      '"max_tokens":' + maxTokens + ',' +
      '"response_format":{"type":"json_object"}' +
      '}'
    const errPrefix = isImage ? 'VISION_' : 'HTTP_'
    try {
      const response = await AIService.requestOnce(
        url,
        {
          method: http.RequestMethod.POST,
          header: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer ' + key,
            'User-Agent': 'GoForward/1.0'
          },
          extraData: bodyStr,
          expectDataType: http.HttpDataType.STRING,
          usingCache: false,
          usingProtocol: http.HttpProtocol.HTTP1_1,
          connectTimeout: 15000,
          readTimeout: readTimeout
        }
      )
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const raw = response.result !== undefined && response.result !== null
          ? response.result.toString()
          : ''
        // 保持既有错误码格式：文字 HTTP_ERROR_xxx / 图片 VISION_HTTP_xxx（上层按前缀匹配文案）
        const httpErrCode = isImage
          ? 'VISION_HTTP_' + response.responseCode
          : 'HTTP_ERROR_' + response.responseCode
        return AIService.failureResult(httpErrCode + AIService.safeErrSnippet(raw))
      }
      const rawResult = response.result !== undefined && response.result !== null
        ? response.result.toString()
        : ''
      if (rawResult.length === 0) {
        return AIService.failureResult(errPrefix + 'EMPTY_BODY')
      }
      const content = AIService.extractAssistantContent(rawResult)
      if (content.length === 0) {
        return AIService.failureResult(errPrefix + 'EMPTY_CONTENT')
      }
      return AIService.parseJson(content, currentDate)
    } catch (err) {
      const msg = AIService.describeCaughtError(err as Object)
      const lower = msg.toLowerCase()
      if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0 ||
        lower.indexOf('time out') >= 0 || msg.indexOf('超时') >= 0) {
        return AIService.failureResult(errPrefix + 'TIMEOUT' + AIService.safeErrSnippet(msg))
      }
      return AIService.failureResult(errPrefix + 'EXCEPTION' + AIService.safeErrSnippet(msg))
    }
  }

  /**
   * 从 OpenAI 兼容响应体取出 assistant 文本。
   * 兼容 content 为 string，或 content 为多段数组（部分服务商）。
   */
  private static extractAssistantContent(rawResult: string): string {
    try {
      const root = JSON.parse(rawResult) as Record<string, Object>
      const choices = root['choices']
      if (choices === undefined || choices === null || !(choices instanceof Array) || choices.length === 0) {
        return ''
      }
      const first = choices[0] as Record<string, Object>
      const message = first['message'] as Record<string, Object>
      if (message === undefined || message === null) {
        return ''
      }
      const content = message['content']
      if (content === undefined || content === null) {
        return ''
      }
      if (typeof content === 'string') {
        return content
      }
      // content: [{ type, text }, ...]
      if (content instanceof Array) {
        let joined = ''
        for (let i = 0; i < content.length; i++) {
          const part = content[i] as Record<string, Object>
          if (part !== undefined && part !== null && part['text'] !== undefined) {
            joined += `${part['text']}`
          }
        }
        return joined
      }
      return `${content}`
    } catch (_e) {
      return ''
    }
  }

  /** 去掉模型偶发的 ```json ... ``` 围栏，便于 JSON.parse */
  private static stripMarkdownFence(content: string): string {
    let s = content.trim()
    if (s.indexOf('```') !== 0) {
      return s
    }
    // ```json\n{...}\n``` 或 ```\n{...}\n```
    const firstNl = s.indexOf('\n')
    if (firstNl > 0) {
      s = s.substring(firstNl + 1)
    }
    const endFence = s.lastIndexOf('```')
    if (endFence >= 0) {
      s = s.substring(0, endFence)
    }
    return s.trim()
  }

  private static parseJson(content: string, currentDate: string): ParseResult {
    try {
      const cleaned = AIService.stripMarkdownFence(content)
      const data = JSON.parse(cleaned) as Record<string, Object>
      const result = new ParseResult()
      result.rawContent = cleaned
      // is_complete 可能是 boolean 或缺失
      const completeRaw = data['is_complete']
      result.isComplete = completeRaw === true || completeRaw === 'true'
      // clarify_question 可能为 null
      const clarifyRaw = data['clarify_question']
      if (clarifyRaw === undefined || clarifyRaw === null || clarifyRaw === 'null') {
        result.clarifyQuestion = ''
      } else {
        result.clarifyQuestion = `${clarifyRaw}`.trim()
      }
      const itemsRaw = data['items']
      if (itemsRaw !== undefined && itemsRaw !== null && itemsRaw instanceof Array) {
        for (let i = 0; i < itemsRaw.length; i++) {
          const item = itemsRaw[i] as Record<string, Object>
          if (item === undefined || item === null) {
            continue
          }
          const parsed = new ParseResultItem()
          parsed.tempId = item['temp_id'] !== undefined && item['temp_id'] !== null
            ? `${item['temp_id']}` : `${i + 1}`
          const rtRaw = item['record_type']
          const rt = rtRaw !== undefined && rtRaw !== null ? `${rtRaw}`.trim() : ''
          if (rt === 'subscription' || rt === 'credit_account' || rt === 'debt') {
            parsed.recordType = rt
          } else {
            parsed.recordType = 'debt'
          }
          const itemComplete = item['is_complete']
          parsed.isComplete = itemComplete === true || itemComplete === 'true'
          const fields = item['parsed_fields'] as Record<string, string | number | boolean | null>
          if (fields !== undefined && fields !== null) {
            const fieldKeys = Object.keys(fields)
            for (const key of fieldKeys) {
              parsed.parsedFields.set(key, fields[key])
            }
          }
          const conf = item['confidence'] as Record<string, string>
          if (conf !== undefined && conf !== null) {
            const confKeys = Object.keys(conf)
            for (const key of confKeys) {
              parsed.confidence.set(key, conf[key])
            }
          }
          result.items.push(parsed)
        }
      }
      AIService.sanitizeParseResult(result, currentDate)
      return result
    } catch (err) {
      // 禁止把模型原文写进错误码（可能含财务字段，且会进 rawContent 链路）
      const errBrief = err instanceof Error ? err.message : 'parse_error'
      return AIService.failureResult(
        'PARSING_EXCEPTION: ' + errBrief + ' | content_len=' + content.length
      )
    }
  }

  /**
   * 输出校验与清洗（错误处理与业务规则验证）：
   * - 金额类字段必须是有限数字，否则置 null（防字符串/NaN/Infinity 入库）
   * - 期数必须是正整数，否则置 null
   * - 日期字段不限输入格式（账单/票据形态多样），尽力归一化；完全无法解析才置 null
   * - 期数一致性：分期且 total>0 时 remaining 收敛到 [1, total]
   * - debt 缺 platform 时补默认值，避免下游出现空平台
   */
  private static sanitizeParseResult(result: ParseResult, currentDate: string): void {
    const moneyKeys: string[] = ['principal', 'current_balance', 'monthly_payment',
      'annual_rate', 'amount', 'credit_limit']
    const intKeys: string[] = ['total_periods', 'remaining_periods', 'bill_day',
      'payment_day', 'annual_fee_required_swipes', 'grace_period_days', 'interest_free_days']
    const dateKeys: string[] = ['start_date', 'next_payment_date', 'next_billing_date',
      'expiry_date']
    for (let i = 0; i < result.items.length; i++) {
      const item = result.items[i]
      for (let k = 0; k < moneyKeys.length; k++) {
        const key = moneyKeys[k]
        const v = item.parsedFields.get(key)
        if (v === undefined || v === null || v === '') {
          continue
        }
        const n = typeof v === 'number' ? v : Number(v)
        if (isNaN(n) || !isFinite(n) || n < 0) {
          item.parsedFields.set(key, null)
        } else {
          item.parsedFields.set(key, n)
        }
      }
      for (let k = 0; k < intKeys.length; k++) {
        const key = intKeys[k]
        const v = item.parsedFields.get(key)
        if (v === undefined || v === null || v === '') {
          continue
        }
        const n = typeof v === 'number' ? v : Number(v)
        if (isNaN(n) || !isFinite(n) || n <= 0 || Math.floor(n) !== n) {
          item.parsedFields.set(key, null)
        } else {
          item.parsedFields.set(key, n)
        }
      }
      for (let k = 0; k < dateKeys.length; k++) {
        const key = dateKeys[k]
        const v = item.parsedFields.get(key)
        if (v === undefined || v === null || v === '') {
          continue
        }
        const monthOnly = key === 'expiry_date'
        const preferFuture = key === 'next_payment_date' || key === 'next_billing_date'
        item.parsedFields.set(key, normalizeFlexibleDate(`${v}`, currentDate, monthOnly, preferFuture))
      }
      // 期数一致性：多期不得落成一次性；分期且总期数有效时 remaining 收敛到 [1, total]
      if (item.recordType === 'debt') {
        const dtRaw = `${item.parsedFields.get('debt_type') ?? ''}`
        const total = item.parsedFields.get('total_periods')
        const remain = item.parsedFields.get('remaining_periods')
        const totalN = typeof total === 'number' ? total : 0
        const remainN = typeof remain === 'number' ? remain : 0
        const dt = coerceDebtTypeByPeriods(dtRaw, totalN, remainN)
        if (dt !== dtRaw) {
          item.parsedFields.set('debt_type', dt)
        }
        if (dt === 'installment' && totalN > 0) {
          if (typeof remain !== 'number' || remainN < 1 || remainN > totalN) {
            item.parsedFields.set('remaining_periods', totalN)
          }
        }
        const platform = item.parsedFields.get('platform')
        if (platform === undefined || platform === null || `${platform}`.trim().length === 0) {
          item.parsedFields.set('platform', '未知平台')
        }
      }
    }
  }

  static async testConnection(key: string, baseUrl: string, model: string): Promise<boolean> {
    const r = await AIService.testConnectionDetailed(key, baseUrl, model)
    return r.ok
  }

  /**
   * 配置页 Toast：测通结果优先；禁止把落盘异常盖成「网络异常」。
   */
  static testResultToast(ok: boolean, message: string, okText: string, failText: string): string {
    if (ok) {
      return okText
    }
    if (message.length > 0) {
      return message
    }
    return failText
  }

  /**
   * 从鸿蒙 BusinessError / 普通对象取出 code+message。
   * 禁止 instanceof Error：原生 BusinessError 上它会抛或恒 false，导致测通 catch 再抛，
   * 配置页只能看到「网络异常，请稍后重试」。
   */
  static describeCaughtError(err: Object | string | number | boolean | null | undefined): string {
    if (err === undefined || err === null) {
      return ''
    }
    if (typeof err === 'string') {
      return err
    }
    if (typeof err === 'number' || typeof err === 'boolean') {
      return `${err}`
    }
    let codePart = ''
    let msgPart = ''
    try {
      const rec = err as Record<string, number | string | Object>
      if (rec['code'] !== undefined && rec['code'] !== null) {
        codePart = `${rec['code']}`
      }
      if (rec['message'] !== undefined && rec['message'] !== null) {
        msgPart = `${rec['message']}`
      }
    } catch (_e) {
    }
    if (codePart.length > 0 && msgPart.length > 0) {
      return codePart + ' ' + msgPart
    }
    if (msgPart.length > 0) {
      return msgPart
    }
    if (codePart.length > 0) {
      return codePart
    }
    try {
      return `${err}`
    } catch (_e2) {
      return ''
    }
  }

  static hintFromCaughtError(err: Object | string | number | boolean | null | undefined,
    url: string): string {
    return AIService.networkFailureHint(AIService.describeCaughtError(err), url)
  }

  /**
   * 测通并返回可读原因（便于配置页 Toast）
   */
  static async testConnectionDetailed(key: string, baseUrl: string,
    model: string): Promise<AIConnectionTestResult> {
    const result = new AIConnectionTestResult()
    const cleanKey = AIService.normalizeApiKey(key)
    if (cleanKey.length === 0) {
      result.message = '缺少 API Key'
      return result
    }
    if (baseUrl.trim().length === 0) {
      result.message = '缺少 Base URL'
      return result
    }
    if (model.trim().length === 0) {
      result.message = '缺少模型名'
      return result
    }
    const url = AIService.resolveChatCompletionsUrl(baseUrl)
    try {
      const body = '{' +
        '"model":' + JSON.stringify(model.trim()) + ',' +
        '"messages":[{"role":"user","content":"ping"}],' +
        '"max_tokens":5' +
        '}'
      const header: Record<string, string> = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ' + cleanKey,
        'User-Agent': 'GoForward/1.0'
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.POST,
        header: header,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        usingCache: false,
        usingProtocol: http.HttpProtocol.HTTP1_1,
        connectTimeout: 15000,
        readTimeout: 25000
      }
      const response = await AIService.requestOnce(url, options)
      const code = response.responseCode
      if (code >= 200 && code < 300) {
        result.ok = true
        result.message = '连接成功'
        return result
      }
      let detail = ''
      try {
        const raw = response.result !== undefined && response.result !== null
          ? response.result.toString()
          : ''
        if (raw.length > 0) {
          detail = AIService.shortErrorBody(raw)
        }
      } catch (_e) {
      }
      if (code === 401 || code === 403) {
        result.message = '连接失败(' + code + ')：API Key 无效或无权限。' +
          '请确认使用方舟 Coding Plan 的 Key，API 格式选 OpenAI，Base URL 为 …/api/coding/v3'
      } else if (code === 404) {
        result.message = detail.length > 0 ? detail : '地址或模型不存在，请检查 Base URL 与模型名'
      } else if (code === 400) {
        result.message = detail.length > 0 ? detail : '参数有误，请检查模型名'
      } else {
        result.message = detail.length > 0 ? detail : ('服务返回异常（' + code + '）')
      }
      return result
    } catch (err) {
      result.message = AIService.hintFromCaughtError(err as Object, url)
      return result
    }
  }

  /**
   * 回调式 request：Promise 版在部分机型上会把 BusinessError 抛到 await 之外。
   */
  private static requestOnce(url: string, options: http.HttpRequestOptions): Promise<http.HttpResponse> {
    const httpRequest = http.createHttp()
    return new Promise<http.HttpResponse>((resolve, reject) => {
      httpRequest.request(url, options, (err: BusinessError, data: http.HttpResponse) => {
        try {
          httpRequest.destroy()
        } catch (_e) {
        }
        if (err !== undefined && err !== null && err.code !== undefined && err.code !== 0) {
          reject(err)
          return
        }
        resolve(data)
      })
    })
  }

  /**
   * 网络层异常 → 可执行提示。
   * 超时最常见的成因是 Base URL 填错（域名不通 / path 不对）。
   * 鸿蒙网络错误码：2300028 超时、2300007 连不上、2300006 域名解析失败。
   */
  static networkFailureHint(rawErr: string, url: string): string {
    const lower = rawErr.toLowerCase()
    const host = AIService.hostOf(url)
    const hostBit = host.length > 0 ? host : '该地址'
    if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0 ||
      lower.indexOf('time out') >= 0 || lower.indexOf('2300028') >= 0 ||
      rawErr.indexOf('超时') >= 0) {
      return '连接超时：请检查 Base URL 是否正确、网络能否访问 ' + hostBit
    }
    if (lower.indexOf('2300006') >= 0 || lower.indexOf('resolve host') >= 0 ||
      lower.indexOf('couldn\'t resolve') >= 0 || rawErr.indexOf('域名') >= 0) {
      return '域名解析失败：请检查 Base URL 中的地址 ' + hostBit + ' 是否写错'
    }
    if (lower.indexOf('2300003') >= 0 || lower.indexOf('2300059') >= 0 ||
      lower.indexOf('2300064') >= 0 || lower.indexOf('ssl') >= 0 ||
      lower.indexOf('certificate') >= 0) {
      return '证书校验失败：设备无法安全访问 ' + hostBit + '，请检查系统时间或换网络'
    }
    if (lower.indexOf('2300005') >= 0 || lower.indexOf('2300007') >= 0 ||
      lower.indexOf('couldn\'t connect') >= 0 || lower.indexOf('connection refused') >= 0) {
      return '无法连接 ' + hostBit + '，请检查网络与 Base URL 后重试'
    }
    return '无法连接 ' + hostBit + '，请检查网络与 Base URL 后重试'
  }

  /** 取 URL 的 host 用于提示，不暴露 path 与 Key；不用正则以免 ArkTS 抛错再盖成网络异常 */
  static hostOf(url: string): string {
    let u = url.trim()
    const lower = u.toLowerCase()
    if (lower.indexOf('https://') === 0) {
      u = u.substring(8)
    } else if (lower.indexOf('http://') === 0) {
      u = u.substring(7)
    }
    const slash = u.indexOf('/')
    const host = slash > 0 ? u.substring(0, slash) : u
    return host.length > 0 ? host : url
  }

  private static shortErrorBody(raw: string): string {
    try {
      const obj = JSON.parse(raw) as Record<string, Object>
      if (obj['error'] !== undefined) {
        const errObj = obj['error'] as Record<string, Object>
        if (errObj['message'] !== undefined) {
          const m = `${errObj['message']}`
          return m.length > 80 ? m.substring(0, 80) + '…' : m
        }
      }
      if (obj['message'] !== undefined) {
        const m = `${obj['message']}`
        return m.length > 80 ? m.substring(0, 80) + '…' : m
      }
    } catch (_e) {
    }
    return raw.length > 60 ? raw.substring(0, 60) + '…' : raw
  }

  /**
   * 失败/未配置结果：无 items，禁止调用方当成功入库（P5）
   * @param code 机器可读原因，写入 rawContent
   */
  private static failureResult(code: string): ParseResult {
    const result = new ParseResult()
    result.isComplete = false
    result.rawContent = code
    result.clarifyQuestion = ''
    return result
  }

  /** 错误片段脱敏：短、无 body 全文 */
  private static safeErrSnippet(raw: string): string {
    if (raw.length === 0) {
      return ''
    }
    const oneLine = raw.replace(/\s+/g, ' ').trim()
    const cut = oneLine.length > 80 ? oneLine.substring(0, 80) : oneLine
    return ': ' + cut
  }
}
