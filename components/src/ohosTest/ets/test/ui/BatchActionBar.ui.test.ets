import { describe, it, expect } from '@ohos/hypium'

export default function batchActionBarUITest() {
  describe('BatchActionBar_UI', () => {
    it('选中0时禁用删除', 0, () => {
      let selected: number = 0
      const canDelete = selected > 0
      expect(canDelete).assertFalse()
    })
    it('选中大于0可删', 0, () => {
      const selected = 2
      expect(selected > 0).assertTrue()
    })
  })
}
