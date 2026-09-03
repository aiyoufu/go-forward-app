/**
 * 同步结果集通用读取工具（从 SyncTableAdapters 拆出）
 * 仅承载与具体表无关的 ResultSet 读取与标准 id 键约定；各表映射见同名 TableSync 文件
 */
import { relationalStore } from '@kit.ArkData'
import { SyncCloudRecord } from './SyncTypes'

/** 标准 id 主键表共用 */
export class SyncIdKeys {
  static localKeyColumn(): string {
    return 'id'
  }

  static cloudRowId(cloudRow: object): string {
    const rec = cloudRow as SyncCloudRecord
    if (rec.id !== undefined && rec.id !== null && ('' + rec.id).length > 0) {
      return '' + rec.id
    }
    return ''
  }
}

export class SyncRs {
  static readString(rs: relationalStore.ResultSet, column: string): string {
    try {
      return rs.getString(rs.getColumnIndex(column))
    } catch {
      return ''
    }
  }

  static readNumber(rs: relationalStore.ResultSet, column: string): number {
    try {
      return Number(rs.getString(rs.getColumnIndex(column)))
    } catch {
      return 0
    }
  }

  /** 币种：缺列或空值回退 CNY */
  static readCurrency(rs: relationalStore.ResultSet, column: string): string {
    const value = SyncRs.readString(rs, column)
    return value.length > 0 ? value : 'CNY'
  }

  /** 锁定汇率：缺列或非法值回退 1.0，避免除零与金额错乱 */
  static readRate(rs: relationalStore.ResultSet, column: string): number {
    const rate = SyncRs.readNumber(rs, column)
    return Number.isFinite(rate) && rate > 0 ? rate : 1.0
  }
}
