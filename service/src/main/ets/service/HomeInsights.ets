import { CreditAccount, Debt, MonthlyPressure, Subscription } from 'common'
import { CalculationService } from './CalculationService'

/** 首页「AI 洞察」单条：一句话结论 + 行动建议，不复述首页已可见事实 */
export class HomeInsight {
  id: string = ''
  tag: string = ''
  title: string = ''
}

/** 洞察输入：用首页已加载的三表做交叉，主数字只用于缺口核对 */
export class HomeInsightInput {
  thisMonthDue: number = 0
  nextMonthDue: number = 0
  remainingDebt: number = 0
  debts: Debt[] = []
  subscriptions: Subscription[] = []
  accounts: CreditAccount[] = []
}

/**
 * 首页稀疏数据洞察（纯函数）。
 * 仅在无行动清单时由 DashboardTab 取用，最多 2 条。
 * 每条只留一句短结论：先还哪笔、峰值是谁、重复订阅、年费缺口等。
 * 禁止复述本月/下月/总待还，禁止「下月加重 / 还很久所以提前还」这类空话。
 */
export class HomeInsights {
  static readonly MAX_ITEMS: number = 2
  static readonly HIGH_RATE_BP: number = 1800
  static readonly RATE_SPREAD_BP: number = 600

  /** 无行动项且已有洞察、非首载骨架时才展示 */
  static shouldShow(hasActionItems: boolean, insightCount: number, firstLoad: boolean): boolean {
    if (firstLoad) {
      return false
    }
    if (hasActionItems) {
      return false
    }
    return insightCount > 0
  }

  /** YYYY-MM →「8月」；非法则回原文 */
  static monthLabel(month: string): string {
    const parts = month.split('-')
    if (parts.length === 2) {
      const m = parseInt(parts[1], 10)
      if (!isNaN(m) && m >= 1 && m <= 12) {
        return m + '月'
      }
    }
    return month
  }

  /** compare 相对 base 达到 1.5 倍（两者均须为正） */
  static isSignificantJump(base: number, compare: number): boolean {
    if (base <= 0 || compare <= 0) {
      return false
    }
    return compare >= base * 1.5
  }

  static build(input: HomeInsightInput, pressure: MonthlyPressure[]): HomeInsight[] {
    const out: HomeInsight[] = []
    HomeInsights.pushRateTarget(out, input)
    HomeInsights.pushSoonClear(out, input)
    HomeInsights.pushInterestHeavy(out, input)
    HomeInsights.pushRevolving(out, input)
    HomeInsights.pushPeakCause(out, input, pressure)
    HomeInsights.pushDupSubs(out, input)
    HomeInsights.pushAnnualFee(out, input)
    HomeInsights.pushSamePayday(out, input)
    HomeInsights.pushCreditUtil(out, input)
    HomeInsights.pushMissingRate(out, input)
    HomeInsights.pushStaleSchedule(out, input)
    if (out.length > HomeInsights.MAX_ITEMS) {
      return out.slice(0, HomeInsights.MAX_ITEMS)
    }
    return out
  }

  private static pushRateTarget(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    let best: Debt | null = null
    let second: Debt | null = null
    for (let i = 0; i < debts.length; i++) {
      const d = debts[i]
      if (d.annual_rate_bp <= 0) {
        continue
      }
      if (best === null || d.annual_rate_bp > best.annual_rate_bp) {
        second = best
        best = d
      } else if (second === null || d.annual_rate_bp > second.annual_rate_bp) {
        second = d
      }
    }
    if (best === null) {
      return
    }
    const bestName = HomeInsights.debtName(best)
    if (second !== null && (best.annual_rate_bp - second.annual_rate_bp) >= HomeInsights.RATE_SPREAD_BP) {
      HomeInsights.push(
        out,
        'rate_target',
        '先还哪笔',
        bestName + ' 年化 ' + HomeInsights.ratePct(best.annual_rate_bp) + '，多还先冲它'
      )
      return
    }
    if (best.annual_rate_bp >= HomeInsights.HIGH_RATE_BP) {
      HomeInsights.push(
        out,
        'rate_target',
        '高利息',
        bestName + ' 年化 ' + HomeInsights.ratePct(best.annual_rate_bp) + '，多还直冲本金'
      )
    }
  }

  private static pushSoonClear(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    let soon: Debt | null = null
    for (let i = 0; i < debts.length; i++) {
      const d = debts[i]
      if (d.remaining_periods < 1 || d.remaining_periods > 2) {
        continue
      }
      if (soon === null || d.remaining_periods < soon.remaining_periods) {
        soon = d
      }
    }
    if (soon === null) {
      return
    }
    const other = HomeInsights.bestRedirectTarget(debts, soon.id)
    if (other === null) {
      return
    }
    HomeInsights.push(
      out,
      'soon_clear',
      '快还完',
      HomeInsights.debtName(soon) + ' 还剩 ' + soon.remaining_periods +
        ' 期，清完转冲 ' + HomeInsights.debtName(other)
    )
  }

