import { SettingsService } from 'service'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { UserService } from 'service'
import { AppStorageKeys } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { AppRouter, RouteNames } from 'common'

type LockMode = 'verify' | 'set' | 'change'

@Component
export struct AppLockPage {
  @State theme: ThemeColors = ThemeManager.DARK
  @State mode: LockMode = 'verify'
  @State step: number = 1
  @State pin: string = ''
  @State confirmPin: string = ''
  @State error: string = ''
  @State verifying: boolean = false
  @State checking: boolean = true
  @State topSafe: number = 0
  @State isFromSettings: boolean = false
  /** change 模式：旧 PIN 是否已验证通过 */
  @State oldVerified: boolean = false
  /** set 模式：PIN 已成功落库，navigateBack 不得再回写关闭 */
  private setCompleted: boolean = false

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.loadThemeAndMode()
  }

  private async loadThemeAndMode(): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    const storedLux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
    this.theme = ThemeManager.currentTheme(settings, AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false, storedLux)
    
    const params = AppRouter.peekParam(RouteNames.APP_LOCK) as Record<string, Object>
    this.isFromSettings = params?.isFromSettings === true
    const wantChange = params?.mode === 'change'
    if (wantChange && settings.app_lock_enabled) {
      this.mode = 'change'
    } else {
      this.mode = settings.app_lock_enabled ? 'verify' : 'set'
    }
    this.oldVerified = false
    this.step = 1
    this.checking = false
  }

  /**
   * 从「我的」页面 push 进来时栈深 > 1，用 pop() 回到已有 MainPage（保留「我的」Tab）；
   * 从 Splash 进入时栈深 === 1，只能 replace 新建 MainPage。
   */
  private navigateBack(): void {
    // 未完成设置就返回：确保不把应用锁写成已开启（设置成功后不可覆盖）
    if (this.mode === 'set' && this.isFromSettings && !this.setCompleted) {
      AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, false)
    }
    if (AppRouter.size() > 1) {
      // 仅设置页入口需回到「我的」Tab；自动锁 pop 后回原页，不动 Tab
      if (this.isFromSettings) {
        AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 4)
      }
      AppRouter.pop()
    } else {
      AppRouter.replace(RouteNames.MAIN)
    }
  }

  private showBackButton(): boolean {
    return this.mode !== 'verify' || this.isFromSettings
  }

  private async doSet(): Promise<void> {
    if (this.pin.length < 6) {
      return
    }
    if (this.pin !== this.confirmPin) {
      this.error = '两次输入的 PIN 码不一致'
      this.pin = ''
      this.confirmPin = ''
      this.step = 1
      return
    }
    this.verifying = true
    this.error = ''
    try {
      await SettingsService.setAppLock(this.pin, 5)
      this.setCompleted = true
      AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_VERIFIED, true)
      AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, true)
      AppStorage.setOrCreate(AppStorageKeys.LAST_ACTIVE_TIME, Date.now())
      AppToast.show(this.mode === 'change' ? 'PIN 码已修改' : ErrorMessages.LOCK_SET, 2000)
      
      this.navigateBack()
    } catch (err) {
      this.error = '设置失败'
    }
    this.verifying = false
  }

  private async doVerify(): Promise<void> {
    if (this.pin.length < 6) {
      return
    }
    this.verifying = true
    this.error = ''
    const ok = await SettingsService.verifyAppLock(this.pin)
    this.verifying = false
    if (ok) {
      AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_VERIFIED, true)
      AppStorage.setOrCreate(AppStorageKeys.LAST_ACTIVE_TIME, Date.now())
      
      AppToast.show(ErrorMessages.LOCK_VERIFIED, 1500)
      this.navigateBack()
    } else {
      this.error = 'PIN 码错误'
      this.pin = ''
    }
  }

  /** change 模式第一步：验证旧 PIN，通过后进入设新 PIN 两步流程（不写解锁态） */
  private async doVerifyOld(): Promise<void> {
    if (this.pin.length < 6) {
      return
    }
    this.verifying = true
    this.error = ''
    const ok = await SettingsService.verifyAppLock(this.pin)
    this.verifying = false
    if (ok) {
      this.pin = ''
      this.step = 1
      this.oldVerified = true
    } else {
      this.error = 'PIN 码错误'
      this.pin = ''
    }
  }

  private appendDigit(d: number): void {
    if (this.pin.length < 6) {
      this.pin += d
      this.error = ''
      if (this.pin.length === 6) {
        setTimeout(() => {
          this.submit()
        }, 150)
      }
    }
  }

  private backspace(): void {
    this.pin = this.pin.slice(0, -1)
  }

  private titleText(): string {
    if (this.mode === 'verify') return '安全验证'
    if (this.mode === 'change') {
      if (!this.oldVerified) return '验证当前 PIN 码'
      return this.step === 1 ? '设置新 PIN 码' : '确认新 PIN 码'
    }
    return this.step === 1 ? '设置安全密码' : '确认安全密码'
  }

  private subtitleText(): string {
    if (this.mode === 'verify') return '输入 6 位 PIN，解锁继续'
    if (this.mode === 'change') {
      if (!this.oldVerified) return '请输入当前使用的 6 位 PIN 码'
      return this.step === 1 ? '请设置新的 6 位数 PIN 码' : '请再次输入刚才设置的新 PIN 码'
    }
    return this.step === 1 ? '请设置您的 6 位数 PIN 码' : '请再次输入刚才设置的 PIN 码'
  }

  private submit(): void {
    if (this.mode === 'verify') {
      this.doVerify()
    } else if (this.mode === 'change' && !this.oldVerified) {
      this.doVerifyOld()
    } else {
      // set 模式，或 change 已验旧：两步设置新 PIN
      if (this.step === 1) {
        this.confirmPin = this.pin
        this.pin = ''
        this.step = 2
      } else {
        this.doSet()
      }
    }
  }

  build() {
    NavDestination() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.checking) {
        Column() {
          Text('加载中...')
            .fontSize(TypeScale.control)
            .fontColor(this.theme.text2)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .backgroundColor(this.theme.background)
      } else {
        Column() {
          // 顶部占位：给悬浮返回让出空间
          Blank().height(this.topSafe + 56)

          // 大锁图标：无边框无底，仅图标放大
          Image($r('app.media.ic_settings_lock'))
            .width(56)
            .height(56)
            .fillColor(this.theme.text)
            .objectFit(ImageFit.Contain)
            .margin({ top: 24, bottom: 20 })

          Text(this.titleText())
            .fontSize(TypeScale.display)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .letterSpacing(-0.2)
            .margin({ bottom: 8 })

          Text(this.subtitleText())
            .fontSize(TypeScale.control)
            .fontColor(this.theme.text2)
            .margin({ bottom: 40 })

          // PIN 点指示器
          Row() {
            ForEach([0, 1, 2, 3, 4, 5], (index: number) => {
              Column()
                .width(14)
                .height(14)
                .backgroundColor(index < this.pin.length ? this.theme.primary : Color.Transparent)
                .borderRadius(this.theme.radiusSm)
                .border({ width: 1, color: this.theme.border })
                .margin({ left: 8, right: 8 })
                .animation({ duration: MotionTokens.feedbackDuration, curve: Curve.EaseOut })
            }, (index: number) => '' + index)
          }
          .height(20)
          .margin({ bottom: 24 })

          if (this.error.length > 0) {
            Text(this.error)
              .fontSize(TypeScale.body)
              .fontColor(this.theme.statusDanger())
              .fontWeight(FontWeight.Medium)
              .margin({ bottom: 16 })
          } else {
            // 错误消息空出高度以防止布局发生抖动
            Text('')
              .fontSize(TypeScale.body)
              .height(13)
              .margin({ bottom: 16 })
          }

          // 数字键盘
          Grid() {
            ForEach([1, 2, 3, 4, 5, 6, 7, 8, 9, -1, 0, -2], (digit: number) => {
              GridItem() {
                if (digit === -1) {
                  Blank()
                } else if (digit === -2) {
                  Button() {
                    Text('⌫')
                      .fontSize(TypeScale.sectionNumber)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.theme.text)
                  }
                  .width(68)
                  .height(68)
                  .type(ButtonType.Circle)
                  .backgroundColor(Color.Transparent)
                  .stateEffect(true)
                  .onClick(() => this.backspace())
                } else {
                  Button({ type: ButtonType.Circle, stateEffect: true }) {
                    Text('' + digit)
                      .fontSize(TypeScale.display)
                      .fontWeight(FontWeight.Regular)
                      .fontColor(this.theme.text)
                  }
                  .width(68)
                  .height(68)
                  .backgroundColor(this.theme.surface2)
                  .onClick(() => this.appendDigit(digit))
                }
              }
              .align(Alignment.Center)
            }, (digit: number) => '' + digit)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .rowsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(16)
          .rowsGap(12)
          .width(260)
          .height(300)
          .margin({ bottom: 40 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Start)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.theme.background)

        // 悬浮返回：对齐表单页圆形返回钮
        if (this.showBackButton()) {
          Column() {
            Text('‹')
              .fontSize(TypeScale.display)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .offset({ y: -1 })
          }
          .width(40)
          .height(40)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(this.theme.radiusXl)
          .backgroundColor(this.theme.surface2)
          .border({ width: 0.5, color: this.theme.border })
          .shadow(this.theme.floatShadowOptions())
          .margin({ left: 16, top: this.topSafe + 8 })
          .onClick(() => this.navigateBack())
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .backgroundColor(this.theme.background)
    .onBackPressed(() => {
      // 验证模式不允许绕锁：返回键直接退出应用（对齐旧整窗锁定行为）
      if (!this.showBackButton()) {
        AppRouter.exitApp(this.getUIContext())
        return true
      }
      this.navigateBack()
      return true
    })
  }
}
