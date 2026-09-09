import {
  ThemeColors,
  ThemeManager,
  AppRouter,
  ImmersiveTitleBar
} from 'common'
import { MotionHelper } from 'common'
import { NotificationsInbox } from 'components'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { fetchEffectiveTheme } from './common/ThemeLoader'

/**
 * 通知中心二级页（系统通知深链 / 直接入栈）。
 * 首页铃铛走半模态抽屉，不经本页。
 * 宽屏必须 NavigationMode.Stack + hideTitleBar，避免 Auto→Split 把内容挤到右侧。
 */
@Component
export struct NotificationsPage {
  @State private theme: ThemeColors = ThemeManager.snapshot()
  @StorageLink('ambientLux') @Watch('onThemeInputs') lux: number = -1
  @StorageLink('systemDark') @Watch('onThemeInputs') systemDark: boolean = false
  @StorageLink('themeRevision') @Watch('onThemeInputs') themeRevision: number = 0
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  aboutToAppear() {
    this.loadTheme()
  }

  onThemeInputs(): void {
    this.loadTheme()
  }

  private async loadTheme(): Promise<void> {
    const next = await fetchEffectiveTheme(this.lux, this.systemDark)
    if (ThemeManager.isSame(this.theme, next)) {
      return
    }
    this.theme = next
  }

  private goBack(): void {
    AppRouter.pop()
  }

  build() {
    NavDestination() {
      HdsNavigation() {
        NotificationsInbox({
          theme: this.theme,
          showSheetChrome: false,
          emptyIcon: $r('app.media.ic_bell')
        })
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: true,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          systemMaterialEffect: ImmersiveTitleBar.material()
        },
        content: {
          title: { mainTitle: '通知' },
          backIcon: { label: '返回', action: () => this.goBack() }
        }
      })
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(false)
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme.background)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .backgroundColor(this.theme.background)
    .translate({ x: this.navTransX })
    .opacity(this.navAlpha)
    .customTransition((op: NavigationOperation, isEnter: boolean) => MotionHelper.navPageTransition(op, isEnter,
      (x: number, alpha: number) => {
        this.navTransX = x
        this.navAlpha = alpha
      }))
  }
}
