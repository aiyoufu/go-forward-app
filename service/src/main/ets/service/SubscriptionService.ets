import { relationalStore } from '@kit.ArkData'
import { Subscription, SubscriptionStatus, CreateSubscriptionInput, UpdateSubscriptionInput, BillingCycle, SubscriptionCategory } from 'common'
import { DbService } from './DbService'
import { E2EEService } from './auth/E2EEService'
import { UserService } from './UserService'
import { Utils } from 'common'
import { Constants } from 'common'
import { PlatformService } from './platform/PlatformService'
import { SyncedWrite } from './SyncedWrite'
import { LocalDataStore } from './sync/LocalDataStore'
import { CalculationService } from './CalculationService'
import { AnalyticsService } from './AnalyticsService'

export class SubscriptionService {
  static async getSubscriptions(userId: string = UserService.getCurrentUserId()): Promise<Subscription[]> {
    const cached = LocalDataStore.getSubscriptions(userId)
    if (cached !== null) {
      return cached
    }
    const rs = await DbService.query(
      'SELECT * FROM subscriptions WHERE user_id = ? ORDER BY next_billing_date ASC',
      [userId]
    )
    const list: Subscription[] = []
    try {
      while (rs.goToNextRow()) {
        const row = SubscriptionService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_SUBSCRIPTIONS, row)
        list.push(SubscriptionService.objectToSubscription(decrypted))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    LocalDataStore.setSubscriptions(list, userId)
    return list
  }

  static async getSubscriptionById(id: string): Promise<Subscription | null> {
    const rs = await DbService.query('SELECT * FROM subscriptions WHERE id = ?', [id])
    let hasRow = false
    try {
      hasRow = rs.goToFirstRow()
    } catch (_e) {
    }
    if (!hasRow) {
      try {
        rs.close()
      } catch (_e2) {
      }
      return null
    }
    const row = SubscriptionService.rowToObject(rs)
    try {
      rs.close()
    } catch (_e3) {
    }
    const decrypted = await E2EEService.decryptRecord(Constants.TABLE_SUBSCRIPTIONS, row)
    return SubscriptionService.objectToSubscription(decrypted)
  }

  static async createSubscription(input: CreateSubscriptionInput): Promise<Subscription> {
    try {
      const preset = PlatformService.getSubscriptionPreset(input.name)
      const sub = new Subscription()
      sub.id = Utils.generateId()
      sub.user_id = UserService.getCurrentUserId()
      sub.name = input.name
      sub.category = input.category !== 'other' ? input.category : (preset.category as SubscriptionCategory)
      sub.amount = Utils.yuanToFen(input.amount)
      sub.billing_cycle = input.billing_cycle
      sub.next_billing_date = input.next_billing_date
      sub.start_date = input.start_date
      sub.end_date = input.end_date
      sub.status = input.status
      sub.credit_account_id = input.credit_account_id
      sub.color = input.color.length > 0 ? input.color : preset.color
      sub.icon_url = input.icon_url
      sub.note = input.note
      sub.reminder_days_before = input.reminder_days_before
      sub.reminder_enabled = input.reminder_enabled
      sub.currency = input.currency
      sub.original_amount_fen = input.original_amount_fen
      sub.locked_exchange_rate = input.locked_exchange_rate
      sub.created_at = DbService.now()
      sub.updated_at = DbService.now()

      const row = SubscriptionService.subscriptionToObject(sub)
      const encrypted = await E2EEService.encryptRecord(Constants.TABLE_SUBSCRIPTIONS, row)
      const values = SubscriptionService.objectToMap(encrypted)
      await DbService.insert('subscriptions', values)
      await SyncedWrite.afterCreate(Constants.TABLE_SUBSCRIPTIONS, sub.id,
        () => LocalDataStore.invalidateSubscriptions())
      await AnalyticsService.trackRecordCreateSuccess('subscription')
      Constants.markPendingNotifPrompt()
      return sub
    } catch (e) {
      AnalyticsService.trackRecordCreateFail('subscription', 'db')
      if (e instanceof Error) {
        throw e
      }
      throw new Error('create_subscription_failed')
    }
  }

  static async updateSubscription(id: string, updates: UpdateSubscriptionInput): Promise<void> {
    const existing = await SubscriptionService.getSubscriptionById(id)
    if (!existing) {
      return
    }
    const sub = SubscriptionService.applyUpdates(existing, updates)
    sub.updated_at = DbService.now()
    const row = SubscriptionService.subscriptionToObject(sub)
    const encrypted = await E2EEService.encryptRecord(Constants.TABLE_SUBSCRIPTIONS, row)
    const values = SubscriptionService.objectToMap(encrypted)
    await DbService.update('subscriptions', values, 'id = ?', [id])
    await SyncedWrite.afterUpsert(Constants.TABLE_SUBSCRIPTIONS, id,
      () => LocalDataStore.invalidateSubscriptions())
  }

  static async deleteSubscription(id: string): Promise<void> {
    const cloudId = await SyncedWrite.beforeDelete(Constants.TABLE_SUBSCRIPTIONS, id)
    await DbService.delete('subscriptions', 'id = ?', [id])
    await SyncedWrite.afterDelete(Constants.TABLE_SUBSCRIPTIONS, id, cloudId,
      () => LocalDataStore.invalidateSubscriptions())
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    await DbService.delete('subscriptions', 'user_id = ?', [userId])
  }

  static async updateSubscriptionStatus(id: string, status: SubscriptionStatus): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('status', status)
    values.set('updated_at', DbService.now())
    await DbService.update('subscriptions', values, 'id = ?', [id])
    await SyncedWrite.afterUpsert(Constants.TABLE_SUBSCRIPTIONS, id,
      () => LocalDataStore.invalidateSubscriptions())
  }

