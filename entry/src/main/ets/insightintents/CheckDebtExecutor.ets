import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { DebtService } from 'service'
import { Utils } from 'common'

export default class CheckDebtExecutor extends InsightIntentExecutor {
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
      const all = await DebtService.getDebts(userId)
      const today = Utils.todayString()
      let totalBalance = 0
      let todayDueCount = 0
      let todayDueAmount = 0
      let overdueCount = 0

      for (const debt of all) {
        if (debt.status !== 'completed') {
          totalBalance += debt.current_balance
          if (debt.next_payment_date === today) {
            todayDueCount += 1
            todayDueAmount += debt.monthly_payment
          }
          if (debt.next_payment_date < today) {
            overdueCount += 1
          }
        }
      }

      const resultParams: Record<string, Object> = {
        'totalBalanceYuan': Utils.fenToYuan(totalBalance),
        'todayDueCount': todayDueCount,
        'todayDueAmountYuan': Utils.fenToYuan(todayDueAmount),
        'overdueCount': overdueCount
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('CheckDebtExecutor', 'loadContent failed: ' + JSON.stringify(err))
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
