export type DebtType = 'installment' | 'credit_card' | 'loan' | 'other'
export type DebtStatus = 'active' | 'completed' | 'paused'
export type RepaymentMethod = 'equal_payment' | 'fixed_interest' | 'custom'

export class Debt {
  id: string = ''
  user_id: string = ''
  platform: string = ''
  platform_color: string = ''
  debt_type: DebtType = 'installment'
  principal: number = 0
  current_balance: number = 0
  monthly_payment: number = 0
  total_periods: number = 0
  remaining_periods: number = 0
  repayment_method: RepaymentMethod = 'equal_payment'
  total_interest: number = 0
  annual_rate_bp: number = 0
  payment_day: number = 1
  next_payment_date: string = ''
  start_date: string = ''
  estimated_end_date: string = ''
  is_auto_payment: boolean = false
  status: DebtStatus = 'active'
  note: string = ''
  credit_account_id: string = ''
  created_at: string = ''
  updated_at: string = ''
  icon_url: string = ''
  currency: string = 'CNY'
  original_principal_fen: number = 0
  locked_exchange_rate: number = 1.0
}

export class CreateDebtInput {
  platform: string = ''
  debt_type: DebtType = 'installment'
  principal: number = 0
  current_balance: number = 0
  monthly_payment: number = 0
  total_periods: number = 0
  remaining_periods: number = 0
  repayment_method: RepaymentMethod = 'equal_payment'
  total_interest: number = 0
  annual_rate_bp: number = 0
  payment_day: number = 1
  next_payment_date: string = ''
  start_date: string = ''
  is_auto_payment: boolean = false
  note: string = ''
  credit_account_id: string = ''
  icon_url?: string = ''
  currency: string = 'CNY'
  original_principal_fen: number = 0
  locked_exchange_rate: number = 1.0
}

export class UpdateDebtInput {
  platform: string | undefined = undefined
  debt_type: DebtType | undefined = undefined
  principal: number | undefined = undefined
  current_balance: number | undefined = undefined
  monthly_payment: number | undefined = undefined
  total_periods: number | undefined = undefined
  remaining_periods: number | undefined = undefined
  repayment_method: RepaymentMethod | undefined = undefined
  total_interest: number | undefined = undefined
  annual_rate_bp: number | undefined = undefined
  payment_day: number | undefined = undefined
  next_payment_date: string | undefined = undefined
  start_date: string | undefined = undefined
  is_auto_payment: boolean | undefined = undefined
  note: string | undefined = undefined
  credit_account_id: string | undefined = undefined
  icon_url: string | undefined = undefined
  currency: string | undefined = undefined
  original_principal_fen: number | undefined = undefined
  locked_exchange_rate: number | undefined = undefined
}

export class PaymentScheduleItem {
  period_number: number = 0
  date: string = ''
  principal: number = 0
  interest: number = 0
  total: number = 0
  balance_after: number = 0
  status: 'paid' | 'pending' = 'pending'
}

export class MonthlyPressure {
  month: string = ''
  amount: number = 0
  debtAmount: number = 0
  subscriptionAmount: number = 0
}

/** 单月固定应还（负债 + 订阅），纯计算结果不落库，金额单位：分 */
export class MonthlyObligation {
  debtObligation: number = 0
  subscriptionObligation: number = 0
  total: number = 0
}
