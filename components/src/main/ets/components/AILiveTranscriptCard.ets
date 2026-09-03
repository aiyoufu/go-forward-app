import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'

/**
 * 听写结果卡片：长文可滚动；编辑 / 重录 / 解析
 */
@Component
export struct AILiveTranscriptCard {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop draftText: string = ''
  @Prop elapsedSec: number = 0
  @Prop editing: boolean = false
  @State private editBuffer: string = ''
  @State private btnPressed: string = ''

  onRerecord: () => void = () => {}
  onStartEdit: () => void = () => {}
  onEditCancel: () => void = () => {}
  onEditDone: (text: string) => void = () => {}
  onParse: () => void = () => {}

  private charCount(): number {
    return this.draftText.length
  }

  private metaLine(): string {
    const n = this.charCount()
    if (this.elapsedSec > 0) {
      const m = Math.floor(this.elapsedSec / 60)
      const r = this.elapsedSec % 60
      const rs = r < 10 ? `0${r}` : `${r}`
      return `${n} 字 · ${m}:${rs}`
    }
    return `${n} 字`
  }

  private parseEnabled(): boolean {
    return this.draftText.trim().length > 0
  }

  private scaleFor(key: string): number {
    return this.btnPressed === key ? MotionTokens.pressScale : 1
  }

  private btnBg(style: string, disabled: boolean): ResourceColor {
    if (disabled && style === 'primary') {
      return this.theme.sheetItemBackground()
    }
    if (style === 'primary') {
      return this.theme.ctaBackground()
    }
    if (style === 'secondary') {
      return this.theme.sheetItemBackground()
    }
    return Color.Transparent
  }

  private btnFg(style: string, disabled: boolean): ResourceColor {
    if (disabled) {
      return this.theme.text3
    }
    if (style === 'primary') {
      return this.theme.ctaForeground()
    }
    return this.theme.text
  }

  private onBtnTouch(key: string, e: TouchEvent, disabled: boolean): void {
    if (disabled) {
      return
    }
    if (e.type === TouchType.Down) {
      this.btnPressed = key
    } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
      this.btnPressed = ''
    }
  }

  private emptyText(): ResourceColor {
    // 占位态「（空）」：用 text3 收敛为次要字色，避免与正文同色过重
    return this.theme.text3
  }

  build() {
    Column({ space: 10 }) {
      Row() {
        Text('听写结果')
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .layoutWeight(1)
        Text(this.editing ? '编辑中' : '可滚动 · 可改 · 再解析')
          .fontSize(TypeScale.caption)
          .fontColor(this.theme.text3)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 14 })

      Column({ space: 10 }) {
        Row() {
          Text(this.editing ? '编辑' : '转写')
            .fontSize(TypeScale.kicker)
            .fontFamily(TypeScale.FONT_MONO)
            .letterSpacing(TypeScale.kickerSpacing)
            .fontColor(this.theme.aiAccent)
            .fontWeight(FontWeight.Medium)
          Blank()
          Text(this.metaLine())
            .fontSize(TypeScale.caption)
            .fontColor(this.theme.text3)
        }
        .width('100%')

        if (this.editing) {
          TextArea({ text: this.editBuffer, placeholder: '编辑听写内容' })
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text)
            .placeholderColor(this.theme.text3)
            .caretColor(this.theme.aiAccent)
            .backgroundColor(this.theme.fieldBackground())
            .border({ width: 1, color: this.theme.fieldBorder() })
            .borderRadius(this.theme.radiusLg)
            .width('100%')
            .constraintSize({ minHeight: 140, maxHeight: 280 })
            .padding(12)
            .onChange((v: string) => {
              this.editBuffer = v
            })
        } else {
          Scroll() {
            Text(this.draftText.length > 0 ? this.draftText : '（空）')
              .fontSize(this.draftText.length > 0 ? TypeScale.control : TypeScale.body)
              .fontWeight(this.draftText.length > 0 ? FontWeight.Medium : FontWeight.Regular)
              .fontColor(this.draftText.length > 0 ? this.theme.text : this.emptyText())
              .lineHeight(this.draftText.length > 0 ? TypeScale.control + 8 : TypeScale.body + 6)
              .width('100%')
          }
          .width('100%')
          .constraintSize({ minHeight: 120, maxHeight: 260 })
          .scrollBar(BarState.Auto)
          .align(Alignment.TopStart)
        }

        if (this.editing) {
          Row({ space: 8 }) {
            Text('取消')
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.btnFg('ghost', false))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.btnBg('ghost', false))
              .border({ width: 1, color: this.theme.border })
              .scale({ x: this.scaleFor('cancel'), y: this.scaleFor('cancel') })
              .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
              .onTouch((e: TouchEvent) => {
                this.onBtnTouch('cancel', e, false)
              })
              .onClick(() => {
                this.onEditCancel()
              })

            Text('完成')
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.btnFg('primary', false))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.btnBg('primary', false))
              .scale({ x: this.scaleFor('done'), y: this.scaleFor('done') })
              .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
              .onTouch((e: TouchEvent) => {
                this.onBtnTouch('done', e, false)
              })
              .onClick(() => {
                this.onEditDone(this.editBuffer)
              })
          }
          .width('100%')
        } else {
          Row({ space: 8 }) {
            Text('重录')
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.btnFg('ghost', false))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.btnBg('ghost', false))
              .border({ width: 1, color: this.theme.border })
              .scale({ x: this.scaleFor('rerecord'), y: this.scaleFor('rerecord') })
              .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
              .onTouch((e: TouchEvent) => {
                this.onBtnTouch('rerecord', e, false)
              })
              .onClick(() => {
                this.onRerecord()
              })

            Text('编辑')
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.btnFg('secondary', false))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.btnBg('secondary', false))
              .border({ width: 1, color: this.theme.border })
              .scale({ x: this.scaleFor('edit'), y: this.scaleFor('edit') })
              .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
              .onTouch((e: TouchEvent) => {
                this.onBtnTouch('edit', e, false)
              })
              .onClick(() => {
                this.editBuffer = this.draftText
                this.onStartEdit()
              })

            Text('解析')
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.btnFg('primary', !this.parseEnabled()))
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(44)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.btnBg('primary', !this.parseEnabled()))
              .opacity(this.parseEnabled() ? 1 : 0.45)
              .scale({ x: this.scaleFor('parse'), y: this.scaleFor('parse') })
              .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
              .onTouch((e: TouchEvent) => {
                this.onBtnTouch('parse', e, !this.parseEnabled())
              })
              .onClick(() => {
                if (this.parseEnabled()) {
                  this.onParse()
                }
              })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.theme.sheetItemBackground())
      .borderRadius(this.theme.radiusLg)
      .border({ width: 1, color: this.theme.aiAccentSoft })
    }
    .width('100%')
  }
}
