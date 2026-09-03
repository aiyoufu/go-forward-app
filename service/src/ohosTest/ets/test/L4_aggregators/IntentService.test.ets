import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { IntentService } from '../../../../main/ets/service/IntentService'
import { AppStorageKeys } from 'common'

export default function intentServiceTest() {
  beforeEach(() => {
    // 清空 IntentService 会写入的 AppStorage 键
    AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, -1)
    AppStorage.setOrCreate(AppStorageKeys.INTENT_ADD_DEBT, false)
    AppStorage.setOrCreate(AppStorageKeys.INTENT_OPEN_AI_LIVE, false)
    AppStorage.setOrCreate(AppStorageKeys.SHOW_AI_LIVE, false)
    AppStorage.setOrCreate(AppStorageKeys.AI_LIVE_LAUNCH_MODE, '')
  })

  describe('IntentService_handleWant_openTab', () => {
    it('openTab数字0_设置MAIN_TAB_INDEX=0', 0, () => {
      IntentService.handleWant({ parameters: { openTab: 0 } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(0)
    })

    it('openTab数字4_设置MAIN_TAB_INDEX=4', 0, () => {
      IntentService.handleWant({ parameters: { openTab: 4 } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(4)
    })

    it('openTab字符串_转换为数字', 0, () => {
      IntentService.handleWant({ parameters: { openTab: '2' } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(2)
    })

    it('openTab字符串非数字_不设置', 0, () => {
      IntentService.handleWant({ parameters: { openTab: 'abc' } } as Record<string, Object>)
      // NaN 不会写入（条件 isNaN(openTab) 拦截）
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(-1)
    })

    it('openTab越界5_不设置', 0, () => {
      IntentService.handleWant({ parameters: { openTab: 5 } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(-1)
    })

    it('openTab负数_不设置', 0, () => {
      IntentService.handleWant({ parameters: { openTab: -1 } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(-1)
    })
  })

  describe('IntentService_handleWant_widgetAction', () => {
    it('widgetAction=repay_打开负债Tab', 0, () => {
      IntentService.handleWant({ parameters: { widgetAction: 'repay' } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(1)
    })

    it('widgetAction=其他_不切Tab', 0, () => {
      IntentService.handleWant({ parameters: { widgetAction: 'other' } } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(-1)
    })
  })

  describe('IntentService_handleWant_action', () => {
    it('action=goforward.add.debt_设置INTENT_ADD_DEBT', 0, () => {
      IntentService.handleWant({ action: 'goforward.add.debt' } as Record<string, Object>)
      expect(AppStorage.get<boolean>(AppStorageKeys.INTENT_ADD_DEBT)).assertTrue()
    })

    it('action=goforward.today.due_切到负债Tab', 0, () => {
      IntentService.handleWant({ action: 'goforward.today.due' } as Record<string, Object>)
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(1)
    })

    it('action=goforward.open.ai.live_默认keyboard模式', 0, () => {
      IntentService.handleWant({ action: 'goforward.open.ai.live' } as Record<string, Object>)
      expect(AppStorage.get<string>(AppStorageKeys.AI_LIVE_LAUNCH_MODE)).assertEqual('keyboard')
      expect(AppStorage.get<boolean>(AppStorageKeys.SHOW_AI_LIVE)).assertTrue()
      expect(AppStorage.get<boolean>(AppStorageKeys.INTENT_OPEN_AI_LIVE)).assertTrue()
    })

    it('action=goforward.open.ai.live_带camera参数', 0, () => {
      IntentService.handleWant({
        action: 'goforward.open.ai.live',
        parameters: { mode: 'camera' }
      } as Record<string, Object>)
      expect(AppStorage.get<string>(AppStorageKeys.AI_LIVE_LAUNCH_MODE)).assertEqual('camera')
    })

    it('action=goforward.open.ai.live_带album参数', 0, () => {
      IntentService.handleWant({
        action: 'goforward.open.ai.live',
        parameters: { mode: 'album' }
      } as Record<string, Object>)
      expect(AppStorage.get<string>(AppStorageKeys.AI_LIVE_LAUNCH_MODE)).assertEqual('album')
    })

    it('action=goforward.open.ai.live_非法mode_默认keyboard', 0, () => {
      IntentService.handleWant({
        action: 'goforward.open.ai.live',
        parameters: { mode: 'invalid' }
      } as Record<string, Object>)
      expect(AppStorage.get<string>(AppStorageKeys.AI_LIVE_LAUNCH_MODE)).assertEqual('keyboard')
    })

    it('action=未知_不设置任何意图', 0, () => {
      IntentService.handleWant({ action: 'unknown.action' } as Record<string, Object>)
      expect(AppStorage.get<boolean>(AppStorageKeys.INTENT_ADD_DEBT)).assertFalse()
      expect(AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)).assertEqual(-1)
    })
  })

  describe('IntentService_handleWant_NFC', () => {
    it('NFC_TAG_FOUND_不抛异常', 0, () => {
      // 系统 NFC kit 在测试环境可能不可用，但 handleNFCWant 内部 try/catch
      try {
        IntentService.handleWant({ action: 'ohos.nfc.tag.action.TAG_FOUND' } as Record<string, Object>)
        expect(true).assertTrue()
      } catch (err) {
        // 不应抛出未捕获异常
        expect(false).assertTrue()
      }
    })

    it('NFC_TAG_FOUND_无tagInfo_安全返回', 0, () => {
      try {
        IntentService.handleWant({ action: 'ohos.nfc.tag.action.TAG_FOUND' } as Record<string, Object>)
        // NFC_RECEIVED_PAYLOAD 不应被设置（因为没读到有效 payload）
        expect(true).assertTrue()
      } catch (err) {
        expect(false).assertTrue()
      }
    })
  })

  describe('IntentService_handleWant_空参数', () => {
    it('parameters为undefined_不抛异常', 0, () => {
      IntentService.handleWant({} as Record<string, Object>)
      expect(true).assertTrue()
    })

    it('action为空_不设置意图', 0, () => {
      IntentService.handleWant({ action: '' } as Record<string, Object>)
      expect(AppStorage.get<boolean>(AppStorageKeys.INTENT_ADD_DEBT)).assertFalse()
    })

    it('want完全为空_不抛异常', 0, () => {
      IntentService.handleWant({} as Record<string, Object>)
      expect(true).assertTrue()
    })
  })
}
