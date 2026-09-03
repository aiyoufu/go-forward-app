import { ThemeColors, ThemeManager, TypeScale } from 'common'
import { ThemeMode } from 'common'
import { SheetHeader, sheetBottomInset } from './SheetDialog'

/**
 * 设置 · 主题模式半模态
 * - 弹窗底 sheetBackground（与选项底区分）
 * - 左右留白 20；三项紧挨、线分割
 * - 未选 sheetItemBackground 有底；选中反转
 * - 选中不自动关闭
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct SettingsThemeSheet {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop themeMode: ThemeMode = 'system'
  onSelect: (mode: ThemeMode) => void = () => {}
  onClose: () => void = () => {}

  private optionIcon(mode: ThemeMode): Resource {
    if (mode === 'light') {
      return $r('app.media.ic_settings_sun')
    }
    if (mode === 'dark') {
      return $r('app.media.ic_settings_moon')
    }
    return $r('app.media.ic_settings_desktop')
  }

  private isSelected(mode: ThemeMode): boolean {
    return this.themeMode === mode
  }

  /**
   * 选项底：必须与弹窗 sheetBackground 区分
   * - 选中：primary 反转
   * - 未选：sheetItemBackground（深 chip / 浅 surface3）
   */
  private rowBg(mode: ThemeMode): ResourceColor {
    if (this.isSelected(mode)) {
      return this.theme.primary
    }
    return this.theme.sheetItemBackground()
  }

  private iconColor(mode: ThemeMode): ResourceColor {
    return this.isSelected(mode) ? this.theme.onPrimary : this.theme.text
  }

  private labelColor(mode: ThemeMode): ResourceColor {
    return this.isSelected(mode) ? this.theme.onPrimary : this.theme.text
  }

  @Builder
  optionRow(label: string, mode: ThemeMode) {
    Row({ space: 14 }) {
      // 固定槽位，避免 stroke 图标或裁切导致「只露一半」
      Column() {
        Image(this.optionIcon(mode))
          .width(22)
          .height(22)
          .fillColor(this.iconColor(mode))
          .objectFit(ImageFit.Contain)
      }
      .width(24)
      .height(24)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .flexShrink(0)
      .clip(false)

      Text(label)
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.labelColor(mode))
        .layoutWeight(1)

      if (this.isSelected(mode)) {
        Image($r('app.media.ic_check'))
          .width(18)
          .height(18)
          .fillColor(this.theme.onPrimary)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 16, bottom: 16 })
    .backgroundColor(this.rowBg(mode))
    .borderRadius(0)
    .clip(false)
    .onClick(() => {
      if (this.isSelected(mode)) {
        return
      }
      this.onSelect(mode)
    })
  }

  build() {
    Column({ space: 0 }) {
      SheetHeader({
        theme: this.theme,
        title: '主题模式',
        subtitle: '',
        onClose: () => {
          this.onClose()
        }
      })

      // 左右留白；组内紧挨 + 线分割；选项底 ≠ 弹窗底
      Column() {
        Column({ space: 0 }) {
          this.optionRow('跟随系统', 'system')
          Row()
            .width('100%')
            .height(0.5)
            .backgroundColor(this.theme.border)
          this.optionRow('浅色', 'light')
          Row()
            .width('100%')
            .height(0.5)
            .backgroundColor(this.theme.border)
          this.optionRow('深色', 'dark')
        }
        .width('100%')
        .borderRadius(this.theme.sheetCardRadius)
        .border({ width: 1, color: this.theme.borderStrong })
        .clip(true)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ top: 0, bottom: sheetBottomInset() })
  }
}
