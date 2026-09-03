import { describe, it, expect } from '@ohos/hypium'
import { ImmersiveTitleBar } from '../../../main/ets/common/ImmersiveTitleBar'

export default function immersiveTitleBarTest() {
  describe('ImmersiveTitleBar', () => {
    it('floatingBarMaterial可调用', 0, () => {
      // 返回材质配置对象；不抛即通过
      const m = ImmersiveTitleBar.floatingBarMaterial()
      expect(m !== null && m !== undefined).assertTrue()
    })
  })
}
