import { TypeScale } from './WidgetTypeScale'

const W_BG: Resource = $r('app.color.widget_bg')
const W_TEXT: Resource = $r('app.color.widget_text')
const W_MUTED: Resource = $r('app.color.widget_muted')
const W_BAR: Resource = $r('app.color.widget_bar')
const W_BAR_PEAK: Resource = $r('app.color.widget_bar_peak')
const W_BAR_CURRENT: Resource = $r('app.color.widget_bar_current')
const W_RADIUS: number = 8
/** 柱体槽高 */
const CHART_H: number = 92

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
 * 资金压力 · 2×2
 * 金额横向书写后 rotate(-90)，沿柱体竖向阅读
 * chartPack: "h|month|amt;..." × 6（分号分隔，金额含千分位逗号）
 */
@Entry(storage)
@Component
struct PressureTrendCard {
  @LocalStorageProp('hasData') hasData: boolean = false
  @LocalStorageProp('peakIndex') peakIndex: number = -1
  @LocalStorageProp('chartPack') chartPack: string =
    '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'

  private packSeg(index: number): string {
    const raw = (this.chartPack && this.chartPack.length > 0)
      ? this.chartPack
      : '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'
    const segs = raw.split(';')
    if (index >= 0 && index < segs.length) {
      return segs[index]
    }
    return '0|—|—'
  }

  private barH(index: number): number {
    const pair = this.packSeg(index).split('|')
    const n = parseInt(pair[0], 10)
    if (isNaN(n) || n < 0) {
      return 0
    }
    return n > 100 ? 100 : n
  }

  private barMonth(index: number): string {
    const pair = this.packSeg(index).split('|')
    if (pair.length >= 2 && pair[1].length > 0) {
      return pair[1]
    }
    return '—'
  }

  private barAmt(index: number): string {
    const pair = this.packSeg(index).split('|')
    if (pair.length >= 3 && pair[2].length > 0 && pair[2] !== '—') {
      return pair[2]
    }
    return ''
  }

  private barColor(index: number): Resource {
    if (index === this.peakIndex) {
      return W_BAR_PEAK
    }
    if (index === 0) {
      return W_BAR_CURRENT
    }
    return W_BAR
  }

  private amtColor(index: number): Resource {
    // 峰值柱/当月柱为反色底，用反色文字保证对比度
    if (index === this.peakIndex || index === 0) {
      return $r('app.color.widget_amt_on_bar')
    }
    return W_TEXT
  }

  private barHeightVp(heightPct: number): number {
    if (heightPct <= 0) {
      return 14
    }
    // 旋转金额需要足够柱高才能放下完整短标签
    return Math.max(44, Math.round(CHART_H * heightPct / 100))
  }

  /** 旋转后沿柱体竖向的可用长度（= 柱高），保底避免最长标签被截 */
  private amtTextWidth(index: number): number {
    return Math.max(this.barHeightVp(this.barH(index)) - 4, 44)
  }

  @Builder
  barCell(index: number) {
    Column({ space: 3 }) {
      Column() {
        Stack({ alignContent: Alignment.Center }) {
          Column()
            .width('100%')
            .height(this.barHeightVp(this.barH(index)))
            .backgroundColor(this.barColor(index))
            .borderRadius(2)
            .opacity(this.barH(index) > 0 ? 1 : 0.4)

          // 横向文案旋转 -90°，平行于柱体纵向；宽度取柱高避免被柱格宽度截断
          if (this.barAmt(index).length > 0) {
            Text(this.barAmt(index))
              .fontSize(TypeScale.kicker)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.amtColor(index))
              .fontWeight(FontWeight.Medium)
              .maxLines(1)
              .width(this.amtTextWidth(index))
              .textAlign(TextAlign.Center)
              .rotate({ angle: -90, centerX: '50%', centerY: '50%' })
          }
        }
        .width('100%')
        .height(this.barHeightVp(this.barH(index)))
        .clip(false)
      }
      .width('100%')
      .height(CHART_H)
      .justifyContent(FlexAlign.End)
      .alignItems(HorizontalAlign.Center)

      Text(this.barMonth(index))
        .fontSize(TypeScale.kicker)
        .fontColor(index === 0 ? W_TEXT : W_MUTED)
        .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .layoutWeight(1)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      Text('还款节奏')
        .fontSize(TypeScale.caption)
        .fontColor(W_MUTED)
        .width('100%')
        .margin({ bottom: 4 })

      if (!this.hasData) {
        Text('暂无预测')
          .fontSize(TypeScale.captionSm)
          .fontColor(W_MUTED)
          .width('100%')
          .layoutWeight(1)
      } else {
        Row({ space: 4 }) {
          this.barCell(0)
          this.barCell(1)
          this.barCell(2)
          this.barCell(3)
          this.barCell(4)
          this.barCell(5)
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(VerticalAlign.Bottom)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(W_BG)
    .borderRadius(W_RADIUS)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': { 'fromWidget': true, 'openTab': 0 } as RouterParams
      } as RouterAction)
    })
  }
}
