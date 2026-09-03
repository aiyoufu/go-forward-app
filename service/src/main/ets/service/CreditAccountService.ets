import { relationalStore } from '@kit.ArkData'
import { CreditAccount, CreateCreditAccountInput, UpdateCreditAccountInput } from 'common'
import { DbService } from './DbService'
import { E2EEService } from './auth/E2EEService'
import { UserService } from './UserService'
import { Utils } from 'common'
import { Constants } from 'common'
import { SyncScheduler } from './sync/SyncScheduler'
import { SyncOutbox } from './sync/SyncOutbox'
import { CloudIdMap } from './sync/CloudIdMap'
import { SyncedWrite } from './SyncedWrite'
import { LocalDataStore } from './sync/LocalDataStore'
import { AnalyticsService } from './AnalyticsService'

export class CreditAccountService {
  static async getCreditAccounts(userId: string = UserService.getCurrentUserId()): Promise<CreditAccount[]> {
    const cached = LocalDataStore.getAccounts(userId)
    if (cached !== null) {
      return cached
    }
    const rs = await DbService.query(
      'SELECT * FROM credit_accounts WHERE user_id = ? ORDER BY sort_order ASC, created_at ASC',
      [userId]
    )
    const list: CreditAccount[] = []
    try {
      while (rs.goToNextRow()) {
        const row = CreditAccountService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_CREDIT_ACCOUNTS, row)
        list.push(CreditAccountService.objectToCreditAccount(decrypted))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    LocalDataStore.setAccounts(list, userId)
    return list
  }

  static async getCreditAccountById(id: string): Promise<CreditAccount | null> {
    if (id.length === 0) {
      return null
    }
    const cached = LocalDataStore.getAccounts()
    if (cached !== null) {
      for (let i = 0; i < cached.length; i++) {
        if (cached[i].id === id) {
          return cached[i]
        }
      }
    }
    // 增量先拉到负债时 FK 可能仍是云端 id，账户补拉后按 cloud_id 也能命中
    const rs = await DbService.query(
      'SELECT * FROM credit_accounts WHERE id = ? OR cloud_id = ? LIMIT 1',
      [id, id]
    )
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
    const row = CreditAccountService.rowToObject(rs)
    try {
      rs.close()
    } catch (_e3) {
    }
    const decrypted = await E2EEService.decryptRecord(Constants.TABLE_CREDIT_ACCOUNTS, row)
    return CreditAccountService.objectToCreditAccount(decrypted)
  }

  /**
   * 用文件名与账户名做近似匹配（子串 + 首段 token，最长命中胜出）。
   * 不访问 DB，纯函数；fileName 通常来自相册选图的 displayName。
   * 返回匹配到的账户原名；未命中返回空串。
   */
  static matchAccountByFileName(fileName: string, accounts: CreditAccount[]): string {
    if (fileName.length === 0 || accounts.length === 0) {
      return ''
    }
    const stripped = fileName.toLowerCase().replace(/\.[^.]+$/, '').trim()
    if (stripped.length === 0) {
      return ''
    }
    const leadingToken = stripped.split(/[-_\s]/)[0]
    let best = ''
    for (let i = 0; i < accounts.length; i++) {
      const acc = accounts[i]
      const name = acc.name.trim().toLowerCase()
      if (name.length === 0) {
        continue
      }
      const substringHit = stripped.indexOf(name) >= 0
      const tokenHit = leadingToken.length >= 2 && name.indexOf(leadingToken) >= 0
      if ((substringHit || tokenHit) && name.length > best.length) {
        best = acc.name
      }
    }
    return best
  }

  static async createCreditAccount(input: CreateCreditAccountInput): Promise<CreditAccount> {
    try {
      const account = new CreditAccount()
      account.id = Utils.generateId()
      account.user_id = UserService.getCurrentUserId()
      account.name = input.name
      account.last_four = input.last_four
      account.color = input.color
      account.icon_url = input.icon_url
      account.expiry_date = input.expiry_date
      account.cvv = input.cvv
      account.bill_day = input.bill_day
      account.payment_day = input.payment_day
      account.annual_fee_required_swipes = input.annual_fee_required_swipes
      account.annual_fee_manual_swipes = input.annual_fee_manual_swipes
      account.credit_limit = input.credit_limit
      account.grace_period_days = input.grace_period_days
      account.interest_free_days = input.interest_free_days
      account.sort_order = input.sort_order
      account.created_at = DbService.now()
      account.updated_at = DbService.now()

      const row = CreditAccountService.creditAccountToObject(account)
      const encrypted = await E2EEService.encryptRecord(Constants.TABLE_CREDIT_ACCOUNTS, row)
      const values = CreditAccountService.objectToMap(encrypted)
      await DbService.insert('credit_accounts', values)
      await SyncedWrite.afterCreate(Constants.TABLE_CREDIT_ACCOUNTS, account.id,
        () => LocalDataStore.invalidateAccounts())
      await AnalyticsService.trackRecordCreateSuccess('credit_account')
      Constants.markPendingNotifPrompt()
      return account
    } catch (e) {
      AnalyticsService.trackRecordCreateFail('credit_account', 'db')
      if (e instanceof Error) {
        throw e
      }
      throw new Error('create_credit_account_failed')
    }
  }

  static async updateCreditAccount(id: string, updates: UpdateCreditAccountInput): Promise<void> {
    const existing = await CreditAccountService.getCreditAccountById(id)
    if (!existing) {
      return
    }
    const account = CreditAccountService.applyUpdates(existing, updates)
    account.updated_at = DbService.now()
    const row = CreditAccountService.creditAccountToObject(account)
    const encrypted = await E2EEService.encryptRecord(Constants.TABLE_CREDIT_ACCOUNTS, row)
    const values = CreditAccountService.objectToMap(encrypted)
    await DbService.update('credit_accounts', values, 'id = ?', [id])
    await SyncedWrite.afterUpsert(Constants.TABLE_CREDIT_ACCOUNTS, id,
      () => LocalDataStore.invalidateAccounts())
  }

  static async deleteCreditAccount(id: string): Promise<void> {
    const cloudId = await SyncedWrite.beforeDelete(Constants.TABLE_CREDIT_ACCOUNTS, id)
    const debtUpdates = new Map<string, string | number | boolean>()
    debtUpdates.set('credit_account_id', '')
    debtUpdates.set('updated_at', DbService.now())
    await DbService.update('debts', debtUpdates, 'credit_account_id = ?', [id])

    const subUpdates = new Map<string, string | number | boolean>()
    subUpdates.set('credit_account_id', '')
    subUpdates.set('updated_at', DbService.now())
    await DbService.update('subscriptions', subUpdates, 'credit_account_id = ?', [id])

    await DbService.delete('credit_accounts', 'id = ?', [id])
    await SyncedWrite.afterDelete(Constants.TABLE_CREDIT_ACCOUNTS, id, cloudId,
      () => LocalDataStore.invalidateAccounts())
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    const debtUpdates = new Map<string, string | number | boolean>()
    debtUpdates.set('credit_account_id', '')
    debtUpdates.set('updated_at', DbService.now())
    await DbService.update('debts', debtUpdates, 'user_id = ?', [userId])

    const subUpdates = new Map<string, string | number | boolean>()
    subUpdates.set('credit_account_id', '')
    subUpdates.set('updated_at', DbService.now())
    await DbService.update('subscriptions', subUpdates, 'user_id = ?', [userId])

    await DbService.delete('credit_accounts', 'user_id = ?', [userId])
  }

  static async updateSortOrder(orderedIds: string[]): Promise<void> {
    for (let i = 0; i < orderedIds.length; i++) {
      const updates = new Map<string, string | number | boolean>()
      updates.set('sort_order', i)
      updates.set('updated_at', DbService.now())
      await DbService.update('credit_accounts', updates, 'id = ?', [orderedIds[i]])
    }
    if (orderedIds.length > 0) {
      for (let i = 0; i < orderedIds.length; i++) {
        const cid = await CloudIdMap.resolveCloudId(Constants.TABLE_CREDIT_ACCOUNTS, orderedIds[i])
        await SyncOutbox.enqueueUpsert(Constants.TABLE_CREDIT_ACCOUNTS, orderedIds[i], cid)
      }
      LocalDataStore.invalidateAccounts()
      SyncScheduler.scheduleAfterWrite()
    }
  }

  private static applyUpdates(existing: CreditAccount, updates: UpdateCreditAccountInput): CreditAccount {
    const account = new CreditAccount()
    account.id = existing.id
    account.user_id = existing.user_id
    account.name = updates.name !== undefined ? updates.name : existing.name
    account.last_four = updates.last_four !== undefined ? updates.last_four : existing.last_four
    account.color = updates.color !== undefined ? updates.color : existing.color
    account.icon_url = updates.icon_url !== undefined ? updates.icon_url : existing.icon_url
    account.expiry_date = updates.expiry_date !== undefined ? updates.expiry_date : existing.expiry_date
    account.cvv = updates.cvv !== undefined ? updates.cvv : existing.cvv
    account.bill_day = updates.bill_day !== undefined ? updates.bill_day : existing.bill_day
    account.payment_day = updates.payment_day !== undefined ? updates.payment_day : existing.payment_day
    account.annual_fee_required_swipes = updates.annual_fee_required_swipes !== undefined ? updates.annual_fee_required_swipes : existing.annual_fee_required_swipes
    account.annual_fee_manual_swipes = updates.annual_fee_manual_swipes !== undefined ? updates.annual_fee_manual_swipes : existing.annual_fee_manual_swipes
    account.credit_limit = updates.credit_limit !== undefined ? updates.credit_limit : existing.credit_limit
    account.grace_period_days = updates.grace_period_days !== undefined ? updates.grace_period_days : existing.grace_period_days
    account.interest_free_days = updates.interest_free_days !== undefined ? updates.interest_free_days : existing.interest_free_days
    account.sort_order = updates.sort_order !== undefined ? updates.sort_order : existing.sort_order
    account.created_at = existing.created_at
    account.updated_at = DbService.now()
    return account
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

  private static objectToCreditAccount(obj: object): CreditAccount {
    const a = new CreditAccount()
    const src = obj as Record<string, string | number | boolean | undefined>
    a.id = '' + (src['id'] ?? '')
    a.user_id = '' + (src['user_id'] ?? '')
    a.name = '' + (src['name'] ?? '')
    a.last_four = '' + (src['last_four'] ?? '')
    a.color = '' + (src['color'] ?? '')
    a.icon_url = '' + (src['icon_url'] ?? '')
    a.expiry_date = '' + (src['expiry_date'] ?? '')
    a.cvv = '' + (src['cvv'] ?? '')
    a.bill_day = Number(src['bill_day']) || 1
    a.payment_day = Number(src['payment_day']) || 1
    a.annual_fee_required_swipes = Number(src['annual_fee_required_swipes']) || 0
    a.annual_fee_manual_swipes = Number(src['annual_fee_manual_swipes']) || 0
    a.credit_limit = Number(src['credit_limit']) || 0
    a.grace_period_days = Number(src['grace_period_days']) || 0
    a.interest_free_days = Number(src['interest_free_days']) || 0
    a.sort_order = Number(src['sort_order']) || 0
    a.created_at = '' + (src['created_at'] ?? '')
    a.updated_at = '' + (src['updated_at'] ?? '')
    return a
  }

  private static creditAccountToObject(account: CreditAccount): Record<string, string | number | boolean> {
    const obj: Record<string, string | number | boolean> = {}
    obj['id'] = account.id
    obj['user_id'] = account.user_id
    obj['name'] = account.name
    obj['last_four'] = account.last_four
    obj['color'] = account.color
    obj['icon_url'] = account.icon_url
    obj['expiry_date'] = account.expiry_date
    obj['cvv'] = account.cvv
    obj['bill_day'] = account.bill_day
    obj['payment_day'] = account.payment_day
    obj['annual_fee_required_swipes'] = account.annual_fee_required_swipes
    obj['annual_fee_manual_swipes'] = account.annual_fee_manual_swipes
    obj['credit_limit'] = account.credit_limit
    obj['grace_period_days'] = account.grace_period_days
    obj['interest_free_days'] = account.interest_free_days
    obj['sort_order'] = account.sort_order
    obj['created_at'] = account.created_at
    obj['updated_at'] = account.updated_at
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
