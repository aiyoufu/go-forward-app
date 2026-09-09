import { Debt, RepaymentMethod, PaymentScheduleItem, MonthlyPressure, MonthlyObligation } from 'common'
import { Subscription, BillingCycle } from 'common'
import { CreditAccount } from 'common'
import { PlatformService } from './platform/PlatformService'

export interface DebtOverdueInfo {
  daysLeft: number
  daysLate: number
  graceDays: number
  isInGracePeriod: boolean
  isBreached: boolean
  isOverdue: boolean
  label: string
}

export class CustomScheduleItem {
  period_number: number = 0
  /** 分 */
  principal: number = 0
  interest: number = 0
  total: number = 0
  /** YYYY-MM-DD，OCR/识别写入；空则预览按下次还款日推算 */
  date: string = ''
  /** 是否已还；识别表有「已还清」时为 true */
  paid: boolean = false
}

/** 解析后的年月（ArkTS 不允许对象字面量作类型） */
class YearMonth {
  year: number = 0
  month: number = 0
}

class CustomScheduleNote {
  custom_schedule: CustomScheduleItem[] | null = null
  text: string = ''
}

export class PaymentSplit {
  principal: number = 0
  interest: number = 0

  constructor(principal: number, interest: number) {
    this.principal = principal
    this.interest = interest
  }
}

/** 待还期数（含当期）与计划起始期号 */
export class PendingPeriodInfo {
  pending: number = 0
  startPeriod: number = 1
}

export class CalculationService {
  static bpToMonthlyRate(annualRateBp: number): number {
    return annualRateBp / 10000 / 12
  }

  static calculatePeriodPayment(
    currentBalance: number,
    annualRateBp: number,
    remainingPeriods: number,
    totalPeriods: number,
    method: RepaymentMethod = 'equal_payment',
    principal: number = 0,
    monthlyPayment: number = 0,
    totalInterest: number = 0
  ): PaymentSplit {
    if (remainingPeriods <= 0) {
      return new PaymentSplit(0, 0)
    }

    // 无利息且无月供时才提前均摊本金；有月供时继续往下拆本金/服务费
    if (annualRateBp === 0 && totalInterest === 0 && monthlyPayment === 0) {
      if (method === 'fixed_interest') {
        const fixedPrincipal = totalPeriods > 0 ? Math.round(principal / totalPeriods) : 0
        if (remainingPeriods === 1) {
          return new PaymentSplit(currentBalance, 0)
        }
        return new PaymentSplit(fixedPrincipal, 0)
      }
      // custom 方法需进入下方分支，从月供推导利息；此处仅对非 custom 做零息本金分摊
      if (method !== 'custom') {
        return new PaymentSplit(Math.round(currentBalance / remainingPeriods), 0)
      }
    }

    const r = CalculationService.bpToMonthlyRate(annualRateBp)

    if (method === 'fixed_interest') {
      const fixedPrincipal = totalPeriods > 0 ? Math.round(principal / totalPeriods) : 0
      const fixedInterest = (monthlyPayment > fixedPrincipal)
        ? (monthlyPayment - fixedPrincipal)
        : (totalPeriods > 0 ? Math.round(totalInterest / totalPeriods) : 0)
      if (remainingPeriods === 1) {
        return new PaymentSplit(currentBalance, fixedInterest)
      }
      return new PaymentSplit(fixedPrincipal, fixedInterest)
    }

    if (method === 'custom') {
      let interest = annualRateBp > 0
        ? Math.round(currentBalance * r)
        : (totalPeriods > 0 ? Math.round(totalInterest / totalPeriods) : 0)
      // 未提供利率/总利息时，若月供高于估算本金，差额视为利息，避免下月应还漏算息费
      const estimatedPrincipal = remainingPeriods === 1
        ? currentBalance
        : (remainingPeriods > 0 ? Math.round(currentBalance / remainingPeriods) : 0)
      if (interest <= 0 && monthlyPayment > estimatedPrincipal) {
        interest = monthlyPayment - estimatedPrincipal
      }
      if (remainingPeriods === 1) {
        return new PaymentSplit(currentBalance, interest)
      }
      const principalPaid = monthlyPayment - interest
      if (principalPaid <= 0) {
        return new PaymentSplit(0, monthlyPayment)
      }
      return new PaymentSplit(principalPaid, interest)
    }

    if (r === 0) {
      const principalPaid = remainingPeriods === 1
        ? currentBalance
        : Math.round(currentBalance / remainingPeriods)
      const interest = Math.max(0, monthlyPayment - principalPaid)
      return new PaymentSplit(principalPaid, interest)
    }

    if (remainingPeriods === 1) {
      // 末期：月供高于剩余本金时差额视为服务费，保证每期应还与月供一致
      const interest = monthlyPayment > currentBalance
        ? monthlyPayment - currentBalance
        : Math.round(currentBalance * r)
      return new PaymentSplit(currentBalance, interest)
    }

    const interest = Math.round(currentBalance * r)
    const computedMonthlyPayment = Math.round(
      (currentBalance * r * Math.pow(1 + r, remainingPeriods)) /
      (Math.pow(1 + r, remainingPeriods) - 1)
    )
    const principalPaid = computedMonthlyPayment - interest
    return new PaymentSplit(principalPaid, interest)
  }

