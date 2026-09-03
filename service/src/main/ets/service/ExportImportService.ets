import { util } from '@kit.ArkTS'
import { picker } from '@kit.CoreFileKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { DebtService } from './DebtService'
import { SubscriptionService } from './SubscriptionService'
import { CreditAccountService } from './CreditAccountService'
import { PaymentService, ImportPaymentInput } from './PaymentService'
import { NotificationService } from './NotificationService'
import { UserService } from './UserService'
import { SyncService } from './sync/SyncService'
import { SyncScheduler } from './sync/SyncScheduler'
import { SyncOutbox } from './sync/SyncOutbox'
import { CloudIdMap } from './sync/CloudIdMap'
import { DbService } from './DbService'
import { LocalDataStore } from './sync/LocalDataStore'
import { CreateDebtInput, DebtType, RepaymentMethod } from 'common'
import { CreateSubscriptionInput, BillingCycle, SubscriptionCategory } from 'common'
import { CreateCreditAccountInput } from 'common'
import { Utils } from 'common'
import { Constants } from 'common'
import { ErrorMessages } from 'common'
import { AnalyticsService } from './AnalyticsService'

export class ImportSummary {
  /** 本次新增条数（补充导入） */
  debts: number = 0
  subscriptions: number = 0
  creditAccounts: number = 0
  paymentRecords: number = 0
  /** 已存在而跳过 */
  skippedDebts: number = 0
  skippedSubscriptions: number = 0
  skippedCreditAccounts: number = 0
  skippedPaymentRecords: number = 0
}

export class ImportResult {
  success: boolean = false
  message: string = ''
  imported: ImportSummary = new ImportSummary()
}

export class ClearAllResult {
  /** 本机业务数据是否已清空 */
  localCleared: boolean = false
  /** 已登录云端但业务数据（债务/还款/信用卡/订阅）云端清空失败 */
  cloudDataFailed: boolean = false
}

export class ExportImportService {
  static async exportToJson(): Promise<string> {
    const debts = await DebtService.getDebts()
    const subscriptions = await SubscriptionService.getSubscriptions()
    const accounts = await CreditAccountService.getCreditAccounts()
    const records: Array<Record<string, string | number | boolean>> = []
    for (const d of debts) {
      const paymentRecords = await PaymentService.getPaymentRecords(d.id)
      for (const r of paymentRecords) {
        const record: Record<string, string | number | boolean> = {}
        record['id'] = r.id
        record['debt_id'] = r.debt_id
        record['period_number'] = r.period_number
        record['payment_date'] = r.payment_date
        record['amount_paid'] = r.amount_paid
        record['principal_paid'] = r.principal_paid
        record['interest_paid'] = r.interest_paid
        record['balance_after'] = r.balance_after
        records.push(record)
      }
    }

    const data: Record<string, object | string | number | Array<object>> = {}
    data['version'] = 1
    data['exported_at'] = new Date().toISOString()
    data['debts'] = debts
    data['subscriptions'] = subscriptions
    data['credit_accounts'] = accounts
    data['payment_records'] = records
    return JSON.stringify(data)
  }

  static async saveJsonToFile(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const json = await ExportImportService.exportToJson()
      const documentSaveOptions = new picker.DocumentSaveOptions()
      documentSaveOptions.newFileNames = ['向前数据备份_' + ExportImportService.formatDate() + '.json']
      const documentPicker = new picker.DocumentViewPicker(context)
      const result = await documentPicker.save(documentSaveOptions)
      if (!result || result.length === 0) {
        return false
      }
      const uri = result[0]
      const file = fileIo.openSync(uri, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      const buffer = encoder.encodeInto(json)
      fileIo.writeSync(file.fd, buffer.buffer)
      fileIo.closeSync(file)
      return true
    } catch {
      return false
    }
  }

