import { notificationManager } from '@kit.NotificationKit'
import { reminderAgentManager, workScheduler } from '@kit.BackgroundTasksKit'
import { common } from '@kit.AbilityKit'
import { DebtService } from './DebtService'
import { SubscriptionService } from './SubscriptionService'
import { CreditAccountService } from './CreditAccountService'
import { SettingsService } from './SettingsService'
import { NotificationService } from './NotificationService'
import { NotificationComposer } from './NotificationComposer'
import { ReminderType, CreditAccount } from 'common'
import { UserService } from './UserService'
import { Utils } from 'common'
import { Logger } from 'common'
import { Constants } from 'common'
import { CalculationService } from './CalculationService'
import { PressureAlertService } from './PressureAlertService'
import { PreferencesService } from './PreferencesService'

class AgentPlan {
  date: string = ''
  title: string = ''
  body: string = ''
  notificationId: number = 0
}

export class ReminderService {
  private static readonly TAG: string = 'Reminder'
  private static readonly PREF_AGENT_IDS: string = 'reminder_agent_ids_v1'
  private static readonly PREF_AGENT_FP: string = 'reminder_agent_fp_v1'
  private static readonly WORK_ID: number = 1001
  private static readonly WORK_ABILITY: string = 'ReminderWorkAbility'
  private static readonly BUNDLE: string = 'com.goforward.app'
  private static readonly AGENT_HOUR: number = 9
  private static readonly AGENT_MINUTE: number = 0
  private static readonly MAX_AGENTS: number = 20
  private static refreshTimer: number = -1

  /** 写后 debounce：刷新应用内通知 + 系统代理提醒 */
  static scheduleRefresh(): void {
    if (ReminderService.refreshTimer !== -1) {
      clearTimeout(ReminderService.refreshTimer)
    }
    ReminderService.refreshTimer = setTimeout(() => {
      ReminderService.refreshTimer = -1
      ReminderService.checkAndGenerateDueReminders().catch((e: Error | string) => {
        Logger.warn(ReminderService.TAG, 'refresh fail: ' +
          (e instanceof Error ? e.message : 'err'))
      })
    }, 2000) as number
  }

  static async ensureNotificationEnabled(context: common.UIAbilityContext): Promise<void> {
    try {
      const asked = await PreferencesService.getBool(Constants.PREF_NOTIF_PROMPT_SHOWN, false)
      if (asked) {
        return
      }
      await notificationManager.requestEnableNotification(context)
      await PreferencesService.putBool(Constants.PREF_NOTIF_PROMPT_SHOWN, true)
    } catch (e) {
      Logger.warn(ReminderService.TAG, 'requestEnableNotification: ' +
        (e instanceof Error ? e.message : 'err'))
    }
  }
  static async checkAndNotify(): Promise<void> {
    await ReminderService.checkAndGenerateDueReminders()
  }

