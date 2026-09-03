/**
 * debts 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { SyncIdKeys, SyncRs } from './SyncRs'

class DebtSyncRow {
  id: string = ''
  user_id: string = ''
  cloud_id: string = ''
  platform: string = ''
  platform_color: string = ''
  debt_type: string = ''
  principal: number = 0
  current_balance: number = 0
  monthly_payment: number = 0
  total_periods: number = 0
  remaining_periods: number = 0
  annual_rate_bp: number = 0
  payment_day: number = 1
  next_payment_date: string = ''
  start_date: string = ''
  estimated_end_date: string = ''
  is_auto_payment: number = 0
  status: string = 'active'
  note: string = ''
  created_at: string = ''
  updated_at: string = ''
  icon_url: string = ''
  credit_account_id: string = ''
  currency: string = 'CNY'
  original_principal_fen: number = 0
  locked_exchange_rate: number = 1.0
  repayment_method: string = 'equal_payment'
  total_interest: number = 0
}

class DebtCloudRecord {
  id: string = ''
  user_id: string = ''
  platform: string = ''
  platform_color: string = ''
  debt_type: string = ''
  principal: number = 0
  current_balance: number = 0
  monthly_payment: number = 0
  total_periods: number = 0
  remaining_periods: number = 0
  annual_rate_bp: number = 0
  payment_day: number = 1
  next_payment_date: string = ''
  start_date: string = ''
  estimated_end_date: string = ''
  is_auto_payment: boolean = false
  status: string = 'active'
  note: string = ''
  created_at: string = ''
  updated_at: string = ''
  icon_url: string = ''
  credit_account_id: string = ''
  currency: string = 'CNY'
  original_principal_fen: number = 0
  locked_exchange_rate: number = 1.0
  repayment_method: string = 'equal_payment'
  total_interest: number = 0
}

function resultSetToDebtRow(rs: relationalStore.ResultSet): DebtSyncRow {
  const row = new DebtSyncRow()
  row.id = SyncRs.readString(rs, 'id')
  row.user_id = SyncRs.readString(rs, 'user_id')
  row.cloud_id = SyncRs.readString(rs, 'cloud_id')
  row.platform = SyncRs.readString(rs, 'platform')
  row.platform_color = SyncRs.readString(rs, 'platform_color')
  row.debt_type = SyncRs.readString(rs, 'debt_type')
  row.principal = SyncRs.readNumber(rs, 'principal')
  row.current_balance = SyncRs.readNumber(rs, 'current_balance')
  row.monthly_payment = SyncRs.readNumber(rs, 'monthly_payment')
  row.total_periods = SyncRs.readNumber(rs, 'total_periods')
  row.remaining_periods = SyncRs.readNumber(rs, 'remaining_periods')
  row.annual_rate_bp = SyncRs.readNumber(rs, 'annual_rate_bp')
  row.payment_day = SyncRs.readNumber(rs, 'payment_day')
  row.next_payment_date = SyncRs.readString(rs, 'next_payment_date')
  row.start_date = SyncRs.readString(rs, 'start_date')
  row.estimated_end_date = SyncRs.readString(rs, 'estimated_end_date')
  row.is_auto_payment = SyncRs.readNumber(rs, 'is_auto_payment')
  row.status = SyncRs.readString(rs, 'status')
  row.note = SyncRs.readString(rs, 'note')
  row.created_at = SyncRs.readString(rs, 'created_at')
  row.updated_at = SyncRs.readString(rs, 'updated_at')
  row.icon_url = SyncRs.readString(rs, 'icon_url')
  row.credit_account_id = SyncRs.readString(rs, 'credit_account_id')
  row.currency = SyncRs.readCurrency(rs, 'currency')
  row.original_principal_fen = SyncRs.readNumber(rs, 'original_principal_fen')
  row.locked_exchange_rate = SyncRs.readRate(rs, 'locked_exchange_rate')
  row.repayment_method = SyncRs.readString(rs, 'repayment_method')
  if (row.repayment_method.length === 0) {
    row.repayment_method = 'equal_payment'
  }
  row.total_interest = SyncRs.readNumber(rs, 'total_interest')
  return row
}

export class DebtTableSync implements TableSync<DebtSyncRow> {
  readonly tableName: string = Constants.TABLE_DEBTS

  async getLocalRows(userId: string): Promise<DebtSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM debts WHERE user_id = ?', [userId])
    const rows: DebtSyncRow[] = []
    try {
      while (rs.goToNextRow()) {
        rows.push(resultSetToDebtRow(rs))
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

  toCloud(row: DebtSyncRow): object {
    const record = new DebtCloudRecord()
    record.id = row.cloud_id.length > 0 ? row.cloud_id : Utils.generateUuid()
    record.user_id = row.user_id
    record.platform = row.platform
    record.platform_color = row.platform_color
    record.debt_type = row.debt_type
    record.principal = row.principal
    record.current_balance = row.current_balance
    record.monthly_payment = row.monthly_payment
    record.total_periods = row.total_periods
    record.remaining_periods = row.remaining_periods
    record.annual_rate_bp = row.annual_rate_bp
    record.payment_day = row.payment_day
    record.next_payment_date = row.next_payment_date
    record.start_date = row.start_date
    record.estimated_end_date = row.estimated_end_date
    record.is_auto_payment = DbService.intToBool(row.is_auto_payment)
    record.status = row.status
    record.note = row.note
    record.created_at = row.created_at
    record.updated_at = row.updated_at.length > 0 ? row.updated_at : DbService.now()
    record.icon_url = row.icon_url
    record.credit_account_id = row.credit_account_id
    record.currency = row.currency
    record.original_principal_fen = row.original_principal_fen
    record.locked_exchange_rate = row.locked_exchange_rate
    record.repayment_method = row.repayment_method.length > 0 ? row.repayment_method : 'equal_payment'
    record.total_interest = row.total_interest
    return record
  }

  fromCloud(cloudRow: object): DebtSyncRow {
    const cloud = cloudRow as DebtCloudRecord
    const row = new DebtSyncRow()
    row.id = Utils.generateId()
    row.user_id = cloud.user_id
    row.cloud_id = cloud.id
    row.platform = cloud.platform
    row.platform_color = cloud.platform_color
    row.debt_type = cloud.debt_type
    row.principal = cloud.principal
    row.current_balance = cloud.current_balance
    row.monthly_payment = cloud.monthly_payment
    row.total_periods = cloud.total_periods
    row.remaining_periods = cloud.remaining_periods
    row.annual_rate_bp = cloud.annual_rate_bp
    row.payment_day = cloud.payment_day
    row.next_payment_date = cloud.next_payment_date
    row.start_date = cloud.start_date
    row.estimated_end_date = cloud.estimated_end_date
    row.is_auto_payment = DbService.boolToInt(cloud.is_auto_payment)
    row.status = cloud.status
    row.note = cloud.note
    row.created_at = cloud.created_at
    row.updated_at = cloud.updated_at
    row.icon_url = cloud.icon_url
    row.credit_account_id = cloud.credit_account_id ?? ''
    row.currency = (cloud.currency ?? '').length > 0 ? cloud.currency : 'CNY'
    row.original_principal_fen = cloud.original_principal_fen ?? 0
    row.locked_exchange_rate = (cloud.locked_exchange_rate ?? 0) > 0 ? cloud.locked_exchange_rate : 1.0
    row.repayment_method = (cloud.repayment_method ?? '').length > 0 ? cloud.repayment_method : 'equal_payment'
    row.total_interest = cloud.total_interest ?? 0
    return row
  }

  toMap(row: DebtSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', row.id)
    values.set('user_id', row.user_id)
    values.set('cloud_id', row.cloud_id)
    values.set('platform', row.platform)
    values.set('platform_color', row.platform_color)
    values.set('debt_type', row.debt_type)
    values.set('principal', row.principal)
    values.set('current_balance', row.current_balance)
    values.set('monthly_payment', row.monthly_payment)
    values.set('total_periods', row.total_periods)
    values.set('remaining_periods', row.remaining_periods)
    values.set('annual_rate_bp', row.annual_rate_bp)
    values.set('payment_day', row.payment_day)
    values.set('next_payment_date', row.next_payment_date)
    values.set('start_date', row.start_date)
    values.set('estimated_end_date', row.estimated_end_date)
    values.set('is_auto_payment', row.is_auto_payment)
    values.set('status', row.status)
    values.set('note', row.note)
    values.set('created_at', row.created_at)
    values.set('updated_at', row.updated_at)
    values.set('icon_url', row.icon_url)
    values.set('credit_account_id', row.credit_account_id)
    values.set('currency', row.currency)
    values.set('original_principal_fen', row.original_principal_fen)
    values.set('locked_exchange_rate', row.locked_exchange_rate)
    values.set('repayment_method', row.repayment_method)
    values.set('total_interest', row.total_interest)
    return values
  }

  getCloudId(row: DebtSyncRow): string {
    return row.cloud_id
  }

  setCloudId(row: DebtSyncRow, cloudId: string): void {
    row.cloud_id = cloudId
  }

  getUpdatedAt(row: DebtSyncRow): string {
    return row.updated_at
  }

  getLocalId(row: DebtSyncRow): string {
    return row.id
  }

  getLocalKeyColumn(): string {
    return SyncIdKeys.localKeyColumn()
  }

  getCloudRowId(cloudRow: object): string {
    return SyncIdKeys.cloudRowId(cloudRow)
  }
}
