import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { SupabaseConfig } from 'common'

export class AuthSession {
  accessToken: string = ''
  refreshToken: string = ''
  userId: string = ''
  email: string = ''

  constructor(accessToken: string = '', refreshToken: string = '', userId: string = '',
    email: string = '') {
    this.accessToken = accessToken
    this.refreshToken = refreshToken
    this.userId = userId
    this.email = email
  }
}

export class AuthUserProfile {
  nickname: string = ''
  avatar_data_url: string = ''
}

export class AuthResult {
  success: boolean = false
  session: AuthSession = new AuthSession()
  error: string = ''
  /** 服务端明确拒绝凭据（HTTP 4xx，非网络错误）：会话已被吊销，如他端改密 */
  sessionRevoked: boolean = false
  profile: AuthUserProfile = new AuthUserProfile()

  constructor(success: boolean = false, session: AuthSession = new AuthSession(), error: string = '') {
    this.success = success
    this.session = session
    this.error = error
  }
}

export class SupabaseAuthUser {
  id: string = ''
  email: string = ''
}

export class SupabaseAuthResponse {
  access_token: string = ''
  refresh_token: string = ''
  user: SupabaseAuthUser = new SupabaseAuthUser()
  error: string = ''
  error_description: string = ''
  message: string = ''
  msg: string = ''
  /** HTTP 状态码；0 = 未收到服务端响应（网络错误） */
  status: number = 0
  profile: AuthUserProfile = new AuthUserProfile()
}

export class SignInRequest {
  email: string = ''
  password: string = ''

  constructor(email: string, password: string) {
    this.email = email
    this.password = password
  }
}

export class SignUpRequest {
  email: string = ''
  password: string = ''

  constructor(email: string, password: string) {
    this.email = email
    this.password = password
  }
}

export class RecoverRequest {
  email: string = ''

  constructor(email: string) {
    this.email = email
  }
}

export class RefreshTokenRequest {
  refresh_token: string = ''

  constructor(refreshToken: string) {
    this.refresh_token = refreshToken
  }
}

export class UpdatePasswordRequest {
  password: string = ''

  constructor(password: string) {
    this.password = password
  }
}

export class VerifyRecoveryRequest {
  type: string = 'recovery'
  token: string = ''

  constructor(token: string) {
    this.token = token
  }
}

export class SupabaseAuthService {
  static async signIn(email: string, password: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置，请在 SupabaseConfig.ets 中填写 URL 和 ANON_KEY')
    }

    const request = new SignInRequest(email, password)
    const response = await SupabaseAuthService.post('/auth/v1/token?grant_type=password', request)

    if (response.access_token.length > 0) {
      const session = new AuthSession(response.access_token, response.refresh_token,
        response.user.id, response.user.email.length > 0 ? response.user.email : email)
      return new AuthResult(true, session, '')
    }

