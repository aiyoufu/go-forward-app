import { describe, it, expect } from '@ohos/hypium'
import { RetryHelper } from '../../../../main/ets/service/RetryHelper'

export default function retryHelperTest() {
  describe('RetryHelper_run', () => {
    it('第一次成功', 0, async () => {
      let calls = 0
      const result = await RetryHelper.run<number>(
        async () => { calls++; return 42 },
        (v: number) => v === 42,
        0,
        () => 0,
        3
      )
      expect(result).assertEqual(42)
      expect(calls).assertEqual(1)
    })
    it('第二次成功', 0, async () => {
      let calls = 0
      const result = await RetryHelper.run<number>(
        async () => {
          calls++
          return calls >= 2 ? 42 : 0
        },
        (v: number) => v === 42,
        -1,
        () => 0,
        3
      )
      expect(result).assertEqual(42)
      expect(calls).assertEqual(2)
    })
    it('重试耗尽_返回最后一次结果', 0, async () => {
      let calls = 0
      const result = await RetryHelper.run<number>(
        async () => { calls++; return 0 },
        (v: number) => v === 42,
        -1,
        () => 0,
        3
      )
      expect(result).assertEqual(0)
      expect(calls).assertEqual(3)
    })
    it('maxAttempts=1_只尝试一次', 0, async () => {
      let calls = 0
      const result = await RetryHelper.run<number>(
        async () => { calls++; return 0 },
        (v: number) => v === 42,
        -1,
        () => 0,
        1
      )
      expect(result).assertEqual(0)
      expect(calls).assertEqual(1)
    })
    it('退避间隔被调用', 0, async () => {
      const backoffs: number[] = []
      await RetryHelper.run<number>(
        async () => 0,
        (v: number) => false,
        -1,
        (attempt: number) => { backoffs.push(attempt); return 0 },
        3
      )
      expect(backoffs.length).assertEqual(2)
      expect(backoffs[0]).assertEqual(0)
      expect(backoffs[1]).assertEqual(1)
    })
    it('shouldStop立即返回_不重试', 0, async () => {
      let calls = 0
      const result = await RetryHelper.run<string>(
        async () => { calls++; return 'done' },
        (v: string) => v === 'done',
        'fallback',
        () => 0,
        5
      )
      expect(result).assertEqual('done')
      expect(calls).assertEqual(1)
    })
  })
}
