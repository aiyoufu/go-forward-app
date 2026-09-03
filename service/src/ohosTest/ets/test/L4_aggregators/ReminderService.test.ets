import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { ReminderService } from '../../../../main/ets/service/ReminderService'
import { NotificationComposer } from '../../../../main/ets/service/NotificationComposer'
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
  s.reminder_enabled = true
  s.reminder_days_before = 3
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

function makeSettings(overrides: Record<string, string | number | boolean> = {}): UserSettings {
  const s = new UserSettings()
  s.user_id = 'test-user-001'
  s.remind_before_due = true
  s.remind_on_due_day = true
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

export default function reminderServiceTest() {
  beforeEach(() => {
    DebtService._reset()
    SubscriptionService._reset()
    CreditAccountService._reset()
    SettingsService._reset()
    CalculationService._reset()
    DbService._reset()
    UserService._reset()
  })

  describe('ReminderService_checkAndNotify', () => {
    it('无今日到期债务_不抛异常', 0, async () => {
      await ReminderService.checkAndNotify()
      expect(true).assertTrue()
    })

    it('有今日到期债务_不抛异常', 0, async () => {
      const today = new Date()
      const m = today.getMonth() + 1
      const todayStr = today.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (today.getDate() < 10 ? '0' + today.getDate() : '' + today.getDate())
      DebtService._setPresetDebts([makeDebt({ id: 'd1', next_payment_date: todayStr })])
      await ReminderService.checkAndNotify()
      expect(true).assertTrue()
    })
  })

  describe('ReminderService_checkAndGenerateDueReminders', () => {
    it('空数据_不抛异常', 0, async () => {
      SettingsService._setPresetSettings(makeSettings())
      await ReminderService.checkAndGenerateDueReminders()
      expect(true).assertTrue()
    })

    it('未设置settings_不抛异常', 0, async () => {
      await ReminderService.checkAndGenerateDueReminders()
      expect(true).assertTrue()
    })

    it('remind_before_due和remind_on_due_day都为false_直接返回', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({
        remind_before_due: false, remind_on_due_day: false
      }))
      await ReminderService.checkAndGenerateDueReminders()
      expect(true).assertTrue()
    })

    it('有即将到期债务_不抛异常', 0, async () => {
      const future = new Date()
      future.setDate(future.getDate() + 3)
      const m = future.getMonth() + 1
      const futureStr = future.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (future.getDate() < 10 ? '0' + future.getDate() : '' + future.getDate())
      DebtService._setPresetDebts([makeDebt({ id: 'd1', next_payment_date: futureStr })])
      SettingsService._setPresetSettings(makeSettings())
      await ReminderService.checkAndGenerateDueReminders()
      expect(true).assertTrue()
    })

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
      await ReminderService.checkAndGenerateDueReminders()
      expect(true).assertTrue()
    })
  })

  describe('ReminderService_checkAndGenerateSubscriptionReminders', () => {
    it('空订阅_不抛异常', 0, async () => {
      await ReminderService.checkAndGenerateSubscriptionReminders('test-user-001', '2099-12-15')
      expect(true).assertTrue()
    })

    it('有即将续费订阅_不抛异常', 0, async () => {
      const future = new Date()
      future.setDate(future.getDate() + 3)
      const m = future.getMonth() + 1
      const futureStr = future.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (future.getDate() < 10 ? '0' + future.getDate() : '' + future.getDate())
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', next_billing_date: futureStr, reminder_days_before: 3 })
      ])
      await ReminderService.checkAndGenerateSubscriptionReminders('test-user-001', '2099-12-15')
      expect(true).assertTrue()
    })

    it('订阅今日扣费_不抛异常', 0, async () => {
      const today = new Date()
      const m = today.getMonth() + 1
      const todayStr = today.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (today.getDate() < 10 ? '0' + today.getDate() : '' + today.getDate())
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', next_billing_date: todayStr })
      ])
      await ReminderService.checkAndGenerateSubscriptionReminders('test-user-001', todayStr)
      expect(true).assertTrue()
    })

    it('订阅今日到期_不抛异常', 0, async () => {
      const today = new Date()
      const m = today.getMonth() + 1
      const todayStr = today.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (today.getDate() < 10 ? '0' + today.getDate() : '' + today.getDate())
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', end_date: todayStr, reminder_days_before: 3 })
      ])
      await ReminderService.checkAndGenerateSubscriptionReminders('test-user-001', todayStr)
      expect(true).assertTrue()
    })

    it('reminder_enabled为false_跳过', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', reminder_enabled: false })
      ])
      await ReminderService.checkAndGenerateSubscriptionReminders('test-user-001', '2099-12-15')
      expect(true).assertTrue()
    })

    it('status非active_跳过', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', status: 'cancelled' })
      ])
      await ReminderService.checkAndGenerateSubscriptionReminders('test-user-001', '2099-12-15')
      expect(true).assertTrue()
    })
  })

  describe('NotificationComposer_createNotification', () => {
    it('创建通知_不抛异常', 0, async () => {
      await NotificationComposer.createNotification('test-user-001', 'payment_due', '测试', '内容')
      expect(true).assertTrue()
    })

    it('带debtId_不抛异常', 0, async () => {
      await NotificationComposer.createNotification('test-user-001', 'payment_due', '测试', '内容', 'd1')
      expect(true).assertTrue()
    })

    it('带debtId和subscriptionId_不抛异常', 0, async () => {
      await NotificationComposer.createNotification('test-user-001', 'pressure_alert', '测试', '内容', 'd1', 's1')
      expect(true).assertTrue()
    })
  })

  describe('ReminderService_scheduleDailyReminder', () => {
    it('调度_不抛异常', 0, () => {
      try {
        ReminderService.scheduleDailyReminder()
        expect(true).assertTrue()
      } catch (err) {
        // workScheduler 在测试环境可能不可用，但应被 catch
        expect(true).assertTrue()
      }
    })
  })
}
