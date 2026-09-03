import { Debt } from 'common'
import { Subscription } from 'common'
import { CreditAccount } from 'common'
import { Utils } from 'common'

/** debt | subscription | account */
export type HomeActionKind = string
/** overdue | today | upcoming */
export type HomeActionUrgency = string
/** record_payment | view */
export type HomeActionPrimary = string

/**
 * 首页行动中心条目
 */
export class HomeActionItem {
  id: string = ''
  kind: HomeActionKind = 'debt'
  title: string = ''
  subtitle: string = ''
  amount: number = 0
  date: string = ''
  urgency: HomeActionUrgency = 'today'
  primaryAction: HomeActionPrimary = 'view'
  entityId: string = ''
}

export class HomeActionBuckets {
  needAction: HomeActionItem[] = []
  upcoming: HomeActionItem[] = []
}

/**
 * 首页行动项聚合（纯函数，today 由调用方注入，便于单测）
 */
export class HomeActionItems {
  /** 今天与目标日的日历日差：目标 − 今天（负=已过） */
  static daysFrom(today: string, date: string): number {
    if (today.length === 0 || date.length === 0) {
      return 0
    }
    // 用时间戳计算，避免在循环/高频路径中 new Date（reuse-date-instances-check）
    const t = Date.parse(today + 'T00:00:00')
    const d = Date.parse(date + 'T00:00:00')
    if (isNaN(t) || isNaN(d)) {
      return 0
    }
    const msPerDay = 24 * 60 * 60 * 1000
    return Math.floor((d - t) / msPerDay)
  }

  static buildBuckets(
    debts: Debt[],
    subscriptions: Subscription[],
    accounts: CreditAccount[],
    today: string
  ): HomeActionBuckets {
    const buckets = new HomeActionBuckets()
    const need: HomeActionItem[] = []
    const up: HomeActionItem[] = []

    for (let i = 0; i < debts.length; i++) {
      const item = HomeActionItems.fromDebt(debts[i], today)
      if (item === null) {
        continue
      }
      if (item.urgency === 'upcoming') {
        up.push(item)
      } else {
        need.push(item)
      }
    }

    for (let i = 0; i < subscriptions.length; i++) {
      const item = HomeActionItems.fromSubscription(subscriptions[i], today)
      if (item === null) {
        continue
      }
      if (item.urgency === 'upcoming') {
        up.push(item)
      } else {
        need.push(item)
      }
    }

    for (let i = 0; i < accounts.length; i++) {
      const item = HomeActionItems.fromAccount(accounts[i], today)
      if (item === null) {
        continue
      }
      if (item.urgency === 'upcoming') {
        up.push(item)
      } else {
        need.push(item)
      }
    }

    HomeActionItems.sortItems(need)
    HomeActionItems.sortItems(up)
    buckets.needAction = need
    buckets.upcoming = up
    return buckets
  }

  private static fromDebt(d: Debt, today: string): HomeActionItem | null {
    if (d.status !== 'active') {
      return null
    }
    if (!d.next_payment_date || d.next_payment_date.length === 0) {
      return null
    }
    const days = HomeActionItems.daysFrom(today, d.next_payment_date)
    const urgency = HomeActionItems.urgencyFromDays(days)
    if (urgency === null) {
      return null
    }
    const item = new HomeActionItem()
    item.id = 'debt:' + d.id
    item.kind = 'debt'
    item.title = d.platform.length > 0 ? d.platform : '负债'
    item.amount = d.monthly_payment > 0 ? d.monthly_payment : d.current_balance
    item.date = d.next_payment_date
    item.urgency = urgency
    item.primaryAction = 'record_payment'
    item.entityId = d.id
    item.subtitle = HomeActionItems.debtSubtitle(days, item.amount)
    return item
  }

  private static fromSubscription(s: Subscription, today: string): HomeActionItem | null {
    if (s.status !== 'active') {
      return null
    }
    if (!s.next_billing_date || s.next_billing_date.length === 0) {
      return null
    }
    // 结束日期早于等于下次扣费日：服务终止，不再产生扣费行动项
    if (s.end_date && s.end_date.length > 0 && s.next_billing_date >= s.end_date) {
      return null
    }
    const days = HomeActionItems.daysFrom(today, s.next_billing_date)
    const urgency = HomeActionItems.urgencyFromDays(days)
    if (urgency === null) {
      return null
    }
    const item = new HomeActionItem()
    item.id = 'subscription:' + s.id
    item.kind = 'subscription'
    item.title = s.name.length > 0 ? s.name : '订阅'
    item.amount = s.amount
    item.date = s.next_billing_date
    item.urgency = urgency
    item.primaryAction = 'view'
    item.entityId = s.id
    item.subtitle = HomeActionItems.subscriptionSubtitle(days, item.amount)
    return item
  }

