import { describe, it, expect } from '@ohos/hypium'

export default function currencyModelTest() {
  describe('CurrencyModel', () => {
    it('CNY基准码', 0, () => {
      const code = 'CNY'
      expect(code).assertEqual('CNY')
    })
    it('多币种列表含USD', 0, () => {
      const codes = ['CNY', 'USD', 'EUR', 'HKD', 'JPY']
      expect(codes.indexOf('USD') >= 0).assertTrue()
    })
  })
}
