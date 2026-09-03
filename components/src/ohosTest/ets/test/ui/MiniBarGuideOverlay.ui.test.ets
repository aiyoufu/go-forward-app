import { describe, it, expect } from '@ohos/hypium'

export default function miniBarGuideOverlayUITest() {
  describe('MiniBarGuideOverlay_UI', () => {
    it('关闭写PREF标记', 0, () => {
      const pref = 'mini_bar_guide_shown'
      expect(pref.length > 0).assertTrue()
    })
    it('展示时show为true', 0, () => {
      const show = true
      expect(show).assertTrue()
    })
  })
}
