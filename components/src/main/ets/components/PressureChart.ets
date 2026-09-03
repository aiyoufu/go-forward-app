import { MonthlyPressure } from 'common'
import { ThemeColors, TypeScale, MotionTokens, Utils } from 'common'
import { MotionHelper } from 'common'

/** 纯函数：从数据中取最大 amount（下限 1） */
export function recomputeMax(data: MonthlyPressure[]): number {
  let m = 1
  for (let i = 0; i < data.length; i++) {
    if (data[i].amount > m) {
      m = data[i].amount
    }
  }
  return m
}

/** 纯函数：当前月份 key（YYYY-MM） */
export function currentMonthKey(): string {
  const d = new Date()
  const y = d.getFullYear()
  const m = (d.getMonth() + 1).toString().padStart(2, '0')
  return y + '-' + m
}

/** 纯函数：是否当前月 */
export function isCurrentMonth(month: string, key: string): boolean {
  return month === key
}

/** 纯函数：是否未来月 */
export function isFutureMonth(month: string, key: string): boolean {
  return month > key
}

/**
 * 柱高：开方压缩 + 保底可见。
 * 线性比例下 ¥7 相对 ¥2300 只有约 0.3% 高，会缩成一条线。
 * 规则：非零柱 = 柱区 20% 起步 + sqrt(金额/峰值) × 剩余高度；峰值仍最高，小额也能看见。
 */
export function barHeightVp(amount: number, maxAmount: number, chartHeight: number): number {
  const h = chartHeight > 0 ? chartHeight : 160
  const barArea = Math.max(88, h)
  if (maxAmount <= 0 || amount <= 0) {
    return 0
  }
  const ratio = amount / (maxAmount * 1.05)
  const clamped = ratio > 1 ? 1 : (ratio < 0 ? 0 : ratio)
  const eased = Math.sqrt(clamped)
  const floor = Math.max(20, Math.round(barArea * 0.2))
  return Math.min(barArea, floor + eased * (barArea - floor))
}

/** 纯函数：月标签 */
export function monthLabel(month: string): string {
  const parts = month.split('-')
  if (parts.length === 2) {
    const m = parseInt(parts[1], 10)
    return m + '月'
  }
  return month
}

/** 纯函数：是否使用万单位 */
export function useWanUnit(maxAmount: number): boolean {
  return (maxAmount / 100) >= 10000
}

/** 纯函数：金额符号段（负号 + ¥ + 细空格），单独用非等宽字体渲染以免 mono 字格留空 */
export function moneySign(fen: number): string {
  return (fen < 0 ? '-' : '') + '¥' + Utils.YUAN_GAP
}

/** 纯函数：金额数字段（不四舍五入，保留实际小数） */
export function moneyBody(fen: number, useWan: boolean): string {
  const yuan = Math.abs(fen) / 100
  if (useWan) {
    const w = yuan / 10000
    return w.toFixed(2).replace(/0+$/, '').replace(/\.$/, '') + '万'
  }
  return yuan.toFixed(2).replace(/0+$/, '').replace(/\.$/, '')
}

/** 纯函数：金额标签（不四舍五入，保留实际小数，带 ¥ 单位） */
export function moneyLabel(fen: number, useWan: boolean): string {
  return moneySign(fen) + moneyBody(fen, useWan)
}

/** 首页趋势图角标：本月 vs 下月 */
export class PressureTrendTag {
  text: string = ''
  /** ok 绿回落 / danger 红升高 */
  role: string = 'off'
}

/**
 * 下月待还相对本月的差额提示；变化不足 2% 不展示。
 * 挂在「下月待还」旁，不要叠在总待还回落曲线上。
 */
export function nextMonthDueHint(thisFen: number, nextFen: number): PressureTrendTag | null {
  const delta = nextFen - thisFen
  const base = Math.max(Math.abs(thisFen), Math.abs(nextFen), 1)
  if (Math.abs(delta) / base < 0.02) {
    return null
  }
  const tag = new PressureTrendTag()
  const yuan = Math.round(Math.abs(delta) / 100)
  if (delta > 0) {
    tag.role = 'danger'
    tag.text = '较本月 +¥' + yuan
  } else {
    tag.role = 'ok'
    tag.text = '较本月 -¥' + yuan
  }
  return tag
}

/** 纯函数：下月相对本月的角标；变化不足 2% 不展示。颜色由调用方按 sparkline 对齐 */
export function pressureTrendTag(data: MonthlyPressure[]): PressureTrendTag | null {
  if (data.length < 2) {
    return null
  }
  const nowAmt = data[0].amount
  const nextAmt = data[1].amount
  const delta = nextAmt - nowAmt
  const base = Math.max(Math.abs(nowAmt), Math.abs(nextAmt), 1)
  if (Math.abs(delta) / base < 0.02) {
    return null
  }
  const tag = new PressureTrendTag()
  const yuan = Math.round(Math.abs(delta) / 100)
  if (delta > 0) {
    tag.role = 'danger'
    tag.text = '↗ +¥' + yuan + ' 下月'
  } else {
    tag.role = 'ok'
    tag.text = '↘ -¥' + yuan + ' 下月'
  }
  return tag
}

