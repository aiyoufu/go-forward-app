import { TypeScale } from './WidgetTypeScale'

const W_BG: Resource = $r('app.color.widget_bg')
const W_TEXT: Resource = $r('app.color.widget_text')
const W_MUTED: Resource = $r('app.color.widget_muted')
const W_DIM: Resource = $r('app.color.widget_dim')
const W_BAR: Resource = $r('app.color.widget_bar')
const W_FILL: Resource = $r('app.color.widget_fill')
const W_GROUP: Resource = $r('app.color.widget_group')
const W_RADIUS: number = 8
/** 竖状进度条格数 */
const TICK_COUNT: number = 20

interface RouterParams {
  fromWidget: boolean
  openTab: number
}

interface RouterAction {
  action: string
  abilityName: string
  params: RouterParams
}

let storage = new LocalStorage()

/**
 * 负债总览 · 2×2
 * 大金额与下方分组（当月/下月/结清进度）拉开间距
 */
@Entry(storage)
@Component
struct DebtOverviewCard {
  @LocalStorageProp('remaining') remaining: string = '¥\u20090.00'
  @LocalStorageProp('progress') progress: number = 0
  @LocalStorageProp('thisMonth') thisMonth: string = '¥\u20090.00'
  @LocalStorageProp('nextMonth') nextMonth: string = '¥\u20090.00'
  @LocalStorageProp('hasData') hasData: boolean = false

  private amountText(): string {
    if (this.remaining && this.remaining.length > 0) {
      return this.remaining
    }
    return '¥\u20090.00'
  }

  private clampedProgress(): number {
    if (this.progress < 0) {
      return 0
    }
    if (this.progress > 100) {
      return 100
    }
    return this.progress
  }

  /** 竖状进度条：已结清比例点亮的格数 */
  private tickFilled(idx: number): boolean {
    return idx < Math.round(this.clampedProgress() / 100 * TICK_COUNT)
  }

  @Builder
  progressTick(idx: number) {
    Column()
      .width(2)
      .height(14)
      .borderRadius(1)
      .backgroundColor(this.tickFilled(idx) ? W_FILL : W_BAR)
  }

  build() {
    Column() {
      // 上：标题 + 主金额
      Column({ space: 4 }) {
        Text('待还')
          .fontSize(TypeScale.caption)
          .fontColor(W_MUTED)
          .width('100%')

        Text(this.amountText())
          .fontSize(TypeScale.display)
          .fontWeight(FontWeight.Bold)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor(W_TEXT)
          .letterSpacing(TypeScale.displaySpacing)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)

      // 金额与分组之间拉开
      Column()
        .width('100%')
        .height(12)

      // 下：当月 / 下月 / 结清进度 同一分组
      Column({ space: 6 }) {
        Row() {
          Text('本月待还')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_MUTED)
            .layoutWeight(1)
          Text(this.thisMonth)
            .fontSize(TypeScale.captionSm)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(W_TEXT)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Row() {
          Text('下月预计')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_MUTED)
            .layoutWeight(1)
          Text(this.nextMonth)
            .fontSize(TypeScale.captionSm)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(W_TEXT)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (!this.hasData) {
          Text('暂无待还记录')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_DIM)
            .width('100%')
        }

        Row({ space: 8 }) {
          // 竖状分格进度条
          Row() {
            this.progressTick(0)
            this.progressTick(1)
            this.progressTick(2)
            this.progressTick(3)
            this.progressTick(4)
            this.progressTick(5)
            this.progressTick(6)
            this.progressTick(7)
            this.progressTick(8)
            this.progressTick(9)
            this.progressTick(10)
            this.progressTick(11)
            this.progressTick(12)
            this.progressTick(13)
            this.progressTick(14)
            this.progressTick(15)
            this.progressTick(16)
            this.progressTick(17)
            this.progressTick(18)
            this.progressTick(19)
          }
          .layoutWeight(1)
          .justifyContent(FlexAlign.SpaceBetween)

          Text(this.clampedProgress() + '%')
            .fontSize(TypeScale.captionSm)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(W_MUTED)
            .maxLines(1)
            .flexShrink(0)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor(W_GROUP)
      .borderRadius(W_RADIUS)
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(W_BG)
    .borderRadius(W_RADIUS)
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': { 'fromWidget': true, 'openTab': 1 } as RouterParams
      } as RouterAction)
    })
  }
}
