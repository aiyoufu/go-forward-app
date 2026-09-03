import { describe, it, expect } from '@ohos/hypium'
import { Constants, ColorTokens } from '../../../main/ets/common/Constants'

export default function constantsTest() {
  describe('Constants', () => {

    describe('Constants_DatabaseConstants', () => {
      it('DB_NAME值正确', 0, () => {
        expect(Constants.DB_NAME).assertEqual('GoForward.db')
      })
      it('DB_VERSION为1', 0, () => {
        expect(Constants.DB_VERSION).assertEqual(1)
      })
      it('PREFERENCES_NAME值正确', 0, () => {
        expect(Constants.PREFERENCES_NAME).assertEqual('GoForwardPrefs')
      })
      it('HUKS_KEY_ALIAS值正确', 0, () => {
        expect(Constants.HUKS_KEY_ALIAS).assertEqual('goforward_master_key')
      })
    })

    describe('UI常量', () => {
      it('FLOATING_TAB_CLEARANCE值正确', 0, () => {
        expect(Constants.FLOATING_TAB_CLEARANCE).assertEqual(96)
      })
    })

    describe('Constants_TableNames', () => {
      it('TABLE_LOCAL_USERS值正确', 0, () => {
        expect(Constants.TABLE_LOCAL_USERS).assertEqual('local_users')
      })
      it('TABLE_USER_SETTINGS值正确', 0, () => {
        expect(Constants.TABLE_USER_SETTINGS).assertEqual('user_settings')
      })
      it('TABLE_CREDIT_ACCOUNTS值正确', 0, () => {
        expect(Constants.TABLE_CREDIT_ACCOUNTS).assertEqual('credit_accounts')
      })
      it('TABLE_DEBTS值正确', 0, () => {
        expect(Constants.TABLE_DEBTS).assertEqual('debts')
      })
      it('TABLE_PAYMENT_RECORDS值正确', 0, () => {
        expect(Constants.TABLE_PAYMENT_RECORDS).assertEqual('payment_records')
      })
      it('TABLE_SUBSCRIPTIONS值正确', 0, () => {
        expect(Constants.TABLE_SUBSCRIPTIONS).assertEqual('subscriptions')
      })
      it('TABLE_NOTIFICATIONS值正确', 0, () => {
        expect(Constants.TABLE_NOTIFICATIONS).assertEqual('notifications')
      })
      it('TABLE_ACHIEVEMENT_CARDS值正确', 0, () => {
        expect(Constants.TABLE_ACHIEVEMENT_CARDS).assertEqual('achievement_cards')
      })
      it('TABLE_SYNC_QUEUE值正确', 0, () => {
        expect(Constants.TABLE_SYNC_QUEUE).assertEqual('sync_queue')
      })
      it('TABLE_SYNC_STATE值正确', 0, () => {
        expect(Constants.TABLE_SYNC_STATE).assertEqual('sync_state')
      })
    })

    describe('Constants_ColumnNames', () => {
      it('CLOUD_ID_COLUMN值正确', 0, () => {
        expect(Constants.CLOUD_ID_COLUMN).assertEqual('cloud_id')
      })
    })

    describe('通知权限待索取标记', () => {
      it('标记后只能取一次', 0, () => {
        Constants.takePendingNotifPrompt()
        expect(Constants.takePendingNotifPrompt()).assertFalse()
        Constants.markPendingNotifPrompt()
        expect(Constants.takePendingNotifPrompt()).assertTrue()
        expect(Constants.takePendingNotifPrompt()).assertFalse()
      })
    })

    describe('AppStorage键映射', () => {
      it('KEY_LIST_REFRESH与AppStorageKeys一致', 0, () => {
        expect(Constants.KEY_LIST_REFRESH).assertEqual('listRefreshToken')
      })
      it('KEY_THEME_REVISION与AppStorageKeys一致', 0, () => {
        expect(Constants.KEY_THEME_REVISION).assertEqual('themeRevision')
      })
    })
  })

  describe('ColorTokens', () => {
    it('PRIMARY值正确', 0, () => {
      expect(ColorTokens.PRIMARY).assertEqual('#26251E')
    })
    it('AMBER值正确', 0, () => {
      expect(ColorTokens.AMBER).assertEqual('#F59E0B')
    })
    it('RED值正确', 0, () => {
      expect(ColorTokens.RED).assertEqual('#CF2D56')
    })
    it('RED_BG包含透明度', 0, () => {
      const bg = ColorTokens.RED_BG as string
      expect(bg.indexOf('rgba') >= 0).assertTrue()
    })
    it('AMBER_BG包含透明度', 0, () => {
      const bg = ColorTokens.AMBER_BG as string
      expect(bg.indexOf('rgba') >= 0).assertTrue()
    })
    it('STATUS_BAR_CONTENT_DARK值正确', 0, () => {
      expect(ColorTokens.STATUS_BAR_CONTENT_DARK).assertEqual('#F2F1EF')
    })
    it('STATUS_BAR_CONTENT_LIGHT值正确', 0, () => {
      expect(ColorTokens.STATUS_BAR_CONTENT_LIGHT).assertEqual('#26251E')
    })
    it('DEFAULT_FALLBACK值正确', 0, () => {
      expect(ColorTokens.DEFAULT_FALLBACK).assertEqual('#858379')
    })
  })
}
