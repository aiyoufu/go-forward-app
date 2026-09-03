import { relationalStore } from '@kit.ArkData'
import { Debt, DebtType, DebtStatus, RepaymentMethod, CreateDebtInput, UpdateDebtInput } from 'common'
import { DbService } from './DbService'
import { E2EEService } from './auth/E2EEService'
import { UserService } from './UserService'
import { Utils } from 'common'
import { Constants } from 'common'
import { CalculationService } from './CalculationService'
import { PlatformService } from './platform/PlatformService'
import { SyncedWrite } from './SyncedWrite'
import { LocalDataStore } from './sync/LocalDataStore'
import { AnalyticsService } from './AnalyticsService'

export class DebtService {
  static async getDebts(userId: string = UserService.getCurrentUserId()): Promise<Debt[]> {
    const cached = LocalDataStore.getDebts(userId)
    if (cached !== null) {
      return cached
    }
    return DebtService.getDebtsPaged(0, 10000, userId)
  }

  static async getDebtsPaged(
    offset: number,
    limit: number,
    userId: string = UserService.getCurrentUserId()
  ): Promise<Debt[]> {
    // 仅「从 0 起的大页」可写回全量投影；分页片段不污染缓存
    const canCacheFull = offset === 0 && limit >= 10000
    if (canCacheFull) {
      const cached = LocalDataStore.getDebts(userId)
      if (cached !== null) {
        return cached
      }
    }
    const rs = await DbService.query(
      'SELECT * FROM debts WHERE user_id = ? ORDER BY next_payment_date ASC LIMIT ? OFFSET ?',
      [userId, limit, offset]
    )
    const list: Debt[] = []
    try {
      while (rs.goToNextRow()) {
        const row = DebtService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_DEBTS, row)
        list.push(DebtService.objectToDebt(decrypted))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    if (canCacheFull) {
      LocalDataStore.setDebts(list, userId)
    }
    return list
  }

  static async getDebtById(id: string): Promise<Debt | null> {
    const rs = await DbService.query('SELECT * FROM debts WHERE id = ?', [id])
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
    const row = DebtService.rowToObject(rs)
    try {
      rs.close()
    } catch (_e3) {
    }
    const decrypted = await E2EEService.decryptRecord(Constants.TABLE_DEBTS, row)
    return DebtService.objectToDebt(decrypted)
  }

  static async createDebt(input: CreateDebtInput): Promise<Debt> {
    try {
      const preset = PlatformService.getPlatformPreset(input.platform)
      const debt = new Debt()
      debt.id = Utils.generateId()
      debt.user_id = UserService.getCurrentUserId()
      debt.platform = input.platform
      debt.platform_color = preset.color
      debt.debt_type = input.debt_type
      debt.principal = Utils.yuanToFen(input.principal)
      debt.current_balance = Utils.yuanToFen(input.current_balance)
      debt.monthly_payment = Utils.yuanToFen(input.monthly_payment)
      debt.total_periods = input.total_periods
      debt.remaining_periods = input.remaining_periods
      debt.repayment_method = input.repayment_method
      debt.total_interest = Utils.yuanToFen(input.total_interest)
      debt.annual_rate_bp = input.annual_rate_bp
      debt.payment_day = input.payment_day
      debt.next_payment_date = input.next_payment_date
      debt.start_date = input.start_date
      debt.estimated_end_date = CalculationService.calculateEstimatedEndDate(input.next_payment_date, input.remaining_periods)
      debt.is_auto_payment = input.is_auto_payment
      debt.status = 'active'
      debt.note = input.note
      debt.credit_account_id = input.credit_account_id
      debt.icon_url = input.icon_url ?? ''
      debt.currency = input.currency
      debt.original_principal_fen = input.original_principal_fen
      debt.locked_exchange_rate = input.locked_exchange_rate
      debt.created_at = DbService.now()
      debt.updated_at = DbService.now()

      const row = DebtService.debtToObject(debt)
      const encrypted = await E2EEService.encryptRecord(Constants.TABLE_DEBTS, row)
      const values = DebtService.objectToMap(encrypted)
      await DbService.insert('debts', values)
      await SyncedWrite.afterCreate(Constants.TABLE_DEBTS, debt.id,
        () => LocalDataStore.invalidateDebts())
      await AnalyticsService.trackRecordCreateSuccess('debt')
      Constants.markPendingNotifPrompt()
      return debt
    } catch (e) {
      AnalyticsService.trackRecordCreateFail('debt', 'db')
      if (e instanceof Error) {
        throw e
      }
      throw new Error('create_debt_failed')
    }
  }

  static async updateDebt(id: string, updates: UpdateDebtInput): Promise<void> {
    const existing = await DebtService.getDebtById(id)
    if (!existing) {
      return
    }
    const debt = DebtService.applyUpdates(existing, updates)
    debt.updated_at = DbService.now()
    const row = DebtService.debtToObject(debt)
    const encrypted = await E2EEService.encryptRecord(Constants.TABLE_DEBTS, row)
    const values = DebtService.objectToMap(encrypted)
    await DbService.update('debts', values, 'id = ?', [id])
    await SyncedWrite.afterUpsert(Constants.TABLE_DEBTS, id,
      () => LocalDataStore.invalidateDebts())
  }

  static async deleteDebt(id: string): Promise<void> {
    const cloudId = await SyncedWrite.beforeDelete(Constants.TABLE_DEBTS, id)
    await DbService.delete('payment_records', 'debt_id = ?', [id])
    await DbService.delete('debts', 'id = ?', [id])
    await SyncedWrite.afterDelete(Constants.TABLE_DEBTS, id, cloudId,
      () => LocalDataStore.invalidateDebts())
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    await DbService.delete('payment_records', 'user_id = ?', [userId])
    await DbService.delete('debts', 'user_id = ?', [userId])
  }

  static async updateDebtStatus(id: string, status: DebtStatus): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('status', status)
    values.set('updated_at', DbService.now())
    await DbService.update('debts', values, 'id = ?', [id])
    await SyncedWrite.afterUpsert(Constants.TABLE_DEBTS, id,
      () => LocalDataStore.invalidateDebts())
  }

