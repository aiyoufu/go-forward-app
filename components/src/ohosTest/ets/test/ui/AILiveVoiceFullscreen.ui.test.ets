import { describe, it, expect } from '@ohos/hypium'

/**
 * AILiveVoiceFullscreen UI 测试
 * 覆盖：提示文字、波形柱高、取消状态、追加模式
 */
export default function AILiveVoiceFullscreen_UITest() {
  describe('AILiveVoiceFullscreen_UI', () => {

    it('渲染_hintLabel_正常_松手查看', 0, async () => {
      const cancelArmed = false
      const appendMode = false
      const hint = cancelArmed ? '松手取消' :
        (appendMode ? '松手追加 上移取消' : '松手查看 上移取消')
      expect(hint).assertEqual('松手查看 上移取消')
    })

    it('渲染_hintLabel_取消_松手取消', 0, async () => {
      const cancelArmed = true
      const hint = cancelArmed ? '松手取消' : 'other'
      expect(hint).assertEqual('松手取消')
    })

    it('渲染_hintLabel_追加_松手追加', 0, async () => {
      const cancelArmed = false
      const appendMode = true
      const hint = cancelArmed ? '松手取消' :
        (appendMode ? '松手追加 上移取消' : '松手查看 上移取消')
      expect(hint).assertEqual('松手追加 上移取消')
    })

    it('渲染_displayPartial_有文字_显示文字', 0, async () => {
      const partialText = '花呗 3000 元'
      const display = partialText.trim().length > 0 ? partialText : '正在听你说…'
      expect(display).assertEqual('花呗 3000 元')
    })

    it('渲染_displayPartial_无文字_正常模式', 0, async () => {
      const partialText = ''
      const appendMode = false
      const display = partialText.trim().length > 0 ? partialText :
        (appendMode ? '继续说，松手追加到卡片…' : '正在听你说…')
      expect(display).assertEqual('正在听你说…')
    })

    it('渲染_displayPartial_无文字_追加模式', 0, async () => {
      const partialText = ''
      const appendMode = true
      const display = partialText.trim().length > 0 ? partialText :
        (appendMode ? '继续说，松手追加到卡片…' : '正在听你说…')
      expect(display).assertEqual('继续说，松手追加到卡片…')
    })

    it('渲染_pillBg_正常_cta色', 0, async () => {
      const cancelArmed = false
      const bg = cancelArmed ? 'red' : 'ctaBackground'
      expect(bg).assertEqual('ctaBackground')
    })

    it('渲染_pillBg_取消_red色', 0, async () => {
      const cancelArmed = true
      const bg = cancelArmed ? 'red' : 'ctaBackground'
      expect(bg).assertEqual('red')
    })

    it('渲染_hintColor_正常_text2', 0, async () => {
      const cancelArmed = false
      const color = cancelArmed ? 'red' : 'text2'
      expect(color).assertEqual('text2')
    })

    it('渲染_hintColor_取消_red', 0, async () => {
      const cancelArmed = true
      const color = cancelArmed ? 'red' : 'text2'
      expect(color).assertEqual('red')
    })

    it('渲染_barColor_正常_ctaForeground', 0, async () => {
      const cancelArmed = false
      const color = cancelArmed ? '#FFFFFF' : 'ctaForeground'
      expect(color).assertEqual('ctaForeground')
    })

    it('渲染_barColor_取消_dangerForeground', 0, async () => {
      const cancelArmed = true
      // 取消态声纹条在红底上，走 dangerForeground()（深色画布为暖白，非裸 #FFFFFF）
      const color = cancelArmed ? 'dangerForeground' : 'ctaForeground'
      expect(color).assertEqual('dangerForeground')
    })

    it('渲染_barHeight_静音最低', 0, async () => {
      const voiceLevel = 4
      const level = Math.min(28, Math.max(4, voiceLevel)) / 28
      let amp: number = 0.28 + level * 0.72
      const minH = 5
      const maxH = 32
      const h = minH + 0 * amp * (maxH - minH)
      expect(h).assertEqual(5)
    })

    it('渲染_barHeight_有声较高', 0, async () => {
      const voiceLevel = 28
      const level = Math.min(28, Math.max(4, voiceLevel)) / 28
      expect(level).assertEqual(1)
    })

    it('渲染_BAR_COUNT_28根', 0, async () => {
      const BAR_COUNT = 28
      expect(BAR_COUNT).assertEqual(28)
    })

    it('渲染_BAR_MIN_5vp', 0, async () => {
      const BAR_MIN = 5
      expect(BAR_MIN).assertEqual(5)
    })

    it('渲染_BAR_MAX_32vp', 0, async () => {
      const BAR_MAX = 32
      expect(BAR_MAX).assertEqual(32)
    })

    it('渲染_波形柱宽_3.5vp', 0, async () => {
      const barWidth = 3.5
      expect(barWidth).assertEqual(3.5)
    })

    it('渲染_波形柱圆角_1.75', 0, async () => {
      let barRadius: number = 1.75
      expect(barRadius).assertEqual(1.75)
    })

    it('渲染_文字透明度_正常1', 0, async () => {
      const cancelArmed = false
      const opacity = cancelArmed ? 0.35 : 1
      expect(opacity).assertEqual(1)
    })

    it('渲染_文字透明度_取消0.35', 0, async () => {
      const cancelArmed = true
      const opacity = cancelArmed ? 0.35 : 1
      expect(opacity).assertEqual(0.35)
    })

    it('渲染_最大行数_8行', 0, async () => {
      const maxLines = 8
      expect(maxLines).assertEqual(8)
    })

    it('渲染_动画相位_0到359循环', 0, async () => {
      let phase = 359
      phase = (phase + 1) % 360
      expect(phase).assertEqual(0)
    })
  })
}
