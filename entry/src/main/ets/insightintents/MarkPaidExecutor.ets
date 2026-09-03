import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { DebtService } from 'service'

export default class MarkPaidExecutor extends InsightIntentExecutor {
  async onExecuteInUIAbilityForegroundMode(intentName: string, params: Record<string, Object>,
    windowStage: window.WindowStage): Promise<insightIntent.ExecuteResult> {
    try {
      // 冷启动生命周期保证 onWindowStageCreate 先于本回调，故主窗必定已就绪
      const context = windowStage.getMainWindowSync().getUIContext().getHostContext() as Context
      await DbService.init(context)
      await PreferencesService.init(context)
      await E2EEService.initialize()
      await UserService.ensureDefaultUser()

      const record = params as Record<string, string>
      const platform = record['platform'] ?? ''
      let debtId = record['debt_id'] ?? ''

      if (debtId.length === 0 && platform.length > 0) {
        const debts = await DebtService.getDebts(UserService.getCurrentUserId())
        for (const debt of debts) {
          if (debt.platform.includes(platform)) {
            debtId = debt.id
            break
          }
        }
      }

      let success = false
      if (debtId.length > 0) {
        await DebtService.updateDebtStatus(debtId, 'completed')
        success = true
      }

      const resultParams: Record<string, Object> = {
        'success': success,
        'debtId': debtId
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('MarkPaidExecutor', 'loadContent failed: ' + JSON.stringify(err))
        }
      })

      const result: insightIntent.ExecuteResult = {
        code: success ? 0 : -1,
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
