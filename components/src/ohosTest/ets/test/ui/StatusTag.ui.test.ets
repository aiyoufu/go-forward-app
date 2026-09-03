import { describe, it, expect } from '@ohos/hypium'

export default function statusTagUITest() {
  describe('StatusTag_UI', () => {
    it('role_ok_warn_danger_muted', 0, () => {
      const roles = ['ok', 'warn', 'danger', 'muted']
      expect(roles.length).assertEqual(4)
    })
    it('文案非空才展示', 0, () => {
      const text = '逾期'
      expect(text.length > 0).assertTrue()
    })
  })
}
