/**
 * 本地优先 · 同步调度（P0-2/3/5）
 * - debounce 合并写后/回前台/网络恢复触发
 * - 单飞锁：并发 schedule 合并为一次 flush，结束后若有 rerun 再跑
 * - 状态写入 AppStorage，供设置页状态图标展示
 */
import { connection } from '@kit.NetworkKit'
import { AppStorageKeys } from 'common'
import { Constants } from 'common'
import { ErrorMessages } from 'common'
import { Logger } from 'common'
import { AuthManager } from '../auth/AuthManager'
import { DbService } from '../DbService'
import { SettingsService } from '../SettingsService'
import { UserService } from '../UserService'
import { SyncService, SyncResult } from './SyncService'
import { SyncOutbox } from './SyncOutbox'
import { LocalDataStore } from './LocalDataStore'
import { AnalyticsService } from '../AnalyticsService'

/** idle | syncing | ok | error */
export type SyncPhase = string

export class SyncStatusSnapshot {
  phase: SyncPhase = 'idle'
  /** 本轮同步主方向：'up'(上传) | 'down'(下载) */
  direction: string = 'down'
  lastSuccessAt: string = ''
  lastMessage: string = ''
  lastError: string = ''
  /** P2-4 可观测 */
  lastDurationMs: number = 0
  successCount: number = 0
  failCount: number = 0
  outboxPending: number = 0
}

export class SyncScheduler {
  private static readonly DEFAULT_DEBOUNCE_MS: number = 800
  private static readonly WRITE_DEBOUNCE_MS: number = 1000
  private static readonly FOREGROUND_DEBOUNCE_MS: number = 400
  private static readonly NET_DEBOUNCE_MS: number = 1500
  /** P2-3：前台周期补同步（毫秒） */
  private static readonly PULSE_INTERVAL_MS: number = 5 * 60 * 1000
  /**
   * 回前台同步冷却：距上次「真正发起过」的同步不足此值时，跳过前台触发。
   * 写后/Realtime/网络恢复/手动/周期 pulse 不受此冷却影响。
   */
  private static readonly FOREGROUND_COOLDOWN_MS: number = 30 * 1000
  /** 进主页后首段禁止 pulse，避免与 loadHome 抢库 */
  private static readonly PULSE_GRACE_MS: number = 30 * 1000
  /** 首页未就绪时等待上限，超时仍同步 */
  private static readonly HOME_READY_FALLBACK_MS: number = 3000
  /** 同步中相位最长展示；超时先落失败态，避免设置页一直「同步中」 */
  static readonly MAX_SYNC_UI_MS: number = 45000

  private static timerId: number = -1
  private static running: boolean = false
  private static rerun: boolean = false
  private static netWatchStarted: boolean = false
  private static pulseTimerId: number = -1
  /** 最近一次「真正发起」同步的完成时间戳（0 表从未），仅用于前台冷却判断 */
  private static lastSyncFinishedAt: number = 0
  /** 首页 loadHome 是否已完成（本进程进主页后） */
  private static homeHydrated: boolean = false
  private static pendingEnterMain: boolean = false
  private static homeWaitTimerId: number = -1
  /**
   * 批量写深度（导入/清空等）。>0 时忽略一切自动 schedule，
   * 避免导入中途 Realtime/前台/写后同步把半成品当孤儿删掉。
   */
  private static bulkDepth: number = 0
  private static phase: SyncPhase = 'idle'
  /** 本轮同步主方向：有 outbox 待推=up，否则 down */
  private static direction: string = 'down'
  private static lastSuccessAt: string = ''
  private static lastMessage: string = ''
  private static lastError: string = ''
  private static lastDurationMs: number = 0
  private static successCount: number = 0
  private static failCount: number = 0
  private static outboxPending: number = 0

  /** 开始批量本地写：取消已排队的写后同步，期间不再 scheduleAfterWrite */
  static beginBulkWrite(): void {
    SyncScheduler.bulkDepth = SyncScheduler.bulkDepth + 1
    if (SyncScheduler.timerId !== -1) {
      clearTimeout(SyncScheduler.timerId)
      SyncScheduler.timerId = -1
    }
  }

