/**
 * AI Live 多条确认列表的行模型与集合运算（从 AILiveOverlay 拆出）
 * 纯函数：行数组由页面 @State 持有，此处只做构建与勾选运算
 */
import { ParseResultItem } from 'service'
import { AILiveMapping } from 'service'
import { PlatformService } from 'service'
import { Utils } from 'common'

/** 多条确认列表行（纯展示 + 勾选；与 pendingItems 按下标对齐） */
export class ConfirmListRow {
  index: number = 0
  selected: boolean = true
  complete: boolean = true
  title: string = ''
  amountText: string = ''
  meta: string = ''
  typeLabel: string = ''
  mark: string = ''
  avatarColor: string = ''
}

/** recordType → 中文类型标签 */
export function typeLabelOf(recordType: string): string {
  if (recordType === 'subscription') {
    return '订阅'
  }
  if (recordType === 'credit_account') {
    return '信用账户'
  }
  return '负债'
}

/** 由解析结果构建确认列表行（完整默认勾选；不完整默认不勾，需表单补全后再入库） */
export function buildConfirmRows(items: ParseResultItem[], fallbackAvatarColor: string): ConfirmListRow[] {
  const rows: ConfirmListRow[] = []
  for (let i = 0; i < items.length; i++) {
    const item = items[i]
    const preview = AILiveMapping.buildPreviewData(item)
    const visual = PlatformService.getBrandVisual(preview.title)
    const row = new ConfirmListRow()
    row.index = i
    row.complete = item.isComplete
    row.selected = item.isComplete
    row.title = preview.title
    row.amountText = Utils.formatMoney(preview.amountFen)
    row.meta = preview.meta
    row.typeLabel = typeLabelOf(item.recordType)
    row.mark = visual.mark.length > 0 ? visual.mark :
      (preview.title.length > 0 ? preview.title.substring(0, 1) : '·')
    row.avatarColor = visual.color.length > 0 ? visual.color : fallbackAvatarColor
    rows.push(row)
  }
  return rows
}

function copyWith(src: ConfirmListRow, selected: boolean): ConfirmListRow {
  const row = new ConfirmListRow()
  row.index = src.index
  row.complete = src.complete
  row.selected = selected
  row.title = src.title
  row.amountText = src.amountText
  row.meta = src.meta
  row.typeLabel = src.typeLabel
  row.mark = src.mark
  row.avatarColor = src.avatarColor
  return row
}

/** 勾选/取消一行；返回新数组驱动 ForEach 刷新 */
export function toggleConfirmRow(rows: ConfirmListRow[], index: number): ConfirmListRow[] {
  return rows.map((src, i) => copyWith(src, i === index ? !src.selected : src.selected))
}

/** 全选/取消全选 */
export function setAllConfirmRows(rows: ConfirmListRow[], selected: boolean): ConfirmListRow[] {
  return rows.map(src => copyWith(src, selected))
}

export function countSelected(rows: ConfirmListRow[]): number {
  let n = 0
  for (let i = 0; i < rows.length; i++) {
    if (rows[i].selected) {
      n++
    }
  }
  return n
}

export function allRowsSelected(rows: ConfirmListRow[]): boolean {
  if (rows.length === 0) {
    return false
  }
  for (let i = 0; i < rows.length; i++) {
    if (!rows[i].selected) {
      return false
    }
  }
  return true
}
