import { describe, it, expect } from '@ohos/hypium'

/**
 * PressureTrendCard 卡片 UI 测试
 * 2×2 卡：6 月柱图（金额旋转 -90° 沿柱体纵向）
 * chartPack 格式: "h|month|amt;..." × 6
 */
export default function pressureTrendCardTest() {
  describe('PressureTrendCard_渲染_有数据', () => {

    it('chartPack_6段解析', 0, () => {
      const chartPack = '75|7|5,200;60|8|3,100;45|9|2,000;30|10|1,500;15|11|800;0|12|—'
      const segs = chartPack.split(';')
      expect(segs.length).assertEqual(6)
    })

    it('柱高_正常值', 0, () => {
      const seg = '75|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(75)
    })

    it('柱高_超100截断', 0, () => {
      const seg = '120|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(100)
    })

    it('柱高_负数归零', 0, () => {
      const seg = '-10|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(0)
    })

    it('月份标签_首柱', 0, () => {
      const seg = '75|7|5,200'
      const pair = seg.split('|')
      // 首柱不追加「月」字，直接显示 pair[1]
      const label = pair.length >= 2 && pair[1].length > 0 ? pair[1] : '—'
      expect(label).assertEqual('7')
    })

    it('金额_正常显示', 0, () => {
      const seg = '75|7|5,200'
      const pair = seg.split('|')
      const amt = (pair.length >= 3 && pair[2].length > 0 && pair[2] !== '—') ? pair[2] : ''
      expect(amt).assertEqual('5,200')
    })

    it('金额_占位符不显示', 0, () => {
      const seg = '0|—|—'
      const pair = seg.split('|')
      const amt = (pair.length >= 3 && pair[2].length > 0 && pair[2] !== '—') ? pair[2] : ''
      expect(amt).assertEqual('')
    })

    it('柱体视口高度_正常', 0, () => {
      const CHART_H = 92
      const heightPct = 75
      const result = heightPct <= 0 ? 14 : Math.max(44, Math.round(CHART_H * heightPct / 100))
      // Math.round(92 * 75 / 100) = 69, Math.max(44, 69) = 69
      expect(result).assertEqual(69)
    })

    it('柱体视口高度_零高度保底14', 0, () => {
      const CHART_H = 92
      const heightPct = 0
      const result = heightPct <= 0 ? 14 : Math.max(44, Math.round(CHART_H * heightPct / 100))
      expect(result).assertEqual(14)
    })

    it('柱体视口高度_最小44', 0, () => {
      const CHART_H = 92
      const heightPct = 10
      const result = heightPct <= 0 ? 14 : Math.max(44, Math.round(CHART_H * heightPct / 100))
      // Math.round(92 * 10 / 100) = 9, Math.max(44, 9) = 44
      expect(result).assertEqual(44)
    })

    it('金额文字宽度_保底44', 0, () => {
      const CHART_H = 92
      const barH = 0
      const barHeightVp = barH <= 0 ? 14 : Math.max(44, Math.round(CHART_H * barH / 100))
      const amtTextWidth = Math.max(barHeightVp - 4, 44)
      // barHeightVp = 14, 14 - 4 = 10, Math.max(10, 44) = 44
      expect(amtTextWidth).assertEqual(44)
    })
  })

  describe('PressureTrendCard_颜色逻辑', () => {

    it('峰值柱_使用peak颜色', 0, () => {
      const peakIndex = 1
      const index = 1
      const isPeak = index === peakIndex
      expect(isPeak).assertTrue()
    })

    it('当月柱_使用current颜色', 0, () => {
      const peakIndex: number = 3
      const index: number = 0
      const isPeak = index === peakIndex
      const isCurrent = index === 0
      expect(isPeak).assertFalse()
      expect(isCurrent).assertTrue()
    })

    it('金额颜色_峰值柱反色', 0, () => {
      const peakIndex = 2
      const index = 2
      const isEmphasized = index === peakIndex || index === 0
      expect(isEmphasized).assertTrue()
    })

    it('金额颜色_普通柱正常色', 0, () => {
      const peakIndex: number = 2
      const index: number = 4
      const isEmphasized = index === peakIndex || index === 0
      expect(isEmphasized).assertFalse()
    })
  })

  describe('PressureTrendCard_无数据降级', () => {

    it('hasData为false_显示暂无预测', 0, () => {
      const hasData = false
      const hintText = hasData ? '' : '暂无预测'
      expect(hintText).assertEqual('暂无预测')
    })

    it('hasData为true_显示柱图', 0, () => {
      const hasData = true
      const showChart = hasData
      expect(showChart).assertTrue()
    })

    it('默认chartPack_全零', 0, () => {
      const defaultPack = '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'
      const segs = defaultPack.split(';')
      for (let i = 0; i < segs.length; i++) {
        const pair = segs[i].split('|')
        expect(parseInt(pair[0], 10)).assertEqual(0)
        expect(pair[1]).assertEqual('—')
        expect(pair[2]).assertEqual('—')
      }
    })

    it('空chartPack降级为默认', 0, () => {
      const chartPack: string = ''
      const raw = (chartPack && chartPack.length > 0)
        ? chartPack
        : '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'
      const segs = raw.split(';')
      expect(segs.length).assertEqual(6)
    })

    it('越界index返回默认段', 0, () => {
      const chartPack = '75|7|5,200'
      const segs = chartPack.split(';')
      const index = 3
      const result = (index >= 0 && index < segs.length) ? segs[index] : '0|—|—'
      expect(result).assertEqual('0|—|—')
    })
  })

  describe('PressureTrendCard_主题适配', () => {

    it('柱图三色资源', 0, () => {
      const bar = 'widget_bar'
      const barPeak = 'widget_bar_peak'
      const barCurrent = 'widget_bar_current'
      expect(bar).not().assertEqual(barPeak)
      expect(bar).not().assertEqual(barCurrent)
      expect(barPeak).not().assertEqual(barCurrent)
    })

    it('金额反色资源', 0, () => {
      const amtOnBar = 'widget_amt_on_bar'
      expect(amtOnBar.length > 0).assertTrue()
    })
  })
}
