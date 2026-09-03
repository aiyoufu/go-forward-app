import { Debt } from 'common'

/**
 * 负债列表筛选/排序（S5）— 纯逻辑，无 UI
 * filterIndex: 0全部 1进行中 2已逾期 3已暂停
 * sortIndex: 0按余额 1按还清日
 */
export class DebtsFilterSort {
  static filterAndSort(
    debts: Debt[],
    searchQuery: string,
    filterIndex: number,
    sortIndex: number,
    today: string
  ): Debt[] {
    let list = debts.filter((d: Debt) => {
      if (searchQuery.length > 0) {
        const q = searchQuery.toLowerCase()
        if (!d.platform.toLowerCase().includes(q) && !d.note.toLowerCase().includes(q)) {
          return false
        }
      }
      if (filterIndex === 0) {
        return d.status !== 'completed'
      }
      if (filterIndex === 1) {
        return d.status === 'active' && d.next_payment_date >= today
      }
      if (filterIndex === 2) {
        return d.status === 'active' && d.next_payment_date < today
      }
      if (filterIndex === 3) {
        return d.status === 'paused'
      }
      return d.status !== 'completed'
    })

    list = list.slice()
    if (sortIndex === 0) {
      list.sort((a: Debt, b: Debt) => b.current_balance - a.current_balance)
    } else {
      list.sort((a: Debt, b: Debt) =>
        (a.estimated_end_date || '').localeCompare(b.estimated_end_date || ''))
    }
    return list
  }
}
