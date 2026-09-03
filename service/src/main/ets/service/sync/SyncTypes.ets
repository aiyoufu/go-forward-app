/**
 * 同步公共类型（S4 从 SyncService 拆出）
 */
export class SyncStats {
  pulled: number = 0
  pushed: number = 0
  failed: number = 0
  table: string = ''

  constructor(table: string = '') {
    this.table = table
  }
}

export class SyncResult {
  success: boolean = false
  message: string = ''
  stats: SyncStats[] = []

  constructor(success: boolean = false, message: string = '', stats: SyncStats[] = []) {
    this.success = success
    this.message = message
    this.stats = stats
  }
}

export interface TableSync<T extends object> {
  readonly tableName: string

  getLocalRows(userId: string): Promise<T[]>

  toCloud(row: T): object

  fromCloud(cloudRow: object): T

  toMap(row: T): Map<string, string | number | boolean>

  getCloudId(row: T): string

  setCloudId(row: T, cloudId: string): void

  getUpdatedAt(row: T): string

  getLocalId(row: T): string

  /**
   * 本地主键列名。默认 id；user_settings 为 user_id。
   */
  getLocalKeyColumn(): string

  /**
   * 从云行解析业务主键（云端 id，或 settings 的 user_id）。
   */
  getCloudRowId(cloudRow: object): string
}

export class SyncCloudRecord {
  id: string = ''
  user_id: string = ''
  updated_at: string = ''
  created_at: string = ''
}
