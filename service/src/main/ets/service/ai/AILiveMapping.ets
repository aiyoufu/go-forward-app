import { ParseResultItem } from './AIService'
import { CreateDebtInput, DebtType } from 'common'
import { CreateSubscriptionInput, BillingCycle, SubscriptionCategory } from 'common'
import { CreateCreditAccountInput } from 'common'
import { Utils } from 'common'

/** Live 确认卡预览数据（纯映射，无 UI） */
export class AILivePreviewData {
  title: string = ''
  amountFen: number = 0
  meta: string = ''
  isSubscription: boolean = false
}

/**
 * AI Live 解析结果 → 预览 / 入库映射（S3）
 * 金额约定：AI parsed_fields 一律为「元」。
 * - 预览 amountFen：仅展示用，转分后走 Utils.formatMoney
 * - CreateDebtInput / CreateSubscriptionInput：传元（Service 内再转分）
 * - CreateCreditAccountInput.credit_limit：传元（库内存元，与表单一致）
 */
export class AILiveMapping {
  /** AI 元 → 分；非法/NaN → 0（仅预览展示） */
  static yuanToFen(yuan: number): number {
    if (yuan === null || yuan === undefined) {
      return 0
    }
    if (yuan !== yuan) {
      return 0
    }
    return Math.round(yuan * 100)
  }

  /** 安全取 number；NaN → 0 */
  static numField(fields: Map<string, string | number | boolean | null>, key: string, fallback: number = 0): number {
    const v = Number(fields.get(key) ?? fallback)
    if (v !== v) {
      return fallback
    }
    return v
  }

  static buildPreviewData(item: ParseResultItem): AILivePreviewData {
    const data = new AILivePreviewData()
    const fields = item.parsedFields
    const isSub = item.recordType === 'subscription'
    const isCreditAccount = item.recordType === 'credit_account'
    data.isSubscription = isSub
    // 类型由 UI 以 tag 展示，meta 只汇总业务字段，不再前置「负债/订阅/信用账户」
    if (isCreditAccount) {
      data.title = (fields.get('name') as string) ?? '未知信用卡'
      const limitYuan = AILiveMapping.numField(fields, 'credit_limit', 0)
      data.amountFen = AILiveMapping.yuanToFen(limitYuan)
      const parts: string[] = []
      const lastFour = (fields.get('last_four') as string) ?? ''
      if (lastFour.length > 0) {
        parts.push('尾号 ' + lastFour)
      }
      const billDay = AILiveMapping.numField(fields, 'bill_day', 0)
      if (billDay > 0) {
        parts.push('出单日 ' + billDay.toString() + ' 号')
      }
      if (limitYuan > 0) {
        parts.push('额度 ' + Utils.formatMoney(data.amountFen))
      }
      data.meta = parts.join(' · ')
    } else if (isSub) {
      const name = (fields.get('name') as string) ?? (fields.get('platform') as string) ?? '未知订阅'
      data.title = name
      const amountYuan = AILiveMapping.numField(fields, 'amount', 0)
      const amountFallback = amountYuan > 0 ? amountYuan : AILiveMapping.numField(fields, 'current_balance', 0)
      data.amountFen = AILiveMapping.yuanToFen(amountFallback)
      const parts: string[] = []
      const cycle = (fields.get('billing_cycle') as string) ?? ''
      if (cycle.length > 0) {
        parts.push(cycle)
      }
      const next = (fields.get('next_billing_date') as string) ?? ''
      if (next.length > 0) {
        parts.push('下次 ' + next)
      }
      data.meta = parts.join(' · ')
    } else {
      data.title = (fields.get('platform') as string) ?? '未知平台'
      // 确认卡金额：优先分期本金，避免把「剩余待还」当成分期金额展示
      const principalYuan = AILiveMapping.numField(fields, 'principal', 0)
      const balanceYuan = AILiveMapping.numField(fields, 'current_balance', 0)
      const amountYuan = principalYuan > 0 ? principalYuan : balanceYuan
      const amountFallback = amountYuan > 0 ? amountYuan : AILiveMapping.numField(fields, 'amount', 0)
      data.amountFen = AILiveMapping.yuanToFen(amountFallback)
      const parts: string[] = []
      const remain = AILiveMapping.numField(fields, 'remaining_periods', 0)
      const total = AILiveMapping.numField(fields, 'total_periods', 0)
      const remainShow = remain > 0 ? remain : total
      if (remainShow > 0) {
        parts.push('剩 ' + remainShow.toString() + ' 期')
      }
      if (balanceYuan > 0 && principalYuan > 0 && Math.abs(balanceYuan - principalYuan) > 0.009) {
        parts.push('待还 ' + Utils.formatMoney(AILiveMapping.yuanToFen(balanceYuan)))
      }
      const monthlyYuan = AILiveMapping.numField(fields, 'monthly_payment', 0)
      if (monthlyYuan > 0) {
        parts.push('月供 ' + Utils.formatMoney(AILiveMapping.yuanToFen(monthlyYuan)))
      }
      const day = AILiveMapping.numField(fields, 'payment_day', 0)
      if (day > 0) {
        parts.push('每月 ' + day.toString() + ' 日')
      }
      data.meta = parts.join(' · ')
    }
    return data
  }

