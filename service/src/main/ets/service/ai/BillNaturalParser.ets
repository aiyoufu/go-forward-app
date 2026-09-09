/**
 * 端侧自然语言负债描述解析（从 LocalBillExtractService 拆出）
 * 覆盖口语表达：「招行 12 期」「花呗欠 3000」「京东白条一次性」
 */
import { ParseResult, ParseResultItem } from './AIService'
import { fillConfidence, guessPlatform, matchMoney, round2 } from './BillParseShared'
import { hasInstallmentStructure } from './BillPlanParser'

/**
 * 还款日提示解析：还款日10月6号 / 还款日 2026年10月6号 / 10月6号还款。
 * 缺年份按今年推断；该日期早于今天超过半年则进位到明年（跨年截图）。
 * 返回 YYYY-MM-DD；解析不出返回 null。
 */
export function parseDueDateHint(text: string): string | null {
  const withPrefix = text.match(/还款日\s*[:：]?\s*(?:(\d{4})\s*年)?\s*(\d{1,2})\s*月\s*(\d{1,2})\s*[号日]/)
  if (withPrefix !== null && withPrefix.length >= 4) {
    const year = withPrefix[1] !== undefined ? parseInt(withPrefix[1], 10) : 0
    return buildDueDate(year, parseInt(withPrefix[2], 10), parseInt(withPrefix[3], 10))
  }
  const withSuffix = text.match(/(\d{1,2})\s*月\s*(\d{1,2})\s*[号日]\s*还款/)
  if (withSuffix !== null && withSuffix.length >= 3) {
    return buildDueDate(0, parseInt(withSuffix[1], 10), parseInt(withSuffix[2], 10))
  }
  return null
}

function buildDueDate(year: number, month: number, day: number): string | null {
  if (!(month >= 1 && month <= 12) || !(day >= 1 && day <= 31)) {
    return null
  }
  let y = year > 0 ? year : new Date().getFullYear()
  let due = new Date(y, month - 1, day)
  if (year <= 0) {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    if (today.getTime() - due.getTime() > 184 * 24 * 60 * 60 * 1000) {
      y++
      due = new Date(y, month - 1, day)
    }
  }
  return `${y}-` + (month < 10 ? '0' + month : '' + month) + '-' + (day < 10 ? '0' + day : '' + day)
}

/**
 * 口语描述解析；无法可靠识别时返回 null（交给 LLM）
 */
