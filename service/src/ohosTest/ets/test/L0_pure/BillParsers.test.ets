import { describe, it, expect } from '@ohos/hypium'
import { tryInstallmentPlanTable, looksLikeBillOcr, scanAllPayDates, hasInstallmentStructure, collectEqualAmountGroups, collectPeriodMarkers } from '../../../../main/ets/service/ai/BillPlanParser'
import { tryNaturalLanguageDebt, parseDueDateHint } from '../../../../main/ets/service/ai/BillNaturalParser'
import { normalizeText, round2, matchMoney, pad2, allZero, guessPlatform, creditAccountHint } from '../../../../main/ets/service/ai/BillParseShared'
import { LocalBillExtractService } from '../../../../main/ets/service/ai/LocalBillExtractService'

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

    it('分期表_逐元素截图_红圈期号单独成行', 0, () => {
      // 支付宝「分期详情」截图：OCR 常把期号徽标、金额、还款日各拆一行；
      // 纯金额行（58.98/19.66）不得被误当序号行把总期数推成 2
      const ocr = [
        '分期详情',
        '58.98',
        '0.00',
        '58.98',
        '分期本金',
        '分期服务费',
        '合计应还',
        '分期应还(元)',
        '最后还款日',
        '1',
        '19.66',
        '2026年09月12日',
        '2',
        '19.66',
        '2026年10月12日',
        '3',
        '19.66',
        '2026年11月12日'
      ].join('\n')
      const r = tryInstallmentPlanTable(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(3)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(19.66)
      expect(it.parsedFields.get('principal')).assertEqual(58.98)
      expect(it.parsedFields.get('current_balance')).assertEqual(58.98)
      expect(`${it.parsedFields.get('next_payment_date')}`).assertEqual('2026-09-12')
      expect(`${it.parsedFields.get('start_date')}`).assertEqual('2026-09-12')
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('installment')
    })

    it('分期表_金额与标签同行_不误判期号', 0, () => {
      const ocr = [
        '分期详情',
        '58.98 分期本金',
        '0.00 分期服务费',
        '58.98 合计应还',
        '1 19.66 2026年09月12日',
        '2 19.66 2026年10月12日',
        '3 19.66 2026年11月12日'
      ].join('\n')
      const r = tryInstallmentPlanTable(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(3)
      expect(it.parsedFields.get('principal')).assertEqual(58.98)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(19.66)
    })

    it('分期表_无关文本_null', 0, () => {
      expect(tryInstallmentPlanTable('今天天气真好出去玩')).assertNull()
    })

    it('分期表_叙事页无计划表结构_null', 0, () => {
      // 月付商品详情：无 n/m、无序号行，日期是下单/收货时间戳而非「同日连续月」计划 → 不是分期表
      const ocr = [
        '商品详情', '吵吵Studio', '89.15',
        '下单成功', '2026-08-20 23:48:14', '占用月付额度89.15元，确认收货后才计入账单',
        '确认收货', '2026-09-05 18:33:39', '89.15元计入10月账单，还款日10月6号',
        '分期方式', '不分期'
      ].join('\n')
      expect(tryInstallmentPlanTable(ocr)).assertNull()
    })

    it('分期表_还款日非同日连续月_不算期数', 0, () => {
      // 有「分期」字样，但日期不构成「每月固定日、月份连续」的计划签名
      const ocr = '分期方式 月付额度89.15元 2026-08-20 下单成功 2026-09-05 确认收货' +
        ' 89.15元计入10月账单 还款日10月6号'
      expect(tryInstallmentPlanTable(ocr)).assertNull()
    })

    it('guessPlatform_裸月付_通配账户提示', 0, () => {
      expect(guessPlatform('占用月付额度89.15元')).assertEqual('月付')
      expect(guessPlatform('美团月付账单')).assertEqual('美团月付')
      expect(guessPlatform('花呗欠3000')).assertEqual('花呗')
    })

    it('分期表_等额期供3次_无日期无序号_仍识别分期', 0, () => {
      // OCR 丢失日期与序号徽标：等额期供 19.66×3 即分期结构证据
      const ocr = [
        '分期详情', '58.98 分期本金', '0.00 分期服务费', '58.98 合计应还',
        '分期应还(元)', '最后还款日', '19.66', '19.66', '19.66'
      ].join('\n')
      const r = tryInstallmentPlanTable(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(3)
      expect(it.parsedFields.get('monthly_payment')).assertEqual(19.66)
      expect(it.parsedFields.get('current_balance')).assertEqual(58.98)
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('installment')
    })

    it('分期表_表头日期与首期粘连_去重后3期', 0, () => {
      // 「最后还款日2026年09月12日」表头粘连 + 行金额带元：日期去重后 3 期
      const ocr = '分期应还(元) 最后还款日2026年09月12日 ' +
        '1 19.66元 2026年09月12日 2 19.66元 2026年10月12日 3 19.66元 2026年11月12日'
      const r = tryInstallmentPlanTable(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(3)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(3)
      expect(`${it.parsedFields.get('next_payment_date')}`).assertEqual('2026-09-12')
    })

    it('scanAllPayDates_同一日期去重', 0, () => {
      const dates = scanAllPayDates('最后还款日2026年09月12日 19.66 2026年09月12日 2026年10月12日')
      expect(dates.length).assertEqual(2)
      expect(dates[0]).assertEqual('2026-09-12')
    })

    it('hasInstallmentStructure_结构证据判定', 0, () => {
      // 同日连续月计划
      expect(hasInstallmentStructure('1 19.66 2026年09月12日 2 19.66 2026年10月12日 3 19.66 2026年11月12日')).assertTrue()
      // 等额期供 ×3 + 三个不同日期
      expect(hasInstallmentStructure('19.66元 2026年09月12日 19.66元 2026年10月12日 19.66元 2026年11月12日')).assertTrue()
      // 一次性叙事页：金额提及 3 次但日期只有 2 个时间戳
      expect(hasInstallmentStructure('占用月付额度89.15元 2026-08-20 下单 89.15元 2026-09-05 确认收货 89.15元计入账单')).assertFalse()
      // 单一还款日
      expect(hasInstallmentStructure('还款日10月6号')).assertFalse()
    })

    it('collectEqualAmountGroups_collectPeriodMarkers_枚举', 0, () => {
      const groups = collectEqualAmountGroups('58.98 分期本金 58.98 合计应还 19.66 19.66 19.66')
      expect(groups.length).assertEqual(2)
      expect(groups[0]).assertEqual('58.98×2')
      expect(groups[1]).assertEqual('19.66×3')
      const markers = collectPeriodMarkers('1/3期 已还清 第2期 分6期')
      expect(markers.length).assertEqual(3)
      expect(markers[0]).assertEqual('1/3期')
      expect(markers[1]).assertEqual('第2期')
      expect(markers[2]).assertEqual('分6期')
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

    it('自然语言_月付不分期_一次性带还款日', 0, () => {
      // 抖音月付商品详情：两处 89.15不得相加成 178.3，应识别一次性 + 还款日10月6号
      const ocr = [
        '商品详情', '吵吵Studio', '89.15',
        '处理进度',
        '下单成功', '2026-08-20 23:48:14', '占用月付额度89.15元，确认收货后才计入账单',
        '确认收货', '2026-09-05 18:33:39', '89.15元计入10月账单，还款日10月6号',
        '商品订单', '商城消费', '分期方式', '不分期', '交易账户', '桃和兮'
      ].join('\n')
      const r = tryNaturalLanguageDebt(ocr)
      expect(r !== null).assertTrue()
      if (r === null) {
        return
      }
      const it = r.items[0]
      expect(it.parsedFields.get('total_periods')).assertEqual(1)
      expect(it.parsedFields.get('remaining_periods')).assertEqual(1)
      expect(it.parsedFields.get('current_balance')).assertEqual(89.15)
      expect(`${it.parsedFields.get('debt_type')}`).assertEqual('credit_card')
      expect(`${it.parsedFields.get('platform')}`).assertEqual('月付')
      expect(it.parsedFields.get('payment_day')).assertEqual(6)
      const next = `${it.parsedFields.get('next_payment_date')}`
      expect(next.substring(5)).assertEqual('10-06')
    })

    it('parseDueDateHint_带年与不带年', 0, () => {
      expect(parseDueDateHint('还款日2026年10月6号')).assertEqual('2026-10-06')
      const noYear = parseDueDateHint('89.15元计入10月账单，还款日10月6号')
      expect(noYear !== null).assertTrue()
      if (noYear !== null) {
        expect(noYear.substring(5)).assertEqual('10-06')
      }
      const suffixForm = parseDueDateHint('账单10月6号还款')
      expect(suffixForm !== null).assertTrue()
      if (suffixForm !== null) {
        expect(suffixForm.substring(5)).assertEqual('10-06')
      }
      expect(parseDueDateHint('没有日期信息')).assertNull()
    })

    it('自然语言_带分期结构证据_不判一次性', 0, () => {
      // 分期详情类文本（等额期供 ×3 + 三个日期）即使带「最后还款日X月X日 + 金额元」，
      // 也不得被降级成一次性；结构证据成立但期数没解析出 → null 交给 LLM
      const r = tryNaturalLanguageDebt(
        '最后还款日2026年09月12日 19.66元 2026年09月13日 19.66元 2026年10月14日 19.66元 2026年11月15日 分期')
      expect(r).assertNull()
    })

    it('自然语言_无关文本_null', 0, () => {
      expect(tryNaturalLanguageDebt('今天天气真好出去玩')).assertNull()
    })
  })
}
