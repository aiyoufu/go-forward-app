import { describe, it, expect } from '@ohos/hypium'
import {
  AILiveDebtDraft, AILiveSubscriptionDraft, AILiveCreditAccountDraft, AILiveDraftKeys
} from '../../../../main/ets/service/ai/AILiveDraft'
import { ParseResultItem } from '../../../../main/ets/service/ai/AIService'

export default function aiLiveDraftTest() {
  describe('AILiveDebtDraft_encode_decode', () => {
    it('roundtrip', 0, async () => {
      const d = new AILiveDebtDraft()
      d.platform = '花呗'
      d.currentBalance = '10000'
      d.monthlyPayment = '1000'
      d.totalPeriods = '12'
      d.remainingPeriods = '6'
      d.annualRate = '18'
      d.paymentDay = '15'
      d.startDate = '2025-01-01'
      d.repaymentDate = '2025-06-01'
      d.note = '测试'
      const encoded = d.encode()
      const decoded = AILiveDebtDraft.decode(encoded)
      expect((decoded) !== null && (decoded) !== undefined).assertTrue()
      expect(decoded!.platform).assertEqual('花呗')
      expect(decoded!.currentBalance).assertEqual('10000')
      expect(decoded!.monthlyPayment).assertEqual('1000')
      expect(decoded!.totalPeriods).assertEqual('12')
      expect(decoded!.remainingPeriods).assertEqual('6')
      expect(decoded!.annualRate).assertEqual('18')
      expect(decoded!.paymentDay).assertEqual('15')
      expect(decoded!.startDate).assertEqual('2025-01-01')
      expect(decoded!.repaymentDate).assertEqual('2025-06-01')
      expect(decoded!.note).assertEqual('测试')
    })
    it('空字符串返回null', 0, async () => {
      expect(AILiveDebtDraft.decode('')).assertNull()
    })
    it('字段不足返回null', 0, async () => {
      expect(AILiveDebtDraft.decode('a\u001fb')).assertNull()
    })
  })

  describe('AILiveSubscriptionDraft_encode_decode', () => {
    it('roundtrip', 0, async () => {
      const d = new AILiveSubscriptionDraft()
      d.name = 'Netflix'
      d.amount = '99'
      d.category = 'video'
      d.billingCycle = 'monthly'
      d.nextBillingDate = '2025-03-01'
      d.startDate = '2025-01-01'
      d.endDate = '2025-12-31'
      d.note = '年费会员'
      const encoded = d.encode()
      const decoded = AILiveSubscriptionDraft.decode(encoded)
      expect((decoded) !== null && (decoded) !== undefined).assertTrue()
      expect(decoded!.name).assertEqual('Netflix')
      expect(decoded!.amount).assertEqual('99')
      expect(decoded!.category).assertEqual('video')
      expect(decoded!.billingCycle).assertEqual('monthly')
      expect(decoded!.nextBillingDate).assertEqual('2025-03-01')
      expect(decoded!.startDate).assertEqual('2025-01-01')
      expect(decoded!.endDate).assertEqual('2025-12-31')
      expect(decoded!.note).assertEqual('年费会员')
    })
    it('空字符串返回null', 0, async () => {
      expect(AILiveSubscriptionDraft.decode('')).assertNull()
    })
    it('字段不足返回null', 0, async () => {
      expect(AILiveSubscriptionDraft.decode('a\u001fb\u001fc')).assertNull()
    })
  })

  describe('AILiveCreditAccountDraft_encode_decode', () => {
    it('roundtrip', 0, async () => {
      const d = new AILiveCreditAccountDraft()
      d.name = '招商信用卡'
      d.lastFour = '1234'
      d.billDay = '5'
      d.paymentDay = '20'
      d.creditLimit = '50000'
      d.expiryDate = '2028-12-31'
      d.annualFeeSwipes = '6'
      d.gracePeriodDays = '3'
      d.note = '主卡'
      const encoded = d.encode()
      const decoded = AILiveCreditAccountDraft.decode(encoded)
      expect((decoded) !== null && (decoded) !== undefined).assertTrue()
      expect(decoded!.name).assertEqual('招商信用卡')
      expect(decoded!.lastFour).assertEqual('1234')
      expect(decoded!.billDay).assertEqual('5')
      expect(decoded!.paymentDay).assertEqual('20')
      expect(decoded!.creditLimit).assertEqual('50000')
      expect(decoded!.expiryDate).assertEqual('2028-12-31')
      expect(decoded!.annualFeeSwipes).assertEqual('6')
      expect(decoded!.gracePeriodDays).assertEqual('3')
      expect(decoded!.note).assertEqual('主卡')
    })
    it('空字符串返回null', 0, async () => {
      expect(AILiveCreditAccountDraft.decode('')).assertNull()
    })
    it('字段不足返回null', 0, async () => {
      expect(AILiveCreditAccountDraft.decode('a\u001fb')).assertNull()
    })
  })

  describe('AILiveDraftKeys', () => {
    it('DEBT键非空', 0, async () => {
      expect(AILiveDraftKeys.DEBT.length).assertLarger(0)
    })
    it('SUBSCRIPTION键非空', 0, async () => {
      expect(AILiveDraftKeys.SUBSCRIPTION.length).assertLarger(0)
    })
    it('CREDIT_ACCOUNT键非空', 0, async () => {
      expect(AILiveDraftKeys.CREDIT_ACCOUNT.length).assertLarger(0)
    })
  })
}
