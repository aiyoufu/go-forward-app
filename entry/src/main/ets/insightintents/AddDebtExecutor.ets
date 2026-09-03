import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { DebtService } from 'service'
import { Utils } from 'common'

export default class AddDebtExecutor extends InsightIntentExecutor {
  async onExecuteInUIAbilityForegroundMode(intentName: string, params: Record<string, Object>,
    windowStage: window.WindowStage): Promise<insightIntent.ExecuteResult> {
    try {
      // 冷启动生命周期保证 onWindowStageCreate 先于本回调，故主窗必定已就绪
      const context = windowStage.getMainWindowSync().getUIContext().getHostContext() as Context
      await DbService.init(context)
      await PreferencesService.init(context)
      await E2EEService.initialize()
      await UserService.ensureDefaultUser()

      const record = params as Record<string, string | number>
      const platform = (record['platform'] as string) ?? '未知平台'
      const principalYuan = Number(record['principal'] ?? 0)
      const monthlyYuan = Number(record['monthly_payment'] ?? 0)
      const totalPeriods = Number(record['total_periods'] ?? 12)
      const paymentDay = Number(record['payment_day'] ?? 1)
      const nextDate = (record['next_payment_date'] as string) ?? Utils.todayString()

      const debt = await DebtService.createDebt({
        platform: platform,
        debt_type: 'loan',
        principal: principalYuan,
        current_balance: Utils.yuanToFen(principalYuan),
        monthly_payment: monthlyYuan,
        total_periods: totalPeriods,
        remaining_periods: totalPeriods,
        repayment_method: 'equal_payment',
        total_interest: 0,
        annual_rate_bp: 0,
        payment_day: paymentDay,
        next_payment_date: nextDate,
        start_date: Utils.todayString(),
        is_auto_payment: false,
        note: '来自小艺意图',
        credit_account_id: '',
        icon_url: '',
        currency: 'CNY',
        original_principal_fen: Utils.yuanToFen(principalYuan),
        locked_exchange_rate: 1.0
      })

      const resultParams: Record<string, Object> = {
        'debtId': debt.id,
        'platform': platform,
        'principalYuan': principalYuan
      }

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('AddDebtExecutor', 'loadContent failed: ' + JSON.stringify(err))
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
