import { describe, it, expect } from '@ohos/hypium'
import { bottomClearance } from '../../../main/ets/components/EmptyState'

export default function EmptyStateTest() {
  describe('bottomClearance', () => {
    it('bottomExtra>=0_返回bottomExtra', 0, async () => {
      expect(bottomClearance(50)).assertEqual(50)
    })
    it('bottomExtra为0_返回0', 0, async () => {
      expect(bottomClearance(0)).assertEqual(0)
    })
    it('bottomExtra为负_返回FLOATING_TAB_CLEARANCE_不再叠加安全区', 0, async () => {
      // Constants.FLOATING_TAB_CLEARANCE = 96（已含底栏+呼吸间距；HdsTabs 自避让安全区）
      expect(bottomClearance(-1)).assertEqual(96)
    })
    it('bottomExtra为负_恒定值不随设备变化', 0, async () => {
      expect(bottomClearance(-1)).assertEqual(bottomClearance(-99))
    })
  })
}
