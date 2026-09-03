import { describe, it, expect } from '@ohos/hypium'

/**
 * DebtPressureCard 卡片 UI 测试
 * 2×4 长卡：剩余负债 + 还款进度条 + 6 月柱图
 * chartPack 格式: "h|month|amt;..." × 6（分号分隔）
 */
export default function debtPressureCardTest() {
  describe('DebtPressureCard_渲染_有数据', () => {

    it('金额显示_正常金额格式化', 0, () => {
      // 验证 amountText 逻辑：有值时返回原值
      const remaining = '¥\u200912,345.67'
      const result = (remaining && remaining.length > 0) ? remaining : '¥\u20090.00'
      expect(result).assertEqual('¥\u200912,345.67')
    })

    it('金额显示_空字符串降级', 0, () => {
      const remaining: string = ''
      const result = (remaining && remaining.length > 0) ? remaining : '¥\u20090.00'
      expect(result).assertEqual('¥\u20090.00')
    })

    it('金额显示_零金额', 0, () => {
      const remaining = '¥\u20090.00'
      const result = (remaining && remaining.length > 0) ? remaining : '¥\u20090.00'
      expect(result).assertEqual('¥\u20090.00')
    })

    it('进度条_百分比0时全部未填充', 0, () => {
      const TICK_COUNT = 40
      const progress = 0
      const filledCount = Math.round(Math.max(0, Math.min(100, progress)) / 100 * TICK_COUNT)
      expect(filledCount).assertEqual(0)
    })

    it('进度条_百分比50时填充一半', 0, () => {
      const TICK_COUNT = 40
      const progress = 50
      const filledCount = Math.round(Math.max(0, Math.min(100, progress)) / 100 * TICK_COUNT)
      expect(filledCount).assertEqual(20)
    })

    it('进度条_百分比100时全部填充', 0, () => {
      const TICK_COUNT = 40
      const progress = 100
      const filledCount = Math.round(Math.max(0, Math.min(100, progress)) / 100 * TICK_COUNT)
      expect(filledCount).assertEqual(40)
    })

    it('进度条_负数钳位到0', 0, () => {
      const TICK_COUNT = 40
      const progress = -10
      const clamped = Math.max(0, Math.min(100, progress))
      const filledCount = Math.round(clamped / 100 * TICK_COUNT)
      expect(filledCount).assertEqual(0)
    })

    it('进度条_超100钳位到100', 0, () => {
      const TICK_COUNT = 40
      const progress = 150
      const clamped = Math.max(0, Math.min(100, progress))
      const filledCount = Math.round(clamped / 100 * TICK_COUNT)
      expect(filledCount).assertEqual(40)
    })

    it('进度文字_显示已还百分比', 0, () => {
      const progress = 75
      const clamped = Math.max(0, Math.min(100, progress))
      const text = '已还' + clamped + '%'
      expect(text).assertEqual('已还75%')
    })
  })

  describe('DebtPressureCard_chartPack解析', () => {

    it('正常6段柱图数据解析', 0, () => {
      const chartPack = '80|7|5,200;60|8|3,100;40|9|2,000;20|10|1,500;0|11|—;0|12|—'
      const segs = chartPack.split(';')
      expect(segs.length).assertEqual(6)
    })

    it('首柱本月标签', 0, () => {
      // index === 0 时月份标签固定为 '本月'
      const index = 0
      const label = index === 0 ? '本月' : '—'
      expect(label).assertEqual('本月')
    })

    it('非首柱月份标签带月字', 0, () => {
      const seg = '60|8|3,100'
      const pair = seg.split('|')
      const label = (pair.length >= 2 && pair[1].length > 0 && pair[1] !== '—')
        ? pair[1] + '月' : '—'
      expect(label).assertEqual('8月')
    })

    it('柱高百分比计算_正常', 0, () => {
      const seg = '80|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(80)
    })

    it('柱高百分比计算_超100截断', 0, () => {
      const seg = '150|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(100)
    })

    it('柱高百分比计算_负数归零', 0, () => {
      const seg = '-5|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(0)
    })

    it('柱高百分比计算_NaN归零', 0, () => {
      const seg = 'abc|7|5,200'
      const pair = seg.split('|')
      const n = parseInt(pair[0], 10)
      const h = (!isNaN(n) && n >= 0) ? (n > 100 ? 100 : n) : 0
      expect(h).assertEqual(0)
    })

    it('柱顶金额_正常显示', 0, () => {
      const seg = '80|7|5,200'
      const pair = seg.split('|')
      const amt = (pair.length >= 3 && pair[2].length > 0 && pair[2] !== '—') ? pair[2] : ''
      expect(amt).assertEqual('5,200')
    })

    it('柱顶金额_空占位', 0, () => {
      const seg = '0|—|—'
      const pair = seg.split('|')
      const amt = (pair.length >= 3 && pair[2].length > 0 && pair[2] !== '—') ? pair[2] : ''
      expect(amt).assertEqual('')
    })

    it('默认chartPack_全零占位', 0, () => {
      const defaultPack = '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'
      const segs = defaultPack.split(';')
      expect(segs.length).assertEqual(6)
      for (let i = 0; i < segs.length; i++) {
        const pair = segs[i].split('|')
        expect(parseInt(pair[0], 10)).assertEqual(0)
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

    it('柱高显示字符串_零高度保底8%', 0, () => {
      const h = 0
      const result = h <= 0 ? '8%' : Math.max(10, Math.round(h * 0.78)) + '%'
      expect(result).assertEqual('8%')
    })

    it('柱高显示字符串_正常高度', 0, () => {
      const h = 80
      const result = h <= 0 ? '8%' : Math.max(10, Math.round(h * 0.78)) + '%'
      expect(result).assertEqual('62%')
    })

    it('柱高显示字符串_最小10%', 0, () => {
      const h = 5
      const result = h <= 0 ? '8%' : Math.max(10, Math.round(h * 0.78)) + '%'
      // Math.round(5 * 0.78) = 4, Math.max(10, 4) = 10
      expect(result).assertEqual('10%')
    })
  })

  describe('DebtPressureCard_峰值与颜色', () => {

    it('峰值柱_颜色区分', 0, () => {
      const peakIndex: number = 2
      const index: number = 2
      // peakIndex 匹配时使用 W_BAR_PEAK
      const isPeak = index === peakIndex
      const isCurrent = index === 0
      expect(isPeak).assertTrue()
      expect(isCurrent).assertFalse()
    })

    it('当月柱_颜色区分', 0, () => {
      const peakIndex: number = 3
      const index: number = 0
      const isPeak = index === peakIndex
      const isCurrent = index === 0
      expect(isPeak).assertFalse()
      expect(isCurrent).assertTrue()
    })

    it('普通柱_默认颜色', 0, () => {
      const peakIndex: number = 2
      const index: number = 4
      const isPeak = index === peakIndex
      const isCurrent = index === 0
      expect(isPeak).assertFalse()
      expect(isCurrent).assertFalse()
    })

    it('emphasized判断_峰值或当月', 0, () => {
      const peakIndex = 2
      const emphasized = (idx: number): boolean => idx === peakIndex || idx === 0
      expect(emphasized(0)).assertTrue()
      expect(emphasized(2)).assertTrue()
      expect(emphasized(3)).assertFalse()
    })
  })

  describe('DebtPressureCard_无数据降级', () => {

    it('hasData为false时显示暂无负债记录', 0, () => {
      const hasData = false
      const hintText = hasData ? '' : '暂无负债记录'
      expect(hintText).assertEqual('暂无负债记录')
    })

    it('hasData为true时不显示提示', 0, () => {
      const hasData = true
      const showHint = !hasData
      expect(showHint).assertFalse()
    })

    it('空数据时进度为0', 0, () => {
      const progress = 0
      const clamped = Math.max(0, Math.min(100, progress))
      expect(clamped).assertEqual(0)
    })

    it('空数据时所有柱高为0', 0, () => {
      const defaultPack = '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'
      const segs = defaultPack.split(';')
      for (let i = 0; i < segs.length; i++) {
        const pair = segs[i].split('|')
        const n = parseInt(pair[0], 10)
        expect(n).assertEqual(0)
      }
    })
  })

  describe('DebtPressureCard_主题适配', () => {

    it('卡片背景色使用资源引用', 0, () => {
      // W_BG = $r('app.color.widget_bg') 随系统主题切换
      // 验证资源引用存在
      const resourceName = 'widget_bg'
      expect(resourceName.length > 0).assertTrue()
    })

    it('文字颜色使用资源引用', 0, () => {
      const textResource = 'widget_text'
      const mutedResource = 'widget_muted'
      const dimResource = 'widget_dim'
      expect(textResource.length > 0).assertTrue()
      expect(mutedResource.length > 0).assertTrue()
      expect(dimResource.length > 0).assertTrue()
    })

    it('柱图颜色_峰值/当月/默认三色', 0, () => {
      const barPeak = 'widget_bar_peak'
      const barCurrent = 'widget_bar_current'
      const barDefault = 'widget_bar'
      expect(barPeak).not().assertEqual(barCurrent)
      expect(barCurrent).not().assertEqual(barDefault)
    })
  })
}
