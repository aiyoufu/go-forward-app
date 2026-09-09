import { describe, it, expect } from '@ohos/hypium'
import {
  UserSettings,
  AIChannelConfig
} from '../../../../main/ets/model/UserSettingsModel'

export default function userSettingsModelTest() {
  describe('UserSettingsModel', () => {

    describe('UserSettings', () => {
      it('默认值正确', 0, () => {
        const s = new UserSettings()
        expect(s.user_id).assertEqual('')
        expect(s.app_lock_enabled).assertFalse()
        expect(s.app_lock_hash).assertEqual('')
        expect(s.email_reminders).assertFalse()
        expect(s.remind_before_due).assertTrue()
        expect(s.remind_on_due_day).assertTrue()
        expect(s.app_lock_timeout_mins).assertEqual(5)
        expect(s.ai_text_enabled).assertFalse()
        expect(s.ai_text_key).assertEqual('')
        expect(s.ai_text_base_url).assertEqual('')
        expect(s.ai_text_model).assertEqual('')
        expect(s.ai_text_api_format).assertEqual('auto')
        expect(s.ai_vision_enabled).assertFalse()
        expect(s.key_backup_encrypted).assertEqual('')
        expect(s.recovery_backup_encrypted).assertEqual('')
        expect(s.light_sense_enabled).assertFalse()
        expect(s.eye_care_enabled).assertFalse()
        expect(s.theme_mode).assertEqual('system')
        expect(s.cloud_sync_enabled).assertTrue()
        expect(s.monthly_budget_limit).assertEqual(0)
        expect(s.pressure_alert_enabled).assertTrue()
        expect(s.share_enabled).assertTrue()
        expect(s.founding_member_no).assertEqual(0)
        expect(s.profile_nickname).assertEqual('')
        expect(s.profile_signature).assertEqual('')
        expect(s.profile_avatar_path).assertEqual('')
        expect(s.updated_at).assertEqual('')
      })
      it('可赋值', 0, () => {
        const s = new UserSettings()
        s.user_id = 'user-123'
        s.theme_mode = 'dark'
        s.eye_care_enabled = true
        s.ai_text_enabled = true
        s.ai_text_key = 'sk-test'
        expect(s.user_id).assertEqual('user-123')
        expect(s.theme_mode).assertEqual('dark')
        expect(s.eye_care_enabled).assertTrue()
        expect(s.ai_text_enabled).assertTrue()
        expect(s.ai_text_key).assertEqual('sk-test')
        s.profile_nickname = '阿豪'
        s.profile_signature = '每天进步一点点'
        s.profile_avatar_path = 'avatar_u1.jpg'
        expect(s.profile_nickname).assertEqual('阿豪')
        expect(s.profile_signature).assertEqual('每天进步一点点')
        expect(s.profile_avatar_path).assertEqual('avatar_u1.jpg')
      })
      it('theme_mode支持三种值', 0, () => {
        const s = new UserSettings()
        s.theme_mode = 'light'
        expect(s.theme_mode).assertEqual('light')
        s.theme_mode = 'dark'
        expect(s.theme_mode).assertEqual('dark')
        s.theme_mode = 'system'
        expect(s.theme_mode).assertEqual('system')
      })
      it('ai_text_api_format支持三种值', 0, () => {
        const s = new UserSettings()
        s.ai_text_api_format = 'openai'
        expect(s.ai_text_api_format).assertEqual('openai')
        s.ai_text_api_format = 'anthropic'
        expect(s.ai_text_api_format).assertEqual('anthropic')
      })
    })

    describe('AIChannelConfig', () => {
      it('默认值正确', 0, () => {
        const c = new AIChannelConfig()
        expect(c.enabled).assertFalse()
        expect(c.key).assertEqual('')
        expect(c.baseUrl).assertEqual('')
        expect(c.model).assertEqual('')
        expect(c.apiFormat).assertEqual('auto')
      })
      it('可赋值', 0, () => {
        const c = new AIChannelConfig()
        c.enabled = true
        c.key = 'sk-123'
        c.baseUrl = 'https://api.example.com'
        c.model = 'gpt-4'
        c.apiFormat = 'openai'
        expect(c.enabled).assertTrue()
        expect(c.key).assertEqual('sk-123')
        expect(c.baseUrl).assertEqual('https://api.example.com')
        expect(c.model).assertEqual('gpt-4')
        expect(c.apiFormat).assertEqual('openai')
      })
    })
  })
}
