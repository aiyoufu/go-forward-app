import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { SettingsTableSync } from '../../../../main/ets/service/sync/SettingsTableSync'
import { DebtTableSync } from '../../../../main/ets/service/sync/DebtTableSync'
import { PaymentTableSync } from '../../../../main/ets/service/sync/PaymentTableSync'
import { CreditAccountTableSync } from '../../../../main/ets/service/sync/CreditAccountTableSync'
import { SubscriptionTableSync } from '../../../../main/ets/service/sync/SubscriptionTableSync'
import { NotificationTableSync } from '../../../../main/ets/service/sync/NotificationTableSync'
import { AchievementTableSync } from '../../../../main/ets/service/sync/AchievementTableSync'
import { SyncRs } from '../../../../main/ets/service/sync/SyncRs'
import { DbService } from '../../mock/DbService.mock'

export default function syncTableAdaptersTest() {
  beforeEach(() => {
    DbService._reset()
  })

  // ══════════════════════════════════════════════════════
  // SettingsTableSync
  // ══════════════════════════════════════════════════════
  describe('SettingsTableSync_toCloud', () => {
    it('本地行转云端记录_bool转换', 0, async () => {
      const adapter = new SettingsTableSync()
      const row = { user_id: 'u1', cloud_id: '', app_lock_enabled: 1, app_lock_hash: 'hash', email_reminders: 0, updated_at: '2024-01-01' }
      // 通过 toMap 构造行，然后 toCloud
      const localRows = await adapter.getLocalRows('u1')
      // 空表 → 空
      expect(localRows.length).assertEqual(0)
      // 直接测试 toCloud：需要一个 SettingsSyncRow 类型参数
      // 由于 SettingsSyncRow 未导出，通过 fromCloud 反向构造
      const cloudRow = { user_id: 'u1', app_lock_enabled: true, app_lock_hash: 'hash', email_reminders: false, updated_at: '2024-01-01' }
      const localRow = adapter.fromCloud(cloudRow)
      expect(localRow.user_id).assertEqual('u1')
      expect(localRow.app_lock_enabled).assertEqual(1)
      expect(localRow.email_reminders).assertEqual(0)
    })

    it('toCloud_cloud_id为空时使用user_id', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: false, app_lock_hash: '', email_reminders: true, updated_at: '' }
      const localRow = adapter.fromCloud(cloudRow)
      expect(localRow.cloud_id).assertEqual('u1') // cloud_id = user_id
    })

    it('toCloud_bool转int', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: true, app_lock_hash: 'h', email_reminders: true, updated_at: '2024-01-01' }
      const localRow = adapter.fromCloud(cloudRow)
      const cloud = adapter.toCloud(localRow) as Record<string, Object>
      expect(cloud['app_lock_enabled']).assertTrue()
      expect(cloud['email_reminders']).assertTrue()
    })
  })

  describe('SettingsTableSync_toMap', () => {
    it('生成Map包含所有字段', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: true, app_lock_hash: 'hash', email_reminders: false, updated_at: '2024-01-01' }
      const localRow = adapter.fromCloud(cloudRow)
      const map = adapter.toMap(localRow)
      expect(map.has('user_id')).assertTrue()
      expect(map.has('app_lock_enabled')).assertTrue()
      expect(map.has('app_lock_hash')).assertTrue()
      expect(map.has('email_reminders')).assertTrue()
      expect(map.has('updated_at')).assertTrue()
    })

    it('cloud_id为空时不包含在Map中', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: false, app_lock_hash: '', email_reminders: false, updated_at: '' }
      const localRow = adapter.fromCloud(cloudRow)
      localRow.cloud_id = ''
      // 手动清空 cloud_id 后 toMap 不应包含 cloud_id
      const map = adapter.toMap(localRow)
      // cloud_id.length === 0 → 不 set
      expect(map.has('cloud_id')).assertFalse()
    })
  })

  describe('SettingsTableSync_接口方法', () => {
    it('getCloudId_优先cloud_id', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: false, app_lock_hash: '', email_reminders: false, updated_at: '' }
      const row = adapter.fromCloud(cloudRow)
      row.cloud_id = 'cloud-123'
      expect(adapter.getCloudId(row)).assertEqual('cloud-123')
    })

    it('getCloudId_cloud_id为空时返回user_id', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: false, app_lock_hash: '', email_reminders: false, updated_at: '' }
      const row = adapter.fromCloud(cloudRow)
      row.cloud_id = ''
      expect(adapter.getCloudId(row)).assertEqual('u1')
    })

    it('getLocalKeyColumn_返回user_id', 0, async () => {
      const adapter = new SettingsTableSync()
      expect(adapter.getLocalKeyColumn()).assertEqual('user_id')
    })

    it('getCloudRowId_返回user_id', 0, async () => {
      const adapter = new SettingsTableSync()
      const id = adapter.getCloudRowId({ user_id: 'u1' })
      expect(id).assertEqual('u1')
    })

    it('getLocalId_返回user_id', 0, async () => {
      const adapter = new SettingsTableSync()
      const cloudRow = { user_id: 'u1', app_lock_enabled: false, app_lock_hash: '', email_reminders: false, updated_at: '' }
      const row = adapter.fromCloud(cloudRow)
      expect(adapter.getLocalId(row)).assertEqual('u1')
    })
  })

  // ══════════════════════════════════════════════════════
  // DebtTableSync
  // ══════════════════════════════════════════════════════
  describe('DebtTableSync_toCloud_fromCloud', () => {
    it('fromCloud_正确映射所有字段', 0, async () => {
      const adapter = new DebtTableSync()
      const cloud = {
        id: 'cloud-1', user_id: 'u1', platform: '京东白条', platform_color: '#1677FF',
        debt_type: 'installment', principal: 100000, current_balance: 80000,
        monthly_payment: 10000, total_periods: 12, remaining_periods: 10,
        annual_rate_bp: 1800, payment_day: 15, next_payment_date: '2024-12-15',
        start_date: '2024-11-01', estimated_end_date: '2025-09-15',
        is_auto_payment: false, status: 'active', note: 'test',
        created_at: '2024-11-14', updated_at: '2024-11-14', icon_url: ''
      }
      const row = adapter.fromCloud(cloud)
      expect(row.cloud_id).assertEqual('cloud-1')
      expect(row.user_id).assertEqual('u1')
      expect(row.platform).assertEqual('京东白条')
      expect(row.principal).assertEqual(100000)
      expect(row.is_auto_payment).assertEqual(0) // boolToInt(false) = 0
    })

    it('toCloud_cloud_id为空时生成uuid', 0, async () => {
      const adapter = new DebtTableSync()
      const cloud = {
        id: '', user_id: 'u1', platform: '白条', platform_color: '#1677FF',
        debt_type: 'installment', principal: 100, current_balance: 100,
        monthly_payment: 50, total_periods: 2, remaining_periods: 2,
        annual_rate_bp: 0, payment_day: 1, next_payment_date: '2024-12-01',
        start_date: '2024-12-01', estimated_end_date: '2025-01-01',
        is_auto_payment: false, status: 'active', note: '',
        created_at: '', updated_at: '', icon_url: ''
      }
      const row = adapter.fromCloud(cloud)
      const result = adapter.toCloud(row) as Record<string, Object>
      // id should be a generated uuid (non-empty)
      expect(('' + result['id']).length).assertLarger(0)
    })

    it('toCloud_is_auto_payment转bool', 0, async () => {
      const adapter = new DebtTableSync()
      const cloud = {
        id: 'c1', user_id: 'u1', platform: '白条', platform_color: '#1677FF',
        debt_type: 'installment', principal: 100, current_balance: 100,
        monthly_payment: 50, total_periods: 2, remaining_periods: 2,
        annual_rate_bp: 0, payment_day: 1, next_payment_date: '2024-12-01',
        start_date: '2024-12-01', estimated_end_date: '2025-01-01',
        is_auto_payment: true, status: 'active', note: '',
        created_at: '', updated_at: '2024-12-01', icon_url: ''
      }
      const row = adapter.fromCloud(cloud)
      expect(row.is_auto_payment).assertEqual(1)
      const result = adapter.toCloud(row) as Record<string, Object>
      expect(result['is_auto_payment']).assertTrue()
    })
  })

  describe('DebtTableSync_toMap', () => {
    it('包含所有字段', 0, async () => {
      const adapter = new DebtTableSync()
      const cloud = {
        id: 'c1', user_id: 'u1', platform: '白条', platform_color: '#1677FF',
        debt_type: 'installment', principal: 100, current_balance: 100,
        monthly_payment: 50, total_periods: 2, remaining_periods: 2,
        annual_rate_bp: 0, payment_day: 1, next_payment_date: '2024-12-01',
        start_date: '2024-12-01', estimated_end_date: '2025-01-01',
        is_auto_payment: false, status: 'active', note: '',
        created_at: '', updated_at: '', icon_url: ''
      }
      const row = adapter.fromCloud(cloud)
      const map = adapter.toMap(row)
      expect(map.has('id')).assertTrue()
      expect(map.has('user_id')).assertTrue()
      expect(map.has('platform')).assertTrue()
      expect(map.has('principal')).assertTrue()
      expect(map.has('icon_url')).assertTrue()
    })
  })

  describe('DebtTableSync_接口方法', () => {
    it('getLocalKeyColumn_返回id', 0, async () => {
      const adapter = new DebtTableSync()
      expect(adapter.getLocalKeyColumn()).assertEqual('id')
    })

    it('getCloudRowId_返回id', 0, async () => {
      const adapter = new DebtTableSync()
      expect(adapter.getCloudRowId({ id: 'c1' })).assertEqual('c1')
    })

    it('getCloudRowId_id为空_返回空', 0, async () => {
      const adapter = new DebtTableSync()
      expect(adapter.getCloudRowId({ id: '' })).assertEqual('')
    })
  })

  // ══════════════════════════════════════════════════════
  // PaymentTableSync
  // ══════════════════════════════════════════════════════
  describe('PaymentTableSync_toCloud_fromCloud', () => {
    it('fromCloud_正确映射', 0, async () => {
      const adapter = new PaymentTableSync()
      const cloud = {
        id: 'pc1', debt_id: 'd1', user_id: 'u1', period_number: 3,
        payment_date: '2024-12-15', scheduled_date: '2024-12-15',
        amount_paid: 10000, principal_paid: 9000, interest_paid: 1000,
        balance_after: 71000, is_manual: true, created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.cloud_id).assertEqual('pc1')
      expect(row.debt_id).assertEqual('d1')
      expect(row.amount_paid).assertEqual(10000)
      expect(row.is_manual).assertEqual(1)
    })

    it('toCloud_is_manual转bool', 0, async () => {
      const adapter = new PaymentTableSync()
      const cloud = {
        id: 'pc1', debt_id: 'd1', user_id: 'u1', period_number: 1,
        payment_date: '2024-12-15', scheduled_date: '2024-12-15',
        amount_paid: 5000, principal_paid: 4000, interest_paid: 1000,
        balance_after: 0, is_manual: false, created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.is_manual).assertEqual(0)
      const result = adapter.toCloud(row) as Record<string, Object>
      expect(result['is_manual']).assertFalse()
    })

    it('getUpdatedAt_返回created_at', 0, async () => {
      const adapter = new PaymentTableSync()
      const cloud = {
        id: 'pc1', debt_id: 'd1', user_id: 'u1', period_number: 1,
        payment_date: '2024-12-15', scheduled_date: '2024-12-15',
        amount_paid: 5000, principal_paid: 4000, interest_paid: 1000,
        balance_after: 0, is_manual: true, created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      expect(adapter.getUpdatedAt(row)).assertEqual('2024-12-15')
    })
  })

  // ══════════════════════════════════════════════════════
  // CreditAccountTableSync
  // ══════════════════════════════════════════════════════
  describe('CreditAccountTableSync_toCloud_fromCloud', () => {
    it('fromCloud_正确映射所有字段', 0, async () => {
      const adapter = new CreditAccountTableSync()
      const cloud = {
        id: 'ca1', user_id: 'u1', name: '招行', last_four: '1234',
        color: '#1677FF', icon_url: '', expiry_date: '2028-12', cvv: '123',
        bill_day: 5, payment_day: 20, annual_fee_required_swipes: 6,
        annual_fee_manual_swipes: 0, credit_limit: 50000, grace_period_days: 3,
        sort_order: 1, created_at: '2024-01-01', updated_at: '2024-01-01'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.cloud_id).assertEqual('ca1')
      expect(row.name).assertEqual('招行')
      expect(row.credit_limit).assertEqual(50000)
      expect(row.sort_order).assertEqual(1)
    })

    it('toMap_包含所有字段', 0, async () => {
      const adapter = new CreditAccountTableSync()
      const cloud = {
        id: 'ca1', user_id: 'u1', name: '招行', last_four: '1234',
        color: '#1677FF', icon_url: '', expiry_date: '2028-12', cvv: '',
        bill_day: 5, payment_day: 20, annual_fee_required_swipes: 6,
        annual_fee_manual_swipes: 0, credit_limit: 50000, grace_period_days: 3,
        sort_order: 0, created_at: '2024-01-01', updated_at: '2024-01-01'
      }
      const row = adapter.fromCloud(cloud)
      const map = adapter.toMap(row)
      expect(map.has('name')).assertTrue()
      expect(map.has('credit_limit')).assertTrue()
      expect(map.has('cvv')).assertTrue()
    })
  })

  // ══════════════════════════════════════════════════════
  // SubscriptionTableSync
  // ══════════════════════════════════════════════════════
  describe('SubscriptionTableSync_toCloud_fromCloud', () => {
    it('fromCloud_正确映射', 0, async () => {
      const adapter = new SubscriptionTableSync()
      const cloud = {
        id: 's1', user_id: 'u1', name: '网易云', category: 'music',
        amount: 1500, billing_cycle: 'monthly', next_billing_date: '2024-12-15',
        start_date: '2024-01-01', end_date: '', status: 'active',
        credit_account_id: '', color: '#FF5722', icon_url: '', note: '',
        reminder_days_before: 3, reminder_enabled: true,
        created_at: '2024-01-01', updated_at: '2024-01-01'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.cloud_id).assertEqual('s1')
      expect(row.name).assertEqual('网易云')
      expect(row.reminder_enabled).assertEqual(1) // boolToInt(true)
    })

    it('toCloud_reminder_enabled转bool', 0, async () => {
      const adapter = new SubscriptionTableSync()
      const cloud = {
        id: 's1', user_id: 'u1', name: '测试', category: 'other',
        amount: 100, billing_cycle: 'monthly', next_billing_date: '2024-12-01',
        start_date: '2024-01-01', end_date: '', status: 'active',
        credit_account_id: '', color: '', icon_url: '', note: '',
        reminder_days_before: 0, reminder_enabled: false,
        created_at: '2024-01-01', updated_at: '2024-01-01'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.reminder_enabled).assertEqual(0)
      const result = adapter.toCloud(row) as Record<string, Object>
      expect(result['reminder_enabled']).assertFalse()
    })
  })

  // ══════════════════════════════════════════════════════
  // NotificationTableSync
  // ══════════════════════════════════════════════════════
  describe('NotificationTableSync_toCloud_fromCloud', () => {
    it('fromCloud_正确映射', 0, async () => {
      const adapter = new NotificationTableSync()
      const cloud = {
        id: 'n1', user_id: 'u1', debt_id: 'd1', subscription_id: '',
        reminder_type: 'due_today', title: '还款提醒', body: '今日有还款',
        is_read: false, sent_at: '2024-12-15', read_at: ''
      }
      const row = adapter.fromCloud(cloud)
      expect(row.cloud_id).assertEqual('n1')
      expect(row.title).assertEqual('还款提醒')
      expect(row.is_read).assertEqual(0)
    })

    it('toCloud_is_read转bool', 0, async () => {
      const adapter = new NotificationTableSync()
      const cloud = {
        id: 'n1', user_id: 'u1', debt_id: '', subscription_id: '',
        reminder_type: 'due_today', title: '提醒', body: '',
        is_read: true, sent_at: '2024-12-15', read_at: '2024-12-16'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.is_read).assertEqual(1)
      const result = adapter.toCloud(row) as Record<string, Object>
      expect(result['is_read']).assertTrue()
    })

    it('getUpdatedAt_返回sent_at', 0, async () => {
      const adapter = new NotificationTableSync()
      const cloud = {
        id: 'n1', user_id: 'u1', debt_id: '', subscription_id: '',
        reminder_type: 'due_today', title: '提醒', body: '',
        is_read: false, sent_at: '2024-12-15', read_at: ''
      }
      const row = adapter.fromCloud(cloud)
      expect(adapter.getUpdatedAt(row)).assertEqual('2024-12-15')
    })
  })

  // ══════════════════════════════════════════════════════
  // AchievementTableSync
  // ══════════════════════════════════════════════════════
  describe('AchievementTableSync_toCloud_fromCloud', () => {
    it('fromCloud_正确映射', 0, async () => {
      const adapter = new AchievementTableSync()
      const cloud = {
        id: 'a1', user_id: 'u1', debt_id: 'd1', platform: '京东白条',
        total_paid: 120000, total_interest: 5000, duration_days: 365,
        completed_at: '2025-12-15', card_data: '{}', created_at: '2025-12-15'
      }
      const row = adapter.fromCloud(cloud)
      expect(row.cloud_id).assertEqual('a1')
      expect(row.total_paid).assertEqual(120000)
      expect(row.duration_days).assertEqual(365)
    })

    it('getUpdatedAt_优先completed_at', 0, async () => {
      const adapter = new AchievementTableSync()
      const cloud = {
        id: 'a1', user_id: 'u1', debt_id: 'd1', platform: '白条',
        total_paid: 100, total_interest: 0, duration_days: 30,
        completed_at: '2025-01-15', card_data: '', created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      expect(adapter.getUpdatedAt(row)).assertEqual('2025-01-15')
    })

    it('getUpdatedAt_completed_at为空时返回created_at', 0, async () => {
      const adapter = new AchievementTableSync()
      const cloud = {
        id: 'a1', user_id: 'u1', debt_id: 'd1', platform: '白条',
        total_paid: 100, total_interest: 0, duration_days: 30,
        completed_at: '', card_data: '', created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      expect(adapter.getUpdatedAt(row)).assertEqual('2024-12-15')
    })

    it('toMap_包含所有字段', 0, async () => {
      const adapter = new AchievementTableSync()
      const cloud = {
        id: 'a1', user_id: 'u1', debt_id: 'd1', platform: '白条',
        total_paid: 100, total_interest: 0, duration_days: 30,
        completed_at: '', card_data: '{}', created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      const map = adapter.toMap(row)
      expect(map.has('total_paid')).assertTrue()
      expect(map.has('card_data')).assertTrue()
      expect(map.has('duration_days')).assertTrue()
    })
  })

  // ══════════════════════════════════════════════════════
  // 所有适配器的 tableName
  // ══════════════════════════════════════════════════════
  describe('SyncTableAdapters_AllTableName', () => {
    it('SettingsTableSync_有tableName', 0, async () => {
      const adapter = new SettingsTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
    it('DebtTableSync_有tableName', 0, async () => {
      const adapter = new DebtTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
    it('PaymentTableSync_有tableName', 0, async () => {
      const adapter = new PaymentTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
    it('CreditAccountTableSync_有tableName', 0, async () => {
      const adapter = new CreditAccountTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
    it('SubscriptionTableSync_有tableName', 0, async () => {
      const adapter = new SubscriptionTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
    it('NotificationTableSync_有tableName', 0, async () => {
      const adapter = new NotificationTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
    it('AchievementTableSync_有tableName', 0, async () => {
      const adapter = new AchievementTableSync()
      expect(adapter.tableName.length).assertLarger(0)
    })
  })

  // ══════════════════════════════════════════════════════
  // setCloudId
  // ══════════════════════════════════════════════════════
  describe('SyncTableAdapters_AllSetCloudId', () => {
    it('DebtTableSync_setCloudId', 0, async () => {
      const adapter = new DebtTableSync()
      const cloud = {
        id: '', user_id: 'u1', platform: '白条', platform_color: '#1677FF',
        debt_type: 'installment', principal: 100, current_balance: 100,
        monthly_payment: 50, total_periods: 2, remaining_periods: 2,
        annual_rate_bp: 0, payment_day: 1, next_payment_date: '2024-12-01',
        start_date: '2024-12-01', estimated_end_date: '2025-01-01',
        is_auto_payment: false, status: 'active', note: '',
        created_at: '', updated_at: '', icon_url: ''
      }
      const row = adapter.fromCloud(cloud)
      adapter.setCloudId(row, 'new-cloud-id')
      expect(adapter.getCloudId(row)).assertEqual('new-cloud-id')
    })

    it('PaymentTableSync_setCloudId', 0, async () => {
      const adapter = new PaymentTableSync()
      const cloud = {
        id: '', debt_id: 'd1', user_id: 'u1', period_number: 1,
        payment_date: '2024-12-15', scheduled_date: '2024-12-15',
        amount_paid: 5000, principal_paid: 4000, interest_paid: 1000,
        balance_after: 0, is_manual: true, created_at: '2024-12-15'
      }
      const row = adapter.fromCloud(cloud)
      adapter.setCloudId(row, 'pc-new')
      expect(adapter.getCloudId(row)).assertEqual('pc-new')
    })
  })
}
