import { describe, it, expect } from '@ohos/hypium'
import { MotionHelper } from '../../../main/ets/common/MotionHelper'

export default function motionHelperTest() {
  describe('MotionHelper', () => {

    describe('LIST_REVEAL_FRAME_MS', () => {
      it('值为16', 0, () => {
        expect(MotionHelper.LIST_REVEAL_FRAME_MS).assertEqual(16)
      })
    })

    describe('runProgress', () => {
      it('返回cancel函数', 0, () => {
        const cancel = MotionHelper.runProgress(100, () => {})
        expect(typeof cancel).assertEqual('function')
        cancel()
      })

      it('cancel后不再回调', 0, () => {
        let tickCount = 0
        const cancel = MotionHelper.runProgress(50, () => {
          tickCount++
        })
        cancel()
        expect(tickCount).assertEqual(0)
      })

      it('onDone在完成时调用', 0, async () => {
        let done = false
        MotionHelper.runProgress(50, () => {}, () => {
          done = true
        })
        // 等待动画完成
        await new Promise<void>((resolve) => {
          setTimeout(() => {
            resolve()
          }, 150)
        })
        expect(done).assertTrue()
      })

      it('缓动值在0到1之间', 0, async () => {
        const values: number[] = []
        MotionHelper.runProgress(80, (t: number) => {
          values.push(t)
        })
        await new Promise<void>((resolve) => {
          setTimeout(() => {
            resolve()
          }, 200)
        })
        for (const v of values) {
          expect(v >= 0).assertTrue()
          expect(v <= 1).assertTrue()
        }
      })

      it('最终值为1', 0, async () => {
        let lastValue = 0
        MotionHelper.runProgress(50, (t: number) => {
          lastValue = t
        })
        await new Promise<void>((resolve) => {
          setTimeout(() => {
            resolve()
          }, 150)
        })
        expect(lastValue).assertEqual(1)
      })

      it('零或负数duration使用默认时长', 0, () => {
        const cancel1 = MotionHelper.runProgress(0, () => {})
        expect(typeof cancel1).assertEqual('function')
        cancel1()
        const cancel2 = MotionHelper.runProgress(-10, () => {})
        expect(typeof cancel2).assertEqual('function')
        cancel2()
      })
    })
  })
}
