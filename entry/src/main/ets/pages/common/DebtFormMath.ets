/**
 * 负债表单派生计算（从 DebtFormPage 拆出）
 * 纯函数：输入输出均为标量/字符串，不触碰组件状态与 UI 上下文
 */
import { CreditAccount } from 'common'
import { Utils } from 'common'
import { Constants } from 'common'
import { RepaymentMethod } from 'common'
import { CalculationService } from 'service'

/** 固定利息：每期利息 → 总利息字符串 */
export function totalInterestFromPeriod(periodInterest: number, periods: number): string {
  return (periodInterest * periods).toFixed(2)
}

/** 固定利息按「本金/期数 + 每期利息」回写月供 */
export function fixedInterestMonthly(balanceYuan: number, periods: number, periodInterest: number): string {
  return ((balanceYuan / periods) + periodInterest).toFixed(2)
}

/**
 * 预览第 1 期日期：优先用开始日；若开始日缺失或被写成下次还款日，
 * 则按「当期 = 总期 - 剩余（当期之后）」从下次还款日回推。
 */
export function resolveFirstPaymentDate(startDate: string, nextRepaymentDate: string,
  totalPeriodsStr: string, remainingPeriodsStr: string): string {
  const next = nextRepaymentDate.length > 0 ? nextRepaymentDate : Utils.todayString()
  if (startDate.length > 0 && startDate !== next) {
    return startDate
  }
  const total = Number(totalPeriodsStr) || 1
  const remainRaw = Number(remainingPeriodsStr)
  const remain = !isNaN(remainRaw) && remainRaw >= 0 ? remainRaw : 1
  const currentPeriod = Math.max(1, total - remain)
  return Utils.addMonths(next, -(currentPeriod - 1))
}

/** 写入用的每月还款日：优先关联账户，否则表单输入（缺省 10） */
export function resolvePaymentDay(accounts: CreditAccount[], creditAccountId: string, inputDay: string): number {
  if (creditAccountId.length > 0) {
    const acc = accounts.find(a => a.id === creditAccountId)
    if (acc !== undefined && acc.payment_day > 0) {
      return acc.payment_day
    }
  }
  return Number(inputDay) || 10
}

/** 年利率说明：参考常见范围 + 自动计算结果提示 */
export function annualRateHintText(principal: number, monthlyPayment: number, totalPeriods: number,
  totalInterest: number, method: RepaymentMethod): string {
  const base = '一般年利率：信用卡分期 12-18%，消费贷 8-24%，房贷 4-6%（>18% 偏高）'
  if (principal <= 0 || totalPeriods <= 0) {
    return base
  }
  const rateBp = CalculationService.calculateAnnualRateBp(
    principal,
    monthlyPayment,
    totalPeriods,
    method,
    totalInterest
  )
  if (rateBp <= 0) {
    return base
  }
  const percent = rateBp / 100
  const tag = rateBp >= Constants.HIGH_RATE_BP_THRESHOLD ? ' · 偏高' : ''
  return '自动计算: ' + percent.toFixed(2) + '%' + tag + ' · ' + base
}
