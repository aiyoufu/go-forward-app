import { describe, it, expect } from '@ohos/hypium'
import {
  Debt,
  CreateDebtInput,
  UpdateDebtInput,
  PaymentScheduleItem,
  MonthlyPressure,
  MonthlyObligation
} from '../../../../main/ets/model/DebtModel'

export default function debtModelTest() {
  describe('DebtModel', () => {

    describe('Debt', () => {
      it('默认值正确', 0, () => {
        const d = new Debt()
        expect(d.id).assertEqual('')
        expect(d.user_id).assertEqual('')
        expect(d.platform).assertEqual('')
        expect(d.debt_type).assertEqual('installment')
        expect(d.principal).assertEqual(0)
        expect(d.current_balance).assertEqual(0)
        expect(d.monthly_payment).assertEqual(0)
        expect(d.total_periods).assertEqual(0)
        expect(d.remaining_periods).assertEqual(0)
        expect(d.repayment_method).assertEqual('equal_payment')
        expect(d.total_interest).assertEqual(0)
        expect(d.annual_rate_bp).assertEqual(0)
        expect(d.payment_day).assertEqual(1)
        expect(d.is_auto_payment).assertFalse()
        expect(d.status).assertEqual('active')
        expect(d.note).assertEqual('')
        expect(d.credit_account_id).assertEqual('')
        expect(d.icon_url).assertEqual('')
      })
      it('可赋值', 0, () => {
        const d = new Debt()
        d.id = 'test-id'
        d.platform = '招商银行'
        d.principal = 1000000
        d.debt_type = 'credit_card'
        d.status = 'completed'
        expect(d.id).assertEqual('test-id')
        expect(d.platform).assertEqual('招商银行')
        expect(d.principal).assertEqual(1000000)
        expect(d.debt_type).assertEqual('credit_card')
        expect(d.status).assertEqual('completed')
      })
    })

    describe('CreateDebtInput', () => {
      it('默认值正确', 0, () => {
        const input = new CreateDebtInput()
        expect(input.platform).assertEqual('')
        expect(input.debt_type).assertEqual('installment')
        expect(input.principal).assertEqual(0)
        expect(input.payment_day).assertEqual(1)
        expect(input.is_auto_payment).assertFalse()
        expect(input.note).assertEqual('')
      })
    })

    describe('UpdateDebtInput', () => {
      it('所有字段默认undefined', 0, () => {
        const input = new UpdateDebtInput()
        expect(input.platform).assertEqual(undefined)
        expect(input.debt_type).assertEqual(undefined)
        expect(input.principal).assertEqual(undefined)
        expect(input.note).assertEqual(undefined)
        expect(input.icon_url).assertEqual(undefined)
      })
      it('可设置部分字段', 0, () => {
        const input = new UpdateDebtInput()
        input.platform = '工商银行'
        input.principal = 500000
        expect(input.platform).assertEqual('工商银行')
        expect(input.principal).assertEqual(500000)
        expect(input.debt_type).assertEqual(undefined)
      })
    })

    describe('PaymentScheduleItem', () => {
      it('默认值正确', 0, () => {
        const item = new PaymentScheduleItem()
        expect(item.period_number).assertEqual(0)
        expect(item.date).assertEqual('')
        expect(item.principal).assertEqual(0)
        expect(item.interest).assertEqual(0)
        expect(item.total).assertEqual(0)
        expect(item.balance_after).assertEqual(0)
        expect(item.status).assertEqual('pending')
      })
      it('status可设为paid', 0, () => {
        const item = new PaymentScheduleItem()
        item.status = 'paid'
        expect(item.status).assertEqual('paid')
      })
    })

    describe('MonthlyPressure', () => {
      it('默认值正确', 0, () => {
        const mp = new MonthlyPressure()
        expect(mp.month).assertEqual('')
        expect(mp.amount).assertEqual(0)
        expect(mp.debtAmount).assertEqual(0)
        expect(mp.subscriptionAmount).assertEqual(0)
      })
    })

    describe('MonthlyObligation', () => {
      it('默认值正确', 0, () => {
        const o = new MonthlyObligation()
        expect(o.debtObligation).assertEqual(0)
        expect(o.subscriptionObligation).assertEqual(0)
        expect(o.total).assertEqual(0)
      })
      it('可赋值', 0, () => {
        const o = new MonthlyObligation()
        o.debtObligation = 500000
        o.subscriptionObligation = 20000
        o.total = 520000
        expect(o.total).assertEqual(520000)
      })
    })
  })
}
