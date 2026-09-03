import { ThemeColors, MotionTokens, Utils } from 'common'
import { MotionHelper } from 'common'

/** 纯函数：走势方向 */
export function trendDir(values: number[]): string {
  const n = values.length
  if (n < 2) {
    return 'flat'
  }
  const first = values[0]
  const last = values[n - 1]
  const span = Math.abs(last - first)
  const base = Math.max(Math.abs(first), Math.abs(last), 1)
  if (span / base < 0.02) {
    return 'flat'
  }
  if (last < first) {
    return 'down'
  }
  if (last > first) {
    return 'up'
  }
  return 'flat'
}

/** 角标色跟走势线：下降绿、上升红，避免绿线配红标 */
export function tagRoleForSparkline(dir: string): string {
  if (dir === 'down') {
    return 'ok'
  }
  if (dir === 'up') {
    return 'danger'
  }
  return 'off'
}

export class SparklineTrendTag {
  text: string = ''
  role: string = 'off'
}

/** 纯函数：元整数千分位（tag 金额用） */
export function formatYuanGrouped(yuan: number): string {
  const s = '' + yuan
  let result = ''
  let count = 0
  for (let i = s.length - 1; i >= 0; i--) {
    result = s.charAt(i) + result
    count++
    if (count === 3 && i > 0) {
      result = ',' + result
      count = 0
    }
  }
  return result
}

/**
 * 总待还沿 sparkline 首尾的变化：文案与颜色同一套差值。
 * 下降绿 ↓ ¥n，上升红 ↑ ¥n；变化不足 2% 不展示。
 */
export function remainingDebtTrendTag(values: number[]): SparklineTrendTag | null {
  if (values.length < 2) {
    return null
  }
  const first = values[0]
  const last = values[values.length - 1]
  const delta = last - first
  const base = Math.max(Math.abs(first), Math.abs(last), 1)
  if (Math.abs(delta) / base < 0.02) {
    return null
  }
  const tag = new SparklineTrendTag()
  const yuan = Math.round(Math.abs(delta) / 100)
  const dir = trendDir(values)
  tag.role = tagRoleForSparkline(dir)
  if (delta < 0) {
    tag.text = '↓ ¥' + Utils.YUAN_GAP + formatYuanGrouped(yuan)
  } else {
    tag.text = '↑ ¥' + Utils.YUAN_GAP + formatYuanGrouped(yuan)
  }
  return tag
}

/** 纯函数：线色 */
export function strokeColor(dir: string, colorful: boolean, isDark: boolean): string {
  if (!colorful) {
    return isDark ? 'rgba(231,233,234,0.92)' : 'rgba(15,20,25,0.88)'
  }
  if (dir === 'down') {
    return isDark ? 'rgba(34,197,94,0.95)' : 'rgba(22,163,74,0.95)'
  }
  if (dir === 'up') {
    return isDark ? 'rgba(244,33,46,0.95)' : 'rgba(220,38,38,0.95)'
  }
  return isDark ? 'rgba(176,180,186,0.90)' : 'rgba(113,118,123,0.90)'
}

/** 纯函数：渐变填充上端色 */
export function fillColorTop(dir: string, colorful: boolean, isDark: boolean): string {
  if (!colorful) {
    return isDark ? 'rgba(231,233,234,0.30)' : 'rgba(15,20,25,0.16)'
  }
  if (dir === 'down') {
    return isDark ? 'rgba(34,197,94,0.38)' : 'rgba(22,163,74,0.24)'
  }
  if (dir === 'up') {
    return isDark ? 'rgba(244,33,46,0.34)' : 'rgba(220,38,38,0.20)'
  }
  return isDark ? 'rgba(176,180,186,0.26)' : 'rgba(113,118,123,0.16)'
}

/** 纯函数：渐变填充下端色 */
export function fillColorBottom(dir: string, colorful: boolean, isDark: boolean): string {
  if (!colorful) {
    return isDark ? 'rgba(231,233,234,0.02)' : 'rgba(15,20,25,0.01)'
  }
  if (dir === 'down') {
    return isDark ? 'rgba(34,197,94,0.03)' : 'rgba(22,163,74,0.02)'
  }
  if (dir === 'up') {
    return isDark ? 'rgba(244,33,46,0.03)' : 'rgba(220,38,38,0.02)'
  }
  return isDark ? 'rgba(176,180,186,0.02)' : 'rgba(113,118,123,0.01)'
}

