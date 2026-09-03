// AuthManager.mock.ets — entry 模块测试用
let isLoggedInState: boolean = true

export class AuthState {
  mode: string = 'local'
  userId: string = 'test-user-001'
  email: string = 'local@goforward.app'
  accessToken: string = ''
  refreshToken: string = ''
}

export class AuthManager {
  static async loadSession(): Promise<AuthState | null> {
    if (!isLoggedInState) return null
    return new AuthState()
  }

  static _setLoggedIn(value: boolean): void {
    isLoggedInState = value
  }

  static _reset(): void {
    isLoggedInState = true
  }
}
