/**
 * achievement_cards 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { SyncIdKeys, SyncRs } from './SyncRs'

class AchievementSyncRow {
  id: string = ''
  user_id: string = ''
  cloud_id: string = ''
  debt_id: string = ''
  platform: string = ''
  total_paid: number = 0
  total_interest: number = 0
  duration_days: number = 0
  completed_at: string = ''
  card_data: string = ''
  created_at: string = ''
}

class AchievementCloudRecord {
  id: string = ''
  user_id: string = ''
  debt_id: string = ''
  platform: string = ''
  total_paid: number = 0
  total_interest: number = 0
  duration_days: number = 0
  completed_at: string = ''
  card_data: string = ''
  created_at: string = ''
}

export class AchievementTableSync implements TableSync<AchievementSyncRow> {
  readonly tableName: string = Constants.TABLE_ACHIEVEMENT_CARDS

  async getLocalRows(userId: string): Promise<AchievementSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM achievement_cards WHERE user_id = ?', [userId])
    const rows: AchievementSyncRow[] = []
    try {
      while (rs.goToNextRow()) {
        const row = new AchievementSyncRow()
        row.id = SyncRs.readString(rs, 'id')
        row.user_id = SyncRs.readString(rs, 'user_id')
        row.cloud_id = SyncRs.readString(rs, 'cloud_id')
        row.debt_id = SyncRs.readString(rs, 'debt_id')
        row.platform = SyncRs.readString(rs, 'platform')
        row.total_paid = SyncRs.readNumber(rs, 'total_paid')
        row.total_interest = SyncRs.readNumber(rs, 'total_interest')
        row.duration_days = SyncRs.readNumber(rs, 'duration_days')
        row.completed_at = SyncRs.readString(rs, 'completed_at')
        row.card_data = SyncRs.readString(rs, 'card_data')
        row.created_at = SyncRs.readString(rs, 'created_at')
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

  toCloud(row: AchievementSyncRow): object {
    const record = new AchievementCloudRecord()
    record.id = row.cloud_id.length > 0 ? row.cloud_id : Utils.generateUuid()
    record.user_id = row.user_id
    record.debt_id = row.debt_id
    record.platform = row.platform
    record.total_paid = row.total_paid
    record.total_interest = row.total_interest
    record.duration_days = row.duration_days
    record.completed_at = row.completed_at
    record.card_data = row.card_data
    record.created_at = row.created_at
    return record
  }

  fromCloud(cloudRow: object): AchievementSyncRow {
    const cloud = cloudRow as AchievementCloudRecord
    const row = new AchievementSyncRow()
    row.id = Utils.generateId()
    row.user_id = cloud.user_id
    row.cloud_id = cloud.id
    row.debt_id = cloud.debt_id
    row.platform = cloud.platform
    row.total_paid = cloud.total_paid
    row.total_interest = cloud.total_interest
    row.duration_days = cloud.duration_days
    row.completed_at = cloud.completed_at
    row.card_data = cloud.card_data
    row.created_at = cloud.created_at
    return row
  }

  toMap(row: AchievementSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', row.id)
    values.set('user_id', row.user_id)
    values.set('cloud_id', row.cloud_id)
    values.set('debt_id', row.debt_id)
    values.set('platform', row.platform)
    values.set('total_paid', row.total_paid)
    values.set('total_interest', row.total_interest)
    values.set('duration_days', row.duration_days)
    values.set('completed_at', row.completed_at)
    values.set('card_data', row.card_data)
    values.set('created_at', row.created_at)
    return values
  }

  getCloudId(row: AchievementSyncRow): string { return row.cloud_id }
  setCloudId(row: AchievementSyncRow, cloudId: string): void { row.cloud_id = cloudId }
  getUpdatedAt(row: AchievementSyncRow): string { return row.completed_at || row.created_at }
  getLocalId(row: AchievementSyncRow): string { return row.id }

  getLocalKeyColumn(): string {
    return SyncIdKeys.localKeyColumn()
  }

  getCloudRowId(cloudRow: object): string {
    return SyncIdKeys.cloudRowId(cloudRow)
  }
}
