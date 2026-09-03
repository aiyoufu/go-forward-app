import { ThemeColors } from 'common'

/** 纯函数：已填充段数 */
export function filledCount(progress: number, segmentCount: number): number {
  const p = Math.max(0, Math.min(100, progress))
  return Math.round((p / 100) * segmentCount)
}

/** 纯函数：构建索引数组 */
export function rebuildIndices(segmentCount: number): number[] {
  const arr: number[] = []
  const n = segmentCount > 0 ? segmentCount : 24
  for (let i = 0; i < n; i++) {
    arr.push(i)
  }
  return arr
}

/**
 * 分段进度条（单色版）
 * - 已完成段：primary（reverse）
 * - 未完成段：chip
 */
@Component
export struct SegmentProgressBar {
  @Prop progress: number = 0
  @Prop segmentCount: number = 28
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop solidColor: string = ''
  @Prop unfilledColor: string = ''
  @Prop segWidth: number = 5
  @Prop segHeight: number = 22
  @Prop segRadius: number = 1
  @State private actualSegmentCount: number = 24
  @State private indices: number[] = []

  aboutToAppear() {
    this.actualSegmentCount = this.segmentCount > 0 ? this.segmentCount : 24
    this.rebuildIndices()
  }

  private rebuildIndices(): void {
    this.indices = rebuildIndices(this.actualSegmentCount)
  }

  private filledCount(): number {
    return filledCount(this.progress, this.actualSegmentCount)
  }

  private getUnfilledColor(): string {
    if (this.unfilledColor.length > 0) {
      return this.unfilledColor
    }
    return '' + this.theme.chip
  }

  private colorAt(index: number, filled: number): string {
    if (index >= filled) {
      return this.getUnfilledColor()
    }
    if (this.solidColor.length > 0) {
      return this.solidColor
    }
    return '' + this.theme.primary
  }

  build() {
    Row({ space: 2.5 }) {
      ForEach(this.indices, (i: number) => {
        Column()
          .width(this.segWidth)
          .height(this.segHeight)
          .borderRadius(this.segRadius)
          .backgroundColor(this.colorAt(i, this.filledCount()))
      }, (i: number) => 'seg-' + i)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .onAreaChange((oldArea: Area, newArea: Area) => {
      const width = Number(newArea.width)
      if (width > 0) {
        const segWidth = this.segWidth
        const gap = 3
        const count = Math.floor((width + gap) / (segWidth + gap))
        if (count > 0 && count !== this.actualSegmentCount) {
          this.actualSegmentCount = count
          this.rebuildIndices()
        }
      }
    })
  }
}
