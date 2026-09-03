import { ParseResultItem } from './AIService'
import { AppStorageKeys } from 'common'
import { Utils } from 'common'

/**
 * AI Live「修改」表单预填：AppStorage 字符串草稿（Tab 分隔，避免 JSON 类型坑）
 * Keys: aiLiveDebtDraft / aiLiveSubscriptionDraft
 */
export class AILiveDebtDraft {
  platform: string = ''
  currentBalance: string = ''
  monthlyPayment: string = ''
  totalPeriods: string = ''
  remainingPeriods: string = ''
  annualRate: string = '0'
  paymentDay: string = ''
  startDate: string = ''
  repaymentDate: string = ''
  note: string = ''
  /** installment | credit_card | loan | other */
  debtType: string = 'installment'
  /** 关联信用账户名称提示（表单按名称模糊匹配） */
  creditAccountHint: string = ''

  encode(): string {
    return [
      this.platform,
      this.currentBalance,
      this.monthlyPayment,
      this.totalPeriods,
      this.remainingPeriods,
      this.annualRate,
      this.paymentDay,
      this.startDate,
      this.repaymentDate,
      this.note,
      this.debtType,
      this.creditAccountHint
    ].join('\u001f')
  }

  static decode(raw: string): AILiveDebtDraft | null {
    if (raw.length === 0) {
      return null
    }
    const p = raw.split('\u001f')
    if (p.length < 10) {
      return null
    }
    const d = new AILiveDebtDraft()
    d.platform = p[0]
    d.currentBalance = p[1]
    d.monthlyPayment = p[2]
    d.totalPeriods = p[3]
    d.remainingPeriods = p[4]
    d.annualRate = p[5]
    d.paymentDay = p[6]
    d.startDate = p[7]
    d.repaymentDate = p[8]
    d.note = p[9]
    d.debtType = p.length > 10 && p[10].length > 0 ? p[10] : 'installment'
    d.creditAccountHint = p.length > 11 ? p[11] : ''
    return d
  }

  /**
   * 与表单页字段语义对齐；AI 金额为「元」字符串，勿再 fenToYuan。
   * 表单「分期金额」= 分期本金 principal（如 332.62），不是剩余待还 current_balance（如 225.08）。
   */
  static fromParseItem(item: ParseResultItem): AILiveDebtDraft {
    const fields = item.parsedFields
    const d = new AILiveDebtDraft()
    d.platform = (fields.get('platform') as string) ?? '未知平台'
    const principalYuan = Number(fields.get('principal') ?? 0)
    const balanceYuan = Number(fields.get('current_balance') ?? 0)
    const monthlyYuan = Number(fields.get('monthly_payment') ?? 0)
    // 优先本金；无本金才退剩余（一次性单据等）
    const formAmount = principalYuan > 0 ? principalYuan : balanceYuan
    d.currentBalance = formAmount > 0 ? formAmount.toString() : ''
    d.monthlyPayment = monthlyYuan > 0 ? monthlyYuan.toString() : ''
    const total = Number(fields.get('total_periods') ?? 12)
    const remain = Number(fields.get('remaining_periods') ?? total)
    d.totalPeriods = (total > 0 ? total : 12).toString()
    d.remainingPeriods = (remain > 0 ? remain : total).toString()
    d.annualRate = (Number(fields.get('annual_rate') ?? 0)).toString()
    const payDay = Number(fields.get('payment_day') ?? 0)
    d.paymentDay = payDay >= 1 && payDay <= 31 ? payDay.toString() : '1'
    d.repaymentDate = (fields.get('next_payment_date') as string) ?? Utils.todayString()
    d.startDate = (fields.get('start_date') as string) ?? Utils.todayString()
    // note 可能已是 { custom_schedule, text } JSON（完整含已还期）
    d.note = (fields.get('note') as string) ?? ''
    const dt = `${fields.get('debt_type') ?? ''}`
    if (dt === 'credit_card' || dt === 'loan' || dt === 'other' || dt === 'installment') {
      d.debtType = dt
    } else if (total > 1 || remain > 1 || monthlyYuan > 0) {
      d.debtType = 'installment'
    } else {
      d.debtType = 'installment'
    }
    const hint = `${fields.get('credit_account_hint') ?? ''}`
    d.creditAccountHint = hint.length > 0 ? hint : d.platform
    return d
  }
}

export class AILiveSubscriptionDraft {
  name: string = ''
  amount: string = ''
  category: string = 'other'
  billingCycle: string = 'monthly'
  nextBillingDate: string = ''
  startDate: string = ''
  endDate: string = ''
  note: string = ''