  /**
   * 把 totalFen 均分到 periods 期，余数 1 分优先加在前几期。
   * 与京东白条等「首期多 0.01」一致。
   */
  static distributeFenFront(totalFen: number, periods: number): number[] {
    const out: number[] = []
    if (periods <= 0) {
      return out
    }
    if (totalFen <= 0) {
      for (let i = 0; i < periods; i++) {
        out.push(0)
      }
      return out
    }
    const base = Math.floor(totalFen / periods)
    const rem = totalFen - base * periods
    for (let i = 0; i < periods; i++) {
      out.push(base + (i < rem ? 1 : 0))
    }
    return out
  }

  /**
   * 鸿蒙端 / 2026-07 前：remaining_periods = 待还期数（含当期）。
   * PC 新语义：remaining_periods = 当期之后还剩几期（不含当期）。
   * 用 current_balance 更接近「月供×remaining」还是「月供×(remaining+1)」判断写入口径。
   */
  static usesInclusiveRemainingPeriods(debt: Debt): boolean {
    if (debt.status === 'completed') {
      return false
    }
    if (debt.debt_type !== 'installment') {
      return false
    }
    const remaining = debt.remaining_periods
    const monthly = debt.monthly_payment
    const balance = debt.current_balance
    if (remaining <= 0 || monthly <= 0 || balance <= 0) {
      return false
    }
    const inclusive = monthly * remaining
    const exclusive = monthly * (remaining + 1)
    return Math.abs(balance - inclusive) < Math.abs(balance - exclusive)
  }

  /** 待还期数（含当期）与计划起始期号。兼容鸿蒙端「remaining 含当期」写入。 */
  static getPendingAndStartPeriod(debt: Debt): PendingPeriodInfo {
    const info = new PendingPeriodInfo()
    const remaining = debt.remaining_periods
    const total = debt.total_periods > 0 ? debt.total_periods : remaining
    if (debt.status === 'completed') {
      info.pending = 0
      info.startPeriod = 1
      return info
    }
    if (CalculationService.usesInclusiveRemainingPeriods(debt)) {
      info.pending = Math.max(0, Math.min(remaining, total > 0 ? total : remaining))
      info.startPeriod = Math.max(1, total - remaining + 1)
      return info
    }
    const cap = total > 0 ? total : remaining + 1
    info.pending = Math.max(0, Math.min(remaining + 1, cap))
    info.startPeriod = total > 0 ? Math.max(1, total - remaining) : 1
    return info
  }

  /**
   * 分期剩余未还总额（含当期、含服务费）。
   * equal_payment / fixed_interest：月供 × 待还期数；不能回退成仅本金的 current_balance。
   */
  static getInstallmentRemainingDue(debt: Debt): number {
    if (debt.debt_type !== 'installment') {
      return debt.current_balance
    }
    if (debt.status === 'completed') {
      return 0
    }
    const pending = CalculationService.getPendingAndStartPeriod(debt).pending
    const noteSchedule = CalculationService.parseCustomSchedule(debt.note)
    if (debt.repayment_method !== 'custom' && noteSchedule === null && debt.monthly_payment > 0 && pending > 0) {
      return debt.monthly_payment * pending
    }
    if (pending <= 0 && debt.current_balance > 0 && debt.monthly_payment > 0) {
      return debt.monthly_payment
    }
    return debt.current_balance
  }

  /**
   * 生成剩余待还计划。
   * period_number 使用**绝对期号**（total - remaining + 1 起），与 markPeriodPaid / doRepay 一致；
   * 禁止再用 1..remaining 相对编号（会导致「第 N 期」对不上计划、还款静默失败）。
   */
  static generatePaymentSchedule(debt: Debt): PaymentScheduleItem[] {
    const schedule: PaymentScheduleItem[] = []
    let balance = debt.current_balance
    let currentDate = new Date(debt.next_payment_date)
    // remaining_periods 异常为 0 但仍有余额时，至少生成 1 期便于关单/还款
    const remaining = debt.remaining_periods > 0
      ? debt.remaining_periods
      : (debt.current_balance > 0 ? 1 : 0)
    const startPeriod = debt.total_periods > 0
      ? Math.max(1, debt.total_periods - Math.max(debt.remaining_periods, 0) + 1)
      : 1

    for (let i = 0; i < remaining; i++) {
      const payment = CalculationService.calculatePeriodPayment(
        balance,
        debt.annual_rate_bp,
        remaining - i,
        debt.total_periods,
        debt.repayment_method,
        debt.principal,
        debt.monthly_payment,
        debt.total_interest
      )
      const total = payment.principal + payment.interest
      balance -= payment.principal
      if (balance < 0) {
        balance = 0
      }

      const item = new PaymentScheduleItem()
      item.period_number = startPeriod + i
      item.date = CalculationService.formatDate(currentDate)
      item.principal = payment.principal
      item.interest = payment.interest
      item.total = total
      item.balance_after = balance
      item.status = 'pending'
      schedule.push(item)

      currentDate.setMonth(currentDate.getMonth() + 1)
    }

    return schedule
  }

