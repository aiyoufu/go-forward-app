import { DbService } from '../DbService'

export class CloudIdMap {
  static async getCloudId(tableName: string, localId: string): Promise<string | null> {
    const rs = await DbService.query(
      'SELECT cloud_id FROM sync_id_map WHERE table_name = ? AND local_id = ?',
      [tableName, localId]
    )
    let cloudId: string | null = null
    try {
      if (rs.goToFirstRow()) {
        cloudId = rs.getString(rs.getColumnIndex('cloud_id'))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return cloudId
  }

  static async getLocalId(tableName: string, cloudId: string): Promise<string | null> {
    const rs = await DbService.query(
      'SELECT local_id FROM sync_id_map WHERE table_name = ? AND cloud_id = ?',
      [tableName, cloudId]
    )
    let localId: string | null = null
    try {
      if (rs.goToFirstRow()) {
        localId = rs.getString(rs.getColumnIndex('local_id'))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return localId
  }

  static async setMapping(tableName: string, localId: string, cloudId: string): Promise<void> {
    const now = DbService.now()
    const values = new Map<string, string | number | boolean>()
    values.set('table_name', tableName)
    values.set('local_id', localId)
    values.set('cloud_id', cloudId)
    values.set('synced_at', now)

    try {
      await DbService.insert('sync_id_map', values)
    } catch {
      await DbService.update('sync_id_map', values, 'table_name = ? AND local_id = ?', [tableName, localId])
    }
  }

  static async removeMapping(tableName: string, localId: string): Promise<void> {
    await DbService.delete('sync_id_map', 'table_name = ? AND local_id = ?', [tableName, localId])
  }

  /**
   * 解析业务行的云端 id：优先 sync_id_map，其次业务表 cloud_id 列。
   */
  static async resolveCloudId(tableName: string, localId: string): Promise<string> {
    if (localId.length === 0) {
      return ''
    }
    const mapped = await CloudIdMap.getCloudId(tableName, localId)
    if (mapped !== null && mapped.length > 0) {
      return mapped
    }
    try {
      const rs = await DbService.query(
        'SELECT cloud_id FROM ' + tableName + ' WHERE id = ?',
        [localId]
      )
      let cloudId = ''
      if (rs.goToFirstRow()) {
        cloudId = '' + (rs.getString(rs.getColumnIndex('cloud_id')) ?? '')
      }
      rs.close()
      return cloudId
    } catch {
      return ''
    }
  }
}
