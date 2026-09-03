import { relationalStore } from '@kit.ArkData'
import { DbService } from './DbService'
import { UserSettings, AiApiFormat } from 'common'
import { ThemeMode } from 'common'
import { E2EEService } from './auth/E2EEService'
import { CryptoService } from './auth/CryptoService'
import { UserService } from './UserService'
import { Constants } from 'common'
import { SyncOutbox } from './sync/SyncOutbox'
import { SettingsAiBackup } from './SettingsAiBackup'

export class SettingsService {
  /** 进程内缓存：主题/锁/AI 配置高频读，避免冷启动与切 Tab 反复扫 user_settings */
  private static cache: UserSettings | null = null
  private static cacheUserId: string = ''

  static clearCache(): void {
    SettingsService.cache = null
    SettingsService.cacheUserId = ''
  }

  /** 同步窥视缓存（Main 首帧主题零 await） */
  static peekCache(userId: string): UserSettings | null {
    if (SettingsService.cache !== null && SettingsService.cacheUserId === userId) {
      return SettingsService.cache
    }
    return null
  }

  static async getSettings(userId: string): Promise<UserSettings> {
    if (SettingsService.cache !== null && SettingsService.cacheUserId === userId) {
      return SettingsService.cloneSettings(SettingsService.cache)
    }
    const rs = await DbService.query(
      'SELECT * FROM user_settings WHERE user_id = ?',
      [userId]
    )
    let hasRow = false
    try {
      hasRow = rs.goToFirstRow()
    } catch (_e) {
    }
    if (!hasRow) {
      try {
        rs.close()
      } catch (_e2) {
      }
      const def = SettingsService.createDefaultSettings(userId)
      try {
        const snap = await SettingsAiBackup.read(userId)
        SettingsAiBackup.hydrate(def, snap)
      } catch (_e) {
      }
      SettingsAiBackup.repairEnabled(def)
      SettingsService.cache = def
      SettingsService.cacheUserId = userId
      return SettingsService.cloneSettings(def)
    }
    const row = SettingsService.rowToObject(rs)
    try {
      rs.close()
    } catch (_e3) {
    }
    const decrypted = await E2EEService.decryptRecord(Constants.TABLE_USER_SETTINGS, row)
    const settings = SettingsService.objectToSettings(decrypted)
    try {
      const snap = await SettingsAiBackup.read(userId)
      SettingsAiBackup.hydrate(settings, snap)
    } catch (_e) {
    }
    SettingsAiBackup.repairEnabled(settings)
    SettingsService.cache = settings
    SettingsService.cacheUserId = userId
    return SettingsService.cloneSettings(settings)
  }

  static async saveSettings(settings: UserSettings): Promise<void> {
    const userId = settings.user_id.length > 0 ? settings.user_id : UserService.getCurrentUserId()
    settings.user_id = userId
    settings.updated_at = DbService.now()

    // 先写旁路快照：RDB 整行更新若因缺列失败，重启仍能恢复 AI 配置
    try {
      await SettingsAiBackup.write(settings)
    } catch (_bak) {
    }

    const row = SettingsService.settingsToObject(settings)
    const encrypted = await E2EEService.encryptRecord(Constants.TABLE_USER_SETTINGS, row)
    const values = SettingsService.objectToMap(encrypted)

    // getSettings 在无行时也会返回带 user_id 的默认对象，不能用它判断是否已落库
    const rs = await DbService.query('SELECT user_id FROM user_settings WHERE user_id = ?', [userId])
    let exists = false
    try {
      exists = rs.goToFirstRow()
    } catch (_e) {
    }
    try {
      rs.close()
    } catch (_e2) {
    }

    try {
      if (exists) {
        await DbService.update('user_settings', values, 'user_id = ?', [userId])
      } else {
        await DbService.insert('user_settings', values)
      }
    } catch (_rdb) {
      try {
        await SettingsService.saveAiColumnsOnly(userId, settings)
      } catch (_ai) {
      }
    }
    SettingsService.cache = SettingsService.cloneSettings(settings)
    SettingsService.cacheUserId = userId
    try {
      await SyncOutbox.enqueueUpsert(Constants.TABLE_USER_SETTINGS, userId, userId)
    } catch {
    }
  }

