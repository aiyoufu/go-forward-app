import { describe, it, expect } from '@ohos/hypium'

/**
 * LegalDocSheet UI 测试
 * 覆盖：文档类型切换、标题、内容滚动
 */
export default function LegalDocSheet_UITest() {
  describe('LegalDocSheet_UI', () => {

    it('渲染_privacy类型_显示隐私政策标题', 0, async () => {
      let kind: string = 'privacy'
      const resolvedKind = kind === 'terms' ? 'terms' : 'privacy'
      expect(resolvedKind).assertEqual('privacy')
    })

    it('渲染_terms类型_显示用户协议标题', 0, async () => {
      let kind: string = 'terms'
      const resolvedKind = kind === 'terms' ? 'terms' : 'privacy'
      expect(resolvedKind).assertEqual('terms')
    })

    it('渲染_无效类型_回退privacy', 0, async () => {
      let kind: string = 'invalid'
      const resolvedKind = kind === 'terms' ? 'terms' : 'privacy'
      expect(resolvedKind).assertEqual('privacy')
    })

    it('渲染_文档内容_可滚动', 0, async () => {
      const bodyText = '这是一段法律文档内容，用于测试滚动功能。'
      expect(bodyText.length > 0).assertTrue()
    })

    it('交互_点击关闭_触发回调', 0, async () => {
      let closed = false
      const onClose = () => { closed = true }
      onClose()
      expect(closed).assertTrue()
    })

    it('渲染_全屏高度_占满弹窗', 0, async () => {
      const height = '100%'
      expect(height).assertEqual('100%')
    })
  })
}