  static addMonths(date: string | Date, months: number): string {
    const d = new Date('' + date)
    d.setMonth(d.getMonth() + months)
    return CalculationService.formatDate(d)
  }

  /**
   * 预计还清日 = 下次还款日 + (剩余期数 - 1) 月。
   * remaining_periods 为 0 时钳制为 0（即到期日本身），避免算成「到期日 - 1 月」。
   */
  static calculateEstimatedEndDate(next_payment_date: string, remaining_periods: number): string {
    if (!next_payment_date || next_payment_date.length === 0) {
      return ''
    }
    return CalculationService.addMonths(next_payment_date, Math.max(0, remaining_periods - 1))
  }

  static calculateCurrentBalance(
    principal: number,
    monthlyPayment: number,
    totalPeriods: number,
    remainingPeriods: number,
    annualRateBp: number,
    repaymentMethod: RepaymentMethod,
    totalInterest: number
  ): number {
    if (remainingPeriods <= 0) {
      return 0
    }
    if (repaymentMethod === 'fixed_interest') {
      const fixedPrincipal = totalPeriods > 0 ? Math.round(principal / totalPeriods) : 0
      const paidPeriods = totalPeriods - remainingPeriods
      return Math.max(0, principal - fixedPrincipal * paidPeriods)
    }
    if (repaymentMethod === 'custom') {
      return Math.max(0, monthlyPayment * remainingPeriods)
    }
    const r = CalculationService.bpToMonthlyRate(annualRateBp)
    if (r === 0) {
      return Math.max(0, Math.round(principal / totalPeriods) * remainingPeriods)
    }
    const n = remainingPeriods
    const pmt = monthlyPayment
    const balance = Math.round(
      pmt * ((1 - Math.pow(1 + r, -n)) / r)
    )
    return Math.max(0, balance)
  }

  static calculateSuggestedMonthlyPayment(
    principal: number,
    annualRateBp: number,
    totalPeriods: number,
    method: RepaymentMethod = 'equal_payment',
    totalInterest: number = 0
  ): number {
    if (totalPeriods <= 0) {
      return 0
    }
    if (annualRateBp === 0) {
      return Math.round((principal + totalInterest) / totalPeriods)
    }
    const r = CalculationService.bpToMonthlyRate(annualRateBp)
    if (method === 'fixed_interest') {
      const fixedPrincipal = Math.round(principal / totalPeriods)
      const fixedInterest = totalPeriods > 0 ? Math.round(totalInterest / totalPeriods) : 0
      return fixedPrincipal + fixedInterest
    }
    return Math.round(
      (principal * r * Math.pow(1 + r, totalPeriods)) /
      (Math.pow(1 + r, totalPeriods) - 1)
    )
  }

  /**
   * 反推年利率（基点）。输入本金、月供、总期数须同单位（元或分皆可，比例一致即可）。
   * - equal_payment：等额本息 PMT = P*r*(1+r)^n / ((1+r)^n - 1)，二分法求解月利率 r。
   * - fixed_interest / custom：年利率 ≈ 总利息 / 本金 / 年数。totalInterest 缺省时按
   *   monthlyPayment * totalPeriods - principal 推断。
   * 任一参数非法或无利息时返回 0。
   */
  static calculateAnnualRateBp(
    principal: number,
    monthlyPayment: number,
    totalPeriods: number,
    method: RepaymentMethod = 'equal_payment',
    totalInterest: number = 0
  ): number {
    if (principal <= 0 || totalPeriods <= 0 || monthlyPayment <= 0) {
      return 0
    }

    if (method === 'equal_payment') {
      const pmtAtZero = principal / totalPeriods
      if (monthlyPayment <= pmtAtZero + 1e-9) {
        return 0
      }
      let lo = 0
      let hi = 0.05
      const tolerance = 1e-9
      for (let i = 0; i < 100; i++) {
        const mid = (lo + hi) / 2
        const factor = Math.pow(1 + mid, totalPeriods)
        const pmtAtMid = principal * mid * factor / (factor - 1)
        if (pmtAtMid < monthlyPayment) {
          lo = mid
        } else {
          hi = mid
        }
        if (hi - lo < tolerance) {
          break
        }
      }
      const monthlyRate = (lo + hi) / 2
      return Math.round(monthlyRate * 12 * 10000)
    }

    let interest = totalInterest
    if (interest <= 0) {
      interest = monthlyPayment * totalPeriods - principal
    }
    if (interest <= 0) {
      return 0
    }
    const years = totalPeriods / 12
    if (years <= 0) {
      return 0
    }
    return Math.round(interest / principal / years * 10000)
  }

