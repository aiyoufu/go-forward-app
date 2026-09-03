export class Utils {
  static yuanToFen(yuan: number): number {
    return Math.round(yuan * 100)
  }

  static fenToYuan(fen: number): number {
    return Math.round(fen) / 100
  }

  /** ¥ 与金额数字之间的细空格（U+2009 THIN SPACE），货币符号与数字稍微分开 */
  static readonly YUAN_GAP: string = ' '

  /** 防窥脱敏占位：金额（保留货币符号轮廓，数字不可辨） */
  static readonly MASK_AMOUNT: string = '¥ ****'
  /** 防窥脱敏占位：名称 / 日期 / 分期等文本 */
  static readonly MASK_TEXT: string = '***'

  /** 防窥脱敏：masked 为 true 时返回占位文本，否则原样返回 */
  static maskIf(masked: boolean, text: string, placeholder: string = Utils.MASK_TEXT): string {
    return masked ? placeholder : text
  }

  static formatMoney(fen: number, showSymbol: boolean = true): string {
    const yuan = Utils.fenToYuan(fen)
    const sign = yuan < 0 ? '-' : ''
    const absYuan = Math.abs(yuan)
    const integerPart = Math.floor(absYuan)
    const decimalPart = Math.round((absYuan - integerPart) * 100)
    const integerStr = Utils.formatIntegerWithComma(integerPart)
    const decimalStr = decimalPart < 10 ? '0' + decimalPart : '' + decimalPart
    if (showSymbol) {
      return sign + '¥' + Utils.YUAN_GAP + integerStr + '.' + decimalStr
    }
    return sign + integerStr + '.' + decimalStr
  }

  /** 整元时去掉尾随 .00，给次要摘要行用 */
  static formatMoneyCompact(fen: number, showSymbol: boolean = true): string {
    const full = Utils.formatMoney(fen, showSymbol)
    if (full.endsWith('.00')) {
      return full.substring(0, full.length - 3)
    }
    return full
  }

  private static formatIntegerWithComma(n: number): string {
    const s = '' + n
    let result = ''
    let count = 0
    for (let i = s.length - 1; i >= 0; i--) {
      result = s.charAt(i) + result
      count++
      if (count === 3 && i > 0) {
        result = ',' + result
        count = 0
      }
    }
    return result
  }

  static formatDate(dateStr: string | Date | number): string {
    const d = new Date(dateStr)
    const year = d.getFullYear()
    const month = d.getMonth() + 1
    const day = d.getDate()
    return year + '-' + (month < 10 ? '0' + month : '' + month) + '-' + (day < 10 ? '0' + day : '' + day)
  }

  static formatMonthDay(dateStr: string | Date | number): string {
    const d = new Date(dateStr)
    const month = d.getMonth() + 1
    const day = d.getDate()
    return (month < 10 ? '0' + month : '' + month) + '-' + (day < 10 ? '0' + day : '' + day)
  }

  static todayString(): string {
    return Utils.formatDate(new Date())
  }

  static addMonths(dateStr: string, months: number): string {
    const d = new Date(dateStr)
    d.setMonth(d.getMonth() + months)
    return Utils.formatDate(d)
  }

  static daysBetween(a: string | Date, b: string | Date): number {
    const da = new Date(a)
    const db = new Date(b)
    const msPerDay = 24 * 60 * 60 * 1000
    return Math.floor((db.getTime() - da.getTime()) / msPerDay)
  }

  static daysFromNow(dateStr: string | Date | number): number {
    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const target = new Date(dateStr)
    target.setHours(0, 0, 0, 0)
    const msPerDay = 24 * 60 * 60 * 1000
    return Math.floor((target.getTime() - today.getTime()) / msPerDay)
  }

  /**
   * 信用卡有效期 → 可比较的 YYYY-MM-DD（当月末日）。
   * 表单存 MM/YY；AI/同步可能写 YYYY-MM 或 YYYY-MM-DD。
   * 无法识别时返回空串（调用方应跳过，勿当「今天」）。
   */
  static creditCardExpiryToYmd(expiry: string): string {
    if (expiry === undefined || expiry === null) {
      return ''
    }
    const s = expiry.trim()
    if (s.length === 0) {
      return ''
    }
    // YYYY-MM-DD
    if (s.length === 10 && s.charAt(4) === '-' && s.charAt(7) === '-') {
      const y = Number(s.substring(0, 4))
      const m = Number(s.substring(5, 7))
      const d = Number(s.substring(8, 10))
      if (isNaN(y) || isNaN(m) || isNaN(d) || m < 1 || m > 12 || d < 1 || d > 31) {
        return ''
      }
      return s
    }
    // YYYY-MM（AI 抽取）
    if (s.length === 7 && s.charAt(4) === '-') {
      const y = Number(s.substring(0, 4))
      const m = Number(s.substring(5, 7))
      return Utils.lastDayOfMonthYmd(y, m)
    }
    // MM/YY（表单主路径，如 06/30 → 2030-06-30）
    if (s.length === 5 && s.charAt(2) === '/') {
      const m = Number(s.substring(0, 2))
      const yy = Number(s.substring(3, 5))
      if (isNaN(m) || isNaN(yy)) {
        return ''
      }
      return Utils.lastDayOfMonthYmd(2000 + yy, m)
    }
    return ''
  }

  /** year + 1-based month → 该月最后一天的 YYYY-MM-DD */
  private static lastDayOfMonthYmd(year: number, month: number): string {
    if (isNaN(year) || isNaN(month) || month < 1 || month > 12 || year < 2000 || year > 2099) {
      return ''
    }
    // day 0 of next month = last day of this month
    const last = new Date(year, month, 0)
    return Utils.formatDate(last)
  }

  static addDays(dateStr: string, days: number): string {
    const d = new Date(dateStr)
    d.setDate(d.getDate() + days)
    return Utils.formatDate(d)
  }

  static nextDateForMonthlyDay(day: number, todayStr?: string): string {
    const today = todayStr !== undefined && todayStr.length > 0
      ? new Date(todayStr + 'T00:00:00') : new Date()
    today.setHours(0, 0, 0, 0)
    const y = today.getFullYear()
    const m = today.getMonth()
    const thisMonth = Utils.buildMonthlyDate(y, m, day)
    if (thisMonth.getTime() >= today.getTime()) {
      return Utils.formatDate(thisMonth)
    }
    return Utils.formatDate(Utils.buildMonthlyDate(y, m + 1, day))
  }

  private static buildMonthlyDate(y: number, m: number, day: number): Date {
    const lastDay = new Date(y, m + 1, 0).getDate()
    return new Date(y, m, Math.min(day, lastDay))
  }

  static generateId(): string {
    const chars = '0123456789abcdef'
    let id = ''
    for (let i = 0; i < 32; i++) {
      id += chars.charAt(Math.floor(Math.random() * 16))
    }
    return id
  }

  static generateUuid(): string {
    const chars = '0123456789abcdef'
    let id = ''
    for (let i = 0; i < 36; i++) {
      if (i === 8 || i === 13 || i === 18 || i === 23) {
        id += '-'
      } else if (i === 14) {
        id += '4'
      } else if (i === 19) {
        id += chars.charAt(Math.floor(Math.random() * 4) + 8)
      } else {
        id += chars.charAt(Math.floor(Math.random() * 16))
      }
    }
    return id
  }

  static clamp(value: number, min: number, max: number): number {
    if (value < min) return min
    if (value > max) return max
    return value
  }

  static bpToPercent(bp: number): number {
    return bp / 100
  }

  static formatNotificationTime(dateStr: string | Date | number): string {
    const d = new Date(dateStr)
    const now = new Date()
    const diffMs = now.getTime() - d.getTime()
    const diffSec = Math.floor(diffMs / 1000)
    if (diffSec < 60) {
      return '刚刚'
    }
    const diffMin = Math.floor(diffSec / 60)
    if (diffMin < 60) {
      return diffMin + '分钟前'
    }
    const diffHour = Math.floor(diffMin / 60)
    if (diffHour < 24) {
      return diffHour + '小时前'
    }

    const pad = (n: number) => n < 10 ? '0' + n : '' + n
    const timePart = pad(d.getHours()) + ':' + pad(d.getMinutes())

    const today = new Date()
    today.setHours(0, 0, 0, 0)
    const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000)
    const dayBefore = new Date(today.getTime() - 2 * 24 * 60 * 60 * 1000)
    const dDay = new Date(d)
    dDay.setHours(0, 0, 0, 0)

    if (dDay.getTime() === yesterday.getTime()) {
      return '昨天 ' + timePart
    }
    if (dDay.getTime() === dayBefore.getTime()) {
      return '前天 ' + timePart
    }
    if (d.getFullYear() === now.getFullYear()) {
      return pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + timePart
    }
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate()) + ' ' + timePart
  }

  static hexToRgba(hexColor: ResourceColor, alpha: number): string {
    const hex = `${hexColor}`.trim()
    if (hex.startsWith('#')) {
      const h = hex.substring(1)
      if (h.length === 6) {
        const r = parseInt(h.substring(0, 2), 16)
        const g = parseInt(h.substring(2, 4), 16)
        const b = parseInt(h.substring(4, 6), 16)
        return `rgba(${r}, ${g}, ${b}, ${alpha})`
      }
    }
    return hex
  }

  /** 字符串稳定哈希（32 位溢出截断）；通知 id / 代理提醒 id 派生用 */
  static hashId(s: string): number {
    let h = 0
    for (let i = 0; i < s.length; i++) {
      h = (h << 5) - h + s.charCodeAt(i)
      h |= 0
    }
    return h
  }
}
