// DbService.mock.ets
// Mock preset: 内存数据库

// 内存存储：table -> rows[]
const store: Map<string, Map<string, string | number | boolean>[]> = new Map()
const sqlCallLog: { sql: string; args?: Array<string | number | boolean> }[] = []
const fixedTimestamp: string = '2024-11-14T10:00:00.000Z'

// 预设查询结果：sql 前缀 -> 行列表
const queryPresets: Map<string, Record<string, string | number | boolean>[]> = new Map()

export class DbService {
  static async init(context: Object): Promise<void> {
    // 空操作
  }

  static async close(): Promise<void> {
    // 空操作
  }

  static async executeSql(sql: string, bindArgs?: Array<string | number | boolean>): Promise<void> {
    sqlCallLog.push({ sql, args: bindArgs })
  }

  static async query(
    sql: string,
    bindArgs?: Array<string | number | boolean>
  ): Promise<Object> {
    sqlCallLog.push({ sql, args: bindArgs })
    // 检查预设
    const keys = queryPresets.keys()
    for (const key of keys) {
      if (sql.indexOf(key) >= 0) {
        const rows = queryPresets.get(key) || []
        return createMockResultSet(rows)
      }
    }
    // 检查内存存储
    const table = extractTableFromSql(sql)
    if (table && store.has(table)) {
      return createMockResultSet(store.get(table) || [])
    }
    return createMockResultSet([])
  }

  static async insert(table: string, values: Map<string, string | number | boolean>): Promise<number> {
    if (!store.has(table)) {
      store.set(table, [])
    }
    const row = new Map<string, string | number | boolean>()
    const keys = values.keys()
    for (const key of keys) {
      row.set(key, values.get(key))
    }
    store.get(table)!.push(row)
    return 1
  }

  static async update(
    table: string,
    values: Map<string, string | number | boolean>,
    whereClause: string,
    whereArgs: Array<string | number | boolean>
  ): Promise<number> {
    sqlCallLog.push({ sql: 'UPDATE ' + table, args: whereArgs })
    return 1
  }

  static async delete(
    table: string,
    whereClause: string,
    whereArgs: Array<string | number | boolean>
  ): Promise<number> {
    sqlCallLog.push({ sql: 'DELETE ' + table, args: whereArgs })
    return 1
  }

  static boolToInt(b: boolean): number {
    return b ? 1 : 0
  }

  static intToBool(n: number): boolean {
    return Number(n) === 1
  }

  static now(): string {
    return fixedTimestamp
  }

  // ---- 测试辅助方法 ----

  /** 设置预设查询结果 */
  static _setQueryPreset(sqlFragment: string, rows: Record<string, string | number | boolean>[]): void {
    queryPresets.set(sqlFragment, rows)
  }

  /** 获取 SQL 调用日志 */
  static _getSqlCallLog(): { sql: string; args?: Array<string | number | boolean> }[] {
    return sqlCallLog
  }

  /** 清空所有状态 */
  static _reset(): void {
    store.clear()
    sqlCallLog.length = 0
    queryPresets.clear()
  }

  /** 获取内存存储 */
  static _getStore(): Map<string, Map<string, string | number | boolean>[]> {
    return store
  }
}

// ---- 辅助函数 ----

function extractTableFromSql(sql: string): string | null {
  const fromMatch = sql.match(/FROM\s+(\w+)/i)
  if (fromMatch) {
    return fromMatch[1]
  }
  const intoMatch = sql.match(/INTO\s+(\w+)/i)
  if (intoMatch) {
    return intoMatch[1]
  }
  return null
}

function createMockResultSet(rows: Record<string, string | number | boolean>[]): Object {
  let rowIndex = -1
  const columnNames: string[] = rows.length > 0 ? Object.keys(rows[0]) : []
  return {
    goToFirstRow(): boolean {
      rowIndex = 0
      return rows.length > 0
    },
    goToNextRow(): boolean {
      rowIndex++
      return rowIndex < rows.length
    },
    close(): void {
      rowIndex = -1
    },
    get columnCount(): number {
      return columnNames.length
    },
    get columnNames(): string[] {
      return columnNames
    },
    getColumnName(index: number): string {
      return columnNames[index] || ''
    },
    getColumnIndex(name: string): number {
      const idx = columnNames.indexOf(name)
      return idx >= 0 ? idx : -1
    },
    getString(index: number): string {
      if (rowIndex < 0 || rowIndex >= rows.length) {
        return ''
      }
      const col = columnNames[index]
      const val = rows[rowIndex][col]
      return val !== undefined && val !== null ? '' + val : ''
    },
    getLong(index: number): number {
      if (rowIndex < 0 || rowIndex >= rows.length) {
        return 0
      }
      const col = columnNames[index]
      const val = rows[rowIndex][col]
      return typeof val === 'number' ? val : Number(val) || 0
    },
    getDouble(index: number): number {
      if (rowIndex < 0 || rowIndex >= rows.length) {
        return 0
      }
      const col = columnNames[index]
      const val = rows[rowIndex][col]
      return typeof val === 'number' ? val : Number(val) || 0
    },
    isColumnNull(index: number): boolean {
      if (rowIndex < 0 || rowIndex >= rows.length) {
        return true
      }
      const col = columnNames[index]
      const val = rows[rowIndex][col]
      return val === null || val === undefined
    }
  }
}
