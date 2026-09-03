import { describe, it, expect } from '@ohos/hypium'
import { tryInstallmentPlanTable, looksLikeBillOcr, scanAllPayDates } from '../../../../main/ets/service/ai/BillPlanParser'
import { tryNaturalLanguageDebt } from '../../../../main/ets/service/ai/BillNaturalParser'
import { normalizeText, round2, matchMoney, pad2, allZero, guessPlatform, creditAccountHint } from '../../../../main/ets/service/ai/BillParseShared'

export default function billParsersTest() {
  describe('BillParseShared', () => {
    it('normalizeText_千分位与空白', 0, () => {
      expect(normalizeText('5,299.00  1,766.34')).assertEqual('5299.00 1766.34')
    })

    it('round2_两位舍入', 0, () => {
      expect(round2(110.875)).assertEqual(110.88)
    })

    it('matchMoney_命中与未命中', 0, () => {
      expect(matchMoney('月供4500元', /月供([0-9]+(?:\.[0-9]+)?)/)).assertEqual(4500)
      expect(matchMoney('没有金额', /月供([0-9]+)/)).assertNull()
    })

    it('pad2_allZero', 0, () => {
      expect(pad2(7)).assertEqual('07')
      expect(pad2(15)).assertEqual('15')
      expect(allZero([0, 0])).assertTrue()
      expect(allZero([0, 1])).assertFalse()
    })

    it('guessPlatform_常见平台', 0, () => {
      expect(guessPlatform('美团月付账单')).assertEqual('美团月付')
      expect(guessPlatform('花呗欠3000')).assertEqual('花呗')
      expect(guessPlatform('hello')).assertEqual('未知平台')
    })

    it('creditAccountHint_映射', 0, () => {
      expect(creditAccountHint('', '美团')).assertEqual('美团月付')
      expect(creditAccountHint('白条分期', '')).assertEqual('京东白条')
    })
  })

  describe('BillPlanParser', () => {
    it('looksLikeBillOcr_宽松检测', 0, () => {
      expect(looksLikeBillOcr('分期金额332.62元')).assertTrue()
      expect(looksLikeBillOcr('今天天气真好')).assertFalse()
    })

    it('scanAllPayDates_中文日期', 0, () => {
      const dates = scanAllPayDates('还款日 2026年07月12日 和 2026-08-12')
      expect(dates.length).assertEqual(2)
      expect(dates[0]).assertEqual('2026-07-12')
    })

    it('分期表_美团样例', 0, () => {
      const ocr =
        '单据分期详情\n分期服务费 3.33\n支付方式 单据分期\n分期金额332.62元\n' +
        '1/3期 已还清 110.87\n还款日 2026-07-08 含服务费0.00 3.33\n' +
        '2/3期 110.87\n还款日 2026-09-03 含服务费0.00 3.33\n' +
        '3/3期 114.21\n还款日 2026-10-03 含服务费3.33\n美团'
      const r = tryInstallmentPlanTable(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(2)
      expect(`${it.parsedFields.get('platform')}`).assertEqual('美团月付')
    })

    it('分期表_无关文本_null', 0, () => {
      expect(tryInstallmentPlanTable('今天天气真好出去玩')).assertNull()
    })
  })

  describe('BillNaturalParser', () => {
    it('自然语言_招行分期', 0, () => {
      const r = tryNaturalLanguageDebt(
        '我在招行信用卡办了一笔12期的家装分期，总共5万块，每月还4500，每月13号还款')
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(12)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(4500)
      expect(it.parsedFields.get('payment_day')).assertEqual(13)
    })

    it('自然语言_一次性还清', 0, () => {
      const r = tryNaturalLanguageDebt('京东白条2000元，一次性还清')
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      expect(r.items[0].parsedFields.get('current_balance')).assertEqual(2000)
      expect(r.items[0].parsedFields.get('total_periods')).assertEqual(1)
    })

    it('自然语言_无关文本_null', 0, () => {
      expect(tryNaturalLanguageDebt('今天天气真好出去玩')).assertNull()
    })
  })
}
