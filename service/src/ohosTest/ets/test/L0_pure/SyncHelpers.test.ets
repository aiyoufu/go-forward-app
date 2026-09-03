import { describe, it, expect } from '@ohos/hypium'
import { SyncHelpers } from '../../../../main/ets/service/sync/SyncHelpers'
import { SyncStats } from '../../../../main/ets/service/sync/SyncTypes'

export default function syncHelpersTest() {
  describe('SyncHelpers_buildSummary', () => {
    it('多条记录汇总', 0, async () => {
      const s1 = new SyncStats('debts')
      s1.pushed = 3
      s1.pulled = 5
      const s2 = new SyncStats('subscriptions')
      s2.pushed = 2
      s2.pulled = 1
      const result = SyncHelpers.buildSummary([s1, s2])
      expect(result).assertEqual('推送 5 条，拉取 6 条')
    })
    it('空数组', 0, async () => {
      expect(SyncHelpers.buildSummary([])).assertEqual('推送 0 条，拉取 0 条')
    })
    it('单条零推拉', 0, async () => {
      const s = new SyncStats('debts')
      expect(SyncHelpers.buildSummary([s])).assertEqual('推送 0 条，拉取 0 条')
    })
  })

  describe('SyncHelpers_pickCloudTimestamp', () => {
    it('有updated_at优先', 0, async () => {
      expect(SyncHelpers.pickCloudTimestamp('2025-06-01', '2025-01-01')).assertEqual('2025-06-01')
    })
    it('updated_at为空用created_at', 0, async () => {
      expect(SyncHelpers.pickCloudTimestamp('', '2025-01-01')).assertEqual('2025-01-01')
    })
    it('都为空返回空', 0, async () => {
      expect(SyncHelpers.pickCloudTimestamp('', '')).assertEqual('')
    })
  })

  describe('SyncHelpers_shouldPreferCloud', () => {
    it('云时间更新_返回true', 0, async () => {
      expect(SyncHelpers.shouldPreferCloud('2025-01-01', '2025-06-01')).assertTrue()
    })
    it('云时间更旧_返回false', 0, async () => {
      expect(SyncHelpers.shouldPreferCloud('2025-06-01', '2025-01-01')).assertFalse()
    })
    it('云时间为空_返回false', 0, async () => {
      expect(SyncHelpers.shouldPreferCloud('2025-01-01', '')).assertFalse()
    })
    it('本地时间为空_云有值_返回true', 0, async () => {
      expect(SyncHelpers.shouldPreferCloud('', '2025-01-01')).assertTrue()
    })
    it('都为空_返回false', 0, async () => {
      expect(SyncHelpers.shouldPreferCloud('', '')).assertFalse()
    })
    it('相同时间_返回false', 0, async () => {
      expect(SyncHelpers.shouldPreferCloud('2025-06-01', '2025-06-01')).assertFalse()
    })
  })

  describe('SyncHelpers_advanceCursor', () => {
    it('取较大时间戳', 0, async () => {
      expect(SyncHelpers.advanceCursor('2025-01-01', ['2025-02-01', '2025-01-15']))
        .assertEqual('2025-02-01')
    })
    it('空列表保留prev', 0, async () => {
      expect(SyncHelpers.advanceCursor('2025-01-01', [])).assertEqual('2025-01-01')
    })
  })

  describe('SyncHelpers_shouldDeleteOrphan', () => {
    it('云端已无且非pending_应删', 0, async () => {
      expect(SyncHelpers.shouldDeleteOrphan('c1', ['c2'], [])).assertTrue()
    })
    it('云端仍有_不删', 0, async () => {
      expect(SyncHelpers.shouldDeleteOrphan('c1', ['c1', 'c2'], [])).assertFalse()
    })
    it('pending保护_不删', 0, async () => {
      expect(SyncHelpers.shouldDeleteOrphan('c1', [], ['c1'])).assertFalse()
    })
    it('无cloudId_不删', 0, async () => {
      expect(SyncHelpers.shouldDeleteOrphan('', ['c1'], [])).assertFalse()
    })
  })

  describe('SyncHelpers_missingCloudIds', () => {
    it('云有本地无_应补拉', 0, async () => {
      const missing = SyncHelpers.missingCloudIds(['acc1', 'sub1', 'debt1'], ['debt1'])
      expect(missing.length).assertEqual(2)
      expect(missing[0]).assertEqual('acc1')
      expect(missing[1]).assertEqual('sub1')
    })
    it('本地已有_不补', 0, async () => {
      const missing = SyncHelpers.missingCloudIds(['acc1'], ['acc1'])
      expect(missing.length).assertEqual(0)
    })
    it('空云id跳过', 0, async () => {
      const missing = SyncHelpers.missingCloudIds(['', 'acc1'], [])
      expect(missing.length).assertEqual(1)
      expect(missing[0]).assertEqual('acc1')
    })
  })

  describe('SyncHelpers_buildSummary_含失败', () => {
    it('有failed时追加文案', 0, async () => {
      const s = new SyncStats('debts')
      s.pushed = 1
      s.pulled = 2
      s.failed = 3
      const msg = SyncHelpers.buildSummary([s])
      expect(msg.indexOf('失败 3') >= 0).assertTrue()
    })
  })

  describe('SyncHelpers_hasHardFailures', () => {
    it('全零_返回false', 0, async () => {
      const s = new SyncStats('debts')
      expect(SyncHelpers.hasHardFailures([s])).assertFalse()
    })
    it('有失败_返回true', 0, async () => {
      const s = new SyncStats('debts')
      s.failed = 1
      expect(SyncHelpers.hasHardFailures([s])).assertTrue()
    })
  })
}
