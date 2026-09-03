import { InsightIntentExecutor, insightIntent } from '@kit.AbilityKit'
import { window } from '@kit.ArkUI'
import { Logger } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { AppStorageKeys } from 'common'

/**
 * 小艺意图：打开「向前」AI 录入（AI Live）
 *
 * 使用配置文件 insight_intent.json 注册（兼容当前 SDK 编译器）。
 * 调试：DevEco 意图调试助手触发 OpenAILive，或 Want action goforward.open.ai.live。
 * 小艺口语命中还需 AGC / 小艺开放平台语料（仅本地 displayName 不够稳定）。
 */
export default class OpenAILiveExecutor extends InsightIntentExecutor {
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
      let mode = 'keyboard'
      if (record['mode'] !== undefined && record['mode'] !== null) {
        mode = `${record['mode']}`
      }
      if (mode !== 'keyboard' && mode !== 'camera' && mode !== 'album') {
        mode = 'keyboard'
      }

      AppStorage.setOrCreate(AppStorageKeys.AI_LIVE_LAUNCH_MODE, mode)
      AppStorage.setOrCreate(AppStorageKeys.SHOW_AI_LIVE, true)
      AppStorage.setOrCreate(AppStorageKeys.INTENT_OPEN_AI_LIVE, true)

      windowStage.loadContent('pages/Index', (err) => {
        if (err) {
          Logger.error('OpenAILiveExecutor', 'loadContent failed: ' + JSON.stringify(err))
        }
      })

      const resultParams: Record<string, Object> = {
        'opened': true,
        'mode': mode,
        'message': '已打开向前 AI 录入'
      }

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
