import { DebtService } from './DebtService'
import { Logger } from 'common'
import { SubscriptionService } from './SubscriptionService'
import { CreditAccountService } from './CreditAccountService'
import { SettingsService } from './SettingsService'
import { NotificationService } from './NotificationService'
import { UserService } from './UserService'
import { Utils } from 'common'
import { UserSettings } from 'common'
import { NotificationComposer } from './NotificationComposer'
import { PressureEvaluator, PressureAlertEvent, PressureSnapshot } from './PressureEvaluator'

/**
 * 压力预警编排器：装载快照 → PressureEvaluator 纯规则评估 → 当日去重 → NotificationComposer 投递。
 * 规则本体在 PressureEvaluator（纯函数），投递通道在 NotificationComposer，本类不含业务判断。
 */
export class PressureAlertService {
  static async evaluate(userId?: string): Promise<void> {
    try {
      const uid = userId !== undefined && userId.length > 0 ? userId : UserService.getCurrentUserId()
      const settings: UserSettings = await SettingsService.getSettings(uid)

      if (!settings.pressure_alert_enabled) {
        return
      }

      const snapshot = new PressureSnapshot()
      snapshot.debts = await DebtService.getDebts(uid)
      snapshot.subscriptions = await SubscriptionService.getSubscriptions(uid)
      snapshot.accounts = await CreditAccountService.getCreditAccounts(uid)
      snapshot.settings = settings
      snapshot.today = Utils.todayString()

      const events: PressureAlertEvent[] = PressureEvaluator.evaluate(snapshot)
      for (const e of events) {
        const hasNotified = await NotificationService.hasNotificationForToday(uid, 'pressure_alert', e.dedupeKey)
        if (!hasNotified) {
          await NotificationComposer.createNotification(
            uid, 'pressure_alert', e.title, e.body, e.debtId, e.subscriptionId)
        }
      }
    } catch {
      Logger.error('PressureAlertService', 'evaluate error')
    }
  }
}
