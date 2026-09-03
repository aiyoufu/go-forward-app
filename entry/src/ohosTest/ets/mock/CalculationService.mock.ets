// CalculationService.mock.ets — entry 模块测试用
let presetMonthlyPressure: Object[] = []

export class CalculationService {
  static calculateMonthlyPressure(debts: Object[], subscriptions: Object[], months?: number): Object[] {
    return presetMonthlyPressure
  }

  static _setPresetMonthlyPressure(pressure: Object[]): void {
    presetMonthlyPressure = pressure
  }

  static _reset(): void {
    presetMonthlyPressure = []
  }
}
