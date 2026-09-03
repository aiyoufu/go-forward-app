/**
 * P2-1/2：进程内数据投影 + 首页轻量落盘帧
 * - 写路径 / 同步成功后 invalidate，UI 仍以 RDB 为准 revalidate
 * - 有缓存时 Tab 可先秒开再静默刷新
 */
import { Debt } from 'common'
import { Subscription } from 'common'
import { CreditAccount } from 'common'
import { AchievementCard } from 'common'
import { MonthlyPressure } from 'common'
import { PreferencesService } from '../PreferencesService'
import { DashboardSummary } from '../DashboardTypes'

/** 首页冷启动可序列化帧（仅关键数字，非完整 Summary / 不含行动列表） */
export class DashboardFrameCache {
  remainingDebt: number = 0
  thisMonthDue: number = 0
  nextMonthDue: number = 0
  activeDebtCount: number = 0
  subscriptionCount: number = 0
  subscriptionTotalAmount: number = 0
  creditAccountCount: number = 0
  progressPercent: number = 0
  hasRepaymentRecords: boolean = false
  monthPaid: number = 0
  /** 金额卡辅行：今日应还（分） */
  todayDueAmount: number = 0
  /** 金额卡辅行：逾期笔数 */
  overdueCount: number = 0
  /** 金额卡辅行：预计还清日期（YYYY-MM） */
  payoffDate: string = ''

  static fromSummary(s: DashboardSummary, monthPaid: number): DashboardFrameCache {
    const f = new DashboardFrameCache()
    f.remainingDebt = s.remainingDebt
    f.thisMonthDue = s.thisMonthDue
    f.nextMonthDue = s.nextMonthDue
    f.activeDebtCount = s.activeDebtCount
    f.subscriptionCount = s.subscriptionCount
    f.subscriptionTotalAmount = s.subscriptionTotalAmount
    f.creditAccountCount = s.creditAccountCount
    f.progressPercent = s.progressPercent
    f.hasRepaymentRecords = s.hasRepaymentRecords
    f.monthPaid = monthPaid
    f.todayDueAmount = s.todayDueAmount
    f.overdueCount = s.overdueCount
    f.payoffDate = s.payoffDate
    return f
  }

  /** 填入空 Summary，供首页先画一帧 */
  applyTo(summary: DashboardSummary): void {
    summary.remainingDebt = this.remainingDebt
    summary.thisMonthDue = this.thisMonthDue
    summary.nextMonthDue = this.nextMonthDue
    summary.activeDebtCount = this.activeDebtCount
    summary.subscriptionCount = this.subscriptionCount
    summary.subscriptionTotalAmount = this.subscriptionTotalAmount
    summary.creditAccountCount = this.creditAccountCount
    summary.progressPercent = this.progressPercent
    summary.hasRepaymentRecords = this.hasRepaymentRecords
    summary.todayDueAmount = this.todayDueAmount
    summary.overdueCount = this.overdueCount
    summary.payoffDate = this.payoffDate
  }
}

export class LocalDataStore {
  private static readonly PREF_DASH_FRAME: string = 'local_data_dash_frame_v1'

  private static ownerUserId: string = ''
  private static debts: Debt[] | null = null
  private static subscriptions: Subscription[] | null = null
  private static accounts: CreditAccount[] | null = null
  private static achievements: AchievementCard[] | null = null
  private static summary: DashboardSummary | null = null
  private static pressure: MonthlyPressure[] | null = null
  private static debtTrend: number[] | null = null
  private static monthPaid: number = -1
  private static revision: number = 0
  /**
   * 失效世代：invalidate 时递增。
   * Tab 并发 loadData 若在 await 期间发生过 invalidate，不得把过期查询结果写回投影。
   */
  private static epoch: number = 0

  /** 投影失效世代（供 UI hydrate 丢弃过期结果） */
  static getEpoch(): number {
    return LocalDataStore.epoch
  }

