import { relationalStore } from '@kit.ArkData'
import { PaymentRecord } from 'common'
import { Debt, PaymentScheduleItem } from 'common'
import { AchievementCard } from 'common'
import { DbService } from './DbService'
import { E2EEService } from './auth/E2EEService'
import { UserService } from './UserService'
import { Utils } from 'common'
import { Constants } from 'common'
import { CalculationService } from './CalculationService'
import { SyncedWrite } from './SyncedWrite'
import { SyncScheduler } from './sync/SyncScheduler'
import { SyncOutbox } from './sync/SyncOutbox'
import { CloudIdMap } from './sync/CloudIdMap'
import { LocalDataStore } from './sync/LocalDataStore'
import { AnalyticsService } from './AnalyticsService'

/** 导入还款记录入参（导入管道 → PaymentService 的唯一数据通道） */
export class ImportPaymentInput {
  debt_id: string = ''
  period_number: number = 0
  payment_date: string = ''
  scheduled_date: string = ''
  amount_paid: number = 0
  principal_paid: number = 0
  interest_paid: number = 0
  balance_after: number = 0
  is_manual: boolean = true
}

export class PaymentService {
  static async getPaymentRecords(debtId: string): Promise<PaymentRecord[]> {
    const rs = await DbService.query(
      'SELECT * FROM payment_records WHERE debt_id = ? ORDER BY period_number ASC',
      [debtId]
    )
    const list: PaymentRecord[] = []
    try {
      while (rs.goToNextRow()) {
        const row = PaymentService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_PAYMENT_RECORDS, row)
        list.push(PaymentService.objectToPaymentRecord(decrypted))
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

  /** 用户全部还款记录（首页负债走势回溯用） */
  static async getRecordsByUser(userId: string): Promise<PaymentRecord[]> {
    const rs = await DbService.query(
      'SELECT * FROM payment_records WHERE user_id = ?',
      [userId]
    )
    const list: PaymentRecord[] = []
    try {
      while (rs.goToNextRow()) {
        const row = PaymentService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_PAYMENT_RECORDS, row)
        list.push(PaymentService.objectToPaymentRecord(decrypted))
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

  /** 用户是否存在任意还款记录（首页还款进度显隐用，不解密、仅判断行存在） */
  static async hasPaymentRecords(userId: string): Promise<boolean> {
    const rs = await DbService.query(
      'SELECT 1 FROM payment_records WHERE user_id = ? LIMIT 1',
      [userId]
    )
    let has = false
    try {
      has = rs.goToNextRow()
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return has
  }

  static async getCurrentMonthPaid(userId: string): Promise<number> {
    const now = new Date()
    const year = now.getFullYear()
    const month = now.getMonth() + 1
    const start = year + '-' + (month < 10 ? '0' + month : '' + month) + '-01'
    const nextMonth = month === 12 ? 1 : month + 1
    const nextYear = month === 12 ? year + 1 : year
    const end = nextYear + '-' + (nextMonth < 10 ? '0' + nextMonth : '' + nextMonth) + '-01'

    const rs = await DbService.query(
      'SELECT * FROM payment_records WHERE user_id = ? AND payment_date >= ? AND payment_date < ?',
      [userId, start, end]
    )
    let total = 0
    try {
      while (rs.goToNextRow()) {
        const row = PaymentService.rowToObject(rs)
        const decrypted = await E2EEService.decryptRecord(Constants.TABLE_PAYMENT_RECORDS, row)
        const record = PaymentService.objectToPaymentRecord(decrypted)
        total += record.amount_paid
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return total
  }

  static async getAchievementCards(userId: string = UserService.getCurrentUserId()): Promise<AchievementCard[]> {
    const rs = await DbService.query(
      'SELECT * FROM achievement_cards WHERE user_id = ? ORDER BY completed_at DESC',
      [userId]
    )
    const list: AchievementCard[] = []
    try {
      while (rs.goToNextRow()) {
        const card = new AchievementCard()
        try {
          card.id = '' + (rs.getString(rs.getColumnIndex('id')) ?? '')
        } catch (_c1) {
        }
        try {
          card.user_id = '' + (rs.getString(rs.getColumnIndex('user_id')) ?? '')
        } catch (_c2) {
        }
        try {
          card.debt_id = '' + (rs.getString(rs.getColumnIndex('debt_id')) ?? '')
        } catch (_c3) {
        }
        try {
          card.platform = '' + (rs.getString(rs.getColumnIndex('platform')) ?? '')
        } catch (_c4) {
        }
        try {
          card.total_paid = Number(rs.getString(rs.getColumnIndex('total_paid'))) || 0
        } catch (_c5) {
        }
        try {
          card.total_interest = Number(rs.getString(rs.getColumnIndex('total_interest'))) || 0
        } catch (_c6) {
        }
        try {
          card.duration_days = Number(rs.getString(rs.getColumnIndex('duration_days'))) || 0
        } catch (_c7) {
        }
        try {
          card.completed_at = '' + (rs.getString(rs.getColumnIndex('completed_at')) ?? '')
        } catch (_c8) {
        }
        try {
          card.card_data = '' + (rs.getString(rs.getColumnIndex('card_data')) ?? '')
        } catch (_c9) {
        }
        try {
          card.created_at = '' + (rs.getString(rs.getColumnIndex('created_at')) ?? '')
        } catch (_c10) {
        }
        list.push(card)
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

  static async markPeriodPaid(
    debt: Debt,
    periodNumber: number,
    paymentDate: string = Utils.todayString(),
    amountOverride?: number
  ): Promise<void> {
    const schedule = CalculationService.generatePaymentSchedule(debt)
    // 优先绝对期号；对不上时取下一期（计划首项）——「本期还款」语义
    let item = schedule.find(s => s.period_number === periodNumber)
    if (!item && schedule.length > 0) {
      item = schedule[0]
    }
    if (!item) {
      // 无计划且无余额：不可假成功；有余额则按月供/余额合成一期
      if (debt.current_balance <= 0) {
        throw new Error('NO_PENDING_PAYMENT')
      }
      item = new PaymentScheduleItem()
      item.period_number = periodNumber > 0 ? periodNumber : 1
      item.date = debt.next_payment_date && debt.next_payment_date.length > 0
        ? debt.next_payment_date
        : paymentDate
      const payTotal = debt.monthly_payment > 0
        ? Math.min(debt.monthly_payment, debt.current_balance)
        : debt.current_balance
      item.principal = payTotal
      item.interest = 0
      item.total = payTotal
      item.balance_after = Math.max(0, debt.current_balance - payTotal)
      item.status = 'pending'
    }

    const principalPaid = item.principal
    const interestPaid = item.interest
    const totalPaid = amountOverride !== undefined ? Utils.yuanToFen(amountOverride) : item.total
    const newBalance = debt.current_balance - principalPaid

    const absPeriod = periodNumber > 0
      ? periodNumber
      : (item.period_number > 0 ? item.period_number : 1)

    const record = new PaymentRecord()
    record.id = Utils.generateId()
    record.debt_id = debt.id
    record.user_id = debt.user_id
    record.period_number = absPeriod
    record.payment_date = paymentDate
    record.scheduled_date = item.date
    record.amount_paid = totalPaid
    record.principal_paid = principalPaid
    record.interest_paid = interestPaid
    record.balance_after = newBalance > 0 ? newBalance : 0
    record.is_manual = true
    record.created_at = DbService.now()

    await PaymentService.insertPaymentRecord(record)

    const remaining = debt.remaining_periods > 0 ? debt.remaining_periods - 1 : 0
    const nextDate = debt.next_payment_date && debt.next_payment_date.length > 0
      ? Utils.addMonths(debt.next_payment_date, 1)
      : paymentDate

    const values = new Map<string, string | number | boolean>()
    values.set('current_balance', record.balance_after)
    values.set('remaining_periods', remaining)
    values.set('next_payment_date', nextDate)
    values.set('updated_at', DbService.now())

    if (remaining <= 0 || record.balance_after <= 0) {
      values.set('status', 'completed')
      values.set('remaining_periods', 0)
      if (record.balance_after <= 0) {
        values.set('current_balance', 0)
      }
      await PaymentService.createAchievementCard(debt, record)
    }

    await DbService.update('debts', values, 'id = ?', [debt.id])
    await SyncOutbox.enqueueUpsert(Constants.TABLE_PAYMENT_RECORDS, record.id, '')
    const debtCloud = await CloudIdMap.resolveCloudId(Constants.TABLE_DEBTS, debt.id)
    await SyncOutbox.enqueueUpsert(Constants.TABLE_DEBTS, debt.id, debtCloud)
    LocalDataStore.invalidateDebts()
    SyncScheduler.scheduleAfterWrite()
    AnalyticsService.trackRepaySuccess('period')
  }

  static async payoffDebt(debt: Debt): Promise<void> {
    const record = new PaymentRecord()
    record.id = Utils.generateId()
    record.debt_id = debt.id
    record.user_id = debt.user_id
    record.period_number = debt.total_periods - debt.remaining_periods + 1
    record.payment_date = Utils.todayString()
    record.scheduled_date = Utils.todayString()
    record.amount_paid = debt.current_balance
    record.principal_paid = debt.current_balance
    record.interest_paid = 0
    record.balance_after = 0
    record.is_manual = true
    record.created_at = DbService.now()

    await PaymentService.insertPaymentRecord(record)

    const values = new Map<string, string | number | boolean>()
    values.set('current_balance', 0)
    values.set('remaining_periods', 0)
    values.set('status', 'completed')
    values.set('updated_at', DbService.now())
    await DbService.update('debts', values, 'id = ?', [debt.id])

    await PaymentService.createAchievementCard(debt, record)
    await SyncOutbox.enqueueUpsert(Constants.TABLE_PAYMENT_RECORDS, record.id, '')
    const debtCloud = await CloudIdMap.resolveCloudId(Constants.TABLE_DEBTS, debt.id)
    await SyncOutbox.enqueueUpsert(Constants.TABLE_DEBTS, debt.id, debtCloud)
    LocalDataStore.invalidateDebts()
    SyncScheduler.scheduleAfterWrite()
    AnalyticsService.trackRepaySuccess('payoff')
  }

  static async importPaymentRecord(input: ImportPaymentInput): Promise<void> {
    const record = new PaymentRecord()
    record.id = Utils.generateId()
    record.debt_id = input.debt_id
    record.user_id = UserService.getCurrentUserId()
    record.period_number = input.period_number
    record.payment_date = input.payment_date
    record.scheduled_date = input.scheduled_date
    record.amount_paid = input.amount_paid
    record.principal_paid = input.principal_paid
    record.interest_paid = input.interest_paid
    record.balance_after = input.balance_after
    record.is_manual = input.is_manual
    record.created_at = DbService.now()
    await PaymentService.insertPaymentRecord(record)
    // 与 create 路径一致：入 outbox，避免仅本地可见、同步核对/他端丢失
    await SyncedWrite.afterCreate(Constants.TABLE_PAYMENT_RECORDS, record.id,
      () => LocalDataStore.invalidateDebts())
  }

  static async deleteAllByUser(userId: string): Promise<void> {
    await DbService.delete('payment_records', 'user_id = ?', [userId])
    await DbService.delete('achievement_cards', 'user_id = ?', [userId])
  }

  private static async insertPaymentRecord(record: PaymentRecord): Promise<void> {
    const row = PaymentService.paymentRecordToObject(record)
    const encrypted = await E2EEService.encryptRecord(Constants.TABLE_PAYMENT_RECORDS, row)
    const values = PaymentService.objectToMap(encrypted)
    await DbService.insert('payment_records', values)
  }

  private static async createAchievementCard(debt: Debt, finalRecord: PaymentRecord): Promise<void> {
    const records = await PaymentService.getPaymentRecords(debt.id)
    let totalPaid = 0
    let totalInterest = 0
    for (const r of records) {
      totalPaid += r.amount_paid
      totalInterest += r.interest_paid
    }

    const start = new Date(debt.start_date)
    const end = new Date(finalRecord.payment_date)
    const durationDays = Math.floor((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24))

    const card = new AchievementCard()
    card.id = Utils.generateId()
    card.user_id = debt.user_id
    card.debt_id = debt.id
    card.platform = debt.platform
    card.total_paid = totalPaid
    card.total_interest = totalInterest
    card.duration_days = durationDays
    card.completed_at = finalRecord.payment_date
    card.card_data = JSON.stringify({
      platform_color: debt.platform_color,
      total_periods: debt.total_periods
    })
    card.created_at = DbService.now()

    const values = new Map<string, string | number | boolean>()
    values.set('id', card.id)
    values.set('user_id', card.user_id)
    values.set('debt_id', card.debt_id)
    values.set('platform', card.platform)
    values.set('total_paid', card.total_paid)
    values.set('total_interest', card.total_interest)
    values.set('duration_days', card.duration_days)
    values.set('completed_at', card.completed_at)
    values.set('card_data', card.card_data)
    values.set('created_at', card.created_at)
    await DbService.insert('achievement_cards', values)
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

  private static objectToPaymentRecord(obj: object): PaymentRecord {
    const r = new PaymentRecord()
    const src = obj as Record<string, string | number | boolean | undefined>
    r.id = '' + (src['id'] ?? '')
    r.debt_id = '' + (src['debt_id'] ?? '')
    r.user_id = '' + (src['user_id'] ?? '')
    r.period_number = Number(src['period_number']) || 0
    r.payment_date = '' + (src['payment_date'] ?? '')
    r.scheduled_date = '' + (src['scheduled_date'] ?? '')
    r.amount_paid = Number(src['amount_paid']) || 0
    r.principal_paid = Number(src['principal_paid']) || 0
    r.interest_paid = Number(src['interest_paid']) || 0
    r.balance_after = Number(src['balance_after']) || 0
    r.is_manual = DbService.intToBool(src['is_manual'] as number)
    r.created_at = '' + (src['created_at'] ?? '')
    return r
  }

  private static paymentRecordToObject(record: PaymentRecord): Record<string, string | number | boolean> {
    const obj: Record<string, string | number | boolean> = {}
    obj['id'] = record.id
    obj['debt_id'] = record.debt_id
    obj['user_id'] = record.user_id
    obj['period_number'] = record.period_number
    obj['payment_date'] = record.payment_date
    obj['scheduled_date'] = record.scheduled_date
    obj['amount_paid'] = record.amount_paid
    obj['principal_paid'] = record.principal_paid
    obj['interest_paid'] = record.interest_paid
    obj['balance_after'] = record.balance_after
    obj['is_manual'] = DbService.boolToInt(record.is_manual)
    obj['created_at'] = record.created_at
    return obj
  }

  private static objectToMap(obj: object): Map<string, string | number | boolean> {
    const map = new Map<string, string | number | boolean>()
    const src = obj as Record<string, string | number | boolean | undefined>
    const keys = Object.keys(src)
    for (const key of keys) {
      const v = src[key]
      if (v !== undefined) {
        map.set(key, v)
      }
    }
    return map
  }
}
