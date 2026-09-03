/**
 * credit_accounts 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { Logger } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { CryptoService } from '../auth/CryptoService'
import { SyncIdKeys, SyncRs } from './SyncRs'

class CreditAccountSyncRow {
  id: string = ''
  user_id: string = ''
  cloud_id: string = ''
  name: string = ''
  last_four: string = ''
  color: string = ''
  icon_url: string = ''
  expiry_date: string = ''
  cvv: string = ''
  bill_day: number = 1
  payment_day: number = 1
  annual_fee_required_swipes: number = 0
  annual_fee_manual_swipes: number = 0
  credit_limit: number = 0
  grace_period_days: number = 0
  interest_free_days: number = 0
  sort_order: number = 0
  created_at: string = ''
  updated_at: string = ''
}

class CreditAccountCloudRecord {
  id: string = ''
  user_id: string = ''
  name: string = ''
  last_four: string = ''
  color: string = ''
  icon_url: string = ''
  expiry_date: string = ''
  cvv: string = ''
  bill_day: number = 1
  payment_day: number = 1
  annual_fee_required_swipes: number = 0
  annual_fee_manual_swipes: number = 0
  credit_limit: number = 0
  grace_period_days: number = 0
  interest_free_days: number = 0
  sort_order: number = 0
  created_at: string = ''
  updated_at: string = ''
}

export class CreditAccountTableSync implements TableSync<CreditAccountSyncRow> {
  readonly tableName: string = Constants.TABLE_CREDIT_ACCOUNTS

  async getLocalRows(userId: string): Promise<CreditAccountSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM credit_accounts WHERE user_id = ?', [userId])
    const rows: CreditAccountSyncRow[] = []
    try {
      while (rs.goToNextRow()) {
        const row = new CreditAccountSyncRow()
        row.id = SyncRs.readString(rs, 'id')
        row.user_id = SyncRs.readString(rs, 'user_id')
        row.cloud_id = SyncRs.readString(rs, 'cloud_id')
        row.name = SyncRs.readString(rs, 'name')
        row.last_four = SyncRs.readString(rs, 'last_four')
        row.color = SyncRs.readString(rs, 'color')
        row.icon_url = SyncRs.readString(rs, 'icon_url')
        row.expiry_date = SyncRs.readString(rs, 'expiry_date')
        row.cvv = SyncRs.readString(rs, 'cvv')
        row.bill_day = SyncRs.readNumber(rs, 'bill_day')
        row.payment_day = SyncRs.readNumber(rs, 'payment_day')
        row.annual_fee_required_swipes = SyncRs.readNumber(rs, 'annual_fee_required_swipes')
        row.annual_fee_manual_swipes = SyncRs.readNumber(rs, 'annual_fee_manual_swipes')
        row.credit_limit = SyncRs.readNumber(rs, 'credit_limit')
        row.grace_period_days = SyncRs.readNumber(rs, 'grace_period_days')
        row.interest_free_days = SyncRs.readNumber(rs, 'interest_free_days')
        row.sort_order = SyncRs.readNumber(rs, 'sort_order')
        row.created_at = SyncRs.readString(rs, 'created_at')
        row.updated_at = SyncRs.readString(rs, 'updated_at')
        rows.push(row)
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return rows
  }

  toCloud(row: CreditAccountSyncRow): object {
    const record = new CreditAccountCloudRecord()
    record.id = row.cloud_id.length > 0 ? row.cloud_id : Utils.generateUuid()
    record.user_id = row.user_id
    record.name = row.name
    record.last_four = row.last_four
    record.color = row.color
    record.icon_url = row.icon_url
    record.expiry_date = row.expiry_date
    // 明文 CVV 禁止上云：仅 enc:v1 密文可出站
    if (row.cvv.length > 0 && !CryptoService.isEncryptedValue(row.cvv)) {
      Logger.warn('CreditAccountTableSync', '拒绝上云明文 CVV')
      record.cvv = ''
    } else {
      record.cvv = row.cvv
    }
    record.bill_day = row.bill_day
    record.payment_day = row.payment_day
    record.annual_fee_required_swipes = row.annual_fee_required_swipes
    record.annual_fee_manual_swipes = row.annual_fee_manual_swipes
    record.credit_limit = row.credit_limit
    record.grace_period_days = row.grace_period_days
    record.interest_free_days = row.interest_free_days
    record.sort_order = row.sort_order
    record.created_at = row.created_at
    record.updated_at = row.updated_at.length > 0 ? row.updated_at : DbService.now()
    return record
  }

  fromCloud(cloudRow: object): CreditAccountSyncRow {
    const cloud = cloudRow as CreditAccountCloudRecord
    const row = new CreditAccountSyncRow()
    row.id = Utils.generateId()
    row.user_id = cloud.user_id
    row.cloud_id = cloud.id
    row.name = cloud.name
    row.last_four = cloud.last_four
    row.color = cloud.color
    row.icon_url = cloud.icon_url
    row.expiry_date = cloud.expiry_date
    row.cvv = cloud.cvv
    row.bill_day = cloud.bill_day
    row.payment_day = cloud.payment_day
    row.annual_fee_required_swipes = cloud.annual_fee_required_swipes
    row.annual_fee_manual_swipes = cloud.annual_fee_manual_swipes
    row.credit_limit = cloud.credit_limit
    row.grace_period_days = cloud.grace_period_days
    row.interest_free_days = cloud.interest_free_days
    row.sort_order = cloud.sort_order
    row.created_at = cloud.created_at
    row.updated_at = cloud.updated_at
    return row
  }

  toMap(row: CreditAccountSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', row.id)
    values.set('user_id', row.user_id)
    values.set('cloud_id', row.cloud_id)
    values.set('name', row.name)
    values.set('last_four', row.last_four)
    values.set('color', row.color)
    values.set('icon_url', row.icon_url)
    values.set('expiry_date', row.expiry_date)
    values.set('cvv', row.cvv)
    values.set('bill_day', row.bill_day)
    values.set('payment_day', row.payment_day)
    values.set('annual_fee_required_swipes', row.annual_fee_required_swipes)
    values.set('annual_fee_manual_swipes', row.annual_fee_manual_swipes)
    values.set('credit_limit', row.credit_limit)
    values.set('grace_period_days', row.grace_period_days)
    values.set('interest_free_days', row.interest_free_days)
    values.set('sort_order', row.sort_order)
    values.set('created_at', row.created_at)
    values.set('updated_at', row.updated_at)
    return values
  }

  getCloudId(row: CreditAccountSyncRow): string { return row.cloud_id }
  setCloudId(row: CreditAccountSyncRow, cloudId: string): void { row.cloud_id = cloudId }
  getUpdatedAt(row: CreditAccountSyncRow): string { return row.updated_at }
  getLocalId(row: CreditAccountSyncRow): string { return row.id }

  getLocalKeyColumn(): string {
    return SyncIdKeys.localKeyColumn()
  }

  getCloudRowId(cloudRow: object): string {
    return SyncIdKeys.cloudRowId(cloudRow)
  }
}
