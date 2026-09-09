import { CreditAccount } from 'common'
import { ReceiptLine } from './SubscriptionReceipt'

export class AccountReceiptModel {
  itemCount: number = 0
  /** 总额度（分），由表单「万元」换算 */
  totalLimitFen: number = 0
  lines: ReceiptLine[] = []
}

/**
 * 账户小票：纯函数，把信用账户折成小票条目。
 * 与负债/订阅小票共用 ReceiptLine；金额为信用额度（万元 → 分）。
 */
export class AccountReceipt {
  /** 表单额度单位是万元 */
  static wanToFen(wan: number): number {
    return Math.round(wan * 1000000)
  }

  static build(accounts: CreditAccount[]): AccountReceiptModel {
    const model = new AccountReceiptModel()
    const lines: ReceiptLine[] = []
    let totalFen = 0
    for (let i = 0; i < accounts.length; i++) {
      const a = accounts[i]
      const line = new ReceiptLine()
      line.name = a.name.length > 0 ? a.name : '未命名账户'
      line.cnyFen = AccountReceipt.wanToFen(a.credit_limit)
      line.subtitle = AccountReceipt.lineSubtitle(a)
      lines.push(line)
      totalFen += line.cnyFen
    }
    lines.sort((a: ReceiptLine, b: ReceiptLine): number => {
      return b.cnyFen - a.cnyFen
    })
    model.lines = lines
    model.itemCount = lines.length
    model.totalLimitFen = totalFen
    return model
  }

  /** 票面副文：还款日 + 尾号 */
  static lineSubtitle(a: CreditAccount): string {
    const parts: string[] = []
    if (a.payment_day > 0) {
      parts.push('还款 ' + a.payment_day + '日')
    }
    const four = a.last_four.trim()
    if (four.length > 0) {
      parts.push('尾号 ' + four)
    }
    return parts.join(' · ')
  }
}
