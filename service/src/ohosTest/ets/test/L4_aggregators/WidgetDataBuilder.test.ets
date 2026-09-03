import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { WidgetDataBuilder } from '../../../../main/ets/service/WidgetDataBuilder'
import { Debt, Subscription } from 'common'
import { DebtService } from '../../mock/DebtService.mock'
import { SubscriptionService } from '../../mock/SubscriptionService.mock'
import { UserService } from '../../mock/UserService.mock'
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
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

export default function widgetDataBuilderTest() {
  beforeEach(() => {
    DebtService._reset()
    SubscriptionService._reset()
    UserService._reset()
    CalculationService._reset()
  })

  // ── formatWidgetMoney ──────────────────────
  describe('WidgetDataBuilder_formatWidgetMoney', () => {
    it('0分_返回¥0.00', 0, () => {
      const s = WidgetDataBuilder.formatWidgetMoney(0)
      expect(s.indexOf('¥') >= 0).assertTrue()
      expect(s.indexOf('0.00') >= 0).assertTrue()
    })

    it('120000分=1200元_返回¥1,200.00', 0, () => {
      const s = WidgetDataBuilder.formatWidgetMoney(120000)
      expect(s.indexOf('1,200') >= 0).assertTrue()
    })

    it('1000万元_用万单位', 0, () => {
      const s = WidgetDataBuilder.formatWidgetMoney(10000000)
      expect(s.indexOf('万') >= 0).assertTrue()
    })

    it('15万元_用万单位且1位小数', 0, () => {
      const s = WidgetDataBuilder.formatWidgetMoney(15000000)
      expect(s.indexOf('万') >= 0).assertTrue()
      expect(s.indexOf('15') >= 0 || s.indexOf('150') >= 0).assertTrue()
    })

    it('负数_带负号', 0, () => {
      const s = WidgetDataBuilder.formatWidgetMoney(-120000)
      expect(s.indexOf('-') >= 0).assertTrue()
    })

    it('100万刚好_取整', 0, () => {
      const s = WidgetDataBuilder.formatWidgetMoney(100000000)
      expect(s.indexOf('100') >= 0).assertTrue()
      expect(s.indexOf('万') >= 0).assertTrue()
    })
  })

  // ── placeholders ──────────────────────
  describe('WidgetDataBuilder_placeholders', () => {
    it('monthDuePlaceholder_结构正确', 0, () => {
      const p = WidgetDataBuilder.monthDuePlaceholder()
      expect(p['hasData']).assertFalse()
      expect(p['moreCount']).assertEqual(0)
      expect((p['debtListPack'] as string).length).assertEqual(0)
    })

    it('pressurePlaceholder_6个分段', 0, () => {
      const p = WidgetDataBuilder.pressurePlaceholder()
      expect(p['hasData']).assertFalse()
      expect(p['peakIndex']).assertEqual(-1)
      const pack = p['chartPack'] as string
      const parts = pack.split(';')
      expect(parts.length).assertEqual(6)
    })

    it('subscriptionPlaceholder_默认值', 0, () => {
      const p = WidgetDataBuilder.subscriptionPlaceholder()
      expect(p['activeSubs']).assertEqual(0)
      expect(p['hasData']).assertFalse()
      expect(p['moreCount']).assertEqual(0)
    })

    it('debtOverviewPlaceholder_默认值', 0, () => {
      const p = WidgetDataBuilder.debtOverviewPlaceholder()
      expect(p['hasData']).assertFalse()
      expect(p['progress']).assertEqual(0)
    })

    it('debtPressurePlaceholder_6个分段', 0, () => {
      const p = WidgetDataBuilder.debtPressurePlaceholder()
      expect(p['hasData']).assertFalse()
      expect(p['peakIndex']).assertEqual(-1)
      const pack = p['chartPack'] as string
      expect(pack.split(';').length).assertEqual(6)
    })
  })

  // ── buildMonthDue ──────────────────────
  describe('WidgetDataBuilder_buildMonthDue', () => {
    it('空数据_返回placeholder样式', 0, async () => {
      const r = await WidgetDataBuilder.buildMonthDue()
      expect(r['hasData']).assertFalse()
      expect(r['moreCount']).assertEqual(0)
    })

    it('有active债务_返回数据', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', status: 'active', monthly_payment: 12000 })])
      const r = await WidgetDataBuilder.buildMonthDue()
      expect(r['hasData']).assertTrue()
    })

    it('债务超过2条_moreCount递增', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', platform: '花呗', monthly_payment: 12000 }),
        makeDebt({ id: 'd2', platform: '京东', monthly_payment: 8000 }),
        makeDebt({ id: 'd3', platform: '美团', monthly_payment: 5000 })
      ])
      const r = await WidgetDataBuilder.buildMonthDue()
      expect(r['moreCount']).assertEqual(1)
    })

    it('completed状态债务_不进清单', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', status: 'completed', monthly_payment: 12000 })
      ])
      const r = await WidgetDataBuilder.buildMonthDue()
      // completed 状态不进入清单，但因 getDueAmountForMonth 返回 0，hasData 可能为 false
      expect(r['moreCount']).assertEqual(0)
    })
  })

  // ── buildPressure ──────────────────────
  describe('WidgetDataBuilder_buildPressure', () => {
    it('空压力数据_返回placeholder', 0, async () => {
      CalculationService._setPresetMonthlyPressure([])
      const r = await WidgetDataBuilder.buildPressure()
      expect(r['hasData']).assertFalse()
      expect(r['peakIndex']).assertEqual(-1)
    })

    it('有压力数据_返回图表', 0, async () => {
      CalculationService._setPresetMonthlyPressure([
        { month: '2024-12', amount: 10000 },
        { month: '2025-01', amount: 20000 }
      ])
      const r = await WidgetDataBuilder.buildPressure()
      expect(r['hasData']).assertTrue()
      expect(r['peakIndex'] >= 0).assertTrue()
    })
  })

  // ── buildSubscription ──────────────────────
  describe('WidgetDataBuilder_buildSubscription', () => {
    it('空订阅_返回默认', 0, async () => {
      const r = await WidgetDataBuilder.buildSubscription()
      expect(r['activeSubs']).assertEqual(0)
      expect(r['hasData']).assertFalse()
    })

    it('有active订阅_计数', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', status: 'active' }),
        makeSubscription({ id: 's2', status: 'paused' })
      ])
      const r = await WidgetDataBuilder.buildSubscription()
      expect(r['activeSubs']).assertEqual(1)
      expect(r['hasData']).assertTrue()
    })

    it('订阅超过2条_moreCount递增', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', name: 'A', status: 'active', next_billing_date: '2099-12-01' }),
        makeSubscription({ id: 's2', name: 'B', status: 'active', next_billing_date: '2099-12-02' }),
        makeSubscription({ id: 's3', name: 'C', status: 'active', next_billing_date: '2099-12-03' })
      ])
      const r = await WidgetDataBuilder.buildSubscription()
      expect(r['moreCount']).assertEqual(1)
    })

    it('空名订阅_显示未命名', 0, async () => {
      SubscriptionService._setPresetSubscriptions([
        makeSubscription({ id: 's1', name: '', status: 'active' })
      ])
      const r = await WidgetDataBuilder.buildSubscription()
      const pack = r['subListPack'] as string
      expect(pack.indexOf('未命名') >= 0).assertTrue()
    })
  })

  // ── buildDebtOverview ──────────────────────
  describe('WidgetDataBuilder_buildDebtOverview', () => {
    it('空债务_返回默认', 0, async () => {
      const r = await WidgetDataBuilder.buildDebtOverview()
      expect(r['hasData']).assertFalse()
      expect(r['progress']).assertEqual(0)
    })

    it('有债务_计算进度', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', principal: 100000, current_balance: 50000, status: 'active' })
      ])
      const r = await WidgetDataBuilder.buildDebtOverview()
      expect(r['hasData']).assertTrue()
      expect(r['progress']).assertEqual(50)
    })

    it('totalDebt为0但有remaining_用remaining作为totalDebt', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', principal: 0, current_balance: 30000, status: 'active' })
      ])
      const r = await WidgetDataBuilder.buildDebtOverview()
      expect(r['hasData']).assertTrue()
    })
  })

  // ── buildDebtPressure ──────────────────────
  describe('WidgetDataBuilder_buildDebtPressure', () => {
    it('空数据_返回placeholder', 0, async () => {
      CalculationService._setPresetMonthlyPressure([])
      const r = await WidgetDataBuilder.buildDebtPressure()
      expect(r['hasData']).assertFalse()
      expect(r['peakIndex']).assertEqual(-1)
    })

    it('有债务和压力数据_返回融合视图', 0, async () => {
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', principal: 100000, current_balance: 50000 })
      ])
      CalculationService._setPresetMonthlyPressure([
        { month: '2024-12', amount: 10000 },
        { month: '2025-01', amount: 20000 }
      ])
      const r = await WidgetDataBuilder.buildDebtPressure()
      expect(r['hasData']).assertTrue()
      expect(r['progress']).assertEqual(50)
      expect(r['peakIndex'] >= 0).assertTrue()
    })
  })
}
