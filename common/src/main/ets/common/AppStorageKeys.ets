/**
 * 跨页 AppStorage 键名集中定义（S1 架构整改）
 * 新增全局状态时只在本文件加常量，避免魔法字符串散落。
 *
 * 读写矩阵约定：
 * - 「写」= AppStorage.setOrCreate/set；「链」= @StorageLink/@StorageProp（含字面量形式）；
 *   「读」= AppStorage.get。维护键时请同步更新本矩阵（scripts/scan-appstorage-matrix.mjs 可复扫）。
 */
export class AppStorageKeys {
  // —— 系统 / 窗口 ——
  /** 写: EntryAbility/ThemeApplier/各启动页；链+读: MainPage 及各页面主题取值 */
  static readonly SYSTEM_DARK: string = 'systemDark'
  /** 写: EntryAbility；链: 五 Tab；读: 各页安全区避让与浮层组件 */
  static readonly TOP_SAFE_HEIGHT: string = 'topSafeHeight'
  /** 写: EntryAbility；链: MainPage；读: 浮层/Sheet 底部避让 */
  static readonly BOTTOM_SAFE_HEIGHT: string = 'bottomSafeHeight'
  /** 写: MainPage 光感监听；链: MainPage；读: ThemeManager/各表单页 */
  static readonly AMBIENT_LUX: string = 'ambientLux'
  /** 应用当前 setColorMode 的值（ConfigurationConstant.ColorMode 枚举整数），
   *  写+读: EntryAbility/ThemeApplier，用于 onConfigurationUpdate 判断回调 colorMode 是否为系统真值 */
  static readonly APPLIED_COLOR_MODE: string = 'appliedColorMode'

  // —— 导航 / Tab ——
  /** 写: 各启动页/意图服务/AuthManager；链+读: MainPage（0~4 切主 Tab） */
  static readonly MAIN_TAB_INDEX: string = 'mainTabIndex'
  /** 写+链: MainPage（返回手势先退多选）；列表 Tab 内部消费 */
  static readonly LIST_SELECT_MODE: string = 'listSelectMode'

  // —— 主题 / 列表刷新 ——
  /** 写: SettingsTab 切主题后经 Constants 置数；链: MainPage 强制刷新底栏配色 */
  static readonly THEME_REVISION: string = 'themeRevision'
  /** 写: Constants（写后令牌）；链: MainPage 触发提醒刷新；各列表 Tab 自刷 */
  static readonly LIST_REFRESH_TOKEN: string = 'listRefreshToken'
  /** 个人资料变更通知（时间戳）：写 ProfilePage/AvatarCropPage；链 SettingsTab 账户卡 + DashboardTab 问候名 */
  static readonly PROFILE_REVISION: string = 'profileRevision'

  // —— 云同步状态（SyncScheduler 写入，设置页只读展示）——
  /** idle | syncing | ok | error。写: SyncScheduler；链: SettingsTab */
  static readonly SYNC_PHASE: string = 'syncPhase'
  /** 写: SyncScheduler；链: SettingsTab */
  static readonly SYNC_LAST_SUCCESS_AT: string = 'syncLastSuccessAt'
  /** 写: SyncScheduler；链: SettingsTab */
  static readonly SYNC_LAST_MESSAGE: string = 'syncLastMessage'
  /** 写: SyncScheduler；链: SettingsTab */
  static readonly SYNC_LAST_ERROR: string = 'syncLastError'
  /** 状态变更令牌：写 SyncScheduler；链 SettingsTab 页面 @Watch 刷新文案 */
  static readonly SYNC_REVISION: string = 'syncRevision'

  // —— 账号会话 ——
  /** 云会话被服务端吊销（他端改密等）：写 AuthManager/MainPage 复位；链 MainPage 踢回登录页 */
  static readonly SESSION_REVOKED_TOKEN: string = 'sessionRevokedToken'

  // —— 应用锁 ——
  /** 写: SettingsTab 开关 / AppLockPage 校验流程；链 SettingsTab */
  static readonly APP_LOCK_ENABLED: string = 'appLockEnabled'
  /** 写: EntryAbility/AppLockPage/SettingsTab */
  static readonly APP_LOCK_VERIFIED: string = 'appLockVerified'
  /** 写+读: EntryAbility（后台时长判定） */
  static readonly LAST_BACKGROUND_TIME: string = 'lastBackgroundTime'
  /** 写: AppLockPage */
  static readonly LAST_ACTIVE_TIME: string = 'lastActiveTime'
  /** 应用是否在后台：写 EntryAbility；链 MainPage；读 SyncScheduler 暂停脉冲 */
  static readonly APP_IN_BACKGROUND: string = 'appInBackground'
  /** 防窥保护脱敏态：写 AntiPeekService（系统窥视 HIDE 置位 / PASS 或关闭开关解除）；
   *  链 列表卡/汇总卡/详情弹窗等敏感文本（金额/名称/日期/分期）打码 */
  static readonly ANTI_PEEK_MASKED: string = 'antiPeekMasked'

