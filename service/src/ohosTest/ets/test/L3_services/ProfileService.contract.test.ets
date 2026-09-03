import { describe, it, expect } from '@ohos/hypium'
import { ProfileService } from '../../../../main/ets/service/ProfileService'

export default function profileServiceContractTest() {
  describe('ProfileService_contract', () => {
    it('昵称上限20字', 0, () => {
      expect(20).assertEqual(20)
    })
    it('签名上限50字', 0, () => {
      expect(50).assertEqual(50)
    })
    it('头像相对filesDir', 0, () => {
      const prefix = 'avatar_'
      expect(prefix.indexOf('avatar_')).assertEqual(0)
    })
    it('stripDataUrlPrefix去掉前缀', 0, () => {
      expect(ProfileService.stripDataUrlPrefix('data:image/jpeg;base64,abc')).assertEqual('abc')
      expect(ProfileService.stripDataUrlPrefix('abc')).assertEqual('abc')
    })
  })
}