  /** 活跃订阅原始金额合计（不按周期折算，避免把季度/年度订阅误算成月费）。 */
  static calculateTotalSubscriptionAmount(subscriptions: Subscription[]): number {
    let total = 0
    for (const sub of subscriptions) {
      if (sub.status !== 'active') {
        continue
      }
      total += sub.amount
    }
    return total
  }

  /** 按计费周期分组求和：cycle -> 原始金额合计（仅活跃订阅）。供 UI 展示「每月 ¥X · 一季度 ¥Y」。 */
  static groupByBillingCycle(subscriptions: Subscription[]): Map<string, number> {
    const map = new Map<string, number>()
    for (const sub of subscriptions) {
      if (sub.status !== 'active') {
        continue
      }
      const current = map.get(sub.billing_cycle) || 0
      map.set(sub.billing_cycle, current + sub.amount)
    }
    return map
  }

  private static applyUpdates(existing: Subscription, updates: UpdateSubscriptionInput): Subscription {
    const input = new CreateSubscriptionInput()
    input.name = updates.name !== undefined ? updates.name : existing.name
    input.category = updates.category !== undefined ? updates.category : existing.category
    input.amount = updates.amount !== undefined ? updates.amount : existing.amount / 100
    input.billing_cycle = updates.billing_cycle !== undefined ? updates.billing_cycle : existing.billing_cycle
    input.next_billing_date = updates.next_billing_date !== undefined ? updates.next_billing_date : existing.next_billing_date
    input.start_date = updates.start_date !== undefined ? updates.start_date : existing.start_date
    input.end_date = updates.end_date !== undefined ? updates.end_date : existing.end_date
    input.status = updates.status !== undefined ? updates.status : existing.status
    input.credit_account_id = updates.credit_account_id !== undefined ? updates.credit_account_id : existing.credit_account_id
    input.color = updates.color !== undefined ? updates.color : existing.color
    input.icon_url = updates.icon_url !== undefined ? updates.icon_url : existing.icon_url
    input.note = updates.note !== undefined ? updates.note : existing.note
    input.reminder_days_before = updates.reminder_days_before !== undefined ? updates.reminder_days_before : existing.reminder_days_before
    input.reminder_enabled = updates.reminder_enabled !== undefined ? updates.reminder_enabled : existing.reminder_enabled
    input.currency = updates.currency !== undefined ? updates.currency : existing.currency
    input.original_amount_fen = updates.original_amount_fen !== undefined ? updates.original_amount_fen : existing.original_amount_fen
    input.locked_exchange_rate = updates.locked_exchange_rate !== undefined ? updates.locked_exchange_rate : existing.locked_exchange_rate

    const preset = PlatformService.getSubscriptionPreset(input.name)
    const sub = new Subscription()
    sub.id = existing.id
    sub.user_id = existing.user_id
    sub.name = input.name
    sub.category = input.category !== 'other' ? input.category : (preset.category as SubscriptionCategory)
    sub.amount = Utils.yuanToFen(input.amount)
    sub.billing_cycle = input.billing_cycle
    sub.next_billing_date = input.next_billing_date
    sub.start_date = input.start_date
    sub.end_date = input.end_date
    sub.status = input.status
    sub.credit_account_id = input.credit_account_id
    sub.color = input.color.length > 0 ? input.color : preset.color
    sub.icon_url = input.icon_url
    sub.note = input.note
    sub.reminder_days_before = input.reminder_days_before
    sub.reminder_enabled = input.reminder_enabled
    sub.currency = input.currency
    sub.original_amount_fen = input.original_amount_fen
    sub.locked_exchange_rate = input.locked_exchange_rate
    sub.created_at = existing.created_at
    sub.updated_at = DbService.now()
    return sub
  }