  static async exportToCsv(): Promise<string> {
    const debts = await DebtService.getDebts()
    const subscriptions = await SubscriptionService.getSubscriptions()
    const accounts = await CreditAccountService.getCreditAccounts()

    const sb: string[] = []
    sb.push('=== 负债 debts ===')
    sb.push('平台,类型,本金(元),当前余额(元),月供(元),总期数,剩余期数,还款方式,年利率(%),还款日,下次还款日,开始日期,状态,备注')
    for (const d of debts) {
      const row: string[] = []
      row.push(ExportImportService.csvEscape(d.platform))
      row.push(d.debt_type)
      row.push(ExportImportService.fenToYuanStr(d.principal))
      row.push(ExportImportService.fenToYuanStr(d.current_balance))
      row.push(ExportImportService.fenToYuanStr(d.monthly_payment))
      row.push('' + d.total_periods)
      row.push('' + d.remaining_periods)
      row.push(d.repayment_method)
      row.push('' + (d.annual_rate_bp / 100))
      row.push('' + d.payment_day)
      row.push(d.next_payment_date)
      row.push(d.start_date)
      row.push(d.status)
      row.push(ExportImportService.csvEscape(d.note))
      sb.push(row.join(','))
    }

    sb.push('')
    sb.push('=== 订阅 subscriptions ===')
    sb.push('名称,分类,金额(元),计费周期,下次扣费日,开始日期,状态,备注')
    for (const s of subscriptions) {
      const row: string[] = []
      row.push(ExportImportService.csvEscape(s.name))
      row.push(s.category)
      row.push(ExportImportService.fenToYuanStr(s.amount))
      row.push(s.billing_cycle)
      row.push(s.next_billing_date)
      row.push(s.start_date)
      row.push(s.status)
      row.push(ExportImportService.csvEscape(s.note))
      sb.push(row.join(','))
    }

    sb.push('')
    sb.push('=== 信用账户 credit_accounts ===')
    sb.push('名称,尾号,出单日,还款日,额度(万元),免年费刷卡次数,已刷次数')
    for (const a of accounts) {
      const row: string[] = []
      row.push(ExportImportService.csvEscape(a.name))
      row.push(a.last_four)
      row.push('' + a.bill_day)
      row.push('' + a.payment_day)
      row.push('' + a.credit_limit)
      row.push('' + a.annual_fee_required_swipes)
      row.push('' + a.annual_fee_manual_swipes)
      sb.push(row.join(','))
    }

    return sb.join('\n')
  }

  static async saveCsvToFile(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const csv = await ExportImportService.exportToCsv()
      const documentSaveOptions = new picker.DocumentSaveOptions()
      documentSaveOptions.newFileNames = ['向前明细表_' + ExportImportService.formatDate() + '.csv']
      const documentPicker = new picker.DocumentViewPicker(context)
      const result = await documentPicker.save(documentSaveOptions)
      if (!result || result.length === 0) {
        return false
      }
      const uri = result[0]
      const file = fileIo.openSync(uri, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      const buffer = encoder.encodeInto('\ufeff' + csv)
      fileIo.writeSync(file.fd, buffer.buffer)
      fileIo.closeSync(file)
      return true
    } catch {
      return false
    }
  }

