// AIService.mock.ets
// Mock preset: 预设解析结果

let presetParseResult: Object = {}

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

export class AIConnectionTestResult {
  ok: boolean = false
  message: string = ''
}

export class AIService {
  static async loadTextChannelConfig(userId?: string): Promise<Object> {
    return {
      enabled: true,
      key: 'mock-api-key',
      baseUrl: 'https://api.mock.com',
      model: 'mock-model',
      apiFormat: 'openai'
    }
  }

  static async loadVisionChannelConfig(userId?: string): Promise<Object> {
    return {
      enabled: true,
      key: 'mock-api-key',
      baseUrl: 'https://api.mock.com',
      model: 'mock-model',
      apiFormat: 'openai'
    }
  }

  static resolveChatCompletionsUrl(baseUrl: string): string {
    if (baseUrl.length === 0) {
      return 'https://api.openai.com/v1/chat/completions'
    }
    let u = baseUrl.trim()
    while (u.endsWith('/') && u.length > 1) {
      u = u.substring(0, u.length - 1)
    }
    if (u.endsWith('/chat/completions')) {
      return u
    }
    return u + '/chat/completions'
  }

  static async parseDebtText(text: string, config: Object): Promise<ParseResult> {
    return presetParseResult as ParseResult
  }

  static async parseDebtFromImage(jpegBase64: string, config: Object): Promise<ParseResult> {
    return presetParseResult as ParseResult
  }

  static async testConnection(key: string, baseUrl: string, model: string): Promise<boolean> {
    return true
  }

  static async testConnectionDetailed(key: string, baseUrl: string, model: string): Promise<AIConnectionTestResult> {
    const result = new AIConnectionTestResult()
    result.ok = true
    result.message = '连接成功'
    return result
  }

  static testResultToast(ok: boolean, message: string, okText: string, failText: string): string {
    if (ok) {
      return okText
    }
    if (message.length > 0) {
      return message
    }
    return failText
  }

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
    return '无法连接 ' + hostBit + '，请检查网络与 Base URL 后重试'
  }

  static hintFromCaughtError(err: Object | string | number | boolean | null | undefined,
    url: string): string {
    return AIService.networkFailureHint(AIService.describeCaughtError(err), url)
  }

  // ---- 测试辅助方法 ----

  static _setPresetParseResult(result: Object): void {
    presetParseResult = result
  }

  static _reset(): void {
    presetParseResult = {}
  }
}
