import { describe, it, expect, beforeAll, afterAll } from '@ohos/hypium'
import testsuite from './List.test'

export default function abilityTest() {
  describe('CommonModuleTest', () => {
    beforeAll(() => {})
    afterAll(() => {})
    it('infrastructure_check', 0, async () => {
      expect(1).assertEqual(1)
    })
  })
  testsuite()
}
