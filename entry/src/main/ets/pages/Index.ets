import { AppRouter, RouteNames, AppToast } from 'common'
import { SplashPage } from './SplashPage'
import lazy { OnboardingPage } from './OnboardingPage'
import lazy { MainPage } from './MainPage'
import lazy { AppLockPage } from './AppLockPage'
import lazy { LoginPage } from './LoginPage'
import lazy { RegisterPage } from './RegisterPage'
import lazy { RecoverPage } from './RecoverPage'
import lazy { secondaryDestination } from './routes/SecondaryDestinations'

/**
 * 单入口页（audit #7）：唯一 @Entry，承载 Navigation + 全局路由表。
 * Splash 静态链入以保证首帧；其余页 import lazy，第一次 push 时再加载。
 */
@Entry
@Component
struct Index {
  @StorageLink('systemDark') systemDark: boolean = true
  /**
   * SYSTEM_DARK 权威源：EntryAbility / SettingsTab 在 COLOR_MODE_NOT_SET 时从
   * Configuration.colorMode（ConfigurationConstant：DARK=0）写入。
   * 不用 Environment.envProp('colorMode')：ArkUI ColorMode 与 ConfigurationConstant 数值相反，
   * 且 envProp 被占键后会永久默认浅色并把 SYSTEM_DARK 盖掉。
   */
  @Builder
  private pageMap(name: string) {
    // 冷路径：启动 / 鉴权 / 主壳（优先命中）
    if (name === RouteNames.SPLASH) {
      SplashPage()
    } else if (name === RouteNames.ONBOARDING) {
      OnboardingPage()
    } else if (name === RouteNames.MAIN) {
      MainPage()
    } else if (name === RouteNames.APP_LOCK) {
      AppLockPage()
    } else if (name === RouteNames.LOGIN) {
      LoginPage()
    } else if (name === RouteNames.REGISTER) {
      RegisterPage()
    } else if (name === RouteNames.RECOVER) {
      RecoverPage()
    } else if (RouteNames.isSecondary(name)) {
      secondaryDestination(name)
    }
  }

  build() {
    Navigation(AppRouter.stack) {
      // navBar 永不展示（hideNavBar），底色与 Splash 一致避免首帧白闪
    }
    .mode(NavigationMode.Stack)
    .hideNavBar(true)
    .navDestination(this.pageMap)
    .backgroundColor(this.systemDark ? '#0C0B09' : '#F7F7F4')
    .width('100%')
    .height('100%')
    .onAppear(() => {
      // AppToast 静态调用点近百处，UIContext 在此唯一入口注册一次
      AppToast.attach(this.getUIContext())
      // 挂载后再入栈，避免 NavPathStack 未绑定时操作丢失
      if (AppRouter.stack.size() === 0) {
        AppRouter.push(RouteNames.SPLASH, undefined, false)
      }
    })
  }
}
