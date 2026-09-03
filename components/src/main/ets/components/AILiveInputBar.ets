import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'

const HOLD_PILL_HEIGHT: number = 52
const KEYBOARD_PILL_HEIGHT: number = 96

/**
 * AI Live 底部录入条
 *
 * hold：单行圆角矩形（圆角对齐上方示例 chip）
 *   [📷 🖼] ——— 按住 说话 ——— [⌨️]
 *
 * keyboard：同一物件长高为两行圆角矩形
 *   试试：话费，每月 39 元
 *   (🎙)                    📷  (🖼)
 */
@Component
export struct AILiveInputBar {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop inputText: string = ''
  @Prop recognizing: boolean = false
  /** idle | transcript */
  @Prop @Watch('onBarModeChange') barMode: string = 'idle'
  /** 智感握姿：true=左手为主；语音切换键与发送等主操作贴主手一侧，媒体按钮在对侧 */
  @Prop leftPrimary: boolean = false
  /** 拍照/相册入口是否可见（默认 true：不依赖图片 AI 渠道配置） */
  @Prop mediaVisible: boolean = true
  /** hold | keyboard */
  @State private surface: string = 'hold'
  @State private holdPressed: boolean = false
  @State private sidePressed: string = ''
  @State private chipPressedKey: string = ''
  private voiceStartY: number = 0
  private voiceTouchActive: boolean = false

  onCamera: () => void = () => {}
  onAlbum: () => void = () => {}
  onTextChange: (v: string) => void = () => {}
  onSend: () => void = () => {}
  onVoicePressStart: () => void = () => {}
  onVoicePressMove: (deltaY: number) => void = () => {}
  onVoicePressEnd: () => void = () => {}

  private onBarModeChange(): void {
    if (this.barMode === 'transcript') {
      this.surface = 'hold'
    }
  }

  private isTranscriptMode(): boolean {
    return this.barMode === 'transcript'
  }

  private isHoldSurface(): boolean {
    return this.surface === 'hold' || this.isTranscriptMode()
  }

  private hasText(): boolean {
    return this.inputText.trim().length > 0
  }

  private pillHeight(): number {
    return this.isHoldSurface() ? HOLD_PILL_HEIGHT : KEYBOARD_PILL_HEIGHT
  }

  private shellRadius(): number {
    return this.isHoldSurface() ? this.theme.radiusLg : this.theme.radiusXl
  }

  /** 键盘卡片使用更强的弹出浮起阴影托起；hold 仍走输入浮条 elevated */
  private shellShadow(): ShadowOptions {
    if (!this.isHoldSurface()) {
      return this.theme.popupShadowOptions()
    }
    return this.theme.isDarkCanvas() ? this.theme.noneShadowOptions() : this.theme.elevatedShadowOptions()
  }



  private pillBg(): ResourceColor {
    if (this.holdPressed && this.isHoldSurface()) {
      return this.theme.aiAccentSoft
    }
    return this.theme.isDarkCanvas() ? this.theme.surface3 : this.theme.surface
  }

  private pillBorder(): ResourceColor {
    if (this.holdPressed && this.isHoldSurface()) {
      return this.theme.aiAccent
    }
    return this.theme.isDarkCanvas() ? this.theme.borderStrong : this.theme.border
  }

  private ink(): ResourceColor {
    return this.theme.text
  }

  private holdLabel(): string {
    if (this.holdPressed) {
      return this.isTranscriptMode() ? '松手 追加' : '松手 查看'
    }
    return '按住 说话'
  }

  private fillExample(text: string): void {
    if (this.recognizing || this.isTranscriptMode()) {
      return
    }
    this.morphSurface('keyboard')
    this.onTextChange(text)
  }

