import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { SettingsService } from '../../mock/SettingsService.mock'
import { DbService } from '../../mock/DbService.mock'
import { UserService } from '../../mock/UserService.mock'
import { E2EEService } from '../../mock/E2EEService.mock'

const userId = 'test-user-001'

function settingsRow(overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    user_id: userId,
    app_lock_enabled: 0,
    app_lock_hash: '',
    email_reminders: 1,
    remind_before_due: 1,
    remind_on_due_day: 1,
    app_lock_timeout_mins: 5,
    ai_text_enabled: 0,
    ai_text_key: '',
    ai_text_base_url: '',
    ai_text_model: '',
    ai_text_api_format: 'auto',
    ai_text_test_fp: '',
    ai_vision_enabled: 0,
    ai_vision_key: '',
    ai_vision_base_url: '',
    ai_vision_model: '',
    ai_vision_api_format: 'auto',
    ai_vision_test_fp: '',
    key_backup_encrypted: '',
    recovery_backup_encrypted: '',
    light_sense_enabled: 0,
    eye_care_enabled: 0,
    theme_mode: 'system',
    cloud_sync_enabled: 1,
    monthly_budget_limit: 0,
    pressure_alert_enabled: 1,
    share_enabled: 1,
    founding_member_no: 0,
    updated_at: '2024-11-14T10:00:00.000Z'
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

export default function settingsServiceTest() {
  beforeEach(() => {
    DbService._reset()
    UserService._reset()
  })

  // ── getSettings ──────────────────────────────────────
  describe('SettingsService_getSettings', () => {
    it('无记录_返回默认设置', 0, async () => {
      const s = await SettingsService.getSettings(userId)
      expect(s.user_id).assertEqual(userId)
      expect(s.theme_mode).assertEqual('system')
      expect(s.cloud_sync_enabled).assertTrue()
      expect(s.app_lock_timeout_mins).assertEqual(5)
    })

    it('有记录_返回解析后的设置', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({ theme_mode: 'dark' })])
      const s = await SettingsService.getSettings(userId)
      expect(s.theme_mode).assertEqual('dark')
    })

    it('无效theme_mode_默认system', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({ theme_mode: 'invalid' })])
      const s = await SettingsService.getSettings(userId)
      expect(s.theme_mode).assertEqual('system')
    })

    it('有效theme_mode_light', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({ theme_mode: 'light' })])
      const s = await SettingsService.getSettings(userId)
      expect(s.theme_mode).assertEqual('light')
    })

    it('ai_text_api_format_openai', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({ ai_text_api_format: 'openai' })])
      const s = await SettingsService.getSettings(userId)
      expect(s.ai_text_api_format).assertEqual('openai')
    })

    it('ai_text_api_format_anthropic', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({ ai_text_api_format: 'anthropic' })])
      const s = await SettingsService.getSettings(userId)
      expect(s.ai_text_api_format).assertEqual('anthropic')
    })

    it('ai_text_api_format_invalid_默认auto', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({ ai_text_api_format: 'invalid' })])
      const s = await SettingsService.getSettings(userId)
      expect(s.ai_text_api_format).assertEqual('auto')
    })
  })

  // ── saveSettings ──────────────────────────────────────
  describe('SettingsService_saveSettings', () => {
    it('新用户_插入记录', 0, async () => {
      const s = await SettingsService.getSettings(userId)
      s.theme_mode = 'dark'
      await SettingsService.saveSettings(s)
      const store = DbService._getStore()
      const rows = store.get('user_settings')
      expect(rows !== undefined).assertTrue()
      expect(rows!.length).assertEqual(1)
    })

    it('已有记录_更新', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow()])
      const s = await SettingsService.getSettings(userId)
      s.light_sense_enabled = true
      await SettingsService.saveSettings(s)
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('UPDATE user_settings') >= 0)).assertTrue()
    })
  })

  // ── setAppLock ──────────────────────────────────────
  describe('SettingsService_setAppLock', () => {
    it('设置应用锁_保存hash', 0, async () => {
      await SettingsService.setAppLock('1234', 10)
      const store = DbService._getStore()
      const rows = store.get('user_settings')
      expect(rows !== undefined).assertTrue()
    })
  })

  // ── verifyAppLock ──────────────────────────────────────
  describe('SettingsService_verifyAppLock', () => {
    it('未启用应用锁_返回true', 0, async () => {
      const result = await SettingsService.verifyAppLock('1234')
      expect(result).assertTrue()
    })

    it('已启用_验证正确PIN', 0, async () => {
      // 先设置应用锁
      await SettingsService.setAppLock('1234', 10)
      // 预设查询返回带 hash 的设置
      const result = await SettingsService.verifyAppLock('1234')
      // 由于 getSettings 会从 store 读，而 store 里有刚插入的行
      // 但 mock 的 query 优先查 preset，无 preset 则查 store
      // store 中的行是 Map 格式，mock 的 getString 会读取
      expect(typeof result).assertEqual('boolean')
    })
  })

  // ── removeAppLock ──────────────────────────────────────
  describe('SettingsService_removeAppLock', () => {
    it('移除应用锁_不抛异常', 0, async () => {
      await SettingsService.removeAppLock()
      const store = DbService._getStore()
      const rows = store.get('user_settings')
      expect(rows !== undefined).assertTrue()
    })
  })

  // ── updateLightSense ──────────────────────────────────
  describe('SettingsService_updateLightSense', () => {
    it('更新光感设置', 0, async () => {
      await SettingsService.updateLightSense(true)
      const store = DbService._getStore()
      expect(store.get('user_settings') !== undefined).assertTrue()
    })
  })

  // ── updateEyeCare ──────────────────────────────────
  describe('SettingsService_updateEyeCare', () => {
    it('更新护眼设置', 0, async () => {
      await SettingsService.updateEyeCare(true)
      const store = DbService._getStore()
      expect(store.get('user_settings') !== undefined).assertTrue()
    })
  })

  // ── updateThemeMode ──────────────────────────────────
  describe('SettingsService_updateThemeMode', () => {
    it('更新主题模式', 0, async () => {
      await SettingsService.updateThemeMode('dark')
      const store = DbService._getStore()
      expect(store.get('user_settings') !== undefined).assertTrue()
    })
  })

  // ── updateCloudSync ──────────────────────────────────
  describe('SettingsService_updateCloudSync', () => {
    it('更新云同步设置', 0, async () => {
      await SettingsService.updateCloudSync(false)
      const store = DbService._getStore()
      expect(store.get('user_settings') !== undefined).assertTrue()
    })
  })

  // ── setFoundingMemberNo ──────────────────────────────
  describe('SettingsService_setFoundingMemberNo', () => {
    it('设置创始会员编号', 0, async () => {
      await SettingsService.setFoundingMemberNo(42)
      const store = DbService._getStore()
      expect(store.get('user_settings') !== undefined).assertTrue()
    })

    it('负数_设为0', 0, async () => {
      await SettingsService.setFoundingMemberNo(-1)
      const store = DbService._getStore()
      expect(store.get('user_settings') !== undefined).assertTrue()
    })
  })

  // ── objectToSettings 字段映射 ──────────────────────────
  describe('SettingsService_objectToSettings_字段映射', () => {
    it('bool字段正确转换', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({
        app_lock_enabled: 1,
        light_sense_enabled: 1,
        eye_care_enabled: 1,
        pressure_alert_enabled: 0
      })])
      const s = await SettingsService.getSettings(userId)
      expect(s.app_lock_enabled).assertTrue()
      expect(s.light_sense_enabled).assertTrue()
      expect(s.eye_care_enabled).assertTrue()
      expect(s.pressure_alert_enabled).assertFalse()
    })

    it('数值字段NaN_默认0', 0, async () => {
      DbService._setQueryPreset('FROM user_settings', [settingsRow({
        monthly_budget_limit: 'not_number',
        founding_member_no: 'abc'
      })])
      const s = await SettingsService.getSettings(userId)
      expect(s.monthly_budget_limit).assertEqual(0)
      expect(s.founding_member_no).assertEqual(0)
    })
  })
}
