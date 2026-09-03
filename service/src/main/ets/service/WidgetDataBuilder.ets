import { DebtService } from './DebtService'
import { SubscriptionService } from './SubscriptionService'
import { Subscription } from 'common'
import { UserService } from './UserService'
import { CalculationService } from './CalculationService'
import { Utils } from 'common'

/**
 * 桌面卡片数据：本月待还 / 资金压力 / 负债总览 / 订阅
 * 金额统一 formatWidgetMoney；图表/列表打包字符串避免 Form 多字段丢失。
 *
 * 统一规则（元为主单位，仅几十万级别起换算万）：
 * - < 10 万元：¥x,xxx.xx（千分位 + 两位小数）
 * - ≥ 10 万元：¥x.x万（整数万去掉 .0）
 * - 禁止 k / 裸数字 / 无货币符号
 * - 例外：压力柱图柱上短标签用 chartMoneyLabel（同阈值，无千分位）
 */
export class WidgetDataBuilder {
  /** 元换算万的阈值：10 万元 */
  private static readonly WAN_THRESHOLD_YUAN: number = 100000

  /** 三张桌面卡唯一金额格式：<10 万元为单位，≥ 10 万用万 */
  static formatWidgetMoney(fen: number): string {
    const yuan = Utils.fenToYuan(fen)
    const sign = yuan < 0 ? '-' : ''
    const abs = Math.abs(yuan)
    if (abs >= WidgetDataBuilder.WAN_THRESHOLD_YUAN) {
      return sign + '¥' + Utils.YUAN_GAP + WidgetDataBuilder.wanBody(abs) + '万'
    }
    return Utils.formatMoney(fen, true)
  }

  /** 万为单位的数字部分：≥100 万取整，否则 1 位小数去掉 .0 */
  private static wanBody(absYuan: number): string {
    const wan = absYuan / 10000
    let s = wan >= 100 ? wan.toFixed(0) : wan.toFixed(1)
    if (s.endsWith('.0')) {
      s = s.substring(0, s.length - 2)
    }
    return s
  }

  /**
   * 压力柱图短标签：带 ¥ 与其他卡片统一（含细空格），<10 万「¥x,xxx」，≥ 10 万「¥x.x万」。
   * 柱上空间有限取整数；不含分号/竖线，避免破坏 chartPack 的 ";" "|" 分隔。
   */
  private static chartMoneyLabel(fen: number): string {
    const yuan = Math.abs(fen) / 100
    const sign = fen < 0 ? '-' : ''
    if (yuan >= WidgetDataBuilder.WAN_THRESHOLD_YUAN) {
      return sign + '¥' + Utils.YUAN_GAP + WidgetDataBuilder.wanBody(yuan) + '万'
    }
    const s = '' + Math.round(yuan)
    let out = ''
    let count = 0
    for (let i = s.length - 1; i >= 0; i--) {
      out = s.charAt(i) + out
      count++
      if (count % 3 === 0 && i > 0) {
        out = ',' + out
      }
    }
    return sign + '¥' + Utils.YUAN_GAP + out
  }

  private static nextMonthLabels(count: number, from: Date): string[] {
    const out: string[] = []
    // 循环外创建，循环内通过 setFullYear 复用，避免重复 new Date
    const d = new Date()
    for (let i = 0; i < count; i++) {
      d.setFullYear(from.getFullYear(), from.getMonth() + i, 1)
      out.push('' + (d.getMonth() + 1))
    }
    return out
  }

  // ── 本月待还 ──────────────────────────────────────────

  static monthDuePlaceholder(): Record<string, string | number | boolean> {
    return {
      'amount': WidgetDataBuilder.formatWidgetMoney(0),
      'hasData': false,
      // name|amountText;name|amountText  最多若干条
      'debtListPack': '',
      'moreCount': 0
    }
  }

  /**
   * 本月待还：总额 + 本月有应还的负债清单（不展示已还）
   * debtListPack: "花呗|¥1,200;京东|¥800"
   */
  static async buildMonthDue(): Promise<Record<string, string | number | boolean>> {
    const userId = UserService.getCurrentUserId()
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)

