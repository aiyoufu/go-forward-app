import { workScheduler, WorkSchedulerExtensionAbility } from '@kit.BackgroundTasksKit'
import { Logger } from 'common'
import {
  AuthManager,
  DbService,
  E2EEService,
  PreferencesService,
  ReminderService,
  UserService
} from 'service'

/**
 * 每日延迟任务：刷新应用内到期通知 + 系统代理提醒（杀进程后仍能弹出）。
 * 由 ReminderService.scheduleDailyReminder 注册。
 */
export default class ReminderWorkAbility extends WorkSchedulerExtensionAbility {
  onWorkStart(_workInfo: workScheduler.WorkInfo): void {
    this.run()
  }

  onWorkStop(_workInfo: workScheduler.WorkInfo): void {
  }

  private async run(): Promise<void> {
    try {
      await DbService.init(this.context)
      await PreferencesService.init(this.context)
      await E2EEService.initialize()
      const session = await AuthManager.loadSession()
      if (session === null || session.userId.length === 0) {
        await UserService.ensureDefaultUser()
      }
      await ReminderService.checkAndGenerateDueReminders()
    } catch (e) {
      Logger.warn('ReminderWork', 'onWorkStart: ' + (e instanceof Error ? e.message : 'err'))
    }
  }
}
