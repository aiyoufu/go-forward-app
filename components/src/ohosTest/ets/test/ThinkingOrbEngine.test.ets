import { describe, it, expect } from '@ohos/hypium'
import { ThinkingOrbEngine } from '../../main/ets/components/ThinkingOrbEngine'

export default function thinkingOrbEngineTest() {
  describe('ThinkingOrbEngine', () => {
    it('hashD落在0到1', 0, () => {
      const h = ThinkingOrbEngine.hashD(3, 1.7)
      expect(h >= 0 && h < 1).assertTrue()
    })

    it('radiusScale随尺寸增大', 0, () => {
      expect(ThinkingOrbEngine.radiusScale(64) > ThinkingOrbEngine.radiusScale(20)).assertTrue()
    })

    it('frameOrbits产出可见点', 0, () => {
      const dots = ThinkingOrbEngine.frameOrbits(64, 0.5)
      expect(dots.length).assertEqual(ThinkingOrbEngine.EXPECTED_DOTS)
      expect(dots[0].r >= ThinkingOrbEngine.R_MIN).assertTrue()
    })

    it('frameGlobe产出扫描点', 0, () => {
      const dots = ThinkingOrbEngine.frameGlobe(64, 0.4)
      expect(dots.length > 40).assertTrue()
    })

    it('frameWave产出波形点', 0, () => {
      const dots = ThinkingOrbEngine.frameWave(64, 0.4)
      expect(dots.length > 40).assertTrue()
    })

    it('speedOf按态取值', 0, () => {
      expect(ThinkingOrbEngine.speedOf('listening') > ThinkingOrbEngine.speedOf('working')).assertTrue()
      expect(ThinkingOrbEngine.speedOf('searching') > 1).assertTrue()
    })

    it('inkRgba深浅反相', 0, () => {
      const light = ThinkingOrbEngine.inkRgba(0, 1, false)
      const dark = ThinkingOrbEngine.inkRgba(0, 1, true)
      expect(light.indexOf('rgba(0,0,0,') === 0).assertTrue()
      expect(dark.indexOf('rgba(255,255,255,') === 0).assertTrue()
    })
  })
}
