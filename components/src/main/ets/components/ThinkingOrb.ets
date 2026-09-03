import { ThemeColors, ThemeManager } from 'common'
import { OrbDot, ThinkingOrbEngine } from './ThinkingOrbEngine'

/**
 * 解析中试用：working 轨道点阵。
 * 按 64 逻辑像素出点（与官网一致），物理像素只做缩放；画完再约下一帧，避免堆积。
 */
@Component
export struct ThinkingOrb {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop orbSize: number = 64
  /** working | searching | listening */
  @Prop orbState: string = 'working'
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  private engine: ThinkingOrbEngine = new ThinkingOrbEngine()
  private timer: number = -1
  private startMs: number = 0
  private ready: boolean = false
  private alive: boolean = false
  private painting: boolean = false

  aboutToAppear(): void {
    this.alive = true
    this.startMs = Date.now()
    this.kick()
  }

  aboutToDisappear(): void {
    this.alive = false
    this.stopClock()
  }

  private kick(): void {
    this.stopClock()
    if (!this.alive) {
      return
    }
    this.timer = setTimeout(() => {
      this.timer = -1
      this.paint()
      if (this.alive) {
        this.kick()
      }
    }, 32)
  }

  private stopClock(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer)
      this.timer = -1
    }
  }

  private paint(): void {
    if (!this.ready || this.painting) {
      return
    }
    this.painting = true
    const ctx = this.context
    const w = ctx.width
    const h = ctx.height
    if (w < 8 || h < 8) {
      this.painting = false
      return
    }
    ctx.clearRect(0, 0, w, h)
    const logical = this.orbSize
    const dpr = w / logical
    const t = ((Date.now() - this.startMs) / 1000) * ThinkingOrbEngine.speedOf(this.orbState)
    const dots = this.engine.fillFrame(logical, t, this.orbState)
    const dark = this.theme.isDarkCanvas()
    const n = this.engine.usedCount()
    let lastStyle = ''
    for (let i = 0; i < n; i++) {
      const d: OrbDot = dots[i]
      if (d.a < 0.06) {
        continue
      }
      const style = ThinkingOrbEngine.inkRgba(d.white, d.a, dark)
      if (style !== lastStyle) {
        ctx.fillStyle = style
        lastStyle = style
      }
      ctx.beginPath()
      ctx.arc(d.x * dpr, d.y * dpr, d.r * dpr, 0, Math.PI * 2)
      ctx.fill()
    }
    this.painting = false
  }

  build() {
    Canvas(this.context)
      .width(this.orbSize)
      .height(this.orbSize)
      .hitTestBehavior(HitTestMode.None)
      .onReady(() => {
        this.ready = true
        this.paint()
      })
  }
}
