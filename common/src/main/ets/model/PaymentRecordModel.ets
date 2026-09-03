export class PaymentRecord {
  id: string = ''
  debt_id: string = ''
  user_id: string = ''
  period_number: number = 0
  payment_date: string = ''
  scheduled_date: string = ''
  amount_paid: number = 0
  principal_paid: number = 0
  interest_paid: number = 0
  balance_after: number = 0
  is_manual: boolean = true
  created_at: string = ''
}
