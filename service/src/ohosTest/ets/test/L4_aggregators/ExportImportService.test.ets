import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { ExportImportService } from '../../../../main/ets/service/ExportImportService'
import { Debt, Subscription, CreditAccount } from 'common'
import { DebtService } from '../../mock/DebtService.mock'
import { SubscriptionService } from '../../mock/SubscriptionService.mock'
import { CreditAccountService } from '../../mock/CreditAccountService.mock'
import { PaymentService } from '../../mock/PaymentService.mock'
import { UserService } from '../../mock/UserService.mock'

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
  d.next_payment_date = '2024-12-15'
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
  s.next_billing_date = '2024-12-15'
  s.start_date = '2024-01-01'
  s.status = 'active'
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
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(a as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return a
}

export default function exportImportServiceTest() {
  beforeEach(() => {
    DebtService._reset()
    SubscriptionService._reset()
    CreditAccountService._reset()
    PaymentService._reset()
    UserService._reset()
  })

  // ── exportToJson ──────────────────────
  describe('ExportImportService_exportToJson', () => {
    it('空数据_返回有效JSON', 0, async () => {
      const json = await ExportImportService.exportToJson()
      const data = JSON.parse(json) as Record<string, Object>
      expect(data['version']).assertEqual(1)
      expect(Array.isArray(data['debts'])).assertTrue()
      expect(Array.isArray(data['subscriptions'])).assertTrue()
      expect(Array.isArray(data['credit_accounts'])).assertTrue()
      expect(Array.isArray(data['payment_records'])).assertTrue()
      expect(typeof data['exported_at'] === 'string').assertTrue()
    })

    it('有债务和订阅_包含在JSON中', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', platform: '花呗' })])
      SubscriptionService._setPresetSubscriptions([makeSubscription({ id: 's1', name: '爱奇艺' })])
      const json = await ExportImportService.exportToJson()
      const data = JSON.parse(json) as Record<string, Object[]>
      expect((data['debts'] as Object[]).length).assertEqual(1)
      expect((data['subscriptions'] as Object[]).length).assertEqual(1)
    })

    it('有信用账户_包含在JSON中', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([makeAccount({ id: 'a1' })])
      const json = await ExportImportService.exportToJson()
      const data = JSON.parse(json) as Record<string, Object[]>
      expect((data['credit_accounts'] as Object[]).length).assertEqual(1)
    })

    it('有还款记录_按债务展开', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1' })])
      PaymentService._setPresetPaymentRecords([
        { id: 'p1', debt_id: 'd1', user_id: 'test-user-001', period_number: 1, payment_date: '2024-01-15', amount_paid: 12000, principal_paid: 10000, interest_paid: 2000, balance_after: 70000 }
      ])
      const json = await ExportImportService.exportToJson()
      const data = JSON.parse(json) as Record<string, Object[]>
      expect((data['payment_records'] as Object[]).length).assertEqual(1)
    })
  })

  // ── exportToCsv ──────────────────────
  describe('ExportImportService_exportToCsv', () => {
    it('空数据_包含三段标题', 0, async () => {
      const csv = await ExportImportService.exportToCsv()
      expect(csv.indexOf('=== 负债 debts ===') >= 0).assertTrue()
      expect(csv.indexOf('=== 订阅 subscriptions ===') >= 0).assertTrue()
      expect(csv.indexOf('=== 信用账户 credit_accounts ===') >= 0).assertTrue()
    })

    it('有债务_包含表头和数据行', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', platform: '花呗' })])
      const csv = await ExportImportService.exportToCsv()
      expect(csv.indexOf('平台,类型,本金(元)') >= 0).assertTrue()
      expect(csv.indexOf('花呗') >= 0).assertTrue()
    })

    it('有订阅_包含订阅行', 0, async () => {
      SubscriptionService._setPresetSubscriptions([makeSubscription({ id: 's1', name: '爱奇艺' })])
      const csv = await ExportImportService.exportToCsv()
      expect(csv.indexOf('爱奇艺') >= 0).assertTrue()
    })

    it('有信用账户_包含账户行', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([makeAccount({ id: 'a1', name: '招行信用卡' })])
      const csv = await ExportImportService.exportToCsv()
      expect(csv.indexOf('招行信用卡') >= 0).assertTrue()
    })

    it('CSV逗号转义_含逗号的字段加引号', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', platform: '花呗,借呗', note: 'A,B' })])
      const csv = await ExportImportService.exportToCsv()
      expect(csv.indexOf('"花呗,借呗"') >= 0).assertTrue()
    })

    it('CSV双引号转义_双引号变两个双引号', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', platform: '花呗"借呗' })])
      const csv = await ExportImportService.exportToCsv()
      expect(csv.indexOf('"花呗""借呗"') >= 0).assertTrue()
    })

    it('金额从分转为元', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1', principal: 120000 })])
      const csv = await ExportImportService.exportToCsv()
      // 120000分 = 1200元
      expect(csv.indexOf('1200') >= 0).assertTrue()
    })
  })

  // ── saveJsonToFile / saveCsvToFile ──────────────────────
  describe('ExportImportService_saveJsonToFile', () => {
    it('无context_返回false', 0, async () => {
      const r = await ExportImportService.saveJsonToFile(null as Object)
      expect(r).assertFalse()
    })
  })

  describe('ExportImportService_saveCsvToFile', () => {
    it('无context_返回false', 0, async () => {
      const r = await ExportImportService.saveCsvToFile(null as Object)
      expect(r).assertFalse()
    })
  })

  // ── importFromFile / importStatementCsv ──────────────────────
  describe('ExportImportService_importFromFile', () => {
    it('无context_返回失败结果', 0, async () => {
      const r = await ExportImportService.importFromFile(null as Object)
      expect(r.success).assertFalse()
    })
  })

  describe('ExportImportService_importStatementCsv', () => {
    it('无context_返回失败结果', 0, async () => {
      const r = await ExportImportService.importStatementCsv(null as Object)
      expect(r.success).assertFalse()
    })
  })

  // ── clearAllUserData ──────────────────────
  describe('ExportImportService_clearAllUserData', () => {
    it('空数据_返回true', 0, async () => {
      const r = await ExportImportService.clearAllUserData()
      expect(r.localCleared).assertTrue()
    })

    it('有数据_清除后返回true', 0, async () => {
      DebtService._setPresetDebts([makeDebt({ id: 'd1' })])
      SubscriptionService._setPresetSubscriptions([makeSubscription({ id: 's1' })])
      CreditAccountService._setPresetCreditAccounts([makeAccount({ id: 'a1' })])
      const r = await ExportImportService.clearAllUserData()
      expect(r.localCleared).assertTrue()
    })
  })
}
