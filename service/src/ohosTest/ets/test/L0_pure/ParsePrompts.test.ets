import { describe, it, expect } from '@ohos/hypium'
import { buildUnifiedSystemPrompt, coerceDebtTypeByPeriods, normalizeFlexibleDate } from '../../../../main/ets/service/ai/ParsePrompts'

// 提示词回归：统一提示词（文字/图片共用）的语义原则锁。
// 设计意图：按概念本质引导模型通用理解，先判定再提取；不做逐文案/逐格式枚举。
// 日期形态由账单/票据决定，提示词不得把输入锁成 ISO；归一化是端侧的事。
export default function parsePromptsTest() {
  describe('ParsePrompts_统一提示词', () => {
    const p = buildUnifiedSystemPrompt('2026-09-08')

    it('注入当前日期', 0, () => {
      expect(p.indexOf('2026-09-08') >= 0).assertTrue()
    })

    it('先判定后提取', 0, () => {
      expect(p.indexOf('【判定】') >= 0).assertTrue()
      expect(p.indexOf('【提取】') >= 0).assertTrue()
    })

    it('分期与一次性按语义定义', 0, () => {
      expect(p.indexOf('按语义，不看特定文案') >= 0).assertTrue()
      expect(p.indexOf('多期还款计划') >= 0).assertTrue()
      expect(p.indexOf('逐月重复') >= 0).assertTrue()
      expect(p.indexOf('单笔到期应还') >= 0).assertTrue()
      expect(p.indexOf('都不影响判定') >= 0).assertTrue()
    })

    it('一次性判定收窄_月付产品归属', 0, () => {
      expect(p.indexOf('无多期计划') >= 0).assertTrue()
      expect(p.indexOf('不是下单') >= 0).assertTrue()
      expect(p.indexOf('月付类产品') >= 0).assertTrue()
    })

    it('逐期列表优先于商品页月付_不得收成一次性', 0, () => {
      // 电商「分期详情」：商品名/商品页 + 序号+金额+日期列表，曾被「月付类产品同样处理」收成一次性
      expect(p.indexOf('序号+金额+日期') >= 0).assertTrue()
      expect(p.indexOf('仍是分期') >= 0).assertTrue()
      expect(p.indexOf('同样处理') < 0).assertTrue()
    })

    it('coerceDebtTypeByPeriods_多期覆盖一次性', 0, () => {
      expect(coerceDebtTypeByPeriods('credit_card', 6, 6)).assertEqual('installment')
      expect(coerceDebtTypeByPeriods('credit_card', 1, 6)).assertEqual('installment')
      expect(coerceDebtTypeByPeriods('credit_card', 1, 1)).assertEqual('credit_card')
      expect(coerceDebtTypeByPeriods('installment', 6, 6)).assertEqual('installment')
      expect(coerceDebtTypeByPeriods('loan', 12, 12)).assertEqual('loan')
    })

    it('字段契约完整', 0, () => {
      expect(p.indexOf('record_type') >= 0).assertTrue()
      expect(p.indexOf('principal') >= 0).assertTrue()
      expect(p.indexOf('bill_day') >= 0).assertTrue()
      expect(p.indexOf('billing_cycle') >= 0).assertTrue()
      expect(p.indexOf('credit_limit') >= 0).assertTrue()
      expect(p.indexOf('annual_rate') >= 0).assertTrue()
      expect(p.indexOf('repayment_plan') >= 0).assertTrue()
      expect(p.indexOf('start_date') >= 0).assertTrue()
      expect(p.indexOf('currency') >= 0).assertTrue()
    })

    it('已还判定唯一标准_显式值优先', 0, () => {
      expect(p.indexOf('还款日严格早于今天') >= 0).assertTrue()
      expect(p.indexOf('禁止再算覆盖') >= 0).assertTrue()
      expect(p.indexOf('勿减1') >= 0).assertTrue()
    })

    it('账单周期与还款日推导', 0, () => {
      expect(p.indexOf('勿把下月账单当本月需还') >= 0).assertTrue()
      expect(p.indexOf('next_payment_date') >= 0).assertTrue()
    })

    it('分类含月付产品与优先级', 0, () => {
      expect(p.indexOf('月付/先享后付') >= 0).assertTrue()
      expect(p.indexOf('debt > credit_account > subscription') >= 0).assertTrue()
    })

    it('无枚举式补丁且补齐边界契约', 0, () => {
      expect(p.indexOf('铁证分期') < 0).assertTrue()
      expect(p.indexOf('国家贴息') < 0).assertTrue()
      expect(p.indexOf('禁止编造') >= 0).assertTrue()
      expect(p.indexOf('[输入已截断]') >= 0).assertTrue()
      expect(p.indexOf('"once"') < 0).assertTrue()
      expect(p.indexOf('[本地提取信号]') < 0).assertTrue()
    })

    it('文字与图片共用_无输入形态分叉', 0, () => {
      expect(p.indexOf('文字或图片') >= 0).assertTrue()
      expect(p.indexOf('OCR') < 0).assertTrue()
    })

    it('日期不锁ISO_形态不限', 0, () => {
      expect(p.indexOf('日期形态不限') >= 0).assertTrue()
      // 提示词不得把日期输入/输出锁成 ISO 模板，否则模型会丢掉非 ISO 账单日期
      expect(p.indexOf('YYYY-MM-DD') < 0).assertTrue()
      expect(p.indexOf('YYYY-MM') < 0).assertTrue()
      expect(p.indexOf('ISO') < 0).assertTrue()
    })

    it('精简优先_控制长度', 0, () => {
      // 每次调用都吃 token；原则说清即可，禁止再膨胀回数千 token 的说明书
      expect(p.length < 1100).assertTrue()
    })
  })

  describe('ParsePrompts_日期归一化', () => {
    const today = '2026-09-08'

    it('已是公历横杠日期_原样规范', 0, () => {
      expect(normalizeFlexibleDate('2026-09-12', today)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('2026-9-12', today)).assertEqual('2026-09-12')
    })

    it('中文年月日_斜杠点号', 0, () => {
      expect(normalizeFlexibleDate('2026年9月12日', today)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('2026年09月12号', today)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('2026/9/12', today)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('2026.09.12', today)).assertEqual('2026-09-12')
    })

    it('缺年按今天补_未还日期可进下一年', 0, () => {
      expect(normalizeFlexibleDate('9月12日', today, false, true)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('09/12', today, false, true)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('3月12日', today, false, true)).assertEqual('2027-03-12')
      expect(normalizeFlexibleDate('3月12日', today, false, false)).assertEqual('2026-03-12')
    })

    it('相对日期_本月下月', 0, () => {
      expect(normalizeFlexibleDate('下月6号', today)).assertEqual('2026-10-06')
      expect(normalizeFlexibleDate('本月6日', today)).assertEqual('2026-09-06')
      expect(normalizeFlexibleDate('下个月12号', today)).assertEqual('2026-10-12')
    })

    it('有效期年月_不含日', 0, () => {
      expect(normalizeFlexibleDate('2026年9月', today, true)).assertEqual('2026-09')
      expect(normalizeFlexibleDate('2026-09', today, true)).assertEqual('2026-09')
      expect(normalizeFlexibleDate('09/28', today, true)).assertEqual('2028-09')
    })

    it('紧凑八位与带时间', 0, () => {
      expect(normalizeFlexibleDate('20260912', today)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('2026-09-12 14:30', today)).assertEqual('2026-09-12')
      expect(normalizeFlexibleDate('2026-09-12T00:00:00', today)).assertEqual('2026-09-12')
    })

    it('无法识别返回null', 0, () => {
      expect(normalizeFlexibleDate('', today)).assertNull()
      expect(normalizeFlexibleDate('不是日期', today)).assertNull()
      expect(normalizeFlexibleDate('——', today)).assertNull()
    })
  })
}