  static parseCustomSchedule(note: string): CustomScheduleItem[] | null {
    if (!note || note.length === 0) {
      return null
    }
    try {
      const parsed = JSON.parse(note) as CustomScheduleNote
      if (parsed && parsed.custom_schedule && Array.isArray(parsed.custom_schedule)) {
        // 显式拷贝 date/paid，避免只保留金额字段
        const raw = parsed.custom_schedule
        const out: CustomScheduleItem[] = []
        for (let i = 0; i < raw.length; i++) {
          const src = raw[i]
          const item = new CustomScheduleItem()
          item.period_number = Number(src.period_number) || 0
          item.principal = Number(src.principal) || 0
          item.interest = Number(src.interest) || 0
          item.total = Number(src.total) || 0
          item.date = src.date !== undefined && src.date !== null ? `${src.date}` : ''
          item.paid = src.paid === true
          out.push(item)
        }
        return out.length > 0 ? out : null
      }
    } catch (e) {
      // note 不是 JSON 或格式不对
    }
    return null
  }

  static getCleanNoteText(note: string): string {
    const schedule = CalculationService.parseCustomSchedule(note)
    if (schedule) {
      try {
        const parsed = JSON.parse(note) as CustomScheduleNote
        if (parsed && typeof parsed.text === 'string') {
          return parsed.text
        }
      } catch (e) {
        // ignore
      }
      return ''
    }
    return note
  }

  /** 从 YYYY-MM-DD 字符串解析年份和月份；无效格式返回 null */
  private static parseYearMonth(dateStr: string): YearMonth | null {
    const parts = dateStr.split('-')
    if (parts.length < 2) {
      return null
    }
    const year = Number(parts[0])
    const month = Number(parts[1])
    if (isNaN(year) || isNaN(month) || month < 1 || month > 12) {
      return null
    }
    const ym = new YearMonth()
    ym.year = year
    ym.month = month
    return ym
  }

  /**
   * 月供口径的当期应还：若月供只写了本金均摊、总息仍在 total_interest，则补上每期服务费。
   * 月供已含息（月供 > 本金/期）时不加，避免重复。
   */
  private static resolveMonthlyWithFee(debt: Debt): number {
    const monthly = debt.monthly_payment
    if (monthly <= 0) {
      return 0
    }
    const periods = debt.total_periods > 0 ? debt.total_periods : debt.remaining_periods
    if (periods <= 0) {
      return monthly
    }
    const principalBase = debt.principal > 0 ? debt.principal : debt.current_balance
    const principalPart = principalBase > 0 ? Math.round(principalBase / periods) : 0
    if (principalPart > 0 && monthly > principalPart + 1) {
      return monthly
    }
    if (debt.total_interest > 0) {
      return monthly + Math.round(debt.total_interest / periods)
    }
    return monthly
  }

  /**
   * 第 p 期（0-based，within remaining）的实际应还金额。
   * 优先 custom schedule；其次 monthly_payment；当 monthly_payment 缺失（AI 识别 / 导入数据
   * 未带月供）时：非分期或末期 -> 还清剩余余额，多期分期 -> 按公式计算，避免「本月待还」误显示 0。
   */
  private static getPeriodPaymentAmount(
    debt: Debt,
    p: number,
    schedule: CustomScheduleItem[] | null,
    startPeriod: number
  ): number {
    if (schedule) {
      const item = schedule.find(s => s.period_number === startPeriod + p)
      if (item) {
        if (item.total > item.principal) {
          return item.total
        }
        if (item.total === item.principal && debt.monthly_payment > item.total) {
          return debt.monthly_payment
        }
        return item.total || debt.monthly_payment || debt.current_balance
      }
    }
    if (debt.monthly_payment > 0) {
      return CalculationService.resolveMonthlyWithFee(debt)
    }
    // monthly_payment 缺失：非分期整笔到期 / 末期还清余额 -> 取 current_balance
    const remainingAtPeriod = debt.remaining_periods - p
    if (debt.debt_type !== 'installment' || remainingAtPeriod <= 1) {
      return debt.current_balance
    }
    // 多期分期缺月供：按公式推算该期应还
    const split = CalculationService.calculatePeriodPayment(
      debt.current_balance, debt.annual_rate_bp, remainingAtPeriod,
      debt.total_periods, debt.repayment_method, debt.principal,
      debt.monthly_payment, debt.total_interest
    )
    const computed = split.principal + split.interest
    return computed > 0 ? computed : debt.current_balance
  }

