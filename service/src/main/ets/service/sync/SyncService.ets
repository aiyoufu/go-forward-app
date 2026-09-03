import { AuthManager, AuthState } from '../auth/AuthManager'
import { UserService } from '../UserService'
import { SupabaseRestService, SupabaseRestOptions, SupabaseRestResponse } from '../SupabaseRestService'
import { DbService } from '../DbService'
import { CloudIdMap } from './CloudIdMap'
import { Utils } from 'common'
import { Constants } from 'common'
import { ErrorMessages } from 'common'
import { Logger } from 'common'
import { SyncCloudRecord, SyncResult, SyncStats, TableSync } from './SyncTypes'
import { SyncHelpers } from './SyncHelpers'
import { RetryHelper } from '../RetryHelper'
import { SyncOutbox, SyncOutboxItem } from './SyncOutbox'
import { SyncFk } from './SyncFk'
import { SettingsTableSync } from './SettingsTableSync'
import { CreditAccountTableSync } from './CreditAccountTableSync'
import { DebtTableSync } from './DebtTableSync'
import { PaymentTableSync } from './PaymentTableSync'
import { SubscriptionTableSync } from './SubscriptionTableSync'
import { NotificationTableSync } from './NotificationTableSync'
import { AchievementTableSync } from './AchievementTableSync'
import { IconCloudService } from '../platform/IconCloudService'

// 对外类型门面：调用方仍从 SyncService 导入
export { SyncStats, SyncResult, TableSync, SyncCloudRecord } from './SyncTypes'

/** 分页拉取结果；complete=false 表示未取全，调用方禁止据此做删除决策 */
class PagedRows {
  rows: object[] = []
  complete: boolean = false
  error: string = ''
  status: number = 0
}

/**
 * P1 同步引擎：
 * 1) flush outbox（upsert/delete，表依赖序）
 * 2) 各表增量 pull + LWW 合并
 * 3) 云端 id 核对删除本地孤儿（防删后回魂）
 * 4) 遗留本地未入队变更仍可 push（兼容升级）
 */
export class SyncService {
  /** 导入宽限期截止（ms）；期内跳过孤儿核对，避免误删本机刚导入数据 */
  private static importGraceUntilMs: number = 0
  /** 最近一次推送失败详情（供摘要展示，避免只有「失败 N」） */
  private static lastPushError: string = ''
  /** 本轮 syncAll 中已成功推上云的 cloud_id，核对时绝对不删 */
  private static justPushedCloudIds: string[] = []

  /** 由 SyncScheduler.endBulkWrite / 导入路径调用 */
  static markImportGrace(durationMs: number = 120000): void {
    const until = Date.now() + (durationMs > 0 ? durationMs : 120000)
    if (until > SyncService.importGraceUntilMs) {
      SyncService.importGraceUntilMs = until
    }
  }

  static isInImportGrace(): boolean {
    return Date.now() < SyncService.importGraceUntilMs
  }

  /** 本轮是否从云拉到了行（含核对删除计数前的 pull）；供调度器决定是否整表刷新 UI */
  static sumPulled(stats: SyncStats[]): number {
    let n = 0
    for (let i = 0; i < stats.length; i++) {
      n += stats[i].pulled
    }
    return n
  }

  static sumPushed(stats: SyncStats[]): number {
    let n = 0
    for (let i = 0; i < stats.length; i++) {
      n += stats[i].pushed
    }
    return n
  }

