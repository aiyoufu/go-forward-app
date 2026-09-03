/**
 * 页面主题加载（各 Tab / MainPage 去重）
 * 读设置 → 计算生效主题；isSame 判断留在调用方，便于各自处理 force / sheet 竞态
 */
import { ThemeColors, ThemeManager } from 'common'
import { SettingsService, UserService } from 'service'

/** 读取用户设置并计算当前生效主题 */
export async function fetchEffectiveTheme(lux: number, systemDark: boolean): Promise<ThemeColors> {
  const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
  return ThemeManager.currentTheme(settings, systemDark, lux)
}
