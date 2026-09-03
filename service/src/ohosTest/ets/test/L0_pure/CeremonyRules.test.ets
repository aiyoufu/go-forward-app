import { describe, it, expect } from '@ohos/hypium'
import {
  willClearAllAfterRepay,
  ALL_CLEARED_CEREMONY_MIN_SETTLED
} from '../../../../main/ets/service/CeremonyRules'

export default function CeremonyRulesTest() {
  describe('willClearAllAfterRepay', () => {
    it('多笔在还_不触发全清', 0, async () => {
      expect(willClearAllAfterRepay(2, 'payoff', 1, 10)).assertFalse()
      expect(willClearAllAfterRepay(3, 'period', 1, 10)).assertFalse()
    })

    it('零笔在还_不触发', 0, async () => {
      expect(willClearAllAfterRepay(0, 'payoff', 0, 10)).assertFalse()
    })

    it('最后一笔_一次性还清_且达门槛_触发', 0, async () => {
      expect(willClearAllAfterRepay(1, 'payoff', 5, ALL_CLEARED_CEREMONY_MIN_SETTLED)).assertTrue()
      expect(willClearAllAfterRepay(1, 'payoff', 5, 8)).assertTrue()
    })

    it('最后一笔_本期还后结清_且达门槛_触发', 0, async () => {
      expect(willClearAllAfterRepay(1, 'period', 1, 5)).assertTrue()
      expect(willClearAllAfterRepay(1, 'period', 0, 6)).assertTrue()
    })

    it('最后一笔结清_但累计不足5笔_不触发仪式', 0, async () => {
      expect(willClearAllAfterRepay(1, 'payoff', 1, 1)).assertFalse()
      expect(willClearAllAfterRepay(1, 'payoff', 1, 4)).assertFalse()
      expect(willClearAllAfterRepay(1, 'period', 1, 3)).assertFalse()
    })

    it('最后一笔_本期还不结清_不触发', 0, async () => {
      expect(willClearAllAfterRepay(1, 'period', 2, 10)).assertFalse()
      expect(willClearAllAfterRepay(1, 'period', 12, 10)).assertFalse()
    })

    it('门槛常量_为5', 0, async () => {
      expect(ALL_CLEARED_CEREMONY_MIN_SETTLED).assertEqual(5)
    })
  })
}
