// SubscriptionService.mock.ets — entry 模块测试用
let presetSubscriptions: Object[] = []

export class SubscriptionService {
  static async getSubscriptions(userId?: string): Promise<Object[]> {
    return presetSubscriptions
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

  static _setPresetSubscriptions(subs: Object[]): void {
    presetSubscriptions = subs
  }

  static _reset(): void {
    presetSubscriptions = []
  }
}
