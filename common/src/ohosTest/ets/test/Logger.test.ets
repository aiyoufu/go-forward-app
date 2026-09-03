import { describe, it, expect } from '@ohos/hypium'
import { Logger } from '../../../main/ets/common/Logger'

export default function loggerTest() {
  describe('Logger', () => {
    it('info不抛', 0, () => {
      Logger.info('Test', 'hello')
      expect(true).assertTrue()
    })
    it('warn不抛', 0, () => {
      Logger.warn('Test', 'warn')
      expect(true).assertTrue()
    })
    it('error不抛', 0, () => {
      Logger.error('Test', 'err')
      expect(true).assertTrue()
    })
  })
}
