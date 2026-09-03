// PreferencesService.mock.ets
// Mock preset: 内存 Map 模拟持久化存储

const storage: Map<string, string | number | boolean> = new Map()

export class PreferencesService {
  static async init(context: Object): Promise<void> {
    // 空操作
  }

  static async putString(key: string, value: string): Promise<void> {
    storage.set(key, value)
  }

  static async getString(key: string, defaultValue: string = ''): Promise<string> {
    const v = storage.get(key)
    return typeof v === 'string' ? v : defaultValue
  }

  static async putNumber(key: string, value: number): Promise<void> {
    storage.set(key, value)
  }

  static async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    const v = storage.get(key)
    return typeof v === 'number' ? v : defaultValue
  }

  static async putBool(key: string, value: boolean): Promise<void> {
    storage.set(key, value)
  }

  static async getBool(key: string, defaultValue: boolean = false): Promise<boolean> {
    const v = storage.get(key)
    return typeof v === 'boolean' ? v : defaultValue
  }

  static async delete(key: string): Promise<void> {
    storage.delete(key)
  }

  // ---- 测试辅助方法 ----

  static _reset(): void {
    storage.clear()
  }

  static _getStore(): Map<string, string | number | boolean> {
    return storage
  }
}
