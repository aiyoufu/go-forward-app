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

export default class QueryPressureExecutor extends InsightIntentExecutor {
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
      const monthlyPressures = CalculationService.calculateMonthlyPressure(debts, subscriptions, 3)
      
      let thisMonthPressureYuan: number = 0
      let nextMonthPressureYuan: number = 0
      let pressureTrend: string = 'stable'
      
      if (monthlyPressures.length > 0) {
        thisMonthPressureYuan = Utils.fenToYuan(monthlyPressures[0].amount)
      }
      if (monthlyPressures.length > 1) {
        nextMonthPressureYuan = Utils.fenToYuan(monthlyPressures[1].amount)
        const diff = monthlyPressures[1].amount - monthlyPressures[0].amount
        if (diff > 0) {
          pressureTrend = 'increasing'
        } else if (diff < 0) {
          pressureTrend = 'decreasing'
        }
      }

      const todayStr = Utils.todayString()
      const futureDateStr = Utils.addDays(todayStr, 7)
      const upcomingDebts = await DebtService.getActiveDebtsDueBeforeOrOn(futureDateStr, userId)
      const upcomingDueCount = upcomingDebts.length
      let upcomingDueAmountFen = 0
      for (const debt of upcomingDebts) {
        upcomingDueAmountFen += debt.monthly_payment
      }

      const resultParams: Record<string, Object> = {
        'thisMonthPressureYuan': thisMonthPressureYuan,
        'nextMonthPressureYuan': nextMonthPressureYuan,
        'pressureTrend': pressureTrend,
        'upcomingDueCount': upcomingDueCount,
        'upcomingDueAmountYuan': Utils.fenToYuan(upcomingDueAmountFen)
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('QueryPressureExecutor', 'loadContent failed: ' + JSON.stringify(err))
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
