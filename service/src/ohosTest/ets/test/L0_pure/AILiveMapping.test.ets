import { describe, it, expect } from '@ohos/hypium'
import { AILiveMapping, AILivePreviewData } from '../../../../main/ets/service/ai/AILiveMapping'
import { ParseResultItem } from '../../../../main/ets/service/ai/AIService'

function makeItem(recordType: string, fields: Record<string, string | number>): ParseResultItem {
  const item = new ParseResultItem()
  item.recordType = recordType
  item.parsedFields = new Map<string, string | number | boolean | null>()
  for (const key of Object.keys(fields)) {
    item.parsedFields.set(key, fields[key])
  }
  return item
}

export default function aiLiveMappingTest() {
  describe('AILiveMapping_yuanToFen', () => {
    it('正常值', 0, async () => {
      expect(AILiveMapping.yuanToFen(100)).assertEqual(10000)
    })
    it('零', 0, async () => {
      expect(AILiveMapping.yuanToFen(0)).assertEqual(0)
    })
    it('NaN返回0', 0, async () => {
      expect(AILiveMapping.yuanToFen(NaN)).assertEqual(0)
    })
    it('负值', 0, async () => {
      expect(AILiveMapping.yuanToFen(-50)).assertEqual(-5000)
    })
    it('小数精度', 0, async () => {
      expect(AILiveMapping.yuanToFen(9.99)).assertEqual(999)
    })
  })

  describe('AILiveMapping_numField', () => {
    it('正常取值', 0, async () => {
      const fields = new Map<string, string | number | boolean | null>()
      fields.set('amount', 100)
      expect(AILiveMapping.numField(fields, 'amount')).assertEqual(100)
    })
    it('不存在返回fallback', 0, async () => {
      const fields = new Map<string, string | number | boolean | null>()
      expect(AILiveMapping.numField(fields, 'missing', 42)).assertEqual(42)
    })
    it('字符串数字', 0, async () => {
      const fields = new Map<string, string | number | boolean | null>()
      fields.set('amount', '200')
      expect(AILiveMapping.numField(fields, 'amount')).assertEqual(200)
    })
    it('NaN返回fallback', 0, async () => {
      const fields = new Map<string, string | number | boolean | null>()
      fields.set('amount', 'abc')
      expect(AILiveMapping.numField(fields, 'amount', 99)).assertEqual(99)
    })
  })

  describe('AILiveMapping_toCreateDebtInput', () => {
    it('基本字段映射', 0, async () => {
      const item = makeItem('debt', {
        platform: '花呗', current_balance: 10000, monthly_payment: 1000,
        total_periods: 12, remaining_periods: 6, annual_rate: 18, payment_day: 15,
        next_payment_date: '2025-06-01', start_date: '2025-01-01', note: '测试'
      })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.platform).assertEqual('花呗')
      expect(input.current_balance).assertEqual(10000)
      expect(input.monthly_payment).assertEqual(1000)
      expect(input.total_periods).assertEqual(12)
      expect(input.remaining_periods).assertEqual(6)
      expect(input.annual_rate_bp).assertEqual(1800)
      expect(input.payment_day).assertEqual(15)
      expect(input.note).assertEqual('测试')
    })
    it('debt_type=credit_card', 0, async () => {
      const item = makeItem('debt', { debt_type: 'credit_card', current_balance: 5000 })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.debt_type).assertEqual('credit_card')
    })
    it('debt_type=loan', 0, async () => {
      const item = makeItem('debt', { debt_type: 'loan' })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.debt_type).assertEqual('loan')
    })
    it('debt_type=other', 0, async () => {
      const item = makeItem('debt', { debt_type: 'other' })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.debt_type).assertEqual('other')
    })
    it('payment_day越界_回退到1', 0, async () => {
      const item = makeItem('debt', { payment_day: 32, current_balance: 1000 })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.payment_day).assertEqual(1)
    })
    it('payment_day=0_回退到1', 0, async () => {
      const item = makeItem('debt', { payment_day: 0, current_balance: 1000 })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.payment_day).assertEqual(1)
    })
    it('无principal_用balance', 0, async () => {
      const item = makeItem('debt', { current_balance: 8000 })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.principal).assertEqual(8000)
    })
    it('remaining_periods=0_用total_periods', 0, async () => {
      const item = makeItem('debt', { total_periods: 12, remaining_periods: 0 })
      const input = AILiveMapping.toCreateDebtInput(item)
      expect(input.remaining_periods).assertEqual(12)
    })
  })

  describe('AILiveMapping_toCreateSubscriptionInput', () => {
    it('基本字段映射', 0, async () => {
      const item = makeItem('subscription', {
        name: 'Netflix', amount: 99, category: 'video', billing_cycle: 'monthly',
        next_billing_date: '2025-03-01', start_date: '2025-01-01', end_date: '2025-12-31',
        note: '年费'
      })
      const input = AILiveMapping.toCreateSubscriptionInput(item)
      expect(input.name).assertEqual('Netflix')
      expect(input.amount).assertEqual(99)
      expect(input.category).assertEqual('video')
      expect(input.billing_cycle).assertEqual('monthly')
      expect(input.status).assertEqual('active')
      expect(input.reminder_enabled).assertTrue()
      expect(input.reminder_days_before).assertEqual(3)
    })
    it('无name用platform', 0, async () => {
      const item = makeItem('subscription', { platform: 'Spotify', amount: 50 })
      const input = AILiveMapping.toCreateSubscriptionInput(item)
      expect(input.name).assertEqual('Spotify')
    })
    it('amount=0用current_balance', 0, async () => {
      const item = makeItem('subscription', { amount: 0, current_balance: 30 })
      const input = AILiveMapping.toCreateSubscriptionInput(item)
      expect(input.amount).assertEqual(30)
    })
  })

  describe('AILiveMapping_toCreateCreditAccountInput', () => {
    it('基本字段映射', 0, async () => {
      const item = makeItem('credit_account', {
        name: '招商信用卡', last_four: '1234', bill_day: 5, payment_day: 20,
        credit_limit: 50000, expiry_date: '2028-12-31',
        annual_fee_required_swipes: 6, grace_period_days: 3
      })
      const input = AILiveMapping.toCreateCreditAccountInput(item)
      expect(input.name).assertEqual('招商信用卡')
      expect(input.last_four).assertEqual('1234')
      expect(input.bill_day).assertEqual(5)
      expect(input.payment_day).assertEqual(20)
      expect(input.credit_limit).assertEqual(50000)
      expect(input.expiry_date).assertEqual('2028-12-31')
      expect(input.annual_fee_required_swipes).assertEqual(6)
      expect(input.grace_period_days).assertEqual(3)
    })
    it('bill_day越界_回退到1', 0, async () => {
      const item = makeItem('credit_account', { bill_day: 32 })
      const input = AILiveMapping.toCreateCreditAccountInput(item)
      expect(input.bill_day).assertEqual(1)
    })
    it('payment_day越界_回退到1', 0, async () => {
      const item = makeItem('credit_account', { payment_day: 0 })
      const input = AILiveMapping.toCreateCreditAccountInput(item)
      expect(input.payment_day).assertEqual(1)
    })
  })

  describe('AILiveMapping_buildPreviewData', () => {
    it('debt类型', 0, async () => {
      const item = makeItem('debt', {
        platform: '花呗', current_balance: 10000, remaining_periods: 6,
        total_periods: 12, monthly_payment: 1000, payment_day: 15
      })
      const data = AILiveMapping.buildPreviewData(item)
      expect(data.title).assertEqual('花呗')
      expect(data.isSubscription).assertFalse()
      expect(data.amountFen).assertEqual(1000000)
      // 类型由 UI tag 展示，meta 只含业务字段
      expect(data.meta.includes('剩 6 期')).assertTrue()
    })
    it('subscription类型', 0, async () => {
      const item = makeItem('subscription', {
        name: 'Netflix', amount: 99, billing_cycle: 'monthly',
        next_billing_date: '2025-03-01'
      })
      const data = AILiveMapping.buildPreviewData(item)
      expect(data.title).assertEqual('Netflix')
      expect(data.isSubscription).assertTrue()
      expect(data.amountFen).assertEqual(9900)
      expect(data.meta.includes('monthly')).assertTrue()
    })
    it('credit_account类型', 0, async () => {
      const item = makeItem('credit_account', {
        name: '招商信用卡', credit_limit: 50000, last_four: '1234', bill_day: 5
      })
      const data = AILiveMapping.buildPreviewData(item)
      expect(data.title).assertEqual('招商信用卡')
      expect(data.amountFen).assertEqual(5000000)
      expect(data.meta.includes('尾号 1234')).assertTrue()
    })
  })
}