  /**
   * 结束批量写：深度归零后开启导入宽限期，并统一 debounce 同步一次。
   * 嵌套调用时仅最外层 end 会真正调度。
   */
  static endBulkWrite(): void {
    if (SyncScheduler.bulkDepth > 0) {
      SyncScheduler.bulkDepth = SyncScheduler.bulkDepth - 1
    }
    if (SyncScheduler.bulkDepth === 0) {
      // 宽限期挂在 SyncService，避免 Scheduler↔Service 循环依赖
      SyncService.markImportGrace(120000)
      SyncScheduler.scheduleAfterWrite()
    }
  }

  /** 写路径：本地落库后调用（debounce 合并连点） */
  static scheduleAfterWrite(): void {
    SyncScheduler.schedule('write', SyncScheduler.WRITE_DEBOUNCE_MS)
  }

  /** 首页 loadHome 是否已完成（冷启动 Ability.onForeground 用此避免抢库） */
  static isHomeHydrated(): boolean {
    return SyncScheduler.homeHydrated
  }

  /** 回前台 / 进主页：首页未就绪或冷却内跳过，避免与 loadHome 抢 RDB */
  static scheduleForeground(): void {
    if (!SyncScheduler.homeHydrated) {
      return
    }
    if (Date.now() - SyncScheduler.lastSyncFinishedAt < SyncScheduler.FOREGROUND_COOLDOWN_MS) {
      return
    }
    SyncScheduler.schedule('foreground', SyncScheduler.FOREGROUND_DEBOUNCE_MS)
  }

  /** 进主页立即排队（仍走单飞，不挡 UI） */
  static scheduleEnterMain(): void {
    SyncScheduler.schedule('enter_main', 0)
  }

  /**
   * 进主页：等首页 hydrate 完成后再同步，避免与 loadHome 抢 RDB。
   * 超时 HOME_READY_FALLBACK_MS 仍发起，防止空首页永不同步。
   */
  static scheduleEnterMainWhenHomeReady(): void {
    if (SyncScheduler.homeHydrated) {
      SyncScheduler.schedule('enter_main', 200)
      return
    }
    SyncScheduler.pendingEnterMain = true
    if (SyncScheduler.homeWaitTimerId !== -1) {
      return
    }
    SyncScheduler.homeWaitTimerId = setTimeout((): void => {
      SyncScheduler.homeWaitTimerId = -1
      if (SyncScheduler.pendingEnterMain) {
        SyncScheduler.pendingEnterMain = false
        SyncScheduler.schedule('enter_main', 0)
      }
    }, SyncScheduler.HOME_READY_FALLBACK_MS) as number
  }

  /** 首页 loadHome 完成：放行排队中的 enter_main */
  static markHomeHydrated(): void {
    SyncScheduler.homeHydrated = true
    if (SyncScheduler.homeWaitTimerId !== -1) {
      clearTimeout(SyncScheduler.homeWaitTimerId)
      SyncScheduler.homeWaitTimerId = -1
    }
    if (SyncScheduler.pendingEnterMain) {
      SyncScheduler.pendingEnterMain = false
      SyncScheduler.schedule('enter_main', 200)
    }
  }

  /** 离开主页 / 登出时复位，避免下次误判已 hydrate */
  static resetHomeHydrated(): void {
    SyncScheduler.homeHydrated = false
    SyncScheduler.pendingEnterMain = false
    if (SyncScheduler.homeWaitTimerId !== -1) {
      clearTimeout(SyncScheduler.homeWaitTimerId)
      SyncScheduler.homeWaitTimerId = -1
    }
  }

  /** 网络恢复 */
  static scheduleNetwork(): void {
    SyncScheduler.schedule('net', SyncScheduler.NET_DEBOUNCE_MS)
  }

  /**
   * 通用调度。debounceMs≤0 则尽快 flush（仍尊重单飞）。
   * bulkDepth>0 时忽略（含 write/foreground/realtime/pulse），避免导入中途同步。
   */
  static schedule(reason: string = '', debounceMs: number = SyncScheduler.DEFAULT_DEBOUNCE_MS): void {
    if (SyncScheduler.bulkDepth > 0) {
      return
    }
    if (reason.length > 0) {
      SyncScheduler.lastScheduleReason = reason
    }
    if (SyncScheduler.timerId !== -1) {
      clearTimeout(SyncScheduler.timerId)
      SyncScheduler.timerId = -1
    }
    const delay = debounceMs > 0 ? debounceMs : 0
    if (delay === 0) {
      SyncScheduler.flush()
      return
    }
    SyncScheduler.timerId = setTimeout((): void => {
      SyncScheduler.timerId = -1
      SyncScheduler.flush()
    }, delay)
  }

