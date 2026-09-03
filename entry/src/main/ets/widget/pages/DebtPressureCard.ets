import { TypeScale } from './WidgetTypeScale'

const W_BG: Resource = $r('app.color.widget_bg')
const W_TEXT: Resource = $r('app.color.widget_text')
const W_MUTED: Resource = $r('app.color.widget_muted')
const W_DIM: Resource = $r('app.color.widget_dim')
const W_BAR: Resource = $r('app.color.widget_bar')
const W_FILL: Resource = $r('app.color.widget_fill')
const W_BAR_PEAK: Resource = $r('app.color.widget_bar_peak')
const W_BAR_CURRENT: Resource = $r('app.color.widget_bar_current')
const W_RADIUS: number = 8
/** 竖状进度条格数（长卡横贯全宽，比 2×2 卡的 20 格加密一倍） */
const TICK_COUNT: number = 40

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
 * 负债 · 资金压力 · 2×4 长卡（融合存量与流量）
 * 主体：剩余负债大金额 → 还款进度（||| 已还x%）→ 6 月柱图
 * 首柱即「当月应还」，柱顶横排金额（长卡柱格够宽，无需旋转）
 * chartPack: "h|month|amt;..." × 6（分号分隔，金额含千分位逗号）
 */
@Entry(storage)
@Component
struct DebtPressureCard {
  @LocalStorageProp('remaining') remaining: string = '¥\u20090.00'
  @LocalStorageProp('progress') progress: number = 0
  @LocalStorageProp('hasData') hasData: boolean = false
  @LocalStorageProp('peakIndex') peakIndex: number = -1
  @LocalStorageProp('chartPack') chartPack: string =
    '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—'

  // ── 存量：剩余负债 + 结清进度 ──

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
      .width(3)
      .height(13)
      .borderRadius(1.5)
      .backgroundColor(this.tickFilled(idx) ? W_FILL : W_BAR)
  }

  // ── 流量：6 月还款节奏柱图 ──

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

  /** 首柱即当月应还，标「本月」；其余为月份数字 */
  private monthLabel(index: number): string {
    if (index === 0) {
      return '本月'
    }
    const pair = this.packSeg(index).split('|')
    if (pair.length >= 2 && pair[1].length > 0 && pair[1] !== '—') {
      return pair[1] + '月'
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

  /** 峰值柱 / 当月柱的金额与月份加重显示 */
  private emphasized(index: number): boolean {
    return index === this.peakIndex || index === 0
  }

  /** 柱高占槽位百分比：上限 78% 给柱顶金额留空间 */
  private barHeightStr(index: number): string {
    const h = this.barH(index)
    if (h <= 0) {
      return '8%'
    }
    return Math.max(10, Math.round(h * 0.78)) + '%'
  }

  @Builder
  barCell(index: number) {
    Column({ space: 2 }) {
      // 金额横排于柱顶
      Column({ space: 2 }) {
        if (this.barAmt(index).length > 0) {
          Text(this.barAmt(index))
            .fontSize(TypeScale.kicker)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.emphasized(index) ? W_TEXT : W_MUTED)
            .fontWeight(this.emphasized(index) ? FontWeight.Medium : FontWeight.Regular)
            .maxLines(1)
            .textAlign(TextAlign.Center)
            .width('100%')
        }
        Column()
          .width('100%')
          .height(this.barHeightStr(index))
          .backgroundColor(this.barColor(index))
          .borderRadius(2)
          .opacity(this.barH(index) > 0 ? 1 : 0.35)
      }
      .width('100%')
      .layoutWeight(1)
      .justifyContent(FlexAlign.End)

      Text(this.monthLabel(index))
        .fontSize(TypeScale.kicker)
        .fontColor(index === 0 ? W_TEXT : W_MUTED)
        .fontWeight(index === 0 ? FontWeight.Medium : FontWeight.Regular)
        .maxLines(1)
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .layoutWeight(1)
    .height('100%')
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    Column() {
      // 头行：标题（无数据时右侧提示）
      Row({ space: 8 }) {
        Text('待还 · 还款节奏')
          .fontSize(TypeScale.caption)
          .fontColor(W_MUTED)
          .layoutWeight(1)

        if (!this.hasData) {
          Text('暂无待还记录')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_DIM)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 剩余负债大金额（存量）
      Text(this.amountText())
        .fontSize(TypeScale.display)
        .fontWeight(FontWeight.Bold)
        .fontFamily(TypeScale.FONT_MONO)
        .fontColor(W_TEXT)
        .letterSpacing(TypeScale.displaySpacing)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 2 })

      // 还款进度：||| 已还x%
      Row({ space: 8 }) {
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
          this.progressTick(20)
          this.progressTick(21)
          this.progressTick(22)
          this.progressTick(23)
          this.progressTick(24)
          this.progressTick(25)
          this.progressTick(26)
          this.progressTick(27)
          this.progressTick(28)
          this.progressTick(29)
          this.progressTick(30)
          this.progressTick(31)
          this.progressTick(32)
          this.progressTick(33)
          this.progressTick(34)
          this.progressTick(35)
          this.progressTick(36)
          this.progressTick(37)
          this.progressTick(38)
          this.progressTick(39)
        }
        .layoutWeight(1)
        .justifyContent(FlexAlign.SpaceBetween)

        Text('已还' + this.clampedProgress() + '%')
          .fontSize(TypeScale.captionSm)
          .fontColor(W_MUTED)
          .maxLines(1)
          .flexShrink(0)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 4 })

      // 6 月还款节奏：首柱即当月应还
      Row({ space: 6 }) {
        this.barCell(0)
        this.barCell(1)
        this.barCell(2)
        this.barCell(3)
        this.barCell(4)
        this.barCell(5)
      }
      .width('100%')
      .layoutWeight(1)
      .margin({ top: 6 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 10 })
    .alignItems(HorizontalAlign.Start)
    .backgroundColor(W_BG)
    .borderRadius(W_RADIUS)
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        'action': 'router',
        'abilityName': 'EntryAbility',
        'params': { 'fromWidget': true, 'openTab': 0 } as RouterParams
      } as RouterAction)
    })
  }
}
