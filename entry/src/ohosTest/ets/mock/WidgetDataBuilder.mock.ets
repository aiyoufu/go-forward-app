// WidgetDataBuilder.mock.ets — entry 模块测试用
export class WidgetDataBuilder {
  static buildDebtPressureData(): Record<string, string | number | boolean> {
    return { hasData: false, remaining: '¥\u20090.00', progress: 0, peakIndex: -1,
      chartPack: '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—' }
  }

  static buildDebtOverviewData(): Record<string, string | number | boolean> {
    return { hasData: false, remaining: '¥\u20090.00', progress: 0,
      thisMonth: '¥\u20090.00', nextMonth: '¥\u20090.00' }
  }

  static buildMonthDueData(): Record<string, string | number | boolean> {
    return { hasData: false, amount: '¥\u20090.00', debtListPack: '', moreCount: 0 }
  }

  static buildPressureTrendData(): Record<string, string | number | boolean> {
    return { hasData: false, peakIndex: -1,
      chartPack: '0|—|—;0|—|—;0|—|—;0|—|—;0|—|—;0|—|—' }
  }

  static buildSubscriptionData(): Record<string, string | number | boolean> {
    return { hasData: false, activeSubs: 0, subListPack: '', moreCount: 0 }
  }
}
