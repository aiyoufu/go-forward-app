import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AIChannelConfig } from 'common'
import { SettingsService } from '../SettingsService'
import { UserService } from '../UserService'

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
   * 从本机设置加载「文字解析」渠道（键盘录入 / OCR 文本共用）
   * S1：统一配置读取，避免 Live / Chat 各写一份
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

  static async parseDebtText(text: string, config: AIChannelConfig): Promise<ParseResult> {
    return AIService.parseDebtTextInternal(text, config, false)
  }

  /**
   * OCR 后的快速文字解析：短 prompt + 短超时，避免「已 OCR 仍卡死在云端」。
   */
  static async parseDebtTextFast(text: string, config: AIChannelConfig): Promise<ParseResult> {
    return AIService.parseDebtTextInternal(text, config, true)
  }

  private static async parseDebtTextInternal(text: string, config: AIChannelConfig,
    fast: boolean): Promise<ParseResult> {
    const key = AIService.normalizeApiKey(config.key)
    if (key.length === 0) {
      return AIService.failureResult('TEXT_DISABLED')
    }
    if (!AIService.isOpenAiCompatibleConfig(config.baseUrl, config.apiFormat)) {
      return AIService.failureResult('FORMAT_UNSUPPORTED_ANTHROPIC')
    }
    const url = AIService.resolveChatCompletionsUrl(config.baseUrl)
    return AIService.callOpenAICompatible(url, key, config.model, text, fast)
  }

  /**
   * 视觉模型识别单据图（OpenAI 兼容 image_url / base64）
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
    return AIService.callOpenAIVision(url, key, config.model, jpegBase64)
  }

  private static async callOpenAIVision(url: string, key: string, model: string,
    jpegBase64: string): Promise<ParseResult> {
    const date = new Date()
    const year = date.getFullYear()
    const month = ('0' + (date.getMonth() + 1)).slice(-2)
    const day = ('0' + date.getDate()).slice(-2)
    const currentDate = `${year}-${month}-${day}`
    const modelName = model.length > 0 ? model : 'deepseek-v4-flash'
    // 视觉兜底用短 prompt：完整 getSystemPrompt 可达数千 token，叠加大图必慢必超时
    const systemPrompt = AIService.getVisionSystemPrompt(currentDate)
    const dataUrl = 'data:image/jpeg;base64,' + jpegBase64
    const userText =
      '读图提取负债/订阅/信用账户，金额单位元。只返回 JSON，不要解释。'
    // detail:low 降低视觉 token；max_tokens 收紧加快结束
    const bodyStr = '{' +
      '"model":' + JSON.stringify(modelName) + ',' +
      '"messages":[' +
      '{"role":"system","content":' + JSON.stringify(systemPrompt) + '},' +
      '{"role":"user","content":[' +
      '{"type":"text","text":' + JSON.stringify(userText) + '},' +
      '{"type":"image_url","image_url":{"url":' + JSON.stringify(dataUrl) +
      ',"detail":"low"}}' +
      ']}' +
      '],' +
      '"max_tokens":1024,' +
      '"response_format":{"type":"json_object"}' +
      '}'
    try {
      const response = await AIService.requestOnce(url, {
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
        // 视觉兜底：45s 内必须返回；超时即失败，避免「卡死式等待」
        readTimeout: 45000
      })
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const raw = response.result !== undefined && response.result !== null
          ? response.result.toString()
          : ''
        return AIService.failureResult('VISION_HTTP_' + response.responseCode +
          AIService.safeErrSnippet(raw))
      }
      const rawResult = response.result !== undefined && response.result !== null
        ? response.result.toString()
        : ''
      if (rawResult.length === 0) {
        return AIService.failureResult('VISION_EMPTY_BODY')
      }
      const content = AIService.extractAssistantContent(rawResult)
      if (content.length === 0) {
        return AIService.failureResult('VISION_EMPTY_CONTENT')
      }
      return AIService.parseJson(content)
    } catch (err) {
      const msg = AIService.describeCaughtError(err as Object)
      const lower = msg.toLowerCase()
      if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0 ||
        lower.indexOf('time out') >= 0 || msg.indexOf('超时') >= 0) {
        return AIService.failureResult('VISION_TIMEOUT' + AIService.safeErrSnippet(msg))
      }
      return AIService.failureResult('VISION_EXCEPTION' + AIService.safeErrSnippet(msg))
    }
  }

  /**
   * 视觉兜底专用短 system prompt（完整版仅用于纯文字解析）。
   * 目标：输入 token 小、输出结构够用，优先速度。
   */
  private static getVisionSystemPrompt(currentDate: string): string {
    return `财务票据抽取助手。今天=${currentDate}。只输出 JSON：
{"items":[{"temp_id":"1","record_type":"debt|subscription|credit_account","parsed_fields":{},"confidence":{},"is_complete":true}],"clarify_question":null,"is_complete":true}
debt.parsed_fields: platform,debt_type(installment|credit_card|loan|other),current_balance,monthly_payment,total_periods,remaining_periods,payment_day,next_payment_date,note
subscription: name,amount,billing_cycle,next_billing_date
credit_account: name,last_four,bill_day,payment_day,credit_limit
金额为元(number)。能算则算 remaining_periods/current_balance；缺关键信息 is_complete=false 并写 clarify_question。不要 markdown。`
  }

  private static getSystemPrompt(currentDate: string): string {
    return `你是一个智能财务信息提取助手。当前系统时间是：${currentDate}。
请从用户的描述中识别所有提到的负债单据、订阅服务或信用账户信息，并以严格的 JSON 格式返回，不包含任何其他文字：

{
  "items": [
    {
      "temp_id": "临时唯一标识符，如 '1', '2'，以便在多轮对话中追踪",
      "record_type": "debt" | "subscription" | "credit_account",
      "parsed_fields": { ... },
      "confidence": { ... },
      "is_complete": boolean
    }
  ],
  "clarify_question": "口语化中文问题，或 null",
  "is_complete": "是否所有条目均已收集/推理完整"
}

【record_type 分类规则】
- "subscription"：提到"订阅"、"会员"、"月费"、"年费"、"自动续费"、"VIP"、"包月"、"包年"等关键词
- "credit_account"：提到"卡号"、"尾号"、"额度"、"账单日"、"信用卡账户"等且不涉及具体欠款金额（仅描述卡片信息本身）
- "debt"：提到"分期"、"欠款"、"还款"、"账单"、"贷款"、"白条"、"花呗"等涉及具体负债

【各 record_type 的 parsed_fields 与 confidence 字段定义】

当 record_type = "debt" 时：
parsed_fields: {
  "platform": "平台名称，例如 '京东白条', '招商信用卡', '中信信用卡' 等",
  "debt_type": "installment" | "credit_card" | "loan" | "other" | null,
  "current_balance": number | null,
  "monthly_payment": number | null,
  "total_periods": number | null,
  "remaining_periods": number | null,
  "annual_rate": number | null,
  "payment_day": number | null,
  "last_four": "卡号尾号（4位数字）" | null,
  "start_date": "YYYY-MM-DD" | null,
  "next_payment_date": "YYYY-MM-DD" | null,
  "note": "备注" | null
}
confidence 字段与 parsed_fields 键名一一对应，值为 "high"|"medium"|"low"|"missing"。

当 record_type = "subscription" 时：
parsed_fields: {
  "name": "订阅服务名称，例如 '网易云音乐', '爱奇艺', 'ChatGPT Plus' 等",
  "category": "video" | "music" | "tools" | "learning" | "lifestyle" | "storage" | "fitness" | "programming" | "ai" | "other",
  "amount": number（每期金额，单位元）| null,
  "billing_cycle": "once" | "weekly" | "biweekly" | "monthly" | "quarterly" | "semiannually" | "annually",
  "next_billing_date": "YYYY-MM-DD" | null,
  "start_date": "YYYY-MM-DD" | null,
  "end_date": "YYYY-MM-DD" | null,
  "note": "备注" | null
}
confidence 字段与 parsed_fields 键名一一对应，值为 "high"|"medium"|"low"|"missing"。

当 record_type = "credit_account" 时：
parsed_fields: {
  "name": "信用卡名称，例如 '招商银行信用卡', '中信银行信用卡' 等",
  "last_four": "卡号尾号（4位数字）" | null,
  "bill_day": number（出单日，1-31）| null,
  "payment_day": number（还款日，1-31）| null,
  "credit_limit": number（额度，单位元）| null,
  "expiry_date": "YYYY-MM" | null,
  "annual_fee_required_swipes": number（免年费刷卡次数）| null,
  "grace_period_days": number（宽限天数，还款日后逾期宽限 1-3 天）| null,
  "interest_free_days": number（免息期天数，交易日至还款日 20-56 天）| null,
  "note": "备注" | null
}
confidence 字段与 parsed_fields 键名一一对应，值为 "high"|"medium"|"low"|"missing"。

【推理与计算规则（仅适用于 debt 类型）】
1. 每一笔负债中：principal（分期本金/原始总额）、current_balance（剩余待还）、monthly_payment（月供）、remaining_periods（剩余期数）是核心字段。
   - principal ≠ current_balance：截图「分期金额/分期本金」进 principal；「剩余待还」进 current_balance。
2. 你必须运用数学推理，结合当前系统时间（${currentDate}）与用户输入的信息，尽可能推算上述字段，而不是一味追问。能算出则 is_complete=true、confidence=high。
3. 【具体推理公式与规范】：
   - 【分期单据推算】：
     - 若有"每期金额/月供"和"总期数"，且未说明已还期数：默认已还 0，remaining_periods=总期数；principal = 月供 * 总期数；current_balance = principal。
       * 示例："京东白条分期6期，每期299.55元，从6月开始第一期"，今天 2026-06-08 → remaining=6，monthly=299.55，principal=current_balance=1797.3。
     - 若有首期还款月与总期数：按今天推已还期数，remaining = 总期数 - 已还；principal = 月供 * 总期数（原始总额）；current_balance = 月供 * remaining（剩余待还）。
       * 示例："中信分期每期58.55、9期、1月4日还首期"，今天 2026-06-08 → 已还约6期，remaining=3，principal=526.95，current_balance=175.65。
     - 若截图同时有「分期金额/本金」与「剩余待还」：principal 用前者，current_balance 用后者，勿把剩余填进本金。
   - 【普通信用卡/一次性单据】：
     - 若说"信用卡下月还398.11"且无分期关键字：debt_type=credit_card，principal 与 current_balance 均=该金额，remaining_periods=1，is_complete=true。
4. annual_rate 和 payment_day 缺失时可允许为 null，此时 confidence 为 missing，且不影响 is_complete。

【订阅推理规则】
1. 订阅的核心字段为 name、amount、billing_cycle。三者齐全即可将 is_complete 设为 true。
2. category 根据服务名称智能推断：视频平台→video，音乐平台→music，AI 工具→ai，编程工具→programming，等等。
3. next_billing_date 如用户未明确说明，不要猜测，设为 null。

【信用账户推理规则】
1. 信用账户的核心字段为 name。只要有名称即可将 is_complete 设为 true。
2. last_four、bill_day、payment_day、credit_limit 等为补充字段，缺失不影响 is_complete。
3. credit_limit 单位为元（用户说"额度5万"应转为 50000）。

【通用规则】
1. 只有在确实缺少信息且通过推理也无法算出的情况下，才需要将 is_complete 设为 false，并在 clarify_question 中提问。
2. 每轮只生成一个整体的 clarify_question，用朋友对话一样的口语化中文，提示用户补充信息。如果所有数据都已提取或推理齐全，则 clarify_question 必须设为 null。
3. 平台名/服务名保留用户原始表述。金额统一转为元（number）。
4. 如果系统输入提供了先前已经提取的数据状态，请在此基础上更新或添加，并保留先前的 temp_id；对于已补充完整或未提及需要补充的条目，请保持原样，不要随意修改或丢失已有的字段。
5. 用户输入可能同时包含多种类型的数据（如同时提到负债和订阅），必须在 items 数组中为每一条数据生成独立的条目，使用正确的 record_type。`;
  }

  /** OCR 文本快速结构化：短 prompt，避免全量 getSystemPrompt 拖垮 Coding 模型 */
  private static getOcrTextSystemPrompt(currentDate: string): string {
    return `从 OCR/听写文本提取财务记录。今天=${currentDate}。只输出 JSON：
{"items":[{"temp_id":"1","record_type":"debt","parsed_fields":{"platform":"","debt_type":"installment","principal":0,"current_balance":0,"monthly_payment":0,"total_periods":0,"remaining_periods":0,"payment_day":null,"next_payment_date":null},"confidence":{},"is_complete":true}],"clarify_question":null,"is_complete":true}
金额为元。有「n/m期」「分期金额/本金」「剩余待还」「还款日」时：principal=分期本金，current_balance=剩余待还（勿混用）。不要 markdown。`
  }

  private static async callOpenAICompatible(url: string, key: string, model: string, text: string,
    fast: boolean = false): Promise<ParseResult> {
    const date = new Date()
    const year = date.getFullYear()
    const month = ('0' + (date.getMonth() + 1)).slice(-2)
    const day = ('0' + date.getDate()).slice(-2)
    const currentDate = `${year}-${month}-${day}`
    const modelName = model.length > 0 ? model : 'deepseek-v4-flash'
    let userText = text
    const maxUser = fast ? 3500 : 6000
    if (userText.length > maxUser) {
      userText = userText.substring(0, maxUser)
    }
    const systemPrompt = fast ?
      AIService.getOcrTextSystemPrompt(currentDate) :
      AIService.getSystemPrompt(currentDate)
    const maxTokens = fast ? 900 : 1536
    const readTimeout = fast ? 18000 : 25000
    const bodyStr = '{' +
      '"model":' + JSON.stringify(modelName) + ',' +
      '"messages":[' +
      '{"role":"system","content":' + JSON.stringify(systemPrompt) + '},' +
      '{"role":"user","content":' + JSON.stringify(userText) + '}' +
      '],' +
      '"max_tokens":' + maxTokens + ',' +
      '"response_format":{"type":"json_object"}' +
      '}'
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
          connectTimeout: 10000,
          readTimeout: readTimeout
        }
      )
      if (response.responseCode < 200 || response.responseCode >= 300) {
        const raw = response.result !== undefined && response.result !== null
          ? response.result.toString()
          : ''
        return AIService.failureResult('HTTP_ERROR_' + response.responseCode +
          AIService.safeErrSnippet(raw))
      }
      const rawResult = response.result !== undefined && response.result !== null
        ? response.result.toString()
        : ''
      if (rawResult.length === 0) {
        return AIService.failureResult('HTTP_EMPTY_BODY')
      }
      const content = AIService.extractAssistantContent(rawResult)
      if (content.length === 0) {
        return AIService.failureResult('HTTP_EMPTY_CONTENT')
      }
      return AIService.parseJson(content)
    } catch (err) {
      return AIService.failureResult('HTTP_EXCEPTION' + AIService.safeErrSnippet(
        AIService.describeCaughtError(err as Object)))
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

  private static parseJson(content: string): ParseResult {
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
      return result
    } catch (err) {
      // 禁止把模型原文写进错误码（可能含财务字段，且会进 rawContent 链路）
      const errBrief = err instanceof Error ? err.message : 'parse_error'
      return AIService.failureResult(
        'PARSING_EXCEPTION: ' + errBrief + ' | content_len=' + content.length
      )
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
