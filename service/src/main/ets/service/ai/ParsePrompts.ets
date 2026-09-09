/**
 * AI 解析统一提示词与日期归一化（纯函数，无重型依赖）— 从 AIService 拆出以便 L0 测试。
 *
 * 架构约定：文字与图片共用同一条提示词、同一套处理逻辑，
 * 由大模型统一完成「先判定类型与负债结构，再提取标准化字段」。
 *
 * 设计原则：
 * 1. 语义定义式，不做关键词/版式/日期格式枚举——只讲清概念本质；
 * 2. 精简优先——每次调用都消耗 token，只保留影响判定正确性的最小规则；
 * 3. 日期形态不限——账单/票据格式各异，模型原样识别，端侧再归一化。
 * parsed_fields 字段 schema 是对外契约（AILiveMapping/AILiveDraft 消费），必须保持稳定。
 */

/**
 * 统一解析提示词：文字输入与图片输入共用。
 */
export function buildUnifiedSystemPrompt(currentDate: string): string {
  return `今天=${currentDate}。从文字或图片提取负债/订阅/信用账户。缺则null，禁止编造。日期形态不限。只返回JSON。

【判定】按语义，不看特定文案。共存 debt > credit_account > subscription。
debt=欠款（含分期、月付/先享后付待还）
subscription=持续服务周期付费（名含月≠订阅）
credit_account=只描述卡（尾号/额度/账单日/还款日），无欠款
分期=有多期还款计划（还款日逐月重复或序号+金额+日期的逐期列表）；商品、贴息、手续费、金额都不影响判定。
一次性=全文无多期计划、单笔到期应还→credit_card；还款日不是下单时间。月付类产品有逐期列表仍是分期。

【提取】金额元。
debt: platform,debt_type(installment|credit_card|loan|other),principal,current_balance,monthly_payment,total_periods,remaining_periods,annual_rate,currency,bill_day,payment_day,last_four,start_date,next_payment_date,repayment_plan,note
subscription: name,category,amount,currency,billing_cycle(weekly|biweekly|monthly|quarterly|semiannually|annually),next_billing_date,start_date,end_date,note
credit_account: name,last_four,bill_day,payment_day,credit_limit,currency,expiry_date,note

写出的剩余期数禁止再算覆盖。已还=还款日严格早于今天或已标明已还；否则remaining=total（勿减1）。勿把下月账单当本月需还。
{"items":[{"temp_id":"1","record_type":"debt","parsed_fields":{},"confidence":{},"is_complete":true}],"clarify_question":null,"is_complete":true}
见[输入已截断]只提取可见部分。无信息则items=[]。`
}

/**
 * 多期计划不得落成一次性：total 或 remaining > 1 时 credit_card → installment。
 * 贷款等其他类型不改。
 */
export function coerceDebtTypeByPeriods(debtType: string, totalPeriods: number,
  remainingPeriods: number = 0): string {
  const n = totalPeriods > remainingPeriods ? totalPeriods : remainingPeriods
  if (n > 1 && debtType === 'credit_card') {
    return 'installment'
  }
  return debtType
}

function pad2(n: number): string {
  if (n < 10) {
    return '0' + n
  }
  return `${n}`
}

function parseToday(currentDate: string): number[] {
  if (currentDate.length >= 10) {
    const y = Number(currentDate.substring(0, 4))
    const m = Number(currentDate.substring(5, 7))
    const d = Number(currentDate.substring(8, 10))
    if (y >= 1900 && m >= 1 && m <= 12 && d >= 1) {
      return [y, m, d]
    }
  }
  const now = new Date()
  return [now.getFullYear(), now.getMonth() + 1, now.getDate()]
}

function firstNumber(s: string, from: number): number {
  let num = ''
  for (let i = from; i < s.length; i++) {
    const code = s.charCodeAt(i)
    if (code >= 0x30 && code <= 0x39) {
      num += s.charAt(i)
    } else if (num.length > 0) {
      break
    }
  }
  if (num.length === 0) {
    return 0
  }
  return Number(num)
}

function isAllDigits(s: string): boolean {
  if (s.length === 0) {
    return false
  }
  for (let i = 0; i < s.length; i++) {
    const code = s.charCodeAt(i)
    if (code < 0x30 || code > 0x39) {
      return false
    }
  }
  return true
}

function leadingDigits(s: string): string {
  let out = ''
  for (let i = 0; i < s.length; i++) {
    const code = s.charCodeAt(i)
    if (code >= 0x30 && code <= 0x39) {
      out += s.charAt(i)
    } else {
      break
    }
  }
  return out
}

function formatDay(year: number, month: number, day: number): string | null {
  if (year < 1900 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) {
    return null
  }
  return `${year}-${pad2(month)}-${pad2(day)}`
}

function formatMonth(year: number, month: number): string | null {
  if (year < 1900 || year > 2100 || month < 1 || month > 12) {
    return null
  }
  return `${year}-${pad2(month)}`
}

function applyPreferFuture(year: number, month: number, day: number, cy: number, cm: number, cd: number,
  preferFuture: boolean): number {
  if (!preferFuture) {
    return year
  }
  if (year !== cy) {
    return year
  }
  if (month < cm || (month === cm && day < cd)) {
    return year + 1
  }
  return year
}

/**
 * 账单/票据日期形态多样：横杠、斜杠、点号、中文、缺年、相对日期、紧凑数字均可。
 * 能识别则归一为 YYYY-MM-DD（或有效期 YYYY-MM）；无法识别返回 null。
 * monthOnly：有效期，只保留年月。
 * preferFuture：缺年时若该日已过则进到下一年（下次还款/扣费）。
 */