/** 纯函数：端点光晕色 */
export function haloColor(dir: string, colorful: boolean, isDark: boolean): string {
  if (!colorful) {
    return isDark ? 'rgba(231,233,234,0.22)' : 'rgba(15,20,25,0.14)'
  }
  if (dir === 'down') {
    return isDark ? 'rgba(34,197,94,0.26)' : 'rgba(22,163,74,0.20)'
  }
  if (dir === 'up') {
    return isDark ? 'rgba(244,33,46,0.24)' : 'rgba(220,38,38,0.18)'
  }
  return isDark ? 'rgba(176,180,186,0.20)' : 'rgba(113,118,123,0.14)'
}

/**
 * 迷你走势图（摘要卡右侧）
 * - 平滑曲线 + 线下渐变填充 + 端点光晕
 * - 彩色：按走势取状态色——下降(改善)=绿，上升(加压)=红，持平=次要灰
 * - Canvas 仅用 rgba，只在数据/主题变化时静态绘制一次
 * - 入场：外层裁剪容器宽 0→满（系统动画，慢速可见），曲线从左到右展开
 */
@Component
export struct Sparkline {
  @Prop @Watch('onValuesChange') values: number[] = []
  @Prop @Watch('onThemeChange') theme: ThemeColors = new ThemeColors()
  /** true：按走势上色；false：单色 ink */
  @Prop colorful: boolean = true
  @Prop strokeWidth: number = 1.8
  @Prop @Watch('onChartWidthChange') chartWidth: number = 72
  @Prop @Watch('onChartHeightChange') chartHeight: number = 36

  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private drawSeq: number = 0
  /** 裁剪容器当前宽（vp）：0→chartWidth 由系统动画驱动 */
  @State private revealW: number = 0
  private revealTimer: number = -1
  private lastPlayAt: number = 0
  private wasOffscreen: boolean = true

  aboutToAppear() {
    this.wasOffscreen = true
    this.playReveal(true)
  }

  aboutToDisappear() {
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
    this.wasOffscreen = true
  }

  onValuesChange() {
    this.requestDraw()
    this.playReveal(true)
  }

  onThemeChange() {
    this.requestDraw()
  }

  onChartWidthChange(): void {
    this.syncCanvasSize()
  }

  onChartHeightChange(): void {
    this.syncCanvasSize()
  }

  /** 画布尺寸变化后重绘，避免沿用旧缓冲被拉伸 */
  private syncCanvasSize(): void {
    this.requestDraw()
    if (this.revealW > 0) {
      this.revealW = this.chartWidth
    }
  }

  /**
   * 重播入场（softReveal 约定）：无动画复位宽 0，下一帧系统 animateTo 展开到满宽
   * @param force 数据变化/画布就绪强制重播，忽略短防抖
   */
  private playReveal(force: boolean = false): void {
    const now = Date.now()
    if (!force && now - this.lastPlayAt < 400) {
      return
    }
    this.lastPlayAt = now
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
    this.revealW = 0
    this.revealTimer = setTimeout(() => {
      this.revealTimer = -1
      // 慢速 + EaseInOut：前段不抢拍，展开过程清晰可见
      this.getUIContext().animateTo({ duration: MotionTokens.trendRevealDuration, curve: Curve.EaseInOut }, () => {
        this.revealW = this.chartWidth
      })
    }, MotionHelper.LIST_REVEAL_FRAME_MS)
  }

  private requestDraw(): void {
    this.drawSeq++
    const seq = this.drawSeq
    setTimeout(() => {
      if (seq === this.drawSeq) {
        this.draw()
      }
    }, 16)
  }

  private isDark(): boolean {
    return this.theme.isDarkCanvas()
  }

  private trendDir(): string {
    return trendDir(this.values)
  }

  private strokeColor(): string {
    return strokeColor(this.trendDir(), this.colorful, this.isDark())
  }

  private fillColorTop(): string {
    return fillColorTop(this.trendDir(), this.colorful, this.isDark())
  }

  private fillColorBottom(): string {
    return fillColorBottom(this.trendDir(), this.colorful, this.isDark())
  }

  private haloColor(): string {
    return haloColor(this.trendDir(), this.colorful, this.isDark())
  }

