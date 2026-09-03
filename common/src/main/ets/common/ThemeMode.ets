/**
 * 主题模式类型与环境光推荐（纯逻辑）
 * 自 LightSensorService 下沉至 common，解除 common/model → service 的反向依赖（audit #13）
 */
export type ThemeMode = 'light' | 'dark' | 'system'

/**
 * Ability Configuration.colorMode 是否为深色。
 *
 * 必须用 ConfigurationConstant 语义（DARK=0, LIGHT=1, NOT_SET=-1），
 * 切勿与 ArkUI ColorMode（LIGHT=0, DARK=1）混用——数值相反，混用会导致「系统深色却永远浅色」。
 *
 * 仅在应用 setColorMode(COLOR_MODE_NOT_SET) 时 config 才等于系统真值；
 * 强制浅/深后 config 是应用生效值，不可写入 SYSTEM_DARK。
 */
export function isAbilityConfigDark(colorMode: number | undefined): boolean {
  // ConfigurationConstant.ColorMode.COLOR_MODE_DARK === 0
  return colorMode === 0
}

/** 按环境光照度推荐主题模式（纯函数，原 LightSensorService.recommendThemeMode） */
export function recommendThemeMode(lux: number): ThemeMode {
  if (lux < 10) {
    return 'dark'
  }
  if (lux > 1000) {
    return 'light'
  }
  return 'system'
}