export function normalizeFlexibleDate(raw: string, currentDate: string, monthOnly: boolean = false,
  preferFuture: boolean = false): string | null {
  let s = raw.trim()
  if (s.length === 0) {
    return null
  }
  const tIdx = s.indexOf('T')
  if (tIdx > 8) {
    s = s.substring(0, tIdx)
  } else {
    for (let i = 8; i < s.length; i++) {
      if (s.charAt(i) !== ' ') {
        continue
      }
      const rest = s.substring(i + 1)
      const colon = rest.indexOf(':')
      if (colon > 0 && colon <= 2) {
        s = s.substring(0, i)
        break
      }
    }
  }
  let compactStr = ''
  for (let i = 0; i < s.length; i++) {
    const c = s.charAt(i)
    if (c !== ' ' && c !== '\t') {
      compactStr += c
    }
  }
  s = compactStr
  if (s.length === 0) {
    return null
  }
  const today = parseToday(currentDate)
  const cy = today[0]
  const cm = today[1]
  const cd = today[2]

  const nextMonthIdx = s.indexOf('下个月')
  const nextIdx = nextMonthIdx >= 0 ? nextMonthIdx : s.indexOf('下月')
  if (nextIdx >= 0) {
    const skip = nextMonthIdx >= 0 ? 3 : 2
    const day = firstNumber(s, nextIdx + skip)
    let month = cm + 1
    let year = cy
    if (month > 12) {
      month = 1
      year++
    }
    if (monthOnly) {
      return formatMonth(year, month)
    }
    return formatDay(year, month, day)
  }
  const thisMonthIdx = s.indexOf('这个月') >= 0 ? s.indexOf('这个月') : s.indexOf('本月')
  if (thisMonthIdx >= 0) {
    const skip = s.indexOf('这个月') === thisMonthIdx ? 3 : 2
    const day = firstNumber(s, thisMonthIdx + skip)
    if (monthOnly) {
      return formatMonth(cy, cm)
    }
    return formatDay(cy, cm, day)
  }

  if (s.indexOf('年') >= 0 || s.indexOf('月') >= 0) {
    let year = 0
    let month = 0
    let day = 0
    let hasDay = false
    let num = ''
    for (let i = 0; i < s.length; i++) {
      const c = s.charAt(i)
      const code = s.charCodeAt(i)
      if (code >= 0x30 && code <= 0x39) {
        num += c
        continue
      }
      if (num.length > 0) {
        const n = Number(num)
        if (c === '年') {
          year = n
        } else if (c === '月') {
          month = n
        } else if (c === '日' || c === '号') {
          day = n
          hasDay = true
        }
        num = ''
      }
    }
    if (num.length > 0 && month > 0 && !hasDay) {
      day = Number(num)
      hasDay = true
    }
    if (year > 0 && year < 100) {
      year = year >= 70 ? 1900 + year : 2000 + year
    }
    if (year <= 0) {
      year = cy
      year = applyPreferFuture(year, month, day > 0 ? day : 1, cy, cm, cd, preferFuture)
    }
    if (monthOnly || !hasDay) {
      return formatMonth(year, month)
    }
    return formatDay(year, month, day)
  }

  if (isAllDigits(s) && s.length === 8) {
    const year = Number(s.substring(0, 4))
    const month = Number(s.substring(4, 6))
    const day = Number(s.substring(6, 8))
    if (monthOnly) {
      return formatMonth(year, month)
    }
    return formatDay(year, month, day)
  }

  let sep = ''
  for (let i = 0; i < s.length; i++) {
    const c = s.charAt(i)
    if (c === '-' || c === '/' || c === '.') {
      sep = c
      break
    }
  }
  if (sep.length === 0) {
    return null
  }
  const parts: string[] = []
  let cur = ''
  for (let i = 0; i < s.length; i++) {
    const c = s.charAt(i)
    if (c === sep) {
      parts.push(leadingDigits(cur))
      cur = ''
    } else {
      cur += c
    }
  }
  parts.push(leadingDigits(cur))
  const compact: string[] = []
  for (let i = 0; i < parts.length; i++) {
    if (parts[i].length > 0) {
      compact.push(parts[i])
    }
  }
  if (compact.length < 2 || compact.length > 3) {
    return null
  }
  for (let i = 0; i < compact.length; i++) {
    if (!isAllDigits(compact[i]) || compact[i].length > 4) {
      return null
    }
  }

  if (compact.length === 3) {
    let year = 0
    let month = 0
    let day = 0
    if (compact[0].length === 4) {
      year = Number(compact[0])
      month = Number(compact[1])
      day = Number(compact[2])
    } else {
      const yy = Number(compact[0])
      year = yy >= 70 ? 1900 + yy : 2000 + yy
      month = Number(compact[1])
      day = Number(compact[2])
    }
    if (monthOnly) {
      return formatMonth(year, month)
    }
    return formatDay(year, month, day)
  }

  // 两段：YYYY-MM / MM-YYYY / MM/YY(有效期) / MM/DD
  const a = Number(compact[0])
  const b = Number(compact[1])
  if (compact[0].length === 4) {
    return formatMonth(a, b)
  }
  if (compact[1].length === 4) {
    return formatMonth(b, a)
  }
  if (monthOnly) {
    const year = b >= 70 ? 1900 + b : 2000 + b
    return formatMonth(year, a)
  }
  let year = applyPreferFuture(cy, a, b, cy, cm, cd, preferFuture)
  return formatDay(year, a, b)
}