  static async setAppLock(pin: string, timeoutMins: number): Promise<void> {
    const salt = CryptoService.randomBytes(16)
    const hash = await CryptoService.hashPin(pin, salt)
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.app_lock_enabled = true
    settings.app_lock_hash = hash
    settings.app_lock_timeout_mins = timeoutMins
    await SettingsService.saveSettings(settings)
  }

  static async verifyAppLock(pin: string): Promise<boolean> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    if (!settings.app_lock_enabled || settings.app_lock_hash.length === 0) {
      return true
    }
    const ok = await CryptoService.verifyPin(pin, settings.app_lock_hash)
    // 存量旧式单轮 SHA256 哈希：校验通过后静默升级为 PBKDF2 重新落库
    if (ok && CryptoService.isLegacyHash(settings.app_lock_hash)) {
      try {
        const salt = CryptoService.randomBytes(16)
        settings.app_lock_hash = await CryptoService.hashPin(pin, salt)
        await SettingsService.saveSettings(settings)
      } catch {
        // 升级失败不影响本次解锁，下次再试
      }
    }
    return ok
  }

  static async removeAppLock(): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.app_lock_enabled = false
    settings.app_lock_hash = ''
    await SettingsService.saveSettings(settings)
  }

  static async updateLightSense(enabled: boolean): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.light_sense_enabled = enabled
    await SettingsService.saveSettings(settings)
  }

  static async updateEyeCare(enabled: boolean): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.eye_care_enabled = enabled
    await SettingsService.saveSettings(settings)
  }

  static async updateThemeMode(mode: ThemeMode): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.theme_mode = mode
    await SettingsService.saveSettings(settings)
  }

  static async updateCloudSync(enabled: boolean): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.cloud_sync_enabled = enabled
    await SettingsService.saveSettings(settings)
  }

  /**
   * 设置创始会员编号（供未来会员/支付系统按购买顺序分配后回写）。
   * @param no 创始序号，0 表示未分配
   */
  static async setFoundingMemberNo(no: number): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    settings.founding_member_no = no > 0 ? Math.floor(no) : 0
    await SettingsService.saveSettings(settings)
  }

  /** 只写 AI 列，避免整行 UPDATE 因缺列失败把配置留在缓存里 */
  private static async saveAiColumnsOnly(userId: string, settings: UserSettings): Promise<void> {
    await DbService.ensureUserSettingsAiColumns()
    const values = new Map<string, string | number | boolean>()
    values.set('ai_text_enabled', DbService.boolToInt(settings.ai_text_enabled))
    values.set('ai_text_key', settings.ai_text_key)
    values.set('ai_text_base_url', settings.ai_text_base_url)
    values.set('ai_text_model', settings.ai_text_model)
    values.set('ai_text_api_format', settings.ai_text_api_format)
    values.set('ai_text_test_fp', settings.ai_text_test_fp)
    values.set('ai_vision_enabled', DbService.boolToInt(settings.ai_vision_enabled))
    values.set('ai_vision_key', settings.ai_vision_key)
    values.set('ai_vision_base_url', settings.ai_vision_base_url)
    values.set('ai_vision_model', settings.ai_vision_model)
    values.set('ai_vision_api_format', settings.ai_vision_api_format)
    values.set('ai_vision_test_fp', settings.ai_vision_test_fp)
    values.set('updated_at', settings.updated_at)
    try {
      await DbService.update('user_settings', values, 'user_id = ?', [userId])
    } catch (_u) {
      values.set('user_id', userId)
      await DbService.insert('user_settings', values)
    }
  }

  static cloneSettings(src: UserSettings): UserSettings {
    const s = new UserSettings()
    s.user_id = src.user_id
    s.app_lock_enabled = src.app_lock_enabled
    s.app_lock_hash = src.app_lock_hash
    s.email_reminders = src.email_reminders
    s.remind_before_due = src.remind_before_due
    s.remind_on_due_day = src.remind_on_due_day
    s.app_lock_timeout_mins = src.app_lock_timeout_mins
    s.ai_text_enabled = src.ai_text_enabled
    s.ai_text_key = src.ai_text_key
    s.ai_text_base_url = src.ai_text_base_url
    s.ai_text_model = src.ai_text_model
    s.ai_text_api_format = src.ai_text_api_format
    s.ai_text_test_fp = src.ai_text_test_fp
    s.ai_vision_enabled = src.ai_vision_enabled
    s.ai_vision_key = src.ai_vision_key
    s.ai_vision_base_url = src.ai_vision_base_url
    s.ai_vision_model = src.ai_vision_model
    s.ai_vision_api_format = src.ai_vision_api_format
    s.ai_vision_test_fp = src.ai_vision_test_fp
    s.key_backup_encrypted = src.key_backup_encrypted
    s.recovery_backup_encrypted = src.recovery_backup_encrypted
    s.light_sense_enabled = src.light_sense_enabled
    s.eye_care_enabled = src.eye_care_enabled
    s.theme_mode = src.theme_mode
    s.cloud_sync_enabled = src.cloud_sync_enabled
    s.monthly_budget_limit = src.monthly_budget_limit
    s.pressure_alert_enabled = src.pressure_alert_enabled
    s.founding_member_no = src.founding_member_no
    s.profile_nickname = src.profile_nickname
    s.profile_signature = src.profile_signature
    s.profile_avatar_path = src.profile_avatar_path
    s.updated_at = src.updated_at
    return s
  }

  private static createDefaultSettings(userId: string): UserSettings {
    const s = new UserSettings()
    s.user_id = userId
    s.app_lock_timeout_mins = 5
    s.light_sense_enabled = false
    s.theme_mode = 'system'
    s.cloud_sync_enabled = true
    s.remind_before_due = true
    s.remind_on_due_day = true
    s.updated_at = DbService.now()
    return s
  }

  private static toApiFormat(value: string | number | boolean | undefined): AiApiFormat {
    const v = '' + (value ?? 'auto')
    if (v === 'openai' || v === 'anthropic') {
      return v
    }
    return 'auto'
  }

  private static rowToObject(rs: relationalStore.ResultSet): Record<string, string | number | boolean> {
    const row: Record<string, string | number | boolean> = {}
    try {
      const columns = rs.columnNames
      for (const col of columns) {
        try {
          row[col] = rs.getString(rs.getColumnIndex(col))
        } catch (_e) {
        }
      }
    } catch (_e2) {
    }
    return row
  }

  private static objectToSettings(obj: object): UserSettings {
    const s = new UserSettings()
    const src = obj as Record<string, string | number | boolean | undefined>
    s.user_id = '' + (src['user_id'] ?? '')
    s.app_lock_enabled = DbService.intToBool(src['app_lock_enabled'] as number)
    s.app_lock_hash = '' + (src['app_lock_hash'] ?? '')
    s.email_reminders = DbService.intToBool(src['email_reminders'] as number)
    s.remind_before_due = DbService.intToBool(src['remind_before_due'] as number)
    s.remind_on_due_day = DbService.intToBool(src['remind_on_due_day'] as number)
    s.app_lock_timeout_mins = src['app_lock_timeout_mins'] as number ?? 5
    s.ai_text_enabled = DbService.intToBool(src['ai_text_enabled'] as number)
    s.ai_text_key = '' + (src['ai_text_key'] ?? '')
    s.ai_text_base_url = '' + (src['ai_text_base_url'] ?? '')
    s.ai_text_model = '' + (src['ai_text_model'] ?? '')
    s.ai_text_api_format = SettingsService.toApiFormat(src['ai_text_api_format'])
    s.ai_text_test_fp = '' + (src['ai_text_test_fp'] ?? '')
    s.ai_vision_enabled = DbService.intToBool(src['ai_vision_enabled'] as number)
    s.ai_vision_key = '' + (src['ai_vision_key'] ?? '')
    s.ai_vision_base_url = '' + (src['ai_vision_base_url'] ?? '')
    s.ai_vision_model = '' + (src['ai_vision_model'] ?? '')
    s.ai_vision_api_format = SettingsService.toApiFormat(src['ai_vision_api_format'])
    s.ai_vision_test_fp = '' + (src['ai_vision_test_fp'] ?? '')
    s.key_backup_encrypted = '' + (src['key_backup_encrypted'] ?? '')
    s.recovery_backup_encrypted = '' + (src['recovery_backup_encrypted'] ?? '')
    // 默认关：与 createDefaultSettings 一致；勿用 ?? 1，否则缺列/脏数据会强制开光感并盖掉「深色」偏好
    s.light_sense_enabled = DbService.intToBool(src['light_sense_enabled'] as number ?? 0)
    s.eye_care_enabled = DbService.intToBool(src['eye_care_enabled'] as number)
    const mode = '' + (src['theme_mode'] ?? 'system')
    s.theme_mode = (mode === 'light' || mode === 'dark' || mode === 'system') ? mode : 'system'
    s.cloud_sync_enabled = DbService.intToBool(src['cloud_sync_enabled'] as number ?? 1)
    s.monthly_budget_limit = Number(src['monthly_budget_limit']) || 0
    s.pressure_alert_enabled = DbService.intToBool(src['pressure_alert_enabled'] as number ?? 1)
    s.founding_member_no = Number(src['founding_member_no']) || 0
    s.profile_nickname = '' + (src['profile_nickname'] ?? '')
    s.profile_signature = '' + (src['profile_signature'] ?? '')
    s.profile_avatar_path = '' + (src['profile_avatar_path'] ?? '')
    s.updated_at = '' + (src['updated_at'] ?? '')
    return s
  }

  private static settingsToObject(settings: UserSettings): Record<string, string | number | boolean> {
    const obj: Record<string, string | number | boolean> = {}
    obj['user_id'] = settings.user_id
    obj['app_lock_enabled'] = DbService.boolToInt(settings.app_lock_enabled)
    obj['app_lock_hash'] = settings.app_lock_hash
    obj['email_reminders'] = DbService.boolToInt(settings.email_reminders)
    obj['remind_before_due'] = DbService.boolToInt(settings.remind_before_due)
    obj['remind_on_due_day'] = DbService.boolToInt(settings.remind_on_due_day)
    obj['app_lock_timeout_mins'] = settings.app_lock_timeout_mins
    obj['ai_text_enabled'] = DbService.boolToInt(settings.ai_text_enabled)
    obj['ai_text_key'] = settings.ai_text_key
    obj['ai_text_base_url'] = settings.ai_text_base_url
    obj['ai_text_model'] = settings.ai_text_model
    obj['ai_text_api_format'] = settings.ai_text_api_format
    obj['ai_text_test_fp'] = settings.ai_text_test_fp
    obj['ai_vision_enabled'] = DbService.boolToInt(settings.ai_vision_enabled)
    obj['ai_vision_key'] = settings.ai_vision_key
    obj['ai_vision_base_url'] = settings.ai_vision_base_url
    obj['ai_vision_model'] = settings.ai_vision_model
    obj['ai_vision_api_format'] = settings.ai_vision_api_format
    obj['ai_vision_test_fp'] = settings.ai_vision_test_fp
    // 废弃 AI 语音 LLM 渠道字段（ai_voice_*）不落盘；系统听写走文字解析，见 docs/deprecated/ai-voice-deprecation.md
    obj['key_backup_encrypted'] = settings.key_backup_encrypted
    obj['recovery_backup_encrypted'] = settings.recovery_backup_encrypted
    obj['light_sense_enabled'] = DbService.boolToInt(settings.light_sense_enabled)
    obj['eye_care_enabled'] = DbService.boolToInt(settings.eye_care_enabled)
    obj['theme_mode'] = settings.theme_mode
    obj['cloud_sync_enabled'] = DbService.boolToInt(settings.cloud_sync_enabled)
    obj['monthly_budget_limit'] = settings.monthly_budget_limit
    obj['pressure_alert_enabled'] = DbService.boolToInt(settings.pressure_alert_enabled)
    obj['founding_member_no'] = settings.founding_member_no
    obj['profile_nickname'] = settings.profile_nickname
    obj['profile_signature'] = settings.profile_signature
    obj['profile_avatar_path'] = settings.profile_avatar_path
    obj['updated_at'] = settings.updated_at
    return obj
  }

  private static objectToMap(obj: object): Map<string, string | number | boolean> {
    const map = new Map<string, string | number | boolean>()
    const src = obj as Record<string, string | number | boolean | undefined>
    const keys = Object.keys(src)
    for (const key of keys) {
      const v = src[key]
      if (v !== undefined) {
        map.set(key, v)
      }
    }
    return map
  }
}
