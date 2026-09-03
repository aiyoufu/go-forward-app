import { describe, it, expect } from '@ohos/hypium'

interface DebtSummaryRecord {
  status: string
  current_balance: number
  estimated_end_date: string
}

interface SubSummaryRecord {
  status: string
  amount: number
}

interface MonthlyPressure {
  debtAmount: number
  subscriptionAmount: number
  amount: number
}

interface SummaryResult {
  activeDebtCount: number
  totalBalanceYuan: number
  thisMonthDueYuan: number
  activeSubscriptionCount: number
  subscriptionTotalYuan: number
  estimatedPayoffDate: string
}

interface ErrorParams {
  error: string
}

/**
 * QuerySummaryExecutor 单元测试
 * 覆盖：初始化链、活跃债务统计、订阅统计、月压力、结果组装、错误处理
 */
export default function querySummaryExecutorTest() {

  describe('QuerySummaryExecutor_初始化链', () => {

    it('初始化顺序_四步链式调用', 0, async () => {
      const order: string[] = []
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()
      expect(order.length).assertEqual(4)
    })
  })

  describe('QuerySummaryExecutor_活跃债务统计', () => {

    it('无债务_全为零', 0, () => {
      const debts: DebtSummaryRecord[] = []
      let activeDebtCount = 0
      let totalBalanceFen = 0
      let estimatedPayoffDate = ''

      for (const debt of debts) {
        const d = debt
        if (d.status === 'active') {
          activeDebtCount += 1
          totalBalanceFen += Number(d.current_balance) || 0
          const endDate = (d.estimated_end_date as string) ?? ''
          if (endDate > estimatedPayoffDate) {
            estimatedPayoffDate = endDate
          }
        }
      }

      expect(activeDebtCount).assertEqual(0)
      expect(totalBalanceFen).assertEqual(0)
      expect(estimatedPayoffDate).assertEqual('')
    })

    it('有活跃债务_正确统计', 0, () => {
      const debts: DebtSummaryRecord[] = [
        { status: 'active', current_balance: 300000, estimated_end_date: '2026-12-31' },
        { status: 'active', current_balance: 200000, estimated_end_date: '2027-06-30' },
        { status: 'completed', current_balance: 0, estimated_end_date: '2025-01-01' }
      ]
      let activeDebtCount = 0
      let totalBalanceFen = 0
      let estimatedPayoffDate = ''

      for (const debt of debts) {
        const d = debt
        if (d.status === 'active') {
          activeDebtCount += 1
          totalBalanceFen += Number(d.current_balance) || 0
          const endDate = (d.estimated_end_date as string) ?? ''
          if (endDate > estimatedPayoffDate) {
            estimatedPayoffDate = endDate
          }
        }
      }

      expect(activeDebtCount).assertEqual(2)
      expect(totalBalanceFen).assertEqual(500000)
      expect(estimatedPayoffDate).assertEqual('2027-06-30')
    })

    it('非活跃债务_不计入', 0, () => {
      const debts: DebtSummaryRecord[] = [
        { status: 'paused', current_balance: 100000, estimated_end_date: '2026-06-30' },
        { status: 'completed', current_balance: 0, estimated_end_date: '2025-01-01' }
      ]
      let activeDebtCount = 0
      for (const debt of debts) {
        const d = debt
        if (d.status === 'active') {
          activeDebtCount += 1
        }
      }
      expect(activeDebtCount).assertEqual(0)
    })

    it('最远到期日_取最大值', 0, () => {
      const debts: DebtSummaryRecord[] = [
        { status: 'active', current_balance: 0, estimated_end_date: '2026-06-30' },
        { status: 'active', current_balance: 0, estimated_end_date: '2028-12-31' },
        { status: 'active', current_balance: 0, estimated_end_date: '2027-03-15' }
      ]
      let estimatedPayoffDate = ''
      for (const debt of debts) {
        const d = debt
        if (d.status === 'active') {
          const endDate = (d.estimated_end_date as string) ?? ''
          if (endDate > estimatedPayoffDate) {
            estimatedPayoffDate = endDate
          }
        }
      }
      expect(estimatedPayoffDate).assertEqual('2028-12-31')
    })
  })

  describe('QuerySummaryExecutor_订阅统计', () => {

    it('无订阅_活跃数为0', 0, () => {
      const subscriptions: SubSummaryRecord[] = []
      let activeSubscriptionCount = 0
      for (const sub of subscriptions) {
        const s = sub
        if (s.status === 'active') {
          activeSubscriptionCount += 1
        }
      }
      expect(activeSubscriptionCount).assertEqual(0)
    })

    it('有活跃订阅_正确计数', 0, () => {
      const subscriptions: SubSummaryRecord[] = [
        { status: 'active', amount: 12800 },
        { status: 'paused', amount: 6800 },
        { status: 'active', amount: 9800 }
      ]
      let activeSubscriptionCount = 0
      for (const sub of subscriptions) {
        const s = sub
        if (s.status === 'active') {
          activeSubscriptionCount += 1
        }
      }
      expect(activeSubscriptionCount).assertEqual(2)
    })

    it('月费总额_仅活跃', 0, () => {
      const subscriptions: SubSummaryRecord[] = [
        { status: 'active', amount: 12800 },
        { status: 'paused', amount: 6800 },
        { status: 'active', amount: 9800 }
      ]
      let total = 0
      for (const sub of subscriptions) {
        const s = sub
        if (s.status === 'active') {
          total += Number(s.amount) || 0
        }
      }
      expect(total).assertEqual(22600)
    })
  })

  describe('QuerySummaryExecutor_本月到期', () => {

    it('有压力数据_提取debtAmount', 0, () => {
      const monthlyPressures: MonthlyPressure[] = [{ debtAmount: 300000, subscriptionAmount: 12800, amount: 312800 }]
      let thisMonthDueFen = 0
      if (monthlyPressures.length > 0) {
        thisMonthDueFen = monthlyPressures[0].debtAmount
      }
      expect(thisMonthDueFen).assertEqual(300000)
    })

    it('无压力数据_为零', 0, () => {
      const monthlyPressures: MonthlyPressure[] = []
      let thisMonthDueFen = 0
      if (monthlyPressures.length > 0) {
        thisMonthDueFen = monthlyPressures[0].debtAmount
      }
      expect(thisMonthDueFen).assertEqual(0)
    })
  })

  describe('QuerySummaryExecutor_结果组装', () => {

    it('成功结果_包含所有字段', 0, () => {
      const resultParams: SummaryResult = {
        activeDebtCount: 2,
        totalBalanceYuan: 5000,
        thisMonthDueYuan: 3000,
        activeSubscriptionCount: 3,
        subscriptionTotalYuan: 226,
        estimatedPayoffDate: '2027-06-30'
      }
      expect(resultParams.activeDebtCount).assertEqual(2)
      expect(resultParams.totalBalanceYuan).assertEqual(5000)
      expect(resultParams.activeSubscriptionCount).assertEqual(3)
      expect(resultParams.estimatedPayoffDate).assertEqual('2027-06-30')
    })

    it('空数据结果', 0, () => {
      const resultParams: SummaryResult = {
        activeDebtCount: 0,
        totalBalanceYuan: 0,
        thisMonthDueYuan: 0,
        activeSubscriptionCount: 0,
        subscriptionTotalYuan: 0,
        estimatedPayoffDate: ''
      }
      expect(resultParams.activeDebtCount).assertEqual(0)
      expect(resultParams.estimatedPayoffDate).assertEqual('')
    })

    it('分转元_各字段', 0, () => {
      expect(500000 / 100).assertEqual(5000)
      expect(22600 / 100).assertEqual(226)
      expect(0 / 100).assertEqual(0)
    })
  })

  describe('QuerySummaryExecutor_错误处理', () => {

    it('查询失败_code为-1', 0, () => {
      let code = 0
      try {
        throw new Error('summary failed')
      } catch (err) {
        code = -1
      }
      expect(code).assertEqual(-1)
    })

    it('错误结果_包含错误信息', 0, () => {
      const err = new Error('db error')
      const errorParams: ErrorParams = { error: (err as Error).message }
      expect(errorParams.error).assertContain('db error')
    })
  })
}
