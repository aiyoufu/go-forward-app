import { http } from '@kit.NetworkKit'
import { SupabaseConfig } from 'common'

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

export class SupabaseRestService {
  static async get(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    return SupabaseRestService.request(http.RequestMethod.GET, token, options)
  }

  static async post(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    return SupabaseRestService.request(http.RequestMethod.POST, token, options)
  }

  static async put(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    return SupabaseRestService.request(http.RequestMethod.PUT, token, options)
  }

  // PATCH 枚举自 SDK 26 才提供，当前兼容 SDK 为 24；直接用字符串字面量避免取到 undefined
  private static readonly METHOD_PATCH: http.RequestMethod = 'PATCH' as http.RequestMethod

  static async patch(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    return SupabaseRestService.request(SupabaseRestService.METHOD_PATCH, token, options)
  }

  static async delete(token: string, options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    return SupabaseRestService.request(http.RequestMethod.DELETE, token, options)
  }

  static buildUpsertOptions(table: string, records: object[]): SupabaseRestOptions {
    const options = new SupabaseRestOptions(table)
    options.body = records
    // PostgREST Prefer 完整值（不要再拼 return= 前缀）
    options.preferReturn = 'resolution=merge-duplicates,return=representation'
    return options
  }

  private static async request(method: http.RequestMethod, token: string,
    options: SupabaseRestOptions): Promise<SupabaseRestResponse> {
    if (!SupabaseConfig.isConfigured()) {
      return new SupabaseRestResponse(0, [], 'Supabase 未配置')
    }

    const httpRequest = http.createHttp()
    const url = SupabaseConfig.URL + '/rest/v1/' + options.table + SupabaseRestService.buildQuery(options)

    const isMutating = method === http.RequestMethod.POST || method === http.RequestMethod.PUT ||
      method === SupabaseRestService.METHOD_PATCH || method === http.RequestMethod.DELETE
    // Prefer 直接使用完整头，避免 return=return=... 错误
    const preferHeader = options.preferReturn.indexOf('return=') >= 0
      ? options.preferReturn
      : ('return=' + options.preferReturn)

    // DELETE/无 body 时不要塞 extraData:''：部分运行时会带 Content-Length:0 + JSON
    // 导致网关/服务异常；有 body 的 POST/PATCH 才写 extraData
    const headers: Record<string, string> = {
      'apikey': SupabaseConfig.ANON_KEY,
      'Authorization': 'Bearer ' + token,
      'Content-Type': 'application/json'
    }
    if (isMutating) {
      headers['Prefer'] = preferHeader
    }
    const requestOptions: http.HttpRequestOptions = {
      method: method,
      header: headers,
      connectTimeout: 10000,
      readTimeout: 15000
    }
    if (options.body !== null) {
      requestOptions.extraData = JSON.stringify(options.body)
    }

    try {
      const response = await httpRequest.request(url, requestOptions)
      const resultText = typeof response.result === 'string' ? response.result : ''
      const parsed = SupabaseRestService.parseArray(resultText)
      let error = ''
      if (response.responseCode < 200 || response.responseCode >= 300) {
        error = SupabaseRestService.pickError(parsed)
        if (error === '请求失败' && resultText.length > 0) {
          error = 'HTTP ' + response.responseCode + ': ' + resultText.substring(0, 120)
        } else if (error === '请求失败') {
          error = 'HTTP ' + response.responseCode
        }
      }
      httpRequest.destroy()
      return new SupabaseRestResponse(response.responseCode, parsed, error)
    } catch (err) {
      httpRequest.destroy()
      const message = err instanceof Error ? err.message : JSON.stringify(err)
      return new SupabaseRestResponse(0, [], '网络请求失败: ' + message)
    }
  }

  private static buildQuery(options: SupabaseRestOptions): string {
    const parts: string[] = []
    parts.push('select=' + encodeURIComponent(options.select))

    const keys = options.filters.keys()
    for (const key of keys) {
      const value = options.filters.get(key)
      if (value !== undefined) {
        parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value))
      }
    }

    return '?' + parts.join('&')
  }

  private static parseArray(jsonText: string): object[] {
    if (jsonText.length === 0) {
      return []
    }

    let parsed: object | object[] | null = null
    try {
      parsed = JSON.parse(jsonText)
    } catch {
      return []
    }

    if (parsed === null) {
      return []
    }

    if (Array.isArray(parsed)) {
      return parsed
    }

    return [parsed as object]
  }

  private static pickError(items: object[]): string {
    if (items.length === 0) {
      return '请求失败'
    }
    const first = items[0] as Record<string, string>
    return first['message'] ?? first['error'] ?? '请求失败'
  }
}