  /** 设置页据此判断能否再点；勿与 UI 本地 syncRunning 脱节 */
  static isRunning(): boolean {
    return SyncScheduler.running
  }

  /**
   * 同步中超过上限就必须离开「同步中」，否则设置页会一直转圈。
   */
  static shouldReleaseSyncingUi(phase: string, elapsedMs: number, maxMs: number): boolean {
    return phase === 'syncing' && elapsedMs >= maxMs
  }

  /** 手动立即同步（设置页「云端同步」点击） */
  static async runNow(): Promise<SyncResult> {
    if (SyncScheduler.timerId !== -1) {
      clearTimeout(SyncScheduler.timerId)
      SyncScheduler.timerId = -1
    }
    if (SyncScheduler.running) {
      return new SyncResult(false, '同步进行中')
    }
    return SyncScheduler.execute(true)
  }

  static getSnapshot(): SyncStatusSnapshot {
    const s = new SyncStatusSnapshot()
    s.phase = SyncScheduler.phase
    s.direction = SyncScheduler.direction
    s.lastSuccessAt = SyncScheduler.lastSuccessAt
    s.lastMessage = SyncScheduler.lastMessage
    s.lastError = SyncScheduler.lastError
    s.lastDurationMs = SyncScheduler.lastDurationMs
    s.successCount = SyncScheduler.successCount
    s.failCount = SyncScheduler.failCount
    s.outboxPending = SyncScheduler.outboxPending
    return s
  }

  /** 面向 UI 的状态文案 */
  static statusLabel(): string {
    if (SyncScheduler.phase === 'syncing') {
      return '正在同步…'
    }
    if (SyncScheduler.phase === 'error' && SyncScheduler.lastError.length > 0) {
      return SyncScheduler.lastError
    }
    if (SyncScheduler.phase === 'ok' && SyncScheduler.lastSuccessAt.length > 0) {
      const msg = SyncScheduler.lastMessage.length > 0 ? SyncScheduler.lastMessage : '已同步'
      return '上次成功 ' + SyncScheduler.formatShortTime(SyncScheduler.lastSuccessAt) + ' · ' + msg
    }
    if (SyncScheduler.lastSuccessAt.length > 0) {
      return '上次成功 ' + SyncScheduler.formatShortTime(SyncScheduler.lastSuccessAt)
    }
    return '尚未同步'
  }

  /** P2-4：可观测摘要行 */
  static observabilityLabel(): string {
    const snap = SyncScheduler.getSnapshot()
    const parts: string[] = []
    if (snap.lastDurationMs > 0) {
      parts.push('耗时 ' + snap.lastDurationMs + 'ms')
    }
    parts.push('成功 ' + snap.successCount)
    parts.push('失败 ' + snap.failCount)
    parts.push('待推 ' + snap.outboxPending)
    return parts.join(' · ')
  }

  /** P2-3：前台驻留时周期补同步（幂等）；首轮延迟 PULSE_GRACE_MS，避免开屏抢库 */
  static startForegroundPulse(): void {
    if (SyncScheduler.pulseTimerId !== -1) {
      return
    }
    SyncScheduler.pulseTimerId = setTimeout((): void => {
      SyncScheduler.pulseTimerId = -1
      const bg = AppStorage.get<boolean>(AppStorageKeys.APP_IN_BACKGROUND)
      if (bg !== true) {
        SyncScheduler.schedule('pulse', 0)
      }
      SyncScheduler.armPulse()
    }, SyncScheduler.PULSE_GRACE_MS) as number
  }

