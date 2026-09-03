import { liveViewManager } from '@kit.LiveViewKit'
import { wantAgent, WantAgent } from '@kit.AbilityKit'
import { Logger } from 'common'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { DebtService } from './DebtService'
import { UserService } from './UserService'
import { Utils } from 'common'
import { ColorTokens } from 'common'
import {
  LiveLockPayload,
  LIVE_LOCK_EVENT
} from './LiveLockPayload'

/**
 * 实况窗 + 锁屏沉浸关联
 * 对齐官方 bpta-lock-screen-immersive-live-window：
 * 1) startLiveView.primary.liveViewLockScreenAbilityName
 * 2) 公共事件推送更新到 LiveViewLockScreenAbility
 */
export class LiveViewService {
  private static readonly LIVE_VIEW_ID: number = 10001
  private static readonly EVENT_DEBT: string = 'DEBT_REMINDER'
  private static readonly LOCK_ABILITY: string = 'LiveViewLockScreenAbility'
  private static sequence: number = 0
  private static clickAction: WantAgent | null = null

  // 实况窗服务端强制校验 primary.clickAction 必须为 WantAgent，缺省会报 Parameter error
  private static async getClickAction(): Promise<WantAgent> {
    if (LiveViewService.clickAction === null) {
      const info: wantAgent.WantAgentInfo = {
        wants: [{
          bundleName: 'com.goforward.app',
          abilityName: 'EntryAbility'
        }],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      }
      try {
        LiveViewService.clickAction = await wantAgent.getWantAgent(info)
      } catch (err) {
        const error = err as BusinessError
        Logger.error('LiveViewService', 'getWantAgent failed: ' + error.message)
      }
    }
    return LiveViewService.clickAction as WantAgent
  }

