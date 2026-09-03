import { describe, it, expect } from '@ohos/hypium'
import { MonthlyPressure, Utils } from 'common'
import {
  recomputeMax, currentMonthKey, isCurrentMonth, isFutureMonth,
  barHeightVp, monthLabel, useWanUnit, moneyLabel, moneySign, moneyBody,
  pressureTrendTag,
  nextMonthDueHint
} from '../../../main/ets/components/PressureChart'

function mp(month: string, amount: number): MonthlyPressure {
  const p = new MonthlyPressure()
  p.month = month
  p.amount = amount
  return p
}

export default function PressureChartTest() {
  describe('recomputeMax', () => {
    it('空数组_返回1', 0, async () => {
      expect(recomputeMax([])).assertEqual(1)
    })
    it('单条数据_返回该值', 0, async () => {
      expect(recomputeMax([mp('2024-01', 500)])).assertEqual(500)
    })
    it('多条数据_返回最大值', 0, async () => {
      expect(recomputeMax([mp('2024-01', 100), mp('2024-02', 300), mp('2024-03', 200)])).assertEqual(300)
    })
    it('所有值为0_返回1', 0, async () => {
      expect(recomputeMax([mp('2024-01', 0), mp('2024-02', 0)])).assertEqual(1)
    })
  })

  describe('currentMonthKey', () => {
    it('返回YYYY_MM格式', 0, async () => {
      const key = currentMonthKey()
      expect(key.length).assertEqual(7)
      expect(key.charAt(4)).assertEqual('-')
    })
  })

  describe('isCurrentMonth', () => {
    it('匹配当前月', 0, async () => {
      const key = currentMonthKey()
      expect(isCurrentMonth(key, key)).assertEqual(true)
    })
    it('不匹配其他月', 0, async () => {
      expect(isCurrentMonth('2020-01', '2024-06')).assertEqual(false)
    })
  })

  describe('isFutureMonth', () => {
    it('未来月_返回true', 0, async () => {
      expect(isFutureMonth('2099-12', '2024-06')).assertEqual(true)
    })
    it('过去月_返回false', 0, async () => {
      expect(isFutureMonth('2020-01', '2024-06')).assertEqual(false)
    })
    it('当前月_返回false', 0, async () => {
      expect(isFutureMonth('2024-06', '2024-06')).assertEqual(false)
    })
  })

  describe('barHeightVp', () => {
    it('正常数据_返回合理高度', 0, async () => {
      const h = barHeightVp(200, 200, 160)
      expect(h > 0).assertEqual(true)
    })
    it('amount为0_返回0', 0, async () => {
      expect(barHeightVp(0, 200, 160)).assertEqual(0)
    })
    it('maxAmount为0_返回0', 0, async () => {
      expect(barHeightVp(200, 0, 160)).assertEqual(0)
    })
    it('chartHeight为0_使用默认160', 0, async () => {
      const h = barHeightVp(100, 200, 0)
      expect(h > 0).assertEqual(true)
    })
    it('极小值_仍可见', 0, async () => {
      const h = barHeightVp(1, 1000000, 160)
      expect(h >= 20).assertEqual(true)
    })
    it('不同金额_高度仍可区分', 0, async () => {
      const hMax = barHeightVp(200, 200, 108)
      const hMid = barHeightVp(100, 200, 108)
      const hLow = barHeightVp(50, 200, 108)
      expect(hMax > hMid).assertEqual(true)
      expect(hMid > hLow).assertEqual(true)
    })
    it('截图口径_小额相对峰值可见且更矮', 0, async () => {
      const peak = barHeightVp(231218, 231218, 108)
      const mid = barHeightVp(59122, 231218, 108)
      const tiny = barHeightVp(759, 231218, 108)
      expect(peak > mid).assertEqual(true)
      expect(mid > tiny).assertEqual(true)
      expect(tiny >= 20).assertEqual(true)
    })
  })

  describe('monthLabel', () => {
    it('正常格式_返回月标签', 0, async () => {
      expect(monthLabel('2024-06')).assertEqual('6月')
    })
    it('12月', 0, async () => {
      expect(monthLabel('2024-12')).assertEqual('12月')
    })
    it('1月', 0, async () => {
      expect(monthLabel('2024-01')).assertEqual('1月')
    })
    it('无分隔符_返回原值', 0, async () => {
      expect(monthLabel('invalid')).assertEqual('invalid')
    })
  })

  describe('useWanUnit', () => {
    it('大额_返回true', 0, async () => {
      // maxAmount/100 >= 10000 → maxAmount >= 1000000
      expect(useWanUnit(1000000)).assertEqual(true)
    })
    it('小额_返回false', 0, async () => {
      expect(useWanUnit(100000)).assertEqual(false)
    })
    it('临界值', 0, async () => {
      expect(useWanUnit(999999)).assertEqual(false)
      expect(useWanUnit(1000000)).assertEqual(true)
    })
  })

  describe('moneySign/moneyBody', () => {
    it('符号段_正数只有¥', 0, async () => {
      expect(moneySign(123456)).assertEqual('¥' + Utils.YUAN_GAP)
    })
    it('符号段_负数负号在¥前', 0, async () => {
      expect(moneySign(-5000)).assertEqual('-¥' + Utils.YUAN_GAP)
    })
    it('数字段_不含¥', 0, async () => {
      // 123456 fen → "1234.56"（不带单位）
      expect(moneyBody(123456, false)).assertEqual('1234.56')
    })
    it('数字段_万单位保留万', 0, async () => {
      expect(moneyBody(1500000, true)).assertEqual('1.5万')
    })
    it('符号段拼数字段等于moneyLabel', 0, async () => {
      expect(moneySign(-5000) + moneyBody(-5000, false)).assertEqual(moneyLabel(-5000, false))
    })
  })

  describe('moneyLabel', () => {
    it('非万单位_小额保留一位', 0, async () => {
      // 50 fen = 0.5 yuan → "0.5"
      expect(moneyLabel(50, false)).assertEqual('¥' + Utils.YUAN_GAP + '0.5')
    })
    it('非万单位_整数去掉.0', 0, async () => {
      // 500 fen = 5 yuan → "5"
      expect(moneyLabel(500, false)).assertEqual('¥' + Utils.YUAN_GAP + '5')
    })
    it('非万单位_百位不四舍五入', 0, async () => {
      // 10000 fen = 100 yuan → "100"
      expect(moneyLabel(10000, false)).assertEqual('¥' + Utils.YUAN_GAP + '100')
    })
    it('非万单位_千位不四舍五入', 0, async () => {
      // 100000 fen = 1000 yuan → "1000"
      expect(moneyLabel(100000, false)).assertEqual('¥' + Utils.YUAN_GAP + '1000')
    })
    it('非万单位_保留两位小数不取整', 0, async () => {
      // 123456 fen = 1234.56 yuan → "1234.56"
      expect(moneyLabel(123456, false)).assertEqual('¥' + Utils.YUAN_GAP + '1234.56')
    })
    it('非万单位_一位小数', 0, async () => {
      // 123450 fen = 1234.5 yuan → "1234.5"
      expect(moneyLabel(123450, false)).assertEqual('¥' + Utils.YUAN_GAP + '1234.5')
    })
    it('万单位_小于10万保留小数', 0, async () => {
      // 500000 fen = 5000 yuan = 0.5万 → "0.5万"
      expect(moneyLabel(500000, true)).assertEqual('¥' + Utils.YUAN_GAP + '0.5万')
    })
    it('万单位_不四舍五入', 0, async () => {
      // 1500000 fen = 15000 yuan = 1.5万 → "1.5万"
      expect(moneyLabel(1500000, true)).assertEqual('¥' + Utils.YUAN_GAP + '1.5万')
    })
    it('负数', 0, async () => {
      expect(moneyLabel(-500, false)).assertEqual('-¥' + Utils.YUAN_GAP + '5')
    })
    it('零元', 0, async () => {
      expect(moneyLabel(0, false)).assertEqual('¥' + Utils.YUAN_GAP + '0')
    })
  })

  describe('pressureTrendTag', () => {
    it('不足两月_不展示', 0, async () => {
      expect(pressureTrendTag([]) === null).assertTrue()
      expect(pressureTrendTag([mp('2026-08', 10000)]) === null).assertTrue()
    })
    it('微幅变化_不展示', 0, async () => {
      expect(pressureTrendTag([mp('2026-08', 10000), mp('2026-09', 10100)]) === null).assertTrue()
    })
    it('下月升高_红标', 0, async () => {
      const tag = pressureTrendTag([mp('2026-08', 1558), mp('2026-09', 47153)])
      expect(tag !== null).assertTrue()
      expect(tag.role).assertEqual('danger')
      expect(tag.text.indexOf('↗') >= 0).assertTrue()
      expect(tag.text.indexOf('下月') >= 0).assertTrue()
    })
    it('下月回落_绿标', 0, async () => {
      const tag = pressureTrendTag([mp('2026-08', 50000), mp('2026-09', 10000)])
      expect(tag !== null).assertTrue()
      expect(tag.role).assertEqual('ok')
      expect(tag.text.indexOf('↘') >= 0).assertTrue()
    })
  })

  describe('nextMonthDueHint', () => {
    it('本月15.58下月471.53_提示较本月多', 0, async () => {
      const tag = nextMonthDueHint(1558, 47153)
      expect(tag !== null).assertTrue()
      expect(tag.role).assertEqual('danger')
      expect(tag.text).assertEqual('较本月 +¥456')
    })
    it('变化不足2%_不提示', 0, async () => {
      expect(nextMonthDueHint(10000, 10100) === null).assertTrue()
    })
  })
}
