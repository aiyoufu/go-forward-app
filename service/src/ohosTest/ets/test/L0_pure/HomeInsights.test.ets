import { describe, it, expect } from '@ohos/hypium'
import { MonthlyPressure } from 'common'
import { HomeInsight, HomeInsightInput, HomeInsights } from '../../../../main/ets/service/HomeInsights'
import { TestFixtures } from '../TestFixtures'

function pressure(month: string, amount: number, subscriptionAmount: number = 0): MonthlyPressure {
  const p = new MonthlyPressure()
  p.month = month
  p.amount = amount
  p.subscriptionAmount = subscriptionAmount
  p.debtAmount = amount - subscriptionAmount
  return p
}

function hasId(items: HomeInsight[], id: string): boolean {
  for (let i = 0; i < items.length; i++) {
    if (items[i].id === id) {
      return true
    }
  }
  return false
}

function firstText(items: HomeInsight[]): string {
  if (items.length === 0) {
    return ''
  }
  return items[0].title
}

export default function homeInsightsTest() {
  describe('HomeInsights_shouldShow', () => {
    it('有行动项不展示', 0, () => {
      expect(HomeInsights.shouldShow(true, 2, false)).assertFalse()
    })
    it('无洞察不展示', 0, () => {
      expect(HomeInsights.shouldShow(false, 0, false)).assertFalse()
    })
    it('首载骨架不展示', 0, () => {
      expect(HomeInsights.shouldShow(false, 2, true)).assertFalse()
    })
    it('无行动项且有洞察展示', 0, () => {
      expect(HomeInsights.shouldShow(false, 1, false)).assertTrue()
    })
  })

  describe('HomeInsights_monthLabel', () => {
    it('合法月份', 0, () => {
      expect(HomeInsights.monthLabel('2026-08')).assertEqual('8月')
      expect(HomeInsights.monthLabel('2026-01')).assertEqual('1月')
    })
    it('非法回原文', 0, () => {
      expect(HomeInsights.monthLabel('bad')).assertEqual('bad')
      expect(HomeInsights.monthLabel('2026-13')).assertEqual('2026-13')
    })
  })

  describe('HomeInsights_isSignificantJump', () => {
    it('1.5倍为跳升', 0, () => {
      expect(HomeInsights.isSignificantJump(100, 150)).assertTrue()
      expect(HomeInsights.isSignificantJump(100, 149)).assertFalse()
    })
    it('非正数不算', 0, () => {
      expect(HomeInsights.isSignificantJump(0, 200)).assertFalse()
      expect(HomeInsights.isSignificantJump(100, 0)).assertFalse()
    })
  })

  describe('HomeInsights_build', () => {
    it('空输入返回空', 0, () => {
      const items = HomeInsights.build(new HomeInsightInput(), [])
      expect(items.length).assertEqual(0)
    })

    it('只给本月下月数字不出空话', 0, () => {
      const input = new HomeInsightInput()
      input.thisMonthDue = 1558
      input.nextMonthDue = 47153
      input.remainingDebt = 78666
      const items = HomeInsights.build(input, [])
      expect(items.length).assertEqual(0)
    })

    it('总待还很大但有近期待还不出长尾空话', 0, () => {
      const input = new HomeInsightInput()
      input.thisMonthDue = 10000
      input.nextMonthDue = 10000
      input.remainingDebt = 80000
      const items = HomeInsights.build(input, [])
      expect(items.length).assertEqual(0)
    })

    it('平稳柱子复述走势则不出', 0, () => {
      const items = HomeInsights.build(new HomeInsightInput(), [
        pressure('2026-08', 6759),
        pressure('2026-09', 6759),
        pressure('2026-10', 6759)
      ])
      expect(items.length).assertEqual(0)
    })

    it('订阅占比柱子看不出是谁则不出', 0, () => {
      const items = HomeInsights.build(new HomeInsightInput(), [
        pressure('2026-08', 10000, 6000),
        pressure('2026-09', 10000, 6000)
      ])
      expect(items.length).assertEqual(0)
    })

    it('利率差指出该先还哪笔', 0, () => {
      const high = TestFixtures.debt()
      high.id = 'high'
      high.platform = '花呗'
      high.annual_rate_bp = 1800
      high.remaining_periods = 8
      const low = TestFixtures.debt()
      low.id = 'low'
      low.platform = '房贷'
      low.annual_rate_bp = 400
      low.remaining_periods = 8
      const input = new HomeInsightInput()
      input.debts = [high, low]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'rate_target')).assertTrue()
      expect(firstText(items).includes('花呗')).assertTrue()
      expect(firstText(items).includes('冲')).assertTrue()
      expect(firstText(items).includes('47153')).assertFalse()
    })

    it('快清完的接到另一笔', 0, () => {
      const soon = TestFixtures.debt()
      soon.id = 'soon'
      soon.platform = '白条'
      soon.annual_rate_bp = 400
      soon.remaining_periods = 1
      const other = TestFixtures.debt()
      other.id = 'other'
      other.platform = '借呗'
      other.annual_rate_bp = 400
      other.remaining_periods = 10
      const input = new HomeInsightInput()
      input.debts = [soon, other]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'soon_clear')).assertTrue()
      expect(items[0].title.includes('借呗')).assertTrue()
    })

    it('这期多半在付息', 0, () => {
      const d = TestFixtures.debt()
      d.platform = '分期乐'
      d.annual_rate_bp = 0
      d.repayment_method = 'custom'
      d.current_balance = 100000
      d.monthly_payment = 10000
      d.remaining_periods = 24
      d.total_interest = 0
      const input = new HomeInsightInput()
      input.debts = [d]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'interest_heavy')).assertTrue()
      expect(firstText(items).includes('本金')).assertTrue()
    })

    it('信用卡最低还压不下来', 0, () => {
      const d = TestFixtures.debt()
      d.platform = '招行'
      d.debt_type = 'credit_card'
      d.annual_rate_bp = 0
      d.remaining_periods = 0
      d.current_balance = 60000
      d.monthly_payment = 5000
      const input = new HomeInsightInput()
      input.debts = [d]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'revolving')).assertTrue()
    })

    it('峰值月点出是哪一笔', 0, () => {
      const d = TestFixtures.debt()
      d.platform = '京东金条'
      d.annual_rate_bp = 0
      d.monthly_payment = 30000
      d.remaining_periods = 6
      d.next_payment_date = '2026-10-15'
      d.payment_day = 15
      const input = new HomeInsightInput()
      input.debts = [d]
      const items = HomeInsights.build(input, [
        pressure('2026-08', 10000),
        pressure('2026-09', 10000),
        pressure('2026-10', 40000)
      ])
      expect(hasId(items, 'peak_cause')).assertTrue()
      let text = ''
      for (let i = 0; i < items.length; i++) {
        if (items[i].id === 'peak_cause') {
          text = items[i].title
        }
      }
      expect(text.includes('10月')).assertTrue()
      expect(text.includes('京东金条')).assertTrue()
    })

    it('同类订阅重复开通', 0, () => {
      const a = TestFixtures.subscription()
      a.id = 's1'
      a.name = '腾讯视频'
      a.category = 'video'
      a.amount = 3000
      const b = TestFixtures.subscription()
      b.id = 's2'
      b.name = '爱奇艺'
      b.category = 'video'
      b.amount = 2500
      const input = new HomeInsightInput()
      input.subscriptions = [a, b]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'dup_subs')).assertTrue()
      expect(firstText(items).includes('腾讯视频')).assertTrue()
      expect(firstText(items).includes('爱奇艺')).assertTrue()    })

    it('年费还差几笔', 0, () => {
      const card = TestFixtures.creditAccount()
      card.name = '招行'
      card.annual_fee_required_swipes = 5
      card.annual_fee_manual_swipes = 3
      const input = new HomeInsightInput()
      input.accounts = [card]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'annual_fee')).assertTrue()
      expect(firstText(items).includes('2 笔')).assertTrue()    })

    it('多笔同一天扣', 0, () => {
      const a = TestFixtures.debt()
      a.id = 'd1'
      a.platform = '花呗'
      a.annual_rate_bp = 400
      a.payment_day = 15
      a.remaining_periods = 8
      const b = TestFixtures.debt()
      b.id = 'd2'
      b.platform = '白条'
      b.annual_rate_bp = 400
      b.payment_day = 15
      b.remaining_periods = 8
      const c = TestFixtures.debt()
      c.id = 'd3'
      c.platform = '借呗'
      c.annual_rate_bp = 400
      c.payment_day = 15
      c.remaining_periods = 8
      const input = new HomeInsightInput()
      input.debts = [a, b, c]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'same_payday')).assertTrue()
      expect(firstText(items).includes('15 号')).assertTrue()
    })

    it('额度占用偏高', 0, () => {
      const card = TestFixtures.creditAccount()
      card.id = 'c1'
      card.name = '招行'
      card.credit_limit = 10000
      const d = TestFixtures.debt()
      d.platform = '招行账单'
      d.annual_rate_bp = 0
      d.credit_account_id = 'c1'
      d.current_balance = 8000
      d.remaining_periods = 8
      const input = new HomeInsightInput()
      input.debts = [d]
      input.accounts = [card]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'credit_util')).assertTrue()
    })

    it('缺利率时提示补全', 0, () => {
      const a = TestFixtures.debt()
      a.id = 'd1'
      a.annual_rate_bp = 0
      a.remaining_periods = 8
      const b = TestFixtures.debt()
      b.id = 'd2'
      b.annual_rate_bp = 0
      b.remaining_periods = 8
      const input = new HomeInsightInput()
      input.debts = [a, b]
      const items = HomeInsights.build(input, [])
      expect(hasId(items, 'missing_rate')).assertTrue()
    })

    it('有余额但近期无待还提示核对', 0, () => {
      const input = new HomeInsightInput()
      input.remainingDebt = 50000
      const items = HomeInsights.build(input, [])
      expect(items.length).assertEqual(1)
      expect(items[0].id).assertEqual('stale_schedule')
      expect(items[0].title.includes('出单日')).assertTrue()
      expect(items[0].title.includes('50000')).assertFalse()
    })

    it('最多两条', 0, () => {
      const high = TestFixtures.debt()
      high.id = 'high'
      high.platform = '花呗'
      high.annual_rate_bp = 1800
      high.remaining_periods = 8
      const soon = TestFixtures.debt()
      soon.id = 'soon'
      soon.platform = '白条'
      soon.annual_rate_bp = 400
      soon.remaining_periods = 1
      const card = TestFixtures.creditAccount()
      card.name = '招行'
      card.annual_fee_required_swipes = 5
      card.annual_fee_manual_swipes = 1
      const input = new HomeInsightInput()
      input.debts = [high, soon]
      input.accounts = [card]
      const items = HomeInsights.build(input, [])
      expect(items.length <= HomeInsights.MAX_ITEMS).assertTrue()
      expect(items.length).assertEqual(2)
    })
  })
}