    const now = new Date()
    const m = now.getMonth() + 1
    const monthKey = now.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m)
    const due = CalculationService.getDueAmountForMonth(debts, subscriptions, monthKey, monthKey)
    const dueAmt = due.debtAmount

    // 本月有应还的负债，按金额降序
    class DueLine {
      name: string = ''
      fen: number = 0
    }
    const lines: DueLine[] = []
    for (const d of debts) {
      if (d.status !== 'active' && d.status !== 'paused') {
        continue
      }
      const fen = CalculationService.getDebtPaymentForMonthAccrued(d, monthKey, monthKey)
      if (fen <= 0) {
        continue
      }
      const line = new DueLine()
      line.name = (d.platform && d.platform.length > 0) ? d.platform : '未命名'
      line.fen = fen
      lines.push(line)
    }
    lines.sort((a: DueLine, b: DueLine) => b.fen - a.fen)

    // 2×2 底部全宽按钮后，清单最多 2 行
    const maxShow = 2
    const shown: string[] = []
    for (let i = 0; i < lines.length && i < maxShow; i++) {
      const n = lines[i].name.length > 6 ? lines[i].name.substring(0, 6) : lines[i].name
      shown.push(n + '|' + WidgetDataBuilder.formatWidgetMoney(lines[i].fen))
    }
    const moreCount = Math.max(0, lines.length - shown.length)

    return {
      'amount': WidgetDataBuilder.formatWidgetMoney(dueAmt),
      'hasData': dueAmt > 0 || lines.length > 0,
      'debtListPack': shown.join(';'),
      'moreCount': moreCount
    }
  }

  // ── 资金压力（6 月）──────────────────────────────────

  static pressurePlaceholder(): Record<string, string | number | boolean> {
    const labels = WidgetDataBuilder.nextMonthLabels(6, new Date())
    const parts: string[] = []
    for (let i = 0; i < 6; i++) {
      parts.push('0|' + labels[i] + '|—')
    }
    return {
      'hasData': false,
      'peakIndex': -1,
      // h|month|amtText × 6，分号分隔（金额含千分位逗号，不能用逗号分段）
      'chartPack': parts.join(';')
    }
  }

  /**
   * 资金压力：固定 6 个月
   * chartPack: "100|7|¥15,000;80|8|¥1,200;..."（分号分隔，标签禁止含 ; 和 |）
   */
  static async buildPressure(): Promise<Record<string, string | number | boolean>> {
    const userId = UserService.getCurrentUserId()
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)
    const list = CalculationService.calculateMonthlyPressure(debts, subscriptions, 6)
    const fallbackLabels = WidgetDataBuilder.nextMonthLabels(6, new Date())

    if (list.length === 0) {
      return WidgetDataBuilder.pressurePlaceholder()
    }

    let maxAmt = 0
    let peakIdx = 0
    for (let i = 0; i < list.length; i++) {
      if (list[i].amount > maxAmt) {
        maxAmt = list[i].amount
        peakIdx = i
      }
    }

    const parts: string[] = []
    for (let i = 0; i < 6; i++) {
      let h = 0
      let label = fallbackLabels[i]
      let amtText = '—'
      if (i < list.length) {
        const amt = list[i].amount
        if (amt > 0 && maxAmt > 0) {
          h = Math.max(14, Math.round((amt / maxAmt) * 100))
        } else if (maxAmt > 0) {
          h = 8
        }
        const segs = list[i].month.split('-')
        if (segs.length === 2) {
          label = '' + parseInt(segs[1], 10)
        }
        if (amt > 0) {
          amtText = WidgetDataBuilder.chartMoneyLabel(amt)
        }
      }
      parts.push(h + '|' + label + '|' + amtText)
    }

    const hasAny = maxAmt > 0 || debts.length > 0 || subscriptions.length > 0

    return {
      'hasData': hasAny,
      'peakIndex': maxAmt > 0 ? peakIdx : -1,
      'chartPack': parts.join(';')
    }
  }

  // ── 订阅（生效数 + 到期日期/状态清单，不展示金额）──

  static subscriptionPlaceholder(): Record<string, string | number | boolean> {
    return {
      'activeSubs': 0,
      'hasData': false,
      // name|dateText|statusText;...  最多若干条
      'subListPack': '',
      'moreCount': 0
    }
  }

  /** 状态文案与 App 内一致（不含 ; 和 |） */
  private static subStatusLabel(status: string): string {
    if (status === 'active') {
      return '生效中'
    }
    if (status === 'paused') {
      return '暂停'
    }
    return '已取消'
  }

  /**
   * 订阅：生效数 + 清单（到期日期、状态），生效订阅按扣费日升序排前
   * subListPack: "爱奇艺|8/1|生效中;网易云|—|暂停"（标签禁止含 ; 和 |）
   */
  static async buildSubscription(): Promise<Record<string, string | number | boolean>> {
    const userId = UserService.getCurrentUserId()
    const subscriptions = await SubscriptionService.getSubscriptions(userId)

    let activeCount = 0
    for (const s of subscriptions) {
      if (s.status === 'active') {
        activeCount++
      }
    }

    // 生效且未来到期（end_date 优先，无结束日则取 next_billing_date）排最前，其余依次垄后
    const todayYmd = Utils.todayString()
    const upcoming: Subscription[] = []
    const rest: Subscription[] = []
    for (const s of subscriptions) {
      const expiryDate = s.end_date.length > 0 ? s.end_date : s.next_billing_date
      if (s.status === 'active' && expiryDate.length > 0 && expiryDate >= todayYmd) {
        upcoming.push(s)
      } else {
        rest.push(s)
      }
    }
    upcoming.sort((a: Subscription, b: Subscription) => {
      const aDate = a.end_date.length > 0 ? a.end_date : a.next_billing_date
      const bDate = b.end_date.length > 0 ? b.end_date : b.next_billing_date
      return aDate.localeCompare(bDate)
    })
    const rank = (s: Subscription): number => s.status === 'active' ? 0 : (s.status === 'paused' ? 1 : 2)
    rest.sort((a: Subscription, b: Subscription) => rank(a) - rank(b))
    const ordered: Subscription[] = []
    for (const s of upcoming) {
      ordered.push(s)
    }
    for (const s of rest) {
      ordered.push(s)
    }

    // 2×2 底部全宽按钮后，清单最多 2 行
    const maxShow = 2
    const shown: string[] = []
    for (let i = 0; i < ordered.length && i < maxShow; i++) {
      const raw = ordered[i].name.length > 0 ? ordered[i].name : '未命名'
      const n = raw.length > 6 ? raw.substring(0, 6) : raw
      const expiryDate = ordered[i].end_date.length > 0 ? ordered[i].end_date : ordered[i].next_billing_date
      const dateText = WidgetDataBuilder.shortDate(expiryDate)
      shown.push(n + '|' + (dateText.length > 0 ? dateText : '—')
        + '|' + WidgetDataBuilder.subStatusLabel(ordered[i].status))
    }
    const moreCount = Math.max(0, ordered.length - shown.length)

    return {
      'activeSubs': activeCount,
      'hasData': subscriptions.length > 0,
      'subListPack': shown.join(';'),
      'moreCount': moreCount
    }
  }

  /** shortDate 复用的临时 Date，避免频繁调用时重复创建实例 */
  private static readonly SHORT_DATE_SCRATCH = new Date()

  /** "yyyy-MM-dd" → "M/d"，解析失败返回空串（不含 ; 和 |） */
  private static shortDate(dateStr: string): string {
    const t = Date.parse(dateStr)
    if (isNaN(t)) {
      return ''
    }
    const d = WidgetDataBuilder.SHORT_DATE_SCRATCH
    d.setTime(t)
    return (d.getMonth() + 1) + '/' + d.getDate()
  }

  // ── 负债总览（长卡，对齐首页负债摘要）────────────────

  static debtOverviewPlaceholder(): Record<string, string | number | boolean> {
    return {
      'remaining': WidgetDataBuilder.formatWidgetMoney(0),
      'progress': 0,
      'thisMonth': WidgetDataBuilder.formatWidgetMoney(0),
      'nextMonth': WidgetDataBuilder.formatWidgetMoney(0),
      'hasData': false
    }
  }

  /** 负债总览 2×2：剩余 + 当月/下月 + 结清进度（无趋势） */
  static async buildDebtOverview(): Promise<Record<string, string | number | boolean>> {
    const userId = UserService.getCurrentUserId()
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)

    let totalDebt = 0
    let remaining = 0
    for (const d of debts) {
      totalDebt += d.principal
      remaining += d.current_balance
    }
    if (totalDebt <= 0 && remaining > 0) {
      totalDebt = remaining
    }
    const paid = Math.max(0, totalDebt - remaining)
    const progress = totalDebt > 0
      ? Math.max(0, Math.min(100, Math.round((paid / totalDebt) * 100)))
      : 0
    const hasData = debts.length > 0 || remaining > 0

    const now = new Date()
    const m = now.getMonth() + 1
    const thisKey = now.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m)
    const nextDate = new Date(now.getFullYear(), now.getMonth() + 1, 1)
    const nm = nextDate.getMonth() + 1
    const nextKey = nextDate.getFullYear() + '-' + (nm < 10 ? '0' + nm : '' + nm)
    const thisDue = CalculationService.getDueAmountForMonth(debts, subscriptions, thisKey, thisKey).debtAmount
    const nextDue = CalculationService.getDueAmountForMonth(debts, subscriptions, nextKey, thisKey).debtAmount

    return {
      'remaining': WidgetDataBuilder.formatWidgetMoney(remaining),
      'progress': progress,
      'thisMonth': WidgetDataBuilder.formatWidgetMoney(thisDue),
      'nextMonth': WidgetDataBuilder.formatWidgetMoney(nextDue),
      'hasData': hasData
    }
  }

  // ── 负债 · 资金压力（2×4 长卡，融合存量与流量）──

  static debtPressurePlaceholder(): Record<string, string | number | boolean> {
    const labels = WidgetDataBuilder.nextMonthLabels(6, new Date())
    const parts: string[] = []
    for (let i = 0; i < 6; i++) {
      parts.push('0|' + labels[i] + '|—')
    }
    return {
      'remaining': WidgetDataBuilder.formatWidgetMoney(0),
      'progress': 0,
      'hasData': false,
      'peakIndex': -1,
      'chartPack': parts.join(';')
    }
  }

  /**
   * 负债·资金压力 2×4：存量（剩余+还款进度）与流量（6 月还款节奏）融合
   * 共享一次查询；当月/下月应还即柱图前两根柱，不再单列字段
   */
  static async buildDebtPressure(): Promise<Record<string, string | number | boolean>> {
    const userId = UserService.getCurrentUserId()
    const debts = await DebtService.getDebts(userId)
    const subscriptions = await SubscriptionService.getSubscriptions(userId)

    // 存量：剩余负债 + 还款进度（口径同 buildDebtOverview）
    let totalDebt = 0
    let remaining = 0
    for (const d of debts) {
      totalDebt += d.principal
      remaining += d.current_balance
    }
    if (totalDebt <= 0 && remaining > 0) {
      totalDebt = remaining
    }
    const paid = Math.max(0, totalDebt - remaining)
    const progress = totalDebt > 0
      ? Math.max(0, Math.min(100, Math.round((paid / totalDebt) * 100)))
      : 0
    const hasData = debts.length > 0 || remaining > 0

    // 流量：6 月压力（口径同 buildPressure，复用同一次查询结果）
    const list = CalculationService.calculateMonthlyPressure(debts, subscriptions, 6)
    const fallbackLabels = WidgetDataBuilder.nextMonthLabels(6, new Date())

    let maxAmt = 0
    let peakIdx = 0
    for (let i = 0; i < list.length; i++) {
      if (list[i].amount > maxAmt) {
        maxAmt = list[i].amount
        peakIdx = i
      }
    }

    const parts: string[] = []
    for (let i = 0; i < 6; i++) {
      let h = 0
      let label = fallbackLabels[i]
      let amtText = '—'
      if (i < list.length) {
        const amt = list[i].amount
        if (amt > 0 && maxAmt > 0) {
          h = Math.max(14, Math.round((amt / maxAmt) * 100))
        } else if (maxAmt > 0) {
          h = 8
        }
        const segs = list[i].month.split('-')
        if (segs.length === 2) {
          label = '' + parseInt(segs[1], 10)
        }
        if (amt > 0) {
          amtText = WidgetDataBuilder.chartMoneyLabel(amt)
        }
      }
      parts.push(h + '|' + label + '|' + amtText)
    }

    return {
      'remaining': WidgetDataBuilder.formatWidgetMoney(remaining),
      'progress': progress,
      'hasData': hasData,
      'peakIndex': maxAmt > 0 ? peakIdx : -1,
      'chartPack': parts.join(';')
    }
  }
}