  private static csvEscape(s: string): string {
    if (!s) {
      return ''
    }
    if (s.includes(',') || s.includes('"') || s.includes('\n')) {
      return '"' + s.replace(/"/g, '""') + '"'
    }
    return s
  }

  private static fenToYuanStr(fen: number): string {
    return '' + (Math.round(fen) / 100)
  }

  /** 补充导入成功文案：不展示还款；标明新增与跳过 */
  private static buildImportToast(s: ImportSummary): string {
    const added: string[] = []
    if (s.creditAccounts > 0) {
      added.push('账户 ' + s.creditAccounts)
    }
    if (s.debts > 0) {
      added.push('负债 ' + s.debts)
    }
    if (s.subscriptions > 0) {
      added.push('订阅 ' + s.subscriptions)
    }
    const skipped = s.skippedCreditAccounts + s.skippedDebts + s.skippedSubscriptions
    if (added.length === 0 && skipped === 0) {
      return '导入完成：无新数据'
    }
    if (added.length === 0) {
      return '导入完成：全部已存在，已跳过 ' + skipped + ' 条'
    }
    let msg = '补充导入：新增 ' + added.join(' · ')
    if (skipped > 0) {
      msg = msg + '，跳过重复 ' + skipped + ' 条'
    }
    return msg
  }

  /**
   * 兼容 snake_case（本应用导出）与 camelCase（云端/旧版导出）
   */
  private static arrayField(
    data: Record<string, Object>,
    snake: string,
    camel: string
  ): Record<string, Object>[] {
    const raw = data[snake] !== undefined && data[snake] !== null
      ? data[snake]
      : data[camel]
    if (raw === undefined || raw === null) {
      return []
    }
    return raw as Record<string, Object>[]
  }

  /** JSON 字段 → 字符串；null/undefined → 空串（避免 "null" 字面量） */
  private static fieldStr(row: Record<string, Object>, key: string, fallback: string = ''): string {
    const v = row[key]
    if (v === undefined || v === null) {
      return fallback
    }
    const s = '' + v
    if (s === 'null' || s === 'undefined') {
      return fallback
    }
    return s
  }

  private static fieldNum(row: Record<string, Object>, key: string, fallback: number = 0): number {
    const v = row[key]
    if (v === undefined || v === null) {
      return fallback
    }
    const n = Number(v)
    if (n !== n) {
      return fallback
    }
    return n
  }

  /**
   * 金额：导出为分时除以 100 得元；若已是小额元则原样。
   * 启发式：带小数且 |v|<1e5 → 元；整数 → 按分（与本应用/云端备份一致）。
   */
  private static fenOrYuanToYuan(value: number): number {
    if (value === 0) {
      return 0
    }
    if (Math.abs(value) < 100000 && value !== Math.floor(value)) {
      return value
    }
    return value / 100
  }

  /** 云端备份常见 UUID，导入时保留为 cloud_id，避免推送成新行与云端旧行分叉 */
  private static looksLikeCloudUuid(id: string): boolean {
    if (id.length !== 36) {
      return false
    }
    // 8-4-4-4-12
    return id.charAt(8) === '-' && id.charAt(13) === '-' && id.charAt(18) === '-' && id.charAt(23) === '-'
  }

  /**
   * 把备份里的 id 绑到本地行 cloud_id + 映射表，并重入 outbox（带 cloudId，upsert 合并到同一云行）。
   */
  private static async bindSourceCloudId(tableName: string, localId: string, sourceId: string): Promise<void> {
    if (localId.length === 0 || !ExportImportService.looksLikeCloudUuid(sourceId)) {
      return
    }
    try {
      const values = new Map<string, string | number | boolean>()
      values.set('cloud_id', sourceId)
      await DbService.update(tableName, values, 'id = ?', [localId])
      await CloudIdMap.setMapping(tableName, localId, sourceId)
      await SyncOutbox.enqueueUpsert(tableName, localId, sourceId)
    } catch {
    }
  }

  /** 若本机已通过同步拥有该云 id，直接复用本地主键 */
  private static async findLocalIdBySourceCloudId(tableName: string, sourceId: string): Promise<string> {
    if (!ExportImportService.looksLikeCloudUuid(sourceId)) {
      return ''
    }
    try {
      const mapped = await CloudIdMap.getLocalId(tableName, sourceId)
      if (mapped !== null && mapped.length > 0) {
        return mapped
      }
    } catch {
    }
    try {
      const rs = await DbService.query(
        'SELECT id FROM ' + tableName + ' WHERE cloud_id = ? LIMIT 1',
        [sourceId]
      )
      let id = ''
      if (rs.goToFirstRow()) {
        id = '' + (rs.getString(rs.getColumnIndex('id')) ?? '')
      }
      rs.close()
      return id
    } catch {
      return ''
    }
  }

  static async importFromFile(context: common.UIAbilityContext): Promise<ImportResult> {
    const result = new ImportResult()
    // 批量写：导入期间禁止每条 create 触发 debounce 同步，否则半成品易被核对/云端旧数据盖回
    let bulkStarted = false
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions()
      documentSelectOptions.maxSelectNumber = 1
      documentSelectOptions.fileSuffixFilters = ['.json']
      const documentPicker = new picker.DocumentViewPicker(context)
      const picked = await documentPicker.select(documentSelectOptions)
      if (!picked || picked.length === 0) {
        result.message = ErrorMessages.FILE_NOT_SELECTED
        return result
      }
      const uri = picked[0]
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, buf)
      fileIo.closeSync(file)
      const decoder = new util.TextDecoder()
      const json = decoder.decodeToString(new Uint8Array(buf))
      const data = JSON.parse(json) as Record<string, Object>

      SyncScheduler.beginBulkWrite()
      bulkStarted = true

      // 补充导入：已有数据按业务键匹配则跳过，仅新增缺失项
      const existingAccounts = await CreditAccountService.getCreditAccounts()
      const existingDebts = await DebtService.getDebts()
      const existingSubs = await SubscriptionService.getSubscriptions()

      const accountIdMap = new Map<string, string>()
      const accounts = ExportImportService.arrayField(data, 'credit_accounts', 'creditAccounts')
      for (const a of accounts) {
        const name = ExportImportService.fieldStr(a, 'name')
        if (name.length === 0) {
          continue
        }
        const lastFour = ExportImportService.fieldStr(a, 'last_four')
        const oldId = ExportImportService.fieldStr(a, 'id')
        let localId = ''
        // 1) 已同步过的同云 id
        if (oldId.length > 0) {
          localId = await ExportImportService.findLocalIdBySourceCloudId(Constants.TABLE_CREDIT_ACCOUNTS, oldId)
        }
        // 2) 业务键匹配
        if (localId.length === 0) {
          const matched = existingAccounts.find((acc) => {
            if (acc.name !== name) {
              return false
            }
            if (lastFour.length > 0 && acc.last_four.length > 0) {
              return acc.last_four === lastFour
            }
            return true
          })
          if (matched) {
            localId = matched.id
          }
        }
        if (localId.length > 0) {
          result.imported.skippedCreditAccounts += 1
          await ExportImportService.bindSourceCloudId(Constants.TABLE_CREDIT_ACCOUNTS, localId, oldId)
        } else {
          const input = new CreateCreditAccountInput()
          input.name = name
          input.last_four = lastFour
          input.color = ExportImportService.fieldStr(a, 'color')
          input.icon_url = ExportImportService.fieldStr(a, 'icon_url')
          input.expiry_date = ExportImportService.fieldStr(a, 'expiry_date')
          input.cvv = ExportImportService.fieldStr(a, 'cvv')
          input.bill_day = ExportImportService.fieldNum(a, 'bill_day', 1)
          input.payment_day = ExportImportService.fieldNum(a, 'payment_day', 1)
          input.credit_limit = ExportImportService.fieldNum(a, 'credit_limit', 0)
          input.annual_fee_required_swipes = ExportImportService.fieldNum(a, 'annual_fee_required_swipes', 0)
          input.annual_fee_manual_swipes = ExportImportService.fieldNum(a, 'annual_fee_manual_swipes', 0)
          input.grace_period_days = ExportImportService.fieldNum(a, 'grace_period_days', 0)
          input.interest_free_days = ExportImportService.fieldNum(a, 'interest_free_days', 0)
          input.sort_order = ExportImportService.fieldNum(a, 'sort_order', 0)
          AnalyticsService.setNextRecordSource('import_json')
          const created = await CreditAccountService.createCreditAccount(input)
          localId = created.id
          existingAccounts.push(created)
          result.imported.creditAccounts += 1
          await ExportImportService.bindSourceCloudId(Constants.TABLE_CREDIT_ACCOUNTS, localId, oldId)
        }
        if (oldId.length > 0 && localId.length > 0) {
          accountIdMap.set(oldId, localId)
        }
      }

      const debtIdMap = new Map<string, string>()
      const debts = ExportImportService.arrayField(data, 'debts', 'debts')
      for (const d of debts) {
        const platform = ExportImportService.fieldStr(d, 'platform', '未知平台')
        const principalYuan = ExportImportService.fenOrYuanToYuan(ExportImportService.fieldNum(d, 'principal', 0))
        const principalFen = Utils.yuanToFen(principalYuan)
        const startDate = ExportImportService.fieldStr(d, 'start_date', Utils.todayString())
        const oldId = ExportImportService.fieldStr(d, 'id')
        let localDebtId = ''
        if (oldId.length > 0) {
          localDebtId = await ExportImportService.findLocalIdBySourceCloudId(Constants.TABLE_DEBTS, oldId)
        }
        if (localDebtId.length === 0) {
          const matchedDebt = existingDebts.find((debt) =>
            debt.platform === platform &&
            debt.principal === principalFen &&
            debt.start_date === startDate
          )
          if (matchedDebt) {
            localDebtId = matchedDebt.id
          }
        }
        if (localDebtId.length > 0) {
          result.imported.skippedDebts += 1
          await ExportImportService.bindSourceCloudId(Constants.TABLE_DEBTS, localDebtId, oldId)
        } else {
          const input = new CreateDebtInput()
          input.platform = platform
          input.debt_type = (ExportImportService.fieldStr(d, 'debt_type', 'installment')) as DebtType
          input.principal = principalYuan
          input.current_balance = ExportImportService.fenOrYuanToYuan(ExportImportService.fieldNum(d, 'current_balance', 0))
          input.monthly_payment = ExportImportService.fenOrYuanToYuan(ExportImportService.fieldNum(d, 'monthly_payment', 0))
          input.total_periods = ExportImportService.fieldNum(d, 'total_periods', 0)
          input.remaining_periods = ExportImportService.fieldNum(d, 'remaining_periods', 0)
          input.repayment_method =
            (ExportImportService.fieldStr(d, 'repayment_method', 'equal_payment')) as RepaymentMethod
          input.total_interest = ExportImportService.fenOrYuanToYuan(ExportImportService.fieldNum(d, 'total_interest', 0))
          input.annual_rate_bp = ExportImportService.fieldNum(d, 'annual_rate_bp', 0)
          input.payment_day = ExportImportService.fieldNum(d, 'payment_day', 1)
          input.next_payment_date = ExportImportService.fieldStr(d, 'next_payment_date', Utils.todayString())
          input.start_date = startDate
          input.is_auto_payment = Boolean(d['is_auto_payment'])
          input.note = ExportImportService.fieldStr(d, 'note')
          input.credit_account_id = accountIdMap.get(ExportImportService.fieldStr(d, 'credit_account_id')) ?? ''
          input.currency = ExportImportService.fieldStr(d, 'currency', 'CNY')
          input.original_principal_fen = ExportImportService.fieldNum(d, 'original_principal_fen', 0)
          input.locked_exchange_rate = ExportImportService.fieldNum(d, 'locked_exchange_rate', 1)
          // 备份若带 icon_url / iconUrl，一并写入（否则导入后只剩字标）
          let iconUrl = ExportImportService.fieldStr(d, 'icon_url')
          if (iconUrl.length === 0) {
            iconUrl = ExportImportService.fieldStr(d, 'iconUrl')
          }
          input.icon_url = iconUrl
          AnalyticsService.setNextRecordSource('import_json')
          const created = await DebtService.createDebt(input)
          localDebtId = created.id
          existingDebts.push(created)
          result.imported.debts += 1
          await ExportImportService.bindSourceCloudId(Constants.TABLE_DEBTS, localDebtId, oldId)
        }
        if (oldId.length > 0 && localDebtId.length > 0) {
          debtIdMap.set(oldId, localDebtId)
        }
      }

      const paymentRecords = ExportImportService.arrayField(data, 'payment_records', 'paymentRecords')
      for (const r of paymentRecords) {
        const oldDebtId = ExportImportService.fieldStr(r, 'debt_id')
        const newDebtId = debtIdMap.get(oldDebtId)
        if (!newDebtId) {
          continue
        }
        const periodNumber = ExportImportService.fieldNum(r, 'period_number', 0)
        const existingPays = await PaymentService.getPaymentRecords(newDebtId)
        const payExists = existingPays.some((p) => p.period_number === periodNumber)
        if (payExists) {
          result.imported.skippedPaymentRecords += 1
          continue
        }
        const payInput = new ImportPaymentInput()
        payInput.debt_id = newDebtId
        payInput.period_number = periodNumber
        payInput.payment_date = ExportImportService.fieldStr(r, 'payment_date', Utils.todayString())
        payInput.scheduled_date = ExportImportService.fieldStr(r, 'scheduled_date')
        // 还款金额在备份中已是分，勿再 /100
        payInput.amount_paid = ExportImportService.fieldNum(r, 'amount_paid', 0)
        payInput.principal_paid = ExportImportService.fieldNum(r, 'principal_paid', 0)
        payInput.interest_paid = ExportImportService.fieldNum(r, 'interest_paid', 0)
        payInput.balance_after = ExportImportService.fieldNum(r, 'balance_after', 0)
        payInput.is_manual = r['is_manual'] === undefined ? true : Boolean(r['is_manual'])
        await PaymentService.importPaymentRecord(payInput)
        const paySourceId = ExportImportService.fieldStr(r, 'id')
        // importPaymentRecord 生成新本地 id，需从库取最近一条再绑 cloud_id
        if (paySourceId.length > 0) {
          const paysAfter = await PaymentService.getPaymentRecords(newDebtId)
          const createdPay = paysAfter.find((p) => p.period_number === periodNumber)
          if (createdPay) {
            await ExportImportService.bindSourceCloudId(Constants.TABLE_PAYMENT_RECORDS, createdPay.id, paySourceId)
          }
        }
        result.imported.paymentRecords += 1
      }

      const subscriptions = ExportImportService.arrayField(data, 'subscriptions', 'subscriptions')
      for (const s of subscriptions) {
        const name = ExportImportService.fieldStr(s, 'name')
        if (name.length === 0) {
          continue
        }
        const cycle = ExportImportService.fieldStr(s, 'billing_cycle', 'monthly')
        const oldId = ExportImportService.fieldStr(s, 'id')
        let localSubId = ''
        if (oldId.length > 0) {
          localSubId = await ExportImportService.findLocalIdBySourceCloudId(Constants.TABLE_SUBSCRIPTIONS, oldId)
        }
        if (localSubId.length === 0) {
          const matchedSub = existingSubs.find((sub) =>
            sub.name === name && sub.billing_cycle === cycle
          )
          if (matchedSub) {
            localSubId = matchedSub.id
          }
        }
        if (localSubId.length > 0) {
          result.imported.skippedSubscriptions += 1
          await ExportImportService.bindSourceCloudId(Constants.TABLE_SUBSCRIPTIONS, localSubId, oldId)
          continue
        }
        const input = new CreateSubscriptionInput()
        input.name = name
        input.category = (ExportImportService.fieldStr(s, 'category', 'other')) as SubscriptionCategory
        input.amount = ExportImportService.fenOrYuanToYuan(ExportImportService.fieldNum(s, 'amount', 0))
        input.billing_cycle = cycle as BillingCycle
        input.next_billing_date = ExportImportService.fieldStr(s, 'next_billing_date', Utils.todayString())
        input.start_date = ExportImportService.fieldStr(s, 'start_date', Utils.todayString())
        input.end_date = ExportImportService.fieldStr(s, 'end_date')
        input.credit_account_id = accountIdMap.get(ExportImportService.fieldStr(s, 'credit_account_id')) ?? ''
        input.color = ExportImportService.fieldStr(s, 'color')
        input.icon_url = ExportImportService.fieldStr(s, 'icon_url')
        input.note = ExportImportService.fieldStr(s, 'note')
        input.reminder_enabled = s['reminder_enabled'] === undefined ? true : Boolean(s['reminder_enabled'])
        input.reminder_days_before = ExportImportService.fieldNum(s, 'reminder_days_before', 3)
        input.currency = ExportImportService.fieldStr(s, 'currency', 'CNY')
        input.original_amount_fen = ExportImportService.fieldNum(s, 'original_amount_fen', 0)
        input.locked_exchange_rate = ExportImportService.fieldNum(s, 'locked_exchange_rate', 1)
        AnalyticsService.setNextRecordSource('import_json')
        const createdSub = await SubscriptionService.createSubscription(input)
        existingSubs.push(createdSub)
        result.imported.subscriptions += 1
        await ExportImportService.bindSourceCloudId(Constants.TABLE_SUBSCRIPTIONS, createdSub.id, oldId)
      }

      result.success = true
      result.message = ExportImportService.buildImportToast(result.imported)
      // 导入可能连写多表：统一清投影 + 抹落盘帧，避免 Tab 秒开/冷启动到导入前数字
      LocalDataStore.invalidateAll()
      await LocalDataStore.clearDashboardFrame()
      Constants.notifyListRefresh()
      return result
    } catch (err) {
      // ArkTS catch 类型受限，避免依赖 Error 原型
      result.message = ErrorMessages.IMPORT_FAILED
      return result
    } finally {
      if (bulkStarted) {
        // 归零后统一 schedule 一次写后同步（成功/失败都要解禁）
        SyncScheduler.endBulkWrite()
      }
    }
  }

  static async importStatementCsv(context: common.UIAbilityContext): Promise<ImportResult> {
    const result = new ImportResult()
    try {
      const documentSelectOptions = new picker.DocumentSelectOptions()
      documentSelectOptions.maxSelectNumber = 1
      documentSelectOptions.fileSuffixFilters = ['.csv']
      const documentPicker = new picker.DocumentViewPicker(context)
      const picked = await documentPicker.select(documentSelectOptions)
      if (!picked || picked.length === 0) {
        result.message = ErrorMessages.FILE_NOT_SELECTED
        return result
      }
      const uri = picked[0]
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(file.fd)
      const buf = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, buf)
      fileIo.closeSync(file)
      const decoder = new util.TextDecoder()
      let text = decoder.decodeToString(new Uint8Array(buf))
      if (text.charCodeAt(0) === 0xFEFF) {
        text = text.slice(1)
      }
      const lines = text.split(/\r?\n/).filter((l: string) => l.trim().length > 0)
      if (lines.length < 2) {
        result.message = ErrorMessages.EMPTY_CSV
        return result
      }

      const debts = await DebtService.getActiveDebtsDueBeforeOrOn('2099-12-31')
      let matched = 0
      for (let i = 1; i < lines.length; i++) {
        const cells = ExportImportService.parseCsvLine(lines[i])
        if (cells.length < 4) continue
        const counterparty = cells[0] + cells[1] + cells[2]
        const amountStr = cells[cells.length - 1] || cells[cells.length - 2]
        const amount = Number(amountStr.replace(/[^\d.]/g, ''))
        if (!amount || amount <= 0) continue
        const matchedDebt = debts.find((d) => counterparty.indexOf(d.platform) >= 0 || d.platform.indexOf(counterparty) >= 0)
        if (!matchedDebt) continue
        const periodNumber = matchedDebt.total_periods - matchedDebt.remaining_periods + 1
        await PaymentService.markPeriodPaid(matchedDebt, periodNumber)
        matched += 1
      }
      result.success = true
      result.imported.paymentRecords = matched
      result.message = '匹配并标记 ' + matched + ' 笔还款'
      if (matched > 0) {
        Constants.notifyListRefresh()
      }
      return result
    } catch (err) {
      result.message = ErrorMessages.IMPORT_FAILED
      return result
    }
  }

  private static parseCsvLine(line: string): string[] {
    const result: string[] = []
    let current = ''
    let inQuote = false
    for (let i = 0; i < line.length; i++) {
      const ch = line.charAt(i)
      if (ch === '"') {
        if (inQuote && line.charAt(i + 1) === '"') {
          current += '"'
          i++
        } else {
          inQuote = !inQuote
        }
      } else if (ch === ',' && !inQuote) {
        result.push(current)
        current = ''
      } else {
        current += ch
      }
    }
    result.push(current)
    return result
  }

  /**
   * 清空本机业务数据 +（若已登录云端）云端业务数据。
   * 本机删除失败 → localCleared=false；本机已删但云端失败 → cloudDataFailed=true。
   * 云端业务数据必须同步删除，否则重新登录时 SyncService 会把云端数据拉回。
   * 调用方据此给出诚实 Toast。幂等：本机已空时再执行仍会重试云端清除。
   */
  static async clearAllUserData(): Promise<ClearAllResult> {
    const result = new ClearAllResult()
    try {
      const userId = UserService.getCurrentUserId()
      // 先删依赖行再删主表（payment 在 debt 删除内也会清一遍，幂等）
      await PaymentService.deleteAllByUser(userId)
      await DebtService.deleteAllByUser(userId)
      await SubscriptionService.deleteAllByUser(userId)
      await CreditAccountService.deleteAllByUser(userId)
      await NotificationService.deleteAll(userId)
      // 同步元数据：避免残留队列在后续同步时误推 / 误拉
      try {
        await DbService.delete('sync_queue', 'user_id = ?', [userId])
      } catch (_q) {
      }
      try {
        await DbService.delete('sync_id_map', '1 = 1', [])
      } catch (_m) {
      }
      try {
        await DbService.delete('sync_state', 'user_id = ?', [userId])
      } catch (_s) {
      }
      result.localCleared = true
      LocalDataStore.invalidateAll()
    } catch {
      return result
    }
    // 云端业务数据：有会话则删除；否则重登同步会把数据拉回
    try {
      await SyncService.clearAllCloudData()
    } catch {
      result.cloudDataFailed = true
    }
    Constants.notifyListRefresh()
    return result
  }

  private static formatDate(): string {
    const d = new Date()
    return d.getFullYear() + '' + (d.getMonth() + 1) + '' + d.getDate() + '_' + d.getHours() + '' + d.getMinutes()
  }
}
