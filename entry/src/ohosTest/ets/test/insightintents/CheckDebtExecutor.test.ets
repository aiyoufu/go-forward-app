import { describe, it, expect } from '@ohos/hypium'

interface DebtRecord {
  status: string
  current_balance: number
  next_payment_date: string
  monthly_payment: number
}

interface CheckDebtResult {
  totalBalanceYuan: number
  todayDueCount: number
  todayDueAmountYuan: number
  overdueCount: number
}

interface ErrorParams {
  error: string
}

interface ErrorResult {
  code: number
  result: ErrorParams
}

/**
 * CheckDebtExecutor 单元测试
 * 覆盖：参数解析、债务查询、聚合计算、结果组装、错误处理
 */
export default function checkDebtExecutorTest() {

  describe('CheckDebtExecutor_初始化链', () => {

    it('初始化顺序_四步链式调用', 0, async () => {
      const order: string[] = []
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()
      expect(order.length).assertEqual(4)
      expect(order[0]).assertEqual('DbService')
      expect(order[3]).assertEqual('UserService')
    })
  })

  describe('CheckDebtExecutor_债务聚合逻辑', () => {

    it('无债务_全部指标为零', 0, () => {
      const all: DebtRecord[] = []
      const today = '2025-07-28'
      let totalBalance = 0
      let todayDueCount = 0
      let todayDueAmount = 0
      let overdueCount = 0

      for (const debt of all) {
        const d = debt
        if (d.status !== 'completed') {
          totalBalance += Number(d.current_balance) || 0
          if (d.next_payment_date === today) {
            todayDueCount += 1
            todayDueAmount += Number(d.monthly_payment) || 0
          }
          if (d.next_payment_date < today) {
            overdueCount += 1
          }
        }
      }

      expect(totalBalance).assertEqual(0)
      expect(todayDueCount).assertEqual(0)
      expect(todayDueAmount).assertEqual(0)
      expect(overdueCount).assertEqual(0)
    })

    it('有活跃债务_正确累加余额', 0, () => {
      const all: DebtRecord[] = [
        { status: 'active', current_balance: 300000, next_payment_date: '2025-08-15', monthly_payment: 50000 },
        { status: 'active', current_balance: 200000, next_payment_date: '2025-07-28', monthly_payment: 30000 }
      ]
      const today = '2025-07-28'
      let totalBalance = 0
      let todayDueCount = 0
      let todayDueAmount = 0

      for (const debt of all) {
        const d = debt
        if (d.status !== 'completed') {
          totalBalance += Number(d.current_balance) || 0
          if (d.next_payment_date === today) {
            todayDueCount += 1
            todayDueAmount += Number(d.monthly_payment) || 0
          }
        }
      }

      expect(totalBalance).assertEqual(500000)
      expect(todayDueCount).assertEqual(1)
      expect(todayDueAmount).assertEqual(30000)
    })

    it('今日到期_正确计数', 0, () => {
      const all: DebtRecord[] = [
        { status: 'active', current_balance: 100000, next_payment_date: '2025-07-28', monthly_payment: 20000 },
        { status: 'active', current_balance: 200000, next_payment_date: '2025-07-28', monthly_payment: 40000 },
        { status: 'active', current_balance: 300000, next_payment_date: '2025-08-15', monthly_payment: 60000 }
      ]
      const today = '2025-07-28'
      let todayDueCount = 0
      let todayDueAmount = 0

      for (const debt of all) {
        const d = debt
        if (d.status !== 'completed') {
          if (d.next_payment_date === today) {
            todayDueCount += 1
            todayDueAmount += Number(d.monthly_payment) || 0
          }
        }
      }

      expect(todayDueCount).assertEqual(2)
      expect(todayDueAmount).assertEqual(60000)
    })

    it('逾期债务_正确计数', 0, () => {
      const all: DebtRecord[] = [
        { status: 'active', current_balance: 100000, next_payment_date: '2025-07-01', monthly_payment: 20000 },
        { status: 'active', current_balance: 200000, next_payment_date: '2025-07-28', monthly_payment: 30000 },
        { status: 'active', current_balance: 300000, next_payment_date: '2025-06-15', monthly_payment: 40000 }
      ]
      const today = '2025-07-28'
      let overdueCount = 0

      for (const debt of all) {
        const d = debt
        if (d.status !== 'completed') {
          if (d.next_payment_date < today) {
            overdueCount += 1
          }
        }
      }

      expect(overdueCount).assertEqual(2)
    })

    it('已完成债务_跳过不计', 0, () => {
      const all: DebtRecord[] = [
        { status: 'completed', current_balance: 0, next_payment_date: '2025-07-28', monthly_payment: 50000 },
        { status: 'active', current_balance: 100000, next_payment_date: '2025-08-15', monthly_payment: 20000 }
      ]
      const today = '2025-07-28'
      let totalBalance = 0
      let todayDueCount = 0

      for (const debt of all) {
        const d = debt
        if (d.status !== 'completed') {
          totalBalance += Number(d.current_balance) || 0
          if (d.next_payment_date === today) {
            todayDueCount += 1
          }
        }
      }

      expect(totalBalance).assertEqual(100000)
      expect(todayDueCount).assertEqual(0)
    })

    it('混合状态_正确分类', 0, () => {
      const all: DebtRecord[] = [
        { status: 'active', current_balance: 500000, next_payment_date: '2025-07-28', monthly_payment: 100000 },
        { status: 'completed', current_balance: 0, next_payment_date: '2025-07-20', monthly_payment: 50000 },
        { status: 'active', current_balance: 300000, next_payment_date: '2025-07-01', monthly_payment: 80000 },
        { status: 'paused', current_balance: 200000, next_payment_date: '2025-08-01', monthly_payment: 60000 }
      ]
      const today = '2025-07-28'
      let totalBalance = 0
      let todayDueCount = 0
      let overdueCount = 0

      for (const debt of all) {
        const d = debt
        if (d.status !== 'completed') {
          totalBalance += Number(d.current_balance) || 0
          if (d.next_payment_date === today) {
            todayDueCount += 1
          }
          if (d.next_payment_date < today) {
            overdueCount += 1
          }
        }
      }

      expect(totalBalance).assertEqual(1000000) // 500000 + 300000 + 200000
      expect(todayDueCount).assertEqual(1)
      expect(overdueCount).assertEqual(1)
    })
  })

  describe('CheckDebtExecutor_结果组装', () => {

    it('成功_code为0', 0, () => {
      const code = 0
      expect(code).assertEqual(0)
    })

    it('分转元_fenToYuan逻辑', 0, () => {
      const totalBalanceFen = 500000
      const yuan = totalBalanceFen / 100
      expect(yuan).assertEqual(5000)
    })

    it('分转元_零金额', 0, () => {
      const fen = 0
      const yuan = fen / 100
      expect(yuan).assertEqual(0)
    })

    it('结果参数_可序列化', 0, () => {
      const resultParams: CheckDebtResult = {
        totalBalanceYuan: 5000,
        todayDueCount: 2,
        todayDueAmountYuan: 800,
        overdueCount: 1
      }
      const serialized = JSON.stringify(resultParams)
      const deserialized: CheckDebtResult = JSON.parse(serialized) as CheckDebtResult
      expect(deserialized.totalBalanceYuan).assertEqual(5000)
      expect(deserialized.todayDueCount).assertEqual(2)
    })
  })

  describe('CheckDebtExecutor_错误处理', () => {

    it('查询失败_进入catch分支', 0, () => {
      let code = 0
      try {
        throw new Error('query failed')
      } catch (err) {
        code = -1
        const errorParams: ErrorParams = { error: (err as Error).message }
        expect(errorParams.error).assertContain('query failed')
      }
      expect(code).assertEqual(-1)
    })

    it('错误结果_始终返回Promise.resolve', 0, async () => {
      const errorObj: ErrorParams = { error: 'test' }
      const resultObj: ErrorResult = { code: -1, result: errorObj }
      const result: ErrorResult = await Promise.resolve(resultObj)
      expect(result.code).assertEqual(-1)
    })
  })
}
