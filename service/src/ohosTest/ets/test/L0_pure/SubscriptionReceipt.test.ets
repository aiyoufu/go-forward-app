import { describe, it, expect } from '@ohos/hypium'
import { Subscription } from 'common'
import { SubscriptionReceipt } from '../../../../main/ets/service/SubscriptionReceipt'

function sub(name: string, amount: number, cycle: string, category: string, status: string = 'active'): Subscription {
  const s = new Subscription()
  s.name = name
  s.amount = amount
  s.billing_cycle = cycle as 'monthly'
  s.category = category as 'ai'
  s.status = status as 'active'
  return s
}

export default function subscriptionReceiptTest() {
  describe('SubscriptionReceipt', () => {
    it('月费折算_年付除以12', 0, async () => {
      expect(SubscriptionReceipt.monthlyFen(12000, 'annually')).assertEqual(1000)
    })
    it('月费折算_月付不变', 0, async () => {
      expect(SubscriptionReceipt.monthlyFen(1500, 'monthly')).assertEqual(1500)
    })
    it('build_跳过非生效', 0, async () => {
      const model = SubscriptionReceipt.build([
        sub('A', 1000, 'monthly', 'ai', 'active'),
        sub('B', 9999, 'monthly', 'video', 'paused')
      ], 2026)
      expect(model.itemCount).assertEqual(1)
      expect(model.totalMonthlyFen).assertEqual(1000)
      expect(model.year).assertEqual(2026)
    })
    it('build_原币月费与币种', 0, async () => {
      const s = sub('ChatGPT', 20000, 'monthly', 'ai')
      s.currency = 'USD'
      s.original_amount_fen = 2000
      const model = SubscriptionReceipt.build([s], 2026)
      expect(model.lines[0].displayFen).assertEqual(2000)
      expect(model.lines[0].currency).assertEqual('USD')
      expect(model.totalMonthlyFen).assertEqual(20000)
    })

    it('build_分类占比合计100', 0, async () => {
      const model = SubscriptionReceipt.build([
        sub('ChatGPT', 20000, 'monthly', 'ai'),
        sub('Netflix', 3000, 'monthly', 'video')
      ], 2026)
      let p = 0
      for (let i = 0; i < model.categories.length; i++) {
        p += model.categories[i].percent
      }
      expect(p).assertEqual(100)
      expect(model.avgMonthlyFen).assertEqual(11500)
    })
  })
}