  static async getOverdueDebts(userId: string = UserService.getCurrentUserId()): Promise<Debt[]> {
    const today = Utils.todayString()
    const rs = await DbService.query(
      'SELECT * FROM debts WHERE user_id = ? AND status = ? AND next_payment_date < ? ORDER BY next_payment_date ASC',
      [userId, 'active', today]
    )
    const list: Debt[] = []
    try {
      while (rs.goToNextRow()) {
        const row = DebtService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_DEBTS, row)
        list.push(DebtService.objectToDebt(decrypted))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return list
  }

  static async getActiveDebtsDueBeforeOrOn(
    date: string,
    userId: string = UserService.getCurrentUserId()
  ): Promise<Debt[]> {
    const rs = await DbService.query(
      'SELECT * FROM debts WHERE user_id = ? AND status = ? AND next_payment_date <= ? ORDER BY next_payment_date ASC',
      [userId, 'active', date]
    )
    const list: Debt[] = []
    try {
      while (rs.goToNextRow()) {
        const row = DebtService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_DEBTS, row)
        list.push(DebtService.objectToDebt(decrypted))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return list
  }

  static async getTodayDueDebts(userId: string = UserService.getCurrentUserId()): Promise<Debt[]> {
    const today = Utils.todayString()
    const rs = await DbService.query(
      'SELECT * FROM debts WHERE user_id = ? AND status = ? AND next_payment_date = ? ORDER BY next_payment_date ASC',
      [userId, 'active', today]
    )
    const list: Debt[] = []
    try {
      while (rs.goToNextRow()) {
        const row = DebtService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_DEBTS, row)
        list.push(DebtService.objectToDebt(decrypted))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return list
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

  private static objectToDebt(obj: object): Debt {
    const d = new Debt()
    const src = obj as Record<string, string | number | boolean | undefined>
    d.id = '' + (src['id'] ?? '')
    d.user_id = '' + (src['user_id'] ?? '')
    d.platform = '' + (src['platform'] ?? '')
    d.platform_color = '' + (src['platform_color'] ?? '')
    d.debt_type = DebtService.toDebtType('' + (src['debt_type'] ?? ''))
    d.principal = Number(src['principal']) || 0
    d.current_balance = Number(src['current_balance']) || 0
    d.monthly_payment = Number(src['monthly_payment']) || 0
    d.total_periods = Number(src['total_periods']) || 0
    d.remaining_periods = Number(src['remaining_periods']) || 0
    d.repayment_method = DebtService.toRepaymentMethod('' + (src['repayment_method'] ?? ''))
    d.total_interest = Number(src['total_interest']) || 0
    d.annual_rate_bp = Number(src['annual_rate_bp']) || 0
    d.payment_day = Number(src['payment_day']) || 1
    d.next_payment_date = '' + (src['next_payment_date'] ?? '')
    d.start_date = '' + (src['start_date'] ?? '')
    d.estimated_end_date = '' + (src['estimated_end_date'] ?? '')
    d.is_auto_payment = DbService.intToBool(src['is_auto_payment'] as number)
    d.status = DebtService.toDebtStatus('' + (src['status'] ?? ''))
    d.note = '' + (src['note'] ?? '')
    d.credit_account_id = '' + (src['credit_account_id'] ?? '')
    d.icon_url = '' + (src['icon_url'] ?? '')
    d.created_at = '' + (src['created_at'] ?? '')
    d.updated_at = '' + (src['updated_at'] ?? '')
    d.currency = '' + (src['currency'] ?? 'CNY')
    d.original_principal_fen = Number(src['original_principal_fen']) || 0
    d.locked_exchange_rate = Number(src['locked_exchange_rate']) || 1.0
    // 存量异常兜底：active 但 remaining_periods<=0（导入/AI 未正确关单）时，
    // 旧公式把预计还清日算成「到期日-1月」，此处按到期日重算修正
    if (d.status === 'active' && d.remaining_periods <= 0 && d.next_payment_date.length > 0) {
      d.estimated_end_date = d.next_payment_date
    }
    return d
  }

  private static toDebtType(value: string): DebtType {
    if (value === 'installment' || value === 'credit_card' || value === 'loan' || value === 'other') {
      return value
    }
    return 'installment'
  }

  private static toRepaymentMethod(value: string): RepaymentMethod {
    if (value === 'equal_payment' || value === 'fixed_interest' || value === 'custom') {
      return value
    }
    return 'equal_payment'
  }

  private static toDebtStatus(value: string): DebtStatus {
    if (value === 'active' || value === 'completed' || value === 'paused') {
      return value
    }
    return 'active'
  }

  private static debtToObject(debt: Debt): Record<string, string | number | boolean> {
    const obj: Record<string, string | number | boolean> = {}
    obj['id'] = debt.id
    obj['user_id'] = debt.user_id
    obj['platform'] = debt.platform
    obj['platform_color'] = debt.platform_color
    obj['debt_type'] = debt.debt_type
    obj['principal'] = debt.principal
    obj['current_balance'] = debt.current_balance
    obj['monthly_payment'] = debt.monthly_payment
    obj['total_periods'] = debt.total_periods
    obj['remaining_periods'] = debt.remaining_periods
    obj['repayment_method'] = debt.repayment_method
    obj['total_interest'] = debt.total_interest
    obj['annual_rate_bp'] = debt.annual_rate_bp
    obj['payment_day'] = debt.payment_day
    obj['next_payment_date'] = debt.next_payment_date
    obj['start_date'] = debt.start_date
    obj['estimated_end_date'] = debt.estimated_end_date
    obj['is_auto_payment'] = DbService.boolToInt(debt.is_auto_payment)
    obj['status'] = debt.status
    obj['note'] = debt.note
    obj['credit_account_id'] = debt.credit_account_id
    obj['icon_url'] = debt.icon_url
    obj['created_at'] = debt.created_at
    obj['updated_at'] = debt.updated_at
    obj['currency'] = debt.currency
    obj['original_principal_fen'] = debt.original_principal_fen
    obj['locked_exchange_rate'] = debt.locked_exchange_rate
    return obj
  }

  private static applyUpdates(existing: Debt, updates: UpdateDebtInput): Debt {
    const input = new CreateDebtInput()
    input.platform = updates.platform !== undefined ? updates.platform : existing.platform
    input.debt_type = updates.debt_type !== undefined ? updates.debt_type : existing.debt_type
    input.principal = updates.principal !== undefined ? updates.principal : existing.principal / 100
    input.current_balance = updates.current_balance !== undefined ? updates.current_balance : existing.current_balance / 100
    input.monthly_payment = updates.monthly_payment !== undefined ? updates.monthly_payment : existing.monthly_payment / 100
    input.total_periods = updates.total_periods !== undefined ? updates.total_periods : existing.total_periods
    input.remaining_periods = updates.remaining_periods !== undefined ? updates.remaining_periods : existing.remaining_periods
    input.repayment_method = updates.repayment_method !== undefined ? updates.repayment_method : existing.repayment_method
    input.total_interest = updates.total_interest !== undefined ? updates.total_interest : existing.total_interest / 100
    input.annual_rate_bp = updates.annual_rate_bp !== undefined ? updates.annual_rate_bp : existing.annual_rate_bp
    input.payment_day = updates.payment_day !== undefined ? updates.payment_day : existing.payment_day
    input.next_payment_date = updates.next_payment_date !== undefined ? updates.next_payment_date : existing.next_payment_date
    input.start_date = updates.start_date !== undefined ? updates.start_date : existing.start_date
    input.is_auto_payment = updates.is_auto_payment !== undefined ? updates.is_auto_payment : existing.is_auto_payment
    input.note = updates.note !== undefined ? updates.note : existing.note
    input.credit_account_id = updates.credit_account_id !== undefined ? updates.credit_account_id : existing.credit_account_id
    input.icon_url = updates.icon_url !== undefined ? updates.icon_url : existing.icon_url
    input.currency = updates.currency !== undefined ? updates.currency : existing.currency
    input.original_principal_fen = updates.original_principal_fen !== undefined ? updates.original_principal_fen : existing.original_principal_fen
    input.locked_exchange_rate = updates.locked_exchange_rate !== undefined ? updates.locked_exchange_rate : existing.locked_exchange_rate

    const updated = new Debt()
    updated.id = existing.id
    updated.user_id = existing.user_id
    updated.platform = input.platform
    updated.platform_color = PlatformService.getPlatformPreset(input.platform).color
    updated.debt_type = input.debt_type
    updated.principal = Utils.yuanToFen(input.principal)
    updated.current_balance = Utils.yuanToFen(input.current_balance)
    updated.monthly_payment = Utils.yuanToFen(input.monthly_payment)
    updated.total_periods = input.total_periods
    updated.remaining_periods = input.remaining_periods
    updated.repayment_method = input.repayment_method
    updated.total_interest = Utils.yuanToFen(input.total_interest)
    updated.annual_rate_bp = input.annual_rate_bp
    updated.payment_day = input.payment_day
    updated.next_payment_date = input.next_payment_date
    updated.start_date = input.start_date
    updated.estimated_end_date = CalculationService.calculateEstimatedEndDate(input.next_payment_date, input.remaining_periods)
    updated.is_auto_payment = input.is_auto_payment
    updated.status = existing.status
    updated.note = input.note
    updated.credit_account_id = input.credit_account_id
    updated.icon_url = input.icon_url ?? ''
    updated.currency = input.currency
    updated.original_principal_fen = input.original_principal_fen
    updated.locked_exchange_rate = input.locked_exchange_rate
    updated.created_at = existing.created_at
    updated.updated_at = DbService.now()
    return updated
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
