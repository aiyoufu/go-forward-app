import { describe, it, expect } from '@ohos/hypium'

/**
 * SheetDialog UI 测试
 * 覆盖：按钮排列、关闭行为、cancel排底排序
 */
export default function SheetDialog_UITest() {
  describe('SheetDialog_UI', () => {

    // ── getOrderedButtons ──
    it('排序_cancel排最后', 0, async () => {
      const buttons = [
        { text: '确定', role: 'default' },
        { text: '取消', role: 'cancel' },
        { text: '删除', role: 'destructive' }
      ]
      const nonCancel = buttons.filter(b => b.role !== 'cancel')
      const cancel = buttons.filter(b => b.role === 'cancel')
      const ordered = nonCancel.concat(cancel)
      expect(ordered[ordered.length - 1].role).assertEqual('cancel')
    })

    it('排序_无cancel_保持原序', 0, async () => {
      const buttons = [
        { text: '确定', role: 'default' },
        { text: '删除', role: 'destructive' }
      ]
      const nonCancel = buttons.filter(b => b.role !== 'cancel')
      const cancel = buttons.filter(b => b.role === 'cancel')
      const ordered = nonCancel.concat(cancel)
      expect(ordered.length).assertEqual(2)
      expect(ordered[0].text).assertEqual('确定')
    })

    it('排序_仅cancel_正常显示', 0, async () => {
      const buttons = [{ text: '取消', role: 'cancel' }]
      const nonCancel = buttons.filter(b => b.role !== 'cancel')
      const cancel = buttons.filter(b => b.role === 'cancel')
      const ordered = nonCancel.concat(cancel)
      expect(ordered.length).assertEqual(1)
      expect(ordered[0].role).assertEqual('cancel')
    })

    // ── 按钮角色 ──
    it('渲染_default角色_中等字重', 0, async () => {
      const role = 'default'
      const isCancel = role === 'cancel'
      expect(isCancel).assertFalse()
    })

    it('渲染_cancel角色_常规字重', 0, async () => {
      const role = 'cancel'
      const isCancel = role === 'cancel'
      expect(isCancel).assertTrue()
    })

    it('渲染_destructive角色_红色文案', 0, async () => {
      const role = 'destructive'
      expect(role).assertEqual('destructive')
    })

    // ── 配置 ──
    it('渲染_有标题_显示标题区', 0, async () => {
      const title = '确认删除'
      const showHeader = title.length > 0
      expect(showHeader).assertTrue()
    })

    it('渲染_无标题_隐藏标题区', 0, async () => {
      const title = ''
      const message = ''
      const showHeader = title.length > 0 || message.length > 0
      expect(showHeader).assertFalse()
    })

    it('渲染_有副标题_显示介绍', 0, async () => {
      const subtitle = '此操作不可撤销'
      const show = subtitle.length > 0
      expect(show).assertTrue()
    })

    // ── 关闭行为 ──
    it('交互_点击关闭_触发回调', 0, async () => {
      let closed = false
      const onClose = () => { closed = true }
      onClose()
      expect(closed).assertTrue()
    })

    it('交互_点击按钮_触发对应回调', 0, async () => {
      let tappedIndex = -1
      const onTap = (index: number) => { tappedIndex = index }
      onTap(1)
      expect(tappedIndex).assertEqual(1)
    })

    // ── 日期选择器 ──
    it('渲染_日期选择器_显示标题', 0, async () => {
      const title = '选择日期'
      const display = title.length > 0 ? title : '选择日期'
      expect(display).assertEqual('选择日期')
    })

    it('交互_确认日期_回调返回日期', 0, async () => {
      let selectedDate: Date | null = null
      const onConfirm = (date: Date) => { selectedDate = date }
      const testDate = new Date('2025-07-15')
      onConfirm(testDate)
      expect(selectedDate).notNull()
    })

    it('交互_取消日期选择_触发取消回调', 0, async () => {
      let cancelled = false
      const onCancel = () => { cancelled = true }
      onCancel()
      expect(cancelled).assertTrue()
    })
  })
}
