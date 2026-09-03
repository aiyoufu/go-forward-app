// CalculationService.mock.ets
// Mock preset: 预设计算结果

let presetPaymentSchedule: Object[] = []
let presetMonthlyPressure: Object[] = []

export interface DebtOverdueInfo {
  daysLeft: number
  daysLate: number
  graceDays: number
  isInGracePeriod: boolean
  isBreached: boolean
  isOverdue: boolean
  label: string
}

export class CustomScheduleItem {
  period_number: number = 0
  principal: number = 0
  interest: number = 0
  total: number = 0
}

export class PaymentSplit {
  principal: number = 0
  interest: number = 0

  constructor(principal: number, interest: number) {
    this.principal = principal
    this.interest = interest
  }
}

export class CalculationService {
  static bpToMonthlyRate(annualRateBp: number): number {
    return annualRateBp / 10000 / 12
  }

  static calculatePeriodPayment(
    currentBalance: number,
    annualRateBp: number,
    remainingPeriods: number,
    totalPeriods: number,
    method?: string,
    principal?: number,
    monthlyPayment?: number,
    totalInterest?: number
  ): PaymentSplit {
    if (remainingPeriods <= 0) {
      return new PaymentSplit(0, 0)
    }
    const monthlyRate = CalculationService.bpToMonthlyRate(annualRateBp)
    const interest = Math.round(currentBalance * monthlyRate)
    const principalPaid = monthlyPayment ? monthlyPayment - interest : Math.round(currentBalance / remainingPeriods)
    return new PaymentSplit(principalPaid, interest)
  }

  static generatePaymentSchedule(debt: Object): Object[] {
    return presetPaymentSchedule
  }

  static addMonths(date: string | Object, months: number): string {
    const d = new Date('' + date)
    d.setMonth(d.getMonth() + months)
    const year = d.getFullYear()
    const month = d.getMonth() + 1
    const day = d.getDate()
    return year + '-' + (month < 10 ? '0' + month : '' + month) + '-' + (day < 10 ? '0' + day : '' + day)
  }

  static calculateCurrentBalance(
    principal: number,
    monthlyPayment: number,
    totalPeriods: number,
    remainingPeriods: number,
    annualRateBp: number,
    repaymentMethod?: string,
    totalInterest?: number
  ): number {
    if (remainingPeriods <= 0) {
      return 0
    }
    return Math.round(principal * remainingPeriods / totalPeriods)
  }

  static calculateSuggestedMonthlyPayment(
    principal: number,
    annualRateBp: number,
    totalPeriods: number,
    method?: string,
    totalInterest?: number
  ): number {
    if (totalPeriods <= 0) {
      return 0
    }
    return Math.round((principal + (totalInterest || 0)) / totalPeriods)
  }

  static parseCustomSchedule(note: string): CustomScheduleItem[] | null {
    if (!note || note.length === 0) {
      return null
    }
    try {
      const parsed = JSON.parse(note)
      if (parsed && parsed.custom_schedule && Array.isArray(parsed.custom_schedule)) {
        return parsed.custom_schedule
      }
    } catch (e) {
      // ignore
    }
    return null
  }

  static getCleanNoteText(note: string): string {
    return note
  }

  static getDebtPaymentForMonth(debt: Object, monthKey: string): number {
    const d = debt as Record<string, string | number>
    if (d.status !== 'active') {
      return 0
    }
    return Number(d.monthly_payment) || 0
  }

  static getDebtPaymentForMonthAccrued(debt: Object, monthKey: string, currentMonthKey: string): number {
    return CalculationService.getDebtPaymentForMonth(debt, monthKey)
  }

  static calculateRemainingInterest(debt: Object): number {
    return 0
  }

  static getCreditLinkedSubscriptionMonthly(subscriptions: Object[]): number {
    return 0
  }

  static isSubscriptionDueInMonth(sub: Object, targetYear: number, targetMonth: number): boolean {
    return false
  }

  static getCreditLinkedSubscriptionDueInMonth(subscriptions: Object[], targetYear: number, targetMonth: number): number {
    return 0
  }

  static getDueAmountForMonth(debts: Object[], subscriptions: Object[], monthKey: string, currentMonthKey?: string): Object {
    return { month: monthKey, debtAmount: 0, subscriptionAmount: 0, amount: 0 }
  }

  static calculateMonthlyPressure(debts: Object[], subscriptions: Object[], months?: number): Object[] {
    return presetMonthlyPressure
  }

  static calculateNextBillingDate(cycle: string, startDate: string): string {
    return CalculationService.addMonths(startDate, 1)
  }

  static getDebtOverdueInfo(debt: Object, creditAccount?: Object | null): DebtOverdueInfo {
    const d = debt as Record<string, string>
    const info: DebtOverdueInfo = {
      daysLeft: 0,
      daysLate: 0,
      graceDays: 0,
      isInGracePeriod: false,
      isBreached: false,
      isOverdue: false,
      label: '进行中'
    }
    if (d.status === 'completed') {
      info.label = '已结清'
    } else if (d.status === 'paused') {
      info.label = '已暂停'
    }
    return info
  }

  // ---- 测试辅助方法 ----

  static _setPresetPaymentSchedule(schedule: Object[]): void {
    presetPaymentSchedule = schedule
  }

  static _setPresetMonthlyPressure(pressure: Object[]): void {
    presetMonthlyPressure = pressure
  }

  static _reset(): void {
    presetPaymentSchedule = []
    presetMonthlyPressure = []
  }
}