  encode(): string {
    return [
      this.name,
      this.amount,
      this.category,
      this.billingCycle,
      this.nextBillingDate,
      this.startDate,
      this.endDate,
      this.note
    ].join('\u001f')
  }

  static decode(raw: string): AILiveSubscriptionDraft | null {
    if (raw.length === 0) {
      return null
    }
    const p = raw.split('\u001f')
    if (p.length < 8) {
      return null
    }
    const d = new AILiveSubscriptionDraft()
    d.name = p[0]
    d.amount = p[1]
    d.category = p[2]
    d.billingCycle = p[3]
    d.nextBillingDate = p[4]
    d.startDate = p[5]
    d.endDate = p[6]
    d.note = p[7]
    return d
  }

  /** AI amount 为元；表单金额亦为元字符串 */
  static fromParseItem(item: ParseResultItem): AILiveSubscriptionDraft {
    const fields = item.parsedFields
    const d = new AILiveSubscriptionDraft()
    d.name = (fields.get('name') as string) ?? (fields.get('platform') as string) ?? '未知订阅'
    const amountYuan = Number(fields.get('amount') ?? fields.get('current_balance') ?? 0)
    d.amount = amountYuan > 0 ? amountYuan.toString() : ''
    d.category = (fields.get('category') as string) ?? 'other'
    d.billingCycle = (fields.get('billing_cycle') as string) ?? 'monthly'
    d.nextBillingDate = (fields.get('next_billing_date') as string) ?? Utils.todayString()
    d.startDate = (fields.get('start_date') as string) ?? Utils.todayString()
    d.endDate = (fields.get('end_date') as string) ?? ''
    d.note = (fields.get('note') as string) ?? ''
    return d
  }
}

export class AILiveCreditAccountDraft {
  name: string = ''
  lastFour: string = ''
  billDay: string = '1'
  paymentDay: string = '1'
  creditLimit: string = ''
  expiryDate: string = ''
  annualFeeSwipes: string = ''
  gracePeriodDays: string = ''
  interestFreeDays: string = ''
  note: string = ''

  encode(): string {
    return [
      this.name,
      this.lastFour,
      this.billDay,
      this.paymentDay,
      this.creditLimit,
      this.expiryDate,
      this.annualFeeSwipes,
      this.gracePeriodDays,
      this.interestFreeDays,
      this.note
    ].join('\u001f')
  }

  static decode(raw: string): AILiveCreditAccountDraft | null {
    if (raw.length === 0) {
      return null
    }
    const p = raw.split('\u001f')
    if (p.length < 9) {
      return null
    }
    const d = new AILiveCreditAccountDraft()
    d.name = p[0]
    d.lastFour = p[1]
    d.billDay = p[2]
    d.paymentDay = p[3]
    d.creditLimit = p[4]
    d.expiryDate = p[5]
    d.annualFeeSwipes = p[6]
    d.gracePeriodDays = p[7]
    d.interestFreeDays = p.length > 9 ? (p[8] ?? '') : ''
    d.note = p.length > 9 ? (p[9] ?? '') : (p[8] ?? '')
    return d
  }

  static fromParseItem(item: ParseResultItem): AILiveCreditAccountDraft {
    const fields = item.parsedFields
    const d = new AILiveCreditAccountDraft()
    d.name = (fields.get('name') as string) ?? '未知信用卡'
    d.lastFour = (fields.get('last_four') as string) ?? ''
    d.billDay = (Number(fields.get('bill_day') ?? 1)).toString()
    d.paymentDay = (Number(fields.get('payment_day') ?? 1)).toString()
    const limitYuan = Number(fields.get('credit_limit') ?? 0)
    d.creditLimit = limitYuan > 0 ? limitYuan.toString() : ''
    d.expiryDate = (fields.get('expiry_date') as string) ?? ''
    d.annualFeeSwipes = (Number(fields.get('annual_fee_required_swipes') ?? 0)).toString()
    d.gracePeriodDays = (Number(fields.get('grace_period_days') ?? 0)).toString()
    d.interestFreeDays = (Number(fields.get('interest_free_days') ?? 0)).toString()
    d.note = (fields.get('note') as string) ?? ''
    return d
  }
}

export class AILiveDraftKeys {
  static readonly DEBT: string = AppStorageKeys.AI_LIVE_DEBT_DRAFT
  static readonly SUBSCRIPTION: string = AppStorageKeys.AI_LIVE_SUBSCRIPTION_DRAFT
  static readonly CREDIT_ACCOUNT: string = AppStorageKeys.AI_LIVE_CREDIT_ACCOUNT_DRAFT
  static readonly OPEN_AI_SHEET: string = AppStorageKeys.SETTINGS_OPEN_AI_SHEET
}
