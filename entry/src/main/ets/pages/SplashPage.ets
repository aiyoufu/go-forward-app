import { TypeScale } from 'common'
import { AppRouter, RouteNames } from 'common'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { E2EEService } from 'service'
import { UserService } from 'service'
import { SettingsService } from 'service'
import { AuthManager } from 'service'
import { PerfTrace } from 'service'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { Constants } from 'common'
import { AppStorageKeys } from 'common'
import { isAbilityConfigDark } from 'common'
import { LegalDocuments } from 'common'
import { ErrorMessages } from 'common'

/** Splash · 初始化路由；主题：未登录跟系统，已登录用账号设置 */
@Component
export struct SplashPage {
  @State message: string = '正在初始化...'
  @StorageLink('systemDark') systemDark: boolean = true

  private canvasColor(): string {
    return this.systemDark ? '#0C0B09' : '#F7F7F4'
  }

  private inkColor(): string {
    return this.systemDark ? '#F2F1EF' : '#26251E'
  }

  private mutedColor(): string {
    return this.systemDark ? '#C9C5BD' : '#5C5A52'
  }

  aboutToAppear() {
    this.initialize()
  }

  private async initialize(): Promise<void> {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      // DB 与 Preferences 并行；光感延后到进主页/登录页，不堵冷启动
      await Promise.all([
        DbService.init(context),
        PreferencesService.init(context)
      ])
      await E2EEService.initialize()

      // 隐私同意门禁
      const consentVer = await PreferencesService.getNumber(LegalDocuments.PREF_CONSENT_VERSION, 0)
      const consentOk = consentVer >= LegalDocuments.CONSENT_VERSION

      // 仅做库表占位初始化，不作为「未登录主题」来源；与读会话互不依赖，并行执行
      const initResults = await Promise.all([
        UserService.ensureDefaultUser(),
        AuthManager.loadSession()
      ])
      const session = initResults[1]
      const cloudOk = session !== null && session.mode === 'cloud' && session.accessToken.length > 0
      const localOk = session !== null && session.mode === 'local' && session.userId.length > 0

      if ((cloudOk || localOk) && consentOk) {
        // 已登录（云或本机）：一次 getSettings 同时用于主题与应用锁
        const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
        this.applyColorMode(settings.theme_mode)
        Constants.notifyThemeChange()
        if (settings.app_lock_enabled) {
          AppRouter.replace(RouteNames.APP_LOCK)
        } else {
          PerfTrace.mark('T1_main_nav')
          AppRouter.replace(RouteNames.MAIN)
        }
        return
      }

      // 未登录：跟随系统（COLOR_MODE_NOT_SET），登录页与系统浅/深一致
      this.applyColorMode('system')
      Constants.notifyThemeChange()

      // 引导只出现一次；之后未登录一律进登录页
      const onboardingDone = await PreferencesService.getBool(Constants.PREF_ONBOARDING_COMPLETED, false)
      if (onboardingDone) {
        AppRouter.replace(RouteNames.LOGIN)
      } else {
        AppRouter.replace(RouteNames.ONBOARDING)
      }
    } catch (err) {
      this.message = ErrorMessages.INIT_FAILED
    } finally {
      await PreferencesService.flush()
    }
  }

  private applyColorMode(mode: string): void {
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (!context) {
        return
      }
      const colorMode = mode === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : mode === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
          : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
      context.getApplicationContext().setColorMode(colorMode)
      AppStorage.setOrCreate(AppStorageKeys.APPLIED_COLOR_MODE, colorMode)
      // 跟随系统时 config 对齐系统（ConfigurationConstant DARK=0），写入 SYSTEM_DARK
      if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
        AppStorage.setOrCreate(AppStorageKeys.SYSTEM_DARK, isAbilityConfigDark(context.config?.colorMode))
      }
    } catch {
    }
  }

  build() {
    NavDestination() {
    Column() {
      Text('向前')
        .fontSize(TypeScale.heroNumber)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.inkColor())
        .letterSpacing(-0.5)
        .margin({ bottom: 40 })

      LoadingProgress()
        .width(40)
        .height(40)
        .color(this.inkColor())
        .margin({ bottom: 16 })

      Text(this.message)
        .fontSize(TypeScale.bodySm)
        .fontColor(this.mutedColor())
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.canvasColor())
    }
    .hideTitleBar(true)
    .backgroundColor(this.canvasColor())
    .onBackPressed(() => AppRouter.handleRootBack(this.getUIContext()))
  }
}
