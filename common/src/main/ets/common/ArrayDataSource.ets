/**
 * LazyForEach 通用数据源（IDataSource）
 * - reload：整表替换（筛选/排序/hydrate）
 * - 增删可用 notify；主路径优先 reload 保证键与顺序正确
 */
export class ArrayDataSource implements IDataSource {
  private listeners: DataChangeListener[] = []
  private dataArray: Object[] = []

  totalCount(): number {
    return this.dataArray.length
  }

  getData(index: number): Object {
    return this.dataArray[index]
  }

  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener)
    }
  }

  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener)
    if (pos >= 0) {
      this.listeners.splice(pos, 1)
    }
  }

  /** 整表替换并通知 LazyForEach 重建可视区 */
  reload(list: Object[]): void {
    this.dataArray = list
    this.notifyDataReload()
  }

  /** 从业务数组拷贝为 Object[] 再 reload（ArkTS 避免 Debt[] as Object[]） */
  reloadFromList(list: Object[]): void {
    this.reload(list)
  }

  clear(): void {
    this.dataArray = []
    this.notifyDataReload()
  }

  private notifyDataReload(): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataReloaded()
    }
  }

  notifyDataAdd(index: number): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataAdd(index)
    }
  }

  notifyDataDelete(index: number): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataDelete(index)
    }
  }

  notifyDataChange(index: number): void {
    for (let i = 0; i < this.listeners.length; i++) {
      this.listeners[i].onDataChange(index)
    }
  }
}

/** 业务数组 → Object[]（供 ArrayDataSource.reload；逐项 push 避免 as Object[]） */
export function toObjectList(list: Object[]): Object[] {
  const out: Object[] = []
  for (let i = 0; i < list.length; i++) {
    out.push(list[i])
  }
  return out
}