  private morphSurface(next: string): void {
    if (this.surface === next) {
      return
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.objectRevealDuration,
      curve: Curve.EaseOut
    }, () => {
      this.surface = next
    })
  }

  /** hold/keyboard 互切淡入淡出；必须挂在 Builder 根组件上，@Builder 返回 void 不能链式修饰 */
  private surfaceTransition(): TransitionEffect {
    return TransitionEffect.OPACITY.animation({
      duration: MotionTokens.objectRevealDuration,
      curve: Curve.EaseOut
    })
  }

  private switchToKeyboard(): void {
    if (this.recognizing || this.voiceTouchActive || this.isTranscriptMode()) {
      return
    }
    this.morphSurface('keyboard')
  }

  private switchToHold(): void {
    if (this.recognizing) {
      return
    }
    this.morphSurface('hold')
  }

  private touchY(e: TouchEvent): number {
    if (e.touches.length > 0) {
      return e.touches[0].y
    }
    if (e.changedTouches.length > 0) {
      return e.changedTouches[0].y
    }
    return 0
  }

  private onHoldTouch(e: TouchEvent): void {
    if (this.recognizing) {
      return
    }
    if (e.type === TouchType.Down) {
      this.voiceTouchActive = true
      this.voiceStartY = this.touchY(e)
      this.holdPressed = true
      this.onVoicePressStart()
    } else if (e.type === TouchType.Move) {
      if (!this.voiceTouchActive) {
        return
      }
      this.onVoicePressMove(this.voiceStartY - this.touchY(e))
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      if (!this.voiceTouchActive) {
        return
      }
      this.voiceTouchActive = false
      this.holdPressed = false
      this.onVoicePressEnd()
    }
  }

  private sideScale(key: string): number {
    return this.sidePressed === key ? MotionTokens.pressScale : 1
  }

  private onSideTouch(key: string, e: TouchEvent): void {
    if (e.type === TouchType.Down) {
      this.sidePressed = key
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.sidePressed = ''
    }
  }

  build() {
    Column({ space: this.theme.spaceXs }) {
      if (!this.isTranscriptMode()) {
        this.exampleTags()
      }
      this.pillShell()
    }
    .width('100%')
  }

  @Builder
  pillShell() {
    // 外层只承担阴影：clip 会裁掉 shadow，必须拆开
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        if (this.isHoldSurface()) {
          this.holdContent()
        } else {
          this.keyboardContent()
        }
      }
      .width('100%')
      .height(this.pillHeight())
      .clip(true)
      .borderRadius(this.shellRadius())
      .animation({
        duration: MotionTokens.objectRevealDuration,
        curve: Curve.EaseOut
      })
    }
    .width('100%')
    .backgroundColor(this.pillBg())
    .borderRadius(this.shellRadius())
    .border({ width: 1, color: this.pillBorder() })
    .shadow(this.shellShadow())
    .scale({
      x: this.holdPressed && this.isHoldSurface() ? 0.99 : 1,
      y: this.holdPressed && this.isHoldSurface() ? 0.99 : 1
    })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
  }

  @Builder
  exampleTags() {
    Column({ space: this.theme.spaceXs }) {
      Text('示例')
        .fontSize(TypeScale.kicker)
        .fontFamily(TypeScale.FONT_MONO)
        .letterSpacing(TypeScale.kickerSpacing)
        .fontColor(this.theme.aiAccent)
        .width('100%')
        .padding({ left: this.theme.spaceXxs, bottom: 2 })
      this.exampleChip('花呗，3000 元，分 12 期', '负债示例')
      this.exampleChip('Netflix，每月 68 元', '订阅示例')
      this.exampleChip('招商信用卡，额度 5 万', '账户示例')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  exampleChip(fillText: string, hint: string) {
    Row({ space: this.theme.spaceXs }) {
      Column()
        .width(3)
        .height(28)
        .borderRadius(this.theme.radiusSm)
        .backgroundColor(this.theme.aiAccent)
      Text(fillText)
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text)
        .layoutWeight(1)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(hint)
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.aiAccent)
        .flexShrink(0)
    }
    .width('100%')
    .padding({ left: 10, right: 12, top: 12, bottom: 12 })
    .backgroundColor(this.theme.surface3)
    .borderRadius(this.theme.radiusLg)
    .border({ width: 1, color: this.theme.borderSoft })
    .scale({
      x: this.chipPressedKey === fillText ? MotionTokens.pressScaleLight : 1,
      y: this.chipPressedKey === fillText ? MotionTokens.pressScaleLight : 1
    })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.chipPressedKey = fillText
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.chipPressedKey = ''
      }
    })
    .onClick(() => {
      this.fillExample(fillText)
    })
  }

  @Builder
  iconButton(
    icon: Resource,
    key: string,
    onClick: () => void,
    iconSize: number = 22
  ) {
    Column() {
      Image(icon)
        .width(iconSize)
        .height(iconSize)
        .fillColor(this.ink())
        .objectFit(ImageFit.Contain)
    }
    .width(40)
    .height(40)
    .justifyContent(FlexAlign.Center)
    .scale({ x: this.sideScale(key), y: this.sideScale(key) })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      this.onSideTouch(key, e)
    })
    .onClick(onClick)
  }

  @Builder
  holdMediaButtons() {
    if (this.mediaVisible) {
      this.iconButton($r('app.media.ic_quick_camera'), 'camera', () => {
        if (!this.recognizing) {
          this.onCamera()
        }
      })
      this.iconButton($r('app.media.ic_album'), 'album', () => {
        if (!this.recognizing) {
          this.onAlbum()
        }
      })
    }
  }

  @Builder
  holdContent() {
    Stack({ alignContent: Alignment.Center }) {
      Row() {
        if (this.leftPrimary) {
          this.holdToggleButton()
          this.holdHotZone()
          this.holdMediaButtons()
        } else {
          this.holdMediaButtons()
          this.holdHotZone()
          this.holdToggleButton()
        }
      }
      .width('100%')
      .height('100%')

      Text(this.holdLabel())
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.holdPressed ? this.theme.aiAccent : this.ink())
        .letterSpacing(1.5)
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height(HOLD_PILL_HEIGHT)
    .padding({ left: 4, right: 4 })
    .transition(this.surfaceTransition())
  }

  @Builder
  holdToggleButton() {
    if (!this.isTranscriptMode()) {
      this.iconButton($r('app.media.ic_keyboard'), 'keyboardToggle', () => {
        this.switchToKeyboard()
      })
    } else {
      Column().width(40).height(40)
    }
  }

  @Builder
  holdHotZone() {
    Row()
      .layoutWeight(1)
      .height('100%')
      .onTouch((e: TouchEvent) => {
        this.onHoldTouch(e)
      })
  }

  @Builder
  kbInput() {
    TextInput({
      placeholder: '试试：话费，每月 39 元',
      text: this.inputText
    })
      .placeholderColor(this.theme.text3)
      .fontColor(this.ink())
      .fontSize(TypeScale.control)
      .caretColor(this.theme.text)
      .backgroundColor(Color.Transparent)
      .showUnderline(false)
      .layoutWeight(1)
      .height(40)
      .padding({ left: this.theme.spaceXxs, right: this.theme.spaceXxs })
      .enterKeyType(EnterKeyType.Send)
      .onChange((v: string) => {
        this.onTextChange(v)
      })
      .onSubmit(() => {
        if (!this.recognizing && this.hasText()) {
          this.onSend()
        }
      })
  }

  @Builder
  kbSendButton() {
    Column() {
      Image($r('app.media.ic_arrow_up'))
        .width(16)
        .height(16)
        .fillColor(this.theme.ctaForeground())
        .objectFit(ImageFit.Contain)
    }
    .width(32)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .borderRadius(this.theme.radiusPill)
    .backgroundColor(this.theme.ctaBackground())
    .scale({ x: this.sideScale('send'), y: this.sideScale('send') })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      this.onSideTouch('send', e)
    })
    .onClick(() => {
      if (!this.recognizing && this.hasText()) {
        this.onSend()
      }
    })
  }

  @Builder
  kbVoiceToggle() {
    this.iconButton($r('app.media.ic_quick_voice'), 'voiceToggle', () => {
      this.switchToHold()
    }, 22)
  }

  @Builder
  kbMediaButtons() {
    Row({ space: this.theme.spaceXxs }) {
      if (this.mediaVisible) {
        this.iconButton($r('app.media.ic_quick_camera'), 'camera', () => {
          if (!this.recognizing) {
            this.onCamera()
          }
        }, 24)
        this.iconButton($r('app.media.ic_album'), 'album', () => {
          if (!this.recognizing) {
            this.onAlbum()
          }
        }, 22)
      }
    }
  }

  @Builder
  keyboardContent() {
    Column() {
      Row() {
        if (this.leftPrimary) {
          if (this.hasText()) {
            this.kbSendButton()
          }
          this.kbInput()
        } else {
          this.kbInput()
          if (this.hasText()) {
            this.kbSendButton()
          }
        }
      }
      .width('100%')
      .height(40)

      Row() {
        // 语音切换键贴智感握姿主手一侧：左手在左、右手在右；媒体按钮对侧
        if (this.leftPrimary) {
          this.kbVoiceToggle()
          Blank().layoutWeight(1)
          this.kbMediaButtons()
        } else {
          this.kbMediaButtons()
          Blank().layoutWeight(1)
          this.kbVoiceToggle()
        }
      }
      .width('100%')
      .height(40)
    }
    .width('100%')
    .height('100%')
    .padding({
      left: this.theme.spaceXs,
      right: this.theme.spaceXs,
      top: this.theme.spaceXs,
      bottom: this.theme.spaceXs
    })
    .justifyContent(FlexAlign.SpaceBetween)
    .transition(this.surfaceTransition())
  }
}
