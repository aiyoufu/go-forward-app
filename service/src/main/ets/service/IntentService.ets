import { Want } from '@kit.AbilityKit'
import { tag } from '@kit.ConnectivityKit'
import { Logger } from 'common'
import { AppStorageKeys } from 'common'
import { NFCSharePayload, NFCShareService } from './platform/NFCShareService'

export class IntentService {
  static handleWant(want: Want): void {
    // 桌面卡片 postCardAction 参数：openTab / widgetAction / fromWidget
    const params = want.parameters
    if (params !== undefined) {
      const openTabRaw = params['openTab']
      let openTab = -1
      if (typeof openTabRaw === 'number') {
        openTab = openTabRaw
      } else if (typeof openTabRaw === 'string') {
        openTab = parseInt(openTabRaw, 10)
      }
      if (!isNaN(openTab) && openTab >= 0 && openTab <= 4) {
        AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, openTab)
      }
      const widgetAction = params['widgetAction']
      if (typeof widgetAction === 'string' && widgetAction === 'repay') {
        AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 1)
      }
    }

    const action = want.action
    if (action === 'goforward.add.debt') {
      AppStorage.setOrCreate(AppStorageKeys.INTENT_ADD_DEBT, true)
    } else if (action === 'goforward.today.due') {
      AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 1)
    } else if (action === 'goforward.open.ai.live') {
      // 调试/深链：拉起并打开 AI 录入（不依赖小艺意图匹配）
      let mode = 'keyboard'
      if (params !== undefined) {
        const m = params['mode']
        if (typeof m === 'string' && (m === 'camera' || m === 'album' || m === 'keyboard')) {
          mode = m
        }
      }
      AppStorage.setOrCreate(AppStorageKeys.AI_LIVE_LAUNCH_MODE, mode)
      AppStorage.setOrCreate(AppStorageKeys.SHOW_AI_LIVE, true)
      AppStorage.setOrCreate(AppStorageKeys.INTENT_OPEN_AI_LIVE, true)
    } else if (action === 'ohos.nfc.tag.action.TAG_FOUND') {
      IntentService.handleNFCWant(want)
    }
  }

  private static handleNFCWant(want: Want): void {
    if (canIUse('SystemCapability.Communication.NFC.Tag')) {
      let tagInfo: tag.TagInfo | null = null
      try {
        tagInfo = tag.getTagInfo(want)
      } catch (err) {
        Logger.error('IntentService', 'NFC getTagInfo error: ' + JSON.stringify(err))
        return
      }
      if (!tagInfo) return

      let ndefTag: tag.NdefTag | null = null
      try {
        ndefTag = tag.getNdef(tagInfo)
      } catch (err) {
        Logger.error('IntentService', 'NFC getNdef error: ' + JSON.stringify(err))
        return
      }
      if (!ndefTag) return

      try {
        const message = ndefTag.getNdefMessage()
        const records = message.getNdefRecords()
        for (const record of records) {
          if (record.tnf === 2 && record.payload) {
            const text = NFCShareService.numberArrayToString(record.payload)
            const payload = NFCShareService.parsePayload(text)
            if (payload) {
              AppStorage.setOrCreate(AppStorageKeys.NFC_RECEIVED_PAYLOAD, payload)
              return
            }
          }
        }
      } catch (err) {
        Logger.error('IntentService', 'NFC read error: ' + JSON.stringify(err))
      }
    } else {
      Logger.info('IntentService', 'NFC tag unsupported on this device')
    }
  }
}