  /** 当期应还（含自定义表首期），不生成整张还款计划 */
  static currentPeriodDue(debt: Debt): number {
    const schedule = CalculationService.parseCustomSchedule(debt.note)
    const pendingInfo = CalculationService.getPendingAndStartPeriod(debt)
    return CalculationService.getPeriodPaymentAmount(debt, 0, schedule, pendingInfo.startPeriod)
  }

  static getDebtPaymentForMonth(
    debt: Debt,
    monthKey: string
  ): number {
    if (debt.status !== 'active' || !debt.next_payment_date) {
      return 0
    }
    const parsed = CalculationService.parseYearMonth(debt.next_payment_date)
    if (!parsed) {
      return 0
    }
    let year = parsed.year
    let month = parsed.month
    const schedule = CalculationService.parseCustomSchedule(debt.note)
    const pendingInfo = CalculationService.getPendingAndStartPeriod(debt)
    let pending = pendingInfo.pending
    const startPeriod = pendingInfo.startPeriod

    // remaining=0 但仍有余额：至少算当期 1 期（PC 末期 / 导入未关单）
    if (pending <= 0 && debt.current_balance > 0) {
      pending = 1
    }

    for (let p = 0; p < pending; p++) {
      const key = year + '-' + (month < 10 ? '0' + month : '' + month)
      if (key === monthKey) {
        return CalculationService.getPeriodPaymentAmount(debt, p, schedule, startPeriod)
      }
      if (key > monthKey) {
        break
      }
      month++
      if (month > 12) {
        month = 1
        year++
      }
    }
    return 0
  }

  /**
   * 指定月应还（「本月」口径叠加逾期累积）。
   * - monthKey !== currentMonthKey：委托 getDebtPaymentForMonth（未来月只算该月 1 期）。
   * - monthKey === currentMonthKey 且已逾期（next_payment_date 月 < currentMonthKey）：
   *   累加从 next_payment_date 月到 currentMonthKey 的所有期数（受待还期数上限，含当期）。
   * - monthKey === currentMonthKey 但未逾期：委托 getDebtPaymentForMonth（本月 1 期）。
   */
  static getDebtPaymentForMonthAccrued(
    debt: Debt,
    monthKey: string,
    currentMonthKey: string
  ): number {
    if (monthKey !== currentMonthKey) {
      return CalculationService.getDebtPaymentForMonth(debt, monthKey)
    }
    if (debt.status !== 'active' || !debt.next_payment_date) {
      return 0
    }
    const parsed = CalculationService.parseYearMonth(debt.next_payment_date)
    if (!parsed) {
      return 0
    }
    const nextPayMonthKey = parsed.year + '-' + (parsed.month < 10 ? '0' + parsed.month : '' + parsed.month)
    // 未逾期（下次还款月 >= 当前月）：走原逻辑（本月 1 期）
    if (nextPayMonthKey >= currentMonthKey) {
      return CalculationService.getDebtPaymentForMonth(debt, monthKey)
    }
    // 已逾期：累加从 next_payment_date 月到 currentMonthKey 的所有期数
    const pendingInfo = CalculationService.getPendingAndStartPeriod(debt)
    let pending = pendingInfo.pending
    const startPeriod = pendingInfo.startPeriod
    if (pending <= 0) {
      if (debt.current_balance <= 0) {
        return 0
      }
      pending = 1
    }
    let year = parsed.year
    let month = parsed.month
    const schedule = CalculationService.parseCustomSchedule(debt.note)
    let total = 0
    for (let p = 0; p < pending; p++) {
      const key = year + '-' + (month < 10 ? '0' + month : '' + month)
      if (key > currentMonthKey) {
        break
      }
      total += CalculationService.getPeriodPaymentAmount(debt, p, schedule, startPeriod)
      month++
      if (month > 12) {
        month = 1
        year++
      }
    }
    return total
  }

  static calculateRemainingInterest(debt: Debt): number {
    const schedule = CalculationService.generatePaymentSchedule(debt)
    let total = 0
    for (const item of schedule) {
      total += item.interest
    }
    return total
  }

