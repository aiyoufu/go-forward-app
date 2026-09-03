// SubscriptionService.mock.ets
// Mock preset: 预设订阅列表

let presetSubscriptions: Object[] = []

export class SubscriptionService {
  static async getSubscriptions(userId?: string): Promise<Object[]> {
    return presetSubscriptions
  }

  static async getSubscriptionById(id: string): Promise<Object | null> {
    for (const sub of presetSubscriptions) {
      const s = sub as Record<string, string>
      if (s.id === id) {
        return sub
      }
    }
    return null
  }

  static async createSubscription(input: Object): Promise<Object> {
    return {}
  }

  static async updateSubscription(id: string, updates: Object): Promise<void> {
    // 空操作
  }

  static async deleteSubscription(id: string): Promise<void> {
    // 空操作
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    // 空操作
  }

  static async updateSubscriptionStatus(id: string, status: string): Promise<void> {
    // 空操作
  }

  static calculateTotalSubscriptionAmount(subscriptions: Object[]): number {
    let total = 0
    for (const sub of subscriptions) {
      const s = sub as Record<string, string | number>
      if (s.status === 'active') {
        total += Number(s.amount) || 0
      }
    }
    return total
  }

  static groupByBillingCycle(subscriptions: Object[]): Map<string, number> {
    const map = new Map<string, number>()
    for (const sub of subscriptions) {
      const s = sub as Record<string, string | number>
      if (s.status !== 'active') {
        continue
      }
      const cycle = (s.billing_cycle as string) || 'monthly'
      map.set(cycle, (map.get(cycle) || 0) + (Number(s.amount) || 0))
    }
    return map
  }

  // ---- 测试辅助方法 ----

  static _setPresetSubscriptions(subs: Object[]): void {
    presetSubscriptions = subs
  }

  static _reset(): void {
    presetSubscriptions = []
  }
}
