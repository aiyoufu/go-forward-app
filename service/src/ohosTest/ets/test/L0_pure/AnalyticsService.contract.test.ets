import { describe, it, expect } from '@ohos/hypium'
import { AnalyticsService } from '../../../../main/ets/service/AnalyticsService'

/**
 * 白盒契约：事件语义方法存在且不抛（缓冲可未 init Preferences）
 * 真机 Preferences 未 init 时 track 内部 catch，不崩溃
 */
export default function analyticsServiceContractTest() {
  describe('AnalyticsService_contract', () => {
    it('setEnabled_false后track不崩溃', 0, () => {
      AnalyticsService.setEnabled(false)
      AnalyticsService.track('app_launch', '{"cold":true}')
      AnalyticsService.setEnabled(true)
      expect(true).assertTrue()
    })
    it('语义方法可调用', 0, () => {
      AnalyticsService.setEnabled(false)
      AnalyticsService.trackTabView('home')
      AnalyticsService.trackRepaySuccess('period')
      AnalyticsService.trackAuthSuccess('login')
      AnalyticsService.trackSyncResult(true, 'manual')
      AnalyticsService.setEnabled(true)
      expect(true).assertTrue()
    })
    it('setNextRecordSource_consume', 0, () => {
      AnalyticsService.setNextRecordSource('ai_live')
      const s = AnalyticsService.consumeRecordSource()
      expect(s).assertEqual('ai_live')
      const s2 = AnalyticsService.consumeRecordSource()
      expect(s2).assertEqual('manual_form')
    })
    it('setNextAiLaunch_consume', 0, () => {
      AnalyticsService.setNextAiLaunch('camera')
      const m = AnalyticsService.consumeAiLaunch()
      expect(m).assertEqual('camera')
    })
    it('bufferSize非负', 0, () => {
      expect(AnalyticsService.bufferSize() >= 0).assertTrue()
    })
  })
}
