import { describe, it, expect } from '@ohos/hypium'
import {
  Subscription,
  CreateSubscriptionInput,
  UpdateSubscriptionInput
} from '../../../../main/ets/model/SubscriptionModel'

export default function subscriptionModelTest() {
  describe('SubscriptionModel', () => {

    describe('Subscription', () => {
      it('默认值正确', 0, () => {
        const s = new Subscription()
        expect(s.id).assertEqual('')
        expect(s.user_id).assertEqual('')
        expect(s.name).assertEqual('')
        expect(s.category).assertEqual('other')
        expect(s.amount).assertEqual(0)
        expect(s.billing_cycle).assertEqual('monthly')
        expect(s.status).assertEqual('active')
        expect(s.reminder_days_before).assertEqual(3)
        expect(s.reminder_enabled).assertTrue()
        expect(s.credit_account_id).assertEqual('')
        expect(s.color).assertEqual('')
        expect(s.icon_url).assertEqual('')
        expect(s.note).assertEqual('')
      })
      it('可赋值', 0, () => {
        const s = new Subscription()
        s.name = 'Netflix'
        s.category = 'video'
        s.amount = 9800
        s.billing_cycle = 'annually'
        s.status = 'paused'
        expect(s.name).assertEqual('Netflix')
        expect(s.category).assertEqual('video')
        expect(s.amount).assertEqual(9800)
        expect(s.billing_cycle).assertEqual('annually')
        expect(s.status).assertEqual('paused')
      })
    })

    describe('CreateSubscriptionInput', () => {
      it('默认值正确', 0, () => {
        const input = new CreateSubscriptionInput()
        expect(input.name).assertEqual('')
        expect(input.category).assertEqual('other')
        expect(input.amount).assertEqual(0)
        expect(input.billing_cycle).assertEqual('monthly')
        expect(input.status).assertEqual('active')
        expect(input.reminder_days_before).assertEqual(3)
        expect(input.reminder_enabled).assertTrue()
      })
    })

    describe('UpdateSubscriptionInput', () => {
      it('所有字段默认undefined', 0, () => {
        const input = new UpdateSubscriptionInput()
        expect(input.name).assertEqual(undefined)
        expect(input.category).assertEqual(undefined)
        expect(input.amount).assertEqual(undefined)
        expect(input.billing_cycle).assertEqual(undefined)
        expect(input.status).assertEqual(undefined)
        expect(input.reminder_days_before).assertEqual(undefined)
        expect(input.reminder_enabled).assertEqual(undefined)
      })
      it('可设置部分字段', 0, () => {
        const input = new UpdateSubscriptionInput()
        input.name = 'Spotify'
        input.amount = 1500
        expect(input.name).assertEqual('Spotify')
        expect(input.amount).assertEqual(1500)
        expect(input.category).assertEqual(undefined)
      })
    })
  })
}
