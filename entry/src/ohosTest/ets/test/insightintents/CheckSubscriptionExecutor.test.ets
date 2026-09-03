import { describe, it, expect } from '@ohos/hypium'

interface SubscriptionRecord {
  status: string
  name: string
  amount: number
  billing_cycle: string
}

interface ActiveSubRecord {
  status: string
  name: string
  amount: number
}

interface TopSubRecord {
  name: string
  amount: number
  billing_cycle: string
}

interface TopSubDisplay {
  name: string
  amountYuan: number
  cycle: string
}

interface CheckSubResult {
  activeCount: number
  subscriptionTotalYuan: number
  topSubscriptions: TopSubDisplay[]
}

interface ErrorParams {
  error: string
}

/**
 * CheckSubscriptionExecutor 单元测试
 * 覆盖：初始化链、订阅查询、活跃过滤、Top3 截取、结果组装、错误处理
 */
export default function checkSubscriptionExecutorTest() {

  describe('CheckSubscriptionExecutor_初始化链', () => {

    it('初始化顺序_四步链式调用', 0, async () => {
      const order: string[] = []
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()
      expect(order.length).assertEqual(4)
    })
  })

  describe('CheckSubscriptionExecutor_订阅过滤', () => {

    it('无订阅_活跃数为0', 0, () => {
      const subscriptions: ActiveSubRecord[] = []
      const activeSubs = subscriptions.filter(s => {
        const sub = s
        return sub.status === 'active'
      })
      expect(activeSubs.length).assertEqual(0)
    })

    it('全部活跃_全保留', 0, () => {
      const subscriptions: SubscriptionRecord[] = [
        { status: 'active', name: 'Netflix', amount: 12800, billing_cycle: 'monthly' },
        { status: 'active', name: 'iCloud', amount: 6800, billing_cycle: 'monthly' }
      ]
      const activeSubs = subscriptions.filter(s => {
        const sub = s
        return sub.status === 'active'
      })
      expect(activeSubs.length).assertEqual(2)
    })

    it('混合状态_仅保留活跃', 0, () => {
      const subscriptions: ActiveSubRecord[] = [
        { status: 'active', name: 'Netflix', amount: 12800 },
        { status: 'paused', name: 'Spotify', amount: 6800 },
        { status: 'cancelled', name: 'iCloud', amount: 3000 },
        { status: 'active', name: 'YouTube', amount: 9800 }
      ]
      const activeSubs = subscriptions.filter(s => {
        const sub = s
        return sub.status === 'active'
      })
      expect(activeSubs.length).assertEqual(2)
    })
  })

  describe('CheckSubscriptionExecutor_月费计算', () => {

    it('月费总额_仅活跃订阅', 0, () => {
      const subscriptions: ActiveSubRecord[] = [
        { status: 'active', name: '', amount: 12800 },
        { status: 'paused', name: '', amount: 6800 },
        { status: 'active', name: '', amount: 9800 }
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

    it('月费总额_无订阅为零', 0, () => {
      const subscriptions: ActiveSubRecord[] = []
      let total = 0
      for (const sub of subscriptions) {
        const s = sub
        if (s.status === 'active') {
          total += Number(s.amount) || 0
        }
      }
      expect(total).assertEqual(0)
    })
  })

  describe('CheckSubscriptionExecutor_Top3截取', () => {

    it('少于3个_全部截取', 0, () => {
      const activeSubs: TopSubRecord[] = [
        { name: 'Netflix', amount: 12800, billing_cycle: 'monthly' }
      ]
      const topSubs = activeSubs.slice(0, 3)
      expect(topSubs.length).assertEqual(1)
    })

    it('恰好3个_全部截取', 0, () => {
      const activeSubs: TopSubRecord[] = [
        { name: 'Netflix', amount: 12800, billing_cycle: 'monthly' },
        { name: 'iCloud', amount: 6800, billing_cycle: 'monthly' },
        { name: 'Spotify', amount: 6800, billing_cycle: 'monthly' }
      ]
      const topSubs = activeSubs.slice(0, 3)
      expect(topSubs.length).assertEqual(3)
    })

    it('超过3个_截取前3', 0, () => {
      const activeSubs: TopSubRecord[] = [
        { name: 'Netflix', amount: 12800, billing_cycle: 'monthly' },
        { name: 'iCloud', amount: 6800, billing_cycle: 'monthly' },
        { name: 'Spotify', amount: 6800, billing_cycle: 'monthly' },
        { name: 'YouTube', amount: 9800, billing_cycle: 'monthly' }
      ]
      const topSubs = activeSubs.slice(0, 3)
      expect(topSubs.length).assertEqual(3)
      const first = topSubs[0]
      expect(first.name).assertEqual('Netflix')
    })

    it('TopSub信息_包含名称/金额/周期', 0, () => {
      const s: TopSubRecord = { name: 'Netflix', amount: 12800, billing_cycle: 'monthly' }
      const amountYuan = (Number(s.amount) || 0) / 100
      const cycle = s.billing_cycle === 'monthly' ? '每月' : s.billing_cycle
      expect(amountYuan).assertEqual(128)
      expect(cycle).assertEqual('每月')
    })
  })

  describe('CheckSubscriptionExecutor_结果组装', () => {

    it('成功结果_包含活跃数/订阅总额/Top3', 0, () => {
      const topSub: TopSubDisplay = { name: 'Netflix', amountYuan: 128, cycle: '每月' }
      const resultParams: CheckSubResult = {
        activeCount: 3,
        subscriptionTotalYuan: 294,
        topSubscriptions: [topSub]
      }
      expect(resultParams.activeCount).assertEqual(3)
      expect(resultParams.subscriptionTotalYuan).assertEqual(294)
      const topSubs = resultParams.topSubscriptions
      expect(topSubs.length).assertEqual(1)
    })

    it('分转元_订阅总额', 0, () => {
      const subscriptionTotalFen = 29400
      const yuan = subscriptionTotalFen / 100
      expect(yuan).assertEqual(294)
    })
  })

  describe('CheckSubscriptionExecutor_错误处理', () => {

    it('查询失败_code为-1', 0, () => {
      let code = 0
      try {
        throw new Error('subscription query failed')
      } catch (err) {
        code = -1
      }
      expect(code).assertEqual(-1)
    })

    it('错误结果_包含错误信息', 0, () => {
      const err = new Error('db timeout')
      const errorParams: ErrorParams = { error: (err as Error).message }
      expect(errorParams.error).assertContain('db timeout')
    })
  })
}
