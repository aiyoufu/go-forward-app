// UserService.mock.ets — entry 模块测试用
let currentUserId: string = 'test-user-001'

export class UserService {
  static getCurrentUserId(): string {
    return currentUserId
  }

  static async ensureDefaultUser(): Promise<string> {
    if (currentUserId.length === 0) {
      currentUserId = 'test-user-001'
    }
    return currentUserId
  }

  static _setUserId(id: string): void {
    currentUserId = id
  }

  static _reset(): void {
    currentUserId = 'test-user-001'
  }
}