  private static armPulse(): void {
    if (SyncScheduler.pulseTimerId !== -1) {
      return
    }
    SyncScheduler.pulseTimerId = setTimeout((): void => {
      SyncScheduler.pulseTimerId = -1
      const bg = AppStorage.get<boolean>(AppStorageKeys.APP_IN_BACKGROUND)
      if (bg === true) {
        return
      }
      SyncScheduler.schedule('pulse', 0)
      SyncScheduler.armPulse()
    }, SyncScheduler.PULSE_INTERVAL_MS)
  }

  static stopForegroundPulse(): void {
    if (SyncScheduler.pulseTimerId !== -1) {
      clearTimeout(SyncScheduler.pulseTimerId)
      SyncScheduler.pulseTimerId = -1
    }
  }

  /**
   * 注册网络恢复回调（幂等）。无网→有网时 schedule。
   * 在 EntryAbility 首次前台调用即可。
   */
  static ensureNetWatch(): void {
    if (SyncScheduler.netWatchStarted) {
      return
    }
    SyncScheduler.netWatchStarted = true
    try {
      const netConnection = connection.createNetConnection()
      netConnection.register((_err: Object) => {
        // 注册失败时静默；前台调度仍覆盖
      })
      netConnection.on('netAvailable', () => {
        SyncScheduler.scheduleNetwork()
      })
    } catch (e) {
      Logger.error('SyncScheduler', 'netWatch: ' + JSON.stringify(e))
    }
  }

  private static flush(): void {
    SyncScheduler.execute(false).catch((e: Object) => {
      Logger.error('SyncScheduler', 'flush: ' + JSON.stringify(e))
    })
  }

  private static lastScheduleReason: string = 'schedule'

  private static mapTrigger(manual: boolean): string {
    if (manual) {
      return 'manual'
    }
    const r = SyncScheduler.lastScheduleReason
    if (r === 'realtime') {
      return 'realtime'
    }
    if (r === 'foreground' || r === 'enter_main' || r === 'launch') {
      return 'launch'
    }
    return 'schedule'
  }