  static async checkAndGenerateDueReminders(): Promise<void> {
    const userId = UserService.getCurrentUserId()
    const settings = await SettingsService.getSettings(userId)
    if (!settings) {
      return
    }
    if (!settings.remind_before_due && !settings.remind_on_due_day) {
      await ReminderService.cancelStoredAgents()
      await PreferencesService.putString(ReminderService.PREF_AGENT_FP, '')
      return
    }

    const debts = await DebtService.getActiveDebtsDueBeforeOrOn(Utils.addDays(Utils.todayString(), 3))
    const creditAccounts = await CreditAccountService.getCreditAccounts(userId)
    const accountMap = new Map<string, CreditAccount>()
    for (const a of creditAccounts) {
      accountMap.set(a.id, a)
    }

    const today = Utils.todayString()
    for (const debt of debts) {
      const account = debt.credit_account_id ? accountMap.get(debt.credit_account_id) : null
      const info = CalculationService.getDebtOverdueInfo(debt, account)
      const refId = debt.id

      if (info.isBreached) {
        if (await NotificationService.hasNotificationForToday(userId, 'payment_due', refId)) continue
        await NotificationComposer.createNotification(userId, 'payment_due', debt.platform + ' 已逾期',
          '已超宽限期 ' + info.daysLate + ' 天，请尽快还款 ' + Utils.formatMoney(debt.monthly_payment), debt.id)
        continue
      }
      if (info.isInGracePeriod) {
        if (await NotificationService.hasNotificationForToday(userId, 'payment_due', refId)) continue
        await NotificationComposer.createNotification(userId, 'payment_due', debt.platform + ' 宽限期内',
          '已逾期 ' + info.daysLate + ' 天，宽限期剩余 ' + (info.graceDays - info.daysLate) + ' 天', debt.id)
        continue
      }
      if (info.daysLeft === 0 && settings.remind_on_due_day) {
        if (await NotificationService.hasNotificationForToday(userId, 'payment_due', refId)) continue
        await NotificationComposer.createNotification(userId, 'payment_due', debt.platform + ' 今日到期',
          '本期应还 ' + Utils.formatMoney(debt.monthly_payment), debt.id)
        continue
      }
      if (settings.remind_before_due && (info.daysLeft === 3 || info.daysLeft === 1)) {
        if (await NotificationService.hasNotificationForToday(userId, 'payment_due', refId)) continue
        await NotificationComposer.createNotification(userId, 'payment_due', debt.platform + ' 即将到期',
          info.daysLeft === 1 ? '明天到期，应还 ' + Utils.formatMoney(debt.monthly_payment)
            : '3 天后到期，应还 ' + Utils.formatMoney(debt.monthly_payment), debt.id)
      }
    }

    await ReminderService.checkAndGenerateSubscriptionReminders(userId, today)

    // 压力预警引擎
    try {
      await PressureAlertService.evaluate(userId)
    } catch {
      // 预警失败不影响主提醒流程
    }

    await ReminderService.rescheduleAgentReminders()
  }

  static async checkAndGenerateSubscriptionReminders(userId: string, today: string): Promise<void> {
    const subscriptions = await SubscriptionService.getSubscriptions(userId)
    for (const sub of subscriptions) {
      if (!sub.reminder_enabled || sub.status !== 'active') continue
      const refId = sub.id
      const daysLeft = Utils.daysFromNow(sub.next_billing_date)
      // 结束日期早于等于下次扣费日：服务终止，不再产生扣费提醒
      const hasFutureBilling = !sub.end_date || sub.end_date.length === 0 || sub.next_billing_date < sub.end_date

      if (hasFutureBilling && daysLeft === sub.reminder_days_before && daysLeft > 0) {
        if (await NotificationService.hasNotificationForToday(userId, 'subscription_due', refId)) continue
        await NotificationComposer.createNotification(userId, 'subscription_due', sub.name + ' 即将续费',
          daysLeft + ' 天后扣费 ' + Utils.formatMoney(sub.amount), '', sub.id)
        continue
      }
      if (hasFutureBilling && daysLeft === 0) {
        if (await NotificationService.hasNotificationForToday(userId, 'subscription_due', refId)) continue
        await NotificationComposer.createNotification(userId, 'subscription_due', sub.name + ' 今日扣费',
          '本期扣费 ' + Utils.formatMoney(sub.amount), '', sub.id)
        continue
      }
      if (sub.end_date) {
        const endDaysLeft = Utils.daysFromNow(sub.end_date)
        if (endDaysLeft === sub.reminder_days_before && endDaysLeft > 0) {
          if (await NotificationService.hasNotificationForToday(userId, 'subscription_due', refId)) continue
          await NotificationComposer.createNotification(userId, 'subscription_due', sub.name + ' 即将到期',
            endDaysLeft + ' 天后到期，届时停止续费', '', sub.id)
          continue
        }
        if (endDaysLeft === 0) {
          if (await NotificationService.hasNotificationForToday(userId, 'subscription_due', refId)) continue
          await NotificationComposer.createNotification(userId, 'subscription_due', sub.name + ' 今日到期',
            '订阅已到期，将停止续费', '', sub.id)
        }
      }
    }
  }

