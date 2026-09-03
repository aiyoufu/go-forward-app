// AuthManager.mock.ets
// Mock preset: 可配置登录状态

let isLoggedInState: boolean = true
let isCloudMode: boolean = false
let cloudAccessToken: string = 'mock-access-token'

export type AuthMode = 'local' | 'cloud'

export class AuthState {
  mode: AuthMode = 'local'
  userId: string = 'test-user-001'
  email: string = 'local@goforward.app'
  accessToken: string = ''
  refreshToken: string = ''

  constructor(mode: AuthMode = 'local', userId: string = 'test-user-001', email: string = 'local@goforward.app',
    accessToken: string = '', refreshToken: string = '') {
    this.mode = mode
    this.userId = userId
    this.email = email
    this.accessToken = accessToken
    this.refreshToken = refreshToken
  }
}

export class AuthOperationResult {
  success: boolean = false
  error: string = ''

  constructor(success: boolean = false, error: string = '') {
    this.success = success
    this.error = error
  }
}

export class AuthManager {
  static readonly KEY_MODE: string = 'auth_mode'
  static readonly KEY_USER_ID: string = 'auth_user_id'
  static readonly KEY_EMAIL: string = 'auth_email'
  static readonly KEY_ACCESS_TOKEN: string = 'auth_access_token'
  static readonly KEY_REFRESH_TOKEN: string = 'auth_refresh_token'

  static async saveCloudSession(session: Object): Promise<void> {
    // 空操作
  }

  static async migrateUserData(oldUserId: string, newUserId: string): Promise<void> {
    // 空操作
  }

  static async saveLocalSession(userId: string): Promise<void> {
    // 空操作
  }

  static async loadSession(): Promise<AuthState | null> {
    if (!isLoggedInState) {
      return null
    }
    if (isCloudMode) {
      return new AuthState('cloud', 'test-user-001', 'cloud@goforward.app', cloudAccessToken, 'mock-refresh-token')
    }
    return new AuthState('local', 'test-user-001', 'local@goforward.app')
  }

  static async clearSession(): Promise<void> {
    isLoggedInState = false
  }

  static async signInCloud(email: string, password: string): Promise<AuthOperationResult> {
    return new AuthOperationResult(true, '')
  }

  static async signUpCloud(email: string, password: string): Promise<AuthOperationResult> {
    return new AuthOperationResult(true, '')
  }

  static async recoverPassword(email: string): Promise<AuthOperationResult> {
    return new AuthOperationResult(true, '')
  }

  static async resetPasswordWithCode(code: string, newPassword: string): Promise<AuthOperationResult> {
    return new AuthOperationResult(true, '')
  }

  static async signOut(): Promise<void> {
    isLoggedInState = false
  }

  static async refreshCloudSession(): Promise<AuthState | null> {
    if (!isLoggedInState) {
      return null
    }
    return new AuthState('cloud', 'test-user-001', 'local@goforward.app', 'mock-access-token', 'mock-refresh-token')
  }

  // ---- 测试辅助方法 ----

  static _setLoggedIn(value: boolean): void {
    isLoggedInState = value
  }

  static _setCloudMode(enabled: boolean, accessToken: string = 'mock-access-token'): void {
    isCloudMode = enabled
    cloudAccessToken = accessToken
  }

  static _reset(): void {
    isLoggedInState = true
    isCloudMode = false
    cloudAccessToken = 'mock-access-token'
  }
}
