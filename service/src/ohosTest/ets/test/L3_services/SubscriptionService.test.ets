import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { SubscriptionService } from '../../mock/SubscriptionService.mock'

const userId = 'test-user-001'

function subObj(overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    id: 'sub-001',
    user_id: userId,
    name: '网易云音乐',
    amount: 1500,
    status: 'active'
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

export default function subscriptionServiceTest() {
  beforeEach(() => {
    SubscriptionService._reset()
  })

  // ── getSubscriptions ──────────────────────────────
  describe('SubscriptionService_getSubscriptions', () => {
    it('空预设_返回空数组', 0, async () => {
      const result = await SubscriptionService.getSubscriptions(userId)
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回订阅列表', 0, async () => {
      SubscriptionService._setPresetSubscriptions([subObj(), subObj({ id: 'sub-002' })])
      const result = await SubscriptionService.getSubscriptions(userId)
      expect(result.length).assertEqual(2)
      expect((result[0] as Record<string, string>).id).assertEqual('sub-001')
    })

    it('不传userId_也返回全部', 0, async () => {
      SubscriptionService._setPresetSubscriptions([subObj()])
      const result = await SubscriptionService.getSubscriptions()
      expect(result.length).assertEqual(1)
    })
  })

  // ── getSubscriptionById ──────────────────────────────
  describe('SubscriptionService_getSubscriptionById', () => {
    it('存在_返回订阅对象', 0, async () => {
      SubscriptionService._setPresetSubscriptions([subObj(), subObj({ id: 'sub-002', name: '爱奇艺' })])
      const result = await SubscriptionService.getSubscriptionById('sub-002')
      expect(result !== null).assertTrue()
      expect((result as Record<string, string>).name).assertEqual('爱奇艺')
    })

    it('不存在_返回null', 0, async () => {
      SubscriptionService._setPresetSubscriptions([subObj()])
      const result = await SubscriptionService.getSubscriptionById('nonexistent')
      expect(result === null).assertTrue()
    })

    it('空预设_返回null', 0, async () => {
      const result = await SubscriptionService.getSubscriptionById('any')
      expect(result === null).assertTrue()
    })
  })

  // ── createSubscription ──────────────────────────────
  describe('SubscriptionService_createSubscription', () => {
    it('返回空对象', 0, async () => {
      const result = await SubscriptionService.createSubscription({ name: '测试' })
      expect(result !== undefined).assertTrue()
    })
  })

  // ── updateSubscription ──────────────────────────────
  describe('SubscriptionService_updateSubscription', () => {
    it('调用不抛异常', 0, async () => {
      await SubscriptionService.updateSubscription('sub-001', { name: '新名称' })
    })
  })

  // ── deleteSubscription ──────────────────────────────
  describe('SubscriptionService_deleteSubscription', () => {
    it('调用不抛异常', 0, async () => {
      await SubscriptionService.deleteSubscription('sub-001')
    })
  })

  // ── deleteAllByUser ──────────────────────────────
  describe('SubscriptionService_deleteAllByUser', () => {
    it('调用不抛异常', 0, async () => {
      await SubscriptionService.deleteAllByUser(userId)
    })
  })

  // ── updateSubscriptionStatus ─────────────────────────
  describe('SubscriptionService_updateSubscriptionStatus', () => {
    it('调用不抛异常', 0, async () => {
      await SubscriptionService.updateSubscriptionStatus('sub-001', 'paused')
    })
  })

  // ── calculateTotalSubscriptionAmount ─────────────────
  describe('SubscriptionService_calculateTotalSubscriptionAmount', () => {
    it('空列表_返回0', 0, () => {
      const result = SubscriptionService.calculateTotalSubscriptionAmount([])
      expect(result).assertEqual(0)
    })

    it('单个active订阅_累加金额', 0, () => {
      const subs = [subObj({ amount: 1500, status: 'active' })]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      expect(result).assertEqual(1500)
    })

    it('多个active订阅_累加总额_不按周期折算', 0, () => {
      const subs = [
        subObj({ amount: 1500, billing_cycle: 'monthly', status: 'active' }),
        subObj({ id: 'sub-002', amount: 21120, billing_cycle: 'once_quarterly', status: 'active' })
      ]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      // 1500 + 21120 = 22620，季度订阅金额原值计入，不乘以 3
      expect(result).assertEqual(22620)
    })

    it('非active状态_跳过不计入', 0, () => {
      const subs = [
        subObj({ amount: 1500, status: 'active' }),
        subObj({ id: 'sub-002', amount: 2500, status: 'paused' }),
        subObj({ id: 'sub-003', amount: 1000, status: 'cancelled' })
      ]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      expect(result).assertEqual(1500)
    })

    it('全部非active_返回0', 0, () => {
      const subs = [
        subObj({ amount: 1500, status: 'paused' }),
        subObj({ id: 'sub-002', amount: 2500, status: 'cancelled' })
      ]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      expect(result).assertEqual(0)
    })

    it('amount为NaN_视为0', 0, () => {
      const subs = [subObj({ amount: 'not_a_number', status: 'active' })]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      expect(result).assertEqual(0)
    })

    it('amount为字符串数字_正确转换', 0, () => {
      const subs = [subObj({ amount: '3000', status: 'active' })]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      expect(result).assertEqual(3000)
    })

    it('混合场景_只累加active的有效金额', 0, () => {
      const subs = [
        subObj({ amount: 1000, status: 'active' }),
        subObj({ id: 'sub-002', amount: 'not_a_number', status: 'active' }),
        subObj({ id: 'sub-003', amount: 2000, status: 'active' }),
        subObj({ id: 'sub-004', amount: 5000, status: 'paused' })
      ]
      const result = SubscriptionService.calculateTotalSubscriptionAmount(subs)
      expect(result).assertEqual(3000)
    })
  })

  // ── groupByBillingCycle ──────────────────────────────
  describe('SubscriptionService_groupByBillingCycle', () => {
    it('空列表_返回空Map', 0, () => {
      const m = SubscriptionService.groupByBillingCycle([])
      expect(m.size).assertEqual(0)
    })

    it('单周期_返回单元素Map', 0, () => {
      const subs = [subObj({ amount: 1500, billing_cycle: 'monthly', status: 'active' })]
      const m = SubscriptionService.groupByBillingCycle(subs)
      expect(m.size).assertEqual(1)
      expect(m.get('monthly')).assertEqual(1500)
    })

    it('混合周期_按周期分组求和_不折算', 0, () => {
      const subs = [
        subObj({ amount: 3000, billing_cycle: 'monthly', status: 'active' }),
        subObj({ id: 'sub-002', amount: 21120, billing_cycle: 'once_quarterly', status: 'active' }),
        subObj({ id: 'sub-003', amount: 12000, billing_cycle: 'annually', status: 'active' })
      ]
      const m = SubscriptionService.groupByBillingCycle(subs)
      expect(m.size).assertEqual(3)
      expect(m.get('monthly')).assertEqual(3000)
      expect(m.get('once_quarterly')).assertEqual(21120)
      expect(m.get('annually')).assertEqual(12000)
    })

    it('同周期_金额累加', 0, () => {
      const subs = [
        subObj({ amount: 1500, billing_cycle: 'monthly', status: 'active' }),
        subObj({ id: 'sub-002', amount: 2500, billing_cycle: 'monthly', status: 'active' })
      ]
      const m = SubscriptionService.groupByBillingCycle(subs)
      expect(m.size).assertEqual(1)
      expect(m.get('monthly')).assertEqual(4000)
    })

    it('非active状态_跳过不计入', 0, () => {
      const subs = [
        subObj({ amount: 1500, billing_cycle: 'monthly', status: 'paused' }),
        subObj({ id: 'sub-002', amount: 2500, billing_cycle: 'once_quarterly', status: 'cancelled' })
      ]
      const m = SubscriptionService.groupByBillingCycle(subs)
      expect(m.size).assertEqual(0)
    })
  })

  // ── _reset ──────────────────────────────────────
  describe('SubscriptionService__reset', () => {
    it('重置后getSubscriptions返回空', 0, async () => {
      SubscriptionService._setPresetSubscriptions([subObj()])
      SubscriptionService._reset()
      const result = await SubscriptionService.getSubscriptions(userId)
      expect(result.length).assertEqual(0)
    })
  })
}