  /** CreateDebtInput 金额字段为「元」，DebtService 入库时 yuanToFen */
  static toCreateDebtInput(item: ParseResultItem): CreateDebtInput {
    const fields = item.parsedFields
    const input = new CreateDebtInput()
    input.platform = (fields.get('platform') as string) ?? '未知平台'
    const debtTypeRaw = `${fields.get('debt_type') ?? 'installment'}`
    let debtType: DebtType = 'installment'
    if (debtTypeRaw === 'credit_card') {
      debtType = 'credit_card'
    } else if (debtTypeRaw === 'loan') {
      debtType = 'loan'
    } else if (debtTypeRaw === 'other') {
      debtType = 'other'
    } else if (debtTypeRaw === 'installment') {
      debtType = 'installment'
    }
    input.debt_type = debtType
    const principalYuan = AILiveMapping.numField(fields, 'principal', 0)
    const balanceYuan = AILiveMapping.numField(fields, 'current_balance', principalYuan)
    const monthlyYuan = AILiveMapping.numField(fields, 'monthly_payment', 0)
    // 无 principal 时用余额；金额保持「元」
    input.principal = principalYuan > 0 ? principalYuan : balanceYuan
    input.current_balance = balanceYuan > 0 ? balanceYuan : principalYuan
    input.monthly_payment = monthlyYuan
    input.total_periods = AILiveMapping.numField(fields, 'total_periods', 12)
    const remain = AILiveMapping.numField(fields, 'remaining_periods', 0)
    input.remaining_periods = remain > 0 ? remain : input.total_periods
    input.repayment_method = 'equal_payment'
    input.total_interest = 0
    input.annual_rate_bp = Math.round(AILiveMapping.numField(fields, 'annual_rate', 0) * 100)
    input.payment_day = AILiveMapping.numField(fields, 'payment_day', 1)
    if (input.payment_day < 1 || input.payment_day > 31) {
      input.payment_day = 1
    }
    input.next_payment_date = (fields.get('next_payment_date') as string) ?? Utils.todayString()
    input.start_date = (fields.get('start_date') as string) ?? Utils.todayString()
    input.is_auto_payment = false
    input.note = (fields.get('note') as string) ?? ''
    // 预览阶段若已匹配到信用账户，带入创建
    const accId = `${fields.get('credit_account_id') ?? ''}`
    input.credit_account_id = accId
    return input
  }

  /** CreateSubscriptionInput.amount 为「元」，SubscriptionService 入库时 yuanToFen */
  static toCreateSubscriptionInput(item: ParseResultItem): CreateSubscriptionInput {
    const fields = item.parsedFields
    const input = new CreateSubscriptionInput()
    input.name = (fields.get('name') as string) ?? (fields.get('platform') as string) ?? '未知订阅'
    const cat = (fields.get('category') as SubscriptionCategory) ?? 'other'
    input.category = cat
    const amountYuan = AILiveMapping.numField(fields, 'amount', 0)
    input.amount = amountYuan > 0 ? amountYuan : AILiveMapping.numField(fields, 'current_balance', 0)
    const cycle = (fields.get('billing_cycle') as BillingCycle) ?? 'monthly'
    input.billing_cycle = cycle
    input.next_billing_date = (fields.get('next_billing_date') as string) ?? Utils.todayString()
    input.start_date = (fields.get('start_date') as string) ?? Utils.todayString()
    input.end_date = (fields.get('end_date') as string) ?? ''
    input.status = 'active'
    input.credit_account_id = ''
    input.color = ''
    input.icon_url = ''
    input.note = (fields.get('note') as string) ?? ''
    input.reminder_days_before = 3
    input.reminder_enabled = true
    return input
  }

  /** credit_limit 与表单一致存「元」，不要转分 */
  static toCreateCreditAccountInput(item: ParseResultItem): CreateCreditAccountInput {
    const fields = item.parsedFields
    const input = new CreateCreditAccountInput()
    input.name = (fields.get('name') as string) ?? '未知信用卡'
    input.last_four = (fields.get('last_four') as string) ?? ''
    input.bill_day = AILiveMapping.numField(fields, 'bill_day', 1)
    if (input.bill_day < 1 || input.bill_day > 31) {
      input.bill_day = 1
    }
    input.payment_day = AILiveMapping.numField(fields, 'payment_day', 1)
    if (input.payment_day < 1 || input.payment_day > 31) {
      input.payment_day = 1
    }
    input.credit_limit = AILiveMapping.numField(fields, 'credit_limit', 0)
    input.expiry_date = (fields.get('expiry_date') as string) ?? ''
    input.annual_fee_required_swipes = AILiveMapping.numField(fields, 'annual_fee_required_swipes', 0)
    input.grace_period_days = AILiveMapping.numField(fields, 'grace_period_days', 0)
    input.interest_free_days = AILiveMapping.numField(fields, 'interest_free_days', 0)
    input.color = ''
    input.icon_url = ''
    input.cvv = ''
    input.annual_fee_manual_swipes = 0
    input.sort_order = 0
    return input
  }
}
