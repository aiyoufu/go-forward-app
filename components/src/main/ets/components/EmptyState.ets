import { ThemeColors, TypeScale, MotionTokens } from 'common'
import { Constants } from 'common'

/**
 * 纯函数：底部安全距离
 * FLOATING_TAB_CLEARANCE(96) 已含底栏 56 + barBottomMargin 28 + 呼吸间距 12；
 * HdsTabs 自身已避让系统安全区，内容侧勿再叠加 bottomSafe（否则双重计算、底部空隙过大）
 */
export function bottomClearance(bottomExtra: number): number {
  if (bottomExtra >= 0) {
    return bottomExtra
  }
  return Constants.FLOATING_TAB_CLEARANCE
}

/**
 * 空状态（Cursor v9 · 物件层）
 * 布局契约：
 * - 外层 Tab：Column(height 100%) → 顶栏 → EmptyState(layoutWeight 1)
 * - 内容在底栏避让之上垂直居中；调用方 .width('100%').layoutWeight(1)
 * - 有插画时以造景为主舞台；无插画时用实心克制标识（不用虚线说明书感 +）
 * - hint 仅辅助，默认可空；优先 primaryLabel 作动作
 */
@Component
export struct EmptyState {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop showIllustration: boolean = false
  @Prop illustration: Resource = $r('app.media.empty_home')
  @Prop icon: Resource = $r('app.media.ic_add')
  @Prop iconSize: number = 30
  @Prop iconColor: ResourceColor = ''
  @Prop accent: ResourceColor = ''
  @Prop title: string = ''
  @Prop subtitle: string = ''
  @Prop hint: string = ''
  /** <0 时用 FLOATING_TAB_CLEARANCE */
  @Prop bottomExtra: number = -1
  @Prop watermark: string = ''
  @Prop kicker: string = ''
  @Prop primaryLabel: string = ''
  @Prop outlineLabel: string = ''
  @Prop statusBarText: string = ''
  @Prop alignStart: boolean = false
  /** 器物式：更大插画、更松标题间距、轻入场 */
  @Prop objectStage: boolean = false
  primaryAction?: () => void
  outlineAction?: () => void

  @State private primaryPressed: boolean = false
  @State private outlinePressed: boolean = false
  @State private revealOpacity: number = 0
  @State private revealOffsetY: number = MotionTokens.objectRevealOffsetY
  @State private revealScale: number = MotionTokens.objectRevealScaleFrom

  aboutToAppear() {
    this.playObjectReveal()
  }

  private playObjectReveal(): void {
    // 下一帧再 animate，保证从当前呈现值起可打断
    setTimeout(() => {
      this.getUIContext().animateTo({
        duration: MotionTokens.objectRevealDuration,
        curve: Curve.EaseOut
      }, () => {
        this.revealOpacity = 1
        this.revealOffsetY = 0
        this.revealScale = 1
      })
    }, 16)
  }

  private bottomClearance(): number {
    return bottomClearance(this.bottomExtra)
  }

  private markSize(): number {
    return this.objectStage ? 64 : 56
  }

  private illustrationSize(): number {
    return this.objectStage ? 160 : 120
  }

  build() {
    Column() {
      // 居中内容区：占满「顶栏以下 − 底栏避让」
      Column() {
        if (this.watermark.length > 0 && !this.alignStart) {
          Text(this.watermark)
            .fontSize(TypeScale.display)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.borderSoft)
            .letterSpacing(TypeScale.displaySpacing)
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .width('100%')
            .opacity(0.85)
            .margin({ bottom: this.theme.spaceXs })
        }

        if (this.kicker.length > 0) {
          Text(this.kicker)
            .fontSize(TypeScale.caption)
            .fontColor(this.theme.text3)
            .fontWeight(FontWeight.Regular)
            .margin({ bottom: this.theme.spaceXs })
        }

        // 主舞台：插画直接呈现（图内自有光影/器物，不再套外层卡片）
        if (this.showIllustration) {
          Image(this.illustration)
            .width(this.illustrationSize())
            .height(this.illustrationSize())
            .objectFit(ImageFit.Contain)
            .draggable(false)
        } else {
          Stack() {
            if (this.iconColor !== '') {
              Image(this.icon)
                .width(this.iconSize)
                .height(this.iconSize)
                .fillColor(this.iconColor)
                .draggable(false)
            } else {
              Text('前')
                .fontSize(TypeScale.display)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.text3)
                .letterSpacing(TypeScale.displaySpacing)
            }
          }
          .width(this.markSize())
          .height(this.markSize())
          .backgroundColor(this.theme.surface2)
          .border({ width: 1, color: this.theme.borderSoft })
          .borderRadius(this.theme.radiusLg)
          .shadow(this.theme.floatShadowOptions())
        }

        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(this.objectStage ? TypeScale.display : TypeScale.heroTitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
            .letterSpacing(this.objectStage ? TypeScale.displaySpacing : TypeScale.heroTitleSpacing)
            .textAlign(this.alignStart ? TextAlign.Start : TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
            .margin({ top: this.objectStage ? this.theme.spaceBase : this.theme.spaceSm })
        }

        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text2)
            .textAlign(this.alignStart ? TextAlign.Start : TextAlign.Center)
            .lineHeight(22)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width(this.objectStage ? '78%' : '100%')
            .margin({ top: this.theme.spaceXs })
        }

