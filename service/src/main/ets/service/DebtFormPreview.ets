import { Debt, RepaymentMethod, PaymentScheduleItem } from 'common'
import { CalculationService, CustomScheduleItem } from './CalculationService'
import { Utils } from 'common'

/** 表单预览还款计划行（P4 从 DebtFormPage 拆出） */
export class DebtPreviewItem {
  period_number: number
  date: string
  principal: number
  interest: number
  total: number
  balance_after: number
  status: 'paid' | 'pending'

  constructor(
    period_number: number,
    date: string,
    principal: number,
    interest: number,
    total: number,
    balance_after: number,
    status: 'paid' | 'pending'
  ) {
    this.period_number = period_number
    this.date = date
    this.principal = principal
    this.interest = interest
    this.total = total
    this.balance_after = balance_after
    this.status = status
  }
}

/** 生成预览计划所需的表单快照（元字符串 / 标志） */
export class DebtFormPreviewInput {
  currentBalanceYuan: string = ''
  monthlyPaymentYuan: string = ''
  totalInterestYuan: string = ''
  totalPeriods: string = ''
  remainingPeriods: string = ''
  annualRate: string = '0'
  repaymentDate: string = ''
  /** 第一期还款日；传入后所有期数按该日期正向逐月推算 */
  firstPaymentDate: string = ''
  isInstallment: boolean = false
  repaymentMethod: RepaymentMethod = 'equal_payment'
  customSchedule: CustomScheduleItem[] = []
}

/**
 * 负债表单还款计划预览（纯逻辑，无 UI）
 */
export class DebtFormPreview {
  static buildSchedule(input: DebtFormPreviewInput): DebtPreviewItem[] {
    const balanceNum = Utils.yuanToFen(Number(input.currentBalanceYuan) || 0)
    const totalPeriodsNum = Number(input.totalPeriods) || 1
    const remainingPeriodsNum = Number(input.remainingPeriods) || 1
    const monthlyPaymentNum = Utils.yuanToFen(Number(input.monthlyPaymentYuan) || 0)
    const totalInterestNum = Utils.yuanToFen(Number(input.totalInterestYuan) || 0)
    const annualRateBp = Math.round((Number(input.annualRate) || 0) * 100)
    const firstPaymentRaw = input.firstPaymentDate.length > 0
      ? input.firstPaymentDate
      : (input.repaymentDate.length > 0 ? input.repaymentDate : Utils.todayString())

    if (balanceNum <= 0) {
      return []
    }
    if (!input.isInstallment) {
      const date = input.repaymentDate.length > 0 ? input.repaymentDate : Utils.todayString()
      return [new DebtPreviewItem(1, date, balanceNum, 0, balanceNum, 0, 'pending')]
    }
    if (totalPeriodsNum <= 0 || remainingPeriodsNum < 0) {
      return []
    }

    // PC 语义：remaining = 当期之后还剩几期；当期 = total - remaining
    const startPeriod = Math.max(1, totalPeriodsNum - remainingPeriodsNum)
    const firstPayDate = new Date(firstPaymentRaw)

    /**
     * 银行「每月等额」：每期应还相同、服务费均摊（中信/白条等额常见）。
     * 有明确月供且月供×期数 > 本金时优先走这条，避免 equal_payment+年化重算 PMT
     * 把 58.31 算成 58.55。
     */
    const impliedFeeFen = monthlyPaymentNum * totalPeriodsNum - balanceNum
    const useEqualMonthly = monthlyPaymentNum > 0 &&
      totalPeriodsNum >= 2 &&
      input.repaymentMethod !== 'custom' &&
      (input.repaymentMethod === 'fixed_interest' ||
        totalInterestNum > 0 ||
        impliedFeeFen >= 1)

    if (useEqualMonthly && input.customSchedule.length === 0) {
      return DebtFormPreview.buildEqualMonthlySchedule(
        balanceNum,
        monthlyPaymentNum,
        totalInterestNum,
        totalPeriodsNum,
        startPeriod,
        firstPayDate
      )
    }

    const actualMonthlyPayment = monthlyPaymentNum > 0
      ? monthlyPaymentNum
      : Utils.yuanToFen(CalculationService.calculateSuggestedMonthlyPayment(
        Utils.fenToYuan(balanceNum),
        annualRateBp,
        totalPeriodsNum,
        input.repaymentMethod,
        Utils.fenToYuan(totalInterestNum)
      ))

    // 从原始本金出发生成全量还款计划，确保已还期和待还期本息拆分一致
    const fullDebt = new Debt()
    fullDebt.principal = balanceNum
    fullDebt.current_balance = balanceNum
    fullDebt.annual_rate_bp = annualRateBp
    fullDebt.remaining_periods = totalPeriodsNum
    fullDebt.total_periods = totalPeriodsNum
    fullDebt.monthly_payment = actualMonthlyPayment
    fullDebt.repayment_method = input.repaymentMethod
    fullDebt.total_interest = totalInterestNum
    fullDebt.next_payment_date = Utils.formatDate(firstPayDate)

    const fullItems = CalculationService.generatePaymentSchedule(fullDebt)
    const fullMap = new Map<number, PaymentScheduleItem>()
    for (const item of fullItems) {
      fullMap.set(item.period_number, item)
    }

    const list: DebtPreviewItem[] = []

    for (let p = 1; p <= totalPeriodsNum; p++) {
      const scheduled = fullMap.get(p)
      if (scheduled) {
        list.push(new DebtPreviewItem(
          scheduled.period_number,
          scheduled.date,
          scheduled.principal,
          scheduled.interest,
          scheduled.total,
          scheduled.balance_after,
          p < startPeriod ? 'paid' : 'pending'
        ))
      }
    }

    if (input.repaymentMethod === 'custom') {
      for (const item of list) {
        const custom = input.customSchedule.find((x: CustomScheduleItem) => x.period_number === item.period_number)
        if (custom) {
          item.principal = custom.principal
          item.interest = custom.interest
          item.total = custom.total
          // 识别表自带还款日时覆盖推算日（例：第 1 期 2026-07-08）
          if (custom.date.length >= 8) {
            item.date = custom.date
          }
          if (custom.paid) {
            item.status = 'paid'
          }
        }
      }
      // 自定义表条数 = 总期数时，强制按表生成全量行（含已还），避免 total/remaining 不一致丢期
      if (input.customSchedule.length >= totalPeriodsNum && totalPeriodsNum > 0) {
        const full: DebtPreviewItem[] = []
        const paidCutoff = startPeriod - 1
        // 是否有 OCR 写入的 paid 标记
        let hasPaidFlag = false
        for (let i = 0; i < input.customSchedule.length; i++) {
          if (input.customSchedule[i].paid) {
            hasPaidFlag = true
            break
          }
        }
        // 缺日期时以表单下次还款日为基准前后推算
        const nextPayDate = new Date(input.repaymentDate.length > 0 ? input.repaymentDate : Utils.todayString())
        const pDate = new Date(nextPayDate.getTime())
        for (let p = 1; p <= totalPeriodsNum; p++) {
          const custom = input.customSchedule.find((x: CustomScheduleItem) => x.period_number === p)
          const total = custom !== undefined ? custom.total : 0
          const principal = custom !== undefined ? custom.principal : 0
          const interest = custom !== undefined ? custom.interest : 0
          let status: 'paid' | 'pending' = p <= paidCutoff ? 'paid' : 'pending'
          if (hasPaidFlag && custom !== undefined) {
            status = custom.paid ? 'paid' : 'pending'
          }
          // 优先用表内日期；否则按下次还款日推算
          let dateStr = ''
          if (custom !== undefined && custom.date.length >= 8) {
            dateStr = custom.date
          } else {
            pDate.setTime(nextPayDate.getTime())
            if (status === 'paid') {
              pDate.setMonth(pDate.getMonth() - (startPeriod - p))
            } else {
              pDate.setMonth(pDate.getMonth() + (p - startPeriod))
            }
            dateStr = Utils.formatDate(pDate)
          }
          full.push(new DebtPreviewItem(
            p,
            dateStr,
            principal,
            interest,
            total,
            0,
            status
          ))
        }
        full.sort((a: DebtPreviewItem, b: DebtPreviewItem) => a.period_number - b.period_number)
        return full
      }
    }

    list.sort((a: DebtPreviewItem, b: DebtPreviewItem) => a.period_number - b.period_number)
    return list
  }

