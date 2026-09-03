import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { PaymentService } from '../../mock/PaymentService.mock'
import { DbService } from '../../mock/DbService.mock'
import { UserService } from '../../mock/UserService.mock'
import { CalculationService } from '../../mock/CalculationService.mock'

const userId = 'test-user-001'

function payRow(overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    id: 'pay-001',
    debt_id: 'debt-001',
    user_id: userId,
    period_number: 1,
    payment_date: '2024-12-15',
    scheduled_date: '2024-12-15',
    amount_paid: 10000,
    principal_paid: 9000,
    interest_paid: 1000,
    balance_after: 71000,
    is_manual: 1,
    created_at: '2024-12-15T10:00:00.000Z'
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

function achievementRow(overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    id: 'ach-001',
    user_id: userId,
    debt_id: 'debt-001',
    platform: '京东白条',
    total_paid: 120000,
    total_interest: 5000,
    duration_days: 365,
    completed_at: '2025-12-15',
    card_data: '{"platform_color":"#1677FF","total_periods":12}',
    created_at: '2025-12-15T10:00:00.000Z'
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

export default function paymentServiceTest() {
  beforeEach(() => {
    DbService._reset()
    UserService._reset()
    CalculationService._reset()
  })

  // ── getPaymentRecords ──────────────────────────────
  describe('PaymentService_getPaymentRecords', () => {
    it('空表_返回空数组', 0, async () => {
      const result = await PaymentService.getPaymentRecords('debt-001')
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回还款记录', 0, async () => {
      DbService._setQueryPreset('FROM payment_records', [payRow(), payRow({ id: 'pay-002', period_number: 2 })])
      const result = await PaymentService.getPaymentRecords('debt-001')
      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('pay-001')
      expect(result[0].amount_paid).assertEqual(10000)
    })
  })

  // ── getRecordsByUser ──────────────────────────────
  describe('PaymentService_getRecordsByUser', () => {
    it('空表_返回空数组', 0, async () => {
      const result = await PaymentService.getRecordsByUser(userId)
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回用户所有记录', 0, async () => {
      DbService._setQueryPreset('FROM payment_records', [payRow()])
      const result = await PaymentService.getRecordsByUser(userId)
      expect(result.length).assertEqual(1)
    })
  })

  // ── getCurrentMonthPaid ──────────────────────────────
  describe('PaymentService_getCurrentMonthPaid', () => {
    it('空表_返回0', 0, async () => {
      const result = await PaymentService.getCurrentMonthPaid(userId)
      expect(result).assertEqual(0)
    })

    it('有记录_返回本月还款总额', 0, async () => {
      // 构造当月记录
      const now = new Date()
      const y = now.getFullYear()
      const m = now.getMonth() + 1
      const dateStr = y + '-' + (m < 10 ? '0' + m : '' + m) + '-15'
      DbService._setQueryPreset('FROM payment_records', [
        payRow({ payment_date: dateStr, amount_paid: 5000 }),
        payRow({ id: 'pay-002', payment_date: dateStr, amount_paid: 3000 })
      ])
      const result = await PaymentService.getCurrentMonthPaid(userId)
      expect(result).assertEqual(8000)
    })
  })

  // ── getAchievementCards ──────────────────────────────
  describe('PaymentService_getAchievementCards', () => {
    it('空表_返回空数组', 0, async () => {
      const result = await PaymentService.getAchievementCards(userId)
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回成就卡片', 0, async () => {
      DbService._setQueryPreset('FROM achievement_cards', [achievementRow()])
      const result = await PaymentService.getAchievementCards(userId)
      expect(result.length).assertEqual(1)
      expect(result[0].platform).assertEqual('京东白条')
      expect(result[0].total_paid).assertEqual(120000)
    })
  })

  // ── markPeriodPaid ──────────────────────────────
  describe('PaymentService_markPeriodPaid', () => {
    it('正常还款_插入记录并更新债务', 0, async () => {
      // 设置预设计划
      CalculationService._setPresetPaymentSchedule([
        { period_number: 1, principal: 9000, interest: 1000, total: 10000, date: '2024-12-15' }
      ])
      const debt = {
        id: 'debt-001',
        user_id: userId,
        current_balance: 80000,
        remaining_periods: 10,
        next_payment_date: '2024-12-15',
        total_periods: 12,
        remaining_periods_copy: 10,
        platform: '京东白条',
        platform_color: '#1677FF',
        start_date: '2024-01-01',
        status: 'active'
      }
      await PaymentService.markPeriodPaid(debt as Object, 1)
      const store = DbService._getStore()
      // 应插入 payment_records
      const payRows = store.get('payment_records')
      expect(payRows !== undefined).assertTrue()
      expect(payRows!.length).assertEqual(1)
    })

    it('期数对不上计划_回退下一期仍写入', 0, async () => {
      // 计划仅有相对/下一期项时，调用方传绝对期号仍应还「下一期」而非假成功
      CalculationService._setPresetPaymentSchedule([
        { period_number: 3, principal: 9000, interest: 1000, total: 10000, date: '2024-12-15' }
      ])
      const debt = {
        id: 'debt-001',
        user_id: userId,
        current_balance: 80000,
        remaining_periods: 10,
        next_payment_date: '2024-12-15',
        total_periods: 12,
        platform: '京东白条',
        platform_color: '#1677FF',
        start_date: '2024-01-01',
        status: 'active'
      }
      await PaymentService.markPeriodPaid(debt as Object, 99)
      const store = DbService._getStore()
      const payRows = store.get('payment_records')
      expect(payRows !== undefined).assertTrue()
      expect(payRows!.length).assertEqual(1)
    })

    it('无计划且无余额_抛错', 0, async () => {
      CalculationService._setPresetPaymentSchedule([])
      const debt = {
        id: 'debt-001',
        user_id: userId,
        current_balance: 0,
        remaining_periods: 0,
        next_payment_date: '2024-12-15',
        total_periods: 12,
        platform: '京东白条',
        platform_color: '#1677FF',
        start_date: '2024-01-01',
        status: 'active'
      }
      let threw = false
      try {
        await PaymentService.markPeriodPaid(debt as Object, 1)
      } catch (_e) {
        threw = true
      }
      expect(threw).assertTrue()
    })
  })

  // ── payoffDebt ──────────────────────────────
  describe('PaymentService_payoffDebt', () => {
    it('全额还款_插入记录并标记完成', 0, async () => {
      const debt = {
        id: 'debt-001',
        user_id: userId,
        current_balance: 50000,
        remaining_periods: 3,
        total_periods: 12,
        next_payment_date: '2024-12-15',
        platform: '京东白条',
        platform_color: '#1677FF',
        start_date: '2024-01-01',
        status: 'active'
      }
      await PaymentService.payoffDebt(debt as Object)
      const store = DbService._getStore()
      const payRows = store.get('payment_records')
      expect(payRows !== undefined).assertTrue()
      expect(payRows!.length).assertEqual(1)
      // 应更新 debts 状态
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('UPDATE debts') >= 0)).assertTrue()
    })
  })

  // ── importPaymentRecord ──────────────────────────────
  describe('PaymentService_importPaymentRecord', () => {
    it('导入记录_插入成功', 0, async () => {
      const input = {
        debt_id: 'debt-001',
        period_number: 1,
        payment_date: '2024-12-15',
        scheduled_date: '2024-12-15',
        amount_paid: 10000,
        principal_paid: 9000,
        interest_paid: 1000,
        balance_after: 71000,
        is_manual: false
      }
      await PaymentService.importPaymentRecord(input as Object)
      const store = DbService._getStore()
      const payRows = store.get('payment_records')
      expect(payRows !== undefined).assertTrue()
      expect(payRows!.length).assertEqual(1)
    })
  })

  // ── deleteAllByUser ──────────────────────────────
  describe('PaymentService_deleteAllByUser', () => {
    it('按用户删除_清除还款和成就', 0, async () => {
      await PaymentService.deleteAllByUser(userId)
      const log = DbService._getSqlCallLog()
      const deleteLogs = log.filter(l => l.sql.indexOf('DELETE') >= 0)
      expect(deleteLogs.length).assertEqual(2)
      expect(deleteLogs[0].sql.indexOf('payment_records') >= 0).assertTrue()
      expect(deleteLogs[1].sql.indexOf('achievement_cards') >= 0).assertTrue()
    })
  })

  // ── objectToPaymentRecord 字段映射 ──────────────────
  describe('PaymentService_objectToPaymentRecord_字段映射', () => {
    it('数值字段正确转换', 0, async () => {
      DbService._setQueryPreset('FROM payment_records', [payRow({ amount_paid: '25000', period_number: '5' })])
      const result = await PaymentService.getPaymentRecords('debt-001')
      expect(result[0].amount_paid).assertEqual(25000)
      expect(result[0].period_number).assertEqual(5)
    })

    it('is_manual为0_false', 0, async () => {
      DbService._setQueryPreset('FROM payment_records', [payRow({ is_manual: 0 })])
      const result = await PaymentService.getPaymentRecords('debt-001')
      expect(result[0].is_manual).assertFalse()
    })

    it('缺失数值字段_默认0', 0, async () => {
      DbService._setQueryPreset('FROM payment_records', [{ id: 'pay-x', debt_id: 'd1', user_id: userId }])
      const result = await PaymentService.getPaymentRecords('debt-001')
      expect(result[0].amount_paid).assertEqual(0)
      expect(result[0].period_number).assertEqual(0)
    })
  })
}
