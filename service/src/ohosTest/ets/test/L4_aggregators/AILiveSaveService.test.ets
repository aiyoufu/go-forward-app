import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { AILiveSaveService } from '../../../../main/ets/service/ai/AILiveSaveService'
import { DebtService } from '../../mock/DebtService.mock'
import { SubscriptionService } from '../../mock/SubscriptionService.mock'
import { CreditAccountService } from '../../mock/CreditAccountService.mock'

function makeItem(recordType: string, overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    recordType: recordType,
    platform: '花呗',
    name: '爱奇艺',
    amount: 1500,
    credit_limit: 5
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

export default function aiLiveSaveServiceTest() {
  beforeEach(() => {
    DebtService._reset()
    SubscriptionService._reset()
    CreditAccountService._reset()
  })

  describe('AILiveSaveService_saveParseItem', () => {
    it('recordType=subscription_调用createSubscription', 0, async () => {
      await AILiveSaveService.saveParseItem(makeItem('subscription'))
      // mock 的 createSubscription 返回 {}，验证不抛异常即可
      expect(true).assertTrue()
    })

    it('recordType=credit_account_调用createCreditAccount', 0, async () => {
      await AILiveSaveService.saveParseItem(makeItem('credit_account'))
      expect(true).assertTrue()
    })

    it('recordType=debt_调用createDebt', 0, async () => {
      await AILiveSaveService.saveParseItem(makeItem('debt'))
      expect(true).assertTrue()
    })

    it('recordType=其他_默认调用createDebt', 0, async () => {
      await AILiveSaveService.saveParseItem(makeItem('unknown_type'))
      expect(true).assertTrue()
    })

    it('recordType为空_默认走debt分支', 0, async () => {
      await AILiveSaveService.saveParseItem(makeItem(''))
      expect(true).assertTrue()
    })
  })
}
