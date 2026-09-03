import { Debt, Utils } from 'common'
import { CalculationService } from './CalculationService'
import { ReceiptLine } from './SubscriptionReceipt'

export class DebtReceiptModel {
  itemCount: number = 0
  /** 剩余待还合计（分），与负债页主数字同口径 */
  totalRemainingFen: number = 0
  /** 已还进度百分比（0-100），与负债页进度条同口径 */
  progressPercent: number = 0
  /** 预计还清日期（YYYY-MM-DD），所有进行中负债中最晚的预计还清日 */
  payoffDate: string = ''
  lines: ReceiptLine[] = []
}

/**
 * 负债小票：纯函数，把进行中负债折成小票条目。
 * 与订阅月结小票共用 ReceiptLine；金额为剩余待还（与列表卡「剩余待还」同口径）。
 */
export class DebtReceipt {
  static build(debts: Debt[]): DebtReceiptModel {
    const model = new DebtReceiptModel()
    const lines: ReceiptLine[] = []
    let balance = 0
    let principal = 0
    let furthestEndDate = ''
    for (let i = 0; i < debts.length; i++) {
      const d = debts[i]
      if (d.status === 'completed') {
        continue
      }
      const line = new ReceiptLine()
      line.name = d.platform.length > 0 ? d.platform : '未命名'
      line.cnyFen = d.current_balance
      line.subtitle = DebtReceipt.lineSubtitle(d)
      lines.push(line)
      balance += d.current_balance
      principal += d.principal

      let endDate = d.estimated_end_date
      if (!endDate && d.next_payment_date) {
        endDate = CalculationService.calculateEstimatedEndDate(d.next_payment_date, d.remaining_periods)
      }
      if (endDate && (!furthestEndDate || endDate > furthestEndDate)) {
        furthestEndDate = endDate
      }
    }
    lines.sort((a: ReceiptLine, b: ReceiptLine): number => {
      return b.cnyFen - a.cnyFen
    })
    model.lines = lines
    model.itemCount = lines.length
    model.totalRemainingFen = balance
    model.progressPercent = principal > 0
      ? Math.min(100, Math.max(0, Math.round(((principal - balance) / principal) * 100)))
      : 0
    if (furthestEndDate.length > 0) {
      furthestEndDate = Utils.formatDate(furthestEndDate)
    }
    model.payoffDate = furthestEndDate
    return model
  }

  /** 票面副文：分期给月供，一次性给下次还款日 */
  private static lineSubtitle(d: Debt): string {
    if (d.debt_type === 'installment' && d.monthly_payment > 0) {
      return '月供 ' + Utils.formatMoney(d.monthly_payment, false)
    }
    if (d.next_payment_date.length > 0) {
      return Utils.formatDate(d.next_payment_date) + ' 到期'
    }
    return ''
  }
}
