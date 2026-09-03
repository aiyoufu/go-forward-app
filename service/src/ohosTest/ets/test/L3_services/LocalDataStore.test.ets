import { describe, it, expect } from '@ohos/hypium'
import { LocalDataStore } from '../../../../main/ets/service/sync/LocalDataStore'
import { DashboardSummary } from '../../../../main/ets/service/DashboardTypes'

export default function localDataStoreTest() {
  describe('LocalDataStore', () => {
    it('invalidateAll抬epoch', 0, () => {
      const e0 = LocalDataStore.getEpoch()
      LocalDataStore.invalidateAll()
      expect(LocalDataStore.getEpoch() > e0).assertTrue()
    })
    it('setDebts_getDebts', 0, () => {
      LocalDataStore.invalidateDebts()
      expect(LocalDataStore.getDebts()).assertNull()
    })
    it('setSummary_getSummary', 0, () => {
      const s = new DashboardSummary()
      s.remainingDebt = 42
      LocalDataStore.setSummary(s)
      const g = LocalDataStore.getSummary()
      expect(g !== null).assertTrue()
      expect(g!.remainingDebt).assertEqual(42)
      LocalDataStore.invalidateAll()
    })
    it('isEpochCurrent', 0, () => {
      const e = LocalDataStore.getEpoch()
      expect(LocalDataStore.isEpochCurrent(e)).assertTrue()
      LocalDataStore.invalidateAll()
      expect(LocalDataStore.isEpochCurrent(e)).assertFalse()
    })
  })
}
