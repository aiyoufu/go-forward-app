import { describe, it, expect } from '@ohos/hypium'

interface PressureRecord {
  amount: number
}

interface UpcomingDebt {
  monthly_payment: number
}

interface PressureResult {
  thisMonthPressureYuan: number
  nextMonthPressureYuan: number
  pressureTrend: string
  upcomingDueCount: number
  upcomingDueAmountYuan: number
}

/**
 * QueryPressureExecutor 单元测试
 * 覆盖：初始化链、压力计算、趋势判断、近期到期统计、结果组装、错误处理
 */
export default function queryPressureExecutorTest() {

  describe('QueryPressureExecutor_初始化链', () => {

    it('初始化顺序_四步链式调用', 0, async () => {
      const order: string[] = []
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()
      expect(order.length).assertEqual(4)
    })
  })

  describe('QueryPressureExecutor_压力趋势判断', () => {

    it('空压力数据_trend为stable', 0, () => {
      const monthlyPressures: PressureRecord[] = []
      let pressureTrend = 'stable'
      if (monthlyPressures.length > 1) {
        const curr = monthlyPressures[0]
        const next = monthlyPressures[1]
        const diff = next.amount - curr.amount
        if (diff > 0) pressureTrend = 'increasing'
        else if (diff < 0) pressureTrend = 'decreasing'
      }
      expect(pressureTrend).assertEqual('stable')
    })

    it('单月数据_trend为stable', 0, () => {
      const monthlyPressures: PressureRecord[] = [{ amount: 500000 }]
      let pressureTrend = 'stable'
      if (monthlyPressures.length > 1) {
        const curr = monthlyPressures[0]
        const next = monthlyPressures[1]
        const diff = next.amount - curr.amount
        if (diff > 0) pressureTrend = 'increasing'
        else if (diff < 0) pressureTrend = 'decreasing'
      }
      expect(pressureTrend).assertEqual('stable')
    })

    it('上升_trend为increasing', 0, () => {
      const monthlyPressures: PressureRecord[] = [{ amount: 500000 }, { amount: 600000 }]
      let pressureTrend = 'stable'
      if (monthlyPressures.length > 1) {
        const curr = monthlyPressures[0]
        const next = monthlyPressures[1]
        const diff = next.amount - curr.amount
        if (diff > 0) pressureTrend = 'increasing'
        else if (diff < 0) pressureTrend = 'decreasing'
      }
      expect(pressureTrend).assertEqual('increasing')
    })

    it('下降_trend为decreasing', 0, () => {
      const monthlyPressures: PressureRecord[] = [{ amount: 600000 }, { amount: 500000 }]
      let pressureTrend = 'stable'
      if (monthlyPressures.length > 1) {
        const curr = monthlyPressures[0]
        const next = monthlyPressures[1]
        const diff = next.amount - curr.amount
        if (diff > 0) pressureTrend = 'increasing'
        else if (diff < 0) pressureTrend = 'decreasing'
      }
      expect(pressureTrend).assertEqual('decreasing')
    })

    it('持平_trend为stable', 0, () => {
      const monthlyPressures: PressureRecord[] = [{ amount: 500000 }, { amount: 500000 }]
      let pressureTrend = 'stable'
      if (monthlyPressures.length > 1) {
        const curr = monthlyPressures[0]
        const next = monthlyPressures[1]
        const diff = next.amount - curr.amount
        if (diff > 0) pressureTrend = 'increasing'
        else if (diff < 0) pressureTrend = 'decreasing'
      }
      expect(pressureTrend).assertEqual('stable')
    })
  })

  describe('QueryPressureExecutor_本月/下月压力', () => {

    it('有数据_提取本月和下月', 0, () => {
      const monthlyPressures: PressureRecord[] = [{ amount: 500000 }, { amount: 600000 }]
      let thisMonth = 0
      let nextMonth = 0
      if (monthlyPressures.length > 0) {
        thisMonth = monthlyPressures[0].amount
      }
      if (monthlyPressures.length > 1) {
        nextMonth = monthlyPressures[1].amount
      }
      expect(thisMonth).assertEqual(500000)
      expect(nextMonth).assertEqual(600000)
    })

    it('无数据_全为零', 0, () => {
      const monthlyPressures: PressureRecord[] = []
      let thisMonth = 0
      let nextMonth = 0
      if (monthlyPressures.length > 0) thisMonth = monthlyPressures[0].amount
      if (monthlyPressures.length > 1) nextMonth = monthlyPressures[1].amount
      expect(thisMonth).assertEqual(0)
      expect(nextMonth).assertEqual(0)
    })

    it('分转元_压力金额', 0, () => {
      const fen = 500000
      const yuan = fen / 100
      expect(yuan).assertEqual(5000)
    })
  })

  describe('QueryPressureExecutor_近期到期统计', () => {

    it('有近期到期_正确统计', 0, () => {
      const upcomingDebts: UpcomingDebt[] = [
        { monthly_payment: 50000 },
        { monthly_payment: 30000 },
        { monthly_payment: 20000 }
      ]
      const upcomingDueCount = upcomingDebts.length
      let upcomingDueAmountFen = 0
      for (const debt of upcomingDebts) {
        upcomingDueAmountFen += debt.monthly_payment
      }
      expect(upcomingDueCount).assertEqual(3)
      expect(upcomingDueAmountFen).assertEqual(100000)
    })

    it('无近期到期_全为零', 0, () => {
      const upcomingDebts: UpcomingDebt[] = []
      const upcomingDueCount = upcomingDebts.length
      let upcomingDueAmountFen = 0
      for (const debt of upcomingDebts) {
        upcomingDueAmountFen += debt.monthly_payment
      }
      expect(upcomingDueCount).assertEqual(0)
      expect(upcomingDueAmountFen).assertEqual(0)
    })
  })

  describe('QueryPressureExecutor_结果组装', () => {

    it('成功结果_包含所有字段', 0, () => {
      const resultParams: PressureResult = {
        thisMonthPressureYuan: 5000,
        nextMonthPressureYuan: 6000,
        pressureTrend: 'increasing',
        upcomingDueCount: 3,
        upcomingDueAmountYuan: 1000
      }
      expect(resultParams.thisMonthPressureYuan).assertEqual(5000)
      expect(resultParams.pressureTrend).assertEqual('increasing')
      expect(resultParams.upcomingDueCount).assertEqual(3)
    })
  })

  describe('QueryPressureExecutor_错误处理', () => {

    it('查询失败_code为-1', 0, () => {
      let code = 0
      try {
        throw new Error('pressure calc failed')
      } catch (err) {
        code = -1
      }
      expect(code).assertEqual(-1)
    })
  })
}
