import { ThemeColors, MotionTokens } from 'common'
import { SkeletonCard } from './SkeletonCard'

/**
 * 骨架列表（首载占位）：整块大卡容器 + count 张嵌组 SkeletonCard，与列表真实卡片形态一致
 * 不自带水平 padding，由调用处统一控制
 */
@Component
// 骨架列表封装 SkeletonCard 交错延时，跨页复用，不宜降为 @Builder
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct SkeletonList {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop count: number = 4
  /** 铺满父容器剩余高度（默认 false，按行高自然排布） */
  @Prop fillHeight: boolean = false

  private indices(): number[] {
    const arr: number[] = []
    for (let i = 0; i < this.count; i++) {
      arr.push(i)
    }
    return arr
  }

  build() {
    Column({ space: 0 }) {
      ForEach(this.indices(), (i: number) => {
        SkeletonCard({
          theme: this.theme,
          delayMs: i * MotionTokens.skeletonStagger,
          fillHeight: this.fillHeight,
          groupDivider: i < this.count - 1
        })
      }, (i: number) => 'skeleton-' + i)
    }
    .width('100%')
    .layoutWeight(this.fillHeight ? 1 : 0)
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusXl)
    .clip(true)
    // 整块大卡：组容器承担一次 float 阴影，与列表真实卡片同源
    .shadow(this.theme.floatShadowOptions())
  }
}