  private static pushInterestHeavy(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    let hit: Debt | null = null
    for (let i = 0; i < debts.length; i++) {
      const d = debts[i]
      if (HomeInsights.alreadyMentions(out, HomeInsights.debtName(d))) {
        continue
      }
      const remaining = d.remaining_periods > 0 ? d.remaining_periods : 0
      if (remaining <= 0) {
        continue
      }
      const split = CalculationService.calculatePeriodPayment(
        d.current_balance,
        d.annual_rate_bp,
        remaining,
        d.total_periods,
        d.repayment_method,
        d.principal,
        d.monthly_payment,
        d.total_interest
      )
      const total = split.principal + split.interest
      if (total <= 0 || split.interest * 10 < total * 4) {
        continue
      }
      hit = d
      break
    }
    if (hit === null) {
      return
    }
    HomeInsights.push(
      out,
      'interest_heavy',
      '多半是息',
      HomeInsights.debtName(hit) + ' 这期多在付息，优先还本金'
    )
  }

  private static pushRevolving(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    let hit: Debt | null = null
    for (let i = 0; i < debts.length; i++) {
      const d = debts[i]
      if (HomeInsights.alreadyMentions(out, HomeInsights.debtName(d))) {
        continue
      }
      if (d.monthly_payment <= 0) {
        continue
      }
      const revolvingType = d.debt_type === 'credit_card' || d.remaining_periods <= 0
      if (!revolvingType) {
        continue
      }
      if (d.current_balance < d.monthly_payment * 6) {
        continue
      }
      hit = d
      break
    }
    if (hit === null) {
      return
    }
    HomeInsights.push(
      out,
      'revolving',
      '最低还',
      HomeInsights.debtName(hit) + ' 最低还压不动本金，直接冲本金'
    )
  }

  private static pushPeakCause(
    out: HomeInsight[],
    input: HomeInsightInput,
    pressure: MonthlyPressure[]
  ): void {
    if (out.length >= HomeInsights.MAX_ITEMS || pressure.length < 2) {
      return
    }
    let peakIdx = 0
    let peakAmt = pressure[0].amount
    for (let i = 1; i < pressure.length; i++) {
      if (pressure[i].amount > peakAmt) {
        peakAmt = pressure[i].amount
        peakIdx = i
      }
    }
    let others = 0
    let count = 0
    for (let i = 0; i < pressure.length; i++) {
      if (i !== peakIdx) {
        others += pressure[i].amount
        count++
      }
    }
    const avg = count > 0 ? others / count : 0
    if (peakAmt <= 0 || avg <= 0 || peakAmt < avg * 1.3) {
      return
    }
    const peakMonth = pressure[peakIdx].month
    const named = HomeInsights.largestContributor(input, peakMonth, peakAmt)
    if (named.length === 0) {
      return
    }
    HomeInsights.push(
      out,
      'peak_cause',
      '哪笔最重',
      HomeInsights.monthLabel(peakMonth) + ' 变重是 ' + named + '，提前还或挪期'
    )
  }

  private static pushDupSubs(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const subs = HomeInsights.activeSubs(input)
    let bestCat: string = ''
    let bestA: Subscription | null = null
    let bestB: Subscription | null = null
    let bestSum = 0
    for (let i = 0; i < subs.length; i++) {
      const a = subs[i]
      if (a.category === 'other') {
        continue
      }
      for (let j = i + 1; j < subs.length; j++) {
        const b = subs[j]
        if (b.category !== a.category) {
          continue
        }
        const sum = a.amount + b.amount
        if (sum > bestSum) {
          bestSum = sum
          bestCat = a.category
          bestA = a
          bestB = b
        }
      }
    }
    if (bestA === null || bestB === null || bestCat.length === 0) {
      return
    }
    HomeInsights.push(
      out,
      'dup_subs',
      '重复订阅',
      bestA.name + ' 和 ' + bestB.name + ' 重叠，留一个'
    )
  }

  private static pushAnnualFee(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    let hit: CreditAccount | null = null
    let gap = 0
    for (let i = 0; i < input.accounts.length; i++) {
      const a = input.accounts[i]
      if (a.annual_fee_required_swipes <= 0) {
        continue
      }
      const remain = a.annual_fee_required_swipes - a.annual_fee_manual_swipes
      if (remain <= 0) {
        continue
      }
      if (hit === null || remain < gap) {
        hit = a
        gap = remain
      }
    }
    if (hit === null || gap <= 0) {
      return
    }
    const name = hit.name.length > 0 ? hit.name : '这张卡'
    HomeInsights.push(
      out,
      'annual_fee',
      '年费',
      name + ' 再刷 ' + gap + ' 笔免年费'
    )
  }

  private static pushSamePayday(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    let bestDay = 0
    let bestCount = 0
    for (let day = 1; day <= 31; day++) {
      let n = 0
      for (let i = 0; i < debts.length; i++) {
        if (debts[i].payment_day === day) {
          n++
        }
      }
      if (n > bestCount) {
        bestCount = n
        bestDay = day
      }
    }
    if (bestCount < 3 || bestDay < 1) {
      return
    }
    HomeInsights.push(
      out,
      'same_payday',
      '同一天扣',
      bestCount + ' 笔挤在每月 ' + bestDay + ' 号，挪开一笔'
    )
  }

