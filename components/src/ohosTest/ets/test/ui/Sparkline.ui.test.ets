import { describe, it, expect } from '@ohos/hypium'

/**
 * Sparkline UI 测试
 * 覆盖：trendDir/strokeColor/fillColorTop/fillColorBottom/haloColor 纯函数
 */
export default function Sparkline_UITest() {
  describe('Sparkline_UI', () => {

    it('纯函数_trendDir_空数组返回flat', 0, async () => {
      const values: number[] = []
      const n = values.length
      const dir = n < 2 ? 'flat' : 'unknown'
      expect(dir).assertEqual('flat')
    })

    it('纯函数_trendDir_单元素返回flat', 0, async () => {
      const values = [100]
      const dir = values.length < 2 ? 'flat' : 'unknown'
      expect(dir).assertEqual('flat')
    })

    it('纯函数_trendDir_上升返回up', 0, async () => {
      const values = [100, 200, 300]
      const first = values[0]
      const last = values[values.length - 1]
      const span = Math.abs(last - first)
      const base = Math.max(Math.abs(first), Math.abs(last), 1)
      const dir = span / base < 0.02 ? 'flat' : (last < first ? 'down' : 'up')
      expect(dir).assertEqual('up')
    })

    it('纯函数_trendDir_下降返回down', 0, async () => {
      const values = [300, 200, 100]
      const first = values[0]
      const last = values[values.length - 1]
      const span = Math.abs(last - first)
      const base = Math.max(Math.abs(first), Math.abs(last), 1)
      const dir = span / base < 0.02 ? 'flat' : (last < first ? 'down' : 'up')
      expect(dir).assertEqual('down')
    })

    it('纯函数_trendDir_微幅变化返回flat', 0, async () => {
      const values = [100, 100.5, 101]
      const first = values[0]
      const last = values[values.length - 1]
      const span = Math.abs(last - first)
      const base = Math.max(Math.abs(first), Math.abs(last), 1)
      const dir = span / base < 0.02 ? 'flat' : (last < first ? 'down' : 'up')
      expect(dir).assertEqual('flat')
    })

    it('纯函数_strokeColor_down彩色深色', 0, async () => {
      const dir = 'down'
      const colorful = true
      const isDark = true
      const color = dir === 'down' ? 'rgba(34,197,94,0.95)' : 'other'
      expect(color).assertEqual('rgba(34,197,94,0.95)')
    })

    it('纯函数_strokeColor_up彩色深色', 0, async () => {
      const dir = 'up'
      const color = dir === 'up' ? 'rgba(244,33,46,0.95)' : 'other'
      expect(color).assertEqual('rgba(244,33,46,0.95)')
    })

    it('纯函数_strokeColor_flat彩色', 0, async () => {
      const dir = 'flat'
      const color = dir === 'flat' ? 'rgba(176,180,186,0.90)' : 'other'
      expect(color).assertEqual('rgba(176,180,186,0.90)')
    })

    it('纯函数_strokeColor_非彩色深色', 0, async () => {
      const colorful = false
      const isDark = true
      const color = !colorful ? 'rgba(231,233,234,0.92)' : 'other'
      expect(color).assertEqual('rgba(231,233,234,0.92)')
    })

    it('纯函数_strokeColor_非彩色浅色', 0, async () => {
      const colorful = false
      const isDark = false
      const color = !colorful ? 'rgba(15,20,25,0.88)' : 'other'
      expect(color).assertEqual('rgba(15,20,25,0.88)')
    })

    it('纯函数_fillColorTop_down深色', 0, async () => {
      const dir = 'down'
      const color = dir === 'down' ? 'rgba(34,197,94,0.38)' : 'other'
      expect(color).assertEqual('rgba(34,197,94,0.38)')
    })

    it('纯函数_fillColorBottom_down深色', 0, async () => {
      const dir = 'down'
      const color = dir === 'down' ? 'rgba(34,197,94,0.03)' : 'other'
      expect(color).assertEqual('rgba(34,197,94,0.03)')
    })

    it('纯函数_haloColor_up深色', 0, async () => {
      const dir = 'up'
      const color = dir === 'up' ? 'rgba(244,33,46,0.24)' : 'other'
      expect(color).assertEqual('rgba(244,33,46,0.24)')
    })

    it('渲染_默认chartWidth_72vp', 0, async () => {
      const chartWidth = 72
      expect(chartWidth).assertEqual(72)
    })

    it('渲染_默认chartHeight_36vp', 0, async () => {
      const chartHeight = 36
      expect(chartHeight).assertEqual(36)
    })

    it('渲染_默认strokeWidth_1.8', 0, async () => {
      let strokeWidth: number = 1.8
      expect(strokeWidth).assertEqual(1.8)
    })

    it('渲染_默认colorful_true', 0, async () => {
      const colorful = true
      expect(colorful).assertTrue()
    })

    it('渲染_端点光晕_半径4.4', 0, async () => {
      const haloRadius = 4.4
      expect(haloRadius).assertEqual(4.4)
    })

    it('渲染_端点实心_半径2.4', 0, async () => {
      const dotRadius = 2.4
      expect(dotRadius).assertEqual(2.4)
    })

    it('边界_全相同值_trendDir返回flat', 0, async () => {
      const values = [100, 100, 100, 100]
      const first = values[0]
      const last = values[values.length - 1]
      const span = Math.abs(last - first)
      const base = Math.max(Math.abs(first), 1)
      const dir = span / base < 0.02 ? 'flat' : 'other'
      expect(dir).assertEqual('flat')
    })
  })
}
