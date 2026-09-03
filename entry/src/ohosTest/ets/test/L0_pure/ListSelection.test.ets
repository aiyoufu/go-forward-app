import { describe, it, expect } from '@ohos/hypium'
import { ListSelection, runBatchDelete } from '../../../../main/ets/pages/common/ListSelection'

export default function listSelectionTest() {
  describe('ListSelection', () => {
    it('isSelected_命中与未命中', 0, () => {
      const selected: string[] = ['a', 'b']
      expect(ListSelection.isSelected(selected, 'a')).assertTrue()
      expect(ListSelection.isSelected(selected, 'c')).assertFalse()
    })

    it('toggle_选中变取消', 0, () => {
      const next = ListSelection.toggle(['a', 'b'], 'a')
      expect(next.length).assertEqual(1)
      expect(next[0]).assertEqual('b')
    })

    it('toggle_未选变选中', 0, () => {
      const next = ListSelection.toggle(['a'], 'b')
      expect(next.length).assertEqual(2)
    })

    it('isAllSelected_空可见列表为假', 0, () => {
      expect(ListSelection.isAllSelected(['a'], [])).assertFalse()
    })

    it('isAllSelected_全部命中为真', 0, () => {
      expect(ListSelection.isAllSelected(['a', 'b'], ['a', 'b'])).assertTrue()
    })

    it('toggleAll_全选补齐可见项并去重', 0, () => {
      const next = ListSelection.toggleAll(['a'], ['b', 'c'])
      expect(next.length).assertEqual(3)
    })

    it('toggleAll_取消全选仅移除可见项', 0, () => {
      const next = ListSelection.toggleAll(['a', 'b', 'x'], ['a', 'b'])
      expect(next.length).assertEqual(1)
      expect(next[0]).assertEqual('x')
    })

    it('initialSelection_带预选', 0, () => {
      expect(ListSelection.initialSelection('id1').length).assertEqual(1)
      expect(ListSelection.initialSelection('').length).assertEqual(0)
      expect(ListSelection.initialSelection().length).assertEqual(0)
    })

    it('splitSucceeded_过滤失败项', 0, () => {
      const ok = ListSelection.splitSucceeded(['a', 'b', 'c'], ['b'])
      expect(ok.length).assertEqual(2)
    })

    it('batchDeleteToast_三种分支', 0, () => {
      expect(ListSelection.batchDeleteToast(2, 0, '项')).assertEqual('删除成功')
      expect(ListSelection.batchDeleteToast(0, 2, '项')).assertEqual('删除失败，请稍后重试')
      expect(ListSelection.batchDeleteToast(1, 1, '项')).assertEqual('已删除 1 项，1 项失败')
    })

    it('runBatchDelete_收集失败id', 0, async () => {
      const failed = await runBatchDelete(['ok1', 'bad', 'ok2'], (id: string): Promise<void> => {
        if (id === 'bad') {
          return Promise.reject(new Error('x'))
        }
        return Promise.resolve()
      })
      expect(failed.length).assertEqual(1)
      expect(failed[0]).assertEqual('bad')
    })
  })
}
