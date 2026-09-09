import { AppStorageKeys } from './AppStorageKeys'

export class Constants {
  static readonly DB_NAME: string = 'GoForward.db'
  /** 历史常量；库表世代以 DbService.SCHEMA_VERSION 为准（当前 5） */
  static readonly DB_VERSION: number = 1
  static readonly PREFERENCES_NAME: string = 'GoForwardPrefs'
  static readonly HUKS_KEY_ALIAS: string = 'goforward_master_key'

  /** Preferences：是否已看过首次启动引导页（仅首次启动、登录前展示一次） */
  static readonly PREF_ONBOARDING_COMPLETED: string = 'onboardingCompleted'

  /** Preferences：是否已看过 MiniBar 长短按说明（首次进入主页展示一次） */
  static readonly PREF_MINI_BAR_GUIDE_SHOWN: string = 'miniBarGuideShown'

  /** Preferences：引导完成后第一次进主页直接打开 AI 录入 */
  static readonly PREF_FIRST_RECORD_OPEN_LIVE: string = 'firstRecordOpenLive'

  /** Preferences：是否已请求过系统通知开关（只问一次；须在用户录入之后） */
  static readonly PREF_NOTIF_PROMPT_SHOWN: string = 'notifPromptShown'

  /** Preferences：上次运行的应用版本号（用于判断首次安装与版本更新） */
  static readonly PREF_LAST_RUN_VERSION: string = 'lastRunAppVersion'

  /** Preferences：用户最近已阅读更新日志的应用版本号 */
  static readonly PREF_LAST_VIEWED_VERSION: string = 'lastViewedAppVersion'

  /** Preferences：云端/远端动态拉取的最新版本信息与更新日志 JSON 缓存 */
  static readonly PREF_CACHED_RELEASE_INFO: string = 'cachedAppReleaseInfo'

  /** Preferences：防窥保护开关（设备级偏好）：系统检测到他人窥视时自动遮蔽财务信息 */
  static readonly PREF_ANTI_PEEK_ENABLED: string = 'antiPeekEnabled'

  /** 本进程刚成功录入过数据：主页据此才索取通知权限，登录进首页不弹 */
  private static pendingNotifPrompt: boolean = false

  static markPendingNotifPrompt(): void {
    Constants.pendingNotifPrompt = true
  }

  static takePendingNotifPrompt(): boolean {
    if (!Constants.pendingNotifPrompt) {
      return false
    }
    Constants.pendingNotifPrompt = false
    return true
  }

  /**
   * 主 Tab 内容底部避让总高度（底栏 56 + barBottomMargin 28 + 呼吸间距 12）。
   * HdsTabs 悬浮栏自身已避让系统底安全区（barBottomMargin 相对安全区上缘），
   * 内容侧直接用本值即可，禁止再叠加 bottomSafe（双重计算会导致底部空隙过大）。
   */
  static readonly FLOATING_TAB_CLEARANCE: number = 96

  static readonly TABLE_LOCAL_USERS: string = 'local_users'
  static readonly TABLE_USER_SETTINGS: string = 'user_settings'
  static readonly TABLE_CREDIT_ACCOUNTS: string = 'credit_accounts'
  static readonly TABLE_DEBTS: string = 'debts'
  static readonly TABLE_PAYMENT_RECORDS: string = 'payment_records'
  static readonly TABLE_SUBSCRIPTIONS: string = 'subscriptions'
  static readonly TABLE_NOTIFICATIONS: string = 'notifications'
  static readonly TABLE_ACHIEVEMENT_CARDS: string = 'achievement_cards'
  static readonly TABLE_SYNC_QUEUE: string = 'sync_queue'
  static readonly TABLE_SYNC_STATE: string = 'sync_state'

  static readonly CLOUD_ID_COLUMN: string = 'cloud_id'

  /**
   * 列表数据刷新令牌（AppStorage）
   * 表单保存 / 删除 / 还款后递增；主 Tab 监听后重新 loadData
   */
  static readonly KEY_LIST_REFRESH: string = AppStorageKeys.LIST_REFRESH_TOKEN

  /**
   * 主题变更令牌：设置里切换深浅色后递增
   * MainPage / 各 Tab 监听后重新 loadTheme，避免底栏仍用旧 primary（浅色黑字贴在深色底上）
   */
  static readonly KEY_THEME_REVISION: string = AppStorageKeys.THEME_REVISION

  /** 通知各列表页刷新（时间戳保证每次变化都能触发 @Watch） */
  static notifyListRefresh(): void {
    // 单调递增，避免同毫秒 Date.now() 撞车导致 @Watch 不触发
    const prev = AppStorage.get<number>(AppStorageKeys.LIST_REFRESH_TOKEN) ?? 0
    const next = Date.now()
    AppStorage.setOrCreate(AppStorageKeys.LIST_REFRESH_TOKEN, next > prev ? next : prev + 1)
  }

  /** 通知全应用主题色刷新 */
  static notifyThemeChange(): void {
    AppStorage.setOrCreate(AppStorageKeys.THEME_REVISION, Date.now())
  }

  /** 高利率阈值（基点）：年利率 ≥ 18% 视为高利率，用于负债卡片「高利率」标识 */
  static readonly HIGH_RATE_BP_THRESHOLD: number = 1800
}

/**
 * 固定语义色令牌（小组件 / 实况窗等无法走 ThemeColors 时使用）
 * 与 ThemeManager 一致：红 / 琥珀保留；主色为 ink foreground
 */
export class ColorTokens {
  static readonly PRIMARY: ResourceColor = '#26251E'
  static readonly AMBER: ResourceColor = '#F59E0B'
  static readonly AMBER_BG: ResourceColor = 'rgba(245,158,11,0.12)'
  static readonly RED: ResourceColor = '#CF2D56'
  static readonly RED_BG: ResourceColor = 'rgba(207,45,86,0.12)'
  static readonly DEFAULT_FALLBACK: ResourceColor = '#858379'
  /** 系统状态栏图标/文字：暗色画布 */
  static readonly STATUS_BAR_CONTENT_DARK: string = '#F2F1EF'
  /** 系统状态栏图标/文字：亮色画布 */
  static readonly STATUS_BAR_CONTENT_LIGHT: string = '#26251E'
}
