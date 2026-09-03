/**
 * P1-1 Outbox：本地写后入队，同步时 flush。
 * 复用 DbService.sync_queue 表。
 * operation: upsert | delete
 */
import { relationalStore } from '@kit.ArkData'
import { DbService } from '../DbService'
import { Constants } from 'common'
import { Utils } from 'common'
import { UserService } from '../UserService'

export class SyncOutboxItem {
  id: string = ''
  user_id: string = ''
  table_name: string = ''
  record_id: string = ''
  operation: string = ''
  /** delete 时为云端 id；upsert 时可为空（flush 时再解析） */
  cloud_id: string = ''
  /** 可选 JSON 载荷；空则 flush 时重读本地 */
  payload: string = ''
  created_at: number = 0
  retry_count: number = 0
}

export class SyncOutbox {
  static readonly OP_UPSERT: string = 'upsert'
  static readonly OP_DELETE: string = 'delete'

  /**
   * 入队 upsert：同一 table+record 的旧 pending 合并为一条最新。
   * cloudId 可为空（尚未映射）。
   */
  static async enqueueUpsert(tableName: string, recordId: string, cloudId: string = ''): Promise<void> {
    if (tableName.length === 0 || recordId.length === 0) {
      return
    }
    await SyncOutbox.removePendingForRecord(tableName, recordId)
    await SyncOutbox.insertItem(tableName, recordId, SyncOutbox.OP_UPSERT, cloudId, '')
  }

  /**
   * 入队 delete：取消同记录 pending upsert；有 cloudId 才需推云端删除。
   * 无 cloudId：仅本地存在过，无需云删。
   */
  static async enqueueDelete(tableName: string, recordId: string, cloudId: string): Promise<void> {
    if (tableName.length === 0 || recordId.length === 0) {
      return
    }
    await SyncOutbox.removePendingForRecord(tableName, recordId)
    if (cloudId.length === 0) {
      return
    }
    await SyncOutbox.insertItem(tableName, recordId, SyncOutbox.OP_DELETE, cloudId, '')
  }

