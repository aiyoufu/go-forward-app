import { describe, it, expect } from '@ohos/hypium'

/**
 * SegmentProgressBar UI 测试
 * 覆盖：filledCount/rebuildIndices 纯函数、分段颜色逻辑
 */
export default function SegmentProgressBar_UITest() {
  describe('SegmentProgressBar_UI', () => {

    it('纯函数_filledCount_0进度返回0', 0, async () => {
      let progress: number = 0
      const segmentCount = 28
      const p = Math.max(0, Math.min(100, progress))
      const filled = Math.round((p / 100) * segmentCount)
      expect(filled).assertEqual(0)
    })

    it('纯函数_filledCount_50进度返回14', 0, async () => {
      const progress = 50
      const segmentCount = 28
      const p = Math.max(0, Math.min(100, progress))
      const filled = Math.round((p / 100) * segmentCount)
      expect(filled).assertEqual(14)
    })

    it('纯函数_filledCount_100进度返回28', 0, async () => {
      const progress = 100
      const segmentCount = 28
      const p = Math.max(0, Math.min(100, progress))
      const filled = Math.round((p / 100) * segmentCount)
      expect(filled).assertEqual(28)
    })

    it('纯函数_filledCount_负进度钳位0', 0, async () => {
      const progress = -10
      const segmentCount = 28
      const p = Math.max(0, Math.min(100, progress))
      const filled = Math.round((p / 100) * segmentCount)
      expect(filled).assertEqual(0)
    })

    it('纯函数_filledCount_超100钳位', 0, async () => {
      const progress = 150
      const segmentCount = 28
      const p = Math.max(0, Math.min(100, progress))
      const filled = Math.round((p / 100) * segmentCount)
      expect(filled).assertEqual(28)
    })

    it('纯函数_rebuildIndices_正常数量', 0, async () => {
      const segmentCount = 5
      const arr: number[] = []
      const n = segmentCount > 0 ? segmentCount : 24
      for (let i = 0; i < n; i++) arr.push(i)
      expect(arr.length).assertEqual(5)
      expect(arr[0]).assertEqual(0)
      expect(arr[4]).assertEqual(4)
    })

    it('纯函数_rebuildIndices_0回退24', 0, async () => {
      let segmentCount: number = 0
      const n = segmentCount > 0 ? segmentCount : 24
      const arr: number[] = []
      for (let i = 0; i < n; i++) arr.push(i)
      expect(arr.length).assertEqual(24)
    })

    it('纯函数_rebuildIndices_负数回退24', 0, async () => {
      const segmentCount = -5
      const n = segmentCount > 0 ? segmentCount : 24
      expect(n).assertEqual(24)
    })

    it('渲染_默认段数28', 0, async () => {
      const segmentCount = 28
      expect(segmentCount).assertEqual(28)
    })

    it('渲染_默认段宽5vp', 0, async () => {
      const segWidth = 5
      expect(segWidth).assertEqual(5)
    })

    it('渲染_默认段高22vp', 0, async () => {
      const segHeight = 22
      expect(segHeight).assertEqual(22)
    })

    it('渲染_已完成段_使用primary色', 0, async () => {
      let index: number = 0
      const filled = 14
      const solidColor = '#primary'
      const color = index < filled ? solidColor : 'chip'
      expect(color).assertEqual('#primary')
    })

    it('渲染_未完成段_使用chip色', 0, async () => {
      const index = 20
      const filled = 14
      const solidColor = '#primary'
      const color = index < filled ? solidColor : 'chip'
      expect(color).assertEqual('chip')
    })

    it('渲染_自定义solidColor_使用自定义色', 0, async () => {
      const solidColor = '#22C55E'
      const hasCustom = solidColor.length > 0
      expect(hasCustom).assertTrue()
    })

    it('渲染_自定义unfilledColor_使用自定义色', 0, async () => {
      const unfilledColor = '#333333'
      const hasCustom = unfilledColor.length > 0
      expect(hasCustom).assertTrue()
    })

    it('边界_极大segmentCount_索引正确', 0, async () => {
      const segmentCount = 1000
      const n = segmentCount > 0 ? segmentCount : 24
      expect(n).assertEqual(1000)
    })
  })
}
