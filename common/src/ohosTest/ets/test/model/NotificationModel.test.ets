import { describe, it, expect } from '@ohos/hypium'
import { Notification } from '../../../../main/ets/model/NotificationModel'

export default function notificationModelTest() {
  describe('NotificationModel', () => {

    describe('Notification', () => {
      it('默认值正确', 0, () => {
        const n = new Notification()
        expect(n.id).assertEqual('')
        expect(n.user_id).assertEqual('')
        expect(n.debt_id).assertEqual('')
        expect(n.subscription_id).assertEqual('')
        expect(n.reminder_type).assertEqual('payment_due')
        expect(n.title).assertEqual('')
        expect(n.body).assertEqual('')
        expect(n.is_read).assertFalse()
        expect(n.sent_at).assertEqual('')
        expect(n.read_at).assertEqual('')
      })
      it('可赋值', 0, () => {
        const n = new Notification()
        n.id = 'notif-1'
        n.reminder_type = 'subscription_due'
        n.title = '还款提醒'
        n.body = '您有一笔还款即将到期'
        n.is_read = true
        expect(n.id).assertEqual('notif-1')
        expect(n.reminder_type).assertEqual('subscription_due')
        expect(n.title).assertEqual('还款提醒')
        expect(n.body).assertEqual('您有一笔还款即将到期')
        expect(n.is_read).assertTrue()
      })
      it('reminder_type支持所有类型', 0, () => {
        const n = new Notification()
        const types: string[] = ['payment_due', 'subscription_due', 'pressure_alert', 'ai_insight', 'monthly_review', 'data_stale', 'milestone', 'update']
        for (const t of types) {
          n.reminder_type = t as any
          expect(n.reminder_type).assertEqual(t)
        }
      })
    })
  })
}
