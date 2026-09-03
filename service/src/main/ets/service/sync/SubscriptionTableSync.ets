/**
 * subscriptions 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { SyncIdKeys, SyncRs } from './SyncRs'

class SubscriptionSyncRow {
  id: string = ''
  user_id: string = ''
  cloud_id: string = ''
  name: string = ''
  category: string = ''
  amount: number = 0
  billing_cycle: string = ''
  next_billing_date: string = ''
  start_date: string = ''
  end_date: string = ''
  status: string = 'active'
  credit_account_id: string = ''
  color: string = ''
  icon_url: string = ''
  note: string = ''
  reminder_days_before: number = 3
  reminder_enabled: number = 1
  created_at: string = ''
  updated_at: string = ''
  currency: string = 'CNY'
  original_amount_fen: number = 0
  locked_exchange_rate: number = 1.0
}

class SubscriptionCloudRecord {
  id: string = ''
  user_id: string = ''
  name: string = ''
  category: string = ''
  amount: number = 0
  billing_cycle: string = ''
  next_billing_date: string = ''
  start_date: string = ''
  end_date: string = ''
  status: string = 'active'
  credit_account_id: string = ''
  color: string = ''
  icon_url: string = ''
  note: string = ''
  reminder_days_before: number = 3
  reminder_enabled: boolean = true
  created_at: string = ''
  updated_at: string = ''
  currency: string = 'CNY'
  original_amount_fen: number = 0
  locked_exchange_rate: number = 1.0
}

export class SubscriptionTableSync implements TableSync<SubscriptionSyncRow> {
  readonly tableName: string = Constants.TABLE_SUBSCRIPTIONS

  async getLocalRows(userId: string): Promise<SubscriptionSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM subscriptions WHERE user_id = ?', [userId])
    const rows: SubscriptionSyncRow[] = []
    try {
      while (rs.goToNextRow()) {
        const row = new SubscriptionSyncRow()
        row.id = SyncRs.readString(rs, 'id')
        row.user_id = SyncRs.readString(rs, 'user_id')
        row.cloud_id = SyncRs.readString(rs, 'cloud_id')
        row.name = SyncRs.readString(rs, 'name')
        row.category = SyncRs.readString(rs, 'category')
        row.amount = SyncRs.readNumber(rs, 'amount')
        row.billing_cycle = SyncRs.readString(rs, 'billing_cycle')
        row.next_billing_date = SyncRs.readString(rs, 'next_billing_date')
        row.start_date = SyncRs.readString(rs, 'start_date')
        row.end_date = SyncRs.readString(rs, 'end_date')
        row.status = SyncRs.readString(rs, 'status')
        row.credit_account_id = SyncRs.readString(rs, 'credit_account_id')
        row.color = SyncRs.readString(rs, 'color')
        row.icon_url = SyncRs.readString(rs, 'icon_url')
        row.note = SyncRs.readString(rs, 'note')
        row.reminder_days_before = SyncRs.readNumber(rs, 'reminder_days_before')
        row.reminder_enabled = SyncRs.readNumber(rs, 'reminder_enabled')
        row.created_at = SyncRs.readString(rs, 'created_at')
        row.updated_at = SyncRs.readString(rs, 'updated_at')
        row.currency = SyncRs.readCurrency(rs, 'currency')
        row.original_amount_fen = SyncRs.readNumber(rs, 'original_amount_fen')
        row.locked_exchange_rate = SyncRs.readRate(rs, 'locked_exchange_rate')
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

  toCloud(row: SubscriptionSyncRow): object {
    const record = new SubscriptionCloudRecord()
    record.id = row.cloud_id.length > 0 ? row.cloud_id : Utils.generateUuid()
    record.user_id = row.user_id
    record.name = row.name
    record.category = row.category
    record.amount = row.amount
    record.billing_cycle = row.billing_cycle
    record.next_billing_date = row.next_billing_date
    record.start_date = row.start_date
    record.end_date = row.end_date
    record.status = row.status
    record.credit_account_id = row.credit_account_id
    record.color = row.color
    record.icon_url = row.icon_url
    record.note = row.note
    record.reminder_days_before = row.reminder_days_before
    record.reminder_enabled = DbService.intToBool(row.reminder_enabled)
    record.created_at = row.created_at
    record.updated_at = row.updated_at.length > 0 ? row.updated_at : DbService.now()
    record.currency = row.currency
    record.original_amount_fen = row.original_amount_fen
    record.locked_exchange_rate = row.locked_exchange_rate
    return record
  }

  fromCloud(cloudRow: object): SubscriptionSyncRow {
    const cloud = cloudRow as SubscriptionCloudRecord
    const row = new SubscriptionSyncRow()
    row.id = Utils.generateId()
    row.user_id = cloud.user_id
    row.cloud_id = cloud.id
    row.name = cloud.name
    row.category = cloud.category
    row.amount = cloud.amount
    row.billing_cycle = cloud.billing_cycle
    row.next_billing_date = cloud.next_billing_date
    row.start_date = cloud.start_date
    row.end_date = cloud.end_date
    row.status = cloud.status
    row.credit_account_id = cloud.credit_account_id
    row.color = cloud.color
    row.icon_url = cloud.icon_url
    row.note = cloud.note
    row.reminder_days_before = cloud.reminder_days_before
    row.reminder_enabled = DbService.boolToInt(cloud.reminder_enabled)
    row.created_at = cloud.created_at
    row.updated_at = cloud.updated_at
    row.currency = (cloud.currency ?? '').length > 0 ? cloud.currency : 'CNY'
    row.original_amount_fen = cloud.original_amount_fen ?? 0
    row.locked_exchange_rate = (cloud.locked_exchange_rate ?? 0) > 0 ? cloud.locked_exchange_rate : 1.0
    return row
  }

  toMap(row: SubscriptionSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', row.id)
    values.set('user_id', row.user_id)
    values.set('cloud_id', row.cloud_id)
    values.set('name', row.name)
    values.set('category', row.category)
    values.set('amount', row.amount)
    values.set('billing_cycle', row.billing_cycle)
    values.set('next_billing_date', row.next_billing_date)
    values.set('start_date', row.start_date)
    values.set('end_date', row.end_date)
    values.set('status', row.status)
    values.set('credit_account_id', row.credit_account_id)
    values.set('color', row.color)
    values.set('icon_url', row.icon_url)
    values.set('note', row.note)
    values.set('reminder_days_before', row.reminder_days_before)
    values.set('reminder_enabled', row.reminder_enabled)
    values.set('created_at', row.created_at)
    values.set('updated_at', row.updated_at)
    values.set('currency', row.currency)
    values.set('original_amount_fen', row.original_amount_fen)
    values.set('locked_exchange_rate', row.locked_exchange_rate)
    return values
  }

  getCloudId(row: SubscriptionSyncRow): string { return row.cloud_id }
  setCloudId(row: SubscriptionSyncRow, cloudId: string): void { row.cloud_id = cloudId }
  getUpdatedAt(row: SubscriptionSyncRow): string { return row.updated_at }
  getLocalId(row: SubscriptionSyncRow): string { return row.id }

  getLocalKeyColumn(): string {
    return SyncIdKeys.localKeyColumn()
  }

  getCloudRowId(cloudRow: object): string {
    return SyncIdKeys.cloudRowId(cloudRow)
  }
}
