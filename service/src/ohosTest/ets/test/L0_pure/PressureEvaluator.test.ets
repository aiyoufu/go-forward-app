import { describe, it, expect } from '@ohos/hypium'
import { Debt, Subscription, CreditAccount, UserSettings } from 'common'
import {
  PressureEvaluator,
  PressureSnapshot,
  PressureAlertEvent
} from '../../../../main/ets/service/PressureEvaluator'

function dateStr(offsetDays: number): string {
  const d = new Date()
  d.setDate(d.getDate() + offsetDays)
  const m = d.getMonth() + 1
  return d.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
    (d.getDate() < 10 ? '0' + d.getDate() : '' + d.getDate())
}

function makeDebt(overrides: Record<string, string | number | boolean> = {}): Debt {
  const d = new Debt()
  d.id = 'd1'
  d.user_id = 'u1'
  d.platform = '花呗'
  d.debt_type = 'installment'
  d.principal = 120000
  d.current_balance = 80000
  d.monthly_payment = 12000
  d.total_periods = 12
  d.remaining_periods = 8
  d.repayment_method = 'equal_payment'
  d.annual_rate_bp = 600
  d.payment_day = 15
  d.next_payment_date = dateStr(3)
  d.start_date = '2024-01-01'
  d.status = 'active'
  d.credit_account_id = ''
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(d as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return d
}

function makeSub(overrides: Record<string, string | number | boolean> = {}): Subscription {
  const s = new Subscription()
  s.id = 's1'
  s.user_id = 'u1'
  s.name = '爱奇艺'
  s.category = 'video'
  s.amount = 2500
  s.billing_cycle = 'monthly'
  s.next_billing_date = dateStr(3)
  s.start_date = '2024-01-01'
  s.status = 'active'
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

function makeAcct(overrides: Record<string, string | number | boolean> = {}): CreditAccount {
  const a = new CreditAccount()
  a.id = 'a1'
  a.user_id = 'u1'
  a.name = '招行'
  a.grace_period_days = 5
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(a as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return a
}

function makeSettings(overrides: Record<string, string | number | boolean> = {}): UserSettings {
  const s = new UserSettings()
  s.user_id = 'u1'
  s.pressure_alert_enabled = true
  s.monthly_budget_limit = 0
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

function evaluate(debts: Debt[], subs: Subscription[], accounts: CreditAccount[],
  settings: UserSettings | null): PressureAlertEvent[] {
  const snap = new PressureSnapshot()
  snap.debts = debts
  snap.subscriptions = subs
  snap.accounts = accounts
  snap.settings = settings
  snap.today = dateStr(0)
  return PressureEvaluator.evaluate(snap)
}

export default function pressureEvaluatorTest() {
  describe('PressureEvaluator_基础', () => {
    it('settings为null_返回空', 0, () => {
      const events = evaluate([makeDebt()], [], [], null)
      expect(events.length).assertEqual(0)
    })

    it('非active债务被过滤_不参与任何规则', 0, () => {
      const events = evaluate(
        [makeDebt({ status: 'completed' }), makeDebt({ id: 'd2', status: 'completed' })],
        [], [], makeSettings())
      expect(events.length).assertEqual(0)
    })
  })

  describe('PressureEvaluator_密集到期', () => {
    it('两笔7天内到期_触发一条', 0, () => {
      // 预算给足：隔离密集规则，排除月度超额回退干扰
      const events = evaluate(
        [makeDebt({ id: 'd1' }), makeDebt({ id: 'd2' })],
        [], [], makeSettings({ monthly_budget_limit: 999999999 }))
      expect(events.length).assertEqual(1)
      expect(events[0].dedupeKey).assertEqual('dense_expiry')
      expect(events[0].title).assertEqual('还款密集预警')
    })

    it('单笔到期_不触发', 0, () => {
      const events = evaluate([makeDebt()], [], [], makeSettings())
      let hasDense = false
      for (const e of events) {
        if (e.dedupeKey === 'dense_expiry') hasDense = true
      }
      expect(hasDense).assertFalse()
    })

    it('到期日已过_不触发密集', 0, () => {
      const events = evaluate(
        [makeDebt({ id: 'd1', next_payment_date: dateStr(-3) }),
          makeDebt({ id: 'd2', next_payment_date: dateStr(-2) })],
        [], [], makeSettings())
      let hasDense = false
      for (const e of events) {
        if (e.dedupeKey === 'dense_expiry') hasDense = true
      }
      expect(hasDense).assertFalse()
    })
  })

  describe('PressureEvaluator_月度超额', () => {
    it('当月应还超预算_触发', 0, () => {
      // 当月到期一笔大额：currentMonthPressure > budgetLimit
      const events = evaluate(
        [makeDebt({ next_payment_date: dateStr(0), remaining_periods: 1 })],
        [], [], makeSettings({ monthly_budget_limit: 100 }))
      let hasExcess = false
      for (const e of events) {
        if (e.dedupeKey === 'monthly_excess') hasExcess = true
      }
      expect(hasExcess).assertTrue()
    })

    it('预算充足_不触发', 0, () => {
      const events = evaluate(
        [makeDebt({ next_payment_date: dateStr(0), remaining_periods: 1 })],
        [], [], makeSettings({ monthly_budget_limit: 999999999 }))
      expect(events.length).assertEqual(0)
    })
  })

  describe('PressureEvaluator_逾期升级', () => {
    it('宽限期内_触发且带debtId', 0, () => {
      const acct = makeAcct({ grace_period_days: 5 })
      const events = evaluate(
        [makeDebt({ credit_account_id: 'a1', next_payment_date: dateStr(-3) })],
        [], [acct], makeSettings({ monthly_budget_limit: 999999999 }))
      expect(events.length).assertEqual(1)
      expect(events[0].dedupeKey).assertEqual('overdue_upgrade_d1')
      expect(events[0].debtId).assertEqual('d1')
      expect(events[0].subscriptionId).assertEqual('')
    })

    it('超过宽限期_已破坏不触发', 0, () => {
      const acct = makeAcct({ grace_period_days: 1 })
      const events = evaluate(
        [makeDebt({ credit_account_id: 'a1', next_payment_date: dateStr(-3) })],
        [], [acct], makeSettings())
      expect(events.length).assertEqual(0)
    })
  })

  describe('PressureEvaluator_订阅叠加', () => {
    it('同日扣费_7天内_触发合计金额', 0, () => {
      const events = evaluate(
        [makeDebt()],
        [makeSub()],
        [], makeSettings({ monthly_budget_limit: 999999999 }))
      expect(events.length).assertEqual(1)
      expect(events[0].dedupeKey).assertEqual('overlap_d1_s1')
      expect(events[0].debtId).assertEqual('d1')
      expect(events[0].subscriptionId).assertEqual('s1')
      expect(events[0].body.indexOf('145')).assertLarger(-1)
    })

    it('扣费日不同_不触发', 0, () => {
      const events = evaluate(
        [makeDebt()],
        [makeSub({ next_billing_date: dateStr(20) })],
        [], makeSettings())
      expect(events.length).assertEqual(0)
    })
  })
}