  static async listPending(userId: string = UserService.getCurrentUserId()): Promise<SyncOutboxItem[]> {
    if (userId.length === 0) {
      return SyncOutbox.listAllPending()
    }
    const rs = await DbService.query(
      'SELECT * FROM sync_queue WHERE user_id = ? ORDER BY created_at ASC',
      [userId]
    )
    const list: SyncOutboxItem[] = []
    try {
      while (rs.goToNextRow()) {
        list.push(SyncOutbox.rowToItem(rs))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return list
  }

  /**
   * 列出全部待推（不按 user_id 过滤）。
   * 入队可能写在 local 默认 user、空 user 或云 user 下；flush 必须扫全表，否则会出现
   * 「成功 / 失败 0 / 待推 15」——队列在，同步却当没有 pending。
   */
  static async listAllPending(): Promise<SyncOutboxItem[]> {
    const rs = await DbService.query(
      'SELECT * FROM sync_queue ORDER BY created_at ASC',
      []
    )
    const list: SyncOutboxItem[] = []
    try {
      while (rs.goToNextRow()) {
        list.push(SyncOutbox.rowToItem(rs))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return list
  }

  /**
   * 同步前把队列统一归到当前云用户，避免 user_id 漂移导致永远待推。
   */
  static async adoptAllPending(sessionUserId: string): Promise<void> {
    if (sessionUserId.length === 0) {
      return
    }
    try {
      const values = new Map<string, string | number | boolean>()
      values.set('user_id', sessionUserId)
      // 全表归并：本机单账号；多账号同库不在产品范围
      await DbService.update('sync_queue', values, '1 = 1', [])
    } catch {
      // 无行可更新时忽略
    }
  }

  static async removeById(id: string): Promise<void> {
    await DbService.delete('sync_queue', 'id = ?', [id])
  }

  static async bumpRetry(id: string, retryCount: number): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('retry_count', retryCount + 1)
    await DbService.update('sync_queue', values, 'id = ?', [id])
  }

  static async clearAllForUser(userId: string): Promise<void> {
    await DbService.delete('sync_queue', 'user_id = ?', [userId])
  }

  /** 表依赖排序：payment 在 debt 后；delete 优先于同表 upsert（先处理删除） */
  static sortForFlush(items: SyncOutboxItem[]): SyncOutboxItem[] {
    const tableRank = (name: string): number => {
      if (name === Constants.TABLE_USER_SETTINGS) {
        return 0
      }
      if (name === Constants.TABLE_CREDIT_ACCOUNTS) {
        return 1
      }
      if (name === Constants.TABLE_DEBTS) {
        return 2
      }
      if (name === Constants.TABLE_PAYMENT_RECORDS) {
        return 3
      }
      if (name === Constants.TABLE_SUBSCRIPTIONS) {
        return 4
      }
      if (name === Constants.TABLE_NOTIFICATIONS) {
        return 5
      }
      if (name === Constants.TABLE_ACHIEVEMENT_CARDS) {
        return 6
      }
      return 50
    }
    const opRank = (op: string): number => {
      return op === SyncOutbox.OP_DELETE ? 0 : 1
    }
    const copy: SyncOutboxItem[] = []
    for (let i = 0; i < items.length; i++) {
      copy.push(items[i])
    }
    copy.sort((a: SyncOutboxItem, b: SyncOutboxItem): number => {
      const tr = tableRank(a.table_name) - tableRank(b.table_name)
      if (tr !== 0) {
        return tr
      }
      const or = opRank(a.operation) - opRank(b.operation)
      if (or !== 0) {
        return or
      }
      return a.created_at - b.created_at
    })
    return copy
  }

  private static async removePendingForRecord(tableName: string, recordId: string): Promise<void> {
    await DbService.delete('sync_queue', 'table_name = ? AND record_id = ?', [tableName, recordId])
  }

  private static async insertItem(
    tableName: string,
    recordId: string,
    operation: string,
    cloudId: string,
    payload: string
  ): Promise<void> {
    const item = new SyncOutboxItem()
    item.id = Utils.generateId()
    // 优先内存当前用户；为空时仍写入空串，flush 前 adoptAllPending 会归并
    let uid = UserService.getCurrentUserId()
    if (uid.length === 0) {
      uid = ''
    }
    item.user_id = uid
    item.table_name = tableName
    item.record_id = recordId
    item.operation = operation
    item.cloud_id = cloudId
    item.payload = payload
    item.created_at = Date.now()
    item.retry_count = 0

    const values = new Map<string, string | number | boolean>()
    values.set('id', item.id)
    values.set('user_id', item.user_id)
    values.set('table_name', item.table_name)
    values.set('record_id', item.record_id)
    values.set('operation', item.operation)
    // payload 存 cloud_id|json：表结构无 cloud_id 列，塞进 payload 前缀
    values.set('payload', SyncOutbox.encodePayload(cloudId, payload))
    values.set('created_at', item.created_at)
    values.set('retry_count', 0)
    await DbService.insert('sync_queue', values)
  }

  /** payload 列编码：cloudId\nJSON 或仅 cloudId */
  static encodePayload(cloudId: string, jsonBody: string): string {
    if (jsonBody.length > 0) {
      return cloudId + '\n' + jsonBody
    }
    return cloudId
  }

  static decodeCloudId(payloadCol: string): string {
    if (payloadCol.length === 0) {
      return ''
    }
    const nl = payloadCol.indexOf('\n')
    if (nl < 0) {
      return payloadCol
    }
    return payloadCol.substring(0, nl)
  }

  static decodeJsonBody(payloadCol: string): string {
    const nl = payloadCol.indexOf('\n')
    if (nl < 0) {
      return ''
    }
    return payloadCol.substring(nl + 1)
  }

  private static rowToItem(rs: relationalStore.ResultSet): SyncOutboxItem {
    const item = new SyncOutboxItem()
    try {
      item.id = '' + (rs.getString(rs.getColumnIndex('id')) ?? '')
      item.user_id = '' + (rs.getString(rs.getColumnIndex('user_id')) ?? '')
      item.table_name = '' + (rs.getString(rs.getColumnIndex('table_name')) ?? '')
      item.record_id = '' + (rs.getString(rs.getColumnIndex('record_id')) ?? '')
      item.operation = '' + (rs.getString(rs.getColumnIndex('operation')) ?? '')
      const rawPayload = '' + (rs.getString(rs.getColumnIndex('payload')) ?? '')
      item.cloud_id = SyncOutbox.decodeCloudId(rawPayload)
      item.payload = SyncOutbox.decodeJsonBody(rawPayload)
      try {
        item.created_at = Number(rs.getLong(rs.getColumnIndex('created_at')) || 0)
      } catch {
        item.created_at = Number(rs.getString(rs.getColumnIndex('created_at')) || 0)
      }
      try {
        item.retry_count = Number(rs.getLong(rs.getColumnIndex('retry_count')) || 0)
      } catch {
        item.retry_count = Number(rs.getString(rs.getColumnIndex('retry_count')) || 0)
      }
    } catch {
      // 列缺失时保持默认
    }
    return item
  }
}
