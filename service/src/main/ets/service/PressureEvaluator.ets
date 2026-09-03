import { Debt, Subscription, CreditAccount, UserSettings } from 'common'
import { Utils } from 'common'
import { CalculationService, DebtOverdueInfo } from './CalculationService'

/** 单条压力预警事件（纯数据；去重与投递由上层完成） */
export class PressureAlertEvent {
  /** 当日去重键（如 dense_expiry / overdue_upgrade_{debtId}） */
  dedupeKey: string = ''
  title: string = ''
  body: string = ''
  debtId: string = ''
  subscriptionId: string = ''
}

/** 评估输入快照：全部由调用方装载，本模块不做任何 IO */
export class PressureSnapshot {
  debts: Debt[] = []
  subscriptions: Subscription[] = []
  accounts: CreditAccount[] = []
  settings: UserSettings | null = null
  /** YYYY-MM-DD */
  today: string = ''
}

/**
 * 压力预警纯规则引擎：
 * 输入快照 → 输出应发事件列表。无服务依赖，可 L0 直测。
 * 阈值与文案为产品契约，改动需同步 L0 用例。
 */
export class PressureEvaluator {
  static evaluate(snapshot: PressureSnapshot): PressureAlertEvent[] {
    const events: PressureAlertEvent[] = []
    const activeDebts = snapshot.debts.filter(d => d.status === 'active')
    const activeSubscriptions = snapshot.subscriptions.filter(s => s.status === 'active')
    const settings = snapshot.settings
    if (settings === null) {
      return events
    }
    const budgetLimit = settings.monthly_budget_limit

    // 1. 未来 7 天密集到期预警
    let denseCount = 0
    let denseTotal = 0
    for (const debt of activeDebts) {
      if (debt.next_payment_date) {
        const days = Utils.daysFromNow(debt.next_payment_date)
        if (days >= 0 && days <= 7) {
          denseCount++
          denseTotal += debt.monthly_payment
        }
      }
    }
    if (denseCount >= 2) {
      const e = new PressureAlertEvent()
      e.dedupeKey = 'dense_expiry'
      e.title = '还款密集预警'
      e.body = `下周有 ${denseCount} 笔合计 ¥${Utils.formatMoney(denseTotal, false)} 到期`
      events.push(e)
    }

    // 2. 月度超额预警
    const currentMonthStr = snapshot.today.substring(0, 7)
    const pressures = CalculationService.calculateMonthlyPressure(activeDebts, activeSubscriptions, 3)
    let currentMonthPressure = 0
    let totalPressure = 0
    let pressureCount = 0
    for (const p of pressures) {
      if (p.month === currentMonthStr) {
        currentMonthPressure = p.amount
      }
      totalPressure += p.amount
      pressureCount++
    }
    const avg3MonthPressure = pressureCount > 0 ? (totalPressure / pressureCount) : 0
    const limitThreshold = budgetLimit > 0 ? budgetLimit : (avg3MonthPressure * 1.2)
    if (currentMonthPressure > limitThreshold && limitThreshold > 0) {
      const e = new PressureAlertEvent()
      e.dedupeKey = 'monthly_excess'
      e.title = '月度支出预警'
      e.body = `本月预估总支出 ¥${Utils.formatMoney(currentMonthPressure, false)}，可能偏高，请留意资金流转。`
      events.push(e)
    }

    // 3. 逾期升级预警
    for (const debt of activeDebts) {
      let acct: CreditAccount | null = null
      if (debt.credit_account_id) {
        for (const a of snapshot.accounts) {
          if (a.id === debt.credit_account_id) {
            acct = a
            break
          }
        }
      }
      const overdueInfo: DebtOverdueInfo = CalculationService.getDebtOverdueInfo(debt, acct)
      if (overdueInfo.isInGracePeriod && overdueInfo.daysLeft <= 1) {
        const e = new PressureAlertEvent()
        e.dedupeKey = `overdue_upgrade_${debt.id}`
        e.title = '紧急还款提醒'
        e.body = `${debt.platform} 宽限期仅剩 ${overdueInfo.daysLeft} 天，逾期将影响信用！`
        e.debtId = debt.id
        events.push(e)
      }
    }

    // 4. 订阅叠加预警
    for (const debt of activeDebts) {
      if (!debt.next_payment_date) continue
      for (const sub of activeSubscriptions) {
        if (sub.next_billing_date === debt.next_payment_date) {
          const daysToDate = Utils.daysFromNow(debt.next_payment_date)
          if (daysToDate >= 0 && daysToDate <= 7) {
            const e = new PressureAlertEvent()
            e.dedupeKey = `overlap_${debt.id}_${sub.id}`
            e.title = '同日扣费提醒'
            const total = debt.monthly_payment + sub.amount
            e.body = `${debt.next_payment_date} 同时有 ${debt.platform} 还款和 ${sub.name} 订阅扣费，合计需准备 ¥${Utils.formatMoney(total, false)}`
            e.debtId = debt.id
            e.subscriptionId = sub.id
            events.push(e)
          }
        }
      }
    }

    return events
  }
}
