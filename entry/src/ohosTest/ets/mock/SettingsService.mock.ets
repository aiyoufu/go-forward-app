// SettingsService.mock.ets — entry 模块测试用
let presetSettings: Object = {
  app_lock_enabled: false,
  app_lock_timeout_mins: 5,
  theme_mode: 'system'
}

export class SettingsService {
  static async getSettings(userId: string): Promise<Object> {
    return presetSettings
  }

  static _setPresetSettings(settings: Object): void {
    presetSettings = settings
  }

  static _reset(): void {
    presetSettings = { app_lock_enabled: false, app_lock_timeout_mins: 5, theme_mode: 'system' }
  }
}
