/**
 * 负债表单字段校验（S5）— 纯逻辑，无 UI
 */
export class DebtFormFields {
  platform: string = ''
  currentBalance: string = ''
  isInstallment: boolean = false
  creditAccountId: string = ''
  paymentDay: string = ''
  repaymentMethod: string = 'equal_payment'
  monthlyPayment: string = ''
  remainingPeriods: string = ''
  totalPeriods: string = ''
  repaymentDate: string = ''
}

export class DebtFormValidator {
  /**
   * @returns 空串表示通过，否则为错误文案
   */
  static validate(f: DebtFormFields): string {
    if (f.platform.trim().length === 0) {
      return '请输入平台名称'
    }
    const balanceNum = Number(f.currentBalance)
    if (isNaN(balanceNum) || balanceNum <= 0) {
      return '请输入正确的负债金额'
    }
    if (f.isInstallment) {
      if (f.creditAccountId.length === 0) {
        const payDayNum = Number(f.paymentDay)
        if (!f.paymentDay || isNaN(payDayNum) || payDayNum < 1 || payDayNum > 31) {
          return '请输入正确的每月还款日 (1-31)'
        }
      }
      if (f.repaymentMethod !== 'custom') {
        const paymentNum = Number(f.monthlyPayment)
        if (isNaN(paymentNum) || paymentNum <= 0) {
          return '请输入正确的每月应还金额'
        }
      }
      const remainingNum = Number(f.remainingPeriods)
      if (isNaN(remainingNum) || remainingNum < 0) {
        return '请输入正确的剩余期数'
      }
      const totalPeriodsNum = Number(f.totalPeriods)
      if (isNaN(totalPeriodsNum) || totalPeriodsNum <= 0) {
        return '请输入正确的总期数'
      }
      if (totalPeriodsNum < remainingNum) {
        return '总期数不能小于剩余期数'
      }
    } else {
      if (f.creditAccountId.length === 0) {
        if (f.repaymentDate.length === 0) {
          return '请选择还款日期'
        }
      }
    }
    return ''
  }
}
