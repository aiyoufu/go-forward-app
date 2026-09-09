import { describe, it, expect } from '@ohos/hypium'
import { MotionTokens } from 'common'
import {
  listItemRevealProgress,
  listItemRevealTranslateY,
  listItemRevealNoImplicit
} from '../../../../main/ets/pages/common/ListReveal'

export default function listRevealTest() {
  describe('ListReveal', () => {
    it('入场起点在槽位上方_负Y自上落下', 0, () => {
      expect(listItemRevealTranslateY(0, 0)).assertEqual(-12)
      expect(listItemRevealTranslateY(0, 5)).assertEqual(-12)
    })

    it('入场结束位移为0', 0, () => {
      expect(listItemRevealTranslateY(1, 0)).assertEqual(0)
      expect(listItemRevealTranslateY(1, 20)).assertEqual(0)
    })

    it('全程位移不为正_禁止自下抬起', 0, () => {
      const ts: number[] = [0, 0.2, 0.4, 0.6, 0.8, 1]
      const indexes: number[] = [0, 3, 8, 20]
      for (let i = 0; i < ts.length; i++) {
        for (let j = 0; j < indexes.length; j++) {
          expect(listItemRevealTranslateY(ts[i], indexes[j]) <= 0).assertTrue()
        }
      }
    })

    it('单项位移单调增至0_只往下不回落', 0, () => {
      const a = listItemRevealTranslateY(0.15, 0)
      const b = listItemRevealTranslateY(0.45, 0)
      const c = listItemRevealTranslateY(0.8, 0)
      expect(a <= b).assertTrue()
      expect(b <= c).assertTrue()
      expect(c <= 0).assertTrue()
    })

    it('错峰自上而下_先到项更接近槽位', 0, () => {
      const t = 100 / MotionTokens.listItemRevealTotal()
      const y0 = listItemRevealTranslateY(t, 0)
      const y3 = listItemRevealTranslateY(t, 3)
      expect(listItemRevealProgress(t, 0) > listItemRevealProgress(t, 3)).assertTrue()
      expect(y0 > y3).assertTrue()
    })

    it('进度边界_0与1', 0, () => {
      expect(listItemRevealProgress(0, 0)).assertEqual(0)
      expect(listItemRevealProgress(1, 0)).assertEqual(1)
      expect(listItemRevealProgress(1, 20)).assertEqual(1)
    })

    it('列表禁止隐式插值', 0, () => {
      const param = listItemRevealNoImplicit()
      expect(param.duration === 0).assertTrue()
    })
  })
}