/**
 * 还款节奏柱状图（Cursor v9：单色 bar/barSoft + 当前月轻强调 + 弱边框）
 * - 常规月=bar、未来月=barSoft、当前月=reverse(primary)
 * - chartHeight：柱区高度，首页可压矮以一屏显示
 * - framed=false：嵌入父卡片时去掉自身边框
 * - 入场：柱高 0→目标（barGrow）
 */
@Component
export struct PressureChart {
  @Prop @Watch('onDataChange') data: MonthlyPressure[] = []
  @Prop theme: ThemeColors = new ThemeColors()
  /** false：嵌入父卡片时去掉自身边框与外边距，避免双边框 */
  @Prop framed: boolean = true
  /** 柱区高度（vp），默认 160；首页紧凑约 110 */
  @Prop chartHeight: number = 160
  /** 是否在柱上竖排金额；默认 true（矮图也显示） */
  @Prop showValues: boolean = true
  /** true：直接满高，不跑入场生长（首页冷启动避免半秒刷帧） */
  @Prop skipGrow: boolean = false
  @State private maxAmount: number = 1
  /** 0→1 柱生长进度 */
  @State private barGrow: number = 0
  private cancelGrow: (() => void) | null = null
  private lastPlayAt: number = 0
  private wasOffscreen: boolean = true

  aboutToAppear() {
    this.recomputeMax()
    if (this.skipGrow) {
      this.barGrow = 1
      this.wasOffscreen = false
      return
    }
    this.wasOffscreen = true
    this.kickBarGrow(true)
  }

  aboutToDisappear() {
    if (this.cancelGrow !== null) {
      this.cancelGrow()
      this.cancelGrow = null
    }
    this.wasOffscreen = true
  }

  onDataChange() {
    this.recomputeMax()
    if (this.skipGrow) {
      this.barGrow = 1
      this.wasOffscreen = false
      return
    }
    this.wasOffscreen = true
    this.kickBarGrow(true)
  }

  private kickBarGrow(force: boolean = false): void {
    const now = Date.now()
    if (!force && now - this.lastPlayAt < 400) {
      return
    }
    this.lastPlayAt = now
    if (this.cancelGrow !== null) {
      this.cancelGrow()
      this.cancelGrow = null
    }
    this.barGrow = 0
    this.cancelGrow = MotionHelper.runProgress(MotionTokens.chartGrowDuration, (t: number) => {
      this.barGrow = t
    }, () => {
      this.cancelGrow = null
      this.barGrow = 1
    })
  }

  private animatedBarHeight(amount: number, index: number): number {
    const p = MotionTokens.barStaggerProgress(this.barGrow, index, this.data.length)
    return this.barHeightVp(amount) * p
  }

  private recomputeMax(): void {
    this.maxAmount = recomputeMax(this.data)
  }

  private barAreaH(): number {
    const h = this.chartHeight > 0 ? this.chartHeight : 160
    // 允许首页压矮；下限略收，避免矮图被抬回去
    return Math.max(88, h)
  }

  private minBarH(): number {
    // 显示竖排金额时保证柱高足够放下数字，避免只露出「¥/万」
    if (this.showValues) {
      return Math.max(56, Math.round(this.barAreaH() * 0.38))
    }
    return this.barAreaH() < 100 ? 18 : 40
  }

  private barHeightVp(amount: number): number {
    return barHeightVp(amount, this.maxAmount, this.chartHeight)
  }

  private totalHeight(): number {
    // 仅 framed 独立卡片时使用固定高度；嵌入时由内容撑开
    const pad = this.framed ? 22 : 4
    return this.barAreaH() + 20 + pad
  }

  private currentMonthKey(): string {
    return currentMonthKey()
  }

  private isCurrentMonth(month: string): boolean {
    return isCurrentMonth(month, currentMonthKey())
  }

  private isFutureMonth(month: string): boolean {
    return isFutureMonth(month, currentMonthKey())
  }

  private barColor(month: string): ResourceColor {
    if (this.isCurrentMonth(month)) {
      return this.theme.primary
    }
    if (this.isFutureMonth(month)) {
      return this.theme.barSoft
    }
    return this.theme.bar
  }

  private barTextColor(month: string): ResourceColor {
    if (this.isCurrentMonth(month)) {
      return this.theme.background
    }
    return this.theme.text
  }

  private monthLabel(month: string): string {
    return monthLabel(month)
  }

  /** 竖排短标签：优先保证数字可见（短柱时也尽量完整） */
  private useWanUnit(): boolean {
    return useWanUnit(this.maxAmount)
  }

  private moneyLabel(fen: number): string {
    return moneyLabel(fen, this.useWanUnit())
  }

  private moneySign(fen: number): string {
    return moneySign(fen)
  }

