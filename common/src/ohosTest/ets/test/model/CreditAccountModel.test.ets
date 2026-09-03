import { describe, it, expect } from '@ohos/hypium'
import {
  CreditAccount,
  CreateCreditAccountInput,
  UpdateCreditAccountInput
} from '../../../../main/ets/model/CreditAccountModel'

export default function creditAccountModelTest() {
  describe('CreditAccountModel', () => {

    describe('CreditAccount', () => {
      it('默认值正确', 0, () => {
        const ca = new CreditAccount()
        expect(ca.id).assertEqual('')
        expect(ca.user_id).assertEqual('')
        expect(ca.name).assertEqual('')
        expect(ca.last_four).assertEqual('')
        expect(ca.color).assertEqual('')
        expect(ca.icon_url).assertEqual('')
        expect(ca.expiry_date).assertEqual('')
        expect(ca.cvv).assertEqual('')
        expect(ca.bill_day).assertEqual(1)
        expect(ca.payment_day).assertEqual(1)
        expect(ca.annual_fee_required_swipes).assertEqual(0)
        expect(ca.annual_fee_manual_swipes).assertEqual(0)
        expect(ca.credit_limit).assertEqual(0)
        expect(ca.grace_period_days).assertEqual(0)
        expect(ca.sort_order).assertEqual(0)
      })
      it('可赋值', 0, () => {
        const ca = new CreditAccount()
        ca.name = '招商银行信用卡'
        ca.last_four = '1234'
        ca.credit_limit = 5000000
        ca.bill_day = 15
        expect(ca.name).assertEqual('招商银行信用卡')
        expect(ca.last_four).assertEqual('1234')
        expect(ca.credit_limit).assertEqual(5000000)
        expect(ca.bill_day).assertEqual(15)
      })
    })

    describe('CreateCreditAccountInput', () => {
      it('默认值正确', 0, () => {
        const input = new CreateCreditAccountInput()
        expect(input.name).assertEqual('')
        expect(input.last_four).assertEqual('')
        expect(input.bill_day).assertEqual(1)
        expect(input.payment_day).assertEqual(1)
        expect(input.credit_limit).assertEqual(0)
        expect(input.sort_order).assertEqual(0)
      })
    })

    describe('UpdateCreditAccountInput', () => {
      it('所有字段默认undefined', 0, () => {
        const input = new UpdateCreditAccountInput()
        expect(input.name).assertEqual(undefined)
        expect(input.last_four).assertEqual(undefined)
        expect(input.color).assertEqual(undefined)
        expect(input.bill_day).assertEqual(undefined)
        expect(input.payment_day).assertEqual(undefined)
        expect(input.credit_limit).assertEqual(undefined)
        expect(input.sort_order).assertEqual(undefined)
      })
      it('可设置部分字段', 0, () => {
        const input = new UpdateCreditAccountInput()
        input.name = '工商银行'
        input.credit_limit = 3000000
        expect(input.name).assertEqual('工商银行')
        expect(input.credit_limit).assertEqual(3000000)
        expect(input.last_four).assertEqual(undefined)
      })
    })
  })
}
