import { describe, it, expect } from '@ohos/hypium'
import { Debt } from 'common'
import { DebtReceipt } from '../../../../main/ets/service/DebtReceipt'

function debt(name: string, balance: number, status: string = 'active'): Debt {
  const d = new Debt()
  d.platform = name
  d.current_balance = balance
  d.status = status as 'active'
  return d
}

export default function debtReceiptTest() {
  describe('DebtReceipt', () => {
    it('build_跳过已结清', 0, async () => {
      const model = DebtReceipt.build([
        debt('花呗', 100000),
        debt('已结清贷款', 999999, 'completed')
      ])
      expect(model.itemCount).assertEqual(1)
      expect(model.totalRemainingFen).assertEqual(100000)
    })
    it('build_按余额降序', 0, async () => {
      const model = DebtReceipt.build([
        debt('花呗', 100000),
        debt('房贷', 9000000)
      ])
      expect(model.lines[0].name).assertEqual('房贷')
      expect(model.lines[1].name).assertEqual('花呗')
    })
    it('build_已还进度与页内同口径', 0, async () => {
      const d = debt('房贷', 600000)
      d.principal = 1000000
      const model = DebtReceipt.build([d])
      expect(model.progressPercent).assertEqual(40)
    })
    it('build_副文_分期给月供', 0, async () => {
      const d = debt('花呗', 100000)
      d.debt_type = 'installment'
      d.monthly_payment = 50000
      const model = DebtReceipt.build([d])
      expect(model.lines[0].subtitle).assertEqual('月供 500.00')
    })
    it('build_副文_一次性给到期日', 0, async () => {
      const d = debt('借款', 100000)
      d.debt_type = 'other'
      d.next_payment_date = '2026-09-01'
      const model = DebtReceipt.build([d])
      expect(model.lines[0].subtitle).assertEqual('2026-09-01 到期')
    })
    it('build_空列表安全', 0, async () => {
      const model = DebtReceipt.build([])
      expect(model.itemCount).assertEqual(0)
      expect(model.totalRemainingFen).assertEqual(0)
      expect(model.progressPercent).assertEqual(0)
      expect(model.payoffDate).assertEqual('')
    })
    it('build_计算最晚预计还清时间', 0, async () => {
      const d1 = debt('花呗', 100000)
      d1.estimated_end_date = '2026-10-01'
      const d2 = debt('借呗', 200000)
      d2.estimated_end_date = '2027-05-15'
      const d3 = debt('已结清', 0, 'completed')
      d3.estimated_end_date = '2029-01-01'
      const model = DebtReceipt.build([d1, d2, d3])
      expect(model.payoffDate).assertEqual('2027-05-15')
    })
    it('build_无estimated_end_date时自动根据期数推算还清时间', 0, async () => {
      const d = debt('分期贷款', 100000)
      d.next_payment_date = '2026-06-01'
      d.remaining_periods = 6
      const model = DebtReceipt.build([d])
      expect(model.payoffDate).assertEqual('2026-11-01')
    })
  })
}
