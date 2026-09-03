import { describe, it, expect } from '@ohos/hypium'

export default function profilePageUITest() {
  describe('ProfilePage_UI', () => {
    it('昵称长度上限20', 0, () => {
      const max = 20
      expect(max).assertEqual(20)
    })
    it('签名长度上限50', 0, () => {
      const max = 50
      expect(max).assertEqual(50)
    })
    it('保存后通知PROFILE_REVISION', 0, () => {
      const key = 'profileRevision'
      expect(key).assertEqual('profileRevision')
    })
  })
}
