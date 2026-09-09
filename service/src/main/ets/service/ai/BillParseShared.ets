/**
 * 端侧单据规则抽取 — 共享工具与行模型（从 LocalBillExtractService 拆出）
 * 供分期表解析器（BillPlanParser）与自然语言解析器（BillNaturalParser）共用
 */
import { ParseResultItem } from './AIService'

/** 分期表行扫描结果（ArkTS 禁止未声明类型的对象字面量） */
export class PeriodScanResult {
  amounts: number[] = []
  /** 服务费/利息（元），与 amounts 一一对应 */
  fees: number[] = []
  paid: boolean[] = []
  dates: string[] = []
}

/** 文本规范化：换行统一、空白折叠、千分位去除 */
export function normalizeText(raw: string): string {
  let t = raw
    .replace(/\r\n/g, '\n')
    .replace(/\r/g, '\n')
    .replace(/[ \t]+/g, ' ')
  // 千分位：5,299.00 / 1,766.34 → 5299.00 / 1766.34（循环处理百万级）
  let prev = ''
  while (prev !== t) {
    prev = t
    t = t.replace(/(\d),(\d{3})/g, '$1$2')
  }
  return t.trim()
}

export function round2(n: number): number {
  return Math.round(n * 100) / 100
}

export function matchMoney(text: string, re: RegExp): number | null {
  const m = text.match(re)
  if (m === null || m.length < 2) {
    return null
  }
  const n = parseFloat(m[1])
  if (n !== n || n < 0) {
    return null
  }
  return round2(n)
}

export function parseDec(s: string): number | null {
  const n = parseFloat(s.replace(',', '.'))
  if (n !== n) {
    return null
  }
  return round2(n)
}

export function allZero(arr: number[]): boolean {
  for (let i = 0; i < arr.length; i++) {
    if (arr[i] > 0) {
      return false
    }
  }
  return true
}

export function pad2(n: number): string {
  if (n < 10) {
    return '0' + n
  }
  return `${n}`
}

/** 从平台名/文本推断关联信用账户提示（表单模糊匹配） */
export function creditAccountHint(text: string, platform: string): string {
  if (text.indexOf('美团') >= 0 || platform.indexOf('美团') >= 0) {
    return '美团月付'
  }
  if (text.indexOf('花呗') >= 0 || platform.indexOf('花呗') >= 0) {
    return '花呗'
  }
  if (text.indexOf('白条') >= 0) {
    return '京东白条'
  }
  if (platform === '账单分期') {
    // 支付宝单据分期常见挂在月付类账户；优先美团月付文案
    return '美团月付'
  }
  return platform
}

export function guessPlatform(text: string): string {
  if (text.indexOf('美团月付') >= 0) {
    return '美团月付'
  }
  if (text.indexOf('美团') >= 0) {
    return '美团月付'
  }
  // 裸「月付」：作子串匹配锚点，便于命中各类 *月付 账户
  if (text.indexOf('月付') >= 0) {
    return '月付'
  }
  if (text.indexOf('花呗') >= 0) {
    return '花呗'
  }
  if (text.indexOf('京东白条') >= 0 || text.indexOf('白条') >= 0) {
    return '京东白条'
  }
  if (text.indexOf('招行') >= 0 || text.indexOf('招商银行') >= 0 ||
    text.indexOf('招商信用卡') >= 0) {
    return '招商银行信用卡'
  }
  if (text.indexOf('中信') >= 0) {
    return '中信银行信用卡'
  }
  // 支付宝「账单分期」截图常见挂月付；图内往往只有「账单分期」无商户名
  if (text.indexOf('账单分期') >= 0) {
    return '美团月付'
  }
  if (text.indexOf('支付宝') >= 0) {
    return '支付宝'
  }
  if (text.indexOf('微信支付') >= 0 || text.indexOf('微信') >= 0) {
    return '微信'
  }
  if (text.indexOf('信用卡') >= 0) {
    return '信用卡'
  }
  return '未知平台'
}

export function fillConfidence(item: ParseResultItem, highCore: boolean): void {
  const conf = highCore ? 'high' : 'medium'
  const keys = ['platform', 'debt_type', 'current_balance', 'monthly_payment',
    'total_periods', 'remaining_periods', 'payment_day', 'next_payment_date',
    'start_date', 'note']
  for (let i = 0; i < keys.length; i++) {
    const k = keys[i]
    if (item.parsedFields.has(k) && item.parsedFields.get(k) !== null) {
      item.confidence.set(k, conf)
    } else {
      item.confidence.set(k, 'missing')
    }
  }
}