  /**
   * 每月等额：每期应还固定为月供，服务费前载均摊，末期本金对齐总本金。
   */
  private static buildEqualMonthlySchedule(
    balanceNum: number,
    monthlyPaymentNum: number,
    totalInterestNum: number,
    totalPeriodsNum: number,
    startPeriod: number,
    firstPayDate: Date
  ): DebtPreviewItem[] {
    const feeFen = totalInterestNum > 0
      ? totalInterestNum
      : Math.max(0, monthlyPaymentNum * totalPeriodsNum - balanceNum)
    const interestParts = CalculationService.distributeFenFront(feeFen, totalPeriodsNum)
    const principals: number[] = []
    let principalAssigned = 0
    for (let i = 0; i < totalPeriodsNum; i++) {
      const interest = interestParts[i] ?? 0
      if (i === totalPeriodsNum - 1) {
        principals.push(Math.max(0, balanceNum - principalAssigned))
      } else {
        const p = Math.max(0, monthlyPaymentNum - interest)
        principals.push(p)
        principalAssigned += p
      }
    }
    let sumP = 0
    for (let i = 0; i < principals.length; i++) {
      sumP += principals[i]
    }
    if (sumP !== balanceNum && totalPeriodsNum > 0) {
      const drift = balanceNum - sumP
      principals[totalPeriodsNum - 1] = Math.max(0, principals[totalPeriodsNum - 1] + drift)
    }

    const list: DebtPreviewItem[] = []
    for (let i = 0; i < totalPeriodsNum; i++) {
      const period = i + 1
      const pDate = new Date(firstPayDate.getTime())
      pDate.setMonth(pDate.getMonth() + i)
      const interest = interestParts[i] ?? 0
      const principal = principals[i] ?? 0
      const total = i === totalPeriodsNum - 1
        ? principal + interest
        : monthlyPaymentNum
      list.push(new DebtPreviewItem(
        period,
        Utils.formatDate(pDate),
        principal,
        interest,
        total,
        0,
        period < startPeriod ? 'paid' : 'pending'
      ))
    }
    return list
  }
}
