import { describe, it, expect } from '@ohos/hypium'
import { DebtFormFields, DebtFormValidator } from '../../../../main/ets/service/DebtFormValidator'

function baseFields(): DebtFormFields {
  const f = new DebtFormFields()
  f.platform = '花呗'
  f.currentBalance = '8000'
  f.isInstallment = false
  // 非分期且无关联信用卡时必须有还款日
  f.repaymentDate = '2024-12-15'
  return f
}

export default function debtFormValidatorTest() {
  describe('DebtFormValidator', () => {
    it('合法表单_通过', 0, () => {
      const err = DebtFormValidator.validate(baseFields())
      expect(err).assertEqual('')
    })
    it('空平台_报错', 0, () => {
      const f = baseFields()
      f.platform = ''
      expect(DebtFormValidator.validate(f)).assertEqual('请输入平台名称')
    })
    it('金额非法_报错', 0, () => {
      const f = baseFields()
      f.currentBalance = '-1'
      expect(DebtFormValidator.validate(f).length).assertLarger(0)
    })
    it('分期缺还款日_报错', 0, () => {
      const f = baseFields()
      f.isInstallment = true
      f.creditAccountId = ''
      f.paymentDay = ''
      f.monthlyPayment = '1000'
      expect(DebtFormValidator.validate(f).length).assertLarger(0)
    })
  })
}