  static scheduleDailyReminder(): void {
    try {
      const stale: workScheduler.WorkInfo = {
        workId: 1,
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        isPersisted: true,
        bundleName: ReminderService.BUNDLE,
        abilityName: 'EntryAbility'
      }
      try {
        workScheduler.stopWork(stale)
      } catch (_e) {
      }
      const workInfo: workScheduler.WorkInfo = {
        workId: ReminderService.WORK_ID,
        networkType: workScheduler.NetworkType.NETWORK_TYPE_ANY,
        isPersisted: true,
        isRepeat: true,
        repeatCycleTime: 24 * 60 * 60 * 1000,
        bundleName: ReminderService.BUNDLE,
        abilityName: ReminderService.WORK_ABILITY
      }
      workScheduler.startWork(workInfo)
    } catch (e) {
      Logger.warn(ReminderService.TAG, 'scheduleDailyReminder: ' +
        (e instanceof Error ? e.message : 'err'))
    }
  }

  private static async rescheduleAgentReminders(): Promise<void> {
    try {
      const userId = UserService.getCurrentUserId()
      if (userId.length === 0) {
        return
      }
      const settings = await SettingsService.getSettings(userId)
      const plans: AgentPlan[] = []
      const today = Utils.todayString()
      const now = new Date()
      const todayHour = now.getHours()
      const todayMinute = now.getMinutes()

      const debts = await DebtService.getActiveDebtsDueBeforeOrOn(Utils.addDays(today, 7), userId)
      for (const debt of debts) {
        const due = debt.next_payment_date
        if (due.length < 10) {
          continue
        }
        if (due < today) {
          if (settings.remind_on_due_day) {
            ReminderService.pushPlanIfFuture(plans, today, todayHour, todayMinute,
              debt.platform + ' 已逾期',
              '请尽快还款 ' + Utils.formatMoney(debt.monthly_payment),
              Utils.hashId(debt.id + ':overdue'))
          }
          continue
        }
        if (due === today && settings.remind_on_due_day) {
          ReminderService.pushPlanIfFuture(plans, today, todayHour, todayMinute,
            debt.platform + ' 今日到期',
            '本期应还 ' + Utils.formatMoney(debt.monthly_payment),
            Utils.hashId(debt.id + ':due'))
          continue
        }
        if (settings.remind_before_due) {
          const before1 = Utils.addDays(due, -1)
          const before3 = Utils.addDays(due, -3)
          if (before1 >= today) {
            ReminderService.pushPlanIfFuture(plans, before1, todayHour, todayMinute,
              debt.platform + ' 即将到期',
              '明天到期，应还 ' + Utils.formatMoney(debt.monthly_payment),
              Utils.hashId(debt.id + ':d1'))
          }
          if (before3 >= today) {
            ReminderService.pushPlanIfFuture(plans, before3, todayHour, todayMinute,
              debt.platform + ' 即将到期',
              '3 天后到期，应还 ' + Utils.formatMoney(debt.monthly_payment),
              Utils.hashId(debt.id + ':d3'))
          }
        }
      }

      const subscriptions = await SubscriptionService.getSubscriptions(userId)
      for (const sub of subscriptions) {
        if (!sub.reminder_enabled || sub.status !== 'active') {
          continue
        }
        const due = sub.next_billing_date
        if (due.length < 10) {
          continue
        }
        if (due >= today) {
          ReminderService.pushPlanIfFuture(plans, due, todayHour, todayMinute,
            sub.name + ' 今日扣费',
            '本期扣费 ' + Utils.formatMoney(sub.amount),
            Utils.hashId(sub.id + ':bill'))
        }
        if (sub.reminder_days_before > 0) {
          const ahead = Utils.addDays(due, -sub.reminder_days_before)
          if (ahead >= today && ahead !== due) {
            ReminderService.pushPlanIfFuture(plans, ahead, todayHour, todayMinute,
              sub.name + ' 即将续费',
              sub.reminder_days_before + ' 天后扣费 ' + Utils.formatMoney(sub.amount),
              Utils.hashId(sub.id + ':ahead'))
          }
        }
      }

      const limit = plans.length < ReminderService.MAX_AGENTS ? plans.length : ReminderService.MAX_AGENTS
      let fp = ''
      for (let i = 0; i < limit; i++) {
        fp = fp + plans[i].date + '#' + plans[i].notificationId + '#' + plans[i].title + ';'
      }
      const prevFp = await PreferencesService.getString(ReminderService.PREF_AGENT_FP, '')
      if (fp === prevFp) {
        return
      }

      await ReminderService.cancelStoredAgents()
      const ids: string[] = []
      for (let i = 0; i < limit; i++) {
        const id = await ReminderService.publishAgent(plans[i])
        if (id > 0) {
          ids.push('' + id)
        }
      }
      await PreferencesService.putString(ReminderService.PREF_AGENT_IDS, ids.join(','))
      await PreferencesService.putString(ReminderService.PREF_AGENT_FP, fp)
    } catch (e) {
      Logger.warn(ReminderService.TAG, 'rescheduleAgentReminders: ' +
        (e instanceof Error ? e.message : 'err'))
    }
  }

