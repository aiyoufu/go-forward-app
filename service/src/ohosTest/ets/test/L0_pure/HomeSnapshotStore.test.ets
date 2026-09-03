import { describe, it, expect } from '@ohos/hypium'
import { DashboardFrameCache } from '../../../../main/ets/service/sync/LocalDataStore'
import { DashboardSummary } from '../../../../main/ets/service/DashboardTypes'

export default function homeSnapshotStoreTest() {
  describe('HomeSnapshot_DashboardFrameCache', () => {
    it('fromSummary拷贝关键字段', 0, () => {
      const s = new DashboardSummary()
      s.remainingDebt = 999
      s.thisMonthDue = 100
      s.overdueCount = 2
      s.activeDebtCount = 3
      s.payoffDate = '2028-06'
      const f = DashboardFrameCache.fromSummary(s, 50)
      expect(f.remainingDebt).assertEqual(999)
      expect(f.thisMonthDue).assertEqual(100)
      expect(f.overdueCount).assertEqual(2)
      expect(f.monthPaid).assertEqual(50)
      expect(f.payoffDate).assertEqual('2028-06')
    })
    it('applyTo写回Summary', 0, () => {
      const f = new DashboardFrameCache()
      f.remainingDebt = 1
      f.thisMonthDue = 2
      f.nextMonthDue = 3
      f.activeDebtCount = 4
      f.payoffDate = '2027-09'
      const s = new DashboardSummary()
      f.applyTo(s)
      expect(s.remainingDebt).assertEqual(1)
      expect(s.thisMonthDue).assertEqual(2)
      expect(s.nextMonthDue).assertEqual(3)
      expect(s.activeDebtCount).assertEqual(4)
      expect(s.payoffDate).assertEqual('2027-09')
    })
    it('空frame默认0', 0, () => {
      const f = new DashboardFrameCache()
      expect(f.remainingDebt).assertEqual(0)
      expect(f.hasRepaymentRecords).assertFalse()
    })
  })
}
