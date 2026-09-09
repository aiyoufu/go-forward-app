// 字段级加密门面：仅对「可重新录入」的凭证字段加解密（AI API Key、卡片 CVV），
// AES-256-GCM，DEK/KEK 模型，密文前缀 enc:v1:。
// 保留 initialize / encryptRecord / decryptRecord 签名，各业务 Service 调用点不动。
import { Constants } from 'common'
import { DekManager } from './DekManager'

export class E2EEService {
  static async initialize(): Promise<void> {
    // no-op：DEK 生命周期由 DekManager/AuthManager 管理
  }

  static async encryptRecord(tableName: string, record: object): Promise<Record<string, string | number | boolean>> {
    return E2EEService.transform(tableName, record, true)
  }

  static async decryptRecord(tableName: string, record: object): Promise<Record<string, string | number | boolean>> {
    return E2EEService.transform(tableName, record, false)
  }

  /** 表 → 敏感列；非敏感表返回空数组 */
  private static sensitiveColumns(tableName: string): string[] {
    if (tableName === Constants.TABLE_USER_SETTINGS) {
      return ['ai_text_key', 'ai_vision_key']
    }
    if (tableName === Constants.TABLE_CREDIT_ACCOUNTS) {
      return ['cvv']
    }
    return []
  }

  /** 对映射到的敏感列做加/解密，其余列原样透传 */
  private static async transform(tableName: string, record: object,
    encrypt: boolean): Promise<Record<string, string | number | boolean>> {
    const columns = E2EEService.sensitiveColumns(tableName)
    const result: Record<string, string | number | boolean> = {}
    const keys = Object.keys(record)
    for (const key of keys) {
      const value = (record as Record<string, string | number | boolean | null | undefined>)[key]
      if (value === undefined || value === null) {
        continue
      }
      if (columns.includes(key) && typeof value === 'string') {
        result[key] = encrypt ? await DekManager.encryptField(value) : await DekManager.decryptField(value)
      } else {
        result[key] = value
      }
    }
    return result
  }
}
