export type ReminderType = 'payment_due' | 'subscription_due' | 'pressure_alert' | 'ai_insight' | 'monthly_review' | 'data_stale' | 'milestone' | 'update'

export class Notification {
  id: string = ''
  user_id: string = ''
  debt_id: string = ''
  subscription_id: string = ''
  reminder_type: ReminderType = 'payment_due'
  title: string = ''
  body: string = ''
  is_read: boolean = false
  sent_at: string = ''
  read_at: string = ''
}
