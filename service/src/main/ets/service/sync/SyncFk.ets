/**
 * 同步外键映射：本地 id ↔ 云端 id
 * - 出站：toCloud 后把 debt_id / credit_account_id / subscription_id 换成云 id
 * - 入站：fromCloud 后换成本地 id，保证本机 FK 可 join
 */
import { Constants } from 'common'
import { CloudIdMap } from './CloudIdMap'

/** 可挂 FK 字段的松散记录（适配 toCloud/fromCloud 产物） */
export class SyncFkRecord {
  debt_id: string = ''
  credit_account_id: string = ''
  subscription_id: string = ''
}

export class SyncFk {
  /**
   * 出站：本地 FK → 云端 id。
   * 找不到云 id 时必须清空本地 id，禁止把本机 generateId 原样推上云
   * （云列多为 uuid + FK，会整批 400 →「推送 0 / 失败 N」）。
   */
  static async mapOutbound(tableName: string, body: object): Promise<object> {
    const rec = body as SyncFkRecord
    if (tableName === Constants.TABLE_PAYMENT_RECORDS ||
      tableName === Constants.TABLE_ACHIEVEMENT_CARDS) {
      if (rec.debt_id !== undefined && rec.debt_id !== null && ('' + rec.debt_id).length > 0) {
        const cloud = await CloudIdMap.getCloudId(Constants.TABLE_DEBTS, '' + rec.debt_id)
        rec.debt_id = (cloud !== null && cloud.length > 0) ? cloud : ''
      }
    }
    if (tableName === Constants.TABLE_SUBSCRIPTIONS) {
      if (rec.credit_account_id !== undefined && rec.credit_account_id !== null &&
        ('' + rec.credit_account_id).length > 0) {
        const cloud = await CloudIdMap.getCloudId(Constants.TABLE_CREDIT_ACCOUNTS, '' + rec.credit_account_id)
        rec.credit_account_id = (cloud !== null && cloud.length > 0) ? cloud : ''
      }
    }
    if (tableName === Constants.TABLE_DEBTS) {
      if (rec.credit_account_id !== undefined && rec.credit_account_id !== null &&
        ('' + rec.credit_account_id).length > 0) {
        const cloud = await CloudIdMap.getCloudId(Constants.TABLE_CREDIT_ACCOUNTS, '' + rec.credit_account_id)
        rec.credit_account_id = (cloud !== null && cloud.length > 0) ? cloud : ''
      }
    }
    if (tableName === Constants.TABLE_NOTIFICATIONS) {
      if (rec.debt_id !== undefined && rec.debt_id !== null && ('' + rec.debt_id).length > 0) {
        const cloud = await CloudIdMap.getCloudId(Constants.TABLE_DEBTS, '' + rec.debt_id)
        rec.debt_id = (cloud !== null && cloud.length > 0) ? cloud : ''
      }
      if (rec.subscription_id !== undefined && rec.subscription_id !== null &&
        ('' + rec.subscription_id).length > 0) {
        const cloud = await CloudIdMap.getCloudId(Constants.TABLE_SUBSCRIPTIONS, '' + rec.subscription_id)
        rec.subscription_id = (cloud !== null && cloud.length > 0) ? cloud : ''
      }
    }
    return body
  }

  /**
   * 出站前检查：依赖父表云 id 的行，父尚未推成功则不应 POST（留给下次 outbox）。
   * true = 可推；false = 暂缓。
   */
  static canPushAfterMap(tableName: string, body: object): boolean {
    const rec = body as SyncFkRecord
    if (tableName === Constants.TABLE_PAYMENT_RECORDS ||
      tableName === Constants.TABLE_ACHIEVEMENT_CARDS) {
      // debt_id 必填：未映射到云 id 时不能推
      return ('' + (rec.debt_id ?? '')).length > 0
    }
    return true
  }

  /**
   * 入站：云端 FK → 本地 id（找不到映射时保留云 id，避免丢字段）
   */
  static async mapInbound(tableName: string, row: object): Promise<object> {
    const rec = row as SyncFkRecord
    if (tableName === Constants.TABLE_PAYMENT_RECORDS ||
      tableName === Constants.TABLE_ACHIEVEMENT_CARDS) {
      if (rec.debt_id !== undefined && rec.debt_id !== null && ('' + rec.debt_id).length > 0) {
        const local = await CloudIdMap.getLocalId(Constants.TABLE_DEBTS, '' + rec.debt_id)
        if (local !== null && local.length > 0) {
          rec.debt_id = local
        }
      }
    }
    if (tableName === Constants.TABLE_SUBSCRIPTIONS) {
      if (rec.credit_account_id !== undefined && rec.credit_account_id !== null &&
        ('' + rec.credit_account_id).length > 0) {
        const local = await CloudIdMap.getLocalId(Constants.TABLE_CREDIT_ACCOUNTS, '' + rec.credit_account_id)
        if (local !== null && local.length > 0) {
          rec.credit_account_id = local
        }
      }
    }
    if (tableName === Constants.TABLE_DEBTS) {
      if (rec.credit_account_id !== undefined && rec.credit_account_id !== null &&
        ('' + rec.credit_account_id).length > 0) {
        const local = await CloudIdMap.getLocalId(Constants.TABLE_CREDIT_ACCOUNTS, '' + rec.credit_account_id)
        if (local !== null && local.length > 0) {
          rec.credit_account_id = local
        }
      }
    }
    if (tableName === Constants.TABLE_NOTIFICATIONS) {
      if (rec.debt_id !== undefined && rec.debt_id !== null && ('' + rec.debt_id).length > 0) {
        const local = await CloudIdMap.getLocalId(Constants.TABLE_DEBTS, '' + rec.debt_id)
        if (local !== null && local.length > 0) {
          rec.debt_id = local
        }
      }
      if (rec.subscription_id !== undefined && rec.subscription_id !== null &&
        ('' + rec.subscription_id).length > 0) {
        const local = await CloudIdMap.getLocalId(Constants.TABLE_SUBSCRIPTIONS, '' + rec.subscription_id)
        if (local !== null && local.length > 0) {
          rec.subscription_id = local
        }
      }
    }
    return row
  }

  /** 纯函数：仅用于单测 — 已有映射表时替换 */
  static applyMap(localId: string, map: Map<string, string>): string {
    if (localId.length === 0) {
      return ''
    }
    const v = map.get(localId)
    return v !== undefined && v.length > 0 ? v : localId
  }
}
