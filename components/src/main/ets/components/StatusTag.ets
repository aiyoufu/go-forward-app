import { ThemeColors, TypeScale } from 'common'

/**
 * 统一状态标签：填充色板（ok 绿 / warn 琥珀 / danger 红 / off 灰）
 * 列表卡与详情弹窗共用，保证文案角色与视觉一致。
 * onPaper=true 时用于深色画布的米白纸面（强制浅色板），避免浅字看不见。
 */
@Component
// 列表/详情共用状态标签，含 role 色板逻辑，不宜降为 @Builder
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct StatusTag {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop text: string = ''
  @Prop role: string = 'ok'
  @Prop onPaper: boolean = false

  build() {
    Text(this.text)
      .fontSize(TypeScale.captionSm)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.fgColor())
      .backgroundColor(this.bgColor())
      .borderRadius(this.theme.radiusSm)
      .padding({ left: 6, right: 6, top: 3, bottom: 3 })
      .maxLines(1)
      .flexShrink(0)
  }

  private useLightPalette(): boolean {
    return this.onPaper && this.theme.isDarkCanvas()
  }

  private fgColor(): ResourceColor {
    if (this.useLightPalette()) {
      if (this.role === 'ok') {
        return '#16A34A'
      }
      if (this.role === 'warn') {
        return '#D97706'
      }
      if (this.role === 'danger') {
        return '#CF2D56'
      }
      return '#5C5A52'
    }
    return this.theme.statusTagFg(this.role)
  }

  private bgColor(): ResourceColor {
    if (this.useLightPalette()) {
      if (this.role === 'ok') {
        return 'rgba(34,197,94,0.12)'
      }
      if (this.role === 'warn') {
        return 'rgba(245,158,11,0.12)'
      }
      if (this.role === 'danger') {
        return 'rgba(207,45,86,0.12)'
      }
      return '#EBEAE5'
    }
    return this.theme.statusTagBg(this.role)
  }
}
