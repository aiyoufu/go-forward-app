import { common } from '@kit.AbilityKit'

/** Navigation 路由名（audit #7：router → Navigation 单入口） */
export class RouteNames {
  static readonly SPLASH = 'SplashPage'
  static readonly ONBOARDING = 'OnboardingPage'
  static readonly MAIN = 'MainPage'
  static readonly APP_LOCK = 'AppLockPage'
  static readonly DEBT_FORM = 'DebtFormPage'
  static readonly SUBSCRIPTION_FORM = 'SubscriptionFormPage'
  static readonly CREDIT_ACCOUNT_FORM = 'CreditAccountFormPage'
  static readonly EXPORT_IMPORT = 'ExportImportPage'
  static readonly LOGIN = 'LoginPage'
  static readonly REGISTER = 'RegisterPage'
  static readonly RECOVER = 'RecoverPage'
  static readonly LEGAL = 'LegalPage'
  static readonly PROFILE = 'ProfilePage'
  static readonly AVATAR_CROP = 'AvatarCropPage'
  static readonly NOTIFICATIONS = 'NotificationsPage'

  /** 表单/导出/资料等次级页：供 Index 判断时不拉入 SecondaryDestinations 依赖树 */
  static isSecondary(name: string): boolean {
    return name === RouteNames.DEBT_FORM ||
      name === RouteNames.SUBSCRIPTION_FORM ||
      name === RouteNames.CREDIT_ACCOUNT_FORM ||
      name === RouteNames.EXPORT_IMPORT ||
      name === RouteNames.LEGAL ||
      name === RouteNames.PROFILE ||
      name === RouteNames.AVATAR_CROP ||
      name === RouteNames.NOTIFICATIONS
  }
}

/**
 * 全局路由助手：单例 NavPathStack 挂在 pages/Index 的 Navigation 上。
 * 语义对齐旧 router：push=pushUrl、replace=replaceUrl、pop=back。
 */
export class AppRouter {
  static readonly stack: NavPathStack = new NavPathStack()

  static push(name: string, param?: Object, animated: boolean = true): void {
    AppRouter.stack.pushPath(new NavPathInfo(name, param), animated)
  }

  static replace(name: string, param?: Object): void {
    AppRouter.stack.replacePath(new NavPathInfo(name, param))
  }

  /** 清空栈后只留目标页：会话被吊销等强制回登录场景，防止返回键回到已登出的页面 */
  static resetTo(name: string, param?: Object): void {
    AppRouter.stack.clear(false)
    AppRouter.stack.pushPath(new NavPathInfo(name, param), false)
  }

  static pop(): void {
    AppRouter.stack.pop()
  }

  static size(): number {
    return AppRouter.stack.size()
  }

  static topName(): string {
    const names = AppRouter.stack.getAllPathName()
    return names.length > 0 ? names[names.length - 1] : ''
  }

  /** 取该路由名最近一次 push 的参数（对齐旧 router.getParams） */
  static peekParam(name: string): Object | undefined {
    const params = AppRouter.stack.getParamByName(name) as Object[]
    return params.length > 0 ? params[params.length - 1] : undefined
  }

  /** 栈底页返回键：复刻旧 router 最后一页 back 即退出应用的行为 */
  static handleRootBack(uiContext: UIContext): boolean {
    if (AppRouter.stack.size() > 1) {
      return false
    }
    AppRouter.exitApp(uiContext)
    return true
  }

  static exitApp(uiContext: UIContext): void {
    try {
      const ctx = uiContext.getHostContext() as common.UIAbilityContext
      ctx.terminateSelf()
    } catch (_e) {
      // 上下文不可用时忽略，交给系统默认行为
    }
  }
}
