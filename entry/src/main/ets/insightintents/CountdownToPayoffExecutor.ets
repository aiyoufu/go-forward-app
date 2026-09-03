import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { DebtService } from 'service'
import { Utils } from 'common'

export default class CountdownToPayoffExecutor extends InsightIntentExecutor {
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
      const activeDebts = all.filter(d => d.status !== 'completed')

      let furthestEndDate = ''
      let totalBalance = 0
      for (const debt of activeDebts) {
        totalBalance += debt.current_balance
        if (debt.estimated_end_date && (!furthestEndDate || debt.estimated_end_date > furthestEndDate)) {
          furthestEndDate = debt.estimated_end_date
        }
      }

      let remainingMonths = 0
      let remainingDays = 0
      if (furthestEndDate) {
        const now = new Date()
        const target = new Date(furthestEndDate)
        remainingMonths = Math.max(1, (target.getFullYear() - now.getFullYear()) * 12 + (target.getMonth() - now.getMonth()))
        remainingDays = Math.max(0, Math.floor((target.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)))
      }

      const resultParams: Record<string, Object> = {
        'activeDebtCount': activeDebts.length,
        'totalBalanceYuan': Utils.fenToYuan(totalBalance),
        'furthestEndDate': furthestEndDate,
        'remainingMonths': remainingMonths,
        'remainingDays': remainingDays
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('CountdownToPayoffExecutor', 'loadContent failed: ' + JSON.stringify(err))
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
