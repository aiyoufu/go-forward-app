import { describe, it, expect } from '@ohos/hypium'
import { Utils } from 'common'
import {
  trendDir, tagRoleForSparkline, remainingDebtTrendTag, formatYuanGrouped, formatFenWithDecimal, strokeColor, fillColorTop, fillColorBottom, haloColor
} from '../../../main/ets/components/Sparkline'

export default function SparklineTest() {
  describe('trendDir', () => {
    it('少于2点_返回flat', 0, async () => {
      expect(trendDir([])).assertEqual('flat')
      expect(trendDir([100])).assertEqual('flat')
    })
    it('下降_返回down', 0, async () => {
      expect(trendDir([200, 100])).assertEqual('down')
    })
    it('上升_返回up', 0, async () => {
      expect(trendDir([100, 200])).assertEqual('up')
    })
    it('持平_阈值内返回flat', 0, async () => {
      expect(trendDir([100, 101])).assertEqual('flat')
    })
    it('多点数据_看首尾', 0, async () => {
      expect(trendDir([100, 500, 300, 50])).assertEqual('down')
    })
  })

  describe('tagRoleForSparkline', () => {
    it('下降线用绿标', 0, async () => {
      expect(tagRoleForSparkline('down')).assertEqual('ok')
    })
    it('上升线用红标', 0, async () => {
      expect(tagRoleForSparkline('up')).assertEqual('danger')
    })
    it('持平不用强调色', 0, async () => {
      expect(tagRoleForSparkline('flat')).assertEqual('off')
    })
  })

  describe('remainingDebtTrendTag', () => {
    it('总待还回落_绿标且金额为差值（保留2位小数）', 0, async () => {
      const tag = remainingDebtTrendTag([78666, 77108, 29955, 0])
      expect(tag !== null).assertTrue()
      expect(tag.role).assertEqual('ok')
      expect(tag.text).assertEqual('↓ ¥' + Utils.YUAN_GAP + '786.66')
    })
    it('总待还升高_红标（保留2位小数）', 0, async () => {
      const tag = remainingDebtTrendTag([10000, 20000])
      expect(tag !== null).assertTrue()
      expect(tag.role).assertEqual('danger')
      expect(tag.text).assertEqual('↑ ¥' + Utils.YUAN_GAP + '100.00')
    })
    it('变化不足2%_不展示', 0, async () => {
      expect(remainingDebtTrendTag([10000, 10100]) === null).assertTrue()
    })
  })

  describe('formatFenWithDecimal', () => {
    it('分转元_2位小数_千分位', 0, async () => {
      expect(formatFenWithDecimal(0)).assertEqual('0.00')
      expect(formatFenWithDecimal(7)).assertEqual('0.07')
      expect(formatFenWithDecimal(100)).assertEqual('1.00')
      expect(formatFenWithDecimal(78666)).assertEqual('786.66')
      expect(formatFenWithDecimal(100000)).assertEqual('1,000.00')
      expect(formatFenWithDecimal(1234567)).assertEqual('12,345.67')
    })
  })

  describe('formatYuanGrouped', () => {
    it('千分位分组', 0, async () => {
      expect(formatYuanGrouped(0)).assertEqual('0')
      expect(formatYuanGrouped(787)).assertEqual('787')
      expect(formatYuanGrouped(1000)).assertEqual('1,000')
      expect(formatYuanGrouped(1234567)).assertEqual('1,234,567')
    })
  })

  describe('strokeColor', () => {
    it('非彩色_浅色', 0, async () => {
      expect(strokeColor('down', false, false)).assertEqual('rgba(15,20,25,0.88)')
    })
    it('非彩色_深色', 0, async () => {
      expect(strokeColor('down', false, true)).assertEqual('rgba(231,233,234,0.92)')
    })
    it('down_浅色绿', 0, async () => {
      expect(strokeColor('down', true, false)).assertEqual('rgba(22,163,74,0.95)')
    })
    it('down_深色绿', 0, async () => {
      expect(strokeColor('down', true, true)).assertEqual('rgba(34,197,94,0.95)')
    })
    it('up_浅色红', 0, async () => {
      expect(strokeColor('up', true, false)).assertEqual('rgba(220,38,38,0.95)')
    })
    it('up_深色红', 0, async () => {
      expect(strokeColor('up', true, true)).assertEqual('rgba(244,33,46,0.95)')
    })
    it('flat_浅色灰', 0, async () => {
      expect(strokeColor('flat', true, false)).assertEqual('rgba(113,118,123,0.90)')
    })
    it('flat_深色灰', 0, async () => {
      expect(strokeColor('flat', true, true)).assertEqual('rgba(176,180,186,0.90)')
    })
  })

  describe('fillColorTop', () => {
    it('非彩色_浅色', 0, async () => {
      expect(fillColorTop('flat', false, false)).assertEqual('rgba(15,20,25,0.16)')
    })
    it('down_浅色', 0, async () => {
      expect(fillColorTop('down', true, false)).assertEqual('rgba(22,163,74,0.24)')
    })
    it('up_浅色', 0, async () => {
      expect(fillColorTop('up', true, false)).assertEqual('rgba(220,38,38,0.20)')
    })
    it('flat_浅色', 0, async () => {
      expect(fillColorTop('flat', true, false)).assertEqual('rgba(113,118,123,0.16)')
    })
  })

  describe('fillColorBottom', () => {
    it('非彩色_浅色', 0, async () => {
      expect(fillColorBottom('flat', false, false)).assertEqual('rgba(15,20,25,0.01)')
    })
    it('down_浅色', 0, async () => {
      expect(fillColorBottom('down', true, false)).assertEqual('rgba(22,163,74,0.02)')
    })
    it('up_浅色', 0, async () => {
      expect(fillColorBottom('up', true, false)).assertEqual('rgba(220,38,38,0.02)')
    })
    it('flat_浅色', 0, async () => {
      expect(fillColorBottom('flat', true, false)).assertEqual('rgba(113,118,123,0.01)')
    })
  })

  describe('haloColor', () => {
    it('非彩色_浅色', 0, async () => {
      expect(haloColor('flat', false, false)).assertEqual('rgba(15,20,25,0.14)')
    })
    it('down_浅色', 0, async () => {
      expect(haloColor('down', true, false)).assertEqual('rgba(22,163,74,0.20)')
    })
    it('up_浅色', 0, async () => {
      expect(haloColor('up', true, false)).assertEqual('rgba(220,38,38,0.18)')
    })
    it('flat_浅色', 0, async () => {
      expect(haloColor('flat', true, false)).assertEqual('rgba(113,118,123,0.14)')
    })
    it('down_深色', 0, async () => {
      expect(haloColor('down', true, true)).assertEqual('rgba(34,197,94,0.26)')
    })
    it('up_深色', 0, async () => {
      expect(haloColor('up', true, true)).assertEqual('rgba(244,33,46,0.24)')
    })
    it('flat_深色', 0, async () => {
      expect(haloColor('flat', true, true)).assertEqual('rgba(176,180,186,0.20)')
    })
  })
}
