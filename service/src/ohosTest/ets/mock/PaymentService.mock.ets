// PaymentService.mock.ets
// Mock preset: 预设还款记录

let presetPaymentRecords: Object[] = []
let presetAchievementCards: Object[] = []

export class PaymentService {
  static async getPaymentRecords(debtId: string): Promise<Object[]> {
    return presetPaymentRecords.filter(r => {
      const record = r as Record<string, string>
      return record.debt_id === debtId
    })
  }

  static async getRecordsByUser(userId: string): Promise<Object[]> {
    return presetPaymentRecords.filter(r => {
      const record = r as Record<string, string>
      return record.user_id === userId
    })
  }

  static async hasPaymentRecords(userId: string): Promise<boolean> {
    return presetPaymentRecords.some(r => {
      const record = r as Record<string, string>
      return record.user_id === userId
    })
  }

  static async getCurrentMonthPaid(userId: string): Promise<number> {
    let total = 0
    for (const r of presetPaymentRecords) {
      const record = r as Record<string, string | number>
      if (record.user_id === userId) {
        total += Number(record.amount_paid) || 0
      }
    }
    return total
  }

  static async getAchievementCards(userId?: string): Promise<Object[]> {
    return presetAchievementCards
  }

  static async markPeriodPaid(debt: Object, periodNumber: number, paymentDate?: string, amountOverride?: number): Promise<void> {
    // 空操作
  }

  static async payoffDebt(debt: Object): Promise<void> {
    // 空操作
  }

  static async importPaymentRecord(input: Object): Promise<void> {
    // 空操作
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    // 空操作
  }

  // ---- 测试辅助方法 ----

  static _setPresetPaymentRecords(records: Object[]): void {
    presetPaymentRecords = records
  }

  static _setPresetAchievementCards(cards: Object[]): void {
    presetAchievementCards = cards
  }

  static _reset(): void {
    presetPaymentRecords = []
    presetAchievementCards = []
  }
}
