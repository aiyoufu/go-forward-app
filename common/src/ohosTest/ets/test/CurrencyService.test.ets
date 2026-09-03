import { describe, it, expect } from '@ohos/hypium'
import { CurrencyService } from '../../../../main/ets/common/CurrencyService'

export default function currencyServiceTest() {
  describe('CurrencyService_币种归一', () => {
    it('合法币种原样返回', 0, () => {
      expect(CurrencyService.normalize('USD')).assertEqual('USD')
      expect(CurrencyService.normalize('JPY')).assertEqual('JPY')
    })

    it('非法或空值回落CNY', 0, () => {
      expect(CurrencyService.normalize('')).assertEqual('CNY')
      expect(CurrencyService.normalize('XXX')).assertEqual('CNY')
    })

    it('本位币判定', 0, () => {
      expect(CurrencyService.isBase('CNY')).assertTrue()
      expect(CurrencyService.isBase('USD')).assertFalse()
    })
  })

  describe('CurrencyService_符号与换算', () => {
    it('符号表', 0, () => {
      expect(CurrencyService.getSymbol('CNY')).assertEqual('¥')
      expect(CurrencyService.getSymbol('USD')).assertEqual('$')
      expect(CurrencyService.getSymbol('HKD')).assertEqual('HK$')
    })

    it('日元小数位为0', 0, () => {
      expect(CurrencyService.getCurrencyInfo('JPY').decimals).assertEqual(0)
    })

    it('toBaseFen_四舍五入到整分', 0, () => {
      expect(CurrencyService.toBaseFen(9.999, 1)).assertEqual(1000)
      expect(CurrencyService.toBaseFen(10, 6.5)).assertEqual(6500)
    })

    it('toBaseFen_非法输入返回0', 0, () => {
      expect(CurrencyService.toBaseFen(Number.NaN, 1)).assertEqual(0)
      expect(CurrencyService.toBaseFen(10, -1)).assertEqual(0)
    })

    it('formatOrigin_带符号原币展示', 0, () => {
      expect(CurrencyService.formatOrigin(9.5, 'USD')).assertEqual('$9.50')
    })
  })
}
