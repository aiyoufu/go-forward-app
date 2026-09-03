import { describe, it, expect } from '@ohos/hypium'
import {
  ConfirmListRow,
  buildConfirmRows,
  toggleConfirmRow,
  setAllConfirmRows,
  countSelected,
  allRowsSelected,
  typeLabelOf
} from '../../../../main/ets/components/AILiveConfirmRows'
import { ParseResultItem } from 'service'

function itemOf(recordType: string, title: string, complete: boolean): ParseResultItem {
  const item = new ParseResultItem()
  item.tempId = 't1'
  item.recordType = recordType
  item.parsedFields.set('platform', title)
  item.parsedFields.set('name', title)
  item.isComplete = complete
  return item
}

export default function ailiveConfirmRowsTest() {
  describe('AILiveConfirmRows', () => {
    it('typeLabelOf_三种类型', 0, () => {
      expect(typeLabelOf('subscription')).assertEqual('订阅')
      expect(typeLabelOf('credit_account')).assertEqual('信用账户')
      expect(typeLabelOf('debt')).assertEqual('负债')
    })

    it('buildConfirmRows_完整默认勾选不完整默认不勾', 0, () => {
      const rows = buildConfirmRows([itemOf('debt', '花呗', true), itemOf('debt', '借呗', false)], '#333333')
      expect(rows.length).assertEqual(2)
      expect(rows[0].selected).assertTrue()
      expect(rows[1].selected).assertFalse()
      expect(rows[0].index).assertEqual(0)
      expect(rows[1].index).assertEqual(1)
    })

    it('toggleConfirmRow_仅翻转目标行', 0, () => {
      const rows = buildConfirmRows([itemOf('debt', '花呗', true), itemOf('debt', '借呗', true)], '#333333')
      const next = toggleConfirmRow(rows, 1)
      expect(next[0].selected).assertTrue()
      expect(next[1].selected).assertFalse()
    })

    it('setAllConfirmRows_全选全不选', 0, () => {
      const rows = buildConfirmRows([itemOf('debt', '花呗', true), itemOf('debt', '借呗', false)], '#333333')
      expect(countSelected(setAllConfirmRows(rows, true))).assertEqual(2)
      expect(countSelected(setAllConfirmRows(rows, false))).assertEqual(0)
    })

    it('allRowsSelected_空列表为假', 0, () => {
      const empty: ConfirmListRow[] = []
      expect(allRowsSelected(empty)).assertFalse()
    })

    it('allRowsSelected_全部勾选为真', 0, () => {
      const rows = buildConfirmRows([itemOf('debt', '花呗', true)], '#333333')
      expect(allRowsSelected(rows)).assertTrue()
      expect(allRowsSelected(toggleConfirmRow(rows, 0))).assertFalse()
    })
  })
}
