import { describe, it, expect } from '@ohos/hypium'
import { AppStorageKeys } from '../../../main/ets/common/AppStorageKeys'

export default function appStorageKeysTest() {
  describe('AppStorageKeys', () => {

    describe('AppStorageKeys_SystemWindowKeys', () => {
      it('SYSTEM_DARK值正确', 0, () => {
        expect(AppStorageKeys.SYSTEM_DARK).assertEqual('systemDark')
      })
      it('TOP_SAFE_HEIGHT值正确', 0, () => {
        expect(AppStorageKeys.TOP_SAFE_HEIGHT).assertEqual('topSafeHeight')
      })
      it('BOTTOM_SAFE_HEIGHT值正确', 0, () => {
        expect(AppStorageKeys.BOTTOM_SAFE_HEIGHT).assertEqual('bottomSafeHeight')
      })
      it('AMBIENT_LUX值正确', 0, () => {
        expect(AppStorageKeys.AMBIENT_LUX).assertEqual('ambientLux')
      })
      it('APPLIED_COLOR_MODE值正确', 0, () => {
        expect(AppStorageKeys.APPLIED_COLOR_MODE).assertEqual('appliedColorMode')
      })
    })

    describe('AppStorageKeys_NavTabKeys', () => {
      it('MAIN_TAB_INDEX值正确', 0, () => {
        expect(AppStorageKeys.MAIN_TAB_INDEX).assertEqual('mainTabIndex')
      })
    })

    describe('AppStorageKeys_ThemeRefreshKeys', () => {
      it('THEME_REVISION值正确', 0, () => {
        expect(AppStorageKeys.THEME_REVISION).assertEqual('themeRevision')
      })
      it('LIST_REFRESH_TOKEN值正确', 0, () => {
        expect(AppStorageKeys.LIST_REFRESH_TOKEN).assertEqual('listRefreshToken')
      })
    })

    describe('AppStorageKeys_SyncStatusKeys', () => {
      it('SYNC_PHASE值正确', 0, () => {
        expect(AppStorageKeys.SYNC_PHASE).assertEqual('syncPhase')
      })
      it('SYNC_REVISION值正确', 0, () => {
        expect(AppStorageKeys.SYNC_REVISION).assertEqual('syncRevision')
      })
      it('SYNC_LAST_SUCCESS_AT值正确', 0, () => {
        expect(AppStorageKeys.SYNC_LAST_SUCCESS_AT).assertEqual('syncLastSuccessAt')
      })
    })

    describe('AppStorageKeys_AppLockKeys', () => {
      it('APP_LOCK_ENABLED值正确', 0, () => {
        expect(AppStorageKeys.APP_LOCK_ENABLED).assertEqual('appLockEnabled')
      })
      it('APP_LOCK_VERIFIED值正确', 0, () => {
        expect(AppStorageKeys.APP_LOCK_VERIFIED).assertEqual('appLockVerified')
      })
      it('LAST_BACKGROUND_TIME值正确', 0, () => {
        expect(AppStorageKeys.LAST_BACKGROUND_TIME).assertEqual('lastBackgroundTime')
      })
      it('LAST_ACTIVE_TIME值正确', 0, () => {
        expect(AppStorageKeys.LAST_ACTIVE_TIME).assertEqual('lastActiveTime')
      })
      it('APP_IN_BACKGROUND值正确', 0, () => {
        expect(AppStorageKeys.APP_IN_BACKGROUND).assertEqual('appInBackground')
      })
    })

    describe('AppStorageKeys_FormSelectionKeys', () => {
      it('SELECTED_DEBT_ID值正确', 0, () => {
        expect(AppStorageKeys.SELECTED_DEBT_ID).assertEqual('selectedDebtId')
      })
      it('SELECTED_SUBSCRIPTION_ID值正确', 0, () => {
        expect(AppStorageKeys.SELECTED_SUBSCRIPTION_ID).assertEqual('selectedSubscriptionId')
      })
      it('SELECTED_CREDIT_ACCOUNT_ID值正确', 0, () => {
        expect(AppStorageKeys.SELECTED_CREDIT_ACCOUNT_ID).assertEqual('selectedCreditAccountId')
      })
    })

    describe('AppStorageKeys_NotificationSettingsSheetKeys', () => {
      it('NOTIFICATION_UNREAD_COUNT值正确', 0, () => {
        expect(AppStorageKeys.NOTIFICATION_UNREAD_COUNT).assertEqual('notificationUnreadCount')
      })
      it('SETTINGS_OPEN_AI_SHEET值正确', 0, () => {
        expect(AppStorageKeys.SETTINGS_OPEN_AI_SHEET).assertEqual('settingsOpenAISheet')
      })
    })

    describe('AI Live草稿键', () => {
      it('AI_LIVE_DEBT_DRAFT值正确', 0, () => {
        expect(AppStorageKeys.AI_LIVE_DEBT_DRAFT).assertEqual('aiLiveDebtDraft')
      })
      it('AI_LIVE_SUBSCRIPTION_DRAFT值正确', 0, () => {
        expect(AppStorageKeys.AI_LIVE_SUBSCRIPTION_DRAFT).assertEqual('aiLiveSubscriptionDraft')
      })
      it('AI_LIVE_CREDIT_ACCOUNT_DRAFT值正确', 0, () => {
        expect(AppStorageKeys.AI_LIVE_CREDIT_ACCOUNT_DRAFT).assertEqual('aiLiveCreditAccountDraft')
      })
    })

    describe('AppStorageKeys_IntentNFCKeys', () => {
      it('INTENT_ADD_DEBT值正确', 0, () => {
        expect(AppStorageKeys.INTENT_ADD_DEBT).assertEqual('intentAddDebt')
      })
      it('INTENT_OPEN_AI_LIVE值正确', 0, () => {
        expect(AppStorageKeys.INTENT_OPEN_AI_LIVE).assertEqual('intentOpenAILive')
      })
      it('NFC_RECEIVED_PAYLOAD值正确', 0, () => {
        expect(AppStorageKeys.NFC_RECEIVED_PAYLOAD).assertEqual('nfcReceivedPayload')
      })
    })

    describe('AI Live浮层触发键', () => {
      it('SHOW_AI_LIVE值正确', 0, () => {
        expect(AppStorageKeys.SHOW_AI_LIVE).assertEqual('showAILive')
      })
      it('AI_LIVE_LAUNCH_MODE值正确', 0, () => {
        expect(AppStorageKeys.AI_LIVE_LAUNCH_MODE).assertEqual('aiLiveLaunchMode')
      })
    })

    describe('全部还清仪式键', () => {
      it('SHOW_ALL_CLEARED_CEREMONY值正确', 0, () => {
        expect(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY).assertEqual('showAllClearedCeremony')
      })
      it('ALL_CLEARED_SETTLED_COUNT值正确', 0, () => {
        expect(AppStorageKeys.ALL_CLEARED_SETTLED_COUNT).assertEqual('allClearedSettledCount')
      })
    })

    describe('AppStorageKeys_AllStringType', () => {
      it('类型验证', 0, () => {
        const keys: string[] = [
          AppStorageKeys.SYSTEM_DARK,
          AppStorageKeys.APPLIED_COLOR_MODE,
          AppStorageKeys.TOP_SAFE_HEIGHT,
          AppStorageKeys.MAIN_TAB_INDEX,
          AppStorageKeys.THEME_REVISION,
          AppStorageKeys.LIST_REFRESH_TOKEN,
          AppStorageKeys.APP_LOCK_ENABLED,
          AppStorageKeys.SELECTED_DEBT_ID,
          AppStorageKeys.AI_LIVE_DEBT_DRAFT,
          AppStorageKeys.INTENT_ADD_DEBT,
          AppStorageKeys.SHOW_AI_LIVE,
          AppStorageKeys.AI_LIVE_LAUNCH_MODE,
          AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY,
          AppStorageKeys.ALL_CLEARED_SETTLED_COUNT,
        ]
        for (const key of keys) {
          expect(typeof key).assertEqual('string')
          expect(key.length > 0).assertTrue()
        }
      })
    })
  })
}
