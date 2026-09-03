/**
 * user_settings 表同步适配器（从 SyncTableAdapters 拆出）
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { SyncCloudRecord, TableSync } from './SyncTypes'
import { SyncRs } from './SyncRs'

class SettingsSyncRow {
  user_id: string = ''
  cloud_id: string = ''
  app_lock_enabled: number = 0
  app_lock_hash: string = ''
  email_reminders: number = 0
  updated_at: string = ''
}

class SettingsCloudRecord {
  user_id: string = ''
  app_lock_enabled: boolean = false
  app_lock_hash: string = ''
  email_reminders: boolean = false
  updated_at: string = ''
}

function resultSetToSettingsRow(rs: relationalStore.ResultSet): SettingsSyncRow {
  const row = new SettingsSyncRow()
  row.user_id = SyncRs.readString(rs, 'user_id')
  row.cloud_id = SyncRs.readString(rs, 'cloud_id')
  row.app_lock_enabled = SyncRs.readNumber(rs, 'app_lock_enabled')
  row.app_lock_hash = SyncRs.readString(rs, 'app_lock_hash')
  row.email_reminders = SyncRs.readNumber(rs, 'email_reminders')
  row.updated_at = SyncRs.readString(rs, 'updated_at')
  return row
}

export class SettingsTableSync implements TableSync<SettingsSyncRow> {
  readonly tableName: string = Constants.TABLE_USER_SETTINGS

  async getLocalRows(userId: string): Promise<SettingsSyncRow[]> {
    const rs = await DbService.query('SELECT * FROM user_settings WHERE user_id = ?', [userId])
    const rows: SettingsSyncRow[] = []
    try {
      if (rs.goToFirstRow()) {
        rows.push(resultSetToSettingsRow(rs))
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

  toCloud(row: SettingsSyncRow): object {
    const record = new SettingsCloudRecord()
    record.user_id = row.user_id
    record.app_lock_enabled = DbService.intToBool(row.app_lock_enabled)
    record.email_reminders = DbService.intToBool(row.email_reminders)
    record.updated_at = row.updated_at.length > 0 ? row.updated_at : DbService.now()
    // 锁哈希本机 only；空串也不出站，避免覆盖云列或撞 CHECK
    const body: Record<string, Object> = {}
    body['user_id'] = record.user_id
    body['app_lock_enabled'] = record.app_lock_enabled
    body['email_reminders'] = record.email_reminders
    body['updated_at'] = record.updated_at
    return body
  }

  fromCloud(cloudRow: object): SettingsSyncRow {
    const cloud = cloudRow as SettingsCloudRecord
    const row = new SettingsSyncRow()
    row.user_id = cloud.user_id
    // 以 user_id 作为云端身份，避免无 id 字段时同步键为空
    row.cloud_id = cloud.user_id
    row.app_lock_enabled = DbService.boolToInt(cloud.app_lock_enabled)
    // 不采用云端哈希，保留本机锁
    row.app_lock_hash = ''
    row.email_reminders = DbService.boolToInt(cloud.email_reminders)
    row.updated_at = cloud.updated_at ?? ''
    return row
  }

  toMap(row: SettingsSyncRow): Map<string, string | number | boolean> {
    const values = new Map<string, string | number | boolean>()
    values.set('user_id', row.user_id)
    if (row.cloud_id.length > 0) {
      values.set('cloud_id', row.cloud_id)
    }
    values.set('app_lock_enabled', row.app_lock_enabled)
    // 不写 app_lock_hash，避免 pull 覆盖本机 PIN
    values.set('email_reminders', row.email_reminders)
    values.set('updated_at', row.updated_at)
    return values
  }

  getCloudId(row: SettingsSyncRow): string {
    return row.cloud_id.length > 0 ? row.cloud_id : row.user_id
  }

  setCloudId(row: SettingsSyncRow, cloudId: string): void {
    row.cloud_id = cloudId
  }

  getUpdatedAt(row: SettingsSyncRow): string {
    return row.updated_at
  }

  getLocalId(row: SettingsSyncRow): string {
    return row.user_id
  }

  getLocalKeyColumn(): string {
    return 'user_id'
  }

  getCloudRowId(cloudRow: object): string {
    const cloud = cloudRow as SettingsCloudRecord
    // settings 云表通常以 user_id 为主键，未必有 id
    if (cloud.user_id !== undefined && cloud.user_id !== null && ('' + cloud.user_id).length > 0) {
      return '' + cloud.user_id
    }
    const rec = cloudRow as Record<string, string>
    return rec['id'] ?? ''
  }
}