  static async refresh(): Promise<void> {
    try {
      // 未在 AGC 开通实况窗权益 / 本机未进调测名单时为 false，系统「实况窗应用列表」也不会出现本应用
      const enabled = await liveViewManager.isLiveViewEnabled()
      if (!enabled) {
        Logger.error('LiveViewService',
          'LiveView disabled: enable Live View service in AppGallery Connect, ' +
          'add this device to test list (or get formal rights), re-sign with new Profile'
        )
        return
      }

      const userId = UserService.getCurrentUserId()
      if (userId.length === 0) {
        return
      }

      const today = Utils.todayString()
      const dueDebts = await DebtService.getActiveDebtsDueBeforeOrOn(today, userId)
      const dueToday = dueDebts.filter(d => d.next_payment_date === today)
      const overdue = dueDebts.filter(d => d.next_payment_date < today)

      const weekLater = Utils.addDays(today, 7)
      const upcomingDebts = await DebtService.getActiveDebtsDueBeforeOrOn(weekLater, userId)
      const upcoming7 = upcomingDebts.filter(d => d.next_payment_date > today)

      if (dueToday.length === 0 && overdue.length === 0 && upcoming7.length < 2) {
        await LiveViewService.stop()
        return
      }

      const totalDueToday = dueToday.reduce((sum, d) => sum + d.monthly_payment, 0)
      const totalOverdue = overdue.reduce((sum, d) => sum + d.monthly_payment, 0)
      const isOverdue = overdue.length > 0
      const isDueToday = dueToday.length > 0
      const isUpcomingPressure = !isOverdue && !isDueToday && upcoming7.length >= 2

      let title = ''
      let totalAmount = 0
      let status = 1
      if (isOverdue) {
        title = '有逾期债务'
        totalAmount = totalDueToday + totalOverdue
        status = 2
      } else if (isDueToday) {
        title = '今日有还款'
        totalAmount = totalDueToday
        status = 1
      } else {
        const upcoming7Total = upcoming7.reduce((sum, d) => sum + d.monthly_payment, 0)
        title = '本周有 ' + upcoming7.length + ' 笔还款'
        totalAmount = upcoming7Total
        status = 3
      }

      const contentLines: liveViewManager.RichText[] = []
      const displayDebts = isOverdue ? overdue.slice(0, 2)
        : isDueToday ? dueToday.slice(0, 2) : upcoming7.slice(0, 2)
      const lineTexts: string[] = []
      for (const debt of displayDebts) {
        const days = Utils.daysBetween(today, debt.next_payment_date)
        const dayLabel = isOverdue ? '逾期' + Math.abs(days) + '天'
          : (days === 0 ? '今日到期' : days + '天后到期')
        const line = debt.platform + ' · ' + Utils.formatMoney(debt.monthly_payment, false) +
          ' · ' + dayLabel
        lineTexts.push(line)
        const richText: liveViewManager.RichText = { text: line }
        contentLines.push(richText)
      }
      const totalDebts = isOverdue ? overdue.length : isDueToday ? dueToday.length : upcoming7.length
      let moreText = ''
      if (totalDebts > 2) {
        moreText = '还有 ' + (totalDebts - 2) + ' 笔待查看'
        const more: liveViewManager.RichText = { text: moreText }
        contentLines.push(more)
      }

      const progress = isOverdue ? 100 : (isDueToday ? 50 : 30)
      const color = isOverdue ? `${ColorTokens.RED}` :
        (isUpcomingPressure ? `${ColorTokens.AMBER}` : `${ColorTokens.PRIMARY}`)
      const summary = totalDebts + '笔 · ' + Utils.formatMoney(totalAmount, true)

      LiveViewService.sequence = LiveViewService.sequence + 1
      const seq = LiveViewService.sequence

      const lockPayload = new LiveLockPayload()
      lockPayload.title = title
      lockPayload.summary = summary
      lockPayload.line1 = lineTexts.length > 0 ? lineTexts[0] : ''
      lockPayload.line2 = lineTexts.length > 1 ? lineTexts[1] : ''
      lockPayload.moreText = moreText
      lockPayload.accentColor = color
      lockPayload.status = status
      lockPayload.sequence = seq

      const payloadJson = JSON.stringify(lockPayload)
      const clickAction = await LiveViewService.getClickAction()

      await liveViewManager.startLiveView({
        id: LiveViewService.LIVE_VIEW_ID,
        event: LiveViewService.EVENT_DEBT,
        sequence: seq,
        isMute: false,
        liveViewData: {
          primary: {
            title: title,
            content: contentLines,
            keepTime: 3600,
            clickAction: clickAction,
            // 官方：关联锁屏沉浸 Extension
            liveViewLockScreenAbilityName: LiveViewService.LOCK_ABILITY,
            liveViewLockScreenAbilityParameters: {
              'payload': payloadJson
            },
            layoutData: {
              layoutType: liveViewManager.LayoutType.LAYOUT_TYPE_PROGRESS,
              progress: progress,
              color: color
            }
          },
          capsule: {
            type: liveViewManager.CapsuleType.CAPSULE_TYPE_TEXT,
            status: 1,
            title: title,
            content: summary,
            backgroundColor: color
          }
        }
      })

      // 推送到已展开的锁屏沉浸页
      LiveViewService.publishLockUpdate(payloadJson)
    } catch (err) {
      const error = err as BusinessError
      Logger.error('LiveViewService', 'LiveView refresh failed: ' + error.message)
    }
  }

  static async stop(): Promise<void> {
    try {
      LiveViewService.sequence = LiveViewService.sequence + 1
      await liveViewManager.stopLiveView({
        id: LiveViewService.LIVE_VIEW_ID,
        event: LiveViewService.EVENT_DEBT,
        sequence: LiveViewService.sequence,
        liveViewData: {
          primary: {
            title: '还款提醒',
            content: []
          }
        }
      })
    } catch (err) {
      const error = err as BusinessError
      Logger.error('LiveViewService', 'LiveView stop failed: ' + error.message)
    }
  }

  private static publishLockUpdate(payloadJson: string): void {
    try {
      const options: commonEventManager.CommonEventPublishData = {
        bundleName: 'com.goforward.app',
        parameters: {
          'payload': payloadJson
        }
      }
      commonEventManager.publish(LIVE_LOCK_EVENT, options, (error: BusinessError) => {
        if (error) {
          // 锁屏未展开时订阅方不存在属正常
        }
      })
    } catch (_e) {
    }
  }
}
