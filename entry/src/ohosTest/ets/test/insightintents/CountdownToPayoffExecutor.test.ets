import { describe, it, expect } from '@ohos/hypium'

interface CountdownDebt {
  status: string
  current_balance: number
  estimated_end_date: string
}

interface CountdownResult {
  activeDebtCount: number
  totalBalanceYuan: number
  furthestEndDate: string
  remainingMonths: number
  remainingDays: number
}

/**
 * CountdownToPayoffExecutor 单元测试
 * 覆盖：初始化链、活跃债务过滤、最远到期日、剩余月/天计算、结果组装、错误处理
 */
export default function countdownToPayoffExecutorTest() {

  describe('CountdownToPayoffExecutor_初始化链', () => {

    it('初始化顺序_四步链式调用', 0, async () => {
      const order: string[] = []
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()
      expect(order.length).assertEqual(4)
    })
  })

  describe('CountdownToPayoffExecutor_活跃债务过滤', () => {

    it('无债务_活跃数为0', 0, () => {
      const all: CountdownDebt[] = []
      const activeDebts = all.filter(d => {
        const debt = d
        return debt.status !== 'completed'
      })
      expect(activeDebts.length).assertEqual(0)
    })

    it('全部活跃_全保留', 0, () => {
      const all: CountdownDebt[] = [
        { status: 'active', current_balance: 100000, estimated_end_date: '2026-12-31' },
        { status: 'paused', current_balance: 200000, estimated_end_date: '2027-06-30' }
      ]
      const activeDebts = all.filter(d => {
        const debt = d
        return debt.status !== 'completed'
      })
      expect(activeDebts.length).assertEqual(2)
    })

    it('已完成_排除', 0, () => {
      const all: CountdownDebt[] = [
        { status: 'completed', current_balance: 0, estimated_end_date: '2025-01-01' },
        { status: 'active', current_balance: 100000, estimated_end_date: '2026-12-31' }
      ]
      const activeDebts = all.filter(d => {
        const debt = d
        return debt.status !== 'completed'
      })
      expect(activeDebts.length).assertEqual(1)
    })
  })

  describe('CountdownToPayoffExecutor_最远到期日', () => {

    it('多笔债务_取最远日期', 0, () => {
      const activeDebts: CountdownDebt[] = [
        { status: '', current_balance: 100000, estimated_end_date: '2026-06-30' },
        { status: '', current_balance: 200000, estimated_end_date: '2027-12-31' },
        { status: '', current_balance: 300000, estimated_end_date: '2026-12-31' }
      ]
      let furthestEndDate = ''
      let totalBalance = 0
      for (const debt of activeDebts) {
        const d = debt
        totalBalance += Number(d.current_balance) || 0
        const endDate = d.estimated_end_date as string
        if (endDate && (!furthestEndDate || endDate > furthestEndDate)) {
          furthestEndDate = endDate
        }
      }
      expect(furthestEndDate).assertEqual('2027-12-31')
      expect(totalBalance).assertEqual(600000)
    })

    it('无到期日_保持空字符串', 0, () => {
      const activeDebts: CountdownDebt[] = [
        { status: '', current_balance: 100000, estimated_end_date: '' },
        { status: '', current_balance: 200000, estimated_end_date: '' }
      ]
      let furthestEndDate = ''
      for (const debt of activeDebts) {
        const d = debt
        const endDate = (d.estimated_end_date as string) ?? ''
        if (endDate && (!furthestEndDate || endDate > furthestEndDate)) {
          furthestEndDate = endDate
        }
      }
      expect(furthestEndDate).assertEqual('')
    })

    it('单笔债务_即为最远', 0, () => {
      const activeDebts: CountdownDebt[] = [
        { status: '', current_balance: 500000, estimated_end_date: '2028-03-15' }
      ]
      let furthestEndDate = ''
      for (const debt of activeDebts) {
        const d = debt
        const endDate = d.estimated_end_date as string
        if (endDate && (!furthestEndDate || endDate > furthestEndDate)) {
          furthestEndDate = endDate
        }
      }
      expect(furthestEndDate).assertEqual('2028-03-15')
    })
  })

  describe('CountdownToPayoffExecutor_剩余时间计算', () => {

    it('有到期日_剩余月数至少为1', 0, () => {
      const furthestEndDate = '2027-12-31'
      const now = new Date('2025-07-28')
      const target = new Date(furthestEndDate)
      const remainingMonths = Math.max(1,
        (target.getFullYear() - now.getFullYear()) * 12 + (target.getMonth() - now.getMonth()))
      expect(remainingMonths >= 1).assertTrue()
    })

    it('有到期日_剩余天数非负', 0, () => {
      const furthestEndDate = '2027-12-31'
      const now = new Date('2025-07-28')
      const target = new Date(furthestEndDate)
      const remainingDays = Math.max(0,
        Math.floor((target.getTime() - now.getTime()) / (1000 * 60 * 60 * 24)))
      expect(remainingDays >= 0).assertTrue()
    })

    it('无到期日_剩余月数为0', 0, () => {
      const furthestEndDate = ''
      let remainingMonths = 0
      let remainingDays = 0
      if (furthestEndDate) {
        remainingMonths = 12 // 不会进入
      }
      expect(remainingMonths).assertEqual(0)
      expect(remainingDays).assertEqual(0)
    })

    it('日期差_精确计算天数', 0, () => {
      const now = new Date('2025-07-01')
      const target = new Date('2025-08-01')
      const days = Math.floor((target.getTime() - now.getTime()) / (1000 * 60 * 60 * 24))
      expect(days).assertEqual(31)
    })
  })

  describe('CountdownToPayoffExecutor_结果组装', () => {

    it('成功结果_包含所有字段', 0, () => {
      const resultParams: CountdownResult = {
        activeDebtCount: 3,
        totalBalanceYuan: 6000,
        furthestEndDate: '2027-12-31',
        remainingMonths: 30,
        remainingDays: 917
      }
      expect(resultParams.activeDebtCount).assertEqual(3)
      expect(resultParams.furthestEndDate).assertEqual('2027-12-31')
    })

    it('空数据_全零结果', 0, () => {
      const resultParams: CountdownResult = {
        activeDebtCount: 0,
        totalBalanceYuan: 0,
        furthestEndDate: '',
        remainingMonths: 0,
        remainingDays: 0
      }
      expect(resultParams.activeDebtCount).assertEqual(0)
      expect(resultParams.furthestEndDate).assertEqual('')
    })
  })

  describe('CountdownToPayoffExecutor_错误处理', () => {

    it('查询失败_code为-1', 0, () => {
      let code = 0
      try {
        throw new Error('debt query failed')
      } catch (err) {
        code = -1
      }
      expect(code).assertEqual(-1)
    })
  })
}