  private moneyBody(fen: number): string {
    return moneyBody(fen, this.useWanUnit())
  }

  /** 竖排文字可用高度（= 柱高），过短时仍给下限避免只露单位 */
  private valueTextWidth(amount: number, index: number): number {
    const barH = this.animatedBarHeight(amount, index)
    return Math.max(barH - 4, 52)
  }

  private showBarValue(): boolean {
    return this.showValues
  }

  /** 当前月反转柱用 onPrimary；其它柱用 text2；柱外标签始终用 text2 */
  private barValueColor(month: string, inside: boolean): ResourceColor {
    if (inside && this.isCurrentMonth(month)) {
      return this.theme.onPrimary
    }
    return this.theme.text2
  }

  /** 目标柱高够竖排数字才写柱内，否则标在柱顶上方 */
  private valueFitsInside(amount: number): boolean {
    return this.barHeightVp(amount) >= 48
  }

  build() {
    Column() {
      Row({ space: 6 }) {
        ForEach(this.data, (item: MonthlyPressure, index: number) => {
          Column({ space: 4 }) {
            Stack({ alignContent: Alignment.Bottom }) {
              Column() {
                ForEach([0, 1, 2, 3, 4], (gi: number) => {
                  Row()
                    .width('100%')
                    .height(0.5)
                    .backgroundColor(this.theme.borderSoft)
                }, (gi: number) => 'grid-' + gi)
              }
              .width('100%')
              .height(this.barAreaH())
              .justifyContent(FlexAlign.SpaceBetween)

              if (item.amount > 0) {
                Column({ space: 2 }) {
                  if (this.showBarValue() && !this.valueFitsInside(item.amount)) {
                    Text() {
                      Span(this.moneySign(item.amount))
                      Span(this.moneyBody(item.amount))
                        .fontFamily(TypeScale.FONT_MONO)
                    }
                      .fontSize(TypeScale.captionSm)
                      .fontWeight(FontWeight.Medium)
                      .fontColor(this.barValueColor(item.month, false))
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .textAlign(TextAlign.Center)
                      .width('100%')
                  }
                  Stack({ alignContent: Alignment.Center }) {
                    Column()
                      .width('100%')
                      .height('100%')
                      .backgroundColor(this.barColor(item.month))
                      .borderRadius({ topLeft: 2, topRight: 2 })

                    if (this.showBarValue() && this.valueFitsInside(item.amount)) {
                      Text() {
                        Span(this.moneySign(item.amount))
                        Span(this.moneyBody(item.amount))
                          .fontFamily(TypeScale.FONT_MONO)
                      }
                        .fontSize(TypeScale.captionSm)
                        .fontWeight(this.isCurrentMonth(item.month) ? FontWeight.Bold : FontWeight.Medium)
                        .fontColor(this.barValueColor(item.month, true))
                        .maxLines(1)
                        .width(this.valueTextWidth(item.amount, index))
                        .textAlign(TextAlign.Center)
                        .rotate({ angle: -90, centerX: '50%', centerY: '50%' })
                    }
                  }
                  .width('76%')
                  .height(this.animatedBarHeight(item.amount, index))
                  .clip(false)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
              } else {
                Image($r('app.media.ic_smile'))
                  .width(20)
                  .height(20)
                  .objectFit(ImageFit.Contain)
                  .margin({ bottom: this.theme.spaceXs })
              }
            }
            .width('100%')
            .height(this.barAreaH())
            .alignContent(Alignment.Bottom)
            .clip(true)

            Text(this.monthLabel(item.month))
              .fontSize(TypeScale.captionSm)
              .fontColor(this.isCurrentMonth(item.month) ? this.theme.text : this.theme.text3)
              .fontFamily(TypeScale.FONT_MONO)
              .fontWeight(this.isCurrentMonth(item.month) ? FontWeight.Medium : FontWeight.Regular)
              .textAlign(TextAlign.Center)
              .width('100%')
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Center)
        }, (item: MonthlyPressure, index: number) => item.month + '#' + index)
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
    }
    .width('100%')
    // framed：固定总高；嵌入首页：仅柱区+月标签高度，由内容撑开
    .height(this.framed ? this.totalHeight() : (this.barAreaH() + 18))
    .padding(this.framed ? { left: 10, right: 10, top: 12, bottom: 10 } : { left: 0, right: 0, top: 0, bottom: 0 })
    .backgroundColor(this.framed ? this.theme.surface2 : Color.Transparent)
    .borderRadius(this.framed ? this.theme.radiusLg : 0)
    .border({ width: this.framed ? 1 : 0, color: this.theme.borderSoft })
    .onVisibleAreaChange([0.0, 0.35], (_expand: boolean, ratio: number) => {
      if (this.skipGrow) {
        return
      }
      if (ratio < 0.08) {
        this.wasOffscreen = true
        return
      }
      if (ratio >= 0.35 && this.wasOffscreen) {
        this.wasOffscreen = false
        this.kickBarGrow(false)
      }
    })
  }
}
