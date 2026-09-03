// E2EEService.mock.ets
// Mock preset: 透传（不加密），encrypt/decrypt 直接返回输入

export class E2EEService {
  static async initialize(): Promise<void> {
    // 空操作
  }

  static async encryptRecord(tableName: string, record: object): Promise<Record<string, string | number | boolean>> {
    return E2EEService.passthrough(record)
  }

  static async decryptRecord(tableName: string, record: object): Promise<Record<string, string | number | boolean>> {
    return E2EEService.passthrough(record)
  }

  private static passthrough(record: object): Record<string, string | number | boolean> {
    const result: Record<string, string | number | boolean> = {}
    const keys = Object.keys(record)
    for (const key of keys) {
      const value = (record as Record<string, string | number | boolean | null | undefined>)[key]
      if (value === undefined || value === null) {
        continue
      }
      result[key] = value
    }
    return result
  }
}
