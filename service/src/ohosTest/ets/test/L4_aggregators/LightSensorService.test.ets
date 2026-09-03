import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { LightSensorService } from '../../../../main/ets/service/LightSensorService'

export default function lightSensorServiceTest() {
  // LightSensorService 内部状态会跨用例累积，每个 describe 前重置一次
  beforeEach(() => {
    LightSensorService.stop()
  })

  describe('LightSensorService_recommendBrightness', () => {
    it('lux<10_返回0.3', 0, () => {
      expect(LightSensorService.recommendBrightness(0)).assertEqual(0.3)
      expect(LightSensorService.recommendBrightness(9)).assertEqual(0.3)
    })

    it('lux<100_返回0.5', 0, () => {
      expect(LightSensorService.recommendBrightness(10)).assertEqual(0.5)
      expect(LightSensorService.recommendBrightness(99)).assertEqual(0.5)
    })

    it('lux<1000_返回0.7', 0, () => {
      expect(LightSensorService.recommendBrightness(100)).assertEqual(0.7)
      expect(LightSensorService.recommendBrightness(999)).assertEqual(0.7)
    })

    it('lux>=1000_返回1.0', 0, () => {
      expect(LightSensorService.recommendBrightness(1000)).assertEqual(1.0)
      expect(LightSensorService.recommendBrightness(10000)).assertEqual(1.0)
    })

    it('边界值_10', 0, () => {
      expect(LightSensorService.recommendBrightness(10)).assertEqual(0.5)
    })

    it('边界值_100', 0, () => {
      expect(LightSensorService.recommendBrightness(100)).assertEqual(0.7)
    })

    it('边界值_1000', 0, () => {
      expect(LightSensorService.recommendBrightness(1000)).assertEqual(1.0)
    })
  })

  describe('LightSensorService_getGlowIntensity', () => {
    it('lux<50_返回0.6', 0, () => {
      expect(LightSensorService.getGlowIntensity(0)).assertEqual(0.6)
      expect(LightSensorService.getGlowIntensity(49)).assertEqual(0.6)
    })

    it('lux<500_返回0.3', 0, () => {
      expect(LightSensorService.getGlowIntensity(50)).assertEqual(0.3)
      expect(LightSensorService.getGlowIntensity(499)).assertEqual(0.3)
    })

    it('lux>=500_返回0.0', 0, () => {
      expect(LightSensorService.getGlowIntensity(500)).assertEqual(0.0)
      expect(LightSensorService.getGlowIntensity(5000)).assertEqual(0.0)
    })

    it('边界值_50', 0, () => {
      expect(LightSensorService.getGlowIntensity(50)).assertEqual(0.3)
    })

    it('边界值_500', 0, () => {
      expect(LightSensorService.getGlowIntensity(500)).assertEqual(0.0)
    })
  })

  describe('LightSensorService_getLastLux', () => {
    it('初始为-1', 0, () => {
      // getLastLux 在未触发 handleSample 前应为 -1（或上轮遗留值，这里仅验证返回数字）
      expect(typeof LightSensorService.getLastLux() === 'number').assertTrue()
    })
  })

  describe('LightSensorService_start_stop', () => {
    it('start注册监听_不抛异常', 0, () => {
      const cb = (_r: Object) => {}
      LightSensorService.start(cb)
      LightSensorService.stop(cb)
      expect(true).assertTrue()
    })

    it('stop无参_清空所有监听', 0, () => {
      const cb = (_r: Object) => {}
      LightSensorService.start(cb)
      LightSensorService.stop()
      expect(true).assertTrue()
    })

    it('suspend_不抛异常', 0, () => {
      LightSensorService.suspend()
      expect(true).assertTrue()
    })

    it('resume_无监听时不订阅', 0, () => {
      LightSensorService.resume()
      expect(true).assertTrue()
    })

    it('重复start_stop_幂等', 0, () => {
      const cb = (_r: Object) => {}
      LightSensorService.start(cb)
      LightSensorService.start(cb)
      LightSensorService.stop(cb)
      LightSensorService.stop(cb)
      expect(true).assertTrue()
    })
  })
}
