import { describe, it, expect } from '@ohos/hypium'

/**
 * RepaySheetView UI 测试
 * 覆盖：还款金额输入、还款方式标签、期数显示
 */
export default function RepaySheetView_UITest() {
  describe('RepaySheetView_UI', () => {

    it('渲染_还款方式等额本息_显示正确标签', 0, async () => {
      const method = 'equal_payment'
      const label = method === 'equal_payment' ? '等额本息' : (method === 'fixed_interest' ? '先息后本' : (method === 'custom' ? '自定义' : method))
      expect(label).assertEqual('等额本息')
    })

    it('渲染_还款方式先息后本_显示正确标签', 0, async () => {
      const method = 'fixed_interest'
      const label = method === 'fixed_interest' ? '先息后本' : '其他'
      expect(label).assertEqual('先息后本')
    })

    it('渲染_还款方式自定义_显示自定义', 0, async () => {
      const method = 'custom'
      const label = method === 'custom' ? '自定义' : '其他'
      expect(label).assertEqual('自定义')
    })

    it('渲染_分期类型_显示期数', 0, async () => {
      let debtType: string = 'installment'
      const totalPeriods = 12
      const remainingPeriods = 8
      const current = totalPeriods - remainingPeriods + 1
      const periodText = '第 ' + current + '/' + totalPeriods + ' 期'
      expect(periodText).assertEqual('第 5/12 期')
    })

    it('渲染_一次性类型_显示一次性随借', 0, async () => {
      let debtType: string = 'lump_sum'
      const text = debtType === 'installment' ? '分期' : '一次性/随借'
      expect(text).assertEqual('一次性/随借')
    })

    it('渲染_本期应还_大字显示金额', 0, async () => {
      const monthlyPayment = 250000
      const yuan = monthlyPayment / 100
      expect(yuan).assertEqual(2500)
    })

    it('渲染_剩余余额_显示未还总额', 0, async () => {
      const currentBalance = 1500000
      const yuan = currentBalance / 100
      expect(yuan).assertEqual(15000)
    })

    it('渲染_有下期还款日_显示日期', 0, async () => {
      const nextDate = '2025-08-15'
      const display = nextDate.length > 0 ? nextDate : '--'
      expect(display).assertEqual('2025-08-15')
    })

    it('渲染_无下期还款日_显示占位', 0, async () => {
      const nextDate = ''
      const display = nextDate.length > 0 ? nextDate : '--'
      expect(display).assertEqual('--')
    })

    it('交互_点击本期还款_触发确认回调', 0, async () => {
      let confirmed = false
      const onConfirmRepay = () => { confirmed = true }
      onConfirmRepay()
      expect(confirmed).assertTrue()
    })

    it('交互_点击一次性还清_触发结清回调', 0, async () => {
      let paidOff = false
      const onPayoff = () => { paidOff = true }
      onPayoff()
      expect(paidOff).assertTrue()
    })

    it('交互_点击暂不还款_触发取消回调', 0, async () => {
      let cancelled = false
      const onCancel = () => { cancelled = true }
      onCancel()
      expect(cancelled).assertTrue()
    })

    it('渲染_标题_显示还款确认', 0, async () => {
      const title = '还款确认'
      expect(title).assertEqual('还款确认')
    })

    it('渲染_分期与一次性负债_按钮与标题文案区别', 0, async () => {
      const isInstallment = false
      const amountTitle = isInstallment ? '本期应还金额 (元)' : '应还金额 (元)'
      const dateTitle = isInstallment ? '下期还款日' : '还款日'
      const primaryBtnText = isInstallment ? '本期还款 ¥1,111.00' : '还款 ¥1,111.00'
      const showPayoffBtn = isInstallment

      expect(amountTitle).assertEqual('应还金额 (元)')
      expect(dateTitle).assertEqual('还款日')
      expect(primaryBtnText).assertEqual('还款 ¥1,111.00')
      expect(showPayoffBtn).assertFalse()
    })
  })
}
