// UserService.mock.ets
// Mock preset: 预设用户

let currentUserId: string = 'test-user-001'

export class LocalUser {
  id: string = 'test-user-001'
  email: string = 'local@goforward.app'
  passwordHash: string = 'mock-hash'
  recoveryKeyEncrypted: string = ''
  createdAt: string = '2024-11-14T10:00:00.000Z'
  updatedAt: string = '2024-11-14T10:00:00.000Z'
}

export class UserService {
  static getCurrentUserId(): string {
    return currentUserId
  }

  static setCurrentUserId(id: string): void {
    currentUserId = id
  }

  static isLoggedIn(): boolean {
    return currentUserId.length > 0
  }

  static async createLocalUser(email: string, password: string): Promise<LocalUser> {
    const user = new LocalUser()
    user.id = 'test-user-new'
    user.email = email
    return user
  }

  static async authenticateLocalUser(email: string, password: string): Promise<LocalUser | null> {
    const user = new LocalUser()
    user.email = email
    return user
  }

  static async getLocalUserById(id: string): Promise<LocalUser | null> {
    const user = new LocalUser()
    user.id = id
    return user
  }

  static async ensureDefaultUser(): Promise<string> {
    if (currentUserId.length === 0) {
      currentUserId = 'test-user-001'
    }
    return currentUserId
  }

  static async ensureCloudUser(userId: string, email: string): Promise<void> {
    currentUserId = userId
  }

  // ---- 测试辅助方法 ----

  static _reset(): void {
    currentUserId = 'test-user-001'
  }
}
