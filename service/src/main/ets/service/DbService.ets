import { relationalStore } from '@kit.ArkData'
import { Constants } from 'common'
import { Utils } from 'common'

export class DbService {
  private static rdbStore: relationalStore.RdbStore | null = null
  /**
   * 库表世代：migrateCloudIdColumns 内容变更时递增。
   * 成熟安装冷启动读到 version>=本值则跳过全部 ALTER 试错。
   */
  private static readonly SCHEMA_VERSION: number = 5
  private static readonly META_KEY_VERSION: string = 'schema_version'

  static async init(context: Context): Promise<void> {
    if (DbService.rdbStore) {
      return
    }
    const config: relationalStore.StoreConfig = {
      name: Constants.DB_NAME,
      // 债务/还款/信贷属财务数据，按数据分类分级要求使用 S3；
      // 系统仅允许安全等级升级（S1→S3 自动迁移），不允许降级
      securityLevel: relationalStore.SecurityLevel.S3,
    }
    try {
      DbService.rdbStore = await relationalStore.getRdbStore(context, config)
    } catch (e) {
      // 打开库失败属致命错误，原样上抛由启动流程处理
      throw e as Error
    }
    await DbService.createTables()
    const ver = await DbService.readSchemaVersion()
    if (ver < 1) {
      // v0→v1：历史列 ALTER 试错包
      await DbService.migrateCloudIdColumns()
    }
    if (ver < 2) {
      // v1→v2：home_snapshot 由 createTables IF NOT EXISTS 保证；仅抬版本
    }
    if (ver < 3) {
      // v2→v3：补齐 AI 配置列（此前 SCHEMA_VERSION 已到 2 会跳过 ALTER）
      await DbService.ensureUserSettingsAiColumns()
    }
    if (ver < 4) {
      // v3→v4：智感握姿总开关列（老库缺列时 SettingsService 读默认开）
      try {
        await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN hand_awareness_enabled INTEGER DEFAULT 1')
      } catch {
        // 列已存在时忽略
      }
    }
    if (ver < 5) {
      // v4→v5：列表页分享按钮总开关（默认开，与历史始终显示一致）
      try {
        await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN share_enabled INTEGER DEFAULT 1')
      } catch {
        // 列已存在时忽略
      }
    }
    if (ver < DbService.SCHEMA_VERSION) {
      await DbService.writeSchemaVersion(DbService.SCHEMA_VERSION)
    }
  }

  private static async readSchemaVersion(): Promise<number> {
    try {
      const rs = await DbService.query(
        'SELECT value FROM schema_meta WHERE key = ?',
        [DbService.META_KEY_VERSION]
      )
      let v = 0
      if (rs.goToNextRow()) {
        const raw = rs.getString(rs.getColumnIndex('value'))
        v = Number(raw) || 0
      }
      rs.close()
      return v
    } catch (_e) {
      return 0
    }
  }

  private static async writeSchemaVersion(version: number): Promise<void> {
    try {
      await DbService.executeSql(
        'DELETE FROM schema_meta WHERE key = ?',
        [DbService.META_KEY_VERSION]
      )
      await DbService.executeSql(
        'INSERT INTO schema_meta (key, value) VALUES (?, ?)',
        [DbService.META_KEY_VERSION, '' + version]
      )
    } catch (_e) {
    }
  }

