import { Debt } from 'common'
import { Subscription } from 'common'
import { CreditAccount } from 'common'
import { PaymentRecord } from 'common'
import { Utils } from 'common'
import { DebtService } from './DebtService'
import { SubscriptionService } from './SubscriptionService'
import { CreditAccountService } from './CreditAccountService'
import { CalculationService } from './CalculationService'
import { PaymentService } from './PaymentService'
import { MonthlyPressure } from 'common'
import { HomeActionBuckets, HomeActionItems } from './HomeActionItems'
import { DashboardSummary, DashboardHomeSnapshot } from './DashboardTypes'

export class DashboardService {
  /**
   * 首页首屏：三表各读一次（可命中 LocalDataStore），内存派生全部 UI 数据。
   * 避免 getSummary + pressure + buckets 三次扫 debts。
   */
  static async loadHome(userId: string): Promise<DashboardHomeSnapshot> {
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)
    const accounts = await CreditAccountService.getCreditAccounts(userId)
    const snap = new DashboardHomeSnapshot()
    snap.summary = await DashboardService.buildSummaryFrom(userId, debts, subscriptions, accounts)
    snap.pressure = CalculationService.calculateMonthlyPressure(debts, subscriptions, 6)
    snap.buckets = HomeActionItems.buildBuckets(debts, subscriptions, accounts, Utils.todayString())
    snap.monthPaid = await PaymentService.getCurrentMonthPaid(userId)
    snap.debtTrend = DashboardService.calculateDebtPaydownTrend(snap.summary.remainingDebt, snap.pressure)
    return snap
  }

  /**
   * 待还消减走势（首页待还总览卡 sparkline 序列）
   * 从当前总待还出发，按各月应还金额递减，至 0 截止；始终呈现单调下降（向好）的平滑消减曲线。
   */
  static calculateDebtPaydownTrend(remainingDebt: number, pressure: MonthlyPressure[]): number[] {
    if (remainingDebt <= 0) {
      return []
    }
    const points: number[] = [remainingDebt]
    let current = remainingDebt
    for (let i = 0; i < pressure.length; i++) {
      if (current <= 0) {
        break
      }
      const paid = pressure[i].debtAmount
      if (paid > 0) {
        current = Math.max(0, current - paid)
        points.push(current)
      }
    }
    if (points.length < 2) {
      points.push(0)
    }
    return points
  }

  static async getSummary(userId: string): Promise<DashboardSummary> {
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)
    const accounts = await CreditAccountService.getCreditAccounts(userId)
    return DashboardService.buildSummaryFrom(userId, debts, subscriptions, accounts)
  }

  /** 由已加载三表组装 Summary（无额外扫 debts） */
  static async buildSummaryFrom(
    userId: string,
    debts: Debt[],
    subscriptions: Subscription[],
    accounts: CreditAccount[]
  ): Promise<DashboardSummary> {
    const summary = new DashboardSummary()
    const today = Utils.todayString()

    for (const d of debts) {
      summary.totalDebt += d.principal
      summary.remainingDebt += d.current_balance
      if (d.status === 'active') {
        summary.activeDebtCount++
        if (d.next_payment_date === today) {
          summary.todayDueCount++
          summary.todayDueAmount += CalculationService.currentPeriodDue(d)
        } else if (d.next_payment_date < today) {
          summary.overdueCount++
        }
        if (d.estimated_end_date.length > 0 &&
          (summary.payoffDate.length === 0 || d.estimated_end_date > summary.payoffDate)) {
          summary.payoffDate = d.estimated_end_date
        }
      } else if (d.status === 'completed') {
        summary.completedDebtCount++
      }
    }
    // 仅展示到月份粒度，避免日频变动引起视觉抖动
    if (summary.payoffDate.length >= 7) {
      summary.payoffDate = summary.payoffDate.substring(0, 7)
    }

    summary.totalPaid = summary.totalDebt - summary.remainingDebt
    summary.progressPercent = summary.totalDebt > 0
      ? Math.round((summary.totalPaid / summary.totalDebt) * 100)
      : 0

    summary.subscriptionCount = subscriptions.filter(s => s.status === 'active').length
    summary.subscriptionTotalAmount = SubscriptionService.calculateTotalSubscriptionAmount(subscriptions)
    summary.subscriptionCycleBreakdown = SubscriptionService.groupByBillingCycle(subscriptions)
    summary.subscriptionDistribution = DashboardService.buildSubscriptionDistribution(subscriptions)
    summary.debtDistribution = DashboardService.buildDebtDistribution(debts)

    summary.creditAccountCount = accounts.length
    for (const a of accounts) {
      summary.totalCreditLimit += a.credit_limit
    }

    // 当月 / 下月应还
    const now = new Date()
    const thisMonthKey = now.getFullYear() + '-' +
      (now.getMonth() + 1 < 10 ? '0' + (now.getMonth() + 1) : '' + (now.getMonth() + 1))
    const nextDate = new Date(now.getFullYear(), now.getMonth() + 1, 1)
    const nextMonthKey = nextDate.getFullYear() + '-' +
      (nextDate.getMonth() + 1 < 10 ? '0' + (nextDate.getMonth() + 1) : '' + (nextDate.getMonth() + 1))

    // 压力图仍含关联订阅月摊；首页主数字只用负债（见下行赋值）
    // 本月口径叠加逾期累积（currentMonthKey = thisMonthKey），下月仍按单期
    const thisDue = CalculationService.getDueAmountForMonth(debts, subscriptions, thisMonthKey, thisMonthKey)
    const nextDue = CalculationService.getDueAmountForMonth(debts, subscriptions, nextMonthKey, thisMonthKey)
    // 首页「本月待还」仅负债现金流（规格 2026-08-12）；订阅月摊仍进压力图，不抬主数字
    summary.thisMonthDue = thisDue.debtAmount
    summary.nextMonthDue = nextDue.debtAmount

    // 最近到期订阅（活跃，按 next_billing_date 升序）
    const activeSubs = subscriptions
      .filter(s => s.status === 'active' && s.next_billing_date.length > 0)
      .sort((a, b) => a.next_billing_date < b.next_billing_date ? -1 :
        (a.next_billing_date > b.next_billing_date ? 1 : 0))
    if (activeSubs.length > 0) {
      const ns = activeSubs[0]
      summary.nextSubscriptionName = ns.name
      summary.nextSubscriptionDate = ns.next_billing_date
    }

    // 统计即将到期/已过期的订阅
    let expiredCount = 0
    let minDays = -1
    let expiringSubs = 0

    for (const s of subscriptions) {
      if (s.status === 'active' && s.next_billing_date.length > 0) {
        const days = Utils.daysFromNow(s.next_billing_date)
        if (days < 0) {
          expiredCount++
        } else {
          if (minDays === -1 || days < minDays) {
            minDays = days
            expiringSubs = 1
          } else if (days === minDays) {
            expiringSubs++
          }
        }
      }
    }

    if (expiredCount > 0) {
      summary.expiringSubscriptionCount = expiredCount
      summary.expiringSubscriptionDays = -1
      summary.expiringSubscriptionLabel = expiredCount + '个已过期'
    } else if (minDays !== -1) {
      summary.expiringSubscriptionCount = expiringSubs
      summary.expiringSubscriptionDays = minDays
      if (minDays === 0) {
        summary.expiringSubscriptionLabel = expiringSubs + '个今天到期'
      } else if (minDays === 1) {
        summary.expiringSubscriptionLabel = expiringSubs + '个明天到期'
      } else {
        summary.expiringSubscriptionLabel = expiringSubs + '个' + minDays + '天后到期'
      }
    } else {
      summary.expiringSubscriptionCount = 0
      summary.expiringSubscriptionDays = -1
      summary.expiringSubscriptionLabel = ''
    }

    // 即将过期账户：到期日在今天起 180 天内（含今天），按到期升序
    // expiry_date 可能是 MM/YY / YYYY-MM / YYYY-MM-DD，须规范后再比日差
    const expiring: string[] = []
    const sortedAcc = accounts
      .filter(a => a.expiry_date !== undefined && a.expiry_date.length > 0)
      .slice()
      .sort((a, b) => {
        const ay = Utils.creditCardExpiryToYmd(a.expiry_date)
        const by = Utils.creditCardExpiryToYmd(b.expiry_date)
        return ay < by ? -1 : (ay > by ? 1 : 0)
      })
    for (const a of sortedAcc) {
      const expiryYmd = Utils.creditCardExpiryToYmd(a.expiry_date)
      if (expiryYmd.length === 0) {
        continue
      }
      const days = Utils.daysFromNow(expiryYmd)
      if (days >= 0 && days <= 180) {
        const four = a.last_four.trim().length > 0 ? a.last_four.trim() : '****'
        expiring.push(a.name + ' · ' + four + ' · ' + a.expiry_date)
      }
    }
    summary.expiringAccountLabels = expiring

    summary.hasRepaymentRecords = await PaymentService.hasPaymentRecords(userId)

    return summary
  }

  /**
   * 首页行动项分桶（逾期/今天 vs 未来 1–7 天）
   * 与 getSummary 分次调用时会重复读表；优先用 loadHome。
   */
  static async getHomeActionBuckets(userId: string): Promise<HomeActionBuckets> {
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)
    const accounts = await CreditAccountService.getCreditAccounts(userId)
    return HomeActionItems.buildBuckets(debts, subscriptions, accounts, Utils.todayString())
  }

  static async getMonthlyPressure(userId: string): Promise<MonthlyPressure[]> {
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)
    return CalculationService.calculateMonthlyPressure(debts, subscriptions, 6)
  }

  /**
   * 剩余负债近 N 月走势（首页负债卡 sparkline）
   * - 以当前余额为锚，按还款记录回溯各月末余额：还款→下降，新增负债→上升
   * - 采样点：前 N-1 个月末 + 今天
   * - 仅当上月末与今天均有负债余额（>0）时才返回非空数组，否则返回 []
   * - 「上月是否有债」以 created_at（记录创建日）为准，避免回填 start_date 导致误判
   */
  static async getRemainingDebtTrend(userId: string, months: number = 6): Promise<number[]> {
    const debts = await DebtService.getDebts(userId)
    return DashboardService.getRemainingDebtTrendWithDebts(userId, debts, months)
  }

  static async getRemainingDebtTrendWithDebts(
    userId: string,
    debts: Debt[],
    months: number = 6
  ): Promise<number[]> {
    if (debts.length === 0) {
      return []
    }
    const records = await PaymentService.getRecordsByUser(userId)
    const byDebt = new Map<string, PaymentRecord[]>()
    for (const r of records) {
      const list = byDebt.get(r.debt_id)
      if (list) {
        list.push(r)
      } else {
        byDebt.set(r.debt_id, [r])
      }
    }

    const now = new Date()
    const points: string[] = []
    // 循环外创建，循环内通过 setFullYear 复用，避免重复 new Date
    const d = new Date()
    for (let i = months - 1; i >= 1; i--) {
      // 往前 i 个月的月末：下个月第 0 天
      d.setFullYear(now.getFullYear(), now.getMonth() - i + 1, 0)
      const m = d.getMonth() + 1
      const day = d.getDate()
      points.push(d.getFullYear() + '-' +
        (m < 10 ? '0' + m : '' + m) + '-' +
        (day < 10 ? '0' + day : '' + day))
    }
    points.push(Utils.todayString())

    if (points.length >= 2) {
      const lastMonthEnd = points[points.length - 2]
      let hasLastMonthDebt = false
      for (const d of debts) {
        const recordDate = d.created_at.length > 0 ? d.created_at.substring(0, 10) : d.start_date
        if (recordDate.length === 0 || recordDate <= lastMonthEnd) {
          hasLastMonthDebt = true
          break
        }
      }
      if (!hasLastMonthDebt) {
        return []
      }
    }

    const out: number[] = []
    for (const p of points) {
      let total = 0
      for (const d of debts) {
        // 采样点早于开始日：当时还没有这笔负债
        if (d.start_date.length > 0 && d.start_date > p) {
          continue
        }
        let bal = d.current_balance
        const recs = byDebt.get(d.id)
        if (recs) {
          for (const r of recs) {
            if (r.payment_date > p) {
              bal += r.principal_paid
            }
          }
        }
        if (bal < 0) {
          bal = 0
        }
        total += bal
      }
      out.push(total)
    }
    if (out.length >= 2) {
      if (out[out.length - 2] <= 0 || out[out.length - 1] <= 0) {
        return []
      }
    }

    // 去除负债尚未创建时的前导 0，避免走势图从 0 陡升再回落产生虚假波峰
    let firstNonZero = 0
    while (firstNonZero < out.length && out[firstNonZero] <= 0) {
      firstNonZero++
    }
    const trimmed = firstNonZero > 0 ? out.slice(firstNonZero) : out
    if (trimmed.length < 2) {
      return []
    }
    return trimmed
  }

  static buildSubscriptionDistribution(subscriptions: Subscription[]): Map<string, number> {
    const map = new Map<string, number>()
    for (const s of subscriptions) {
      if (s.status !== 'active') {
        continue
      }
      const current = map.get(s.category) || 0
      map.set(s.category, current + s.amount)
    }
    return map
  }

  static buildDebtDistribution(debts: Debt[]): Map<string, number> {
    const map = new Map<string, number>()
    for (const d of debts) {
      if (d.status !== 'active') {
        continue
      }
      const current = map.get(d.debt_type) || 0
      map.set(d.debt_type, current + d.current_balance)
    }
    return map
  }
}