  /**
   * 关联信用账户的活跃订阅月费（分摊到月）。
   * 与 DebtsTab / Dashboard 卡片「当月·下月应还」口径一致。
   */
  static getCreditLinkedSubscriptionMonthly(subscriptions: Subscription[]): number {
    let total = 0
    for (const sub of subscriptions) {
      if (sub.status !== 'active') {
        continue
      }
      if (!sub.credit_account_id || sub.credit_account_id.length === 0) {
        continue
      }
      const info = PlatformService.getBillingCycleInfo(sub.billing_cycle)
      // monthsPerCycle = 一个计费周期含多少个月；月费 = 周期金额 / 月数
      const monthly = info.monthsPerCycle > 0 ? sub.amount / info.monthsPerCycle : sub.amount
      total += monthly
    }
    return total
  }

  /**
   * 订阅在指定年月是否真实扣费（非月摊）。
   * 从 next_billing_date 起按计费周期推进，命中目标月即计；once 仅命中当月。
   * end_date 是服务终止日：扣费日落在 end_date 当天或之后均不再计费。
   */
  static isSubscriptionDueInMonth(sub: Subscription, targetYear: number, targetMonth: number): boolean {
    if (sub.status !== 'active' || sub.next_billing_date.length === 0) {
      return false
    }
    const cursor = new Date(sub.next_billing_date)
    if (isNaN(cursor.getTime())) {
      return false
    }
    // targetMonth 为 1-12；day=0 得到该月最后一天
    const targetMonthEnd = new Date(targetYear, targetMonth, 0)
    if (cursor > targetMonthEnd) {
      return false
    }

    let endDate: Date | null = null
    if (sub.end_date.length > 0) {
      const parsed = new Date(sub.end_date)
      if (!isNaN(parsed.getTime())) {
        endDate = parsed
      }
    }

    // 结束日期早于首个扣费日：无未来扣费
    if (endDate !== null && cursor >= endDate) {
      return false
    }

    const hitsTarget = (d: Date): boolean => {
      return d.getFullYear() === targetYear && (d.getMonth() + 1) === targetMonth
    }

    if (sub.billing_cycle.startsWith('once')) {
      return hitsTarget(cursor)
    }

    const monthsPerCycle = PlatformService.getBillingCycleInfo(sub.billing_cycle).monthsPerCycle
    if (monthsPerCycle <= 0) {
      return hitsTarget(cursor)
    }

    while (cursor <= targetMonthEnd) {
      if (endDate !== null && cursor >= endDate) {
        return false
      }
      if (hitsTarget(cursor)) {
        return true
      }
      if (monthsPerCycle >= 1) {
        cursor.setMonth(cursor.getMonth() + monthsPerCycle)
      } else {
        cursor.setDate(cursor.getDate() + Math.round(monthsPerCycle * 30))
      }
    }
    return false
  }

  /**
   * 指定年月真实扣费的「关联信用账户」订阅合计。
   * 与 getCreditLinkedSubscriptionMonthly 同口径范围（仅关联信用账户），
   * 但按真实扣费月归集：季/年付只落在扣费当月，不摊到每月。
   */
  static getCreditLinkedSubscriptionDueInMonth(
    subscriptions: Subscription[],
    targetYear: number,
    targetMonth: number
  ): number {
    let total = 0
    for (const sub of subscriptions) {
      if (!sub.credit_account_id || sub.credit_account_id.length === 0) {
        continue
      }
      if (CalculationService.isSubscriptionDueInMonth(sub, targetYear, targetMonth)) {
        total += sub.amount
      }
    }
    return total
  }

  /**
   * 指定月份的应还合计（负债月供 + 关联信用账户订阅月费）。
   * 负债走 getDebtPaymentForMonth（与卡片一致），订阅按月摊（每月计入）。
   * 传入 currentMonthKey 时，monthKey === currentMonthKey 的本月口径叠加逾期累积。
   */
  static getDueAmountForMonth(
    debts: Debt[],
    subscriptions: Subscription[],
    monthKey: string,
    currentMonthKey?: string
  ): MonthlyPressure {
    let debtAmount = 0
    const useAccrued = currentMonthKey !== undefined && currentMonthKey.length > 0
    for (const debt of debts) {
      debtAmount += useAccrued
        ? CalculationService.getDebtPaymentForMonthAccrued(debt, monthKey, currentMonthKey as string)
        : CalculationService.getDebtPaymentForMonth(debt, monthKey)
    }
    const subscriptionAmount = CalculationService.getCreditLinkedSubscriptionMonthly(subscriptions)
    const pressure = new MonthlyPressure()
    pressure.month = monthKey
    pressure.debtAmount = debtAmount
    pressure.subscriptionAmount = subscriptionAmount
    pressure.amount = debtAmount + subscriptionAmount
    return pressure
  }

