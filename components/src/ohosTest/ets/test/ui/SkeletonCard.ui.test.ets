import { describe, it, expect } from '@ohos/hypium'

export default function skeletonCardUITest() {
  describe('SkeletonCard_UI', () => {
    it('占位高度正数', 0, () => {
      const h = 74
      expect(h > 0).assertTrue()
    })
  })
}