  private static rowToObject(rs: relationalStore.ResultSet): Record<string, string | number | boolean> {
    const row: Record<string, string | number | boolean> = {}
    try {
      const count = rs.columnCount
      for (let i = 0; i < count; i++) {
        const name = rs.getColumnName(i)
        row[name] = rs.getString(i)
      }
    } catch (_e) {
    }
    return row
  }

  private static objectToSubscription(obj: object): Subscription {
    const s = new Subscription()
    const src = obj as Record<string, string | number | boolean | undefined>
    s.id = '' + (src['id'] ?? '')
    s.user_id = '' + (src['user_id'] ?? '')
    s.name = '' + (src['name'] ?? '')
    s.category = SubscriptionService.toCategory('' + (src['category'] ?? ''))
    s.amount = Number(src['amount']) || 0
    s.billing_cycle = SubscriptionService.toBillingCycle('' + (src['billing_cycle'] ?? ''))
    s.next_billing_date = '' + (src['next_billing_date'] ?? '')
    s.start_date = '' + (src['start_date'] ?? '')
    s.end_date = '' + (src['end_date'] ?? '')
    s.status = SubscriptionService.toStatus('' + (src['status'] ?? ''))
    s.credit_account_id = '' + (src['credit_account_id'] ?? '')
    s.color = '' + (src['color'] ?? '')
    s.icon_url = '' + (src['icon_url'] ?? '')
    s.note = '' + (src['note'] ?? '')
    s.reminder_days_before = Number(src['reminder_days_before']) || 0
    s.reminder_enabled = DbService.intToBool(src['reminder_enabled'] as number)
    s.created_at = '' + (src['created_at'] ?? '')
    s.updated_at = '' + (src['updated_at'] ?? '')
    s.currency = '' + (src['currency'] ?? 'CNY')
    s.original_amount_fen = Number(src['original_amount_fen']) || 0
    s.locked_exchange_rate = Number(src['locked_exchange_rate']) || 1.0
    return s
  }

  private static toCategory(value: string): SubscriptionCategory {
    const valid: SubscriptionCategory[] = ['video', 'music', 'tools', 'learning', 'lifestyle', 'storage', 'fitness', 'programming', 'ai', 'other']
    if (valid.indexOf(value as SubscriptionCategory) >= 0) {
      return value as SubscriptionCategory
    }
    return 'other'
  }

  private static toBillingCycle(value: string): BillingCycle {
    const valid: BillingCycle[] = ['once', 'once_weekly', 'once_quarterly', 'once_annually', 'weekly', 'biweekly', 'monthly', 'quarterly', 'semiannually', 'annually']
    if (valid.indexOf(value as BillingCycle) >= 0) {
      return value as BillingCycle
    }
    return 'monthly'
  }

  private static toStatus(value: string): SubscriptionStatus {
    const valid: SubscriptionStatus[] = ['active', 'paused', 'cancelled']
    if (valid.indexOf(value as SubscriptionStatus) >= 0) {
      return value as SubscriptionStatus
    }
    return 'active'
  }

  private static subscriptionToObject(sub: Subscription): Record<string, string | number | boolean> {
    const obj: Record<string, string | number | boolean> = {}
    obj['id'] = sub.id
    obj['user_id'] = sub.user_id
    obj['name'] = sub.name
    obj['category'] = sub.category
    obj['amount'] = sub.amount
    obj['billing_cycle'] = sub.billing_cycle
    obj['next_billing_date'] = sub.next_billing_date
    obj['start_date'] = sub.start_date
    obj['end_date'] = sub.end_date
    obj['status'] = sub.status
    obj['credit_account_id'] = sub.credit_account_id
    obj['color'] = sub.color
    obj['icon_url'] = sub.icon_url
    obj['note'] = sub.note
    obj['reminder_days_before'] = sub.reminder_days_before
    obj['reminder_enabled'] = DbService.boolToInt(sub.reminder_enabled)
    obj['created_at'] = sub.created_at
    obj['updated_at'] = sub.updated_at
    obj['currency'] = sub.currency
    obj['original_amount_fen'] = sub.original_amount_fen
    obj['locked_exchange_rate'] = sub.locked_exchange_rate
    return obj
  }

  private static objectToMap(obj: Record<string, string | number | boolean | undefined>): Map<string, string | number | boolean> {
    const map = new Map<string, string | number | boolean>()
    const keys = Object.keys(obj)
    for (const key of keys) {
      const v = obj[key]
      if (v !== undefined) {
        map.set(key, v)
      }
    }
    return map
  }
}
