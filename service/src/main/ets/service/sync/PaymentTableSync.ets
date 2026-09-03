/**
 * payment_records 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { SyncIdKeys, SyncRs } from './SyncRs'

class PaymentSyncRow {
  id: string = ''
  debt_id: string = ''
  user_id: string = ''
  cloud_id: string = ''
  period_number: number = 0
  payment_date: string = ''
  scheduled_date: string = ''
  amount_paid: number = 0
  principal_paid: number = 0
  interest_paid: number = 0
  balance_after: number = 0
  is_manual: number = 1
  created_at: string = ''
}

class PaymentCloudRecord {
  id: string = ''
  debt_id: string = ''
  user_id: string = ''
  period_number: number = 0
  payment_date: string = ''
  scheduled_date: string = ''
  amount_paid: number = 0
  principal_paid: number = 0
  interest_paid: number = 0
  balance_after: number = 0
  is_manual: boolean = true
  created_at: string = ''
}

function resultSetToPaymentRow(rs: relationalStore.ResultSet): PaymentSyncRow {
  const row = new PaymentSyncRow()
  row.id = SyncRs.readString(rs, 'id')
  row.debt_id = SyncRs.readString(rs, 'debt_id')
  row.user_id = SyncRs.readString(rs, 'user_id')
  row.cloud_id = SyncRs.readString(rs, 'cloud_id')
  row.period_number = SyncRs.readNumber(rs, 'period_number')
  row.payment_date = SyncRs.readString(rs, 'payment_date')
  row.scheduled_date = SyncRs.readString(rs, 'scheduled_date')
  row.amount_paid = SyncRs.readNumber(rs, 'amount_paid')
  row.principal_paid = SyncRs.readNumber(rs, 'principal_paid')
  row.interest_paid = SyncRs.readNumber(rs, 'interest_paid')
  row.balance_after = SyncRs.readNumber(rs, 'balance_after')
  row.is_manual = SyncRs.readNumber(rs, 'is_manual')
  row.created_at = SyncRs.readString(rs, 'created_at')
  return row
}

export class PaymentTableSync implements TableSync<PaymentSyncRow> {
  readonly tableName: string = Constants.TABLE_PAYMENT_RECORDS

  async getLocalRows(userId: string): Promise<PaymentSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM payment_records WHERE user_id = ?', [userId])
    const rows: PaymentSyncRow[] = []
    try {
      while (rs.goToNextRow()) {
        rows.push(resultSetToPaymentRow(rs))
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

  toCloud(row: PaymentSyncRow): object {
    const record = new PaymentCloudRecord()
    record.id = row.cloud_id.length > 0 ? row.cloud_id : Utils.generateUuid()
    record.debt_id = row.debt_id
    record.user_id = row.user_id
    record.period_number = row.period_number
    record.payment_date = row.payment_date
    record.scheduled_date = row.scheduled_date
    record.amount_paid = row.amount_paid
    record.principal_paid = row.principal_paid
    record.interest_paid = row.interest_paid
    record.balance_after = row.balance_after
    record.is_manual = DbService.intToBool(row.is_manual)
    record.created_at = row.created_at
    return record
  }

  fromCloud(cloudRow: object): PaymentSyncRow {
    const cloud = cloudRow as PaymentCloudRecord
    const row = new PaymentSyncRow()
    row.id = Utils.generateId()
    row.debt_id = cloud.debt_id
    row.user_id = cloud.user_id
    row.cloud_id = cloud.id
    row.period_number = cloud.period_number
    row.payment_date = cloud.payment_date
    row.scheduled_date = cloud.scheduled_date
    row.amount_paid = cloud.amount_paid
    row.principal_paid = cloud.principal_paid
    row.interest_paid = cloud.interest_paid
    row.balance_after = cloud.balance_after
    row.is_manual = DbService.boolToInt(cloud.is_manual)
    row.created_at = cloud.created_at
    return row
  }

  toMap(row: PaymentSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', row.id)
    values.set('debt_id', row.debt_id)
    values.set('user_id', row.user_id)
    values.set('cloud_id', row.cloud_id)
    values.set('period_number', row.period_number)
    values.set('payment_date', row.payment_date)
    values.set('scheduled_date', row.scheduled_date)
    values.set('amount_paid', row.amount_paid)
    values.set('principal_paid', row.principal_paid)
    values.set('interest_paid', row.interest_paid)
    values.set('balance_after', row.balance_after)
    values.set('is_manual', row.is_manual)
    values.set('created_at', row.created_at)
    return values
  }

  getCloudId(row: PaymentSyncRow): string {
    return row.cloud_id
  }

  setCloudId(row: PaymentSyncRow, cloudId: string): void {
    row.cloud_id = cloudId
  }

  getUpdatedAt(row: PaymentSyncRow): string {
    return row.created_at
  }

  getLocalId(row: PaymentSyncRow): string {
    return row.id
  }

  getLocalKeyColumn(): string {
    return SyncIdKeys.localKeyColumn()
  }

  getCloudRowId(cloudRow: object): string {
    return SyncIdKeys.cloudRowId(cloudRow)
  }
}
