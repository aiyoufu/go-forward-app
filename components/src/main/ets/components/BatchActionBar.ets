import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'

/**
 * 批量选择模式底部操作栏
 * - 左：全选 / 取消全选（primary 文字按钮）
 * - 右：取消（退出选择模式） + 删除 (N)（N>0 红底白字；N=0 禁用 chip + text3）
 * - 页内浮面板：surface2 + radiusXl + floatShadow（DESIGN「页内整块浮起一次 shadow」）
 * - 圆角 / 字阶 / 动效一律 token，禁裸值
 */
@Component
export struct BatchActionBar {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop selectedCount: number = 0
  @Prop allSelected: boolean = false
  onToggleAll: () => void = () => {
  }
  onDelete: () => void = () => {
  }
  onCancel: () => void = () => {
  }
  @State private deletePressed: boolean = false

  private canDelete(): boolean {
    return this.selectedCount > 0
  }

  build() {
    Row() {
      // 全选 / 取消全选
      Text(this.allSelected ? '取消全选' : '全选')
        .fontSize(TypeScale.control)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.primary)
        .padding({ left: 8, right: 8, top: 10, bottom: 10 })
        .onClick(() => {
          this.onToggleAll()
        })

      Blank()

      // 取消（退出选择模式）
      Text('取消')
        .fontSize(TypeScale.control)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text2)
        .padding({ left: 8, right: 8, top: 10, bottom: 10 })
        .onClick(() => {
          this.onCancel()
        })

      // 删除 (N)：危险主操作，红底白字；无选中则禁用（chip + text3）
      Row({ space: 4 }) {
        Text('删除')
          .fontSize(TypeScale.control)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.canDelete() ? this.theme.dangerForeground() : this.theme.text3)
        Text('(' + this.selectedCount + ')')
          .fontSize(TypeScale.control)
          .fontWeight(FontWeight.Medium)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor(this.canDelete() ? this.theme.dangerForeground() : this.theme.text3)
      }
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .borderRadius(this.theme.radiusSm)
      .backgroundColor(this.canDelete() ? this.theme.dangerBackground() : this.theme.chip)
      .scale({ x: this.deletePressed && this.canDelete() ? MotionTokens.pressScale : 1,
        y: this.deletePressed && this.canDelete() ? MotionTokens.pressScale : 1 })
      .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        if (!this.canDelete()) {
          return
        }
        if (e.type === TouchType.Down) {
          this.deletePressed = true
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.deletePressed = false
        }
      })
      .onClick(() => {
        if (this.canDelete()) {
          this.onDelete()
        }
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusXl)
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow(this.theme.floatShadowOptions())
  }
}
