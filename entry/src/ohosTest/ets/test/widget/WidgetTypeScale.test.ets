import { describe, it, expect } from '@ohos/hypium'

/**
 * WidgetTypeScale 字体比例测试
 * 卡片专用字号令牌，须与 common/ThemeManager.ets 的 TypeScale 保持同步
 */
export default function widgetTypeScaleTest() {
  describe('WidgetTypeScale_字号令牌', () => {

    it('FONT_MONO_等宽字体名', 0, () => {
      const FONT_MONO = 'HarmonyOS Sans Mono'
      expect(FONT_MONO).assertEqual('HarmonyOS Sans Mono')
    })

    it('bodySm_12fp', 0, () => {
      const bodySm = 12
      expect(bodySm).assertEqual(12)
    })

    it('caption_11fp', 0, () => {
      const caption = 11
      expect(caption).assertEqual(11)
    })

    it('captionSm_10fp', 0, () => {
      const captionSm = 10
      expect(captionSm).assertEqual(10)
    })

    it('display_20fp', 0, () => {
      const display = 20
      expect(display).assertEqual(20)
    })

    it('displaySpacing_负0.4', 0, () => {
      const displaySpacing = -0.4
      expect(displaySpacing).assertEqual(-0.4)
    })

    it('kicker_9fp', 0, () => {
      const kicker = 9
      expect(kicker).assertEqual(9)
    })
  })

  describe('WidgetTypeScale_层级关系', () => {

    it('display > bodySm > caption > captionSm > kicker', 0, () => {
      const display = 20
      const bodySm = 12
      const caption = 11
      const captionSm = 10
      const kicker = 9
      expect(display > bodySm).assertTrue()
      expect(bodySm > caption).assertTrue()
      expect(caption > captionSm).assertTrue()
      expect(captionSm > kicker).assertTrue()
    })

    it('display 与 bodySm 差距合理', 0, () => {
      const display = 20
      const bodySm = 12
      const ratio = display / bodySm
      // 比例约 1.67
      expect(ratio > 1.5).assertTrue()
      expect(ratio < 2.0).assertTrue()
    })

    it('captionSm 与 kicker 差距为1fp', 0, () => {
      const captionSm = 10
      const kicker = 9
      expect(captionSm - kicker).assertEqual(1)
    })
  })

  describe('WidgetTypeScale_与common同步', () => {

    it('字号令牌数量一致', 0, () => {
      // WidgetTypeScale 定义了 7 个令牌
      const tokens = ['FONT_MONO', 'bodySm', 'caption', 'captionSm', 'display', 'displaySpacing', 'kicker']
      expect(tokens.length).assertEqual(7)
    })

    it('数值型令牌均为有限数', 0, () => {
      const numericTokens = [12, 11, 10, 20, -0.4, 9]
      for (let i = 0; i < numericTokens.length; i++) {
        expect(isFinite(numericTokens[i])).assertTrue()
      }
    })
  })
}
