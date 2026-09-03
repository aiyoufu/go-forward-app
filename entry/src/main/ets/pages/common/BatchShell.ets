import { ThemeColors, TypeScale, Constants } from 'common'
import { BatchActionBar } from 'components'

/**
 * 三列表 Tab（负债/订阅/信用账户）批量选择壳：
 * - BatchSelectHeader：选择态标题栏，居中「已选 N 项」，背景随列表滚动淡入
 * - BatchActionOverlay：底部全选/删除操作栏宿主，浮于列表之上并避让悬浮 Tab；
 *   空白区点击穿透回列表（HitTestMode.Transparent）
 */
@Component
export struct BatchSelectHeader {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop selectedCount: number = 0
  @Prop topSafe: number = 0
  /** 顶栏背景（父页按滚动透明度计算后传入） */
  @Prop topBarBg: ResourceColor = Color.Transparent

  build() {
    Row() {
      Text('已选 ' + this.selectedCount + ' 项')
        .fontSize(TypeScale.bodySm)
        .fontColor(this.theme.text)
    }
    .width('100%')
    .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, top: 10 + this.topSafe, bottom: 8 })
    .justifyContent(FlexAlign.Center)
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.topBarBg)
  }
}

@Component
export struct BatchActionOverlay {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop selectedCount: number = 0
  @Prop allSelected: boolean = false
  onToggleAll: () => void = () => {}
  onDelete: () => void = () => {}
  onCancel: () => void = () => {}

  build() {
    Column() {
      BatchActionBar({
        theme: this.theme,
        selectedCount: this.selectedCount,
        allSelected: this.allSelected,
        onToggleAll: () => {
          this.onToggleAll()
        },
        onDelete: () => {
          this.onDelete()
        },
        onCancel: () => {
          this.onCancel()
        }
      })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.End)
    .padding({
      left: this.theme.pageHorizontalPadding,
      right: this.theme.pageHorizontalPadding,
      bottom: Constants.FLOATING_TAB_CLEARANCE + 8
    })
    .hitTestBehavior(HitTestMode.Transparent)
  }
}
