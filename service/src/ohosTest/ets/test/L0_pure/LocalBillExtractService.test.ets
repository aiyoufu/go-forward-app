import { describe, it, expect } from '@ohos/hypium'
import { LocalBillExtractService } from '../../../../main/ets/service/ai/LocalBillExtractService'

export default function localBillExtractServiceTest() {
  describe('LocalBillExtractService_tryExtract', () => {
    it('空串_null', 0, () => {
      expect(LocalBillExtractService.tryExtract('')).assertNull()
    })

    it('无关文本_null', 0, () => {
      expect(LocalBillExtractService.tryExtract('今天天气真好出去玩')).assertNull()
    })

    it('自然语言_招行分期_完整', 0, () => {
      const r = LocalBillExtractService.tryExtract(
        '我在招行信用卡办了一笔12期的家装分期，总共5万块，每月还4500，每月13号还款')
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      expect(r.items.length).assertEqual(1)
      expect(LocalBillExtractService.isResultUsable(r)).assertTrue()
      const it = r.items[0]
      expect(it.recordType).assertEqual('debt')
      expect(`${it.parsedFields.get('platform')}`).assertContain('招商')
      expect(it.parsedFields.get('total_periods')).assertEqual(12)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(4500)
      expect(it.parsedFields.get('current_balance')).assertEqual(50000)
      expect(it.parsedFields.get('payment_day')).assertEqual(13)
    })

    it('自然语言_花呗分期', 0, () => {
      const r = LocalBillExtractService.tryExtract('花呗欠了3000元，分10期还完，每月还300')
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      expect(LocalBillExtractService.isResultUsable(r)).assertTrue()
      const it = r.items[0]
      expect(`${it.parsedFields.get('platform')}`).assertEqual('花呗')
      expect(it.parsedFields.get('total_periods')).assertEqual(10)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(300)
      expect(it.parsedFields.get('current_balance')).assertEqual(3000)
    })

    it('自然语言_一次性还清', 0, () => {
      const r = LocalBillExtractService.tryExtract('京东白条2000元，一次性还清')
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      expect(LocalBillExtractService.isResultUsable(r)).assertTrue()
      const it = r.items[0]
      expect(`${it.parsedFields.get('platform')}`).assertEqual('京东白条')
      expect(it.parsedFields.get('current_balance')).assertEqual(2000)
      expect(it.parsedFields.get('total_periods')).assertEqual(1)
    })

    it('分期计划表OCR_美团样例', 0, () => {
      const ocr =
        '单据分期详情\n分期服务费 3.33\n支付方式 单据分期\n分期金额332.62元\n' +
        '1/3期 已还清 110.87\n还款日 2026-07-08 含服务费0.00 3.33\n' +
        '2/3期 110.87\n还款日 2026-09-03 含服务费0.00 3.33\n' +
        '3/3期 114.21\n还款日 2026-10-03 含服务费3.33\n美团'
      const r = LocalBillExtractService.tryExtract(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      expect(LocalBillExtractService.isResultUsable(r)).assertTrue()
      const it = r.items[0]
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('installment')
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      // 分期本金 ≠ 剩余待还
      expect(it.parsedFields.get('principal')).assertEqual(332.62)
      // 未还 = 2+3 期合计
      expect(it.parsedFields.get('current_balance')).assertEqual(225.08)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(110.87)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(2)
      expect(`${it.parsedFields.get('platform')}`).assertEqual('美团月付')
      expect(`${it.parsedFields.get('next_payment_date')}`).assertEqual('2026-09-03')
      const note = `${it.parsedFields.get('note') ?? ''}`
      expect(note.indexOf('custom_schedule') >= 0).assertTrue()
      expect(note.indexOf('"period_number":3') >= 0).assertTrue()
      // 备注 text 为空，不写 OCR 技术文案
      expect(note.indexOf('"text":""') >= 0).assertTrue()
      // 第 3 期：应付 114.21、服务费 3.33 → 本金 110.88 元 = 11088 分，息 333 分
      expect(note.indexOf('"interest":333') >= 0).assertTrue()
      expect(note.indexOf('"principal":11088') >= 0).assertTrue()
      expect(note.indexOf('"total":11421') >= 0).assertTrue()
    })

    it('分期计划表OCR_金额拆行', 0, () => {
      const ocr =
        '单据分期详情\n支付方式 单据分期\n分期金额332.62元\n' +
        '1/3 期\n已还清\n110.87\n还款日 2026-07-08\n' +
        '2/3 期\n110.87\n还款日 2026-09-03\n' +
        '3/3 期\n114.21\n还款日 2026-10-03'
      const r = LocalBillExtractService.tryExtract(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('installment')
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(110.87)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(2)
    })

    // 京东/白条等「分期详情」：无 1/3 期，圆点序号 + 千分位金额 + 中文日期
    it('分期详情OCR_序号列表_千分位', 0, () => {
      const ocr =
        '分期详情\nApple/苹果 【送1年 等2种商品\n已优惠158.97(含国家贴息)\n' +
        '5,299.00 分期本金\n0.00 分期服务费\n5,299.00 合计应还\n' +
        '分期应还(元) 最后还款日\n' +
        '1 1,766.34 2026年07月12日\n' +
        '2 1,766.33 2026年08月12日\n' +
        '3 1,766.33 2026年09月12日\n'
      const r = LocalBillExtractService.tryExtract(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      expect(LocalBillExtractService.isResultUsable(r)).assertTrue()
      const it = r.items[0]
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('installment')
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(3)
      expect(it.parsedFields.get('principal')).assertEqual(5299)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(1766.34)
      // 三期合计 1766.34+1766.33+1766.33 = 5299.00
      expect(it.parsedFields.get('current_balance')).assertEqual(5299)
      expect(`${it.parsedFields.get('next_payment_date')}`).assertEqual('2026-07-12')
      expect(it.parsedFields.get('payment_day')).assertEqual(12)
      const note = `${it.parsedFields.get('note') ?? ''}`
      expect(note.indexOf('custom_schedule') >= 0).assertTrue()
      expect(note.indexOf('"period_number":3') >= 0).assertTrue()
    })

    // 金额在上、标签在下的 OCR 列布局 + 还款日个数兜底
    it('分期详情OCR_金额在前_还款日兜底期数', 0, () => {
      const ocr =
        '分期详情\n5299.00\n0.00\n5299.00\n分期本金\n分期服务费\n合计应还\n' +
        '1 1766.34 2026年07月12日\n' +
        '2 1766.33 2026年08月12日\n' +
        '3 1766.33 2026年09月12日'
      const r = LocalBillExtractService.tryExtract(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('installment')
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(1766.34)
    })

    it('isResultUsable_空项_false', 0, () => {
      const r = LocalBillExtractService.tryExtract('今天天气真好出去玩')
      // null 不算 usable
      expect(r === null || !LocalBillExtractService.isResultUsable(r)).assertTrue()
    })
  })
}
