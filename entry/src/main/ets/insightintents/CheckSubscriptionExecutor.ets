import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { SubscriptionService } from 'service'
import { PlatformService } from 'service'
import { Utils } from 'common'

export default class CheckSubscriptionExecutor extends InsightIntentExecutor {
  async onExecuteInUIAbilityForegroundMode(intentName: string, params: Record<string, Object>,
    windowStage: window.WindowStage): Promise<insightIntent.ExecuteResult> {
    try {
      // 冷启动生命周期保证 onWindowStageCreate 先于本回调，故主窗必定已就绪
      const context = windowStage.getMainWindowSync().getUIContext().getHostContext() as Context
      await DbService.init(context)
      await PreferencesService.init(context)
      await E2EEService.initialize()
      await UserService.ensureDefaultUser()

      const userId = UserService.getCurrentUserId()
      const subscriptions = await SubscriptionService.getSubscriptions(userId)
      const activeSubs = subscriptions.filter(s => s.status === 'active')
      const subscriptionTotal = SubscriptionService.calculateTotalSubscriptionAmount(subscriptions)

      class SubInfo {
        name: string = ''
        amountYuan: number = 0
        cycle: string = ''
      }
      const topSubs: SubInfo[] = []
      for (const s of activeSubs.slice(0, 3)) {
        const info = new SubInfo()
        info.name = s.name
        info.amountYuan = Utils.fenToYuan(s.amount)
        info.cycle = PlatformService.getBillingCycleInfo(s.billing_cycle).label
        topSubs.push(info)
      }

      const resultParams: Record<string, Object> = {
        'activeCount': activeSubs.length,
        'subscriptionTotalYuan': Utils.fenToYuan(subscriptionTotal),
        'topSubscriptions': topSubs
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('CheckSubscriptionExecutor', 'loadContent failed: ' + JSON.stringify(err))
        }
      })

      const result: insightIntent.ExecuteResult = {
        code: 0,
        result: resultParams
      }
      return Promise.resolve(result)
    } catch (err) {
      const errorParams: Record<string, Object> = { 'error': JSON.stringify(err) }
      const result: insightIntent.ExecuteResult = {
        code: -1,
        result: errorParams
      }
      return Promise.resolve(result)
    }
  }
}
