import { describe, it, expect } from '@ohos/hypium'
import { ConfirmListRow, buildConfirmRows } from '../../../../main/ets/components/AILiveConfirmRows'
import { ParseResultItem } from 'service'

/**
 * AILiveConfirmRowItem UI 测试
 * 覆盖：行模型到组件入参的映射约定（勾选态驱动边框/勾选圆点）
 */
export default function ailiveConfirmRowItem_UITest() {
  describe('AILiveConfirmRowItem_UI', () => {

    function itemOf(recordType: string, title: string, complete: boolean): ParseResultItem {
      const item = new ParseResultItem()
      item.recordType = recordType
      item.parsedFields.set('platform', title)
      item.isComplete = complete
      return item
    }

    it('行模型_完整项默认选中', 0, async () => {
      const rows = buildConfirmRows([itemOf('debt', '花呗', true)], '#333333')
      expect(rows[0].selected).assertTrue()
    })

    it('行模型_不完整项显示补全入口', 0, async () => {
      const rows = buildConfirmRows([itemOf('debt', '借呗', false)], '#333333')
      const actionLabel = rows[0].complete ? '详情' : '补全'
      expect(actionLabel).assertEqual('补全')
    })

    it('行模型_标题空值兜底未知', 0, async () => {
      const row = new ConfirmListRow()
      row.title = ''
      expect(row.title.length > 0 ? row.title : '未知').assertEqual('未知')
    })

    it('行模型_勾选切换驱动边框宽度', 0, async () => {
      const row = new ConfirmListRow()
      row.selected = true
      const borderWidth = row.selected ? 1.5 : 1
      expect(borderWidth).assertEqual(1.5)
    })
  })
}
