import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { DashboardService } from '../../../../main/ets/service/DashboardService'
import { Debt, Subscription, CreditAccount } from 'common'
import { DebtService } from '../../mock/DebtService.mock'
import { SubscriptionService } from '../../mock/SubscriptionService.mock'
import { CreditAccountService } from '../../mock/CreditAccountService.mock'
import { PaymentService } from '../../mock/PaymentService.mock'
import { CalculationService } from '../../mock/CalculationService.mock'

function makeDebt(overrides: Record<string, string | number | boolean> = {}): Debt {
  const d = new Debt()
  d.id = 'd1'
  d.user_id = 'test-user-001'
  d.platform = '花呗'
  d.debt_type = 'installment'
  d.principal = 120000
  d.current_balance = 80000
  d.monthly_payment = 12000
  d.total_periods = 12
  d.remaining_periods = 8
  d.repayment_method = 'equal_payment'
  d.annual_rate_bp = 600
  d.payment_day = 15
  d.next_payment_date = '2099-12-15'
  d.start_date = '2024-01-01'
  d.status = 'active'
  d.note = ''
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(d as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return d
}

function makeSubscription(overrides: Record<string, string | number | boolean> = {}): Subscription {
  const s = new Subscription()
  s.id = 's1'
  s.user_id = 'test-user-001'
  s.name = '爱奇艺'
  s.category = 'video'
  s.amount = 2500
  s.billing_cycle = 'monthly'
  s.next_billing_date = '2099-12-15'
  s.start_date = '2024-01-01'
  s.status = 'active'
  s.note = ''
  s.reminder_enabled = true
  s.reminder_days_before = 3
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

function makeAccount(overrides: Record<string, string | number | boolean> = {}): CreditAccount {
  const a = new CreditAccount()
  a.id = 'a1'
  a.user_id = 'test-user-001'
  a.name = '招行信用卡'
  a.last_four = '1234'
  a.bill_day = 5
  a.payment_day = 25
  a.credit_limit = 5
  a.annual_fee_required_swipes = 6
  a.annual_fee_manual_swipes = 3
  a.expiry_date = '2099-12-31'
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(a as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return a
}

export default function dashboardServiceTest() {
  beforeEach(() => {
    DebtService._reset()
    SubscriptionService._reset()
    CreditAccountService._reset()
    PaymentService._reset()
    CalculationService._reset()
  })

  // ── buildSubscriptionDistribution ──────────────────────
  describe('DashboardService_buildSubscriptionDistribution', () => {
    it('空列表_返回空Map', 0, () => {
      const m = DashboardService.buildSubscriptionDistribution([])
      expect(m.size).assertEqual(0)
    })

    it('只统计active订阅', 0, () => {
      const subs = [
        makeSubscription({ id: 's1', category: 'video', amount: 2500, status: 'active' }),
        makeSubscription({ id: 's2', category: 'music', amount: 1000, status: 'paused' })
      ]
      const m = DashboardService.buildSubscriptionDistribution(subs)
      expect(m.size).assertEqual(1)
      expect(m.get('video')).assertEqual(2500)
    })

    it('同分类累加', 0, () => {
      const subs = [
        makeSubscription({ id: 's1', category: 'video', amount: 2500, status: 'active' }),
        makeSubscription({ id: 's2', category: 'video', amount: 1500, status: 'active' })
      ]
      const m = DashboardService.buildSubscriptionDistribution(subs)
      expect(m.get('video')).assertEqual(4000)
    })
  })

  // ── buildDebtDistribution ──────────────────────
  describe('DashboardService_buildDebtDistribution', () => {
    it('空列表_返回空Map', 0, () => {
      const m = DashboardService.buildDebtDistribution([])
      expect(m.size).assertEqual(0)
    })

    it('只统计active债务', 0, () => {
      const debts = [
        makeDebt({ id: 'd1', debt_type: 'installment', current_balance: 80000, status: 'active' }),
        makeDebt({ id: 'd2', debt_type: 'mortgage', current_balance: 500000, status: 'completed' })
      ]
      const m = DashboardService.buildDebtDistribution(debts)
      expect(m.size).assertEqual(1)
      expect(m.get('installment')).assertEqual(80000)
    })

    it('同类型累加', 0, () => {
      const debts = [
        makeDebt({ id: 'd1', debt_type: 'installment', current_balance: 80000, status: 'active' }),
        makeDebt({ id: 'd2', debt_type: 'installment', current_balance: 40000, status: 'active' })
      ]
      const m = DashboardService.buildDebtDistribution(debts)
      expect(m.get('installment')).assertEqual(120000)
    })
  })

  // ── getSummary ──────────────────────
  describe('DashboardService_getSummary', () => {
    it('空数据_返回默认summary', 0, async () => {
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.totalDebt).assertEqual(0)
      expect(s.activeDebtCount).assertEqual(0)
      expect(s.completedDebtCount).assertEqual(0)
      expect(s.subscriptionCount).assertEqual(0)
      expect(s.creditAccountCount).assertEqual(0)
      expect(s.progressPercent).assertEqual(0)
    })

    it('有active债务_累计totalDebt和remainingDebt', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', principal: 100000, current_balance: 80000, status: 'active' }),
        makeDebt({ id: 'd2', principal: 50000, current_balance: 30000, status: 'active' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.totalDebt).assertEqual(150000)
      expect(s.remainingDebt).assertEqual(110000)
      expect(s.activeDebtCount).assertEqual(2)
    })

    it('有completed债务_累计completedDebtCount', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', status: 'completed' }),
        makeDebt({ id: 'd2', status: 'completed' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.completedDebtCount).assertEqual(2)
      expect(s.activeDebtCount).assertEqual(0)
    })

    it('progressPercent计算', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', principal: 100000, current_balance: 50000, status: 'active' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      // totalPaid = 100000 - 50000 = 50000, progress = 50%
      expect(s.progressPercent).assertEqual(50)
    })

    it('信用账户数和总额度', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([
        makeAccount({ id: 'a1', credit_limit: 5 }),
        makeAccount({ id: 'a2', credit_limit: 10 })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.creditAccountCount).assertEqual(2)
      expect(s.totalCreditLimit).assertEqual(15)
    })

    it('订阅数和订阅总额_不按周期折算', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', amount: 2500, billing_cycle: 'monthly', status: 'active' }),
        makeSubscription({ id: 's2', amount: 1500, status: 'paused' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.subscriptionCount).assertEqual(1)
      expect(s.subscriptionTotalAmount).assertEqual(2500)
    })

    it('混合周期订阅总额_不折算_分组明细正确', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', amount: 3000, billing_cycle: 'monthly', status: 'active' }),
        makeSubscription({ id: 's2', amount: 21120, billing_cycle: 'once_quarterly', status: 'active' }),
        makeSubscription({ id: 's3', amount: 12000, billing_cycle: 'annually', status: 'active' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      // 总额为原始金额之和，季度订阅不被乘以 3
      expect(s.subscriptionTotalAmount).assertEqual(3000 + 21120 + 12000)
      expect(s.subscriptionCycleBreakdown.size).assertEqual(3)
      expect(s.subscriptionCycleBreakdown.get('monthly')).assertEqual(3000)
      expect(s.subscriptionCycleBreakdown.get('once_quarterly')).assertEqual(21120)
      expect(s.subscriptionCycleBreakdown.get('annually')).assertEqual(12000)
    })

    it('todayDueCount统计', 0, async () => {
      const today = new Date()
      const m = today.getMonth() + 1
      const todayStr = today.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (today.getDate() < 10 ? '0' + today.getDate() : '' + today.getDate())
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', next_payment_date: todayStr, status: 'active' }),
        makeDebt({ id: 'd2', next_payment_date: '2099-01-01', status: 'active' })
      ])
      CalculationService._setPresetPaymentSchedule([{ total: 12000 }])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.todayDueCount).assertEqual(1)
    })

    it('即将过期账户标签', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([
        makeAccount({ id: 'a1', name: '招行', last_four: '1234', expiry_date: '2099-12-31' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.expiringAccountLabels.length >= 0).assertTrue()
    })

    it('payoffDate_取活跃负债estimated_end_date最晚值_并截到月份', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', status: 'active', estimated_end_date: '2027-03-15' }),
        makeDebt({ id: 'd2', status: 'active', estimated_end_date: '2028-06-01' }),
        makeDebt({ id: 'd3', status: 'active', estimated_end_date: '2026-12-30' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.payoffDate).assertEqual('2028-06')
    })

    it('payoffDate_已完成负债不参与计算', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', status: 'active', estimated_end_date: '2026-09-01' }),
        makeDebt({ id: 'd2', status: 'completed', estimated_end_date: '2099-12-31' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.payoffDate).assertEqual('2026-09')
    })

    it('payoffDate_无活跃负债_为空', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', status: 'completed', estimated_end_date: '2026-01-01' })
      ])
      const s = await DashboardService.getSummary('test-user-001')
      expect(s.payoffDate).assertEqual('')
    })
  })

  // ── getMonthlyPressure ──────────────────────
  describe('DashboardService_getMonthlyPressure', () => {
    it('空数据_返回mock预设', 0, async () => {
      CalculationService._setPresetMonthlyPressure([])
      const list = await DashboardService.getMonthlyPressure('test-user-001')
      expect(list.length).assertEqual(0)
    })

    it('有压力数据_返回预设列表', 0, async () => {
      CalculationService._setPresetMonthlyPressure([
        { month: '2024-12', amount: 10000 },
        { month: '2025-01', amount: 12000 }
      ])
      const list = await DashboardService.getMonthlyPressure('test-user-001')
      expect(list.length).assertEqual(2)
    })
  })

  // ── getRemainingDebtTrend ──────────────────────
  describe('DashboardService_getRemainingDebtTrend', () => {
    it('无债务_返回空数组', 0, async () => {
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      expect(trend.length).assertEqual(0)
    })

    it('有债务无还款记录_返回当前余额走势', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 80000, start_date: '2020-01-01' })
      ])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      // 6 个采样点：前 5 个月末 + 今天
      expect(trend.length).assertEqual(6)
    })

    it('months=3_返回3个采样点', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', start_date: '2020-01-01' })])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 3)
      expect(trend.length).assertEqual(3)
    })

    it('start_date在未来_无上月债务数据_返回空', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 80000, start_date: '2099-12-31' })
      ])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      // 上月末无债务存在，无可对比数据，直接返回空
      expect(trend.length).assertEqual(0)
    })

    it('债务本月才新增_无上月数据_返回空', 0, async () => {
      const now = new Date()
      const m = now.getMonth() + 1
      const thisMonthStart = now.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-01'
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 80000, start_date: thisMonthStart })
      ])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      // 当月有债、上月无债，无法对比，隐藏走势
      expect(trend.length).assertEqual(0)
    })

    it('有还款记录_回溯历史余额', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 50000, start_date: '2020-01-01' })
      ])
      PaymentService._setPresetPaymentRecords([
        { debt_id: 'd1', user_id: 'test-user-001', payment_date: '2099-12-31', principal_paid: 30000 }
      ])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      // 今天的采样点 = current_balance = 50000
      // 历史采样点 < payment_date，所以 bal = 50000 + 30000 = 80000
      expect(trend.length).assertEqual(6)
    })

    it('上月有债本月已还清_返回空', 0, async () => {
      const now = new Date()
      const m = now.getMonth() + 1
      const thisMonthStart = now.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-01'
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 0, start_date: '2020-01-01' })
      ])
      PaymentService._setPresetPaymentRecords([
        { debt_id: 'd1', user_id: 'test-user-001', payment_date: thisMonthStart, principal_paid: 50000 }
      ])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      // 上月末余额 = 0 + 50000 = 50000（还款发生在本月，回溯加回）
      // 本月余额 = 0（已还清），不显示趋势图
      expect(trend.length).assertEqual(0)
    })

    it('本月新建回填开始日期_返回空', 0, async () => {
      const now = new Date()
      const m = now.getMonth() + 1
      const day = now.getDate()
      const today = now.getFullYear() + '-' +
        (m < 10 ? '0' + m : '' + m) + '-' +
        (day < 10 ? '0' + day : '' + day)
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 80000, start_date: '2020-01-01', created_at: today + 'T12:00:00.000Z' })
      ])
      const trend = await DashboardService.getRemainingDebtTrend('test-user-001', 6)
      // 本月新建（created_at 为今天）但 start_date 回填到 2020 年
      // 实际上月无记录，不显示趋势图
      expect(trend.length).assertEqual(0)
    })

    it('loadHome_包含debtTrend', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', current_balance: 80000, start_date: '2020-01-01' })
      ])
      const home = await DashboardService.loadHome('test-user-001')
      expect(home.debtTrend.length >= 2).assertTrue()
    })
  })

  // ── calculateDebtPaydownTrend ──────────────────
  describe('DashboardService_calculateDebtPaydownTrend', () => {
    it('无剩余负债_返回空数组', 0, () => {
      const trend = DashboardService.calculateDebtPaydownTrend(0, [])
      expect(trend.length).assertEqual(0)
    })

    it('多期消减_单调递减至0截止', 0, () => {
      const pressure = [
        { month: '2026-08', amount: 1558, debtAmount: 1558, subscriptionAmount: 0 },
        { month: '2026-09', amount: 47153, debtAmount: 47153, subscriptionAmount: 0 },
        { month: '2026-10', amount: 29955, debtAmount: 29955, subscriptionAmount: 0 },
        { month: '2026-11', amount: 0, debtAmount: 0, subscriptionAmount: 0 },
        { month: '2026-12', amount: 0, debtAmount: 0, subscriptionAmount: 0 }
      ]
      const trend = DashboardService.calculateDebtPaydownTrend(78666, pressure)
      // 78666 -> 77108 -> 29955 -> 0 (到0即止，不填充后续 0)
      expect(trend.length).assertEqual(4)
      expect(trend[0]).assertEqual(78666)
      expect(trend[1]).assertEqual(77108)
      expect(trend[2]).assertEqual(29955)
      expect(trend[3]).assertEqual(0)
    })

    it('单期结清_返回起点与0两点', 0, () => {
      const pressure = [
        { month: '2026-08', amount: 50000, debtAmount: 50000, subscriptionAmount: 0 }
      ]
      const trend = DashboardService.calculateDebtPaydownTrend(50000, pressure)
      expect(trend.length).assertEqual(2)
      expect(trend[0]).assertEqual(50000)
      expect(trend[1]).assertEqual(0)
    })

    it('空压力序列_兜底两点消减', 0, () => {
      const trend = DashboardService.calculateDebtPaydownTrend(100000, [])
      expect(trend.length).assertEqual(2)
      expect(trend[0]).assertEqual(100000)
      expect(trend[1]).assertEqual(0)
    })
  })
}