  private static pushPlanIfFuture(
    plans: AgentPlan[],
    date: string,
    nowHour: number,
    nowMinute: number,
    title: string,
    body: string,
    notificationId: number
  ): void {
    const today = Utils.todayString()
    if (date < today) {
      return
    }
    if (date === today) {
      if (nowHour > ReminderService.AGENT_HOUR ||
        (nowHour === ReminderService.AGENT_HOUR && nowMinute >= ReminderService.AGENT_MINUTE)) {
        return
      }
    }
    const p = new AgentPlan()
    p.date = date
    p.title = title
    p.body = body
    p.notificationId = Math.abs(notificationId) % 100000 + 200
    plans.push(p)
  }

  private static async publishAgent(plan: AgentPlan): Promise<number> {
    const y = Number(plan.date.substring(0, 4))
    const m = Number(plan.date.substring(5, 7))
    const d = Number(plan.date.substring(8, 10))
    if (isNaN(y) || isNaN(m) || isNaN(d)) {
      return 0
    }
    const req: reminderAgentManager.ReminderRequestCalendar = {
      reminderType: reminderAgentManager.ReminderType.REMINDER_TYPE_CALENDAR,
      dateTime: {
        year: y,
        month: m,
        day: d,
        hour: ReminderService.AGENT_HOUR,
        minute: ReminderService.AGENT_MINUTE
      },
      title: plan.title,
      content: plan.body,
      notificationId: plan.notificationId,
      slotType: notificationManager.SlotType.CONTENT_INFORMATION,
      wantAgent: {
        pkgName: ReminderService.BUNDLE,
        abilityName: 'EntryAbility'
      },
      actionButton: [
        {
          title: '关闭',
          type: reminderAgentManager.ActionButtonType.ACTION_BUTTON_TYPE_CLOSE
        }
      ]
    }
    try {
      return await reminderAgentManager.publishReminder(req)
    } catch (e) {
      Logger.warn(ReminderService.TAG, 'publishReminder: ' +
        (e instanceof Error ? e.message : 'err'))
      return 0
    }
  }

  private static async cancelStoredAgents(): Promise<void> {
    try {
      const raw = await PreferencesService.getString(ReminderService.PREF_AGENT_IDS, '')
      if (raw.length === 0) {
        return
      }
      const parts = raw.split(',')
      for (let i = 0; i < parts.length; i++) {
        const id = Number(parts[i])
        if (id > 0) {
          try {
            await reminderAgentManager.cancelReminder(id)
          } catch (_e) {
          }
        }
      }
      await PreferencesService.putString(ReminderService.PREF_AGENT_IDS, '')
    } catch (e) {
      Logger.warn(ReminderService.TAG, 'cancelStoredAgents: ' +
        (e instanceof Error ? e.message : 'err'))
    }
  }
}
