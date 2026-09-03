import { ThemeColors, TypeScale } from 'common'

/**
 * 列表筛选/排序右上紧凑菜单（对齐参考：右侧精准勾选 + 顶栏图标标题 + 分割线）
 * 契约：sheetBackground + sheetEdgeColor + radiusXl + popupShadow 悬浮（无全屏压暗遮罩）；
 * 外层不 clip，避免阴影被裁；内层 clip 保圆角。选中右侧 ✓，无反转底色
 */
@Component
export struct FilterSortMenuPanel {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop title: string = ''
  /** 顶栏左侧图标；由调用方传入 entry/components 侧 media */
  @Prop icon: Resource = $r('app.media.ic_check')
  @Prop showIcon: boolean = true
  @Prop options: string[] = []
  @Prop selectedIndex: number = 0
  /** 菜单宽度 vp：贴合 2～4 字中文标签与右侧对号，默认 148 */
  @Prop menuWidth: number = 148
  /** 选项过多时限制最大高度，内部可滚 */
  @Prop maxBodyHeight: number = 320
  onSelect: (index: number) => void = () => {}

  @Builder
  optionRow(label: string, index: number) {
    Row() {
      Text(label)
        .fontSize(TypeScale.control)
        .fontWeight(this.selectedIndex === index ? FontWeight.Medium : FontWeight.Regular)
        .fontColor(this.selectedIndex === index ? this.theme.text : this.theme.text2)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      if (this.selectedIndex === index) {
        Image($r('app.media.ic_check'))
          .width(20)
          .height(20)
          .fillColor(this.theme.text)
          .objectFit(ImageFit.Contain)
          .flexShrink(0)
          .margin({ left: 8 })
      }
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      this.onSelect(index)
    })
  }

  build() {
    // 外层：阴影 + 描边 + 底；禁止 clip，否则 popup 阴影被裁掉
    Column() {
      // 内层：圆角裁切内容，避免滚动区方角溢出
      Column({ space: 0 }) {
        // 顶栏：图标 + 标题
        if (this.title.length > 0) {
          Row({ space: 8 }) {
            if (this.showIcon) {
              Image(this.icon)
                .width(18)
                .height(18)
                .fillColor(this.theme.text2)
                .objectFit(ImageFit.Contain)
                .flexShrink(0)
            }
            Text(this.title)
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 10, bottom: 8 })
          .alignItems(VerticalAlign.Center)

          // 分割线
          Row()
            .width('100%')
            .height(0.5)
            .backgroundColor(this.theme.border)
        }

        // 选项列表
        Scroll() {
          Column({ space: 0 }) {
            ForEach(this.options, (label: string, index: number) => {
              this.optionRow(label, index)
            }, (label: string, index: number) => `fsm_${index}_${label}`)
          }
          .width('100%')
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .constraintSize({ maxHeight: this.maxBodyHeight })
        .width('100%')
      }
      .width('100%')
      .clip(true)
      .borderRadius(this.theme.radiusXl)
    }
    .width(this.menuWidth)
    .backgroundColor(this.theme.sheetBackground())
    .borderRadius(this.theme.radiusXl)
    .border({ width: 1, color: this.theme.sheetEdgeColor() })
    .shadow(this.theme.popupShadowOptions())
    .hitTestBehavior(HitTestMode.Default)
    .onClick(() => {
      // 吞掉面板自身点击，避免穿透到关闭层
    })
  }
}
