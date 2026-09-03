export type BillingCycle =
  'once' | 'once_weekly' | 'once_quarterly' | 'once_annually' |
  'weekly' | 'biweekly' | 'monthly' | 'quarterly' | 'semiannually' | 'annually'

export type SubscriptionStatus = 'active' | 'paused' | 'cancelled'
export type SubscriptionCategory =
  'video' | 'music' | 'tools' | 'learning' | 'lifestyle' | 'storage' | 'fitness' | 'programming' | 'ai' | 'other'

export class Subscription {
  id: string = ''
  user_id: string = ''
  name: string = ''
  category: SubscriptionCategory = 'other'
  amount: number = 0
  billing_cycle: BillingCycle = 'monthly'
  next_billing_date: string = ''
  start_date: string = ''
  end_date: string = ''
  status: SubscriptionStatus = 'active'
  credit_account_id: string = ''
  color: string = ''
  icon_url: string = ''
  note: string = ''
  reminder_days_before: number = 3
  reminder_enabled: boolean = true
  created_at: string = ''
  updated_at: string = ''
  currency: string = 'CNY'
  original_amount_fen: number = 0
  locked_exchange_rate: number = 1.0
}

export class CreateSubscriptionInput {
  name: string = ''
  category: SubscriptionCategory = 'other'
  amount: number = 0
  billing_cycle: BillingCycle = 'monthly'
  next_billing_date: string = ''
  start_date: string = ''
  end_date: string = ''
  status: SubscriptionStatus = 'active'
  credit_account_id: string = ''
  color: string = ''
  icon_url: string = ''
  note: string = ''
  reminder_days_before: number = 3
  reminder_enabled: boolean = true
  currency: string = 'CNY'
  original_amount_fen: number = 0
  locked_exchange_rate: number = 1.0
}

export class UpdateSubscriptionInput {
  name: string | undefined = undefined
  category: SubscriptionCategory | undefined = undefined
  amount: number | undefined = undefined
  billing_cycle: BillingCycle | undefined = undefined
  next_billing_date: string | undefined = undefined
  start_date: string | undefined = undefined
  end_date: string | undefined = undefined
  status: SubscriptionStatus | undefined = undefined
  credit_account_id: string | undefined = undefined
  color: string | undefined = undefined
  icon_url: string | undefined = undefined
  note: string | undefined = undefined
  reminder_days_before: number | undefined = undefined
  reminder_enabled: boolean | undefined = undefined
  currency: string | undefined = undefined
  original_amount_fen: number | undefined = undefined
  locked_exchange_rate: number | undefined = undefined
}
