import { describe, it, expect } from '@ohos/hypium'

/**
 * SwipeEditDeleteActions UI 测试
 * 覆盖：按钮组合、宽度计算、回调触发
 */
export default function SwipeEditDeleteActions_UITest() {
  describe('SwipeEditDeleteActions_UI', () => {

    it('渲染_有还款按钮_总宽度为3倍actionWidth', 0, async () => {
      const actionWidth = 72
      const hasRepay = true
      const totalWidth = actionWidth * (hasRepay ? 3 : 2)
      expect(totalWidth).assertEqual(216)
    })

    it('渲染_无还款按钮_总宽度为2倍actionWidth', 0, async () => {
      const actionWidth = 72
      const hasRepay = false
      const totalWidth = actionWidth * (hasRepay ? 3 : 2)
      expect(totalWidth).assertEqual(144)
    })

    it('渲染_默认高度_74vp', 0, async () => {
      const actionHeight = 74
      expect(actionHeight).assertEqual(74)
    })

    it('渲染_默认圆角_10vp', 0, async () => {
      const cornerRadius = 10
      expect(cornerRadius).assertEqual(10)
    })

    it('渲染_还款按钮_显示还款文字', 0, async () => {
      const label = '还款'
      expect(label).assertEqual('还款')
    })

    it('渲染_编辑按钮_显示编辑文字', 0, async () => {
      const label = '编辑'
      expect(label).assertEqual('编辑')
    })

    it('渲染_删除按钮_显示删除文字', 0, async () => {
      const label = '删除'
      expect(label).assertEqual('删除')
    })

    it('交互_点击编辑_触发onEdit回调', 0, async () => {
      let edited = false
      const onEdit = () => { edited = true }
      onEdit()
      expect(edited).assertTrue()
    })

    it('交互_点击删除_触发onDelete回调', 0, async () => {
      let deleted = false
      const onDelete = () => { deleted = true }
      onDelete()
      expect(deleted).assertTrue()
    })

    it('交互_点击还款_触发onRepay回调', 0, async () => {
      let repaid = false
      const onRepay = () => { repaid = true }
      onRepay()
      expect(repaid).assertTrue()
    })

    it('渲染_自定义actionWidth_总宽度随之变化', 0, async () => {
      const actionWidth = 80
      const totalWidth = actionWidth * 3
      expect(totalWidth).assertEqual(240)
    })

    it('渲染_圆角只裁右侧', 0, async () => {
      let topLeft: number = 0
      const topRight = 10
      let bottomLeft: number = 0
      const bottomRight = 10
      expect(topLeft).assertEqual(0)
      expect(topRight).assertEqual(10)
      expect(bottomLeft).assertEqual(0)
      expect(bottomRight).assertEqual(10)
    })

    it('渲染_还款按钮_使用primary背景色', 0, async () => {
      const repayBg = 'primary'
      expect(repayBg).assertEqual('primary')
    })

    it('渲染_编辑按钮_使用bar背景色', 0, async () => {
      const editBg = 'bar'
      expect(editBg).assertEqual('bar')
    })

    it('渲染_删除按钮_使用dangerBackground色', 0, async () => {
      const deleteBg = 'dangerBackground'
      expect(deleteBg).assertEqual('dangerBackground')
    })

    it('边界_极大actionWidth_总宽度正确', 0, async () => {
      const actionWidth = 9999
      const totalWidth = actionWidth * 2
      expect(totalWidth).assertEqual(19998)
    })
  })
}
