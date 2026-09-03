import { describe, it, expect } from '@ohos/hypium'
import { DebtsFilterSort } from '../../../../main/ets/service/DebtsFilterSort'
import { Debt } from 'common'
import { TestFixtures } from '../TestFixtures'

function debtOf(platform: string, balance: number, nextPay: string, endDate: string, note: string): Debt {
  const d = TestFixtures.debt()
  d.platform = platform
  d.current_balance = balance
  d.next_payment_date = nextPay
  d.estimated_end_date = endDate
  d.note = note
  return d
}

export default function debtsFilterSortTest() {
  describe('DebtsFilterSort_filterAndSort', () => {
    it('filterIndex=0_返回未结清', 0, () => {
      const a = debtOf('花呗', 5000, '2025-06-01', '2025-12-01', '')
      a.status = 'active'
      const b = debtOf('借呗', 10000, '2025-03-01', '2025-09-01', '测试')
      b.status = 'active'
      const c = debtOf('京东白条', 3000, '2025-04-01', '2025-08-01', '')
      c.status = 'paused'
      const d = debtOf('微粒贷', 0, '2025-01-01', '2025-01-01', '')
      d.status = 'completed'
      const debts: Debt[] = [a, b, c, d]
      const result = DebtsFilterSort.filterAndSort(debts, '', 0, 0, '2025-05-01')
      expect(result.length).assertEqual(3)
    })
    it('搜索平台', 0, () => {
      const a = debtOf('花呗', 5000, '2025-06-01', '2025-12-01', '')
      a.status = 'active'
      const b = debtOf('借呗', 10000, '2025-03-01', '2025-09-01', '测试')
      b.status = 'active'
      const result = DebtsFilterSort.filterAndSort([a, b], '花呗', 0, 0, '2025-05-01')
      expect(result.length).assertEqual(1)
      expect(result[0].platform).assertEqual('花呗')
    })
    it('余额降序', 0, () => {
      const a = debtOf('花呗', 5000, '2025-06-01', '2025-12-01', '')
      a.status = 'active'
      const b = debtOf('借呗', 10000, '2025-03-01', '2025-09-01', '')
      b.status = 'active'
      const result = DebtsFilterSort.filterAndSort([a, b], '', 0, 0, '2025-05-01')
      expect(result[0].current_balance).assertLargerOrEqual(result[1].current_balance)
    })
    it('空列表', 0, () => {
      const empty: Debt[] = []
      expect(DebtsFilterSort.filterAndSort(empty, '', 0, 0, '2025-05-01').length).assertEqual(0)
    })
  })
}
