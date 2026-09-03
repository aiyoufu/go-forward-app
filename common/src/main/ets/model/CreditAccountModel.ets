export class CreditAccount {
  id: string = ''
  user_id: string = ''
  name: string = ''
  last_four: string = ''
  color: string = ''
  icon_url: string = ''
  expiry_date: string = ''
  cvv: string = ''
  bill_day: number = 1
  payment_day: number = 1
  annual_fee_required_swipes: number = 0
  annual_fee_manual_swipes: number = 0
  credit_limit: number = 0
  grace_period_days: number = 0
  interest_free_days: number = 0
  sort_order: number = 0
  created_at: string = ''
  updated_at: string = ''
}

export class CreateCreditAccountInput {
  name: string = ''
  last_four: string = ''
  color: string = ''
  icon_url: string = ''
  expiry_date: string = ''
  cvv: string = ''
  bill_day: number = 1
  payment_day: number = 1
  annual_fee_required_swipes: number = 0
  annual_fee_manual_swipes: number = 0
  credit_limit: number = 0
  grace_period_days: number = 0
  interest_free_days: number = 0
  sort_order: number = 0
}

export class UpdateCreditAccountInput {
  name: string | undefined = undefined
  last_four: string | undefined = undefined
  color: string | undefined = undefined
  icon_url: string | undefined = undefined
  expiry_date: string | undefined = undefined
  cvv: string | undefined = undefined
  bill_day: number | undefined = undefined
  payment_day: number | undefined = undefined
  annual_fee_required_swipes: number | undefined = undefined
  annual_fee_manual_swipes: number | undefined = undefined
  credit_limit: number | undefined = undefined
  grace_period_days: number | undefined = undefined
  interest_free_days: number | undefined = undefined
  sort_order: number | undefined = undefined
}
