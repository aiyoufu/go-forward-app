import { describe, it, expect } from '@ohos/hypium'
import { DebtFormPreview, DebtFormPreviewInput, DebtPreviewItem } from '../../../../main/ets/service/DebtFormPreview'
import { CustomScheduleItem } from '../../../../main/ets/service/CalculationService'

export default function debtFormPreviewTest() {
  describe('DebtFormPreview_buildSchedule', () => {
    it('余额为0返回空', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '0'
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(0)
    })
    it('非分期_单笔返回1条', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '5000'
      input.isInstallment = false
      input.repaymentDate = '2025-06-01'
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(1)
      expect(result[0].period_number).assertEqual(1)
      expect(result[0].status).assertEqual('pending')
      expect(result[0].date).assertEqual('2025-06-01')
    })
    it('分期_零利率_等额', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '6000'
      input.monthlyPaymentYuan = '1000'
      input.totalPeriods = '6'
      input.remainingPeriods = '6'
      input.annualRate = '0'
      input.isInstallment = true
      input.repaymentMethod = 'equal_payment'
      input.repaymentDate = '2025-01-01'
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(6)
    })
    it('分期_期数为0返回空', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '6000'
      input.totalPeriods = '0'
      input.remainingPeriods = '0'
      input.isInstallment = true
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(0)
    })
    it('分期_部分已还_含paid和pending', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '12000'
      input.monthlyPaymentYuan = '2000'
      input.totalPeriods = '12'
      input.remainingPeriods = '6'
      input.annualRate = '0'
      input.isInstallment = true
      input.repaymentMethod = 'equal_payment'
      input.repaymentDate = '2025-07-01'
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertLarger(0)
      let hasPaid = false
      let hasPending = false
      for (const item of result) {
        if (item.status === 'paid') { hasPaid = true }
        if (item.status === 'pending') { hasPending = true }
      }
      expect(hasPaid).assertTrue()
      expect(hasPending).assertTrue()
    })
    it('结果按期数排序', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '6000'
      input.monthlyPaymentYuan = '1000'
      input.totalPeriods = '6'
      input.remainingPeriods = '6'
      input.annualRate = '0'
      input.isInstallment = true
      input.repaymentMethod = 'equal_payment'
      input.repaymentDate = '2025-01-01'
      const result = DebtFormPreview.buildSchedule(input)
      for (let i = 1; i < result.length; i++) {
        expect(result[i].period_number).assertLarger(result[i - 1].period_number)
      }
    })
    it('自定义还款方式_覆盖金额', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '3000'
      input.monthlyPaymentYuan = '1000'
      input.totalPeriods = '3'
      input.remainingPeriods = '3'
      input.annualRate = '0'
      input.isInstallment = true
      input.repaymentMethod = 'custom'
      input.repaymentDate = '2025-01-01'
      input.customSchedule = [
        { period_number: 1, principal: 50000, interest: 10000, total: 60000 } as any,
        { period_number: 2, principal: 100000, interest: 0, total: 100000 } as any,
        { period_number: 3, principal: 150000, interest: 0, total: 150000 } as any,
      ]
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(3)
      expect(result[0].total).assertEqual(60000)
      expect(result[1].total).assertEqual(100000)
    })
    it('自定义表_使用OCR还款日_首期7月8日', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '332.62'
      input.monthlyPaymentYuan = '110.87'
      input.totalPeriods = '3'
      input.remainingPeriods = '2'
      input.annualRate = '0'
      input.isInstallment = true
      input.repaymentMethod = 'custom'
      // 下次还款为 9 月；若误用推算，第 1 期会变成 8 月而非 7 月 8 日
      input.repaymentDate = '2026-09-03'
      const s1 = new CustomScheduleItem()
      s1.period_number = 1
      s1.principal = 11087
      s1.interest = 0
      s1.total = 11087
      s1.date = '2026-07-08'
      s1.paid = true
      const s2 = new CustomScheduleItem()
      s2.period_number = 2
      s2.principal = 11087
      s2.interest = 0
      s2.total = 11087
      s2.date = '2026-09-03'
      s2.paid = false
      const s3 = new CustomScheduleItem()
      s3.period_number = 3
      s3.principal = 11088
      s3.interest = 333
      s3.total = 11421
      s3.date = '2026-10-03'
      s3.paid = false
      input.customSchedule = [s1, s2, s3]
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(3)
      expect(result[0].date).assertEqual('2026-07-08')
      expect(result[0].status).assertEqual('paid')
      expect(result[1].date).assertEqual('2026-09-03')
      expect(result[2].date).assertEqual('2026-10-03')
    })
    it('中信等额_每期应还与服务费相同', 0, async () => {
      // 58.31×9 - 519.93 = 4.86 → 每期息 0.54；勿走年化 PMT 算出 58.55
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '519.93'
      input.monthlyPaymentYuan = '58.31'
      input.totalPeriods = '9'
      input.remainingPeriods = '1'
      input.totalInterestYuan = '4.86'
      input.annualRate = '3.23'
      input.isInstallment = true
      input.repaymentMethod = 'equal_payment'
      input.repaymentDate = '2026-01-04'
      input.firstPaymentDate = '2026-01-04'
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(9)
      for (let i = 0; i < 8; i++) {
        expect(result[i].total).assertEqual(5831)
        expect(result[i].interest).assertEqual(54)
        expect(result[i].principal).assertEqual(5777)
      }
      expect(result.filter((x: DebtPreviewItem) => x.status === 'paid').length).assertEqual(7)
      expect(result[7].status).assertEqual('pending')
      expect(result[8].status).assertEqual('pending')
      expect(result[8].total).assertEqual(5831)
      expect(result[0].date).assertEqual('2026-01-04')
    })
    it('非自定义方式_预览编辑覆盖单期', 0, async () => {
      // 等额摊算基础上，用户在预览中改了第 8 期金额/利息：该期按编辑值，其余期不变
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '519.93'
      input.monthlyPaymentYuan = '58.31'
      input.totalPeriods = '9'
      input.remainingPeriods = '9'
      input.totalInterestYuan = '4.86'
      input.annualRate = '3.23'
      input.isInstallment = true
      input.repaymentMethod = 'equal_payment'
      input.repaymentDate = '2026-01-04'
      input.firstPaymentDate = '2026-01-04'
      const edited = new CustomScheduleItem()
      edited.period_number = 8
      edited.principal = 4000
      edited.interest = 100
      edited.total = 4100
      input.customSchedule = [edited]
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(9)
      expect(result[7].total).assertEqual(4100)
      expect(result[7].principal).assertEqual(4000)
      expect(result[7].interest).assertEqual(100)
      expect(result[0].total).assertEqual(5831)
      expect(result[8].total).assertEqual(5831)
    })
    it('非分期_无还款日期_使用today', 0, async () => {
      const input = new DebtFormPreviewInput()
      input.currentBalanceYuan = '5000'
      input.isInstallment = false
      input.repaymentDate = ''
      const result = DebtFormPreview.buildSchedule(input)
      expect(result.length).assertEqual(1)
      expect(result[0].date.length).assertLarger(0)
    })
  })

  describe('DebtPreviewItem_constructor', () => {
    it('构造参数正确', 0, async () => {
      const item = new DebtPreviewItem(1, '2025-01-01', 100, 10, 110, 900, 'pending')
      expect(item.period_number).assertEqual(1)
      expect(item.date).assertEqual('2025-01-01')
      expect(item.principal).assertEqual(100)
      expect(item.interest).assertEqual(10)
      expect(item.total).assertEqual(110)
      expect(item.balance_after).assertEqual(900)
      expect(item.status).assertEqual('pending')
    })
  })
}
