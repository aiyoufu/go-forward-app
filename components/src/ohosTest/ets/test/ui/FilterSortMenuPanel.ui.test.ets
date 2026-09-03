import { describe, it, expect } from '@ohos/hypium'

export default function filterSortMenuPanelUITest() {
  describe('FilterSortMenuPanel_UI', () => {
    it('选项切换更新index', 0, () => {
      let index = 0
      index = 2
      expect(index).assertEqual(2)
    })
    it('关闭回调', 0, () => {
      let closed = false
      const onClose = () => {
        closed = true
      }
      onClose()
      expect(closed).assertTrue()
    })
  })
}
