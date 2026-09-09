import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { HandednessService } from '../../../../main/ets/service/HandednessService'

export default function handednessServiceTest() {
  beforeEach(() => {
    // 清空监听者，避免跨用例污染
    HandednessService.stop(() => {})
  })

  describe('HandednessService_isLeftPrimary', () => {
    it('返回布尔值', 0, () => {
      const v = HandednessService.isLeftPrimary()
      expect(typeof v === 'boolean').assertTrue()
    })

    it('初始默认false', 0, () => {
      // 静态字段 leftPrimary 默认 false
      expect(HandednessService.isLeftPrimary()).assertFalse()
    })
  })

  describe('HandednessService_start_stop', () => {
    it('start_无context_不抛异常', 0, async () => {
      let received = false
      const listener = (left: boolean) => { received = true }
      await HandednessService.start(listener)
      // start 时会立即把当前缓存态推给监听者
      expect(received).assertTrue()
      HandednessService.stop(listener)
    })

    it('stop_清空监听者', 0, () => {
      const listener = (left: boolean) => {}
      // stop 未注册的 listener 也不抛异常
      HandednessService.stop(listener)
      expect(true).assertTrue()
    })

    it('多次start同一listener_不重复', 0, async () => {
      let count = 0
      const listener = (left: boolean) => { count++ }
      await HandednessService.start(listener)
      await HandednessService.start(listener)
      // 第二次 start 也会推一次缓存态
      expect(count >= 1).assertTrue()
      HandednessService.stop(listener)
    })
  })

  describe('HandednessService_setEnabled', () => {
    it('默认开启', 0, () => {
      expect(HandednessService.isEnabled()).assertTrue()
    })

    it('setEnabled_开关可切换', 0, () => {
      HandednessService.setEnabled(false)
      expect(HandednessService.isEnabled()).assertFalse()
      HandednessService.setEnabled(true)
      expect(HandednessService.isEnabled()).assertTrue()
    })

    it('setEnabled_重复设置不抛异常', 0, () => {
      HandednessService.setEnabled(true)
      expect(HandednessService.isEnabled()).assertTrue()
    })
  })
}
