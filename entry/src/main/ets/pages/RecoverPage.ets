import { ThemeColors, ThemeManager, TypeScale } from 'common'
import { MotionHelper } from 'common'
import { AuthManager } from 'service'
import { SupabaseConfig } from 'common'
import { ErrorMessages } from 'common'
import { LightReading, LightSensorService } from 'service'
import { AppStorageKeys } from 'common'
import { AppRouter } from 'common'

/** 找回密码 · 与登录页同主题；未登录跟随系统 */
@Component
export struct RecoverPage {
  @State theme: ThemeColors = ThemeManager.getTheme('system',
    AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false)
  @State email: string = ''
  @State status: string = ''
  @State loading: boolean = false
  @State topSafe: number = 0
  @State lux: number = -1
  @State emailFocused: boolean = false
  @State ctaPressed: boolean = false
  @State step: number = 1
  @State code: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''
  @State codeFocused: boolean = false
  @State passwordFocused: boolean = false
  @State confirmFocused: boolean = false

  /** 光感监听需稳定引用，便于 start/stop 配对 */
  private readonly lightListener: (reading: LightReading) => void = (reading: LightReading): void => {
    this.lux = reading.lux
    this.applySystemTheme()
  }

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.applySystemTheme()
    LightSensorService.start(this.lightListener)
  }

  private applySystemTheme(): void {
    const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false
    this.theme = ThemeManager.getTheme('system', systemDark)
  }

  aboutToDisappear() {
    LightSensorService.stop(this.lightListener)
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

  private ctaGlow(): string {
    return this.isDarkCanvas() ? 'rgba(255, 255, 255, 0.22)' : 'rgba(15, 20, 25, 0.28)'
  }

  private isSuccess(): boolean {
    return this.status.includes('已发送') || this.status.includes('成功')
  }

  private async sendCode(): Promise<void> {
    if (!SupabaseConfig.isConfigured()) {
      this.status = '请先配置 Supabase URL 和 ANON_KEY'
      return
    }
    if (this.email.length === 0) {
      this.status = '请输入邮箱'
      return
    }

    this.loading = true
    this.status = ''
    try {
      const result = await AuthManager.recoverPassword(this.email)
      if (result.success) {
        this.status = '验证码已发送，请检查邮箱（含垃圾邮件箱）'
        this.step = 2
      } else {
        this.status = ErrorMessages.auth(result.error, '发送失败，请稍后再试')
      }
    } catch {
      this.status = '发送失败，请稍后再试'
    } finally {
      this.loading = false
    }
  }

  private async resetPassword(): Promise<void> {
    if (this.code.length === 0) {
      this.status = '请输入验证码'
      return
    }
    if (this.code.length !== 6) {
      this.status = '验证码为 6 位数字'
      return
    }
    if (this.newPassword.length === 0) {
      this.status = '请输入新密码'
      return
    }
    if (this.newPassword.length < 6) {
      this.status = '密码至少 6 位'
      return
    }
    if (this.newPassword !== this.confirmPassword) {
      this.status = '两次密码不一致'
      return
    }

    this.loading = true
    this.status = ''
    try {
      const result = await AuthManager.resetPasswordWithCode(this.code, this.newPassword)
      if (result.success) {
        this.status = '密码重置成功，请使用新密码登录'
        setTimeout(() => AppRouter.pop(), 1500)
      } else {
        this.status = ErrorMessages.auth(result.error, '重置失败，请稍后再试')
      }
    } catch {
      this.status = '重置失败，请稍后再试'
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

      Column() {
        Blank().height(this.topSafe + 20)

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

        Blank().height(32)

        Column({ space: 10 }) {
          Text(this.step === 1 ? '找回密码' : '重置密码')
            .fontSize(TypeScale.heroNumber)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .letterSpacing(-0.6)
            .width('100%')

          Text(this.step === 1 ? '输入注册邮箱，我们会发送验证码' : '输入邮箱收到的 6 位验证码和新密码')
            .fontSize(TypeScale.control)
            .fontColor(this.theme.text2)
            .lineHeight(21)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')

        Blank().height(36)

        Column({ space: 18 }) {
          if (this.step === 1) {
            Column({ space: 8 }) {
              this.fieldLabel('邮箱')
              TextInput({ placeholder: '你的注册邮箱', text: this.email })
                .placeholderColor(this.theme.text3)
                .fontColor(this.theme.text)
                .fontSize(TypeScale.listPrimary)
                .backgroundColor(this.inputBg())
                .borderRadius(this.theme.radiusLg)
                .height(52)
                .padding({ left: 16, right: 16 })
                .border({ width: 1.5, color: this.inputBorder(this.emailFocused) })
                .onFocus(() => this.emailFocused = true)
                .onBlur(() => this.emailFocused = false)
                .onChange((v: string) => this.email = v)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          } else {
            Column({ space: 8 }) {
              this.fieldLabel('验证码')
              TextInput({ placeholder: '6 位数字验证码', text: this.code })
                .type(InputType.Number)
                .placeholderColor(this.theme.text3)
                .fontColor(this.theme.text)
                .fontSize(TypeScale.listPrimary)
                .backgroundColor(this.inputBg())
                .borderRadius(this.theme.radiusLg)
                .height(52)
                .padding({ left: 16, right: 16 })
                .border({ width: 1.5, color: this.inputBorder(this.codeFocused) })
                .onFocus(() => this.codeFocused = true)
                .onBlur(() => this.codeFocused = false)
                .onChange((v: string) => this.code = v)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column({ space: 8 }) {
              this.fieldLabel('新密码')
              TextInput({ placeholder: '至少 6 位', text: this.newPassword })
                .type(InputType.Password)
                .placeholderColor(this.theme.text3)
                .fontColor(this.theme.text)
                .fontSize(TypeScale.listPrimary)
                .backgroundColor(this.inputBg())
                .borderRadius(this.theme.radiusLg)
                .height(52)
                .padding({ left: 16, right: 16 })
                .border({ width: 1.5, color: this.inputBorder(this.passwordFocused) })
                .onFocus(() => this.passwordFocused = true)
                .onBlur(() => this.passwordFocused = false)
                .onChange((v: string) => this.newPassword = v)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')

            Column({ space: 8 }) {
              this.fieldLabel('确认密码')
              TextInput({ placeholder: '再次输入新密码', text: this.confirmPassword })
                .type(InputType.Password)
                .placeholderColor(this.theme.text3)
                .fontColor(this.theme.text)
                .fontSize(TypeScale.listPrimary)
                .backgroundColor(this.inputBg())
                .borderRadius(this.theme.radiusLg)
                .height(52)
                .padding({ left: 16, right: 16 })
                .border({ width: 1.5, color: this.inputBorder(this.confirmFocused) })
                .onFocus(() => this.confirmFocused = true)
                .onBlur(() => this.confirmFocused = false)
                .onChange((v: string) => this.confirmPassword = v)
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }

          if (this.status.length > 0) {
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
          }

          Button() {
            Row() {
              Text(this.loading ? (this.step === 1 ? '发送中' : '重置中') : (this.step === 1 ? '发送验证码' : '重置密码'))
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
          .borderRadius(this.theme.radiusPill)
          .shadow({
            radius: this.ctaPressed ? 8 : 16,
            color: this.ctaGlow(),
            offsetX: 0,
            offsetY: this.ctaPressed ? 2 : 6
          })
          .scale({
            x: this.ctaPressed ? 0.985 : 1,
            y: this.ctaPressed ? 0.985 : 1
          })
          .enabled(!this.loading)
          .onTouch((event: TouchEvent) => {
            if (event.type === TouchType.Down) {
              this.ctaPressed = true
            } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
              this.ctaPressed = false
            }
          })
          .onClick(() => {
            if (this.step === 1) {
              this.sendCode()
            } else {
              this.resetPassword()
            }
          })
          .margin({ top: 6 })

          Row({ space: 4 }) {
            if (this.step === 1) {
              Text('已有密码？')
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text3)
              Text('返回登录')
                .fontSize(TypeScale.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.primary)
                .onClick(() => AppRouter.pop())
            } else {
              Text('未收到验证码？')
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text3)
              Text('重新发送')
                .fontSize(TypeScale.body)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.primary)
                .onClick(() => {
                  this.step = 1
                  this.status = ''
                  this.code = ''
                  this.newPassword = ''
                  this.confirmPassword = ''
                })
            }
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .padding({ top: 4 })
        }
        .width('100%')

        Blank().layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .padding({ left: 24, right: 24 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.canvasBottom())
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
}
