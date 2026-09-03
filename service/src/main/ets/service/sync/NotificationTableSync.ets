/**
 * notifications 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { SyncIdKeys, SyncRs } from './SyncRs'

class NotificationSyncRow {
  id: string = ''
  user_id: string = ''
  cloud_id: string = ''
  debt_id: string = ''
  subscription_id: string = ''
  reminder_type: string = ''
  title: string = ''
  body: string = ''
  is_read: number = 0
  sent_at: string = ''
  read_at: string = ''
}

class NotificationCloudRecord {
  id: string = ''
  user_id: string = ''
  debt_id: string = ''
  subscription_id: string = ''
  reminder_type: string = ''
  title: string = ''
  body: string = ''
  is_read: boolean = false
  sent_at: string = ''
  read_at: string = ''
}

export class NotificationTableSync implements TableSync<NotificationSyncRow> {
  readonly tableName: string = Constants.TABLE_NOTIFICATIONS

  async getLocalRows(userId: string): Promise<NotificationSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM notifications WHERE user_id = ?', [userId])
    const rows: NotificationSyncRow[] = []
    try {
      while (rs.goToNextRow()) {
        const row = new NotificationSyncRow()
        row.id = SyncRs.readString(rs, 'id')
        row.user_id = SyncRs.readString(rs, 'user_id')
        row.cloud_id = SyncRs.readString(rs, 'cloud_id')
        row.debt_id = SyncRs.readString(rs, 'debt_id')
        row.subscription_id = SyncRs.readString(rs, 'subscription_id')
        row.reminder_type = SyncRs.readString(rs, 'reminder_type')
        row.title = SyncRs.readString(rs, 'title')
        row.body = SyncRs.readString(rs, 'body')
        row.is_read = SyncRs.readNumber(rs, 'is_read')
        row.sent_at = SyncRs.readString(rs, 'sent_at')
        row.read_at = SyncRs.readString(rs, 'read_at')
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

  toCloud(row: NotificationSyncRow): object {
    const record = new NotificationCloudRecord()
    record.id = row.cloud_id.length > 0 ? row.cloud_id : Utils.generateUuid()
    record.user_id = row.user_id
    record.debt_id = row.debt_id
    record.subscription_id = row.subscription_id
    record.reminder_type = row.reminder_type
    record.title = row.title
    record.body = row.body
    record.is_read = DbService.intToBool(row.is_read)
    record.sent_at = row.sent_at
    record.read_at = row.read_at
    return record
  }

  fromCloud(cloudRow: object): NotificationSyncRow {
    const cloud = cloudRow as NotificationCloudRecord
    const row = new NotificationSyncRow()
    row.id = Utils.generateId()
    row.user_id = cloud.user_id
    row.cloud_id = cloud.id
    row.debt_id = cloud.debt_id
    row.subscription_id = cloud.subscription_id
    row.reminder_type = cloud.reminder_type
    row.title = cloud.title
    row.body = cloud.body
    row.is_read = DbService.boolToInt(cloud.is_read)
    row.sent_at = cloud.sent_at
    row.read_at = cloud.read_at
    return row
  }

  toMap(row: NotificationSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', row.id)
    values.set('user_id', row.user_id)
    values.set('cloud_id', row.cloud_id)
    values.set('debt_id', row.debt_id)
    values.set('subscription_id', row.subscription_id)
    values.set('reminder_type', row.reminder_type)
    values.set('title', row.title)
    values.set('body', row.body)
    values.set('is_read', row.is_read)
    values.set('sent_at', row.sent_at)
    values.set('read_at', row.read_at)
    return values
  }

  getCloudId(row: NotificationSyncRow): string { return row.cloud_id }
  setCloudId(row: NotificationSyncRow, cloudId: string): void { row.cloud_id = cloudId }
  getUpdatedAt(row: NotificationSyncRow): string { return row.sent_at }
  getLocalId(row: NotificationSyncRow): string { return row.id }

  getLocalKeyColumn(): string {
    return SyncIdKeys.localKeyColumn()
  }

  getCloudRowId(cloudRow: object): string {
    return SyncIdKeys.cloudRowId(cloudRow)
  }
}