  static async syncAll(): Promise<SyncResult> {
    const session = await AuthManager.loadSession()
    if (!session || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return new SyncResult(false, '未登录云端或登录态已过期')
    }

    const stats: SyncStats[] = []
    const errors: string[] = []
    const userId = session.userId.length > 0 ? session.userId : UserService.getCurrentUserId()
    SyncService.lastPushError = ''
    SyncService.justPushedCloudIds = []

    try {
      // 漏入队的本机行（引导期本地录入、导入、enqueue 失败）补进 outbox，避免只拉不推
      await SyncService.enqueueRowsMissingCloudId(userId)

      // 鸿蒙本地 file:// 图标转存到 Storage，供 Web/PC 回显
      try {
        await IconCloudService.repairCloudIcons(session)
      } catch (iconErr) {
        Logger.warn('SyncService', 'repairCloudIcons 失败: ' +
          (iconErr instanceof Error ? iconErr.message : 'err'))
      }

      // P1-1：先 flush 写队列
      const outboxStats = await SyncService.flushOutbox(session)
      stats.push(outboxStats)
      if (outboxStats.failed > 0) {
        const detail = SyncService.lastPushError.length > 0
          ? ('outbox 部分失败: ' + SyncService.lastPushError)
          : 'outbox 部分失败'
        errors.push(detail)
      }

      // 核对删除需谨慎（宁可回魂，不可误删）：
      // - outbox 枚举失败 → 全表跳过核对（未知当有 pending）
      // - 该表仍有 pending / 导入宽限 / flush 失败 → 跳过该表
      // - 本轮刚推成功的 cloud_id 在 reconcileDeletes 内按 id 保护，不再因「任意 push」跳过全表
      let pendingUnknown = false
      let pendingItems: SyncOutboxItem[] = []
      try {
        pendingItems = await SyncOutbox.listAllPending()
      } catch (e) {
        pendingUnknown = true
        Logger.warn('SyncService', 'listAllPending 失败，本轮跳过核对: ' +
          (e instanceof Error ? e.message : 'err'))
      }
      const skipAllReconcile = pendingUnknown ||
        outboxStats.failed > 0 ||
        SyncService.isInImportGrace()

      // P1-5：表顺序 payment 在 debt 后
      await SyncService.runOneTable(new SettingsTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_USER_SETTINGS))
      await SyncService.runOneTable(new CreditAccountTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_CREDIT_ACCOUNTS))
      await SyncService.runOneTable(new DebtTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_DEBTS))
      await SyncService.runOneTable(new PaymentTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_PAYMENT_RECORDS))
      await SyncService.runOneTable(new SubscriptionTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_SUBSCRIPTIONS))
      await SyncService.runOneTable(new NotificationTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_NOTIFICATIONS))
      await SyncService.runOneTable(new AchievementTableSync(), session, stats, errors,
        skipAllReconcile || SyncService.tableHasPending(pendingItems, Constants.TABLE_ACHIEVEMENT_CARDS))

      await SyncService.updateLastSyncAt('global', session.userId, DbService.now())
      let summary = SyncHelpers.buildSummary(stats)
      if (SyncService.lastPushError.length > 0) {
        if (summary.indexOf('失败') >= 0) {
          summary = summary + '（' + SyncService.lastPushError + '）'
        } else {
          summary = summary + '，失败（' + SyncService.lastPushError + '）'
        }
      }
      // 任一条推送失败都不能报成功：否则设置页显示「已同步」，云端却是空的
      if (errors.length > 0 || SyncHelpers.hasHardFailures(stats)) {
        const detail = SyncService.lastPushError.length > 0
          ? summary
          : (errors.length > 0 ? errors[0] : summary)
        return new SyncResult(false,
          ErrorMessages.userFacing(detail, ErrorMessages.SYNC_FAILED), stats)
      }
      return new SyncResult(true, summary, stats)
    } catch (err) {
      const detail = err instanceof Error ? err.message : JSON.stringify(err)
      return new SyncResult(false,
        ErrorMessages.userFacing(detail, ErrorMessages.SYNC_FAILED), stats)
    }
  }

  private static async runOneTable<T extends object>(
    sync: TableSync<T>,
    session: AuthState,
    stats: SyncStats[],
    errors: string[],
    skipReconcile: boolean = false
  ): Promise<void> {
    try {
      stats.push(await SyncService.syncTable(sync, session, skipReconcile))
    } catch (tableErr) {
      const st = new SyncStats(sync.tableName)
      st.failed += 1
      stats.push(st)
      const detail = tableErr instanceof Error ? tableErr.message : JSON.stringify(tableErr)
      errors.push(detail)
    }
  }

  /**
   * 单表：增量/全量 pull → LWW → 遗留 push → id 核对删除 → 推进 cursor
   */
  private static async syncTable<T extends object>(
    sync: TableSync<T>,
    session: AuthState,
    skipReconcile: boolean = false
  ): Promise<SyncStats> {
    const stats = new SyncStats(sync.tableName)
    const userId = session.userId.length > 0 ? session.userId : UserService.getCurrentUserId()
    if (userId.length === 0) {
      stats.failed += 1
      return stats
    }

    const lastSyncAt = await SyncService.getLastSyncAt(sync.tableName)
    const timeCol = SyncService.pullTimeColumn(sync.tableName)

    const pullOptions = new SupabaseRestOptions(sync.tableName)
    pullOptions.filters.set('user_id', 'eq.' + userId)
    // P1-3：有 cursor 时增量；首同全量
    if (lastSyncAt.length > 0 && timeCol.length > 0) {
      pullOptions.filters.set(timeCol, 'gt.' + lastSyncAt)
    }
    // 首同全量可能超过云端单页上限（默认 1000），必须翻页，否则本批之外的行拉不到
    const pulledPage = await SyncService.getAllPages(
      pullOptions, session, SyncService.pullOrderColumn(sync.tableName))
    if (pulledPage.error.length > 0) {
      stats.failed += 1
      throw new Error(sync.tableName + ' 拉取失败: ' + pulledPage.error +
        (pulledPage.status > 0 ? ' (HTTP ' + pulledPage.status + ')' : ''))
    }

    const cloudRows = pulledPage.rows
    const localRows = await sync.getLocalRows(userId)

    const cloudById = new Map<string, object>()
    const pullTimestamps: string[] = []
    for (const cloudRow of cloudRows) {
      const cloudId = sync.getCloudRowId(cloudRow)
      if (cloudId.length > 0) {
        cloudById.set(cloudId, cloudRow)
      }
      pullTimestamps.push(SyncService.extractUpdatedAt(cloudRow))
    }

    // 仍在 outbox 待推的本地行（导入/离线新建后本轮尚未成功上云）：
    // 绝不能让云端旧行在 pull/LWW 阶段把它盖回 —— 这正是「导入后同步失败，数据回退」的根因。
    // 这些行本地即真源，命中云行时改为加入待推让本地最终赢。
    const pendingLocalIds = await SyncService.listPendingLocalIds(sync.tableName)

    const localByCloudId = new Map<string, T>()
    const toPush: object[] = []
    /** 本轮遗留 push 的本地行，成功后落盘 cloud_id */
    const pushLocalRows: T[] = []

    for (const localRow of localRows) {
      // 注意：无持久化 cloud_id 时不要先 setCloudId —— 否则核对会把「仅内存临时 id」当成已上云孤儿删掉
      // （导入/离线新建后增量同步时会短暂显示再被抹回云端旧数据）
      let cloudId = sync.getCloudId(localRow)
      const hadPersistedCloudId = cloudId.length > 0
      if (!hadPersistedCloudId) {
        cloudId = Utils.generateUuid()
      }

      const localId = sync.getLocalId(localRow)
      const pendingUnknown = pendingLocalIds.length === 1 && pendingLocalIds[0] === '*'
      const isPending = pendingUnknown ||
        (localId.length > 0 && SyncHelpers.listHas(pendingLocalIds, localId))

      const cloudRow = cloudById.get(cloudId)
      if (cloudRow) {
        localByCloudId.set(cloudId, localRow)
        const cloudUpdatedAt = SyncService.extractUpdatedAt(cloudRow)
        const localUpdatedAt = sync.getUpdatedAt(localRow)
        if (isPending) {
          // 本地有未 flush 的变更（含刚导入）：保留本地，改为补推，禁止云端覆盖
          sync.setCloudId(localRow, cloudId)
          const body = await SyncService.buildOutboundBody(sync, localRow, userId)
          toPush.push(body)
          pushLocalRows.push(localRow)
        } else if (SyncHelpers.shouldPreferCloud(localUpdatedAt, cloudUpdatedAt)) {
          const merged = sync.fromCloud(cloudRow)
          sync.setCloudId(merged, cloudId)
          await SyncFk.mapInbound(sync.tableName, merged)
          await SyncService.saveLocalRow(sync, merged, localRow)
          stats.pulled += 1
        } else if (SyncHelpers.compareTimestamps(localUpdatedAt, cloudUpdatedAt) > 0) {
          // 本地更新：遗留 push（未入 outbox 的兼容路径）
          const body = await SyncService.buildOutboundBody(sync, localRow, userId)
          toPush.push(body)
          pushLocalRows.push(localRow)
        }
      } else if (lastSyncAt.length === 0 || !hadPersistedCloudId) {
        // 全量：推云上没有的本地行；或本地尚无 cloud_id（outbox 失败/漏入队）→ 遗留补推
        // 有 cloud_id 的增量「本批未含」视为未变，不误推
        sync.setCloudId(localRow, cloudId)
        const body = await SyncService.buildOutboundBody(sync, localRow, userId)
        toPush.push(body)
        pushLocalRows.push(localRow)
      }
    }

    // 本批 pull 里云有本地无 → 插入
    for (const cloudRow of cloudRows) {
      const cloudId = sync.getCloudRowId(cloudRow)
      if (cloudId.length > 0 && !localByCloudId.has(cloudId)) {
        // 可能本地已有同 cloud_id（增量时 localByCloudId 未标记因 LWW 相等）
        const existing = SyncService.findLocalByCloudId(localRows, sync, cloudId)
        if (existing !== null) {
          continue
        }
        const merged = sync.fromCloud(cloudRow)
        sync.setCloudId(merged, cloudId)
        await SyncFk.mapInbound(sync.tableName, merged)
        await SyncService.saveLocalRow(sync, merged, null)
        stats.pulled += 1
      }
    }

    // 逐条推：避免一批里一条坏 FK 导致整批失败（表现为「推送 0 / 失败 N」）
    for (let i = 0; i < toPush.length; i++) {
      const localRow = pushLocalRows[i]
      const bodyRaw = toPush[i]
      if (!SyncFk.canPushAfterMap(sync.tableName, bodyRaw)) {
        stats.failed += 1
        if (SyncService.lastPushError.length === 0) {
          SyncService.lastPushError = sync.tableName + ' 依赖的父记录尚未上云，已暂缓'
        }
        continue
      }
      const body = SyncService.sanitizeOutboundBody(bodyRaw)
      const pushOptions = SupabaseRestService.buildUpsertOptions(sync.tableName, [body])
      const pushResponse = await SyncService.requestWithAuth(
        (token) => SupabaseRestService.post(token, pushOptions),
        session
      )
      if (pushResponse.error.length > 0) {
        stats.failed += 1
        if (SyncService.lastPushError.length === 0) {
          SyncService.lastPushError = sync.tableName + ': ' + pushResponse.error
        }
        continue
      }
      const pushedCloudId = sync.getCloudId(localRow)
      const localId = sync.getLocalId(localRow)
      if (localId.length > 0 && pushedCloudId.length > 0) {
        await CloudIdMap.setMapping(sync.tableName, localId, pushedCloudId)
        SyncService.justPushedCloudIds.push(pushedCloudId)
        const values = new Map<string, string | number | boolean>()
        values.set('cloud_id', pushedCloudId)
        try {
          await DbService.update(sync.tableName, values, sync.getLocalKeyColumn() + ' = ?', [localId])
        } catch (e) {
          Logger.warn('SyncService', sync.tableName + ' cloud_id 回写失败: ' +
            (e instanceof Error ? e.message : 'err'))
          stats.failed += 1
          continue
        }
      }
      stats.pushed += 1
    }

    // P1-2：按 DB 真源核对（勿用上面可能被 setCloudId 改过的内存行）
    // skipReconcile：该表 outbox 未净 / 导入宽限 / 枚举失败 — 只推拉、不删本机行
    const pendingIdsUnknown = pendingLocalIds.length === 1 && pendingLocalIds[0] === '*'
    if (!skipReconcile && !pendingIdsUnknown) {
      const freshLocal = await sync.getLocalRows(userId)
      const deleted = await SyncService.reconcileDeletes(sync, session, userId, freshLocal)
      stats.pulled += deleted
    }

    // 未取全禁止前进 cursor，避免跳过尚未拉取的行
    if (pulledPage.complete) {
      let nextCursor = SyncHelpers.advanceCursor(lastSyncAt, pullTimestamps)
      if (nextCursor.length === 0) {
        nextCursor = DbService.now()
      }
      await SyncService.updateLastSyncAt(sync.tableName, userId, nextCursor)
    } else {
      Logger.warn('SyncService', sync.tableName + ' 分页未取全，本轮不推进 cursor')
    }
    return stats
  }

  /**
   * 把「本地有行但还没有 cloud_id」的记录补进 outbox。
   * 漏入队时增量同步会当成无事可做，界面显示已同步、云端却是空的。
   */
  private static async enqueueRowsMissingCloudId(userId: string): Promise<void> {
    if (userId.length === 0) {
      return
    }
    await SyncService.enqueueMissingFor(new SettingsTableSync(), userId)
    await SyncService.enqueueMissingFor(new CreditAccountTableSync(), userId)
    await SyncService.enqueueMissingFor(new DebtTableSync(), userId)
    await SyncService.enqueueMissingFor(new PaymentTableSync(), userId)
    await SyncService.enqueueMissingFor(new SubscriptionTableSync(), userId)
    await SyncService.enqueueMissingFor(new NotificationTableSync(), userId)
    await SyncService.enqueueMissingFor(new AchievementTableSync(), userId)
  }

  private static async enqueueMissingFor<T extends object>(
    sync: TableSync<T>,
    userId: string
  ): Promise<void> {
    try {
      const rows = await sync.getLocalRows(userId)
      for (let j = 0; j < rows.length; j++) {
        const row = rows[j]
        const localId = sync.getLocalId(row)
        if (localId.length === 0) {
          continue
        }
        if (sync.getCloudId(row).length === 0) {
          const cloudHint = sync.tableName === Constants.TABLE_USER_SETTINGS ? localId : ''
          await SyncOutbox.enqueueUpsert(sync.tableName, localId, cloudHint)
        }
      }
    } catch (e) {
      Logger.warn('SyncService', '补入队 ' + sync.tableName + ' 失败: ' +
        (e instanceof Error ? e.message : 'err'))
    }
  }

  private static tableHasPending(pending: SyncOutboxItem[], tableName: string): boolean {
    for (let i = 0; i < pending.length; i++) {
      if (pending[i].table_name === tableName) {
        return true
      }
    }
    return false
  }

  /** flush 结果：1 成功 / 0 硬失败 / 2 暂缓（等父记录，不算失败） */
  private static readonly FLUSH_OK: number = 1
  private static readonly FLUSH_FAIL: number = 0
  private static readonly FLUSH_DEFER: number = 2

  /**
   * flush outbox：按表依赖序 + delete 优先；多轮直到无进展
   * （先账户/债，后还款，避免「父未上云 → 15 条全算失败」）
   */
  private static async flushOutbox(session: AuthState): Promise<SyncStats> {
    const stats = new SyncStats('outbox')
    const userId = session.userId.length > 0 ? session.userId : UserService.getCurrentUserId()
    try {
      await SyncOutbox.adoptAllPending(userId)
    } catch (e) {
      Logger.warn('SyncService', 'adoptAllPending 失败: ' +
        (e instanceof Error ? e.message : 'err'))
    }

    for (let round = 0; round < 6; round++) {
      const pending = SyncOutbox.sortForFlush(await SyncOutbox.listAllPending())
      if (pending.length === 0) {
        break
      }
      let pushedThisRound = 0
      let hardFailThisRound = 0
      for (let i = 0; i < pending.length; i++) {
        const item = pending[i]
        try {
          const code = await SyncService.flushOne(item, session)
          if (code === SyncService.FLUSH_OK) {
            await SyncOutbox.removeById(item.id)
            stats.pushed += 1
            pushedThisRound += 1
          } else if (code === SyncService.FLUSH_DEFER) {
            // 等父记录，本轮不记失败、不 bump
          } else {
            hardFailThisRound += 1
            await SyncOutbox.bumpRetry(item.id, item.retry_count)
          }
        } catch (e) {
          hardFailThisRound += 1
          await SyncOutbox.bumpRetry(item.id, item.retry_count)
          if (SyncService.lastPushError.length === 0) {
            const detail = e instanceof Error ? e.message : JSON.stringify(e)
            SyncService.lastPushError = item.table_name + ': ' + detail
          }
        }
      }
      if (pushedThisRound === 0) {
        // 无进展：剩余全部记失败（含仍 DEFER 的，便于 UI 显示失败数与原因）
        stats.failed += hardFailThisRound
        const still = await SyncOutbox.listAllPending()
        if (still.length > 0 && hardFailThisRound === 0) {
          // 全是 DEFER：记失败条数并写清原因
          stats.failed += still.length
          if (SyncService.lastPushError.length === 0) {
            SyncService.lastPushError = '依赖的父记录未能上云，' + still.length + ' 条暂缓'
          }
        }
        break
      }
    }
    // 多轮后仍剩余：记入 failed，便于「待推」与摘要一致
    try {
      const left = await SyncOutbox.listAllPending()
      if (left.length > 0 && stats.failed < left.length) {
        stats.failed = left.length
      }
    } catch {
    }
    return stats
  }

  private static async flushOne(item: SyncOutboxItem, session: AuthState): Promise<number> {
    if (item.operation === SyncOutbox.OP_DELETE) {
      if (item.cloud_id.length === 0) {
        return SyncService.FLUSH_OK
      }
      const options = new SupabaseRestOptions(item.table_name)
      options.filters.set('id', 'eq.' + item.cloud_id)
      options.preferReturn = 'minimal'
      const response = await SyncService.requestWithAuth(
        (token) => SupabaseRestService.delete(token, options),
        session
      )
      if (response.error.length === 0) {
        return SyncService.FLUSH_OK
      }
      if (response.status === 404 || response.status === 406) {
        return SyncService.FLUSH_OK
      }
      if (response.status >= 200 && response.status < 300) {
        return SyncService.FLUSH_OK
      }
      if (SyncService.lastPushError.length === 0) {
        SyncService.lastPushError = item.table_name + ' delete: ' + response.error
      }
      return SyncService.FLUSH_FAIL
    }

    if (item.operation === SyncOutbox.OP_UPSERT) {
      return SyncService.flushUpsertByTable(item, session)
    }
    return SyncService.FLUSH_OK
  }

  private static async flushUpsertByTable(item: SyncOutboxItem, session: AuthState): Promise<number> {
    if (item.table_name === Constants.TABLE_USER_SETTINGS) {
      return SyncService.flushUpsertWith(new SettingsTableSync(), item, session)
    }
    if (item.table_name === Constants.TABLE_CREDIT_ACCOUNTS) {
      return SyncService.flushUpsertWith(new CreditAccountTableSync(), item, session)
    }
    if (item.table_name === Constants.TABLE_DEBTS) {
      return SyncService.flushUpsertWith(new DebtTableSync(), item, session)
    }
    if (item.table_name === Constants.TABLE_PAYMENT_RECORDS) {
      return SyncService.flushUpsertWith(new PaymentTableSync(), item, session)
    }
    if (item.table_name === Constants.TABLE_SUBSCRIPTIONS) {
      return SyncService.flushUpsertWith(new SubscriptionTableSync(), item, session)
    }
    if (item.table_name === Constants.TABLE_NOTIFICATIONS) {
      return SyncService.flushUpsertWith(new NotificationTableSync(), item, session)
    }
    if (item.table_name === Constants.TABLE_ACHIEVEMENT_CARDS) {
      return SyncService.flushUpsertWith(new AchievementTableSync(), item, session)
    }
    return SyncService.FLUSH_OK
  }

  private static async flushUpsertWith<T extends object>(
    sync: TableSync<T>,
    item: SyncOutboxItem,
    session: AuthState
  ): Promise<number> {
    const sessionUserId = session.userId.length > 0 ? session.userId : UserService.getCurrentUserId()
    // 先按 session 用户查；找不到再按主键探测 user_id（导入/迁移后偶发不一致）
    let target: T | null = await SyncService.findLocalRow(sync, sessionUserId, item.record_id)
    if (target === null) {
      const ownerId = await SyncService.probeRowUserId(item.table_name, sync.getLocalKeyColumn(), item.record_id)
      if (ownerId === null) {
        // 本地行已不存在，可清队列
        return SyncService.FLUSH_OK
      }
      if (ownerId.length > 0 && ownerId !== sessionUserId) {
        target = await SyncService.findLocalRow(sync, ownerId, item.record_id)
      }
    }
    if (target === null) {
      if (SyncService.lastPushError.length === 0) {
        SyncService.lastPushError = item.table_name + ': 本地行不可读 (id=' + item.record_id + ')'
      }
      return SyncService.FLUSH_FAIL
    }
    let cloudId = sync.getCloudId(target)
    if (cloudId.length === 0) {
      cloudId = item.cloud_id.length > 0 ? item.cloud_id : Utils.generateUuid()
      sync.setCloudId(target, cloudId)
    }
    const rawBody = await IconCloudService.rewriteOutboundIcon(item.table_name, sync.toCloud(target), session)
    // RLS：云端 user_id 必须等于 JWT sub，强制写 session 用户
    const asRec = rawBody as SyncCloudRecord
    if (sessionUserId.length > 0) {
      asRec.user_id = sessionUserId
    }
    const mapped = await SyncFk.mapOutbound(item.table_name, rawBody)
    if (!SyncFk.canPushAfterMap(item.table_name, mapped)) {
      if (SyncService.lastPushError.length === 0) {
        SyncService.lastPushError = item.table_name + ' 依赖的父记录尚未上云，已暂缓'
      }
      return SyncService.FLUSH_DEFER
    }
    // 空字符串 UUID/日期 → null，避免 Postgres「invalid input syntax for type uuid」
    const body = SyncService.sanitizeOutboundBody(mapped)
    const pushOptions = SupabaseRestService.buildUpsertOptions(item.table_name, [body])
    const pushResponse = await SyncService.requestWithAuth(
      (token) => SupabaseRestService.post(token, pushOptions),
      session
    )
    if (pushResponse.error.length > 0) {
      if (SyncService.lastPushError.length === 0) {
        SyncService.lastPushError = item.table_name + ': ' + pushResponse.error
      }
      return SyncService.FLUSH_FAIL
    }
    await CloudIdMap.setMapping(item.table_name, item.record_id, cloudId)
    SyncService.justPushedCloudIds.push(cloudId)
    const values = new Map<string, string | number | boolean>()
    values.set('cloud_id', cloudId)
    // 若本地 user_id 与 session 不一致，顺手纠正，避免下次 getLocalRows 再丢
    if (sessionUserId.length > 0) {
      values.set('user_id', sessionUserId)
    }
    const keyCol = sync.getLocalKeyColumn()
    try {
      await DbService.update(item.table_name, values, keyCol + ' = ?', [item.record_id])
    } catch {
    }
    return SyncService.FLUSH_OK
  }

  /**
   * 出站体清理：uuid 外键/可选日期的空串改为 null，防止整批 400。
   * 仅改顶层字段，浅拷贝即可（避免 JSON.parse/stringify 深拷贝，bad-deep-clone-check）。
   */
  private static sanitizeOutboundBody(body: object): object {
    const src = body as Record<string, Object | null>
    const plain: Record<string, Object | null> = {}
    const keys = Object.keys(src)
    for (let i = 0; i < keys.length; i++) {
      const k = keys[i]
      plain[k] = src[k]
    }
    const uuidFks: string[] = ['credit_account_id', 'debt_id', 'subscription_id']
    for (let i = 0; i < uuidFks.length; i++) {
      const k = uuidFks[i]
      const v = plain[k]
      // key 不存在（undefined）时切勿补 null —— 否则会给无此列的表（如 user_settings）凭空加列，
      // 触发「Could not find the 'credit_account_id' column」。仅把已存在的空串/空值规整为 null。
      if (v === undefined) {
        continue
      }
      if (v === null || ('' + v).length === 0) {
        plain[k] = null
      }
    }
    const optDates: string[] = ['end_date', 'expiry_date', 'scheduled_date', 'read_at']
    for (let i = 0; i < optDates.length; i++) {
      const k = optDates[i]
      const v = plain[k]
      if (v !== undefined && v !== null && ('' + v).length === 0) {
        plain[k] = null
      }
    }
    // 有格式/正则 CHECK 的可选文本列：空串既非 NULL 也不匹配正则，会整批违反 CHECK。
    // 例：credit_accounts.last_four 约束 `IS NULL OR ~ '^\d{4}$'`，本地默认 '' 必然失败，
    // 导致该行 push 永久失败、outbox 排不空，表现为「一直同步中」。空串统一转 null。
    const optText: string[] = ['last_four']
    for (let i = 0; i < optText.length; i++) {
      const k = optText[i]
      const v = plain[k]
      if (v !== undefined && v !== null && ('' + v).length === 0) {
        plain[k] = null
      }
    }
    return plain as object
  }

  /** toCloud + 强制 session user_id + FK 映射 */
  private static async buildOutboundBody<T extends object>(
    sync: TableSync<T>,
    localRow: T,
    sessionUserId: string
  ): Promise<object> {
    const session = await AuthManager.loadSession()
    const raw = session !== null
      ? await IconCloudService.rewriteOutboundIcon(sync.tableName, sync.toCloud(localRow), session)
      : sync.toCloud(localRow)
    const asRec = raw as SyncCloudRecord
    if (sessionUserId.length > 0) {
      asRec.user_id = sessionUserId
    }
    return SyncFk.mapOutbound(sync.tableName, raw)
  }

  private static async findLocalRow<T extends object>(
    sync: TableSync<T>,
    userId: string,
    recordId: string
  ): Promise<T | null> {
    if (userId.length === 0 || recordId.length === 0) {
      return null
    }
    const localRows = await sync.getLocalRows(userId)
    for (let i = 0; i < localRows.length; i++) {
      if (sync.getLocalId(localRows[i]) === recordId) {
        return localRows[i]
      }
    }
    return null
  }

  /** 不按 user 过滤，探测行是否存在及其 user_id；不存在返回 null */
  private static async probeRowUserId(
    tableName: string,
    keyCol: string,
    recordId: string
  ): Promise<string | null> {
    try {
      const rs = await DbService.query(
        'SELECT user_id FROM ' + tableName + ' WHERE ' + keyCol + ' = ?',
        [recordId]
      )
      if (!rs.goToFirstRow()) {
        rs.close()
        return null
      }
      let uid = ''
      try {
        uid = '' + (rs.getString(rs.getColumnIndex('user_id')) ?? '')
      } catch {
        uid = ''
      }
      rs.close()
      return uid
    } catch {
      return null
    }
  }

  /**
   * 该表仍在 outbox 待推的本地 record_id 列表。
   * pull/LWW 阶段据此保护：本地有未 flush 变更（含刚导入）的行，绝不被云端旧行覆盖。
   */
  private static async listPendingLocalIds(tableName: string): Promise<string[]> {
    const ids: string[] = []
    try {
      const pending = await SyncOutbox.listAllPending()
      for (let i = 0; i < pending.length; i++) {
        if (pending[i].table_name === tableName && pending[i].record_id.length > 0) {
          ids.push(pending[i].record_id)
        }
      }
    } catch (e) {
      Logger.warn('SyncService', 'listPendingLocalIds 失败，本表按全保护处理: ' +
        (e instanceof Error ? e.message : 'err'))
      return ['*']
    }
    return ids
  }

  /**
   * 核对：补拉「云有本地无」+ 删除本地「有 cloud_id 但不在云端」的行（他端已删）。
   * 保护：pending outbox 的 cloud_id **与** local record_id（导入/新建尚未成功上云时 cloud_id 常为空）。
   * 无 cloud_id 的行永不删（尚未映射到云，不是孤儿）。
   */
  private static async reconcileDeletes<T extends object>(
    sync: TableSync<T>,
    session: AuthState,
    userId: string,
    localRows: T[]
  ): Promise<number> {
    // settings 以 user_id 为键，不做孤儿删
    if (sync.tableName === Constants.TABLE_USER_SETTINGS) {
      return 0
    }
    const idOptions = new SupabaseRestOptions(sync.tableName)
    idOptions.select = 'id'
    idOptions.filters.set('user_id', 'eq.' + userId)
    // 必须翻页取全：单页被 max-rows 截断时，未返回的云 id 会被误判为「他端已删」
    const paged = await SyncService.getAllPages(
      idOptions, session, SyncService.pullOrderColumn(sync.tableName))
    if (paged.error.length > 0 || !paged.complete) {
      // 核对失败/未取全不抛：避免阻断整表；本轮跳过删除（宁可回魂，不可误删）
      return 0
    }
    const cloudIds: string[] = []
    for (let i = 0; i < paged.rows.length; i++) {
      const cid = sync.getCloudRowId(paged.rows[i])
      if (cid.length > 0) {
        cloudIds.push(cid)
      }
    }

    const pending = await SyncOutbox.listAllPending()
    const pendingCloudIds: string[] = []
    const pendingLocalIds: string[] = []
    for (let i = 0; i < pending.length; i++) {
      if (pending[i].table_name !== sync.tableName) {
        continue
      }
      if (pending[i].cloud_id.length > 0) {
        pendingCloudIds.push(pending[i].cloud_id)
      }
      if (pending[i].record_id.length > 0) {
        pendingLocalIds.push(pending[i].record_id)
      }
    }

    // 云有本地无：增量 pull 会漏掉 updated_at 早于 cursor 的行（PC 导入曾保留备份旧时间戳）。
    // 核对阶段按 id 差集补拉，否则订阅/账户会「云上有、手机没有」。
    const localCloudIds: string[] = []
    for (let i = 0; i < localRows.length; i++) {
      const cid = sync.getCloudId(localRows[i])
      if (cid.length > 0) {
        localCloudIds.push(cid)
      }
    }
    const missingIds = SyncHelpers.missingCloudIds(cloudIds, localCloudIds)
    let inserted = 0
    if (missingIds.length > 0) {
      inserted = await SyncService.backfillMissingCloudRows(sync, session, userId, missingIds)
    }

    let removed = 0
    const keyCol = sync.getLocalKeyColumn()
    for (let i = 0; i < localRows.length; i++) {
      const row = localRows[i]
      const localId = sync.getLocalId(row)
      // 队列里尚未 flush 成功的本地行：无论 cloud_id 是否已写，都保留
      if (localId.length > 0 && SyncHelpers.listHas(pendingLocalIds, localId)) {
        continue
      }
      const cloudId = sync.getCloudId(row)
      // 本轮刚推成功的 id：云列表可能短暂不可见，绝不能当孤儿删
      if (cloudId.length > 0 && SyncHelpers.listHas(SyncService.justPushedCloudIds, cloudId)) {
        continue
      }
      if (!SyncHelpers.shouldDeleteOrphan(cloudId, cloudIds, pendingCloudIds)) {
        continue
      }
      // 还款先随债删；单删 payment 即可
      if (sync.tableName === Constants.TABLE_DEBTS) {
        await DbService.delete(Constants.TABLE_PAYMENT_RECORDS, 'debt_id = ?', [localId])
      }
      await DbService.delete(sync.tableName, keyCol + ' = ?', [localId])
      await CloudIdMap.removeMapping(sync.tableName, localId)
      removed += 1
    }
    return removed + inserted
  }

  /** 按 cloud id 列表拉取完整行并写入本地（增量漏拉的补救） */
  private static async backfillMissingCloudRows<T extends object>(
    sync: TableSync<T>,
    session: AuthState,
    userId: string,
    missingIds: string[]
  ): Promise<number> {
    const rows = await SyncService.fetchCloudRowsByIds(sync.tableName, session, userId, missingIds)
    let n = 0
    for (let i = 0; i < rows.length; i++) {
      const cloudRow = rows[i]
      const cloudId = sync.getCloudRowId(cloudRow)
      if (cloudId.length === 0) {
        continue
      }
      try {
        const merged = sync.fromCloud(cloudRow)
        sync.setCloudId(merged, cloudId)
        await SyncFk.mapInbound(sync.tableName, merged)
        await SyncService.saveLocalRow(sync, merged, null)
        n += 1
      } catch (e) {
        Logger.warn('SyncService', sync.tableName + ' 补拉写入失败: ' +
          (e instanceof Error ? e.message : 'err'))
      }
    }
    return n
  }

  private static async fetchCloudRowsByIds(
    tableName: string,
    session: AuthState,
    userId: string,
    ids: string[]
  ): Promise<object[]> {
    const out: object[] = []
    const chunkSize = 80
    for (let start = 0; start < ids.length; start += chunkSize) {
      const chunk: string[] = []
      const end = start + chunkSize < ids.length ? start + chunkSize : ids.length
      for (let i = start; i < end; i++) {
        chunk.push(ids[i])
      }
      if (chunk.length === 0) {
        continue
      }
      const options = new SupabaseRestOptions(tableName)
      options.select = '*'
      options.filters.set('user_id', 'eq.' + userId)
      options.filters.set('id', 'in.(' + chunk.join(',') + ')')
      const response = await SyncService.requestWithAuth(
        (token) => SupabaseRestService.get(token, options),
        session
      )
      if (response.error.length > 0) {
        Logger.warn('SyncService', tableName + ' 补拉缺失行失败: ' + response.error)
        break
      }
      for (let j = 0; j < response.data.length; j++) {
        out.push(response.data[j])
      }
    }
    return out
  }

  /** 增量时间列：无统一 updated_at 的表单独映射 */
  private static pullTimeColumn(tableName: string): string {
    if (tableName === Constants.TABLE_PAYMENT_RECORDS) {
      return 'created_at'
    }
    if (tableName === Constants.TABLE_NOTIFICATIONS) {
      return 'sent_at'
    }
    if (tableName === Constants.TABLE_ACHIEVEMENT_CARDS) {
      return 'created_at'
    }
    return 'updated_at'
  }

  /** 分页排序列：settings 云表以 user_id 为主键，未必有 id 列 */
  private static pullOrderColumn(tableName: string): string {
    if (tableName === Constants.TABLE_USER_SETTINGS) {
      return 'user_id'
    }
    return 'id'
  }

  private static async getLastSyncAt(tableName: string): Promise<string> {
    try {
      const rs = await DbService.query(
        'SELECT last_sync_at FROM sync_state WHERE table_name = ?',
        [tableName]
      )
      let at = ''
      if (rs.goToFirstRow()) {
        at = '' + (rs.getString(rs.getColumnIndex('last_sync_at')) ?? '')
      }
      rs.close()
      return at
    } catch {
      return ''
    }
  }

  /** offset 未推进时同一首页键会重复，必须停，否则会一直同步中 */
  static pageDidStall(prevFirstKey: string, firstKey: string, pageIndex: number): boolean {
    return pageIndex > 0 && firstKey.length > 0 && firstKey === prevFirstKey
  }

  private static pageFirstKey(batch: object[], orderColumn: string): string {
    if (batch.length === 0) {
      return ''
    }
    const rec = batch[0] as Record<string, Object>
    if (rec[orderColumn] !== undefined && rec[orderColumn] !== null) {
      return `${rec[orderColumn]}`
    }
    if (rec['id'] !== undefined && rec['id'] !== null) {
      return `${rec['id']}`
    }
    if (rec['user_id'] !== undefined && rec['user_id'] !== null) {
      return `${rec['user_id']}`
    }
    return ''
  }

  /**
   * 分页 GET：PostgREST 默认 max-rows（通常 1000）会静默截断，
   * 单次请求的结果不能代表「云端全量」。核对删除若基于截断列表判断孤儿，
   * 会把第 1001 行起的本地行当成他端已删而误删 —— 故必须翻页取全。
   * 以 id 排序保证翻页稳定；complete=false 表示中途失败，调用方须放弃删除决策。
   */
  private static async getAllPages(
    baseOptions: SupabaseRestOptions,
    session: AuthState,
    orderColumn: string = 'id',
    pageSize: number = 1000
  ): Promise<PagedRows> {
    const out = new PagedRows()
    let offset = 0
    let prevFirstKey: string = ''
    // 上限兜底：避免云端异常时无限翻页
    for (let page = 0; page < 200; page++) {
      const options = new SupabaseRestOptions(baseOptions.table)
      options.select = baseOptions.select
      options.preferReturn = baseOptions.preferReturn
      for (const key of baseOptions.filters.keys()) {
        const v = baseOptions.filters.get(key)
        if (v !== undefined) {
          options.filters.set(key, v)
        }
      }
      // 稳定排序 + 窗口；缺一都可能漏行或重复
      options.filters.set('order', orderColumn + '.asc')
      options.filters.set('limit', '' + pageSize)
      options.filters.set('offset', '' + offset)

      const response = await SyncService.requestWithAuth(
        (token) => SupabaseRestService.get(token, options),
        session
      )
      if (response.error.length > 0) {
        out.error = response.error
        out.status = response.status
        return out
      }
      const batch = response.data
      for (let i = 0; i < batch.length; i++) {
        out.rows.push(batch[i])
      }
      // 终止条件只认「本页 0 行」：云端 max-rows 可能小于请求的 pageSize，
      // 若按 batch.length < pageSize 判定结束，会在首页就误判取全而漏掉后续行。
      if (batch.length === 0) {
        out.complete = true
        return out
      }
      const firstKey = SyncService.pageFirstKey(batch, orderColumn)
      if (SyncService.pageDidStall(prevFirstKey, firstKey, page)) {
        out.complete = true
        return out
      }
      prevFirstKey = firstKey
      offset += batch.length
    }
    return out
  }

  /**
   * 带鉴权请求：遇 401 时尝试 refresh JWT 后重试一次。
   */
  private static async requestWithAuth(
    request: (token: string) => Promise<SupabaseRestResponse>,
    session: AuthState
  ): Promise<SupabaseRestResponse> {
    let response = await SyncService.requestWithRetry(request, session.accessToken)
    if (response.status !== 401) {
      return response
    }
    const refreshed = await AuthManager.refreshCloudSession()
    if (refreshed === null || refreshed.accessToken.length === 0) {
      return response
    }
    session.accessToken = refreshed.accessToken
    if (refreshed.refreshToken.length > 0) {
      session.refreshToken = refreshed.refreshToken
    }
    return SyncService.requestWithRetry(request, session.accessToken)
  }

  private static requestWithRetry(
    request: (token: string) => Promise<SupabaseRestResponse>,
    token: string,
    maxAttempts: number = 3
  ): Promise<SupabaseRestResponse> {
    return RetryHelper.run<SupabaseRestResponse>(
      () => request(token),
      (r: SupabaseRestResponse) => r.error.length === 0 || (r.status >= 400 && r.status < 500),
      new SupabaseRestResponse(0, [], '同步请求失败'),
      (attempt: number) => 1000 * (attempt + 1),
      maxAttempts
    )
  }

  private static extractUpdatedAt(cloudRow: object): string {
    const record = cloudRow as SyncCloudRecord
    return SyncHelpers.pickCloudTimestamp(record.updated_at, record.created_at)
  }

  /**
   * 保存本地行：优先按 existingLocal 主键更新；否则按 cloud_id / id 查找，避免 pull 产生重复行。
   */
  private static async saveLocalRow<T extends object>(
    sync: TableSync<T>,
    row: T,
    existingLocal: T | null
  ): Promise<void> {
    let localId = sync.getLocalId(row)
    const cloudId = sync.getCloudId(row)
    const keyCol = sync.getLocalKeyColumn()

    if (existingLocal !== null) {
      localId = sync.getLocalId(existingLocal)
      // 把合并结果的主键改回已有本地 id（适配器 fromCloud 常生成新 id）
      if (keyCol === 'id') {
        const valuesFix = sync.toMap(row)
        valuesFix.set('id', localId)
        if (cloudId.length > 0) {
          valuesFix.set('cloud_id', cloudId)
        }
        await DbService.update(sync.tableName, valuesFix, 'id = ?', [localId])
        if (localId.length > 0 && cloudId.length > 0) {
          await CloudIdMap.setMapping(sync.tableName, localId, cloudId)
        }
        return
      }
    }

    if (cloudId.length > 0 && keyCol === 'id') {
      const mapped = await CloudIdMap.getLocalId(sync.tableName, cloudId)
      if (mapped !== null && mapped.length > 0) {
        localId = mapped
      } else {
        try {
          const rsCloud = await DbService.query(
            'SELECT id FROM ' + sync.tableName + ' WHERE cloud_id = ?',
            [cloudId]
          )
          if (rsCloud.goToFirstRow()) {
            localId = '' + (rsCloud.getString(rsCloud.getColumnIndex('id')) ?? localId)
          }
          rsCloud.close()
        } catch {
        }
      }
    }

    const values = sync.toMap(row)
    if (keyCol === 'id') {
      values.set('id', localId)
    }
    if (cloudId.length > 0 && keyCol === 'id') {
      values.set('cloud_id', cloudId)
    } else if (cloudId.length > 0 && !values.has('cloud_id')) {
      values.set('cloud_id', cloudId)
    }

    const rs = await DbService.query(
      'SELECT ' + keyCol + ' FROM ' + sync.tableName + ' WHERE ' + keyCol + ' = ?',
      [localId]
    )
    let exists = false
    try {
      exists = rs.goToFirstRow()
    } catch (_e) {
    }
    try {
      rs.close()
    } catch (_e2) {
    }

    if (exists) {
      await DbService.update(sync.tableName, values, keyCol + ' = ?', [localId])
    } else {
      await DbService.insert(sync.tableName, values)
    }

    if (localId.length > 0 && cloudId.length > 0) {
      await CloudIdMap.setMapping(sync.tableName, localId, cloudId)
    }
  }

  private static findLocalByCloudId<T extends object>(localRows: T[], sync: TableSync<T>, cloudId: string): T | null {
    for (const row of localRows) {
      if (sync.getCloudId(row) === cloudId) {
        return row
      }
    }
    return null
  }

  private static async updateLastSyncAt(tableName: string, userId: string, at: string): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('table_name', tableName)
    values.set('user_id', userId)
    values.set('last_sync_at', at.length > 0 ? at : DbService.now())
    try {
      await DbService.insert('sync_state', values)
    } catch {
      await DbService.update('sync_state', values, 'table_name = ?', [tableName])
    }
  }

  /**
   * 清空当前云端用户的全部业务同步数据。
   */
  static async clearAllCloudData(): Promise<void> {
    const session = await AuthManager.loadSession()
    if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return
    }
    const tables: string[] = [
      Constants.TABLE_PAYMENT_RECORDS,
      Constants.TABLE_DEBTS,
      Constants.TABLE_SUBSCRIPTIONS,
      Constants.TABLE_CREDIT_ACCOUNTS,
      Constants.TABLE_NOTIFICATIONS,
      Constants.TABLE_ACHIEVEMENT_CARDS
    ]

    let failed: string[] = []
    for (let i = 0; i < tables.length; i++) {
      try {
        await SyncService.deleteAllRowsForUser(session, tables[i])
      } catch (_e) {
        failed.push(tables[i])
      }
    }

    if (failed.length > 0) {
      const still: string[] = []
      for (let i = 0; i < failed.length; i++) {
        try {
          await SyncService.deleteAllRowsForUser(session, failed[i])
        } catch (_e2) {
          still.push(failed[i])
        }
      }
      failed = still
    }

    if (failed.length > 0) {
      const residual: string[] = []
      for (let i = 0; i < failed.length; i++) {
        const hasRows = await SyncService.hasCloudRowsForUser(session, failed[i])
        if (hasRows) {
          residual.push(failed[i])
        }
      }
      if (residual.length > 0) {
        throw new Error('云端未清完: ' + residual.join(','))
      }
    }
  }

  private static async deleteAllRowsForUser(session: AuthState, table: string): Promise<void> {
    const options = new SupabaseRestOptions(table)
    options.filters.set('user_id', 'eq.' + session.userId)
    options.preferReturn = 'minimal'
    const response = await SyncService.requestWithAuth(
      (token) => SupabaseRestService.delete(token, options),
      session
    )
    if (response.error.length > 0) {
      throw new Error(table + ' 云端清除失败: ' + response.error)
    }
  }

  private static async hasCloudRowsForUser(session: AuthState, table: string): Promise<boolean> {
    const options = new SupabaseRestOptions(table)
    options.select = 'id'
    options.filters.set('user_id', 'eq.' + session.userId)
    options.filters.set('limit', '1')
    const response = await SyncService.requestWithAuth(
      (token) => SupabaseRestService.get(token, options),
      session
    )
    if (response.error.length > 0) {
      return true
    }
    return response.data.length > 0
  }
}
