import { describe, it, expect } from '@ohos/hypium'
import { HomeSubtitleComposer } from '../../main/ets/common/HomeSubtitleComposer'

export default function homeSubtitleComposerTest() {
  describe('HomeSubtitleComposer', () => {
    it('组合容量大于一千', 0, () => {
      expect(HomeSubtitleComposer.capacity() > 1000).assertTrue()
    })

    it('composeAt覆盖容量且非空', 0, () => {
      const n = HomeSubtitleComposer.capacity()
      const first = HomeSubtitleComposer.composeAt(0)
      const mid = HomeSubtitleComposer.composeAt(Math.floor(n / 2))
      const last = HomeSubtitleComposer.composeAt(n - 1)
      const wrap = HomeSubtitleComposer.composeAt(n)
      expect(first.length >= 4).assertTrue()
      expect(mid.length >= 4).assertTrue()
      expect(last.length >= 4).assertTrue()
      expect(wrap).assertEqual(first)
    })

    it('三句式样例可读', 0, () => {
      const three = HomeSubtitleComposer.WHEN[0] + '，' +
        HomeSubtitleComposer.ACT[0] + '，' + HomeSubtitleComposer.CLOSE[0]
      expect(HomeSubtitleComposer.isComposed(three)).assertTrue()
      const also = HomeSubtitleComposer.WHEN[0] + '也' + HomeSubtitleComposer.ACT[0]
      expect(HomeSubtitleComposer.isComposed(also)).assertTrue()
      const pair = HomeSubtitleComposer.ACT[0] + '，' + HomeSubtitleComposer.CLOSE[0]
      expect(HomeSubtitleComposer.isComposed(pair)).assertTrue()
    })

    it('空文本不是组合句', 0, () => {
      expect(HomeSubtitleComposer.isComposed('')).assertFalse()
    })

    it('抽样句不含金额与负债词', 0, () => {
      const n = HomeSubtitleComposer.capacity()
      const step = 37
      for (let i = 0; i < n; i += step) {
        const s = HomeSubtitleComposer.composeAt(i)
        expect(s.indexOf('¥') < 0).assertTrue()
        expect(s.indexOf('逾期') < 0).assertTrue()
        expect(s.indexOf('负债') < 0).assertTrue()
      }
    })
  })
}
