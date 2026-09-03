import { preferences } from '@kit.ArkData'
import { Constants } from 'common'

export class PreferencesService {
  private static pref: preferences.Preferences | null = null
  private static dirty: boolean = false

  static async init(context: Context): Promise<void> {
    if (PreferencesService.pref) {
      return
    }
    try {
      PreferencesService.pref = await preferences.getPreferences(context, Constants.PREFERENCES_NAME)
    } catch (_e) {
    }
  }

  static async flush(): Promise<void> {
    if (!PreferencesService.dirty || !PreferencesService.pref) {
      return
    }
    try {
      await PreferencesService.getPref().flush()
      PreferencesService.dirty = false
    } catch (_e) {
    }
  }

  static async putString(key: string, value: string): Promise<void> {
    try {
      await PreferencesService.getPref().put(key, value)
      PreferencesService.dirty = true
    } catch (_e) {
    }
  }

  static async getString(key: string, defaultValue: string = ''): Promise<string> {
    return PreferencesService.getStringSync(key, defaultValue)
  }

  static getStringSync(key: string, defaultValue: string = ''): string {
    try {
      const v = PreferencesService.getPref().getSync(key, defaultValue)
      return typeof v === 'string' ? v : defaultValue
    } catch (_e) {
      return defaultValue
    }
  }

  static async putNumber(key: string, value: number): Promise<void> {
    try {
      await PreferencesService.getPref().put(key, value)
      PreferencesService.dirty = true
    } catch (_e) {
    }
  }

  static async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    return PreferencesService.getNumberSync(key, defaultValue)
  }

  static getNumberSync(key: string, defaultValue: number = 0): number {
    try {
      const v = PreferencesService.getPref().getSync(key, defaultValue)
      return typeof v === 'number' ? v : defaultValue
    } catch (_e) {
      return defaultValue
    }
  }

  static async putBool(key: string, value: boolean): Promise<void> {
    try {
      await PreferencesService.getPref().put(key, value)
      PreferencesService.dirty = true
    } catch (_e) {
    }
  }

  static async getBool(key: string, defaultValue: boolean = false): Promise<boolean> {
    return PreferencesService.getBoolSync(key, defaultValue)
  }

  static getBoolSync(key: string, defaultValue: boolean = false): boolean {
    try {
      const v = PreferencesService.getPref().getSync(key, defaultValue)
      return typeof v === 'boolean' ? v : defaultValue
    } catch (_e) {
      return defaultValue
    }
  }

  static async delete(key: string): Promise<void> {
    try {
      await PreferencesService.getPref().delete(key)
      PreferencesService.dirty = true
    } catch (_e) {
    }
  }

  private static getPref(): preferences.Preferences {
    if (!PreferencesService.pref) {
      throw new Error('Preferences not initialized')
    }
    return PreferencesService.pref
  }
}
