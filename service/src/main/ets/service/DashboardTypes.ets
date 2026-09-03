import { MonthlyPressure } from 'common'
import { HomeActionBuckets } from './HomeActionItems'

/** 首页聚合摘要（纯数据类，供 LocalDataStore 缓存与 UI 投影使用） */
export class DashboardSummary {
  totalDebt: number = 0
  totalPaid: number = 0
  remainingDebt: number = 0
  activeDebtCount: number = 0
  completedDebtCount: number = 0
  subscriptionCount: number = 0
  /** 活跃订阅原始金额合计（不按周期折算；季度/年度订阅不会被误算成月费）。 */
  subscriptionTotalAmount: number = 0
  /** 按计费周期分组的金额：cycle -> 原始金额合计，供 UI 展示「每月 ¥X · 一季度 ¥Y」。 */
  subscriptionCycleBreakdown: Map<string, number> = new Map()
  subscriptionDistribution: Map<string, number> = new Map()
  debtDistribution: Map<string, number> = new Map()
  creditAccountCount: number = 0
  totalCreditLimit: number = 0
  todayDueAmount: number = 0
  todayDueCount: number = 0
  overdueCount: number = 0
  progressPercent: number = 0
  /** 是否存在任意还款记录（无记录时首页不展示还款进度条） */
  hasRepaymentRecords: boolean = false
  /** 当月应还（含关联订阅月费，与负债页口径一致） */
  thisMonthDue: number = 0
  /** 下月应还 */
  nextMonthDue: number = 0
  /**
   * 预计还清日期（YYYY-MM）。取所有活跃负债 estimated_end_date 的最晚值；无活跃负债时为空。
   * 月份粒度足够供首页「还清日期」卡片展示。
   */
  payoffDate: string = ''
  /** 最近到期订阅名称 */
  nextSubscriptionName: string = ''
  /** 最近到期订阅日期 YYYY-MM-DD */
  nextSubscriptionDate: string = ''
  /** 即将过期账户文案列表（名称 · 尾号 · 到期日），供轮播 */
  expiringAccountLabels: string[] = []
  /** 即将到期的订阅数量（3天内） */
  expiringSubscriptionCount: number = 0
  /** 距离今天最近的即将到期的订阅天数（负数表示已过期，-1为未定义/无） */
  expiringSubscriptionDays: number = -1
  /** 订阅到期提醒文案 */
  expiringSubscriptionLabel: string = ''
}

/** 首页一次读库快照：summary + 压力 + 行动桶 + 本月已还 */
export class DashboardHomeSnapshot {
  summary: DashboardSummary = new DashboardSummary()
  pressure: MonthlyPressure[] = []
  buckets: HomeActionBuckets = new HomeActionBuckets()
  monthPaid: number = 0
  debtTrend: number[] = []
}
