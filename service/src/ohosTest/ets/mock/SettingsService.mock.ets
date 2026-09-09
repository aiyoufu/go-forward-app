// SettingsService.mock.ets
// Mock preset: 预设设置对象

let presetSettings: Object = {}

export class SettingsService {
  static async getSettings(userId: string): Promise<Object> {
    return presetSettings
  }

  static async saveSettings(settings: Object): Promise<void> {
    presetSettings = settings
  }

  static async setAppLock(pin: string, timeoutMins: number): Promise<void> {
    // 空操作
  }

  static async verifyAppLock(pin: string): Promise<boolean> {
    return true
  }

  static async removeAppLock(): Promise<void> {
    // 空操作
  }

  static async updateLightSense(enabled: boolean): Promise<void> {
    // 空操作
  }

  static async updateEyeCare(enabled: boolean): Promise<void> {
    // 空操作
  }

  static async updateThemeMode(mode: string): Promise<void> {
    // 空操作
  }

  static async updateShareEnabled(enabled: boolean): Promise<void> {
    // 空操作
  }

  static async updateCloudSync(enabled: boolean): Promise<void> {
    // 空操作
  }

  static async setFoundingMemberNo(no: number): Promise<void> {
    // 空操作
  }

  // ---- 测试辅助方法 ----

  static _setPresetSettings(settings: Object): void {
    presetSettings = settings
  }

  static _reset(): void {
    presetSettings = {}
  }
}