        // 说明书式 hint 弱化：有主按钮时不强调 hint
        if (this.hint.length > 0 && this.primaryLabel.length === 0) {
          Text(this.hint)
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
            .textAlign(this.alignStart ? TextAlign.Start : TextAlign.Center)
            .maxLines(1)
            .width('100%')
            .margin({ top: this.theme.spaceXs })
            .opacity(0.85)
        }

        if (this.primaryLabel.length > 0 || this.outlineLabel.length > 0) {
          Row({ space: 12 }) {
            if (this.primaryLabel.length > 0) {
              Text(this.primaryLabel)
                .fontSize(TypeScale.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.onPrimary)
                .backgroundColor(this.theme.primary)
                .borderRadius(this.theme.radiusMd)
                .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                .scale({
                  x: this.primaryPressed ? MotionTokens.pressScale : 1,
                  y: this.primaryPressed ? MotionTokens.pressScale : 1
                })
                .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  if (e.type === TouchType.Down) {
                    this.primaryPressed = true
                  } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                    this.primaryPressed = false
                  }
                })
                .onClick(() => {
                  if (this.primaryAction) {
                    this.primaryAction()
                  }
                })
            }
            if (this.outlineLabel.length > 0) {
              Text(this.outlineLabel)
                .fontSize(TypeScale.body)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.text)
                .border({ width: 1, color: this.theme.borderSoft })
                .borderRadius(this.theme.radiusMd)
                .padding({ left: 20, right: 20, top: 10, bottom: 10 })
                .scale({
                  x: this.outlinePressed ? MotionTokens.pressScaleLight : 1,
                  y: this.outlinePressed ? MotionTokens.pressScaleLight : 1
                })
                .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
                .onTouch((e: TouchEvent) => {
                  if (e.type === TouchType.Down) {
                    this.outlinePressed = true
                  } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
                    this.outlinePressed = false
                  }
                })
                .onClick(() => {
                  if (this.outlineAction) {
                    this.outlineAction()
                  }
                })
            }
          }
          .margin({ top: 20 })
        }

        if (this.statusBarText.length > 0) {
          Row() {
            Text(this.statusBarText)
              .fontSize(TypeScale.kicker)
              .fontColor(this.theme.text3)
              .fontFamily(TypeScale.FONT_MONO)
              .letterSpacing(TypeScale.kickerSpacing)
          }
          .width('100%')
          .justifyContent(this.alignStart ? FlexAlign.Start : FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
          .margin({ top: this.theme.spaceSm })
          .border({ width: 1, color: this.theme.border })
          .borderRadius(this.theme.radiusSm)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(this.alignStart ? HorizontalAlign.Start : HorizontalAlign.Center)
      .padding(this.alignStart
        ? { left: 0, right: 0 }
        : { left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding })
      .opacity(this.revealOpacity)
      .translate({ y: this.revealOffsetY })
      .scale({ x: this.revealScale, y: this.revealScale })

      // 悬浮底栏避让（与列表页 List 底部留白同一常量，保证各 Tab 视觉中心对齐）
      Column()
        .width('100%')
        .height(this.bottomClearance())
    }
    .width('100%')
    .height('100%')
  }
}