  /**
   * 未来各月应还（首页「未来待还趋势」柱状图数据源）。
   * 负债按月供（本月叠加逾期累积），订阅按**真实扣费月**归集：
   * 季/年付只落在扣费当月，不摊到每月，避免无扣费月份出现虚高柱子。
   */
  static calculateMonthlyPressure(debts: Debt[], subscriptions: Subscription[], months: number = 6): MonthlyPressure[] {
    const result: MonthlyPressure[] = []
    const today = new Date()

    // 当前月 key：本月（i=0）口径叠加逾期累积，其余月仍按单期
    const cm = today.getMonth() + 1
    const currentMonthKey = today.getFullYear() + '-' + (cm < 10 ? '0' + cm : '' + cm)

    const d = new Date(today.getFullYear(), today.getMonth(), 1)
    for (let i = 0; i < months; i++) {
      const year = d.getFullYear()
      const month = d.getMonth() + 1
      const key = year + '-' + (month < 10 ? '0' + month : '' + month)

      let debtAmount = 0
      for (const debt of debts) {
        debtAmount += CalculationService.getDebtPaymentForMonthAccrued(debt, key, currentMonthKey)
      }
      const subDue = CalculationService.getCreditLinkedSubscriptionDueInMonth(subscriptions, year, month)

      const pressure = new MonthlyPressure()
      pressure.month = key
      pressure.debtAmount = debtAmount
      pressure.subscriptionAmount = subDue
      pressure.amount = debtAmount + subDue
      result.push(pressure)

      d.setMonth(d.getMonth() + 1)
    }

    return result
  }

  static calculateNextBillingDate(cycle: BillingCycle, startDate: string): string {
    const d = new Date(startDate)
    const info = PlatformService.getBillingCycleInfo(cycle)
    const months = info.monthsPerCycle
    if (months >= 1) {
      d.setMonth(d.getMonth() + months)
    } else {
      const days = Math.round(months * 30)
      d.setDate(d.getDate() + days)
    }
    return CalculationService.formatDate(d)
  }

  /**
   * 关联信用账户时按账户账单日/还款日从开始日期推算首期应还日（YYYY-MM-DD）。
   * 交易日落在账单日及之后计入次月账单；还款日早于账单日时再顺延一月。
   * 无账单日时退化为按还款日比较。无账单日或账单日/还款日越界时返回 ''。
   * periodShift：中途录入时向后的期数偏移，逐月推进并钳制月末。
   */
  static firstDueDateForAccount(startISO: string, billDay: number, paymentDay: number,
    periodShift: number = 0): string {
    const start = new Date(startISO)
    if (isNaN(start.getTime())) {
      return ''
    }
    const pay = Math.round(paymentDay)
    if (!(pay >= 1 && pay <= 31)) {
      return ''
    }
    const bill = billDay >= 1 && billDay <= 31 ? Math.round(billDay) : 0
    let year = start.getFullYear()
    let month = start.getMonth() + 1
    if (bill > 0) {
      if (start.getDate() >= bill) {
        month++
        if (month > 12) {
          month = 1
          year++
        }
      }
      if (pay < bill) {
        month++
        if (month > 12) {
          month = 1
          year++
        }
      }
    } else if (start.getDate() > pay) {
      month++
      if (month > 12) {
        month = 1
        year++
      }
    }
    month += Math.max(0, Math.round(periodShift))
    while (month > 12) {
      month -= 12
      year++
    }
    const lastDay = new Date(year, month, 0).getDate()
    const day = pay < lastDay ? pay : lastDay
    return year + '-' + (month < 10 ? '0' + month : '' + month) + '-' +
      (day < 10 ? '0' + day : '' + day)
  }

  private static formatDate(date: Date): string {
    const year = date.getFullYear()
    const month = date.getMonth() + 1
    const day = date.getDate()
    return year + '-' + (month < 10 ? '0' + month : '' + month) + '-' + (day < 10 ? '0' + day : '' + day)
  }

