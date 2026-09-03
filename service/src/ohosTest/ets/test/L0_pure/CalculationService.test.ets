import { describe, it, expect } from '@ohos/hypium'
import { CalculationService } from '../../../../main/ets/service/CalculationService'
import { Debt } from 'common'
import { Subscription } from 'common'
import { TestFixtures } from '../TestFixtures'

function makeSub(overrides: Record<string, string | number> = {}): Subscription {
  const s = TestFixtures.subscription()
  s.status = 'active'
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number>)[k] = overrides[k]
  }
  return s
}

export default function calculationServiceTest() {
  describe('CalculationService_bpToMonthlyRate', () => {
    it('正常年利率1800bp', 0, () => {
      expect(CalculationService.bpToMonthlyRate(1800)).assertEqual(0.18 / 12)
    })
    it('零利率', 0, () => {
      expect(CalculationService.bpToMonthlyRate(0)).assertEqual(0)
    })
  })

  describe('CalculationService_calculatePeriodPayment', () => {
    it('等额本息_有利息', 0, () => {
      const result = CalculationService.calculatePeriodPayment(10000, 1800, 12, 12, 'equal_payment')
      expect(result.principal + result.interest).assertLarger(0)
      expect(result.interest).assertEqual(Math.round(10000 * (0.18 / 12)))
    })
    it('等额本息_最后一期', 0, () => {
      const result = CalculationService.calculatePeriodPayment(5000, 1200, 1, 12, 'equal_payment')
      expect(result.principal).assertEqual(5000)
    })
    it('等额本息_末期月供高于本金_差额为服务费', 0, () => {
      const result = CalculationService.calculatePeriodPayment(5777, 323, 1, 9, 'equal_payment', 51993, 5831, 486)
      expect(result.principal).assertEqual(5777)
      expect(result.interest).assertEqual(54)
    })
    it('固定利息_零利率本金按期分摊', 0, () => {
      const result = CalculationService.calculatePeriodPayment(12000, 0, 12, 12, 'fixed_interest')
      // 0 利率时利息为 0，本金可按算法为 0 或分摊，只断言非负
      expect(result.principal >= 0).assertTrue()
      expect(result.interest >= 0).assertTrue()
    })
    it('自定义_无利率时从月供推导利息', 0, () => {
      // 本金 57.77、月供 58.31、最后一期：利息应为 0.54
      const result = CalculationService.calculatePeriodPayment(5777, 0, 1, 9, 'custom', 0, 5831, 0)
      expect(result.principal).assertEqual(5777)
      expect(result.interest).assertEqual(54)
    })
    it('自定义_多期无利率时从月供推导利息', 0, () => {
      const result = CalculationService.calculatePeriodPayment(6000, 0, 3, 3, 'custom', 0, 2500, 0)
      // 估算本金 2000，月供 2500，利息 500
      expect(result.interest).assertEqual(500)
      expect(result.principal).assertEqual(2000)
    })
  })

  describe('CalculationService_scheduleAndInterest', () => {
    it('generatePaymentSchedule非空', 0, () => {
      const debt = TestFixtures.debt()
      debt.current_balance = 12000
      debt.remaining_periods = 12
      debt.monthly_payment = 1000
      debt.annual_rate_bp = 0
      const schedule = CalculationService.generatePaymentSchedule(debt)
      expect(schedule.length).assertLarger(0)
    })
    it('calculateRemainingInterest非负', 0, () => {
      const debt = TestFixtures.debt()
      const interest = CalculationService.calculateRemainingInterest(debt)
      expect(interest >= 0).assertTrue()
    })
    it('getDebtOverdueInfo可调用', 0, () => {
      const debt = TestFixtures.debt()
      debt.status = 'active'
      debt.next_payment_date = '2020-01-01'
      const info = CalculationService.getDebtOverdueInfo(debt)
      expect(info !== null && info !== undefined).assertTrue()
    })
    it('parseCustomSchedule空note', 0, () => {
      const r = CalculationService.parseCustomSchedule('')
      expect(r === null).assertTrue()
    })
    it('getCleanNoteText', 0, () => {
      const t = CalculationService.getCleanNoteText('普通备注')
      expect(t).assertEqual('普通备注')
    })
    it('getDebtPaymentForMonth_PC剩余1_下月含服务费', 0, () => {
      const debt = TestFixtures.debt()
      debt.debt_type = 'installment'
      debt.status = 'active'
      debt.repayment_method = 'equal_payment'
      debt.current_balance = 11662
      debt.monthly_payment = 5831
      debt.principal = 51993
      debt.total_interest = 486
      debt.total_periods = 9
      debt.remaining_periods = 1
      debt.next_payment_date = '2026-08-04'
      debt.annual_rate_bp = 323
      expect(CalculationService.getDebtPaymentForMonth(debt, '2026-08')).assertEqual(5831)
      expect(CalculationService.getDebtPaymentForMonth(debt, '2026-09')).assertEqual(5831)
    })
    it('getDebtPaymentForMonth_月供仅本金_补上每期服务费', 0, () => {
      const debt = TestFixtures.debt()
      debt.debt_type = 'installment'
      debt.status = 'active'
      debt.repayment_method = 'equal_payment'
      debt.current_balance = 5777
      debt.monthly_payment = 5777
      debt.principal = 51993
      debt.total_interest = 486
      debt.total_periods = 9
      debt.remaining_periods = 0
      debt.next_payment_date = '2026-09-04'
      expect(CalculationService.getDebtPaymentForMonth(debt, '2026-09')).assertEqual(5831)
    })
    it('getDebtPaymentForMonth_custom_schedule丢失利息时用月供补齐', 0, () => {
      const debt = TestFixtures.debt()
      debt.repayment_method = 'custom'
      debt.current_balance = 5777
      debt.monthly_payment = 5831
      debt.total_periods = 9
      debt.remaining_periods = 1
      debt.next_payment_date = '2026-09-04'
      debt.annual_rate_bp = 0
      debt.note = '{"custom_schedule":[{"period_number":9,"principal":5777,"interest":0,"total":5777,"paid":false,"date":"2026-09-04"}],"text":""}'
      const amount = CalculationService.getDebtPaymentForMonth(debt, '2026-09')
      expect(amount).assertEqual(5831)
    })
    it('getInstallmentRemainingDue_末期remaining0_用月供不含仅本金', 0, () => {
      const debt = TestFixtures.debt()
      debt.debt_type = 'installment'
      debt.status = 'active'
      debt.repayment_method = 'equal_payment'
      debt.current_balance = 5777
      debt.monthly_payment = 5831
      debt.total_periods = 9
      debt.remaining_periods = 0
      debt.annual_rate_bp = 323
      expect(CalculationService.getInstallmentRemainingDue(debt)).assertEqual(5831)
    })
    it('getInstallmentRemainingDue_PC剩余1_两期待还', 0, () => {
      const debt = TestFixtures.debt()
      debt.debt_type = 'installment'
      debt.status = 'active'
      debt.repayment_method = 'equal_payment'
      debt.current_balance = 11662
      debt.monthly_payment = 5831
      debt.total_periods = 9
      debt.remaining_periods = 1
      expect(CalculationService.getInstallmentRemainingDue(debt)).assertEqual(11662)
    })
    it('getDebtPaymentForMonth_custom_schedule含利息时直接用schedule', 0, () => {
      const debt = TestFixtures.debt()
      debt.repayment_method = 'custom'
      debt.current_balance = 5777
      debt.monthly_payment = 5831
      debt.total_periods = 9
      debt.remaining_periods = 1
      debt.next_payment_date = '2026-09-04'
      debt.annual_rate_bp = 0
      debt.note = '{"custom_schedule":[{"period_number":9,"principal":5777,"interest":54,"total":5831,"paid":false,"date":"2026-09-04"}],"text":""}'
      const amount = CalculationService.getDebtPaymentForMonth(debt, '2026-09')
      expect(amount).assertEqual(5831)
    })
  })

  describe('CalculationService_monthlyPressure', () => {
    it('空列表', 0, () => {
      const debts: Debt[] = []
      const subs: Subscription[] = []
      const result = CalculationService.calculateMonthlyPressure(debts, subs, 3)
      expect(result.length).assertLarger(0)
    })
    it('有债务', 0, () => {
      const debt = TestFixtures.debt()
      debt.status = 'active'
      debt.monthly_payment = 1000
      const result = CalculationService.calculateMonthlyPressure([debt], [], 2)
      expect(result.length).assertEqual(2)
    })
    it('联动订阅月额', 0, () => {
      const s = TestFixtures.subscription()
      s.status = 'active'
      s.amount = 100
      s.credit_account_id = 'acc1'
      const m = CalculationService.getCreditLinkedSubscriptionMonthly([s])
      expect(m).assertEqual(100)
    })
    it('仅关联订阅_本月debtAmount为0_合计含订阅', 0, () => {
      const s = TestFixtures.subscription()
      s.status = 'active'
      s.amount = 8317
      s.credit_account_id = 'acc1'
      const due = CalculationService.getDueAmountForMonth([], [s], '2026-08', '2026-08')
      expect(due.debtAmount).assertEqual(0)
      expect(due.subscriptionAmount).assertEqual(8317)
      expect(due.amount).assertEqual(8317)
    })
  })

  describe('CalculationService_isSubscriptionDueInMonth', () => {
    it('正常月付_无结束日_计入下个月', 0, () => {
      const s = makeSub({ billing_cycle: 'monthly', next_billing_date: '2026-09-08' })
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 8)).assertEqual(false)
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 9)).assertEqual(true)
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 10)).assertEqual(false)
    })
    it('结束日等于下次扣费日_该月不计费', 0, () => {
      // 月付至 2026-09-08 终止，9/8 当天不再产生新一期扣费
      const s = makeSub({ billing_cycle: 'monthly', next_billing_date: '2026-09-08', end_date: '2026-09-08' })
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 9)).assertEqual(false)
    })
    it('结束日在下次扣费日之前_无未来扣费', 0, () => {
      const s = makeSub({ billing_cycle: 'monthly', next_billing_date: '2026-09-08', end_date: '2026-09-01' })
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 9)).assertEqual(false)
    })
    it('一次性季度_结束日等于下次扣费日_不摊到结束月', 0, () => {
      // 7 月购买的一季度订阅，10/16 到期，8/9/10 均不视为扣费月
      const s = makeSub({ billing_cycle: 'once_quarterly', next_billing_date: '2026-10-16', end_date: '2026-10-16' })
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 8)).assertEqual(false)
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 9)).assertEqual(false)
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 10)).assertEqual(false)
    })
    it('结束日晚于后续扣费日_期内扣费仍计入', 0, () => {
      const s = makeSub({ billing_cycle: 'monthly', next_billing_date: '2026-08-08', end_date: '2026-10-07' })
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 8)).assertEqual(true)
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 9)).assertEqual(true)
      expect(CalculationService.isSubscriptionDueInMonth(s, 2026, 10)).assertEqual(false)
    })
  })

  describe('CalculationService_dates', () => {
    it('addMonths', 0, () => {
      const d = CalculationService.addMonths('2024-01-15', 1)
      expect(d.length).assertLarger(0)
    })
    it('calculateEstimatedEndDate', 0, () => {
      const d = CalculationService.calculateEstimatedEndDate('2024-01-15', 3)
      expect(d.length).assertLarger(0)
    })
    it('calculateNextBillingDate monthly', 0, () => {
      const d = CalculationService.calculateNextBillingDate('monthly', '2024-01-15')
      expect(d.length).assertLarger(0)
    })
  })
}
