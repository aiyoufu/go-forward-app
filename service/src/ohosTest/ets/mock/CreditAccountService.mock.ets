// CreditAccountService.mock.ets
// Mock preset: 预设信用卡列表

let presetCreditAccounts: Object[] = []

export class CreditAccountService {
  static async getCreditAccounts(userId?: string): Promise<Object[]> {
    return presetCreditAccounts
  }

  static async getCreditAccountById(id: string): Promise<Object | null> {
    for (const account of presetCreditAccounts) {
      const a = account as Record<string, string>
      if (a.id === id) {
        return account
      }
    }
    return null
  }

  static async createCreditAccount(input: Object): Promise<Object> {
    return {}
  }

  static async updateCreditAccount(id: string, updates: Object): Promise<void> {
    // 空操作
  }

  static async deleteCreditAccount(id: string): Promise<void> {
    // 空操作
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    // 空操作
  }

  static async updateSortOrder(orderedIds: string[]): Promise<void> {
    // 空操作
  }

  static matchAccountByFileName(fileName: string, accounts: Object[]): string {
    if (fileName.length === 0 || accounts.length === 0) {
      return ''
    }
    const stripped = fileName.toLowerCase().replace(/\.[^.]+$/, '').trim()
    if (stripped.length === 0) {
      return ''
    }
    const leadingToken = stripped.split(/[-_\s]/)[0]
    let best = ''
    for (let i = 0; i < accounts.length; i++) {
      const acc = accounts[i] as Record<string, string>
      const rawName = (acc.name ?? '') as string
      const name = rawName.trim().toLowerCase()
      if (name.length === 0) {
        continue
      }
      const substringHit = stripped.indexOf(name) >= 0
      const tokenHit = leadingToken.length >= 2 && name.indexOf(leadingToken) >= 0
      if ((substringHit || tokenHit) && name.length > best.length) {
        best = rawName
      }
    }
    return best
  }

  // ---- 测试辅助方法 ----

  static _setPresetCreditAccounts(accounts: Object[]): void {
    presetCreditAccounts = accounts
  }

  static _reset(): void {
    presetCreditAccounts = []
  }
}
