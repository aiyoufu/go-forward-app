import { notificationManager } from '@kit.NotificationKit'
import { wantAgent } from '@kit.AbilityKit'
import { Notification, ReminderType } from 'common'
import { Utils } from 'common'
import { DbService } from './DbService'
import { NotificationService } from './NotificationService'

/**
 * 通知投递统一出口：落库（仅作「今日已发」去重）+ 系统通知推送。
 * ReminderService 与 PressureAlertService 共用，避免两引擎互相依赖。
 */
export class NotificationComposer {
  private static readonly BUNDLE: string = 'com.goforward.app'

  static async createNotification(
    userId: string,
    reminderType: ReminderType,
    title: string,
    body: string,
    debtId: string = '',
    subscriptionId: string = ''
  ): Promise<void> {
    const n = new Notification()
    n.id = Utils.generateId()
    n.user_id = userId
    n.debt_id = debtId
    n.subscription_id = subscriptionId
    n.reminder_type = reminderType
    n.title = title
    n.body = body
    n.is_read = false
    n.sent_at = DbService.now()
    // 仅作「今日已发」去重，不再作为应用内收件箱
    await NotificationService.createNotification(n)

    const request: notificationManager.NotificationRequest = {
      id: Math.abs(Utils.hashId(n.id)) % 100000 + 100,
      content: {
        notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
        normal: {
          title: title,
          text: body,
          additionalText: '向前'
        }
      }
    }
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: NotificationComposer.BUNDLE,
          abilityName: 'EntryAbility'
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      }
      request.wantAgent = await wantAgent.getWantAgent(info)
    } catch {
    }
    try {
      await notificationManager.publish(request)
    } catch {
      // 系统通知推送失败不影响去重落库
    }
  }
}