  static bumpRevision(): void {
    LocalDataStore.revision = LocalDataStore.revision + 1
  }

  private static bumpEpoch(): void {
    LocalDataStore.epoch = LocalDataStore.epoch + 1
  }

  /** 全量失效（同步成功后 / 清空数据） */
  static invalidateAll(): void {
    LocalDataStore.bumpEpoch()
    LocalDataStore.ownerUserId = ''
    LocalDataStore.debts = null
    LocalDataStore.subscriptions = null
    LocalDataStore.accounts = null
    LocalDataStore.achievements = null
    LocalDataStore.summary = null
    LocalDataStore.pressure = null
    LocalDataStore.debtTrend = null
    LocalDataStore.monthPaid = -1
    LocalDataStore.bumpRevision()
  }

  /** 负债域（含还款、成就、首页摘要依赖） */
  static invalidateDebts(): void {
    LocalDataStore.bumpEpoch()
    LocalDataStore.debts = null
    LocalDataStore.achievements = null
    LocalDataStore.summary = null
    LocalDataStore.pressure = null
    LocalDataStore.debtTrend = null
    LocalDataStore.monthPaid = -1
    LocalDataStore.bumpRevision()
  }

  static invalidateSubscriptions(): void {
    LocalDataStore.bumpEpoch()
    LocalDataStore.subscriptions = null
    LocalDataStore.summary = null
    LocalDataStore.pressure = null
    LocalDataStore.bumpRevision()
  }

  static invalidateAccounts(): void {
    LocalDataStore.bumpEpoch()
    LocalDataStore.accounts = null
    LocalDataStore.summary = null
    LocalDataStore.bumpRevision()
  }

  /**
   * 仅当 hydrate 期间未再发生 invalidate 时写回投影，防止旧查询污染缓存。
   * 返回 false 表示已过期，调用方应丢弃本次结果、勿再 set。
   */
  static isEpochCurrent(epochAtStart: number): boolean {
    return epochAtStart === LocalDataStore.epoch
  }

  /** 导入/清空后抹掉落盘首页帧，避免冷启动秒开到导入前数字 */
  static async clearDashboardFrame(userId: string = ''): Promise<void> {
    try {
      await PreferencesService.putString(LocalDataStore.PREF_DASH_FRAME, '')
      if (userId.length > 0) {
        await PreferencesService.putString(LocalDataStore.frameKey(userId), '')
      }
    } catch {
    }
  }

  private static frameKey(userId: string): string {
    return LocalDataStore.PREF_DASH_FRAME + ':' + userId
  }

  private static bindOwner(userId: string): boolean {
    if (userId.length === 0) {
      return false
    }
    if (LocalDataStore.ownerUserId.length === 0) {
      LocalDataStore.ownerUserId = userId
      return true
    }
    return LocalDataStore.ownerUserId === userId
  }

  // —— Debts ——
  static getDebts(userId: string = ''): Debt[] | null {
    if (userId.length > 0 && LocalDataStore.ownerUserId !== userId) {
      return null
    }
    return LocalDataStore.debts
  }

  static setDebts(list: Debt[], userId: string = ''): void {
    if (userId.length > 0 && !LocalDataStore.bindOwner(userId)) {
      return
    }
    LocalDataStore.debts = list
  }

  // —— Subscriptions ——
  static getSubscriptions(userId: string = ''): Subscription[] | null {
    if (userId.length > 0 && LocalDataStore.ownerUserId !== userId) {
      return null
    }
    return LocalDataStore.subscriptions
  }

  static setSubscriptions(list: Subscription[], userId: string = ''): void {
    if (userId.length > 0 && !LocalDataStore.bindOwner(userId)) {
      return
    }
    LocalDataStore.subscriptions = list
  }

  // —— Credit accounts ——
  static getAccounts(userId: string = ''): CreditAccount[] | null {
    if (userId.length > 0 && LocalDataStore.ownerUserId !== userId) {
      return null
    }
    return LocalDataStore.accounts
  }

