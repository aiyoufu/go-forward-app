/**
 * AI Live 多条确认列表行（从 AILiveOverlay 拆出）
 * 纯展示 + 勾选/详情/补全回调；数据为 ConfirmListRow 行模型
 */
import { ThemeColors, ThemeManager, TypeScale } from 'common'
import { ConfirmListRow } from './AILiveConfirmRows'

@Component
export struct AILiveConfirmRowItem {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop row: ConfirmListRow = new ConfirmListRow()
  onToggle: (index: number) => void = () => {}
  onDetail: (index: number) => void = () => {}
  onEditForm: (index: number) => void = () => {}

  build() {
    Row({ space: 10 }) {
      // 勾选圆点
      Column() {
        if (this.row.selected) {
          Text('✓')
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.ctaForeground())
        }
      }
      .width(22)
      .height(22)
      .borderRadius(this.theme.radiusPill)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.row.selected ? this.theme.ctaBackground() : Color.Transparent)
      .border({
        width: 1.5,
        color: this.row.selected ? this.theme.ctaBackground() : this.theme.borderStrong
      })
      .onClick(() => this.onToggle(this.row.index))

      Column() {
        Text(this.row.mark.length > 0 ? this.row.mark : '·')
          .fontSize(TypeScale.body)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.onColorBlock())
      }
      .width(34)
      .height(34)
      .borderRadius(this.theme.radiusSm)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.row.avatarColor)

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(this.row.title.length > 0 ? this.row.title : '未知')
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.row.amountText)
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
        }
        .width('100%')

        Row({ space: 6 }) {
          Text(this.row.typeLabel)
            .fontSize(TypeScale.captionSm)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text2)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.theme.surface3)
            .borderRadius(this.theme.radiusSm)
          if (!this.row.complete) {
            Text('不完整')
              .fontSize(TypeScale.captionSm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.statusWarning())
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.theme.statusWarningBg())
              .borderRadius(this.theme.radiusSm)
          }
          if (this.row.meta.length > 0) {
            Text(this.row.meta)
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text2)
              .layoutWeight(1)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => this.onToggle(this.row.index))

      Column({ space: 4 }) {
        Text(this.row.complete ? '详情' : '补全')
          .fontSize(TypeScale.bodySm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text2)
          .onClick(() => {
            if (this.row.complete) {
              this.onDetail(this.row.index)
            } else {
              this.onEditForm(this.row.index)
            }
          })
      }
    }
    .width('100%')
    .padding({ left: 10, right: 12, top: 10, bottom: 10 })
    .backgroundColor(this.theme.sheetItemBackground())
    .borderRadius(this.theme.radiusSm)
    .border({
      width: this.row.selected ? 1.5 : 1,
      color: this.row.selected ? this.theme.ctaBackground() : this.theme.border
    })
  }
}
