import { ThemeColors, ThemeManager, TypeScale } from 'common'

/**
 * 按住听写态：提示 + 实心胶囊 + 柱状波形（有高度、持续律动）
 * 配色：正常 CTA；取消 red
 */
@Component
export struct AILiveVoiceFullscreen {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop partialText: string = ''
  @Prop voiceLevel: number = 10
  @Prop elapsedSec: number = 0
  @Prop cancelArmed: boolean = false
  @Prop appendMode: boolean = false
  @Prop bottomSafe: number = 0
  /** 驱动波形律动，定时推进 */
  @State private animPhase: number = 0
  private animTimer: number = -1

  private static readonly BAR_COUNT: number = 28
  private static readonly BAR_MIN: number = 5
  private static readonly BAR_MAX: number = 32

  aboutToAppear(): void {
    this.startWaveAnim()
  }

  aboutToDisappear(): void {
    this.stopWaveAnim()
  }

  private startWaveAnim(): void {
    this.stopWaveAnim()
    this.animTimer = setInterval(() => {
      // 用 UI 线程 setInterval 推进相位；音量再调制高度
      this.animPhase = (this.animPhase + 1) % 360
    }, 40)
  }

  private stopWaveAnim(): void {
    if (this.animTimer !== -1) {
      clearInterval(this.animTimer)
      this.animTimer = -1
    }
  }

  private hintLabel(): string {
    if (this.cancelArmed) {
      return '松手取消'
    }
    return this.appendMode ? '松手追加 上移取消' : '松手查看 上移取消'
  }

  private pillBg(): ResourceColor {
    return this.cancelArmed ? this.theme.red : this.theme.ctaBackground()
  }

  private hintColor(): ResourceColor {
    // 提示文案位于胶囊上方的全屏玻璃遮罩上（不在 CTA 底色内）：
    // - 正常态用 text2：三主题次要字色，深浅遮罩均可读；ctaForeground 是给 CTA 底反色的，
    //   落在遮罩上会变成暗底近黑 / 亮底近白，几乎不可见
    // - 取消态用 red 表达取消语义，浅深底均可读；写死白字只适配深色
    if (this.cancelArmed) {
      return this.theme.red
    }
    return this.theme.text2
  }

  private barColor(): ResourceColor {
    if (this.cancelArmed) {
      // 红底上的声纹条走 dangerForeground：深色画布压成暖白，禁裸 #FFFFFF
      return this.theme.dangerForeground()
    }
    return this.theme.ctaForeground()
  }

  /**
   * 柱高：本地相位持续起伏 + voiceLevel 抬整体幅度
   * voiceLevel 约 4~28（SpeechService.pcmLevel）
   */
  private barHeight(index: number): number {
    const level = Math.min(28, Math.max(4, this.voiceLevel)) / 28
    // 相位：animPhase 0~359，换算弧度感
    const t = this.animPhase * 0.17
    // 两路正弦错相，避免整齐排队
    const a = Math.abs(Math.sin(index * 0.55 + t))
    const b = Math.abs(Math.sin(index * 0.95 - t * 1.25 + 0.8))
    const c = Math.abs(Math.sin(index * 0.3 + t * 0.6))
    const shape = a * 0.5 + b * 0.35 + c * 0.15
    // 静音也有最低律动；有声时更高
    const amp = 0.28 + level * 0.72
    const h = AILiveVoiceFullscreen.BAR_MIN +
      shape * amp * (AILiveVoiceFullscreen.BAR_MAX - AILiveVoiceFullscreen.BAR_MIN)
    return Math.round(Math.min(AILiveVoiceFullscreen.BAR_MAX, Math.max(AILiveVoiceFullscreen.BAR_MIN, h)))
  }

  private displayPartial(): string {
    const t = this.partialText.trim()
    if (t.length > 0) {
      return t
    }
    return this.appendMode ? '继续说，松手追加到卡片…' : '正在听你说…'
  }

  private barIndexes(): number[] {
    const arr: number[] = []
    for (let i = 0; i < AILiveVoiceFullscreen.BAR_COUNT; i++) {
      arr.push(i)
    }
    return arr
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Text(this.displayPartial())
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .lineHeight(TypeScale.listPrimary + 6)
          .textAlign(TextAlign.Center)
          .width('100%')
          .opacity(this.cancelArmed ? 0.35 : 1)
          .maxLines(8)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 28, right: 28, top: 80 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column({ space: 14 }) {
        Text(this.hintLabel())
          .fontSize(TypeScale.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.hintColor())
          .textAlign(TextAlign.Center)
          .width('100%')

        // 实心胶囊 + 高柱波形（随 animPhase / voiceLevel 跳动）
        Row({ space: 3 }) {
          ForEach(this.barIndexes(), (i: number) => {
            Column()
              .width(3.5)
              .height(this.barHeight(i))
              .borderRadius(1.75)
              .backgroundColor(this.barColor())
          }, (i: number) => `bar-${i}`)
        }
        .width('100%')
        .height(52)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .padding({ left: 18, right: 18 })
        .backgroundColor(this.pillBg())
        .borderRadius(this.theme.radiusPill)
        .clip(true)
      }
      .width('100%')
      .padding({
        left: 14,
        right: 14,
        bottom: this.bottomSafe > 0 ? this.bottomSafe + 8 : 16
      })
    }
    .width('100%')
    .height('100%')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    // 与 Overlay 一致：压暗 + 极轻 blur
    .backgroundColor(this.theme.aiMaskDim())
    .backgroundEffect({
      radius: this.theme.aiGlassBlurRadius(),
      saturation: this.theme.aiGlassSaturation(),
      brightness: this.theme.aiGlassBrightness(),
      color: this.theme.aiGlassTint()
    })
  }
}
