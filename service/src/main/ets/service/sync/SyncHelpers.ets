import { SyncStats } from './SyncTypes'

/**
 * 同步纯工具（S4）— 无网络/DB，可单测
 *
 * ## 冲突策略（P1-4）
 * 整行 LWW：优先把时间戳解析为毫秒后按数值比较（Date.parse），
 * 避免 `Z` / `+00:00` / 微秒精度等格式差异导致字符串字典序误判；解析失败才回退字符串比较。
 * - 云 `updated_at` **严格大于** 本地 → 云胜（shouldPreferCloud=true）
 * - 本地 **严格大于** 云 → 本地推（调用方 toPush）
 * - **相等（含同秒）**：保留本地，不覆盖（防抖/重复 pull 不抖动）
 * - 云时间空：不覆盖本地
 * - 本地时间空且云有值：云胜
 * 权威时间：以云端返回的 updated_at 为准写回本地（拉赢时 fromCloud 已带云时间）。
 */
export class SyncHelpers {
  /** 汇总推拉条数文案 */
  static buildSummary(stats: SyncStats[]): string {
    let totalPushed = 0
    let totalPulled = 0
    let totalFailed = 0
    for (let i = 0; i < stats.length; i++) {
      totalPushed += stats[i].pushed
      totalPulled += stats[i].pulled
      totalFailed += stats[i].failed
    }
    let msg = '推送 ' + totalPushed + ' 条，拉取 ' + totalPulled + ' 条'
    if (totalFailed > 0) {
      msg = msg + '，失败 ' + totalFailed
    }
    return msg
  }

  /** 任一张表有失败条数：本轮不能算同步成功 */
  static hasHardFailures(stats: SyncStats[]): boolean {
    for (let i = 0; i < stats.length; i++) {
      if (stats[i].failed > 0) {
        return true
      }
    }
    return false
  }

  /**
   * 云行时间戳：优先 updated_at，否则 created_at
   */
  static pickCloudTimestamp(updatedAt: string, createdAt: string): string {
    if (updatedAt !== undefined && updatedAt !== null && updatedAt.length > 0) {
      return updatedAt
    }
    if (createdAt !== undefined && createdAt !== null) {
      return createdAt
    }
    return ''
  }

  /**
   * 时间戳比较：优先解析为毫秒数值比较（Date.parse），解析失败才回退字符串字典序。
   * 避免本地 `toISOString()` 的 `Z` 与云端 Postgres 的 `+00:00`、微秒精度差异导致的误判。
   * 返回 >0 表示 a 更晚，<0 表示 a 更早，0 表示相等。
   */
  static compareTimestamps(a: string, b: string): number {
    const ma = Date.parse(a)
    const mb = Date.parse(b)
    const aValid = ma === ma // 非 NaN
    const bValid = mb === mb
    if (aValid && bValid) {
      if (ma > mb) {
        return 1
      }
      if (ma < mb) {
        return -1
      }
      return 0
    }
    // 任一无法解析：回退字符串比较
    if (a > b) {
      return 1
    }
    if (a < b) {
      return -1
    }
    return 0
  }

  /**
   * 本地是否应被云覆盖：云时间严格更新（相等不覆盖）
   */
  static shouldPreferCloud(localUpdatedAt: string, cloudUpdatedAt: string): boolean {
    if (cloudUpdatedAt.length === 0) {
      return false
    }
    if (localUpdatedAt.length === 0) {
      return true
    }
    return SyncHelpers.compareTimestamps(cloudUpdatedAt, localUpdatedAt) > 0
  }

  /**
   * 增量 cursor：取 max(prev, 各云行时间戳)
   */
  static advanceCursor(prev: string, timestamps: string[]): string {
    let best = prev
    for (let i = 0; i < timestamps.length; i++) {
      const t = timestamps[i]
      if (t.length === 0) {
        continue
      }
      if (best.length === 0 || SyncHelpers.compareTimestamps(t, best) > 0) {
        best = t
      }
    }
    return best
  }

  /**
   * 本地 cloud_id 是否应在核对中删除：
   * 有 cloud_id、不在云端 id 列表、且不在 pending 保护列表。
   */
  static shouldDeleteOrphan(cloudId: string, cloudIds: string[], pendingCloudIds: string[]): boolean {
    if (cloudId.length === 0) {
      return false
    }
    if (SyncHelpers.listHas(pendingCloudIds, cloudId)) {
      return false
    }
    return !SyncHelpers.listHas(cloudIds, cloudId)
  }

  /**
   * 云端有、本地没有的 cloud_id。
   * 增量 pull（updated_at > last_sync_at）会漏掉「他端导入但保留旧时间戳」的行，
   * 核对阶段用这份差集补拉。
   */
  static missingCloudIds(cloudIds: string[], localCloudIds: string[]): string[] {
    const missing: string[] = []
    for (let i = 0; i < cloudIds.length; i++) {
      const id = cloudIds[i]
      if (id.length === 0) {
        continue
      }
      if (!SyncHelpers.listHas(localCloudIds, id)) {
        missing.push(id)
      }
    }
    return missing
  }

  static listHas(list: string[], value: string): boolean {
    for (let i = 0; i < list.length; i++) {
      if (list[i] === value) {
        return true
      }
    }
    return false
  }
}