  private static fromAccount(a: CreditAccount, today: string): HomeActionItem | null {
    if (!a.expiry_date || a.expiry_date.length === 0) {
      return null
    }
    // 表单存 MM/YY，不能直接 Date.parse；规范为当月末 YYYY-MM-DD
    const expiryYmd = Utils.creditCardExpiryToYmd(a.expiry_date)
    if (expiryYmd.length === 0) {
      return null
    }
    const days = HomeActionItems.daysFrom(today, expiryYmd)
    // 已过期默认不上屏；仅今天或 1..7 天
    if (days < 0) {
      return null
    }
    const urgency = HomeActionItems.urgencyFromDays(days)
    if (urgency === null) {
      return null
    }
    const item = new HomeActionItem()
    item.id = 'account:' + a.id
    item.kind = 'account'
    item.title = a.name.length > 0 ? a.name : '账户'
    item.amount = 0
    item.date = expiryYmd
    item.urgency = urgency
    item.primaryAction = 'view'
    item.entityId = a.id
    const four = a.last_four.trim().length > 0 ? a.last_four.trim() : '****'
    item.subtitle = HomeActionItems.accountSubtitle(days, four)
    return item
  }

  /**
   * days < 0 → overdue；0 → today；1..7 → upcoming；else null
   */
  static urgencyFromDays(days: number): HomeActionUrgency | null {
    if (days < 0) {
      return 'overdue'
    }
    if (days === 0) {
      return 'today'
    }
    if (days >= 1 && days <= 7) {
      return 'upcoming'
    }
    return null
  }

  private static debtSubtitle(days: number, amountFen: number): string {
    const money = Utils.formatMoney(amountFen)
    if (days < 0) {
      return '已逾期 ' + (-days) + ' 天 · ' + money
    }
    if (days === 0) {
      return '今天还款 · ' + money
    }
    if (days === 1) {
      return '明天还款 · ' + money
    }
    return days + ' 天后 · ' + money
  }

  private static subscriptionSubtitle(days: number, amountFen: number): string {
    const money = Utils.formatMoney(amountFen)
    if (days < 0) {
      return '已过期 ' + (-days) + ' 天 · ' + money
    }
    if (days === 0) {
      return '今天扣款 · ' + money
    }
    if (days === 1) {
      return '明天扣款 · ' + money
    }
    return days + ' 天后扣款 · ' + money
  }

  private static accountSubtitle(days: number, lastFour: string): string {
    const tail = '尾号 ' + lastFour
    if (days === 0) {
      return '今天到期 · ' + tail
    }
    if (days === 1) {
      return '明天到期 · ' + tail
    }
    return days + ' 天后到期 · ' + tail
  }

  private static sortItems(list: HomeActionItem[]): void {
    list.sort((a: HomeActionItem, b: HomeActionItem): number => {
      const ua = HomeActionItems.urgencyRank(a.urgency)
      const ub = HomeActionItems.urgencyRank(b.urgency)
      if (ua !== ub) {
        return ua - ub
      }
      if (a.date < b.date) {
        return -1
      }
      if (a.date > b.date) {
        return 1
      }
      const ka = HomeActionItems.kindRank(a.kind)
      const kb = HomeActionItems.kindRank(b.kind)
      if (ka !== kb) {
        return ka - kb
      }
      if (a.entityId < b.entityId) {
        return -1
      }
      if (a.entityId > b.entityId) {
        return 1
      }
      return 0
    })
  }

  private static urgencyRank(u: string): number {
    if (u === 'overdue') {
      return 0
    }
    if (u === 'today') {
      return 1
    }
    return 2
  }

  private static kindRank(k: string): number {
    if (k === 'debt') {
      return 0
    }
    if (k === 'subscription') {
      return 1
    }
    return 2
  }
}
