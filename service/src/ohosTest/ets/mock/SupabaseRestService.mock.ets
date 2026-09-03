// SupabaseRestService.mock.ets
// Mock preset: 预设 JSON 响应 + 请求记录；支持按调用顺序的响应队列（多步 API）

const requestLog: { method: string; token: string; options: Object }[] = []
let presetResponse: Object[] = []
let presetStatus: number = 200
let presetError: string = ''

export class SupabaseRestOptions {
  table: string = ''
  select: string = '*'
  filters: Map<string, string> = new Map<string, string>()
  body: object | null = null
  preferReturn: string = 'representation'

  constructor(table: string = '') {
    this.table = table
  }
}

export class SupabaseRestResponse {
  status: number = 0
  data: object[] = []
  error: string = ''

  constructor(status: number = 0, data: object[] = [], error: string = '') {
    this.status = status
    this.data = data
    this.error = error
  }
}

/** 按 FIFO 消费；空则回落 preset* */
let responseQueue: SupabaseRestResponse[] = []

function takeResponse(): SupabaseRestResponse {
  if (responseQueue.length > 0) {
    const next = responseQueue.shift()
    if (next !== undefined) {
      return next
    }
  }
  return new SupabaseRestResponse(presetStatus, presetResponse, presetError)
}

export class SupabaseRestService {
  static async get(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    requestLog.push({ method: 'GET', token, options })
    return takeResponse()
  }

  static async post(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    requestLog.push({ method: 'POST', token, options })
    return takeResponse()
  }

  static async put(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    requestLog.push({ method: 'PUT', token, options })
    return takeResponse()
  }

  static async patch(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    requestLog.push({ method: 'PATCH', token, options })
    return takeResponse()
  }

  static async delete(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    requestLog.push({ method: 'DELETE', token, options })
    return takeResponse()
  }

  static buildUpsertOptions(table: string, records: object[]): SupabaseRestOptions {
    const options = new SupabaseRestOptions(table)
    options.body = records
    options.preferReturn = 'resolution=merge-duplicates,return=representation'
    return options
  }

  // ---- 测试辅助方法 ----

  static _setPresetResponse(data: object[], status: number = 200, error: string = ''): void {
    presetResponse = data
    presetStatus = status
    presetError = error
    responseQueue = []
  }

  /** 入队一次响应（多步流程：先 GET 再 POST 等） */
  static _enqueueResponse(data: object[], status: number = 200, error: string = ''): void {
    responseQueue.push(new SupabaseRestResponse(status, data, error))
  }

  static _getRequestLog(): { method: string; token: string; options: Object }[] {
    return requestLog
  }

  static _reset(): void {
    requestLog.length = 0
    presetResponse = []
    presetStatus = 200
    presetError = ''
    responseQueue = []
  }
}
