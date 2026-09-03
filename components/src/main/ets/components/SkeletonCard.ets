import { ThemeColors, MotionTokens } from 'common'

/**
 * 骨架卡（首载占位）：logo 块 + 两行文本条 + 右侧金额条
 * - 脉动：opacity 0.3↔0.7，iterations -1 + Alternate，delayMs 错峰
 * - 布局对齐列表卡：36 logo / 74 高
 * - 嵌组行形态：透明底 + 可选底部分隔，由 SkeletonList 组容器承担圆角与 float 阴影一次
 */
@Component
export struct SkeletonCard {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop delayMs: number = 0
  /** 铺满父容器剩余高度：与 SkeletonList.fillHeight 成对使用 */
  @Prop fillHeight: boolean = false
  /** 是否画底部分隔 hairline（末行不画） */
  @Prop groupDivider: boolean = false
  @State private pulse: number = 0.3
  private started: boolean = false

  private startPulse(): void {
    if (this.started) {
      return
    }
    this.started = true
    this.getUIContext().animateTo({
      duration: MotionTokens.skeletonPulseDuration,
      curve: Curve.EaseInOut,
      delay: this.delayMs,
      iterations: -1,
      playMode: PlayMode.Alternate
    }, () => {
      this.pulse = 0.7
    })
  }

  build() {
    Column() {
      Row() {
        Column()
          .width(MotionTokens.listLogoSize)
          .height(MotionTokens.listLogoSize)
          .borderRadius(MotionTokens.listLogoRadius)
          .backgroundColor(this.theme.surface3)

        Column({ space: this.theme.spaceXs }) {
          Column()
            .width('55%')
            .height(14)
            .borderRadius(this.theme.radiusSm)
            .backgroundColor(this.theme.surface3)
          Column()
            .width('35%')
            .height(10)
            .borderRadius(this.theme.radiusSm)
            .backgroundColor(this.theme.surface3)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ left: this.theme.spaceSm })

        Column()
          .width(56)
          .height(14)
          .borderRadius(this.theme.radiusSm)
          .backgroundColor(this.theme.surface3)
      }
      .width('100%')
      .height(this.fillHeight ? 0 : 80)
      .layoutWeight(this.fillHeight ? 1 : 0)
      .padding({
        left: this.theme.spaceSm,
        right: this.theme.spaceSm,
        top: this.theme.spaceXs,
        bottom: this.theme.spaceXs
      })
      .alignItems(VerticalAlign.Center)

      if (this.groupDivider) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(this.theme.borderSoft)
      }
    }
    .width('100%')
    .layoutWeight(this.fillHeight ? 1 : 0)
    .backgroundColor(Color.Transparent)
    .opacity(this.pulse)
    .onAppear(() => {
      this.startPulse()
    })
  }
}