  /**
   * 指定月份固定应还总额（负债 + 订阅）。
   * 金额单位：分。
   * 订阅 billingDate/endDate 在循环外创建、每个订阅通过 setTime 重置复用。
   */
  static calculateSingleMonthObligation(
    debts: Debt[],
    subscriptions: Subscription[],
    month: string
  ): MonthlyObligation {
    const result = new MonthlyObligation()

    // 负债部分：从 next_payment_date 起逐期推演，命中目标月才累加
    for (const debt of debts) {
      if (debt.status !== 'active') {
        continue
      }
      const isInstallment = !debt.debt_type || debt.debt_type === 'installment'
      const parsed = CalculationService.parseYearMonth(debt.next_payment_date)
      if (!parsed) {
        continue
      }
      let year = parsed.year
      let monthNum = parsed.month
      const schedule = CalculationService.parseCustomSchedule(debt.note)
      const totalPeriods = debt.total_periods > 0 ? debt.total_periods : debt.remaining_periods
      const pendingIncludingCurrent = isInstallment
        ? Math.max(0, Math.min(debt.remaining_periods + 1, totalPeriods))
        : 1
      const startPeriod = totalPeriods - debt.remaining_periods

      for (let p = 0; p < pendingIncludingCurrent; p++) {
        const key = year + '-' + (monthNum < 10 ? '0' + monthNum : '' + monthNum)
        if (key === month) {
          const periodNumber = startPeriod + p
          let amount: number = 0
          if (!isInstallment) {
            amount = debt.current_balance >= 0 ? debt.current_balance : debt.monthly_payment
          } else if (schedule) {
            const item = schedule.find(s => s.period_number === periodNumber)
            amount = item ? item.total : debt.monthly_payment
          } else {
            amount = debt.monthly_payment
          }
          result.debtObligation += amount
        }
        monthNum++
        if (monthNum > 12) {
          monthNum = 1
          year++
        }
      }
    }

    // 订阅部分：全部 active 订阅，扣费日落在 [月初, end_date) 且 [月初, 下月初) 才计入
    const monthParts = month.split('-')
    const targetYear = Number(monthParts[0])
    const targetMonthNum = Number(monthParts[1])
    const monthStart = new Date(targetYear, targetMonthNum - 1, 1)
    const monthEnd = new Date(targetYear, targetMonthNum, 1)
    monthStart.setHours(0, 0, 0, 0)
    monthEnd.setHours(0, 0, 0, 0)

    const billingDate = new Date()
    const endDate = new Date()
    for (const sub of subscriptions) {
      if (sub.status !== 'active') {
        continue
      }
      billingDate.setTime(Date.parse(sub.next_billing_date))
      billingDate.setHours(0, 0, 0, 0)

      const cycle: string = sub.billing_cycle
      const hasEndDate = sub.end_date.length > 0
      if (hasEndDate) {
        endDate.setTime(Date.parse(sub.end_date))
        endDate.setHours(0, 0, 0, 0)
      }

      // 结束日期早于等于首个扣费日：无未来扣费
      if (hasEndDate && billingDate >= endDate) {
        continue
      }

      let iterations = 0
      while (billingDate < monthEnd && iterations < 100) {
        iterations++
        if (hasEndDate && billingDate >= endDate) {
          break
        }
        if (billingDate >= monthStart && billingDate < monthEnd) {
          result.subscriptionObligation += sub.amount
        }
        if (cycle === 'once' || cycle.startsWith('once_')) {
          break
        } else if (cycle === 'weekly') {
          billingDate.setDate(billingDate.getDate() + 7)
        } else if (cycle === 'biweekly') {
          billingDate.setDate(billingDate.getDate() + 14)
        } else if (cycle === 'monthly') {
          CalculationService.addMonthsClamped(billingDate, 1)
        } else if (cycle === 'quarterly') {
          CalculationService.addMonthsClamped(billingDate, 3)
        } else if (cycle === 'semiannually') {
          CalculationService.addMonthsClamped(billingDate, 6)
        } else if (cycle === 'annually') {
          CalculationService.addMonthsClamped(billingDate, 12)
        } else {
          CalculationService.addMonthsClamped(billingDate, 1)
        }
      }
    }

    result.total = result.debtObligation + result.subscriptionObligation
    return result
  }

  /** 月末日期钳制加月：31 日 +1 月落到月末而非跨月 */
  private static addMonthsClamped(date: Date, months: number): void {
    const day = date.getDate()
    date.setMonth(date.getMonth() + Math.round(months))
    if (date.getDate() !== day) {
      date.setDate(0)
    }
  }

  static getDebtOverdueInfo(debt: Debt, creditAccount?: CreditAccount | null): DebtOverdueInfo {
    const info: DebtOverdueInfo = {
      daysLeft: 0,
      daysLate: 0,
      graceDays: 0,
      isInGracePeriod: false,
      isBreached: false,
      isOverdue: false,
      label: ''
    }
    if (debt.status === 'completed') {
      info.label = '已结清'
      return info
    }
    if (debt.status === 'paused') {
      info.label = '已暂停'
      return info
    }
    if (!debt.next_payment_date) {
      info.label = '进行中'
      return info
    }
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const next = new Date(debt.next_payment_date)
    next.setHours(0, 0, 0, 0)
    const diffMs = today.getTime() - next.getTime()
    const daysLeft = Math.floor(diffMs / (1000 * 60 * 60 * 24))
    info.daysLeft = -daysLeft
    info.daysLate = daysLeft > 0 ? daysLeft : 0
    info.graceDays = creditAccount?.grace_period_days ?? 0
    if (daysLeft <= 0) {
      info.label = '进行中'
    } else {
      const remainingGrace = info.graceDays - daysLeft
      if (remainingGrace >= 0) {
        info.isInGracePeriod = true
        info.label = '宽限期内'
      } else {
        info.isBreached = true
        info.isOverdue = true
        info.label = '已逾期'
      }
    }
    return info
  }
}