export function tryNaturalLanguageDebt(text: string): ParseResult | null {
  const platform = guessPlatform(text)
  // 必须像在描述一笔债
  const debtHint =
    text.indexOf('分期') >= 0 ||
    text.indexOf('欠') >= 0 ||
    text.indexOf('还') >= 0 ||
    text.indexOf('白条') >= 0 ||
    text.indexOf('花呗') >= 0 ||
    text.indexOf('贷款') >= 0 ||
    text.indexOf('信用卡') >= 0
  if (!debtHint && platform === '未知平台') {
    return null
  }

  let totalPeriods: number | null = null
  const p1 = text.match(/分\s*(\d+)\s*期/)
  if (p1 !== null) {
    totalPeriods = parseInt(p1[1], 10)
  }
  if (totalPeriods === null) {
    const p2 = text.match(/(\d+)\s*期/)
    if (p2 !== null && text.indexOf('分期') >= 0) {
      totalPeriods = parseInt(p2[1], 10)
    }
  }

  let monthly = matchMoney(text, /每月还\s*([0-9]+(?:\.[0-9]+)?)\s*元?/)
  if (monthly === null) {
    monthly = matchMoney(text, /月供\s*([0-9]+(?:\.[0-9]+)?)/)
  }
  if (monthly === null) {
    monthly = matchMoney(text, /每期\s*([0-9]+(?:\.[0-9]+)?)/)
  }

  let principal = matchMoney(text, /总共\s*([0-9]+(?:\.[0-9]+)?)\s*万/)
  if (principal !== null) {
    principal = round2(principal * 10000)
  }
  if (principal === null) {
    principal = matchMoney(text, /总共\s*([0-9]+(?:\.[0-9]+)?)\s*元?/)
  }
  if (principal === null) {
    principal = matchMoney(text, /欠了?\s*([0-9]+(?:\.[0-9]+)?)\s*元?/)
  }
  if (principal === null) {
    principal = matchMoney(text, /白条\s*([0-9]+(?:\.[0-9]+)?)/)
  }
  if (principal === null) {
    principal = matchMoney(text, /([0-9]+(?:\.[0-9]+)?)\s*元/)
  }

  const once =
    text.indexOf('一次性') >= 0 ||
    text.indexOf('一次还清') >= 0 ||
    text.indexOf('全额') >= 0

  let paymentDay: number | null = null
  const dayM = text.match(/每月\s*(\d{1,2})\s*号/)
  if (dayM !== null) {
    paymentDay = parseInt(dayM[1], 10)
  }
  if (paymentDay === null) {
    const dayM2 = text.match(/(\d{1,2})\s*号还款/)
    if (dayM2 !== null) {
      paymentDay = parseInt(dayM2[1], 10)
    }
  }
  // 「还款日10月6号」等明示还款日；无「每月N号」时日号兼作每月还款日
  const dueDate = parseDueDateHint(text)
  if (paymentDay === null && dueDate !== null) {
    paymentDay = parseInt(dueDate.substring(8, 10), 10)
  }

  if (once) {
    if (principal === null && monthly === null) {
      return null
    }
    const amt = principal !== null ? principal : (monthly as number)
    const item = new ParseResultItem()
    item.tempId = '1'
    item.recordType = 'debt'
    item.isComplete = true
    item.parsedFields.set('platform', platform)
    item.parsedFields.set('debt_type', 'credit_card')
    item.parsedFields.set('current_balance', amt)
    item.parsedFields.set('monthly_payment', amt)
    item.parsedFields.set('total_periods', 1)
    item.parsedFields.set('remaining_periods', 1)
    if (paymentDay !== null) {
      item.parsedFields.set('payment_day', paymentDay)
    }
    if (dueDate !== null) {
      item.parsedFields.set('next_payment_date', dueDate)
    }
    item.parsedFields.set('note', '')
    fillConfidence(item, true)
    const result = new ParseResult()
    result.items.push(item)
    result.isComplete = true
    result.rawContent = 'LOCAL_RULE_ONCE'
    return result
  }

  if (totalPeriods === null || totalPeriods <= 0) {
    // 有月供+总额可反推期数
    if (principal !== null && monthly !== null && monthly > 0) {
      totalPeriods = Math.round(principal / monthly)
      if (totalPeriods < 1 || totalPeriods > 120) {
        totalPeriods = null
      }
    }
  }

  // 文本带分期结构证据但上面没解析出期数：交给 LLM 判别，避免误降级为一次性
  if (totalPeriods === null && hasInstallmentStructure(text)) {
    return null
  }

  // 明示还款日但推不出分期结构 → 一次性债务（单笔到期）
  if (totalPeriods === null && principal !== null && dueDate !== null) {
    const item = new ParseResultItem()
    item.tempId = '1'
    item.recordType = 'debt'
    item.isComplete = true
    item.parsedFields.set('platform', platform)
    item.parsedFields.set('debt_type', 'credit_card')
    item.parsedFields.set('current_balance', principal)
    item.parsedFields.set('monthly_payment', principal)
    item.parsedFields.set('total_periods', 1)
    item.parsedFields.set('remaining_periods', 1)
    if (paymentDay !== null) {
      item.parsedFields.set('payment_day', paymentDay)
    }
    if (dueDate !== null) {
      item.parsedFields.set('next_payment_date', dueDate)
    }
    item.parsedFields.set('note', '')
    fillConfidence(item, true)
    const result = new ParseResult()
    result.items.push(item)
    result.isComplete = true
    result.rawContent = 'LOCAL_RULE_ONCE'
    return result
  }

  if (totalPeriods === null && monthly === null && principal === null) {
    return null
  }

  // 分期：至少月供+期数 或 总额+期数
  if (totalPeriods !== null && monthly === null && principal !== null) {
    monthly = round2(principal / totalPeriods)
  }
  if (totalPeriods !== null && principal === null && monthly !== null) {
    principal = round2(monthly * totalPeriods)
  }

  if (principal === null && monthly === null) {
    return null
  }

  const item = new ParseResultItem()
  item.tempId = '1'
  item.recordType = 'debt'
  const complete =
    principal !== null &&
    monthly !== null &&
    totalPeriods !== null &&
    totalPeriods > 0
  item.isComplete = complete
  item.parsedFields.set('platform', platform)
  item.parsedFields.set('debt_type', totalPeriods !== null && totalPeriods > 1 ?
    'installment' : 'credit_card')
  if (principal !== null) {
    item.parsedFields.set('current_balance', principal)
  }
  if (monthly !== null) {
    item.parsedFields.set('monthly_payment', monthly)
  }
  if (totalPeriods !== null) {
    item.parsedFields.set('total_periods', totalPeriods)
    item.parsedFields.set('remaining_periods', totalPeriods)
  }
  if (paymentDay !== null) {
    item.parsedFields.set('payment_day', paymentDay)
  }
  item.parsedFields.set('note', '')
  fillConfidence(item, complete)

  const result = new ParseResult()
  result.items.push(item)
  result.isComplete = complete
  result.clarifyQuestion = complete ? '' :
    '还差一些金额或期数信息，可补充总金额、月供或期数。'
  result.rawContent = 'LOCAL_RULE_NL'
  return result
}
