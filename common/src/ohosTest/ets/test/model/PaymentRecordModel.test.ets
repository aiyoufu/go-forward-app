import { describe, it, expect } from '@ohos/hypium'
import { PaymentRecord } from '../../../../main/ets/model/PaymentRecordModel'

export default function paymentRecordModelTest() {
  describe('PaymentRecordModel', () => {

    describe('PaymentRecord', () => {
      it('默认值正确', 0, () => {
        const p = new PaymentRecord()
        expect(p.id).assertEqual('')
        expect(p.debt_id).assertEqual('')
        expect(p.user_id).assertEqual('')
        expect(p.period_number).assertEqual(0)
        expect(p.payment_date).assertEqual('')
        expect(p.scheduled_date).assertEqual('')
        expect(p.amount_paid).assertEqual(0)
        expect(p.principal_paid).assertEqual(0)
        expect(p.interest_paid).assertEqual(0)
        expect(p.balance_after).assertEqual(0)
        expect(p.is_manual).assertTrue()
        expect(p.created_at).assertEqual('')
      })
      it('可赋值', 0, () => {
        const p = new PaymentRecord()
        p.id = 'pay-1'
        p.debt_id = 'debt-1'
        p.period_number = 3
        p.amount_paid = 500000
        p.principal_paid = 400000
        p.interest_paid = 100000
        p.balance_after = 1000000
        p.is_manual = false
        expect(p.id).assertEqual('pay-1')
        expect(p.debt_id).assertEqual('debt-1')
        expect(p.period_number).assertEqual(3)
        expect(p.amount_paid).assertEqual(500000)
        expect(p.principal_paid).assertEqual(400000)
        expect(p.interest_paid).assertEqual(100000)
        expect(p.balance_after).assertEqual(1000000)
        expect(p.is_manual).assertFalse()
      })
    })
  })
}