  // —— 表单选中 / 编辑 ——
  /** 写: DebtsTab；读: DebtFormPage 编辑回填 */
  static readonly SELECTED_DEBT_ID: string = 'selectedDebtId'
  /** 写: SubscriptionsTab；读: SubscriptionFormPage */
  static readonly SELECTED_SUBSCRIPTION_ID: string = 'selectedSubscriptionId'
  /** 写: CreditAccountsTab；读: CreditAccountFormPage */
  static readonly SELECTED_CREDIT_ACCOUNT_ID: string = 'selectedCreditAccountId'
  /** 首页「查看」：切 Tab 后打开详情（勿复用表单编辑键）。写 DashboardTab/列表 Tab；读对应列表 Tab */
  static readonly OPEN_DEBT_DETAIL_ID: string = 'openDebtDetailId'
  static readonly OPEN_SUB_DETAIL_ID: string = 'openSubDetailId'
  static readonly OPEN_ACCOUNT_DETAIL_ID: string = 'openAccountDetailId'

  // —— 通知 / 设置 Sheet ——
  /** 通知未读数：写 NotificationService/NotificationsInbox；链 DashboardTab 铃铛红点 */
  static readonly NOTIFICATION_UNREAD_COUNT: string = 'notificationUnreadCount'
  /** 写: MainPage 初始化建位；链 SettingsTab 打开 AI 配置 Sheet */
  static readonly SETTINGS_OPEN_AI_SHEET: string = 'settingsOpenAISheet'
  /** 写: SettingsTab；读: MainPage（Sheet 展开期间跳过主题刷新防动画重播） */
  static readonly SETTINGS_SHEET_BLOCKING_THEME: string = 'settingsSheetBlockingTheme'
  /** AI 配置变更令牌：SettingsTab 自增；MainPage 据此触发 MiniBar 引导补播 */
  static readonly AI_CONFIG_REVISION: string = 'aiConfigRevision'

  // —— AI Live 草稿 ——
  /** 经 AILiveDraftKeys 别名使用：写 AILiveOverlay 保存流；读 DebtFormPage/SubscriptionFormPage/CreditAccountFormPage 回填后删除 */
  static readonly AI_LIVE_DEBT_DRAFT: string = 'aiLiveDebtDraft'
  static readonly AI_LIVE_SUBSCRIPTION_DRAFT: string = 'aiLiveSubscriptionDraft'
  static readonly AI_LIVE_CREDIT_ACCOUNT_DRAFT: string = 'aiLiveCreditAccountDraft'

  // —— 意图 / NFC ——
  /** 写: IntentService（goforward.add.debt）；读: MainPage 进入首页后打开负债表单 */
  static readonly INTENT_ADD_DEBT: string = 'intentAddDebt'
  /** 小艺 OpenAILive 意图：写 OpenAILiveExecutor/IntentService；读 MainPage 进入首页后打开 AI 录入 */
  static readonly INTENT_OPEN_AI_LIVE: string = 'intentOpenAILive'
  /** NFC 分享接收：写 IntentService；读 MainPage 弹窗展示并复位 */
  static readonly NFC_RECEIVED_PAYLOAD: string = 'nfcReceivedPayload'

  // —— AI Live 浮层触发 ——
  /** 写: OpenAILiveExecutor/IntentService/MainPage 复位；链 MainPage 全屏浮层 */
  static readonly SHOW_AI_LIVE: string = 'showAILive'
  /** keyboard | camera | album。写: 同上；链 MainPage */
  static readonly AI_LIVE_LAUNCH_MODE: string = 'aiLiveLaunchMode'

  // —— 全部还清仪式（MainPage 全屏层）——
  /** 是否展示「轻舟已过万重山」全清仪式。写 DebtsTab；链 MainPage+AllClearedCeremonyOverlay */
  static readonly SHOW_ALL_CLEARED_CEREMONY: string = 'showAllClearedCeremony'
  /** 累计结清笔数（仪式文案）。写 DebtsTab；链 MainPage */
  static readonly ALL_CLEARED_SETTLED_COUNT: string = 'allClearedSettledCount'

  // —— 订阅月结小票（MainPage 全屏层，需盖住悬浮底栏）——
  /** 写 SubscriptionsTab；链 MainPage */
  static readonly SHOW_RECEIPT_OVERLAY: string = 'showReceiptOverlay'
  /** 写 SubscriptionsTab；读 MainPage 传入浮层 */
  static readonly RECEIPT_MODEL: string = 'receiptModel'

  // -- 负债小票（MainPage 全屏层，需盖住悬浮底栏）--
  /** 写 DebtsTab；链 MainPage */
  static readonly SHOW_DEBT_RECEIPT_OVERLAY: string = 'showDebtReceiptOverlay'
  /** 写 DebtsTab；读 MainPage 传入浮层 */
  static readonly DEBT_RECEIPT_MODEL: string = 'debtReceiptModel'
}
