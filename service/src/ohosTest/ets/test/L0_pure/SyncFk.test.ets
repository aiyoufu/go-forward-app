import { describe, it, expect } from '@ohos/hypium'
import { SyncFk } from '../../../../main/ets/service/sync/SyncFk'

export default function syncFkTest() {
  describe('SyncFk_applyMap', () => {
    it('命中映射返回云id', 0, async () => {
      const map = new Map<string, string>()
      map.set('local-1', 'cloud-1')
      expect(SyncFk.applyMap('local-1', map)).assertEqual('cloud-1')
    })
    it('未命中保留原id', 0, async () => {
      const map = new Map<string, string>()
      expect(SyncFk.applyMap('local-x', map)).assertEqual('local-x')
    })
    it('空id返回空', 0, async () => {
      const map = new Map<string, string>()
      expect(SyncFk.applyMap('', map)).assertEqual('')
    })
  })
}
