// DebtService.mock.ets — entry 模块测试用
let presetDebts: Object[] = []
let createdDebt: Object = { id: 'debt-001', platform: 'test' }
let updateStatusCallLog: { id: string; status: string }[] = []

export class DebtService {
  static async getDebts(userId?: string): Promise<Object[]> {
    return presetDebts
  }

  static async createDebt(input: Object): Promise<Object> {
    return createdDebt
  }

  static async updateDebtStatus(id: string, status: string): Promise<void> {
    updateStatusCallLog.push({ id, status })
  }

  static async getActiveDebtsDueBeforeOrOn(date: string, userId?: string): Promise<Object[]> {
    return presetDebts.filter(d => {
      const debt = d as Record<string, string>
      return debt.status === 'active' && debt.next_payment_date <= date
    })
  }

  static _setPresetDebts(debts: Object[]): void {
    presetDebts = debts
  }

  static _setCreatedDebt(debt: Object): void {
    createdDebt = debt
  }

  static _getUpdateStatusCallLog(): { id: string; status: string }[] {
    return updateStatusCallLog
  }

  static _reset(): void {
    presetDebts = []
    createdDebt = { id: 'debt-001', platform: 'test' }
    updateStatusCallLog = []
  }
}
