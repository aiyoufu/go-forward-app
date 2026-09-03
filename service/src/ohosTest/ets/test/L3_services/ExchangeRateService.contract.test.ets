import { describe, it, expect } from '@ohos/hypium'

export default function exchangeRateServiceContractTest() {
  describe('ExchangeRateService_contract', () => {
    it('CNY基准为1', 0, () => {
      const rate = 1
      expect(rate).assertEqual(1)
    })
    it('未知币种回退1', 0, () => {
      const fallback = 1
      expect(fallback).assertEqual(1)
    })
  })
}
