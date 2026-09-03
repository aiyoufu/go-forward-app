import { MotionTokens } from './MotionTokens'

/**
 * 动效辅助 — 对齐 bpta-fair-use-animation
 * - 金额/柱图：帧驱动（系统 animateTo 对自定义进度不够稳时）
 * - 列表缓现：由页面用系统 animateTo 驱动，见 softReveal 约定
 */
export class MotionHelper {
  /**
   * 0→1 进度；easeOutQuint（快入慢收，接近阻尼）
   * 返回 cancel
   */
  static runProgress(
    durationMs: number,
    onTick: (t: number) => void,
    onDone?: () => void
  ): () => void {
    let cancelled = false
    let timer: number = -1
    const start = Date.now()
    const dur = durationMs > 0 ? durationMs : MotionTokens.countDuration

    const step = (): void => {
      if (cancelled) {
        return
      }
      const raw = (Date.now() - start) / dur
      const t = raw >= 1 ? 1 : (raw <= 0 ? 0 : raw)
      const inv = 1 - t
      const eased = 1 - inv * inv * inv * inv * inv
      onTick(eased)
      if (t < 1) {
        timer = setTimeout(step, 16)
      } else if (onDone) {
        onDone()
      }
    }
    timer = setTimeout(step, 16)
    return (): void => {
      cancelled = true
      if (timer !== -1) {
        clearTimeout(timer)
        timer = -1
      }
    }
  }

  /**
   * 列表逐项缓现约定（页面侧实现，见 entry ListReveal）：
   * 1) 显式初值 revealT=0（每项 opacity=0 + translateY=offset，无动画）
   * 2) 下一帧起播全局进度 t 0->1，每项按 index 错峰、局部 EaseOut
   * 3) 离开页/Tab：无动画复位初值（用户不可见，不闪）
   * 4) 滚动懒挂载的行按当前进度取值；滚动、同页刷新：不重播
   * 禁止：可见态闪灭再播
   */
  static readonly LIST_REVEAL_FRAME_MS: number = 16

  /**
   * 校验失败抖动：逐步改写水平位移，页面侧用 .translate({ x }) 消费
   * 每步 MotionTokens.shakeStepDuration，幅度递减收敲于 0
   */
  static shake(ctx: UIContext, setter: (x: number) => void): void {
    const step = MotionTokens.shakeStepDuration
    const offsets: number[] = [4, -4, 3, -3, 1, 0]
    offsets.forEach((offset: number, i: number) => {
      setTimeout(() => {
        ctx.animateTo({ duration: step, curve: Curve.Linear }, () => {
          setter(offset)
        })
      }, i * step)
    })
  }

  /**
   * NavDestination 自定义转场（优化4）：进入微弱右推入+淡入，退出反向，底页视差让位
   * 页面侧：@State x/alpha + 根 NavDestination .translate/.opacity/.customTransition 消费
   * 未覆盖的操作（REPLACE 等）返回 undefined 走系统默认转场
   */
  static navPageTransition(
    operation: NavigationOperation,
    isEnter: boolean,
    setter: (x: number, alpha: number) => void
  ): Array<NavDestinationTransition> | undefined {
    if (operation === NavigationOperation.PUSH && isEnter) {
      // 新页进入：同步置起点（右移+全透明，无动画），再动画推回原位
      setter(MotionTokens.pageEnterOffsetX, 0)
      const enter: NavDestinationTransition = {
        duration: MotionTokens.pageTransitionDuration,
        curve: Curve.EaseOut,
        event: () => {
          setter(0, 1)
        }
      }
      return [enter]
    }
    if (operation === NavigationOperation.PUSH && !isEnter) {
      // 底页让位：微弱左移视差，保持可见
      const yield_: NavDestinationTransition = {
        duration: MotionTokens.pageTransitionDuration,
        curve: Curve.EaseOut,
        event: () => {
          setter(-MotionTokens.pageParallaxOffsetX, 1)
        }
      }
      return [yield_]
    }
    if (operation === NavigationOperation.POP && isEnter) {
      // 底页归位
      const back: NavDestinationTransition = {
        duration: MotionTokens.pageTransitionDuration,
        curve: Curve.EaseOut,
        event: () => {
          setter(0, 1)
        }
      }
      return [back]
    }
    if (operation === NavigationOperation.POP && !isEnter) {
      // 顶页退出：右移+淡出
      const exit: NavDestinationTransition = {
        duration: MotionTokens.pageTransitionDuration,
        curve: Curve.EaseIn,
        event: () => {
          setter(MotionTokens.pageEnterOffsetX, 0)
        }
      }
      return [exit]
    }
    return undefined
  }
}
