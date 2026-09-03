import { ThemeColors, ThemeManager, TypeScale} from 'common'
import { MotionHelper } from 'common'
import { LegalDocuments, LegalDocKind } from 'common'
import { AppStorageKeys } from 'common'
import { AppRouter, RouteNames } from 'common'
import { ImmersiveTitleBar } from 'common'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'

interface LegalPageParams {
  kind?: string
}

/**
 * 隐私政策 / 用户协议阅读页（上架 M1）
 * 顶部标题栏与新增/编辑页统一：HdsNavigation + 沉浸光感材质
 */
@Component
export struct LegalPage {
  @State theme: ThemeColors = ThemeManager.DARK
  @State kind: LegalDocKind = 'privacy'
  @State titleText: string = '隐私政策'
  @State bodyText: string = ''
  private pageScroller: Scroller = new Scroller()

  aboutToAppear() {
    this.theme = ThemeManager.DARK
    const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? true
    this.theme = systemDark ? ThemeManager.DARK : ThemeManager.LIGHT
    const params = AppRouter.peekParam(RouteNames.LEGAL) as LegalPageParams
    if (params !== undefined && params !== null && params.kind === 'terms') {
      this.kind = 'terms'
    } else {
      this.kind = 'privacy'
    }
    this.titleText = LegalDocuments.title(this.kind)
    this.bodyText = LegalDocuments.body(this.kind)
  }

  private goBack(): void {
    AppRouter.pop()
  }

  /** 页转场位移/透明度（MotionHelper.navPageTransition 驱动） */
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  build() {
    NavDestination() {
    HdsNavigation() {
      Column() {
        Scroll(this.pageScroller) {
          Text(this.bodyText)
            .fontSize(TypeScale.control)
            .fontColor(this.theme.text2)
            .lineHeight(22)
            .width('100%')
            .padding({ left: 20, right: 20, top: 8, bottom: 40 })
        }
        .layoutWeight(1)
        .scrollBar(BarState.Auto)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .clip(false)
        .width('100%')
      }
      .width('100%')
      .height('100%')
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
        title: { mainTitle: this.titleText },
        backIcon: { label: '返回', action: () => this.goBack() }
      }
    })
    // 宽屏/折叠屏默认 Auto→Split 会把内容挤到半屏，二级页强制 Stack 全宽
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.pageScroller])
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
