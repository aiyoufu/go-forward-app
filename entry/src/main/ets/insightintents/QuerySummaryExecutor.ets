import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { DebtService } from 'service'
import { SubscriptionService } from 'service'
import { CalculationService } from 'service'
import { Utils } from 'common'

export default class QuerySummaryExecutor extends InsightIntentExecutor {
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
      const debts = await DebtService.getDebts(userId)
      const subscriptions = await SubscriptionService.getSubscriptions(userId)
      
      let activeDebtCount = 0
      let totalBalanceFen = 0
      let estimatedPayoffDate = ''
      
      for (const debt of debts) {
        if (debt.status === 'active') {
          activeDebtCount += 1
          totalBalanceFen += debt.current_balance
          if (debt.estimated_end_date > estimatedPayoffDate) {
            estimatedPayoffDate = debt.estimated_end_date
          }
        }
      }

      let activeSubscriptionCount = 0
      for (const sub of subscriptions) {
        if (sub.status === 'active') {
          activeSubscriptionCount += 1
        }
      }

      const subscriptionTotalFen = SubscriptionService.calculateTotalSubscriptionAmount(subscriptions)
      const monthlyPressures = CalculationService.calculateMonthlyPressure(debts, subscriptions, 1)

      let thisMonthDueFen = 0
      if (monthlyPressures.length > 0) {
        thisMonthDueFen = monthlyPressures[0].debtAmount
      }

      const resultParams: Record<string, Object> = {
        'activeDebtCount': activeDebtCount,
        'totalBalanceYuan': Utils.fenToYuan(totalBalanceFen),
        'thisMonthDueYuan': Utils.fenToYuan(thisMonthDueFen),
        'activeSubscriptionCount': activeSubscriptionCount,
        'subscriptionTotalYuan': Utils.fenToYuan(subscriptionTotalFen),
        'estimatedPayoffDate': estimatedPayoffDate
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('QuerySummaryExecutor', 'loadContent failed: ' + JSON.stringify(err))
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
