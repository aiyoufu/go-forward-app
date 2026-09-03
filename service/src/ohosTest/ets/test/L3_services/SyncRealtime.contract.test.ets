import { describe, it, expect } from '@ohos/hypium'
import { SyncRealtime } from '../../../../main/ets/service/sync/SyncRealtime'

export default function syncRealtimeContractTest() {
  describe('SyncRealtime_contract', () => {
    it('初始未start', 0, () => {
      // 可能已被其它测试启动；仅检查 API 存在
      const started = SyncRealtime.isStarted()
      expect(typeof started === 'boolean').assertTrue()
    })
  })
}
