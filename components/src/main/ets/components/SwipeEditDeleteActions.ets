import { MotionTokens, ThemeColors, ThemeManager, TypeScale } from 'common'

/**
 * 列表左滑：还款(可选) + 编辑 + 删除
 * - 各按钮同一套尺寸约束，高度强制一致
 * - 不用 height:'100%'，避免 swipe 宿主把某一侧撑高
 * - 圆角只裁最右侧
 * - onRepay 不传时退化为 编辑+删除 两按钮
 * - 色：还款=反转块 primary/onPrimary；编辑=bar 抬层+描边（与列表 surface2 拉开）；删除=red
 * - 禁止业务绿/蓝（#10B981 / #1D9BF0）
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct SwipeEditDeleteActions {
  @Prop theme: ThemeColors = ThemeManager.DARK
  onEdit: () => void = () => {
  }
  onDelete: () => void = () => {
  }
  onRepay: (() => void) | undefined = undefined
  /** 必须与卡片 / ListItem 高度一致（vp） */
  @Prop actionHeight: number = 74
  @Prop cornerRadius: number = 10
  @Prop actionWidth: number = 72
  @State private repayPressed: boolean = false
  @State private editPressed: boolean = false
  @State private deletePressed: boolean = false

  private totalWidth(): number {
    return this.actionWidth * (this.onRepay ? 3 : 2)
  }

  build() {
    Row() {
      // 还款 -- 反转块（主操作）
      if (this.onRepay) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_repay'))
            .width(18)
            .height(18)
            .fillColor(this.theme.onPrimary)
            .objectFit(ImageFit.Contain)
            .flexShrink(0)
          Text('还款')
            .fontSize(TypeScale.captionSm)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.onPrimary)
            .flexShrink(0)
        }
        .width(this.actionWidth)
        .height(this.actionHeight)
        .constraintSize({
          minWidth: this.actionWidth,
          maxWidth: this.actionWidth,
          minHeight: this.actionHeight,
          maxHeight: this.actionHeight
        })
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .backgroundColor(this.theme.primary)
        .clip(true)
        .scale({ x: this.repayPressed ? MotionTokens.pressScaleLight : 1,
                 y: this.repayPressed ? MotionTokens.pressScaleLight : 1 })
        .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) { this.repayPressed = true }
          else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.repayPressed = false }
        })
        .onClick(() => {
          this.onRepay!()
        })
      }

      // 编辑 -- bar 抬层 + 发丝描边，避免与列表 surface2 糊边
      Column({ space: 4 }) {
        Image($r('app.media.ic_edit'))
          .width(18)
          .height(18)
          .fillColor(this.theme.text)
          .objectFit(ImageFit.Contain)
          .flexShrink(0)
        Text('编辑')
          .fontSize(TypeScale.captionSm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .flexShrink(0)
      }
      .width(this.actionWidth)
      .height(this.actionHeight)
      .constraintSize({
        minWidth: this.actionWidth,
        maxWidth: this.actionWidth,
        minHeight: this.actionHeight,
        maxHeight: this.actionHeight
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.theme.bar)
      .border({
        width: { left: 1, right: 0, top: 0, bottom: 0 },
        color: this.theme.borderStrong
      })
      .clip(true)
      .scale({ x: this.editPressed ? MotionTokens.pressScaleLight : 1,
               y: this.editPressed ? MotionTokens.pressScaleLight : 1 })
      .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.editPressed = true }
        else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.editPressed = false }
      })
      .onClick(() => {
        this.onEdit()
      })

      // 删除 -- 语义红
      Column({ space: 4 }) {
        Image($r('app.media.ic_delete'))
          .width(18)
          .height(18)
          .fillColor(this.theme.dangerForeground())
          .objectFit(ImageFit.Contain)
          .flexShrink(0)
        Text('删除')
          .fontSize(TypeScale.captionSm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.dangerForeground())
          .flexShrink(0)
      }
      .width(this.actionWidth)
      .height(this.actionHeight)
      .constraintSize({
        minWidth: this.actionWidth,
        maxWidth: this.actionWidth,
        minHeight: this.actionHeight,
        maxHeight: this.actionHeight
      })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.theme.dangerBackground())
      .clip(true)
      .scale({ x: this.deletePressed ? MotionTokens.pressScaleLight : 1,
               y: this.deletePressed ? MotionTokens.pressScaleLight : 1 })
      .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) { this.deletePressed = true }
        else if (e.type === TouchType.Up || e.type === TouchType.Cancel) { this.deletePressed = false }
      })
      .onClick(() => {
        this.onDelete()
      })
    }
    .width(this.totalWidth())
    .height(this.actionHeight)
    .constraintSize({
      minWidth: this.totalWidth(),
      maxWidth: this.totalWidth(),
      minHeight: this.actionHeight,
      maxHeight: this.actionHeight
    })
    .alignItems(VerticalAlign.Top)
    .borderRadius({
      topLeft: 0,
      topRight: this.cornerRadius,
      bottomLeft: 0,
      bottomRight: this.cornerRadius
    })
    .clip(true)
  }
}