  /** 中点二次贝塞尔平滑连线（终点落在真实数据点上） */
  private tracePath(ctx: CanvasRenderingContext2D, points: number[][]): void {
    const n = points.length
    ctx.moveTo(points[0][0], points[0][1])
    if (n === 2) {
      ctx.lineTo(points[1][0], points[1][1])
      return
    }
    for (let i = 1; i < n - 1; i++) {
      const midX = (points[i][0] + points[i + 1][0]) / 2
      const midY = (points[i][1] + points[i + 1][1]) / 2
      ctx.quadraticCurveTo(points[i][0], points[i][1], midX, midY)
    }
    ctx.quadraticCurveTo(
      points[n - 2][0], points[n - 2][1],
      points[n - 1][0], points[n - 1][1]
    )
  }

  private draw(): void {
    const ctx = this.context
    const w = ctx.width
    const h = ctx.height
    if (w < 4 || h < 4) {
      return
    }
    ctx.clearRect(0, 0, w, h)

    const n = this.values.length
    if (n < 2) {
      return
    }

    let minV = this.values[0]
    let maxV = this.values[0]
    for (let i = 1; i < n; i++) {
      const v = this.values[i]
      if (v < minV) {
        minV = v
      }
      if (v > maxV) {
        maxV = v
      }
    }
    const span = maxV - minV
    // 上方留边（含端点光晕）；下方贴底，扩大填充带
    const padTop = 5
    const padBottom = 1
    const usableH = Math.max(1, h - padTop - padBottom)
    const padX = 4
    const usableW = Math.max(1, w - padX * 2)
    // 曲线占满可用高度，走势幅度拉满更有方向感
    const yScale = 0.92

    const points: number[][] = []
    for (let i = 0; i < n; i++) {
      const x = padX + (usableW * i) / (n - 1)
      let t = 0.5
      if (span > 0) {
        t = (this.values[i] - minV) / span
      }
      const y = padTop + usableH * (1 - t * yScale)
      points.push([x, y])
    }

    // 线下渐变填充（沿平滑曲线闭合）
    const baseY = h - padBottom
    const grad = ctx.createLinearGradient(0, padTop, 0, baseY)
    grad.addColorStop(0, this.fillColorTop())
    grad.addColorStop(1, this.fillColorBottom())
    ctx.beginPath()
    this.tracePath(ctx, points)
    ctx.lineTo(points[n - 1][0], baseY)
    ctx.lineTo(points[0][0], baseY)
    ctx.closePath()
    ctx.fillStyle = grad
    ctx.fill()

    // 平滑主线
    ctx.beginPath()
    this.tracePath(ctx, points)
    ctx.strokeStyle = this.strokeColor()
    ctx.lineWidth = this.strokeWidth
    ctx.lineJoin = 'round'
    ctx.lineCap = 'round'
    ctx.stroke()

    // 端点：外晕 + 实心点，强化「现在在哪」（入场时随裁剪最后露出）
    const last = points[n - 1]
    ctx.beginPath()
    ctx.arc(last[0], last[1], 4.4, 0, Math.PI * 2)
    ctx.fillStyle = this.haloColor()
    ctx.fill()
    ctx.beginPath()
    ctx.arc(last[0], last[1], 2.4, 0, Math.PI * 2)
    ctx.fillStyle = this.strokeColor()
    ctx.fill()
  }

  build() {
    // 外层 Stack 固定尺寸保持布局稳定；内层裁剪容器宽度动画实现从左到右展开
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        Canvas(this.context)
          .width(this.chartWidth)
          .height(this.chartHeight)
          .onReady(() => {
            // 首帧画布就绪晚于 aboutToAppear：补绘 + 重播保证入场可见
            this.requestDraw()
            this.playReveal(true)
          })
      }
      .width(this.revealW)
      .height(this.chartHeight)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)
      .clip(true)
    }
    .width(this.chartWidth)
    .height(this.chartHeight)
    .hitTestBehavior(HitTestMode.None)
    .onVisibleAreaChange([0.0, 0.35], (_expand: boolean, ratio: number) => {
      // 离开视口（含切 Tab）后再进入才重播，与柱图同机制
      if (ratio < 0.08) {
        this.wasOffscreen = true
        return
      }
      if (ratio >= 0.35 && this.wasOffscreen) {
        this.wasOffscreen = false
        this.playReveal(false)
      }
    })
  }
}
