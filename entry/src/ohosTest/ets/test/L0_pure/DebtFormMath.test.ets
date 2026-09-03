import { describe, it, expect } from '@ohos/hypium'
import {
  totalInterestFromPeriod,
  fixedInterestMonthly,
  resolveFirstPaymentDate,
  resolvePaymentDay,
  annualRateHintText
} from '../../../../main/ets/pages/common/DebtFormMath'
import { CreditAccount } from 'common'

function accountOf(id: string, payDay: number): CreditAccount {
  const a = new CreditAccount()
  a.id = id
  a.payment_day = payDay
  return a
}

export default function debtFormMathTest() {
  describe('DebtFormMath', () => {
    it('totalInterestFromPeriod_每期乘期数', 0, () => {
      expect(totalInterestFromPeriod(12.5, 6)).assertEqual('75.00')
    })

    it('fixedInterestMonthly_本金均摊加每期利息', 0, () => {
      expect(fixedInterestMonthly(1200, 12, 10)).assertEqual('110.00')
    })

    it('resolveFirstPaymentDate_开始日有效则直接用', 0, () => {
      const d = resolveFirstPaymentDate('2025-01-10', '2025-02-10', '12', '0')
      expect(d).assertEqual('2025-01-10')
    })

    it('resolvePaymentDay_优先关联账户还款日', 0, () => {
      const accounts: CreditAccount[] = [accountOf('a1', 25)]
      expect(resolvePaymentDay(accounts, 'a1', '10')).assertEqual(25)
    })

    it('resolvePaymentDay_无关联回退输入', 0, () => {
      expect(resolvePaymentDay([], '', '15')).assertEqual(15)
    })

    it('resolvePaymentDay_非法输入回退默认10', 0, () => {
      expect(resolvePaymentDay([], '', '')).assertEqual(10)
    })

    it('annualRateHintText_本金缺失返回基础说明', 0, () => {
      const t = annualRateHintText(0, 100, 12, 0, 'equal_payment')
      expect(t.startsWith('一般年利率')).assertTrue()
    })
  })
}
