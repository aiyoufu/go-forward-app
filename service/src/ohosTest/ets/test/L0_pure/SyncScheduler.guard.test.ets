import { describe, it, expect } from '@ohos/hypium'
import { SyncScheduler } from '../../../../main/ets/service/sync/SyncScheduler'
import { SyncService } from '../../../../main/ets/service/sync/SyncService'

export default function syncSchedulerGuardTest() {
  describe('SyncScheduler_syncingGuard', () => {
    it('未超时保持同步中', 0, () => {
      expect(SyncScheduler.shouldReleaseSyncingUi('syncing', 1000, 45000)).assertFalse()
    })

    it('超时必须离开同步中', 0, () => {
      expect(SyncScheduler.shouldReleaseSyncingUi('syncing', 45000, 45000)).assertTrue()
    })

    it('已结束不释放', 0, () => {
      expect(SyncScheduler.shouldReleaseSyncingUi('ok', 60000, 45000)).assertFalse()
    })
  })

  describe('SyncScheduler_homeHydrated', () => {
    it('reset后未hydrate', 0, () => {
      SyncScheduler.resetHomeHydrated()
      expect(SyncScheduler.isHomeHydrated()).assertFalse()
    })

    it('mark后已hydrate', 0, () => {
      SyncScheduler.markHomeHydrated()
      expect(SyncScheduler.isHomeHydrated()).assertTrue()
      SyncScheduler.resetHomeHydrated()
    })
  })

  describe('SyncService_pageDidStall', () => {
    it('首页不判定卡住', 0, () => {
      expect(SyncService.pageDidStall('', 'id-1', 0)).assertFalse()
    })

    it('翻页后首页键重复视为卡住', 0, () => {
      expect(SyncService.pageDidStall('id-1', 'id-1', 1)).assertTrue()
    })

    it('翻页键变化继续', 0, () => {
      expect(SyncService.pageDidStall('id-1', 'id-2', 1)).assertFalse()
    })
  })
}
