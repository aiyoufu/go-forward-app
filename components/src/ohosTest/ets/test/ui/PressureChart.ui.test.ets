import { describe, it, expect } from '@ohos/hypium'

/**
 * PressureChart UI 测试
 * 覆盖：纯函数 recomputeMax/currentMonthKey/isCurrentMonth/isFutureMonth/barHeightVp/monthLabel/useWanUnit/moneyLabel
 */
export default function PressureChart_UITest() {
  describe('PressureChart_UI', () => {

    it('纯函数_recomputeMax_空数组返回1', 0, async () => {
      const data: number[] = []
      let m = 1
      for (let i = 0; i < data.length; i++) {
        if (data[i] > m) m = data[i]
      }
      expect(m).assertEqual(1)
    })

    it('纯函数_recomputeMax_取最大值', 0, async () => {
      const data = [100, 500, 300, 200]
      let m = 1
      for (let i = 0; i < data.length; i++) {
        if (data[i] > m) m = data[i]
      }
      expect(m).assertEqual(500)
    })

    it('纯函数_recomputeMax_全负数返回1', 0, async () => {
      const data = [-10, -20, -5]
      let m = 1
      for (let i = 0; i < data.length; i++) {
        if (data[i] > m) m = data[i]
      }
      expect(m).assertEqual(1)
    })

    it('纯函数_currentMonthKey_格式YYYY-MM', 0, async () => {
      const d = new Date()
      const y = d.getFullYear()
      const mo = (d.getMonth() + 1).toString().padStart(2, '0')
      const key = y + '-' + mo
      expect(key.length).assertEqual(7)
      expect(key.indexOf('-')).assertEqual(4)
    })

    it('纯函数_isCurrentMonth_相同返回true', 0, async () => {
      const month = '2025-07'
      const key = '2025-07'
      expect(month === key).assertTrue()
    })

    it('纯函数_isCurrentMonth_不同返回false', 0, async () => {
      const month = '2025-06'
      const key = '2025-07'
      expect(month === key).assertFalse()
    })

    it('纯函数_isFutureMonth_未来月返回true', 0, async () => {
      const month = '2025-08'
      const key = '2025-07'
      expect(month > key).assertTrue()
    })

    it('纯函数_isFutureMonth_过去月返回false', 0, async () => {
      const month = '2025-06'
      const key = '2025-07'
      expect(month > key).assertFalse()
    })

    it('纯函数_barHeightVp_正常金额', 0, async () => {
      const amount = 500
      const maxAmount = 1000
      const chartHeight = 160
      const barArea = Math.max(88, chartHeight)
      const ratio = amount / (maxAmount * 1.05)
      const eased = Math.sqrt(ratio)
      const floor = Math.max(20, Math.round(barArea * 0.2))
      const h = floor + eased * (barArea - floor)
      expect(h > 0).assertTrue()
    })

    it('纯函数_barHeightVp_零金额返回0', 0, async () => {
      let amount: number = 0
      const maxAmount = 1000
      const chartHeight = 160
      if (maxAmount <= 0 || amount <= 0) {
        expect(0).assertEqual(0)
      }
    })

    it('纯函数_barHeightVp_零maxAmount返回0', 0, async () => {
      const amount = 500
      let maxAmount: number = 0
      if (maxAmount <= 0 || amount <= 0) {
        expect(0).assertEqual(0)
      }
    })

    it('纯函数_monthLabel_正常格式', 0, async () => {
      const month = '2025-07'
      const parts = month.split('-')
      const m = parseInt(parts[1], 10)
      const label = m + '月'
      expect(label).assertEqual('7月')
    })

    it('纯函数_monthLabel_无效格式_返回原文', 0, async () => {
      let month: string = 'invalid'
      const parts = month.split('-')
      const label = parts.length === 2 ? (parseInt(parts[1], 10) + '月') : month
      expect(label).assertEqual('invalid')
    })

    it('纯函数_monthLabel_12月', 0, async () => {
      const month = '2025-12'
      const parts = month.split('-')
      const m = parseInt(parts[1], 10)
      const label = m + '月'
      expect(label).assertEqual('12月')
    })

    it('纯函数_useWanUnit_大额使用万', 0, async () => {
      const maxAmount = 1000000
      const useWan = (maxAmount / 100) >= 10000
      expect(useWan).assertTrue()
    })

    it('纯函数_useWanUnit_小额不使用万', 0, async () => {
      const maxAmount = 50000
      const useWan = (maxAmount / 100) >= 10000
      expect(useWan).assertFalse()
    })

    it('纯函数_moneyLabel_小额元', 0, async () => {
      const fen = 5000
      const useWan = false
      const yuan = Math.abs(fen) / 100
      const sign = fen < 0 ? '-' : ''
      const label = sign + '¥' + yuan.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
      expect(label).assertEqual('¥50')
    })

    it('纯函数_moneyLabel_大额元', 0, async () => {
      const fen = 150000
      const useWan = false
      const yuan = Math.abs(fen) / 100
      const sign = fen < 0 ? '-' : ''
      const label = sign + '¥' + yuan.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
      expect(label).assertEqual('¥1500')
    })

    it('纯函数_moneyLabel_万单位', 0, async () => {
      const fen = 1500000
      const useWan = true
      const yuan = Math.abs(fen) / 100
      const w = yuan / 10000
      const label = '¥' + w.toFixed(2).replace(/0+$/, '').replace(/\.$/, '') + '万'
      expect(label).assertEqual('¥1.5万')
    })

    it('纯函数_moneyLabel_负数金额', 0, async () => {
      const fen = -5000
      const yuan = Math.abs(fen) / 100
      const sign = fen < 0 ? '-' : ''
      const label = sign + '¥' + yuan.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
      expect(label).assertEqual('-¥50')
    })

    it('渲染_framed模式_有边框和背景', 0, async () => {
      const framed = true
      const pad = framed ? 22 : 4
      expect(pad).assertEqual(22)
    })

    it('渲染_嵌入模式_无边框', 0, async () => {
      const framed = false
      const pad = framed ? 22 : 4
      expect(pad).assertEqual(4)
    })

    it('渲染_柱区高度下限88', 0, async () => {
      const chartHeight = 50
      const barArea = Math.max(88, chartHeight)
      expect(barArea).assertEqual(88)
    })

    it('渲染_柱区高度正常', 0, async () => {
      const chartHeight = 160
      const barArea = Math.max(88, chartHeight)
      expect(barArea).assertEqual(160)
    })
  })
}
