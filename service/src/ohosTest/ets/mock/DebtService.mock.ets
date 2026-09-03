// DebtService.mock.ets
// Mock preset: 预设债务列表

let presetDebts: Object[] = []

export class DebtService {
  static async getDebts(userId?: string): Promise<Object[]> {
    return presetDebts
  }

  static async getDebtsPaged(offset: number, limit: number, userId?: string): Promise<Object[]> {
    return presetDebts.slice(offset, offset + limit)
  }

  static async getDebtById(id: string): Promise<Object | null> {
    for (const debt of presetDebts) {
      const d = debt as Record<string, string>
      if (d.id === id) {
        return debt
      }
    }
    return null
  }

  static async createDebt(input: Object): Promise<Object> {
    return new Object()
  }

  static async updateDebt(id: string, updates: Object): Promise<void> {
    // 空操作
  }

  static async deleteDebt(id: string): Promise<void> {
    // 空操作
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    // 空操作
  }

  static async updateDebtStatus(id: string, status: string): Promise<void> {
    // 空操作
  }

  static async getOverdueDebts(userId?: string): Promise<Object[]> {
    return presetDebts.filter(d => {
      const debt = d as Record<string, string>
      return debt.status === 'active'
    })
  }

  static async getActiveDebtsDueBeforeOrOn(date: string, userId?: string): Promise<Object[]> {
    return presetDebts.filter(d => {
      const debt = d as Record<string, string>
      return debt.status === 'active' && debt.next_payment_date <= date
    })
  }

  static async getTodayDueDebts(userId?: string): Promise<Object[]> {
    return presetDebts.filter(d => {
      const debt = d as Record<string, string>
      return debt.status === 'active'
    })
  }

  // ---- 测试辅助方法 ----

  static _setPresetDebts(debts: Object[]): void {
    presetDebts = debts
  }

  static _reset(): void {
    presetDebts = []
  }
}
