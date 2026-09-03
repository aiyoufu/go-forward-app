import { Debt, Subscription, CreditAccount, UserSettings } from 'common'

export class TestFixtures {
  static debt(): Debt {
    const d = new Debt()
    d.id = 'd1'
    d.user_id = 'test-user'
    d.platform = '测试平台'
    d.current_balance = 10000
    d.principal = 10000
    d.monthly_payment = 1000
    d.status = 'active'
    d.total_periods = 12
    d.remaining_periods = 6
    d.annual_rate_bp = 1800
    d.payment_day = 15
    d.next_payment_date = '2024-12-15'
    d.debt_type = 'installment'
    d.repayment_method = 'equal_payment'
    return d
  }

  static subscription(): Subscription {
    const s = new Subscription()
    s.id = 's1'
    s.user_id = 'test-user'
    s.name = '测试订阅'
    s.amount = 2500
    s.status = 'active'
    s.category = 'video'
    s.billing_cycle = 'monthly'
    s.next_billing_date = '2024-12-15'
    return s
  }

  static creditAccount(): CreditAccount {
    const c = new CreditAccount()
    c.id = 'c1'
    c.user_id = 'test-user'
    c.name = '测试卡'
    c.credit_limit = 50000
    return c
  }

  static settings(): UserSettings {
    return new UserSettings()
  }
}
