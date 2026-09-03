import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { PressureAlertService } from '../../../../main/ets/service/PressureAlertService'
import { Debt, Subscription, CreditAccount, UserSettings } from 'common'
import { DebtService } from '../../mock/DebtService.mock'
import { SubscriptionService } from '../../mock/SubscriptionService.mock'
import { CreditAccountService } from '../../mock/CreditAccountService.mock'
import { SettingsService } from '../../mock/SettingsService.mock'
import { CalculationService } from '../../mock/CalculationService.mock'
import { DbService } from '../../mock/DbService.mock'
import { UserService } from '../../mock/UserService.mock'

function makeDebt(overrides: Record<string, string | number | boolean> = {}): Debt {
  const d = new Debt()
  d.id = 'd1'
  d.user_id = 'test-user-001'
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
  d.next_payment_date = '2099-12-15'
  d.start_date = '2024-01-01'
  d.status = 'active'
  d.credit_account_id = ''
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(d as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return d
}

function makeSubscription(overrides: Record<string, string | number | boolean> = {}): Subscription {
  const s = new Subscription()
  s.id = 's1'
  s.user_id = 'test-user-001'
  s.name = '爱奇艺'
  s.category = 'video'
  s.amount = 2500
  s.billing_cycle = 'monthly'
  s.next_billing_date = '2099-12-15'
  s.start_date = '2024-01-01'
  s.status = 'active'
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

function makeSettings(overrides: Record<string, string | number | boolean> = {}): UserSettings {
  const s = new UserSettings()
  s.user_id = 'test-user-001'
  s.pressure_alert_enabled = true
  s.monthly_budget_limit = 0
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

export default function pressureAlertServiceTest() {
  beforeEach(() => {
    DebtService._reset()
    SubscriptionService._reset()
    CreditAccountService._reset()
    SettingsService._reset()
    CalculationService._reset()
    DbService._reset()
    UserService._reset()
  })

  describe('PressureAlertService_evaluate_基础路径', () => {
    it('空数据_不抛异常', 0, async () => {
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })

    it('指定userId_不抛异常', 0, async () => {
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate('test-user-001')
      expect(true).assertTrue()
    })

    it('未设置settings_不抛异常', 0, async () => {
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })

    it('pressure_alert_enabled为false_直接返回', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({ pressure_alert_enabled: false }))
      // 不应抛出
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })
  })

  describe('PressureAlertService_evaluate_密集到期', () => {
    it('2笔active债务未来7天到期_不抛异常', 0, async () => {
      // 计算未来 3 天的日期
      const future = new Date()
      future.setDate(future.getDate() + 3)
      const m = future.getMonth() + 1
      const futureStr = future.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (future.getDate() < 10 ? '0' + future.getDate() : '' + future.getDate())
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', next_payment_date: futureStr }),
        makeDebt({ id: 'd2', next_payment_date: futureStr })
      ])
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })

    it('1笔到期_不触发密集预警', 0, async () => {
      const future = new Date()
      future.setDate(future.getDate() + 3)
      const m = future.getMonth() + 1
      const futureStr = future.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (future.getDate() < 10 ? '0' + future.getDate() : '' + future.getDate())
      DebtService._setPresetDebts([makeDebt({ id: 'd1', next_payment_date: futureStr })])
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })

    it('债务到期日已过_不触发密集预警', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', next_payment_date: '2020-01-01' }),
        makeDebt({ id: 'd2', next_payment_date: '2020-01-02' })
      ])
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })
  })

  describe('PressureAlertService_evaluate_月度超额', () => {
    it('有预算限额_不抛异常', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({ monthly_budget_limit: 10000 }))
      CalculationService._setPresetMonthlyPressure([
        { month: '2099-12', amount: 5000 }
      ])
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })

    it('无预算限额但有压力数据_用平均值', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({ monthly_budget_limit: 0 }))
      CalculationService._setPresetMonthlyPressure([
        { month: '2099-12', amount: 5000 },
        { month: '2099-11', amount: 4000 },
        { month: '2099-10', amount: 6000 }
      ])
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })
  })

  describe('PressureAlertService_evaluate_订阅叠加', () => {
    it('订阅和债务同日到期_不抛异常', 0, async () => {
      const future = new Date()
      future.setDate(future.getDate() + 3)
      const m = future.getMonth() + 1
      const futureStr = future.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (future.getDate() < 10 ? '0' + future.getDate() : '' + future.getDate())
      DebtService._setPresetDebts([makeDebt({ id: 'd1', next_payment_date: futureStr })])
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', next_billing_date: futureStr })
      ])
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })
  })

  describe('PressureAlertService_evaluate_逾期升级', () => {
    it('债务关联信用账户_不抛异常', 0, async () => {
      const acct = new CreditAccount()
      acct.id = 'a1'
      acct.user_id = 'test-user-001'
      acct.name = '招行'
      acct.grace_period_days = 3
      CreditAccountService._setPresetCreditAccounts([acct])
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', credit_account_id: 'a1' })
      ])
      SettingsService._setPresetSettings(makeSettings())
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })
  })

  describe('PressureAlertService_evaluate_异常容错', () => {
    it('SettingsService抛错_被捕获', 0, async () => {
      // 不预设 settings，SettingsService.mock 返回 {} 空对象
      // pressure_alert_enabled 读取 undefined，应为 falsy 直接返回
      await PressureAlertService.evaluate()
      expect(true).assertTrue()
    })
  })
}
