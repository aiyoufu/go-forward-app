import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { MotionHelper } from 'common'
import { AppStorageKeys } from 'common'
import { Constants } from 'common'
import { AppRouter, RouteNames } from 'common'
import { PreferencesService } from 'service'

/**
 * 首次品牌引导页（只出现一次）
 * - 布局结构：
 *   1. 纯黑沉浸式背景
 *   2. 顶部居中 3D 点阵线框地球（onboarding_globe）
 *   3. 品牌徽章胶囊（向前 · GOFORWARD）
 *   4. 居中双行大标题（掌控每一笔财务\n从此刻开始）
 *   5. 居中双行说明副文（集中追踪负债单据、周期订阅与信用账户\n随时掌握每一笔财务流向）
 *   6. 主胶囊「登录」按钮（进邮箱登录页，协议勾选在登录页内完成）
 *   7. 底部居中「没有账户？注册」文字链
 * - 看过引导后冷启动与登出均进 LoginPage
 */
@Component
export struct OnboardingPage {
  @State theme: ThemeColors = ThemeManager.getTheme('dark', true)
  @State topSafe: number = 0
  @State bottomSafe: number = 0
  @State private ctaPressed: boolean = false
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 0
    this.theme = ThemeManager.getTheme('dark', true)
  }

  private async markOnboardingSeen(): Promise<void> {
    try {
      await PreferencesService.putBool(Constants.PREF_ONBOARDING_COMPLETED, true)
    } catch (_e) {
    }
  }

  private goLogin(): void {
    void this.markOnboardingSeen().then(() => {
      AppRouter.push(RouteNames.LOGIN)
    })
  }

  private goRegister(): void {
    void this.markOnboardingSeen().then(() => {
      AppRouter.push(RouteNames.REGISTER)
    })
  }

  build() {
    NavDestination() {
      Stack({ alignContent: Alignment.TopStart }) {
        // 纯黑沉浸式背景
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#000000')

        Column() {
          Blank().height(this.topSafe)

          Blank() // 顶部弹性占位，实现垂直居中

          // 核心内容展示区（插图 + 徽章 + 大标题 + 说明）
          Column() {
            // 1. 3D 点阵线框地球
            Image($r('app.media.onboarding_globe'))
              .width('68%')
              .aspectRatio(1)
              .objectFit(ImageFit.Contain)
              .alignSelf(ItemAlign.Center)
              .margin({ bottom: 16 })

            // 2. 品牌徽章胶囊
            Row() {
              Text('向前 · GOFORWARD')
                .fontSize(TypeScale.captionSm)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.text2)
                .letterSpacing(1.5)
            }
            .padding({ left: 14, right: 14, top: 5, bottom: 5 })
            .backgroundColor(this.theme.surface3)
            .borderRadius(this.theme.radiusPill)
            .margin({ bottom: 16 })

            // 3. 居中大标题（双行，暖白而非纯白）
            Text('掌控每一笔财务\n从此刻开始')
              .fontSize(TypeScale.heroTitle)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F2F1EF')
              .letterSpacing(TypeScale.heroTitleSpacing)
              .lineHeight(36)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ bottom: 12 })

            // 4. 居中副文说明（双行，柔和次级字色）
            Text('集中追踪负债单据、周期订阅与信用账户\n随时掌握每一笔财务流向')
              .fontSize(TypeScale.body)
              .fontColor(this.theme.text2)
              .lineHeight(20)
              .textAlign(TextAlign.Center)
              .width('100%')
              .padding({ left: 12, right: 12 })
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          Blank() // 底部弹性占位，实现垂直居中

          // 底部操作区
          Column({ space: this.theme.spaceSm }) {
            Button() {
              Row() {
                Text('登录')
                  .fontSize(TypeScale.listPrimary)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.ctaForeground())
              }
              .justifyContent(FlexAlign.Center)
              .width('100%')
            }
            .width('100%')
            .height(54)
            .backgroundColor(this.theme.ctaBackground())
            .borderRadius(this.theme.radiusLg)
            .shadow(this.theme.floatShadowOptions())
            .scale({
              x: this.ctaPressed ? MotionTokens.pressScale : 1,
              y: this.ctaPressed ? MotionTokens.pressScale : 1
            })
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.ctaPressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.ctaPressed = false
              }
            })
            .onClick(() => this.goLogin())

            // 没有账户？注册
            Row({ space: 4 }) {
              Text('没有账户？')
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text2)
              Text('注册')
                .fontSize(TypeScale.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.primary)
                .onClick(() => this.goRegister())
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .margin({ top: 8 })
          }
          .width('100%')
          .margin({ bottom: this.theme.spaceBase })

          Blank().height(this.bottomSafe)
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({
          left: this.theme.pageHorizontalPadding,
          right: this.theme.pageHorizontalPadding
        })
      }
      .width('100%')
      .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor('#000000')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .translate({ x: this.navTransX })
    .opacity(this.navAlpha)
    .customTransition((op: NavigationOperation, isEnter: boolean) => MotionHelper.navPageTransition(op, isEnter,
      (x: number, alpha: number) => {
        this.navTransX = x
        this.navAlpha = alpha
      }))
    .onBackPressed(() => AppRouter.handleRootBack(this.getUIContext()))
  }
}
