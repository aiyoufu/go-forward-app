import { describe, it, expect } from '@ohos/hypium'
import { SheetDialogButton, SheetDialogConfig, SheetDatePickerConfig, CalendarDayCell } from '../../../main/ets/components/SheetDialog'
import { getOrderedButtons, isConfirmButtonPair } from '../../../main/ets/components/SheetDialog'

export default function SheetDialogTest() {
  describe('SheetDialogButton', () => {
    it('默认构造_role为default', 0, async () => {
      const btn = new SheetDialogButton('确定', '#FFFFFF')
      expect(btn.text).assertEqual('确定')
      expect(btn.role).assertEqual('default')
      expect(btn.selected).assertFalse()
    })
    it('指定role', 0, async () => {
      const btn = new SheetDialogButton('取消', '#999', 'cancel')
      expect(btn.role).assertEqual('cancel')
    })
    it('指定selected', 0, async () => {
      const btn = new SheetDialogButton('DeepSeek', '#FFF', 'default', true)
      expect(btn.selected).assertTrue()
    })
  })

  describe('SheetDialogConfig', () => {
    it('默认构造_空字段', 0, async () => {
      const cfg = new SheetDialogConfig()
      expect(cfg.title).assertEqual('')
      expect(cfg.message).assertEqual('')
      expect(cfg.buttons.length).assertEqual(0)
    })
    it('带参构造', 0, async () => {
      const btns = [new SheetDialogButton('OK', '#FFF')]
      const cfg = new SheetDialogConfig('标题', '内容', btns)
      expect(cfg.title).assertEqual('标题')
      expect(cfg.message).assertEqual('内容')
      expect(cfg.buttons.length).assertEqual(1)
    })
  })

  describe('SheetDatePickerConfig', () => {
    it('默认构造', 0, async () => {
      const cfg = new SheetDatePickerConfig()
      expect(cfg.title).assertEqual('')
      expect(cfg.start.getFullYear()).assertEqual(2020)
      expect(cfg.end.getFullYear()).assertEqual(2050)
    })
    it('带参构造', 0, async () => {
      const d = new Date('2024-06-15')
      const cfg = new SheetDatePickerConfig('选择', d)
      expect(cfg.title).assertEqual('选择')
      expect(cfg.selected.getFullYear()).assertEqual(2024)
    })
  })

  describe('CalendarDayCell', () => {
    it('构造与属性赋值', 0, async () => {
      const cell = new CalendarDayCell(2026, 7, 15, true, false, true)
      expect(cell.year).assertEqual(2026)
      expect(cell.month).assertEqual(7)
      expect(cell.day).assertEqual(15)
      expect(cell.isCurrentMonth).assertEqual(true)
      expect(cell.isSelected).assertEqual(true)
      const d = cell.toDate()
      expect(d.getFullYear()).assertEqual(2026)
      expect(d.getMonth()).assertEqual(7)
      expect(d.getDate()).assertEqual(15)
    })
  })

  describe('getOrderedButtons', () => {
    it('空数组_返回空', 0, async () => {
      const result = getOrderedButtons([])
      expect(result.length).assertEqual(0)
    })
    it('无cancel_保持原序', 0, async () => {
      const btns = [
        new SheetDialogButton('确定', '#FFF', 'default'),
        new SheetDialogButton('删除', '#F00', 'destructive')
      ]
      const result = getOrderedButtons(btns)
      expect(result.length).assertEqual(2)
      expect(result[0].btn.text).assertEqual('确定')
      expect(result[1].btn.text).assertEqual('删除')
    })
    it('cancel在首位_移到底部', 0, async () => {
      const btns = [
        new SheetDialogButton('取消', '#999', 'cancel'),
        new SheetDialogButton('确定', '#FFF', 'default')
      ]
      const result = getOrderedButtons(btns)
      expect(result[0].btn.text).assertEqual('确定')
      expect(result[1].btn.text).assertEqual('取消')
    })
    it('多cancel_全部移到底部保持原序', 0, async () => {
      const btns = [
        new SheetDialogButton('取消A', '#999', 'cancel'),
        new SheetDialogButton('确定', '#FFF', 'default'),
        new SheetDialogButton('取消B', '#999', 'cancel')
      ]
      const result = getOrderedButtons(btns)
      expect(result[0].btn.text).assertEqual('确定')
      expect(result[1].btn.text).assertEqual('取消A')
      expect(result[2].btn.text).assertEqual('取消B')
    })
    it('保留原始index', 0, async () => {
      const btns = [
        new SheetDialogButton('取消', '#999', 'cancel'),
        new SheetDialogButton('确定', '#FFF', 'default')
      ]
      const result = getOrderedButtons(btns)
      expect(result[0].index).assertEqual(1)
      expect(result[1].index).assertEqual(0)
    })
  })

  describe('isConfirmButtonPair', () => {
    it('取消加确认_是双按钮对', 0, async () => {
      const btns = [
        new SheetDialogButton('取消', '#999', 'cancel'),
        new SheetDialogButton('确认退出', '#F00', 'destructive')
      ]
      expect(isConfirmButtonPair(btns)).assertTrue()
    })
    it('三项选择_不是双按钮对', 0, async () => {
      const btns = [
        new SheetDialogButton('A', '#FFF', 'default'),
        new SheetDialogButton('清除', '#F00', 'destructive'),
        new SheetDialogButton('取消', '#999', 'cancel')
      ]
      expect(isConfirmButtonPair(btns)).assertFalse()
    })
    it('两个都不是取消_不是双按钮对', 0, async () => {
      const btns = [
        new SheetDialogButton('确定', '#FFF', 'default'),
        new SheetDialogButton('删除', '#F00', 'destructive')
      ]
      expect(isConfirmButtonPair(btns)).assertFalse()
    })
  })
}
