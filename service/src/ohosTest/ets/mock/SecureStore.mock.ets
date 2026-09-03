// SecureStore.mock.ets
// Mock preset: 内存 Map 模拟加密存储

const storage: Map<string, string> = new Map()

export class SecureStore {
  static async putString(alias: string, value: string): Promise<void> {
    if (value.length === 0) {
      storage.delete(alias)
      return
    }
    storage.set(alias, value)
  }

  static async getString(alias: string): Promise<string> {
    return storage.get(alias) || ''
  }

  static async remove(alias: string): Promise<void> {
    storage.delete(alias)
  }

  // ---- 测试辅助方法 ----

  static _reset(): void {
    storage.clear()
  }

  static _getStore(): Map<string, string> {
    return storage
  }
}