    const msg = SupabaseAuthService.pickError(response)
    return new AuthResult(false, new AuthSession(), msg)
  }

  static async signUp(email: string, password: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置，请在 SupabaseConfig.ets 中填写 URL 和 ANON_KEY')
    }

    const request = new SignUpRequest(email, password)
    const response = await SupabaseAuthService.post('/auth/v1/signup', request)

    if (response.access_token.length > 0) {
      const session = new AuthSession(response.access_token, response.refresh_token,
        response.user.id, response.user.email.length > 0 ? response.user.email : email)
      return new AuthResult(true, session, '')
    }

    const msg = SupabaseAuthService.pickError(response)
    return new AuthResult(false, new AuthSession(), msg)
  }

  static async recover(email: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置')
    }

    const request = new RecoverRequest(email)
    const response = await SupabaseAuthService.post('/auth/v1/recover', request)

    // GoTrue /recover 成功返回 2xx（响应体为空对象，无 error 字段）；网络错误 status=0、
    // 限流/参数错误为 4xx 时响应体常只带 msg，故必须按 HTTP 状态码判定，不能凭 error 字段是否为空
    if (response.status >= 200 && response.status < 300) {
      return new AuthResult(true, new AuthSession(), '')
    }

    const msg = SupabaseAuthService.pickError(response)
    return new AuthResult(false, new AuthSession(), msg)
  }

  static async verifyRecovery(token: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置')
    }
    const request = new VerifyRecoveryRequest(token)
    const response = await SupabaseAuthService.post('/auth/v1/verify', request)
    if (response.access_token.length > 0) {
      const session = new AuthSession(response.access_token, response.refresh_token,
        response.user.id, response.user.email)
      return new AuthResult(true, session, '')
    }
    const msg = SupabaseAuthService.pickError(response)
    return new AuthResult(false, new AuthSession(), msg)
  }

  /**
   * 登录态修改账户密码：PUT /auth/v1/user，需 Bearer access token。
   * GoTrue 成功响应是用户对象（无 error 字段），失败带 msg/error_description。
   */
  static async updateUser(accessToken: string, newPassword: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置')
    }
    const body = new UpdatePasswordRequest(newPassword)
    const response = await SupabaseAuthService.put('/auth/v1/user', body, accessToken)
    const hasError = response.error.length > 0 || response.error_description.length > 0 ||
      response.message.length > 0 || response.msg.length > 0
    if (!hasError) {
      return new AuthResult(true, new AuthSession(), '')
    }
    return new AuthResult(false, new AuthSession(), SupabaseAuthService.pickError(response))
  }

  /** 更新昵称（写入 auth user_metadata.nickname，与 Web 端同源） */
  static async updateUserNickname(accessToken: string, nickname: string): Promise<AuthResult> {
    return SupabaseAuthService.putUserData(accessToken, '{"data":{"nickname":' + JSON.stringify(nickname) + '}}')
  }

  /** 更新头像 dataURL（写入 auth user_metadata.avatar_data_url，与 Web 端同源） */
  static async updateUserAvatar(accessToken: string, avatarDataUrl: string): Promise<AuthResult> {
    return SupabaseAuthService.putUserData(accessToken,
      '{"data":{"avatar_data_url":' + JSON.stringify(avatarDataUrl) + '}}')
  }

  private static async putUserData(accessToken: string, jsonBody: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置')
    }
    const httpRequest = http.createHttp()
    const url = SupabaseConfig.URL + '/auth/v1/user'
    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: {
          'apikey': SupabaseConfig.ANON_KEY,
          'Authorization': 'Bearer ' + accessToken,
          'Content-Type': 'application/json'
        },
        extraData: jsonBody,
        connectTimeout: 20000,
        readTimeout: 30000
      })
      const resultText = typeof response.result === 'string' ? response.result : ''
      const parsed = SupabaseAuthService.parseJson(resultText)
      parsed.status = response.responseCode
      httpRequest.destroy()
      const hasError = parsed.error.length > 0 || parsed.error_description.length > 0 ||
        parsed.message.length > 0 || parsed.msg.length > 0
      if (response.responseCode >= 200 && response.responseCode < 300 && !hasError) {
        const ok = new AuthResult(true, new AuthSession(), '')
        ok.profile = parsed.profile
        return ok
      }
      return new AuthResult(false, new AuthSession(), SupabaseAuthService.pickError(parsed))
    } catch (err) {
      httpRequest.destroy()
      const error = err as BusinessError
      return new AuthResult(false, new AuthSession(),
        error.message.length > 0 ? error.message : '网络请求失败')
    }
  }

  /**
   * 从 GoTrue 用户 JSON 取出 nickname / avatar_data_url。
   * 兼容 token 响应（user.user_metadata）与 GET /auth/v1/user（顶层 user_metadata）。
   */
  static parseUserMetadata(jsonText: string): AuthUserProfile {
    const out = new AuthUserProfile()
    if (jsonText.length === 0) {
      return out
    }
    try {
      const root = JSON.parse(jsonText) as Record<string, Object>
      SupabaseAuthService.fillProfileFromMeta(out, root['user_metadata'])
      const nested = root['user']
      if (nested !== undefined && nested !== null && typeof nested === 'object') {
        const userObj = nested as Record<string, Object>
        SupabaseAuthService.fillProfileFromMeta(out, userObj['user_metadata'])
      }
    } catch (_e) {
    }
    return out
  }

  private static fillProfileFromMeta(out: AuthUserProfile, raw: Object | undefined): void {
    if (raw === undefined || raw === null || typeof raw !== 'object') {
      return
    }
    const meta = raw as Record<string, string>
    const nick = meta['nickname']
    if (typeof nick === 'string') {
      out.nickname = nick
    }
    const avatar = meta['avatar_data_url']
    if (typeof avatar === 'string') {
      out.avatar_data_url = avatar
    }
  }

  /** 用 refresh_token 换新的 access_token（JWT 过期时） */
  static async refresh(refreshToken: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置')
    }
    if (refreshToken.length === 0) {
      return new AuthResult(false, new AuthSession(), '无刷新令牌')
    }
    const body = new RefreshTokenRequest(refreshToken)
    const response = await SupabaseAuthService.post('/auth/v1/token?grant_type=refresh_token', body)
    if (response.access_token.length > 0) {
      const session = new AuthSession(
        response.access_token,
        response.refresh_token.length > 0 ? response.refresh_token : refreshToken,
        response.user.id,
        response.user.email
      )
      return new AuthResult(true, session, '')
    }
    const msg = SupabaseAuthService.pickError(response)
    const result = new AuthResult(false, new AuthSession(), msg.length > 0 ? msg : '登录已过期')
    // 400/401/403 = GoTrue 明确拒绝刷新令牌（已被他端改密吊销等）；网络错误 0 / 限流 429 不算
    result.sessionRevoked = response.status === 400 || response.status === 401 || response.status === 403
    return result
  }

  /**
   * 校验当前 access token 对应的会话是否仍有效：GET /auth/v1/user。
   * GoTrue 会检查 session_id，他端改密吊销后即使 JWT 未过期也返回 401/403。
   */
  static async getUser(accessToken: string): Promise<AuthResult> {
    if (!SupabaseConfig.isConfigured()) {
      return new AuthResult(false, new AuthSession(), 'Supabase 未配置')
    }
    const response = await SupabaseAuthService.get('/auth/v1/user', accessToken)
    if (response.status === 200) {
      const ok = new AuthResult(true, new AuthSession(), '')
      ok.profile = response.profile
      return ok
    }
    const result = new AuthResult(false, new AuthSession(), SupabaseAuthService.pickError(response))
    result.sessionRevoked = response.status === 401 || response.status === 403
    return result
  }

  private static pickError(response: SupabaseAuthResponse): string {
    if (response.error_description.length > 0) {
      return response.error_description
    }
    if (response.message.length > 0) {
      return response.message
    }
    if (response.msg.length > 0) {
      return response.msg
    }
    if (response.error.length > 0) {
      return response.error
    }
    return '请求失败'
  }

  private static async post(path: string, body: object): Promise<SupabaseAuthResponse> {
    const httpRequest = http.createHttp()
    const url = SupabaseConfig.URL + path

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.POST,
        header: {
          'apikey': SupabaseConfig.ANON_KEY,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 20000,
        readTimeout: 30000
      })

      const resultText = typeof response.result === 'string' ? response.result : ''
      const parsed = SupabaseAuthService.parseJson(resultText)
      parsed.status = response.responseCode
      httpRequest.destroy()
      return parsed
    } catch (err) {
      httpRequest.destroy()
      const error = err as BusinessError
      const resp = new SupabaseAuthResponse()
      resp.message = error.message.length > 0 ? error.message : '网络请求失败'
      return resp
    }
  }

  private static async get(path: string, accessToken: string): Promise<SupabaseAuthResponse> {
    const httpRequest = http.createHttp()
    const url = SupabaseConfig.URL + path

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.GET,
        header: {
          'apikey': SupabaseConfig.ANON_KEY,
          'Authorization': 'Bearer ' + accessToken
        },
        connectTimeout: 20000,
        readTimeout: 30000
      })

      const resultText = typeof response.result === 'string' ? response.result : ''
      const parsed = SupabaseAuthService.parseJson(resultText)
      parsed.status = response.responseCode
      httpRequest.destroy()
      return parsed
    } catch (err) {
      httpRequest.destroy()
      const error = err as BusinessError
      const resp = new SupabaseAuthResponse()
      resp.message = error.message.length > 0 ? error.message : '网络请求失败'
      return resp
    }
  }

  private static async put(path: string, body: object, accessToken: string): Promise<SupabaseAuthResponse> {
    const httpRequest = http.createHttp()
    const url = SupabaseConfig.URL + path

    try {
      const response = await httpRequest.request(url, {
        method: http.RequestMethod.PUT,
        header: {
          'apikey': SupabaseConfig.ANON_KEY,
          'Authorization': 'Bearer ' + accessToken,
          'Content-Type': 'application/json'
        },
        extraData: JSON.stringify(body),
        connectTimeout: 20000,
        readTimeout: 30000
      })

      const resultText = typeof response.result === 'string' ? response.result : ''
      const parsed = SupabaseAuthService.parseJson(resultText)
      httpRequest.destroy()
      return parsed
    } catch (err) {
      httpRequest.destroy()
      const error = err as BusinessError
      const resp = new SupabaseAuthResponse()
      resp.message = error.message.length > 0 ? error.message : '网络请求失败'
      return resp
    }
  }

  private static parseJson(jsonText: string): SupabaseAuthResponse {
    const empty = new SupabaseAuthResponse()
    if (jsonText.length === 0) {
      return empty
    }

    let parsed: SupabaseAuthResponse | null = null
    try {
      parsed = JSON.parse(jsonText)
    } catch {
      return empty
    }

    if (parsed === null) {
      return empty
    }

    const response = new SupabaseAuthResponse()
    // 字段归一化防 undefined：PUT /auth/v1/user 成功响应是顶层用户对象，无下列字段
    response.access_token = '' + (parsed.access_token ?? '')
    response.refresh_token = '' + (parsed.refresh_token ?? '')
    response.user = parsed.user ? parsed.user : new SupabaseAuthUser()
    response.error = '' + (parsed.error ?? '')
    response.error_description = '' + (parsed.error_description ?? '')
    response.message = '' + (parsed.message ?? '')
    response.msg = '' + (parsed.msg ?? '')
    response.profile = SupabaseAuthService.parseUserMetadata(jsonText)
    return response
  }
}
