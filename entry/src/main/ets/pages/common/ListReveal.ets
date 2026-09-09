/**
 * 列表 Tab 公共动效（三列表 Tab 去重）
 * 逐项缓现（Apple per-row 模型）：列表不整体动，行按 index 错峰各自入场
 * - 仅 opacity + translate（图形变换）；全局进度线性推进，每项局部 EaseOut
 * - 位移自上落下（负 Y → 0），波从顶部往下展开；禁止自下抬起 / 过冲回落
 * - revealT 等 @State 值由页面持有；本文件只管 timer 生命周期与进度换算
 */
import { MotionTokens, MotionHelper } from 'common'

export class ListReveal {
  private timer: number = -1

  cancel(): void {
    if (this.timer !== -1) {
      clearTimeout(this.timer)
      this.timer = -1
    }
  }

  /** 离开 Tab：静默复位初值（用户看不见，不闪） */
  resetSilent(apply: (t: number) => void): void {
    this.cancel()
    apply(0)
  }

  /**
   * 进入 Tab：t 0->1 线性推进（错峰与局部缓动在 listItemRevealProgress 内算），
   * 下一帧起播，保证显式初值（revealT=0）先渲染。
   * 必须帧驱动：animateTo 只会插值起止视觉值，错峰函数不会每帧重算。
   */
  softReveal(apply: (t: number) => void): void {
    this.cancel()
    apply(0)
    const total = MotionTokens.listItemRevealTotal()
    const start = Date.now()
    const step = (): void => {
      this.timer = -1
      const raw = (Date.now() - start) / total
      apply(raw >= 1 ? 1 : raw)
      if (raw < 1) {
        this.timer = setTimeout(step, MotionHelper.LIST_REVEAL_FRAME_MS)
      }
    }
    this.timer = setTimeout(step, MotionHelper.LIST_REVEAL_FRAME_MS)
  }
}

/** 全局揭示进度 t∈[0,1] 下第 index 项的局部入场比例（封顶错峰 + 每项 EaseOutCubic） */
export function listItemRevealProgress(t: number, index: number): number {
  const local = (t * MotionTokens.listItemRevealTotal() - MotionTokens.listItemRevealDelay(index)) /
    MotionTokens.listItemRevealDuration
  const p = local >= 1 ? 1 : (local <= 0 ? 0 : local)
  const inv = 1 - p
  return 1 - inv * inv * inv
}

/**
 * 第 index 项在进度 t 下的自上落下位移（入场结束后为 0）
 * 起点为负 Y（在槽位上方），随进度单调增至 0 —— 只往下，不抬起、不过冲。
 */
export function listItemRevealTranslateY(t: number, index: number): number {
  return (listItemRevealProgress(t, index) - 1) * MotionTokens.listItemRevealOffsetY
}

/** 切入 Tab 时无动画回顶，避免 Spring 过冲造成「上移再落下」 */
export function scrollListToTopSilent(scroller: Scroller): void {
  try {
    scroller.scrollTo({ xOffset: 0, yOffset: 0, animation: false })
  } catch (_err) {
  }
}

/** 列表禁止隐式布局插值，避免插入时过冲回落；不影响行侧滑 */
export function listItemRevealNoImplicit(): AnimateParam {
  return { duration: MotionTokens.instantDuration }
}

/** hero 数字滚动播放器（进入 Tab / 数据刷新时的计数动画） */
export class HeroCounter {
  private cancelFn: (() => void) | null = null

  play(apply: (t: number) => void): void {
    this.cancel()
    apply(0)
    this.cancelFn = MotionHelper.runProgress(MotionTokens.countDuration, apply, () => {
      this.cancelFn = null
      apply(1)
    })
  }

  cancel(): void {
    if (this.cancelFn !== null) {
      this.cancelFn()
      this.cancelFn = null
    }
  }
}

/** 顶栏磨砂渐变比例：滚动驱动 0->1；变化低于阈值时返回原值避免高频刷新 */
export function topBarFadeRatio(yOffset: number, fadeDistance: number, currentAlpha: number): number {
  let ratio = yOffset / fadeDistance
  ratio = ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio)
  if (Math.abs(ratio - currentAlpha) > 0.01 || ((ratio === 0 || ratio === 1) && ratio !== currentAlpha)) {
    return ratio
  }
  return currentAlpha
}

/** 列表项退场转场（左滑位移 + 淡出） */
export function listExitTransition(): TransitionEffect {
  return TransitionEffect.asymmetric(
    TransitionEffect.IDENTITY,
    TransitionEffect.OPACITY
      .combine(TransitionEffect.translate({ x: -MotionTokens.listItemExitOffsetX }))
      .animation({ duration: MotionTokens.listItemExitDuration, curve: Curve.EaseOut })
  )
}
