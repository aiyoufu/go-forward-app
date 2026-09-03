import { describe, it, expect } from '@ohos/hypium'
import { filledCount, rebuildIndices } from '../../../main/ets/components/SegmentProgressBar'

export default function SegmentProgressBarTest() {
  describe('filledCount', () => {
    it('0%_返回0', 0, async () => {
      expect(filledCount(0, 28)).assertEqual(0)
    })
    it('100%_返回全部', 0, async () => {
      expect(filledCount(100, 28)).assertEqual(28)
    })
    it('50%_返回一半', 0, async () => {
      expect(filledCount(50, 28)).assertEqual(14)
    })
    it('负数_截断为0', 0, async () => {
      expect(filledCount(-10, 28)).assertEqual(0)
    })
    it('超100_截断为100', 0, async () => {
      expect(filledCount(150, 28)).assertEqual(28)
    })
    it('小段数', 0, async () => {
      expect(filledCount(50, 4)).assertEqual(2)
    })
  })

  describe('rebuildIndices', () => {
    it('正常数量', 0, async () => {
      const arr = rebuildIndices(5)
      expect(arr.length).assertEqual(5)
      expect(arr[0]).assertEqual(0)
      expect(arr[4]).assertEqual(4)
    })
    it('0_回退到24', 0, async () => {
      const arr = rebuildIndices(0)
      expect(arr.length).assertEqual(24)
    })
    it('负数_回退到24', 0, async () => {
      const arr = rebuildIndices(-1)
      expect(arr.length).assertEqual(24)
    })
    it('1', 0, async () => {
      const arr = rebuildIndices(1)
      expect(arr.length).assertEqual(1)
    })
  })
}
