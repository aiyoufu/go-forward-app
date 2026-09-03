import { Subscription } from 'common'
import { PlatformService } from './platform/PlatformService'

export class ReceiptLine {
  name: string = ''
  monthlyFen: number = 0
  displayFen: number = 0
  currency: string = 'CNY'
  category: string = ''
  iconUrl: string = ''
  /** 票面副文：年付 / 月付，对应参考图 Annual subscription */
  subtitle: string = ''
  /** 与订阅列表同口径：已折合人民币的周期金额（分） */
  cnyFen: number = 0
}

export class ReceiptShare {
  label: string = ''
  percent: number = 0
}

export class ReceiptModel {
  year: number = 2026
  itemCount: number = 0
  totalMonthlyFen: number = 0
  avgMonthlyFen: number = 0
  categories: ReceiptShare[] = []
  lines: ReceiptLine[] = []
}

/**
 * 订阅月结小票：纯函数，把活跃订阅折成月费再汇总。
 */
export class SubscriptionReceipt {
  /** 票面周期副文，对齐参考图「Annual subscription」信息槽，不写说明书 */
  static cycleShareLabel(cycle: string): string {
    if (cycle === 'annually' || cycle === 'once_annually') {
      return '年付'
    }
    if (cycle === 'semiannually') {
      return '半年付'
    }
    if (cycle === 'quarterly' || cycle === 'once_quarterly') {
      return '季付'
    }
    if (cycle === 'monthly' || cycle === 'once') {
      return '月付'
    }
    if (cycle === 'biweekly') {
      return '两周付'
    }
    if (cycle === 'weekly' || cycle === 'once_weekly') {
      return '周付'
    }
    return ''
  }

  static monthlyFen(amount: number, cycle: string): number {
    const months = PlatformService.getBillingCycleInfo(cycle).monthsPerCycle
    if (months <= 0) {
      return amount
    }
    return Math.round(amount / months)
  }

  static build(subs: Subscription[], year: number): ReceiptModel {
    const model = new ReceiptModel()
    model.year = year > 0 ? year : new Date().getFullYear()
    const lines: ReceiptLine[] = []
    const byCat = new Map<string, number>()
    let total = 0
    for (let i = 0; i < subs.length; i++) {
      const s = subs[i]
      if (s.status !== 'active') {
        continue
      }
      const monthly = SubscriptionReceipt.monthlyFen(s.amount, s.billing_cycle)
      const originFen = s.original_amount_fen > 0 ? s.original_amount_fen : s.amount
      const line = new ReceiptLine()
      line.name = s.name.length > 0 ? s.name : '未命名'
      line.monthlyFen = monthly
      line.displayFen = SubscriptionReceipt.monthlyFen(originFen, s.billing_cycle)
      line.cnyFen = s.amount
      line.currency = s.currency.length > 0 ? s.currency : 'CNY'
      line.category = s.category
      line.iconUrl = s.icon_url
      line.subtitle = SubscriptionReceipt.cycleShareLabel(s.billing_cycle)
      lines.push(line)
      total += s.amount
      const prev = byCat.get(s.category) || 0
      byCat.set(s.category, prev + monthly)
    }
    lines.sort((a: ReceiptLine, b: ReceiptLine): number => {
      return a.name.localeCompare(b.name)
    })
    model.lines = lines
    model.itemCount = lines.length
    model.totalMonthlyFen = total
    model.avgMonthlyFen = lines.length > 0 ? Math.round(total / lines.length) : 0
    model.categories = SubscriptionReceipt.categoryShares(byCat, total)
    return model
  }

  private static categoryShares(byCat: Map<string, number>, total: number): ReceiptShare[] {
    const keys: string[] = []
    const iter = byCat.keys()
    for (const k of iter) {
      keys.push(k)
    }
    keys.sort((a: string, b: string): number => {
      const da = byCat.get(a) || 0
      const db = byCat.get(b) || 0
      return db - da
    })
    const out: ReceiptShare[] = []
    let used = 0
    for (let i = 0; i < keys.length; i++) {
      const share = new ReceiptShare()
      share.label = PlatformService.getCategoryInfo(keys[i]).label
      const fen = byCat.get(keys[i]) || 0
      if (i === keys.length - 1) {
        share.percent = total > 0 ? Math.max(0, 100 - used) : 0
      } else {
        share.percent = total > 0 ? Math.round(fen * 100 / total) : 0
        used += share.percent
      }
      out.push(share)
    }
    return out
  }
}
