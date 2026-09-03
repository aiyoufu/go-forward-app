import { describe, it, expect } from '@ohos/hypium'
import { PerfTrace } from '../../../../main/ets/service/PerfTrace'

export default function perfTraceTest() {
  describe('PerfTrace', () => {
    it('boot后T1T2初始为负', 0, () => {
      PerfTrace.boot()
      expect(PerfTrace.getT1Ms() < 0).assertTrue()
      expect(PerfTrace.getT2Ms() < 0).assertTrue()
    })
    it('mark_T1后getT1Ms非负', 0, () => {
      PerfTrace.boot()
      const ms = PerfTrace.mark('T1_main_nav')
      expect(ms >= 0).assertTrue()
      expect(PerfTrace.getT1Ms() >= 0).assertTrue()
    })
    it('mark_T2后getT2Ms不小于T1', 0, () => {
      PerfTrace.boot()
      PerfTrace.mark('T1_main_nav')
      PerfTrace.mark('T2_home_ready')
      expect(PerfTrace.getT2Ms() >= PerfTrace.getT1Ms()).assertTrue()
    })
    it('未boot时mark仍返回非负', 0, () => {
      // mark 可自举 t0
      const ms = PerfTrace.mark('probe')
      expect(ms >= 0).assertTrue()
    })
  })
}
