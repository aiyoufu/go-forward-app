import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { MotionHelper } from 'common'
import { AuthManager } from 'service'
import { SettingsService } from 'service'
import { UserService } from 'service'
import { SupabaseConfig } from 'common'
import { LightReading, LightSensorService } from 'service'
import { AppStorageKeys, isAbilityConfigDark } from 'common'
import { UserSettings } from 'common'
import { LegalDocuments } from 'common'
import { PreferencesService } from 'service'
import { AnalyticsService } from 'service'
import { ErrorMessages } from 'common'
import { AppToast } from 'common'
import { Constants } from 'common'
import { LegalDocSheet } from 'components'
import { common, ConfigurationConstant } from '@kit.AbilityKit'
import { AppRouter, RouteNames } from 'common'

/** 注册页 · 与登录页同主题；未登录跟随系统，注册成功后套用账号主题 */
@Component
export struct RegisterPage {
  @State theme: ThemeColors = ThemeManager.getTheme('system',
    AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false)
  @State email: string = ''
  @State password: string = ''
  @State confirmPassword: string = ''
  @State status: string = ''
  @State loading: boolean = false
  @State topSafe: number = 0
  @State bottomSafe: number = 0
  @State lux: number = -1
  @State emailFocused: boolean = false
  @State passwordFocused: boolean = false
  @State confirmFocused: boolean = false
  @State showPassword: boolean = false
  @State ctaPressed: boolean = false
  @State errorTranslateX: number = 0
  @State hasAgreed: boolean = false
  @State showLegalSheet: boolean = false
  @State legalKind: string = 'privacy'
  private shakeTimerIds: number[] = []
  /** 光感监听需稳定引用，便于 start/stop 配对 */
  private readonly lightListener: (reading: LightReading) => void = (reading: LightReading): void => {
    this.lux = reading.lux
    this.applySystemTheme()
  }

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 0
    this.applySystemTheme()
    LightSensorService.start(this.lightListener)
  }

  private async persistAgreement(): Promise<void> {
    try {
      await PreferencesService.putNumber(
        LegalDocuments.PREF_CONSENT_VERSION,
        LegalDocuments.CONSENT_VERSION
      )
      AnalyticsService.trackPrivacyAccept('register')
    } catch (_e) {
      // 持久化失败不阻塞主流程；下次进入仍会要求勾选
    }
  }

  private openLegal(kind: string): void {
    this.legalKind = kind
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showLegalSheet = true
    })
  }

  private applySystemTheme(): void {
    const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false
    this.theme = ThemeManager.getTheme('system', systemDark)
  }

  private async applyAuthenticatedTheme(): Promise<void> {
    try {
      const settings: UserSettings = await SettingsService.getSettings(UserService.getCurrentUserId())
      const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false
      this.theme = ThemeManager.currentTheme(settings, systemDark, this.lux)
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (context) {
        const mode = settings.theme_mode
        const colorMode = mode === 'dark' ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
          : mode === 'light' ? ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
            : ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
        context.getApplicationContext().setColorMode(colorMode)
        AppStorage.setOrCreate(AppStorageKeys.APPLIED_COLOR_MODE, colorMode)
        if (colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
          AppStorage.setOrCreate(AppStorageKeys.SYSTEM_DARK, isAbilityConfigDark(context.config?.colorMode))
        }
      }
      Constants.notifyThemeChange()
    } catch (_e) {
    }
  }

  aboutToDisappear() {
    LightSensorService.stop(this.lightListener)
    this.shakeTimerIds.forEach(id => clearTimeout(id))
  }

  private isDarkCanvas(): boolean {
    return this.theme.isDarkCanvas()
  }

  private canvasTop(): string {
    return `${this.theme.background}`
  }

  private canvasBottom(): string {
    return `${this.theme.background}`
  }

  private ambientGlow(): string {
    return this.isDarkCanvas() ? 'rgba(255, 255, 255, 0.10)' : 'rgba(15, 20, 25, 0.06)'
  }

  private inputBg(): string {
    return this.isDarkCanvas() ? 'rgba(255, 255, 255, 0.06)' : 'rgba(15, 20, 25, 0.04)'
  }

  private inputBorder(focused: boolean): string {
    if (focused) {
      return `${this.theme.primary}`
    }
    return this.isDarkCanvas() ? 'rgba(255, 255, 255, 0.12)' : 'rgba(15, 20, 25, 0.10)'
  }

  private isSuccess(): boolean {
    return this.status.includes('成功')
  }

  private shakeError() {
    this.shakeTimerIds.forEach(id => clearTimeout(id))
    this.shakeTimerIds = []

    this.errorTranslateX = 0
    const shakeSequence = [6, -6, 4, -4, 2, -2, 0]
    let delay = 16
    shakeSequence.forEach((val) => {
      const timerId = setTimeout(() => {
        this.getUIContext().animateTo({
          duration: MotionTokens.shakeStepDuration,
          curve: Curve.EaseInOut
        }, () => {
          this.errorTranslateX = val
        })
      }, delay)
      this.shakeTimerIds.push(timerId)
      delay += MotionTokens.shakeStepDuration
    })
  }

  private showError(msg: string) {
    if (this.status.length > 0) {
      this.status = msg
      this.shakeError()
    } else {
      this.status = msg
    }
  }

  private async register(): Promise<void> {
    if (!this.hasAgreed) {
      AppToast.show(ErrorMessages.CONSENT_REQUIRED, 2500)
      return
    }
    if (!SupabaseConfig.isConfigured()) {
      this.showError('请先配置 Supabase URL 和 ANON_KEY')
      return
    }
    if (this.email.length === 0 || this.password.length === 0) {
      this.showError('请输入邮箱和密码')
      return
    }
    if (this.password.length < 6) {
      this.showError('密码长度至少 6 位')
      return
    }
    if (this.password !== this.confirmPassword) {
      this.showError('两次输入的密码不一致')
      return
    }

    this.loading = true
    try {
      const result = await AuthManager.signUpCloud(this.email, this.password)
      if (result.success) {
        await SettingsService.updateCloudSync(true)
        try {
          await PreferencesService.putBool(Constants.PREF_ONBOARDING_COMPLETED, true)
        } catch (_e) {
        }
        await this.persistAgreement()
        // P0-1：先进主页读本地；MainPage → SyncScheduler 后台 sync + notifyListRefresh
        this.status = '注册成功，正在进入...'
        await this.applyAuthenticatedTheme()
        AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 0)
        AppRouter.replace(RouteNames.MAIN)
      } else {
        this.showError(result.error ?? '注册失败，请稍后再试')
      }
    } catch {
      this.showError('注册失败，请稍后再试')
    } finally {
      this.loading = false
    }
  }

  @Builder
  fieldLabel(label: string) {
    Text(label)
      .fontSize(TypeScale.caption)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.text2)
      .letterSpacing(1.2)
  }

  /** 页转场位移/透明度（MotionHelper.navPageTransition 驱动） */
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  build() {
    NavDestination() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 168,
          colors: [[this.canvasTop(), 0.0], [this.canvasBottom(), 0.55], [this.canvasBottom(), 1.0]]
        })

      Column()
        .width('120%')
        .height(300)
        .margin({ left: '-10%', top: -40 })
        .radialGradient({
          center: ['40%', '20%'],
          radius: '70%',
          colors: [
            [this.ambientGlow(), 0],
            ['rgba(0,0,0,0)', 0.72]
          ]
        })

      Scroll() {
        Column() {
          Blank().height(this.topSafe + 56)

          Column({ space: 8 }) {
            Text('创建账户')
              .fontSize(TypeScale.heroNumber)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .letterSpacing(-0.6)
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Blank().height(28)

          Column({ space: 14 }) {
            Column({ space: 7 }) {
              this.fieldLabel('邮箱')
              TextInput({ placeholder: '邮箱地址', text: this.email })
                .placeholderColor(this.theme.text3)
                .fontColor(this.theme.text)
                .fontSize(TypeScale.listPrimarySm)
                .backgroundColor(this.inputBg())
                .borderRadius(this.theme.radiusLg)
                .height(50)
                .padding({ left: 16, right: 16 })
                .border({ width: 1.5, color: this.inputBorder(this.emailFocused) })
                .onFocus(() => this.emailFocused = true)
                .onBlur(() => this.emailFocused = false)
                .onChange((v: string) => {
                  this.email = v
                  this.status = ''
                })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column({ space: 7 }) {
              this.fieldLabel('密码')
              Row() {
                TextInput({ placeholder: '设置 6 位以上密码', text: this.password })
                  .layoutWeight(1)
                  .type(this.showPassword ? InputType.Normal : InputType.Password)
                  .showPasswordIcon(false)
                  .placeholderColor(this.theme.text3)
                  .fontColor(this.theme.text)
                  .fontSize(TypeScale.listPrimarySm)
                  .backgroundColor(Color.Transparent)
                  .height(50)
                  .padding({ left: 16, right: 8 })
                  .border({ width: 0 })
                  .onFocus(() => this.passwordFocused = true)
                  .onBlur(() => this.passwordFocused = false)
                  .onChange((v: string) => {
                    this.password = v
                    this.status = ''
                  })

                Column() {
                  Image(this.showPassword ? $r('app.media.ic_eye_open') : $r('app.media.ic_eye_off'))
                    .width(20)
                    .height(20)
                    .fillColor(this.showPassword ? this.theme.text : this.theme.text3)
                }
                .width(44)
                .height(44)
                .justifyContent(FlexAlign.Center)
                .onClick(() => {
                  this.showPassword = !this.showPassword
                })
              }
              .width('100%')
              .height(50)
              .backgroundColor(this.inputBg())
              .borderRadius(this.theme.radiusLg)
              .border({ width: 1.5, color: this.inputBorder(this.passwordFocused) })
              .clip(true)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column({ space: 7 }) {
              this.fieldLabel('确认密码')
              TextInput({ placeholder: '再次输入新密码', text: this.confirmPassword })
                .type(this.showPassword ? InputType.Normal : InputType.Password)
                .placeholderColor(this.theme.text3)
                .fontColor(this.theme.text)
                .fontSize(TypeScale.listPrimarySm)
                .backgroundColor(this.inputBg())
                .borderRadius(this.theme.radiusLg)
                .height(50)
                .padding({ left: 16, right: 16 })
                .border({ width: 1.5, color: this.inputBorder(this.confirmFocused) })
                .onFocus(() => this.confirmFocused = true)
                .onBlur(() => this.confirmFocused = false)
                .onChange((v: string) => {
                  this.confirmPassword = v
                  this.status = ''
                })
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Row({ space: 8 }) {
              Text(this.isSuccess() ? '✓' : '!')
                .fontSize(TypeScale.bodySm)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.isSuccess() ? this.theme.statusOk() : this.theme.statusDanger())
              Text(this.status)
                .fontSize(TypeScale.body)
                .fontColor(this.isSuccess() ? this.theme.statusOk() : this.theme.statusDanger())
                .layoutWeight(1)
            }
            .width('100%')
            .translate({ x: this.errorTranslateX })
            .visibility(this.status.length > 0 ? Visibility.Visible : Visibility.None)

            Button() {
              Text(this.loading ? '创建中' : '创建账户')
                .fontSize(TypeScale.listPrimary)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.ctaForeground())
                .width('100%')
                .textAlign(TextAlign.Center)
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
            .enabled(!this.loading)
            .onTouch((event: TouchEvent) => {
              if (event.type === TouchType.Down) {
                this.ctaPressed = true
              } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
                this.ctaPressed = false
              }
            })
            .onClick(() => this.register())
            .margin({ top: 6 })

            Row({ space: 4 }) {
              Checkbox({ name: 'legalConsentRegister', group: 'legalConsentRegisterGroup' })
                .select(this.hasAgreed)
                .shape(CheckBoxShape.ROUNDED_SQUARE)
                .selectedColor(this.theme.primary as string)
                .unselectedColor(this.theme.text2 as string)
                .mark({
                  strokeColor: this.theme.onPrimary as string,
                  size: 12,
                  strokeWidth: 2
                })
                .width(20)
                .height(20)
                .onChange((v: boolean) => {
                  this.hasAgreed = v
                })
              Flex({ wrap: FlexWrap.Wrap, alignItems: ItemAlign.Center }) {
                Text('已阅读并同意')
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.theme.text2)
                Text('《隐私政策》')
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.theme.primary)
                  .onClick(() => this.openLegal('privacy'))
                Text('和')
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.theme.text2)
                Text('《用户协议》')
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.theme.primary)
                  .onClick(() => this.openLegal('terms'))
              }
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 10 })

            Row({ space: 4 }) {
              Text('已有账户？')
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text3)
              Text('登录')
                .fontSize(TypeScale.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.primary)
                .onClick(() => {
                  const names = AppRouter.stack.getAllPathName()
                  const prev = names.length > 1 ? names[names.length - 2] : ''
                  if (prev === RouteNames.LOGIN) {
                    AppRouter.pop()
                  } else {
                    AppRouter.replace(RouteNames.LOGIN)
                  }
                })
            }
            .justifyContent(FlexAlign.Start)
            .width('100%')
            .padding({ top: 4 })
          }
          .width('100%')

          Blank().height(this.bottomSafe + 24)
        }
        .width('100%')
        .constraintSize({ minHeight: '100%' })
        .justifyContent(FlexAlign.Center)
        .padding({ left: 24, right: 24 })
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)

      // 顶部浮动导航栏
      Row() {
        Text('←')
          .fontSize(TypeScale.display)
          .fontColor(this.theme.text)
          .fontWeight(FontWeight.Medium)
          .padding({ right: 12, top: 4, bottom: 4 })
          .onClick(() => AppRouter.pop())

        Blank()

        Row({ space: 6 }) {
          Image($r('app.media.ic_compass'))
            .width(16)
            .height(16)
            .fillColor(this.theme.primary)
          Text('向前')
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .letterSpacing(1)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({
        top: this.topSafe + 16,
        left: 24,
        right: 24
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.canvasBottom())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet(this.showLegalSheet, this.legalSheetBuilder, {
      height: '80%',
      dragBar: true,
      radius: LengthMetrics.vp(this.theme.sheetRadius),
      showClose: false,
      backgroundColor: this.theme.sheetBackground() as string,
      blurStyle: BlurStyle.NONE,
      maskColor: this.theme.sheetMaskColor(),
      shadow: this.theme.sheetShadowOptions(),
      onDisappear: () => {
        this.showLegalSheet = false
      }
    })
    }
    .hideTitleBar(true)
    .backgroundColor(this.canvasBottom())
    .translate({ x: this.navTransX })
    .opacity(this.navAlpha)
    .customTransition((op: NavigationOperation, isEnter: boolean) => MotionHelper.navPageTransition(op, isEnter,
      (x: number, alpha: number) => {
        this.navTransX = x
        this.navAlpha = alpha
      }))
  }

  @Builder
  legalSheetBuilder() {
    LegalDocSheet({
      theme: this.theme,
      kind: this.legalKind,
      onClose: () => {
        this.showLegalSheet = false
      }
    })
  }
}
