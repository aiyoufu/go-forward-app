/**
 * 列表 Tab 公共行为（从 Debts/Subscriptions/CreditAccounts 三 Tab 去重）
 * 纯函数：状态由页面 @State 持有，此处只做集合运算，不触碰 UI 上下文
 */
import { ErrorMessages } from 'common'

/** 批量选择集合运算 */
export class ListSelection {
  static isSelected(selected: string[], id: string): boolean {
    return selected.indexOf(id) >= 0
  }

  /** 勾选/取消一项；返回新数组驱动 ForEach 刷新 */
  static toggle(selected: string[], id: string): string[] {
    if (selected.indexOf(id) >= 0) {
      return selected.filter(x => x !== id)
    }
    return selected.concat([id])
  }

  /** 可见项是否全部已选 */
  static isAllSelected(selected: string[], visibleIds: string[]): boolean {
    if (visibleIds.length === 0) {
      return false
    }
    for (let i = 0; i < visibleIds.length; i++) {
      if (selected.indexOf(visibleIds[i]) < 0) {
        return false
      }
    }
    return true
  }

  /** 全选/取消全选（仅作用于当前可见项，保留不可见项的勾选态） */
  static toggleAll(selected: string[], visibleIds: string[]): string[] {
    if (ListSelection.isAllSelected(selected, visibleIds)) {
      const visible: Set<string> = new Set()
      for (let i = 0; i < visibleIds.length; i++) {
        visible.add(visibleIds[i])
      }
      return selected.filter(id => !visible.has(id))
    }
    const set: Set<string> = new Set()
    for (let i = 0; i < selected.length; i++) {
      set.add(selected[i])
    }
    for (let i = 0; i < visibleIds.length; i++) {
      set.add(visibleIds[i])
    }
    return Array.from(set)
  }

  /** 进入多选时的初始勾选（可带预选） */
  static initialSelection(preselectId?: string): string[] {
    const ids: string[] = []
    if (preselectId && preselectId.length > 0) {
      ids.push(preselectId)
    }
    return ids
  }

  /** 批量删除结果分桶 */
  static splitSucceeded(ids: string[], failed: string[]): string[] {
    return ids.filter(id => failed.indexOf(id) < 0)
  }

  /** 批量删除完成后的提示文案 */
  static batchDeleteToast(succeededCount: number, failedCount: number, unit: string): string {
    if (failedCount === 0) {
      return ErrorMessages.DELETE_OK
    }
    if (succeededCount === 0) {
      return ErrorMessages.DELETE_FAILED
    }
    return '已删除 ' + succeededCount + ' ' + unit + '，' + failedCount + ' ' + unit + '失败'
  }
}

/** 批量删除循环执行：逐个调 deleteOne，收集失败 id */
export async function runBatchDelete(ids: string[], deleteOne: (id: string) => Promise<void>): Promise<string[]> {
  const failed: string[] = []
  for (let i = 0; i < ids.length; i++) {
    try {
      await deleteOne(ids[i])
    } catch (_e) {
      failed.push(ids[i])
    }
  }
  return failed
}