  private static async execute(manual: boolean): Promise<SyncResult> {
    if (SyncScheduler.running) {
      SyncScheduler.rerun = true
      return new SyncResult(false, '同步进行中')
    }
    SyncScheduler.running = true
    const startedAt = Date.now()
    /** 是否真正进入 syncing 相位（用于前台冷却记录） */
    let attempted = false

    let result = new SyncResult(false, '未执行')
    let watchId: number = -1
    try {
      // DB 未就绪（Splash 前 onForeground）：静默跳过，不写 error 态
      if (!DbService.isReady()) {
        result = new SyncResult(false, 'DB 未就绪')
        return result
      }
      // 判断本轮主方向：outbox 有待推=上传(↑)，否则下载(↓)
      try {
        const pending = await SyncOutbox.listAllPending()
        SyncScheduler.direction = pending.length > 0 ? 'up' : 'down'
      } catch {
        SyncScheduler.direction = 'down'
      }
      SyncScheduler.setPhase('syncing', '', '')
      attempted = true
      watchId = setTimeout((): void => {
        if (SyncScheduler.shouldReleaseSyncingUi(SyncScheduler.phase, SyncScheduler.MAX_SYNC_UI_MS,
          SyncScheduler.MAX_SYNC_UI_MS)) {
          SyncScheduler.setPhase('error', '', '同步超时，请检查网络后重试')
        }
      }, SyncScheduler.MAX_SYNC_UI_MS) as number
      const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
      if (!settings.cloud_sync_enabled) {
        result = new SyncResult(false, '未开启云同步')
        SyncScheduler.setPhase('idle', '', '')
        return result
      }
      const session = await AuthManager.loadSession()
      if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
        result = new SyncResult(false, '未登录云端')
        SyncScheduler.setPhase('idle', '', '')
        return result
      }

      result = await SyncService.syncAll()
      if (result.success) {
        const at = SyncScheduler.nowIso()
        SyncScheduler.lastSuccessAt = at
        SyncScheduler.successCount = SyncScheduler.successCount + 1
        SyncScheduler.setPhase('ok', result.message, '')
        // 仅当本轮从云拉到数据时才整表刷新 UI。
        // 纯推送成功（导入后常见「推送 N / 拉取 0」）：本机已是真源，再 invalidate+notify
        // 易触发并发 loadData 竞态，体感像「同步成功后列表退回旧数据」。
        const pulled = SyncService.sumPulled(result.stats)
        if (pulled > 0) {
          LocalDataStore.invalidateAll()
          SettingsService.clearCache()
          Constants.notifyListRefresh()
        }
      } else {
        SyncScheduler.failCount = SyncScheduler.failCount + 1
        const friendly = ErrorMessages.userFacing(result.message, ErrorMessages.SYNC_FAILED)
        SyncScheduler.setPhase('error', '', friendly)
        if (manual && friendly === ErrorMessages.SYNC_AUTH_EXPIRED) {
          result = new SyncResult(false, friendly, result.stats)
        } else if (manual) {
          result = new SyncResult(false, friendly, result.stats)
        }
      }
      return result
    } catch (e) {
      SyncScheduler.failCount = SyncScheduler.failCount + 1
      const detail = e instanceof Error ? e.message : JSON.stringify(e)
      const friendly = ErrorMessages.userFacing(detail, ErrorMessages.SYNC_FAILED)
      SyncScheduler.setPhase('error', '', friendly)
      result = new SyncResult(false, friendly)
      return result
    } finally {
      if (watchId !== -1) {
        try {
          clearTimeout(watchId)
        } catch (_w) {
        }
      }
      SyncScheduler.lastDurationMs = Date.now() - startedAt
      // 仅真正发起过同步的轮次才记冷却，避免 rerun/DB 未就绪误锁前台触发
      if (attempted) {
        SyncScheduler.lastSyncFinishedAt = Date.now()
      }
      try {
        // 与 flush 一致扫全表，避免 user_id 不一致时 UI「待推 15」与真实 flush 脱节
        const pending = await SyncOutbox.listAllPending()
        SyncScheduler.outboxPending = pending.length
      } catch {
        SyncScheduler.outboxPending = 0
      }
      SyncScheduler.publish()
      // 仅真正尝试过同步时记结果（跳过 DB 未就绪 / 未登录 等静默路径也记，便于漏斗）
      if (attempted || result.message.length > 0) {
        const trigger = SyncScheduler.mapTrigger(manual)
        AnalyticsService.trackSyncResult(result.success, trigger, result.success ? '' : result.message)
      }
      SyncScheduler.running = false
      if (SyncScheduler.rerun) {
        SyncScheduler.rerun = false
        SyncScheduler.schedule('rerun', 200)
      }
    }
  }

  private static setPhase(phase: SyncPhase, message: string, error: string): void {
    SyncScheduler.phase = phase
    if (message.length > 0) {
      SyncScheduler.lastMessage = message
    }
    if (phase === 'error') {
      SyncScheduler.lastError = error
    } else if (phase === 'ok' || phase === 'syncing') {
      SyncScheduler.lastError = ''
    }
    SyncScheduler.publish()
  }

  private static publish(): void {
    try {
      AppStorage.setOrCreate(AppStorageKeys.SYNC_PHASE, SyncScheduler.phase)
      AppStorage.setOrCreate(AppStorageKeys.SYNC_LAST_SUCCESS_AT, SyncScheduler.lastSuccessAt)
      AppStorage.setOrCreate(AppStorageKeys.SYNC_LAST_MESSAGE, SyncScheduler.lastMessage)
      AppStorage.setOrCreate(AppStorageKeys.SYNC_LAST_ERROR, SyncScheduler.lastError)
      const prev = AppStorage.get<number>(AppStorageKeys.SYNC_REVISION) ?? 0
      AppStorage.setOrCreate(AppStorageKeys.SYNC_REVISION, prev + 1)
    } catch (_e) {
      // AppStorage 未就绪时忽略
    }
  }

  private static nowIso(): string {
    const d = new Date()
    const pad = (n: number): string => (n < 10 ? '0' + n : '' + n)
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) +
      ' ' + pad(d.getHours()) + ':' + pad(d.getMinutes())
  }

  private static formatShortTime(isoLike: string): string {
    // 已是 "YYYY-MM-DD HH:mm" 则直接展示后半；否则原样
    if (isoLike.length >= 16 && isoLike.indexOf(' ') > 0) {
      return isoLike.substring(5) // MM-DD HH:mm
    }
    return isoLike
  }

  private static sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout((): void => {
        resolve()
      }, ms)
    })
  }
}
