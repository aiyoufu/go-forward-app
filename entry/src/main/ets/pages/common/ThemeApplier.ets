/**
 * 系统色彩模式应用（从 SettingsTab 拆出）
 * 封装 AbilityContext.setColorMode 与系统深浅回读；调用方传 UIAbilityContext
 */
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { AppStorageKeys, isAbilityConfigDark } from 'common'

/**
 * 在 COLOR_MODE_NOT_SET 下从 Ability config 拉系统深浅写入 SYSTEM_DARK。
 * 使用 ConfigurationConstant 语义（DARK=0），见 isAbilityConfigDark。
 */
export function pullSystemDarkFromAbilityConfig(ctx: common.UIAbilityContext): void {
  try {
    const applied = AppStorage.get<number>(AppStorageKeys.APPLIED_COLOR_MODE)
    if (applied !== undefined && applied !== ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      return
    }
    const isDark = isAbilityConfigDark(ctx.config?.colorMode)
    if (AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) !== isDark) {
      AppStorage.setOrCreate(AppStorageKeys.SYSTEM_DARK, isDark)
    }
  } catch {
  }
}

export function applySystemColorMode(ctx: common.UIAbilityContext, mode: 'light' | 'dark' | 'system'): void {
  try {
    const colorMode = mode === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
      : mode === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
        : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    ctx.getApplicationContext().setColorMode(colorMode)
    AppStorage.setOrCreate(AppStorageKeys.APPLIED_COLOR_MODE, colorMode)
    // 跟随系统：config 现在应对齐系统深浅（ConfigurationConstant）
    if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
      const isDark = isAbilityConfigDark(ctx.config?.colorMode)
      AppStorage.setOrCreate(AppStorageKeys.SYSTEM_DARK, isDark)
    }
  } catch {
  }
}