  private static async migrateCloudIdColumns(): Promise<void> {
    const tables = [
      Constants.TABLE_CREDIT_ACCOUNTS,
      Constants.TABLE_DEBTS,
      Constants.TABLE_PAYMENT_RECORDS,
      Constants.TABLE_SUBSCRIPTIONS,
      Constants.TABLE_NOTIFICATIONS,
      Constants.TABLE_ACHIEVEMENT_CARDS
    ]
    for (const table of tables) {
      try {
        await DbService.executeSql('ALTER TABLE ' + table + ' ADD COLUMN cloud_id TEXT')
      } catch {
        // 列已存在或迁移失败时忽略
      }
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN theme_mode TEXT DEFAULT \'system\'')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN cloud_sync_enabled INTEGER DEFAULT 1')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN cloud_id TEXT')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE notifications ADD COLUMN subscription_id TEXT')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE credit_accounts ADD COLUMN grace_period_days INTEGER DEFAULT 0')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE credit_accounts ADD COLUMN interest_free_days INTEGER DEFAULT 0')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE subscriptions ADD COLUMN end_date TEXT')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN ai_text_api_format TEXT DEFAULT \'auto\'')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN ai_vision_api_format TEXT DEFAULT \'auto\'')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN ai_voice_api_format TEXT DEFAULT \'auto\'')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    await DbService.ensureUserSettingsAiColumns()
    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN ai_voice_test_fp TEXT DEFAULT \'\'')
    } catch {
    }

    try {
      await DbService.executeSql('ALTER TABLE debts ADD COLUMN icon_url TEXT')
    } catch {
      // 列已存在或迁移失败时忽略
    }

    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN monthly_budget_limit INTEGER DEFAULT 0')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN pressure_alert_enabled INTEGER DEFAULT 1')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN ai_insight_push_enabled INTEGER DEFAULT 0')
    } catch {
    }
    try {
      // 创始会员编号：0 = 未分配，未来会员/支付系统按购买顺序写入
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN founding_member_no INTEGER DEFAULT 0')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN profile_nickname TEXT DEFAULT \'\'')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN profile_signature TEXT DEFAULT \'\'')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE user_settings ADD COLUMN profile_avatar_path TEXT DEFAULT \'\'')
    } catch {
    }

    // 多币种支持：负债表
    try {
      await DbService.executeSql('ALTER TABLE debts ADD COLUMN currency TEXT DEFAULT \'CNY\'')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE debts ADD COLUMN original_principal_fen INTEGER DEFAULT 0')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE debts ADD COLUMN locked_exchange_rate REAL DEFAULT 1.0')
    } catch {
    }

    // 多币种支持：订阅表
    try {
      await DbService.executeSql('ALTER TABLE subscriptions ADD COLUMN currency TEXT DEFAULT \'CNY\'')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE subscriptions ADD COLUMN original_amount_fen INTEGER DEFAULT 0')
    } catch {
    }
    try {
      await DbService.executeSql('ALTER TABLE subscriptions ADD COLUMN locked_exchange_rate REAL DEFAULT 1.0')
    } catch {
    }
  }

  static async close(): Promise<void> {
    if (DbService.rdbStore) {
      try {
        await DbService.rdbStore.close()
      } catch (_e) {
      }
      DbService.rdbStore = null
    }
  }

  /** 补齐 AI 渠道列；列已存在时 ALTER 失败可忽略 */
  static async ensureUserSettingsAiColumns(): Promise<void> {
    const alters: string[] = [
      'ALTER TABLE user_settings ADD COLUMN ai_text_api_format TEXT DEFAULT \'auto\'',
      'ALTER TABLE user_settings ADD COLUMN ai_vision_api_format TEXT DEFAULT \'auto\'',
      'ALTER TABLE user_settings ADD COLUMN ai_text_test_fp TEXT DEFAULT \'\'',
      'ALTER TABLE user_settings ADD COLUMN ai_vision_test_fp TEXT DEFAULT \'\''
    ]
    for (let i = 0; i < alters.length; i++) {
      try {
        await DbService.executeSql(alters[i])
      } catch (_e) {
      }
    }
  }

  /** Splash 初始化完成前为 false；供 SyncScheduler 等后台任务短路 */
  static isReady(): boolean {
    return DbService.rdbStore !== null
  }

  private static getStore(): relationalStore.RdbStore {
    if (!DbService.rdbStore) {
      throw new Error('RdbStore not initialized')
    }
    return DbService.rdbStore
  }

  private static async createTables(): Promise<void> {
    DbService.getStore()

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS schema_meta (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS local_users (
        id TEXT PRIMARY KEY,
        email TEXT,
        password_hash TEXT,
        recovery_key_encrypted TEXT,
        created_at TEXT,
        updated_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS user_settings (
        user_id TEXT PRIMARY KEY,
        app_lock_enabled INTEGER DEFAULT 0,
        app_lock_hash TEXT,
        email_reminders INTEGER DEFAULT 0,
        remind_before_due INTEGER DEFAULT 1,
        remind_on_due_day INTEGER DEFAULT 1,
        monthly_review_push INTEGER DEFAULT 1,
        app_lock_timeout_mins INTEGER DEFAULT 5,
        ai_text_enabled INTEGER DEFAULT 0,
        ai_text_key TEXT,
        ai_text_base_url TEXT,
        ai_text_model TEXT,
        ai_text_api_format TEXT DEFAULT 'auto',
        ai_vision_enabled INTEGER DEFAULT 0,
        ai_vision_key TEXT,
        ai_vision_base_url TEXT,
        ai_vision_model TEXT,
        ai_vision_api_format TEXT DEFAULT 'auto',
        key_backup_encrypted TEXT,
        recovery_backup_encrypted TEXT,
        light_sense_enabled INTEGER DEFAULT 0,
        eye_care_enabled INTEGER DEFAULT 0,
        hand_awareness_enabled INTEGER DEFAULT 1,
        share_enabled INTEGER DEFAULT 1,
        theme_mode TEXT DEFAULT 'system',
        cloud_sync_enabled INTEGER DEFAULT 1,
        updated_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS credit_accounts (
        id TEXT PRIMARY KEY,
        cloud_id TEXT,
        user_id TEXT,
        name TEXT,
        last_four TEXT,
        color TEXT,
        icon_url TEXT,
        expiry_date TEXT,
        cvv TEXT,
        bill_day INTEGER,
        payment_day INTEGER,
        annual_fee_required_swipes INTEGER,
        annual_fee_manual_swipes INTEGER,
        credit_limit REAL,
        grace_period_days INTEGER DEFAULT 0,
        interest_free_days INTEGER DEFAULT 0,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT,
        updated_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS debts (
        id TEXT PRIMARY KEY,
        cloud_id TEXT,
        user_id TEXT,
        platform TEXT,
        platform_color TEXT,
        debt_type TEXT,
        principal INTEGER,
        current_balance INTEGER,
        monthly_payment INTEGER,
        total_periods INTEGER,
        remaining_periods INTEGER,
        repayment_method TEXT,
        total_interest INTEGER,
        annual_rate_bp INTEGER,
        payment_day INTEGER,
        next_payment_date TEXT,
        start_date TEXT,
        estimated_end_date TEXT,
        is_auto_payment INTEGER DEFAULT 0,
        status TEXT,
        note TEXT,
        credit_account_id TEXT,
        created_at TEXT,
        updated_at TEXT,
        icon_url TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS payment_records (
        id TEXT PRIMARY KEY,
        cloud_id TEXT,
        debt_id TEXT,
        user_id TEXT,
        period_number INTEGER,
        payment_date TEXT,
        scheduled_date TEXT,
        amount_paid INTEGER,
        principal_paid INTEGER,
        interest_paid INTEGER,
        balance_after INTEGER,
        is_manual INTEGER DEFAULT 1,
        created_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS subscriptions (
        id TEXT PRIMARY KEY,
        cloud_id TEXT,
        user_id TEXT,
        name TEXT,
        category TEXT,
        amount INTEGER,
        billing_cycle TEXT,
        next_billing_date TEXT,
        start_date TEXT,
        end_date TEXT,
        status TEXT,
        credit_account_id TEXT,
        color TEXT,
        icon_url TEXT,
        note TEXT,
        reminder_days_before INTEGER DEFAULT 3,
        reminder_enabled INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS notifications (
        id TEXT PRIMARY KEY,
        cloud_id TEXT,
        user_id TEXT,
        debt_id TEXT,
        subscription_id TEXT,
        reminder_type TEXT,
        title TEXT,
        body TEXT,
        is_read INTEGER DEFAULT 0,
        sent_at TEXT,
        read_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS achievement_cards (
        id TEXT PRIMARY KEY,
        cloud_id TEXT,
        user_id TEXT,
        debt_id TEXT,
        platform TEXT,
        total_paid INTEGER,
        total_interest INTEGER,
        duration_days INTEGER,
        completed_at TEXT,
        card_data TEXT,
        created_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS sync_queue (
        id TEXT PRIMARY KEY,
        user_id TEXT,
        table_name TEXT,
        record_id TEXT,
        operation TEXT,
        payload TEXT,
        created_at INTEGER,
        retry_count INTEGER DEFAULT 0
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS sync_state (
        table_name TEXT PRIMARY KEY,
        user_id TEXT,
        last_sync_at TEXT
      )
    `)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS sync_id_map (
        table_name TEXT NOT NULL,
        local_id TEXT NOT NULL,
        cloud_id TEXT NOT NULL,
        synced_at TEXT,
        PRIMARY KEY (table_name, local_id)
      )
    `)

    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_sync_map_cloud ON sync_id_map(table_name, cloud_id)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_debts_user ON debts(user_id)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_debts_status_date ON debts(user_id, status, next_payment_date)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_debts_next_date ON debts(next_payment_date)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_payments_debt ON payment_records(debt_id)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_payments_user_date ON payment_records(user_id, payment_date)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_subscriptions_user ON subscriptions(user_id)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_subscriptions_user_status ON subscriptions(user_id, status)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_credit_accounts_user ON credit_accounts(user_id)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_notifications_user ON notifications(user_id)`)
    await DbService.executeSql(`CREATE INDEX IF NOT EXISTS idx_achievement_user ON achievement_cards(user_id)`)

    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS budget_categories (
        id TEXT PRIMARY KEY,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        color TEXT,
        sort_order INTEGER DEFAULT 0,
        is_system INTEGER DEFAULT 0,
        is_enabled INTEGER DEFAULT 1,
        created_at TEXT,
        updated_at TEXT
      )
    `)
    await DbService.executeSql(
      'CREATE INDEX IF NOT EXISTS idx_budget_categories_user ON budget_categories(user_id)'
    )

    // v2：首页物化快照（冷启动只读 1 行）
    await DbService.executeSql(`
      CREATE TABLE IF NOT EXISTS home_snapshot (
        user_id TEXT PRIMARY KEY,
        payload TEXT NOT NULL,
        updated_at TEXT
      )
    `)
  }

  static async executeSql(sql: string, bindArgs?: Array<string | number | boolean>): Promise<void> {
    const store = DbService.getStore()
    // 系统 API 标记可抛错，编译器要求 try 包裹；捕获后原样上抛，错误语义不变（下同）
    try {
      await store.executeSql(sql, bindArgs)
    } catch (e) {
      throw e as Error
    }
  }

  static async query(
    sql: string,
    bindArgs?: Array<string | number | boolean>
  ): Promise<relationalStore.ResultSet> {
    const store = DbService.getStore()
    try {
      // 透传 ResultSet 给调用方，由调用方负责 close（各 Service 用完即关），此处不关闭为规则误报
      // eslint-disable-next-line @performance/datashare-query-unrelease-check
      return await store.querySql(sql, bindArgs)
    } catch (e) {
      throw e as Error
    }
  }

  static async insert(table: string, values: Map<string, string | number | boolean>): Promise<number> {
    const store = DbService.getStore()
    const row: relationalStore.ValuesBucket = {}
    const keys = values.keys()
    for (const key of keys) {
      const v = values.get(key)
      if (v !== undefined) {
        row[key] = v
      }
    }
    try {
      return await store.insert(table, row)
    } catch (e) {
      throw e as Error
    }
  }

  static async update(
    table: string,
    values: Map<string, string | number | boolean>,
    whereClause: string,
    whereArgs: Array<string | number | boolean>
  ): Promise<number> {
    const store = DbService.getStore()
    const sets: string[] = []
    const args: Array<string | number | boolean> = []
    const keys = values.keys()
    for (const key of keys) {
      const v = values.get(key)
      if (v !== undefined) {
        sets.push(key + ' = ?')
        args.push(v)
      }
    }
    for (const arg of whereArgs) {
      args.push(arg)
    }
    const sql = 'UPDATE ' + table + ' SET ' + sets.join(', ') + ' WHERE ' + whereClause
    try {
      await store.executeSql(sql, args)
    } catch (e) {
      throw e as Error
    }
    return 1
  }

  static async delete(
    table: string,
    whereClause: string,
    whereArgs: Array<string | number | boolean>
  ): Promise<number> {
    const store = DbService.getStore()
    const sql = 'DELETE FROM ' + table + ' WHERE ' + whereClause
    try {
      await store.executeSql(sql, whereArgs)
    } catch (e) {
      throw e as Error
    }
    return 1
  }

  static boolToInt(b: boolean): number {
    return b ? 1 : 0
  }

  static intToBool(n: number): boolean {
    return Number(n) === 1
  }

  static now(): string {
    return new Date().toISOString()
  }
}