  private static pushCreditUtil(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    let hit: CreditAccount | null = null
    for (let i = 0; i < input.accounts.length; i++) {
      const a = input.accounts[i]
      if (a.credit_limit <= 0 || a.id.length === 0) {
        continue
      }
      let used = 0
      for (let j = 0; j < debts.length; j++) {
        if (debts[j].credit_account_id === a.id) {
          used += debts[j].current_balance
        }
      }
      if (used * 10 < a.credit_limit * 7) {
        continue
      }
      hit = a
      break
    }
    if (hit === null) {
      return
    }
    const name = hit.name.length > 0 ? hit.name : '这张卡'
    HomeInsights.push(
      out,
      'credit_util',
      '额度偏高',
      name + ' 额度用掉大半，先压这笔'
    )
  }

  private static pushMissingRate(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const debts = HomeInsights.activeDebts(input)
    if (debts.length < 2) {
      return
    }
    let missing = 0
    for (let i = 0; i < debts.length; i++) {
      if (debts[i].annual_rate_bp <= 0) {
        missing++
      }
    }
    if (missing <= 0) {
      return
    }
    HomeInsights.push(
      out,
      'missing_rate',
      '缺利率',
      '有负债没填年化，补上才排得出先后'
    )
  }

  private static pushStaleSchedule(out: HomeInsight[], input: HomeInsightInput): void {
    if (out.length >= HomeInsights.MAX_ITEMS || input.remainingDebt <= 0) {
      return
    }
    if (input.thisMonthDue > 0 || input.nextMonthDue > 0) {
      return
    }
    HomeInsights.push(
      out,
      'stale_schedule',
      '核对日期',
      '有余额但近期无待还，核下出单日'
    )
  }

  private static largestContributor(
    input: HomeInsightInput,
    monthKey: string,
    peakAmt: number
  ): string {
    const parts = monthKey.split('-')
    if (parts.length !== 2) {
      return ''
    }
    const year = parseInt(parts[0], 10)
    const month = parseInt(parts[1], 10)
    if (isNaN(year) || isNaN(month)) {
      return ''
    }
    let topName = ''
    let topAmt = 0
    const debts = HomeInsights.activeDebts(input)
    for (let i = 0; i < debts.length; i++) {
      const amt = CalculationService.getDebtPaymentForMonth(debts[i], monthKey)
      if (amt > topAmt) {
        topAmt = amt
        topName = HomeInsights.debtName(debts[i])
      }
    }
    const subs = HomeInsights.activeSubs(input)
    for (let i = 0; i < subs.length; i++) {
      const s = subs[i]
      if (!CalculationService.isSubscriptionDueInMonth(s, year, month)) {
        continue
      }
      if (s.amount > topAmt) {
        topAmt = s.amount
        topName = s.name.length > 0 ? s.name : '这笔订阅'
      }
    }
    if (topName.length === 0 || peakAmt <= 0 || topAmt * 10 < peakAmt * 4) {
      return ''
    }
    return topName
  }

  private static bestRedirectTarget(debts: Debt[], exceptId: string): Debt | null {
    let best: Debt | null = null
    for (let i = 0; i < debts.length; i++) {
      const d = debts[i]
      if (d.id === exceptId) {
        continue
      }
      if (best === null) {
        best = d
        continue
      }
      if (d.annual_rate_bp > best.annual_rate_bp) {
        best = d
        continue
      }
      if (d.annual_rate_bp === best.annual_rate_bp && d.current_balance > best.current_balance) {
        best = d
      }
    }
    return best
  }

  private static activeDebts(input: HomeInsightInput): Debt[] {
    const list: Debt[] = []
    for (let i = 0; i < input.debts.length; i++) {
      const d = input.debts[i]
      if (d.status === 'active' && d.current_balance > 0) {
        list.push(d)
      }
    }
    return list
  }

  private static activeSubs(input: HomeInsightInput): Subscription[] {
    const list: Subscription[] = []
    for (let i = 0; i < input.subscriptions.length; i++) {
      const s = input.subscriptions[i]
      if (s.status === 'active') {
        list.push(s)
      }
    }
    return list
  }

  private static debtName(d: Debt): string {
    if (d.platform.length > 0) {
      return d.platform
    }
    return '这笔负债'
  }

  private static ratePct(bp: number): string {
    return '' + Math.round(bp / 100) + '%'
  }

  private static alreadyMentions(out: HomeInsight[], name: string): boolean {
    if (name.length === 0) {
      return false
    }
    for (let i = 0; i < out.length; i++) {
      if (out[i].title.includes(name)) {
        return true
      }
    }
    return false
  }

  private static push(
    out: HomeInsight[],
    id: string,
    tag: string,
    title: string
  ): void {
    if (out.length >= HomeInsights.MAX_ITEMS) {
      return
    }
    const item = new HomeInsight()
    item.id = id
    item.tag = tag
    item.title = title
    out.push(item)
  }
}