  static setAccounts(list: CreditAccount[], userId: string = ''): void {
    if (userId.length > 0 && !LocalDataStore.bindOwner(userId)) {
      return
    }
    LocalDataStore.accounts = list
  }

  // —— Achievements ——
  static getAchievements(): AchievementCard[] | null {
    return LocalDataStore.achievements
  }

  static setAchievements(list: AchievementCard[]): void {
    LocalDataStore.achievements = list
  }

  // —— Dashboard ——
  static getSummary(): DashboardSummary | null {
    return LocalDataStore.summary
  }

  static setSummary(s: DashboardSummary): void {
    LocalDataStore.summary = s
  }

  static getPressure(): MonthlyPressure[] | null {
    return LocalDataStore.pressure
  }

  static setPressure(list: MonthlyPressure[]): void {
    LocalDataStore.pressure = list
  }

  static getDebtTrend(): number[] | null {
    return LocalDataStore.debtTrend
  }

  static setDebtTrend(list: number[]): void {
    LocalDataStore.debtTrend = list
  }

  static getMonthPaid(): number {
    return LocalDataStore.monthPaid
  }

  static setMonthPaid(v: number): void {
    LocalDataStore.monthPaid = v
  }

  /** 写盘首页帧（Preferences 已 init 后调用） */
  static async persistDashboardFrame(s: DashboardSummary, monthPaid: number, userId: string = ''): Promise<void> {
    try {
      const f = DashboardFrameCache.fromSummary(s, monthPaid)
      const json = JSON.stringify({
        remainingDebt: f.remainingDebt,
        thisMonthDue: f.thisMonthDue,
        nextMonthDue: f.nextMonthDue,
        activeDebtCount: f.activeDebtCount,
        subscriptionCount: f.subscriptionCount,
        subscriptionTotalAmount: f.subscriptionTotalAmount,
        creditAccountCount: f.creditAccountCount,
        progressPercent: f.progressPercent,
        hasRepaymentRecords: f.hasRepaymentRecords,
        monthPaid: f.monthPaid,
        todayDueAmount: f.todayDueAmount,
        overdueCount: f.overdueCount
      })
      const key = userId.length > 0 ? LocalDataStore.frameKey(userId) : LocalDataStore.PREF_DASH_FRAME
      await PreferencesService.putString(key, json)
    } catch {
    }
  }

  /** 读盘首页帧；失败返回 null */
  static async loadDashboardFrame(userId: string = ''): Promise<DashboardFrameCache | null> {
    try {
      const key = userId.length > 0 ? LocalDataStore.frameKey(userId) : LocalDataStore.PREF_DASH_FRAME
      const raw = await PreferencesService.getString(key, '')
      if (raw.length === 0) {
        return null
      }
      const o = JSON.parse(raw) as Record<string, number>
      const f = new DashboardFrameCache()
      f.remainingDebt = Number(o['remainingDebt']) || 0
      f.thisMonthDue = Number(o['thisMonthDue']) || 0
      f.nextMonthDue = Number(o['nextMonthDue']) || 0
      f.activeDebtCount = Number(o['activeDebtCount']) || 0
      f.subscriptionCount = Number(o['subscriptionCount']) || 0
      f.subscriptionTotalAmount = Number(o['subscriptionTotalAmount']) || 0
      f.creditAccountCount = Number(o['creditAccountCount']) || 0
      f.progressPercent = Number(o['progressPercent']) || 0
      f.hasRepaymentRecords = Boolean(o['hasRepaymentRecords'])
      f.monthPaid = Number(o['monthPaid']) || 0
      f.todayDueAmount = Number(o['todayDueAmount']) || 0
      f.overdueCount = Number(o['overdueCount']) || 0
      return f
    } catch {
      return null
    }
  }
}
