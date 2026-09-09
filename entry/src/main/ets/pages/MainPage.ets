import { LengthMetrics } from '@kit.ArkUI'
import { DashboardTab } from './DashboardTab'
import { DebtsTab } from './DebtsTab'
import { SubscriptionsTab } from './SubscriptionsTab'
import { CreditAccountsTab } from './CreditAccountsTab'
import { SettingsTab } from './SettingsTab'
import { LiveViewService } from 'service'
import { fetchEffectiveTheme } from './common/ThemeLoader'
import { WidgetUpdateService } from 'service'
import { ReminderService } from 'service'
import { NFCShareService, NFCSharePayload } from 'service'
import { SyncScheduler } from 'service'
import { SyncRealtime } from 'service'
import { AuthManager } from 'service'
import { PreferencesService } from 'service'
import { AnalyticsService } from 'service'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { AppStorageKeys } from 'common'
import { Constants } from 'common'
import { SettingsService } from 'service'
import { AIParseOrchestrator } from 'service'
import { UserService } from 'service'
import { LightReading, LightSensorService } from 'service'
import { ReceiptModel } from 'service'
import { DebtReceiptModel, AccountReceiptModel } from 'service'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton } from 'components'
import lazy { AILiveOverlay } from '../components/AILiveOverlay'
import { AllClearedCeremonyOverlay } from 'components'
import { MiniBarGuideOverlay } from 'components'
import { ReceiptSlipOverlay, ReceiptSlipModel } from 'components'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import {
  HdsTabs,
  HdsTabsController,
  HdsBarStyle
} from '@kit.UIDesignKit'
import { ImmersiveTitleBar } from 'common'
import { AppRouter, RouteNames } from 'common'
import { common } from '@kit.AbilityKit'

/**
 * 底部悬浮导航 —— 官方文档直译
 *
 * https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-spatiality-immersive
 * https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-smart-reach
 *
 * - AdaptiveTabView：BottomTabBarStyle + miniBar + IMMERSIVE 沉浸光感
 * - SmartReach：adaptToHandedness = true
 */

@Component
export struct MainPage {
  @State selectedIndex: number = 0
  @State theme: ThemeColors = ThemeManager.DARK
  /** 与官方 isMiniBar 一致：true = 折叠，false = 展开 */
  @State isMiniBarCollapsed: boolean = true
  @State showSheet: boolean = false
  @State showAILive: boolean = false
  /** 全部还清仪式：DebtsTab 写入 AppStorage，本页全屏盖住底栏 */
  @StorageLink('showAllClearedCeremony') showAllClearedCeremony: boolean = false
  @StorageLink('allClearedSettledCount') allClearedSettledCount: number = 0
  /** 订阅月结小票：SubscriptionsTab 写入 AppStorage，本页全屏盖住底栏 */
  @StorageLink('showReceiptOverlay') showReceiptOverlay: boolean = false
  /** 负债小票：DebtsTab 写入 AppStorage，本页全屏盖住底栏 */
  @StorageLink('showDebtReceiptOverlay') showDebtReceiptOverlay: boolean = false
  /** 账户小票：CreditAccountsTab 写入 AppStorage，本页全屏盖住底栏 */
  @StorageLink('showAccountReceiptOverlay') showAccountReceiptOverlay: boolean = false
  /** keyboard | camera | album —— 打开 AI Live 时的入口（系统听写在 Live 胶囊条内） */
  @State aiLaunchMode: string = 'keyboard'
  @State sheetConfig: SheetDialogConfig = new SheetDialogConfig()
  /** 首次进入主页：MiniBar 长短按说明（仅展示一次，关闭后持久化） */
  @State @Watch('onMiniBarGuideChange') showMiniBarGuide: boolean = false
  @StorageLink(AppStorageKeys.AI_CONFIG_REVISION) @Watch('onAiConfigRevision') aiConfigRevision: number = 0
  @StorageLink('listRefreshToken') @Watch('onListRefreshForReminder') listRefreshForReminder: number = 0
  private sheetCallback: (index: number) => void = () => {}
  @StorageLink('ambientLux') @Watch('onLuxChange') lux: number = -1
  @StorageLink('systemDark') @Watch('onLuxChange') systemDark: boolean = false
  /** 设置里切换主题后刷新底栏/图标色 */
  @StorageLink('themeRevision') @Watch('onThemeRevision') themeRevision: number = 0
  /** 首页卡片等请求切换主 Tab：0~5 */
  @StorageLink('mainTabIndex') @Watch('onMainTabRequest') mainTabIndex: number = 0
  /** 列表 Tab 批量选择态：返回手势先退多选，不退出应用 */
  @StorageLink('listSelectMode') listSelectMode: boolean = false
  @StorageProp(AppStorageKeys.BOTTOM_SAFE_HEIGHT) bottomSafe: number = 0
  private controller: HdsTabsController = new HdsTabsController()
  private tabsPreloaded: boolean = false
  /** 首帧后切 Tab 的延时句柄，销毁时清理 */
  private tabSwitchTimer: number = -1
  /** MiniBar 引导首启延时句柄，销毁时清理 */
  private guideLaunchTimer: number = -1
  /** 进主页延后副作用句柄（sync/widget/preload 等） */
  private deferredTimers: number[] = []
  /** Dashboard AI 快捷条触发标记 */
  @StorageLink('showAILive') @Watch('onAILiveRequest') showAILiveRequest: boolean = false
  @StorageLink('aiLiveLaunchMode') aiLiveLaunchModeStorage: string = 'keyboard'
  /** 云会话被服务端吊销（他端改密等）：踢回登录页 */
  @StorageLink('sessionRevokedToken') @Watch('onSessionRevoked') sessionRevokedToken: number = 0
  /** 回前台时重新校验会话有效性 */
  @StorageLink('appInBackground') @Watch('onBackgroundChange') appInBackground: boolean = false
  /** 光感监听需稳定引用，便于 start/stop 配对 */
  private readonly lightListener: (reading: LightReading) => void = (reading: LightReading): void => {
    // 传感器侧已节流；此处再挡一次极小抖动
    const prev = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX)
    if (prev === undefined || Math.abs(prev - reading.lux) >= 15) {
      AppStorage.setOrCreate(AppStorageKeys.AMBIENT_LUX, reading.lux)
    }
  }

  aboutToAppear() {
    // 保留卡片/深链已写入的 Tab，勿无条件冲成 0
    const pendingTab = AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX)
    if (pendingTab === undefined) {
      AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 0)
    }
    if (AppStorage.get<boolean>(AppStorageKeys.LIST_SELECT_MODE) === undefined) {
      AppStorage.setOrCreate(AppStorageKeys.LIST_SELECT_MODE, false)
    }
    AppStorage.setOrCreate(AppStorageKeys.THEME_REVISION,
      AppStorage.get<number>(AppStorageKeys.THEME_REVISION) ?? 0)
    AppStorage.setOrCreate(AppStorageKeys.SETTINGS_OPEN_AI_SHEET, false)
    // 全清仪式键：缺省时建位，勿强行清掉已触发状态
    if (AppStorage.get<boolean>(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY) === undefined) {
      AppStorage.setOrCreate(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY, false)
    }
    if (AppStorage.get<number>(AppStorageKeys.ALL_CLEARED_SETTLED_COUNT) === undefined) {
      AppStorage.setOrCreate(AppStorageKeys.ALL_CLEARED_SETTLED_COUNT, 0)
    }
    // 小艺 OpenAILive 等意图可能已置位，勿无条件清空
    const openFromIntent = AppStorage.get<boolean>(AppStorageKeys.INTENT_OPEN_AI_LIVE) === true
      || AppStorage.get<boolean>(AppStorageKeys.SHOW_AI_LIVE) === true
    const launchMode = AppStorage.get<string>(AppStorageKeys.AI_LIVE_LAUNCH_MODE) || 'keyboard'
    if (!openFromIntent) {
      AppStorage.setOrCreate(AppStorageKeys.SHOW_AI_LIVE, false)
      AppStorage.setOrCreate(AppStorageKeys.AI_LIVE_LAUNCH_MODE, 'keyboard')
    }
    // 首帧：主题尽量同步窥视缓存；同步等首页 hydrate；其它副作用再分阶段
    SyncScheduler.resetHomeHydrated()
    this.applyThemeFromCacheOrLoad()
    this.handleNFCReceive()
    if (this.sessionRevokedToken > 0) {
      this.onSessionRevoked()
    }
    if (openFromIntent) {
      this.consumeOpenAILiveIntent(launchMode)
    }
    if (AppStorage.get<boolean>(AppStorageKeys.INTENT_ADD_DEBT) === true) {
      AppStorage.setOrCreate(AppStorageKeys.INTENT_ADD_DEBT, false)
      this.deferWork(200, () => {
        AppRouter.push(RouteNames.DEBT_FORM)
      })
    }
    const targetTab = AppStorage.get<number>(AppStorageKeys.MAIN_TAB_INDEX) ?? 0
    if (targetTab > 0 && targetTab <= 4) {
      this.selectedIndex = targetTab
      this.tabSwitchTimer = setTimeout(() => {
        this.tabSwitchTimer = -1
        this.onMainTabRequest()
      }, 80)
    } else {
      this.selectedIndex = 0
      AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 0)
      this.trackTabView(0)
    }

    this.schedulePostMainWarmup()

    if (!openFromIntent) {
      this.launchFirstRecordOrGuide()
    }
  }

  private async launchFirstRecordOrGuide(): Promise<void> {
    try {
      const firstRecord = await PreferencesService.getBool(Constants.PREF_FIRST_RECORD_OPEN_LIVE, false)
      if (firstRecord) {
        // 第一笔优先：不先盖两步说明，直接打开录入
        this.openFirstRecordLive()
        return
      }
      const shown = await PreferencesService.getBool(Constants.PREF_MINI_BAR_GUIDE_SHOWN, false)
      if (shown) {
        return
      }
      if (!await this.isAiConfigured()) {
        return
      }
      this.guideLaunchTimer = setTimeout(() => {
        this.guideLaunchTimer = -1
        this.showMiniBarGuide = true
      }, 1200)
    } catch (_e) {
    }
  }

  /** AI 已配置 = 文字或图片任一渠道已填 key（与 Live/Chat 门槛一致） */
  private async isAiConfigured(): Promise<boolean> {
    try {
      const uid = UserService.getCurrentUserId()
      const cached = SettingsService.peekCache(uid)
      const settings = cached !== null ? cached : await SettingsService.getSettings(uid)
      return AIParseOrchestrator.canParseText(settings)
    } catch (_e) {
      return false
    }
  }

  /** 折叠 MiniBar 点按：已配置 AI → 智能录入；未配置 → 展开手动新增菜单 */
  private handleMiniBarTap(): void {
    this.isAiConfigured().then((configured: boolean) => {
      if (configured) {
        this.openAiLive('keyboard')
      } else {
        this.expandMiniBar()
      }
    })
  }

  /** AI 配置变更令牌 @Watch 入口（保持同步签名） */
  private onAiConfigRevision(): void {
    this.maybeShowGuideAfterAiConfigured()
  }

  /** AI 配置完成后（设置页关闭 AI 配置 Sheet）：补播 MiniBar 引导（仅一次） */
  private async maybeShowGuideAfterAiConfigured(): Promise<void> {
    if (this.aiConfigRevision <= 0 || this.showMiniBarGuide || this.guideLaunchTimer !== -1) {
      return
    }
    if (this.showAILive || this.showAllClearedCeremony) {
      return
    }
    try {
      const shown = await PreferencesService.getBool(Constants.PREF_MINI_BAR_GUIDE_SHOWN, false)
      if (shown) {
        return
      }
      if (!await this.isAiConfigured()) {
        return
      }
      this.showMiniBarGuide = true
    } catch (_e) {
    }
  }

  private onMiniBarGuideChange(): void {
    if (this.showMiniBarGuide) {
      return
    }
    this.maybeOpenFirstRecordAfterGuide()
  }

  private async maybeOpenFirstRecordAfterGuide(): Promise<void> {
    try {
      const firstRecord = await PreferencesService.getBool(Constants.PREF_FIRST_RECORD_OPEN_LIVE, false)
      if (firstRecord) {
        this.openFirstRecordLive()
      }
    } catch (_e) {
    }
  }

  private openFirstRecordLive(): void {
    PreferencesService.putBool(Constants.PREF_FIRST_RECORD_OPEN_LIVE, false).catch(() => {
    })
    this.openAiLive('keyboard')
  }

  private onListRefreshForReminder(): void {
    if (Constants.takePendingNotifPrompt()) {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (ctx) {
        ReminderService.ensureNotificationEnabled(ctx)
      }
    }
    ReminderService.scheduleRefresh()
  }

  /** 有 Settings 缓存则同步上色（零 await）；无缓存再异步读库 */
  private applyThemeFromCacheOrLoad(): void {
    const uid = UserService.getCurrentUserId()
    const cached = SettingsService.peekCache(uid)
    if (cached !== null) {
      const next = ThemeManager.currentTheme(cached, this.systemDark, this.lux)
      if (!ThemeManager.isSame(this.theme, next)) {
        this.theme = next
      }
      return
    }
    this.loadTheme(false)
  }

  /**
   * 进主页副作用分阶段：
   * - 同步：等 Dashboard markHomeHydrated
   * - 光感：仅 light_sense_enabled
   * - pulse：首 30s 宽限（SyncScheduler）
   */
  private schedulePostMainWarmup(): void {
    this.deferWork(80, () => {
      LiveViewService.refresh()
    })
    this.deferWork(150, () => {
      this.startLightSensorIfEnabled()
    })
    // 不立即 scheduleEnterMain：由 loadHome 完成后 markHomeHydrated 放行；此处仅登记等待
    SyncScheduler.scheduleEnterMainWhenHomeReady()
    this.deferWork(500, () => {
      SyncScheduler.startForegroundPulse()
    })
    this.deferWork(800, () => {
      SyncRealtime.start()
      AuthManager.validateCloudSession()
    })
    this.deferWork(1200, () => {
      const ctx = this.getUIContext().getHostContext() as Context
      if (ctx) {
        WidgetUpdateService.updateAll(ctx)
      }
    })
    this.deferWork(1600, () => {
      ReminderService.checkAndGenerateDueReminders().catch(() => {
      })
      ReminderService.scheduleDailyReminder()
    })
  }

  private startLightSensorIfEnabled(): void {
    const uid = UserService.getCurrentUserId()
    const cached = SettingsService.peekCache(uid)
    if (cached !== null) {
      if (cached.light_sense_enabled) {
        LightSensorService.start(this.lightListener)
      }
      return
    }
    SettingsService.getSettings(uid).then((s) => {
      if (s.light_sense_enabled) {
        LightSensorService.start(this.lightListener)
      }
    }).catch(() => {
    })
  }

  private deferWork(delayMs: number, fn: () => void): void {
    const id = setTimeout(() => {
      this.deferredTimers = this.deferredTimers.filter((t: number) => t !== id)
      fn()
    }, delayMs) as number
    this.deferredTimers.push(id)
  }

  /** 小艺「用向前录入」等意图：进入首页后打开 AI Live */
  private consumeOpenAILiveIntent(launchMode: string): void {
    this.openAiLive(launchMode.length > 0 ? launchMode : 'intent')
    AppStorage.setOrCreate(AppStorageKeys.INTENT_OPEN_AI_LIVE, false)
    AppStorage.setOrCreate(AppStorageKeys.SHOW_AI_LIVE, false)
  }

  private onMainTabRequest(): void {
    const idx = this.mainTabIndex
    if (idx < 0 || idx > 4) {
      return
    }
    if (idx === this.selectedIndex) {
      return
    }
    try {
      this.controller.changeIndex(idx)
      this.selectedIndex = idx
      this.trackTabView(idx)
    } catch (_err) {
      // changeIndex 不可用时忽略
    }
  }

  /** Dashboard AI 快捷条通过 AppStorage 触发 AI Live 浮层 */
  private onAILiveRequest(): void {
    if (!this.showAILiveRequest) {
      return
    }
    const mode = this.aiLiveLaunchModeStorage || 'keyboard'
    this.openAiLive(mode)
    // 重置标记，避免重复触发
    AppStorage.setOrCreate(AppStorageKeys.SHOW_AI_LIVE, false)
  }

  private openAiLive(mode: string): void {
    this.aiLaunchMode = mode
    AnalyticsService.setNextAiLaunch(mode)
    AnalyticsService.trackAiLiveOpen()
    this.showAILive = true
  }

  private trackTabView(index: number): void {
    const names: string[] = ['home', 'debts', 'subs', 'accounts', 'settings']
    if (index >= 0 && index < names.length) {
      AnalyticsService.trackTabView(names[index])
    }
  }

  private handlePageShown(): void {
    // 仅预热相邻 Tab，不全量 1–4（降低内存与主线程）
    if (!this.tabsPreloaded) {
      this.deferWork(1500, () => {
        try {
          if (!this.tabsPreloaded) {
            const cur = this.selectedIndex
            const ids: number[] = []
            if (cur - 1 >= 0) {
              ids.push(cur - 1)
            }
            if (cur + 1 <= 4) {
              ids.push(cur + 1)
            }
            if (ids.length > 0) {
              this.controller.preloadItems(ids)
            }
            this.tabsPreloaded = true
          }
        } catch (_err) {
        }
      })
    }
  }

  aboutToDisappear() {
    LightSensorService.stop(this.lightListener)
    SyncScheduler.resetHomeHydrated()
    if (this.tabSwitchTimer !== -1) {
      clearTimeout(this.tabSwitchTimer)
      this.tabSwitchTimer = -1
    }
    if (this.guideLaunchTimer !== -1) {
      clearTimeout(this.guideLaunchTimer)
      this.guideLaunchTimer = -1
    }
    for (let i = 0; i < this.deferredTimers.length; i++) {
      clearTimeout(this.deferredTimers[i])
    }
    this.deferredTimers = []
  }

  private onLuxChange(): void {
    // 光感变化不要用 animateTo，高频动画会卡死交互
    this.loadTheme(false)
  }

  private onThemeRevision(): void {
    // 强制刷新：主题切换时常在设置 Sheet 关闭过程中，不能被 blocking 跳过
    this.loadTheme(false, true)
  }

  /** 云会话被吊销：提示并清栈回登录页 */
  private onSessionRevoked(): void {
    if (this.sessionRevokedToken <= 0) {
      return
    }
    AppStorage.setOrCreate(AppStorageKeys.SESSION_REVOKED_TOKEN, 0)
    AppToast.show(ErrorMessages.SESSION_REVOKED, 3000)
    AppRouter.resetTo(RouteNames.LOGIN)
  }

  private onBackgroundChange(): void {
    if (!this.appInBackground) {
      AuthManager.validateCloudSession()
    }
  }

  private async loadTheme(_animate: boolean = false, force: boolean = false): Promise<void> {
    // 半模态打开时避免父树重建，否则子 Tab 的 bindSheet 会重播弹出动画
    if (!force && this.shouldSkipThemeRefresh()) {
      return
    }
    const next = await fetchEffectiveTheme(this.lux, this.systemDark)
    // await 后可能已打开半模态，再检查一次（强制刷新主题时不跳过）
    if (!force && this.shouldSkipThemeRefresh()) {
      return
    }
    // 光感高频回调若每次 new ThemeColors 都会整树重建，子 Tab 的 bindSheet 会反复弹出
    if (!force && ThemeManager.isSame(this.theme, next)) {
      return
    }
    this.theme = next
  }

  private shouldSkipThemeRefresh(): boolean {
    return this.showSheet || this.showAILive ||
      AppStorage.get<boolean>(AppStorageKeys.SETTINGS_SHEET_BLOCKING_THEME) === true
  }

  private handleNFCReceive(): void {
    const payload = AppStorage.get<NFCSharePayload>(AppStorageKeys.NFC_RECEIVED_PAYLOAD)
    if (payload) {
      AppStorage.setOrCreate(AppStorageKeys.NFC_RECEIVED_PAYLOAD, null)
      const title = payload.type === 'debt' ? '收到负债分享' : '收到账户分享'
      const message = payload.type === 'debt'
        ? payload.platform + '\n剩余待还: ' + (payload.currentBalanceFen / 100).toFixed(2) + ' 元\n月供: ' +
          (payload.monthlyPaymentFen / 100).toFixed(2) + ' 元'
        : payload.accountName + ' 尾号' + payload.accountLastFour
      const config = new SheetDialogConfig(title, message, [
        new SheetDialogButton('关闭', this.theme.text, 'default')
      ])
      this.openSheet(config, () => {})
    }
  }

  private openSheet(config: SheetDialogConfig, callback: (index: number) => void): void {
    this.sheetConfig = config
    this.sheetCallback = callback
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showSheet = true
    })
  }

  private onAddSelect(action: string): void {
    this.collapseMiniBar()
    if (action === 'debt') {
      AppRouter.push(RouteNames.DEBT_FORM)
    } else if (action === 'subscription') {
      AppRouter.push(RouteNames.SUBSCRIPTION_FORM)
    } else if (action === 'creditAccount') {
      AppRouter.push(RouteNames.CREDIT_ACCOUNT_FORM)
    } else if (action === 'ai_text') {
      this.openAiLive('keyboard')
    } else if (action === 'ai_camera') {
      this.openAiLive('camera')
    } else if (action === 'ai_album') {
      this.openAiLive('album')
    }
  }

  private collapseMiniBar(): void {
    try {
      this.controller.applyMiniBarStyle(HdsBarStyle.COLLAPSE)
    } catch (_e) {
    }
  }

  private expandMiniBar(): void {
    try {
      this.controller.applyMiniBarStyle(HdsBarStyle.EXPAND)
      // 同步本地态，避免 onBarStyleChange 未回调时 UI 仍显示折叠
      this.isMiniBarCollapsed = false
    } catch (_e) {
      this.isMiniBarCollapsed = false
    }
  }

  /** Live / 全清仪式打开时拦截返回，避免误退出 Ability */
  private handleBackPress(): boolean {
    if (this.showMiniBarGuide) {
      this.showMiniBarGuide = false
      return true
    }
    if (this.showAllClearedCeremony) {
      this.showAllClearedCeremony = false
      AppStorage.setOrCreate(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY, false)
      return true
    }
    if (this.showReceiptOverlay) {
      this.showReceiptOverlay = false
      return true
    }
    if (this.showDebtReceiptOverlay) {
      this.showDebtReceiptOverlay = false
      return true
    }
    if (this.showAccountReceiptOverlay) {
      this.showAccountReceiptOverlay = false
      return true
    }
    if (this.showAILive) {
      this.showAILive = false
      return true
    }
    if (this.listSelectMode) {
      this.listSelectMode = false
      return true
    }
    return AppRouter.handleRootBack(this.getUIContext())
  }

  /** 悬浮底栏距安全区上缘 28（HdsTabs 自身已避让系统安全区，勿再叠加 bottomSafe） */
  private getBarBottomMargin(): number {
    return 28
  }

  private miniBarFg(): string {
    // Mini 背景是跟随页签栏的光感材质（浅色下为浅底），前景统一用正文色，勿用 onPrimary
    return `${this.theme.text}`
  }

  /**
   * 折叠：AI 星芒（点按智能录入 / 长按展开）
   * 展开：新增负债 | 新增订阅 | 新增账户
   * 系统听写不在 MiniBar 单独占项，在 AI Live 胶囊条内调起
   */
  @Builder
  miniBarBuilder() {
    if (this.isMiniBarCollapsed) {
      // 折叠 MiniBar：上下 Blank 均分 + 图标，强制视觉垂直居中
      // 官方约定内容定宽 56（勿 width 100%）；彩色星芒不加 fillColor
      Column() {
        Blank().layoutWeight(1)
        Image($r('app.media.ic_ai_spark'))
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
          .flexShrink(0)
        Blank().layoutWeight(1)
      }
      .width(56)
      .height(56)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 1 })
            .onAction(() => {
              this.handleMiniBarTap()
            }),
          LongPressGesture({ repeat: false, duration: 400 })
            .onAction(() => {
              // 长按：展开手动/高级入口
              this.expandMiniBar()
            })
        )
      )
    } else {
      Row() {
        Column({ space: 2 }) {
          Image($r('app.media.ic_tab_debt'))
            .width(18)
            .height(18)
            .fillColor(this.miniBarFg())
          Text('新增负债')
            .fontSize(TypeScale.kicker)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.miniBarFg())
            .maxLines(1)
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => this.onAddSelect('debt'))

        Column({ space: 2 }) {
          Image($r('app.media.ic_tab_subscription'))
            .width(18)
            .height(18)
            .fillColor(this.miniBarFg())
          Text('新增订阅')
            .fontSize(TypeScale.kicker)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.miniBarFg())
            .maxLines(1)
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => this.onAddSelect('subscription'))

        Column({ space: 2 }) {
          Image($r('app.media.ic_tab_account'))
            .width(18)
            .height(18)
            .fillColor(this.miniBarFg())
          Text('新增账户')
            .fontSize(TypeScale.kicker)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.miniBarFg())
            .maxLines(1)
        }
        .layoutWeight(1)
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .onClick(() => this.onAddSelect('creditAccount'))
      }
      .width('100%')
      .height('100%')
      .padding({ left: 4, right: 4 })
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    NavDestination() {
    Stack() {
      // 官方：HdsTabs 悬浮 + MiniBar + 智感握姿
      HdsTabs({ index: this.selectedIndex, controller: this.controller }) {
        TabContent() {
          DashboardTab()
        }
        .tabBar(new BottomTabBarStyle($r('app.media.ic_tab_home'), '首页')
          .labelStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
          .iconStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
        )

        TabContent() {
          DebtsTab()
        }
        .tabBar(new BottomTabBarStyle($r('app.media.ic_tab_debt'), '负债')
          .labelStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
          .iconStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
        )

        TabContent() {
          SubscriptionsTab()
        }
        .tabBar(new BottomTabBarStyle($r('app.media.ic_tab_subscription'), '订阅')
          .labelStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
          .iconStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
        )

        TabContent() {
          CreditAccountsTab()
        }
        .tabBar(new BottomTabBarStyle($r('app.media.ic_tab_account'), '账户')
          .labelStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
          .iconStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
        )

        TabContent() {
          SettingsTab()
        }
        .tabBar(new BottomTabBarStyle($r('app.media.ic_tab_profile'), '我的')
          .labelStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
          .iconStyle({
            selectedColor: this.theme.controlSelected() as string,
            unselectedColor: this.theme.text3 as string
          })
        )
      }
      .barOverlap(true)
      .vertical(false)
      .barPosition(BarPosition.End)
      .scrollable(false)
      // 给悬浮底栏一个明确的 surface2 底色，避免与页面背景融合成一整条
      .barBackgroundColor(this.theme.surface2)
      .barBackgroundBlurStyle(BlurStyle.Thin)
      .barFloatingStyle({
        barBottomMargin: this.getBarBottomMargin(),
        // 智感握姿
        adaptToHandedness: true,
        // 沉浸光感：官方 AdaptiveTabView = IMMERSIVE + ADAPTIVE
        systemMaterialEffect: ImmersiveTitleBar.floatingBarMaterial(),
        miniBar: {
          miniBarBuilder: (): void => {
            this.miniBarBuilder()
          },
          // 产品默认折叠（圆 +）；展开/收起交给系统互斥动效
          miniBarStyle: HdsBarStyle.COLLAPSE,
          // Mini 背景跟随页签栏光感材质
          enableMiniBarBackground: true,
          enableMiniBarClip: true,
          onBarStyleChange: (miniBarStyle: HdsBarStyle): void => {
            this.isMiniBarCollapsed = miniBarStyle === HdsBarStyle.COLLAPSE
          }
        }
      })
      .onChange((index: number) => {
        this.selectedIndex = index
        AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, index)
        this.trackTabView(index)
        // 切 Tab 时收起 Mini（与官方对称）
        if (!this.isMiniBarCollapsed) {
          this.collapseMiniBar()
        }
      })
      .width('100%')
      .height('100%')

      // AI Live：盖在主 Tab 上，不 push 路由；入口由 MiniBar 指定
      if (this.showAILive) {
        AILiveOverlay({
          show: $showAILive,
          theme: this.theme,
          launchMode: this.aiLaunchMode
        })
      }

      // 全部还清仪式：盖住底栏；z 在 AI Live 之上（极短里程碑）
      if (this.showAllClearedCeremony) {
        AllClearedCeremonyOverlay({
          show: $showAllClearedCeremony,
          theme: this.theme,
          settledCount: this.allClearedSettledCount
        })
      }

      // MiniBar 长短按说明：首次进入主页仅展示一次
      if (this.showMiniBarGuide) {
        MiniBarGuideOverlay({
          show: $showMiniBarGuide,
          theme: this.theme
        })
      }

      // 订阅月结小票：全屏磨砂浮层，居中盖住底栏
      if (this.showReceiptOverlay) {
        ReceiptSlipOverlay({
          theme: this.theme,
          model: ReceiptSlipModel.fromSubscription(
            AppStorage.get<ReceiptModel>(AppStorageKeys.RECEIPT_MODEL) ?? new ReceiptModel()
          ),
          onClose: () => {
            this.showReceiptOverlay = false
          }
        })
      }

      // 负债小票：全屏磨砂浮层，居中盖住底栏
      if (this.showDebtReceiptOverlay) {
        ReceiptSlipOverlay({
          theme: this.theme,
          model: ReceiptSlipModel.fromDebt(
            AppStorage.get<DebtReceiptModel>(AppStorageKeys.DEBT_RECEIPT_MODEL) ?? new DebtReceiptModel()
          ),
          onClose: () => {
            this.showDebtReceiptOverlay = false
          }
        })
      }

      // 账户小票：全屏磨砂浮层，居中盖住底栏
      if (this.showAccountReceiptOverlay) {
        ReceiptSlipOverlay({
          theme: this.theme,
          model: ReceiptSlipModel.fromAccount(
            AppStorage.get<AccountReceiptModel>(AppStorageKeys.ACCOUNT_RECEIPT_MODEL) ??
              new AccountReceiptModel()
          ),
          onClose: () => {
            this.showAccountReceiptOverlay = false
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet(this.showSheet, this.sheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      radius: LengthMetrics.vp(this.theme.sheetRadius),
      showClose: false,
      backgroundColor: this.theme.sheetBackground() as string,
      blurStyle: BlurStyle.NONE,
      maskColor: this.theme.sheetMaskColor(),
      shadow: this.theme.sheetShadowOptions(),
      onDisappear: () => {
        this.showSheet = false
      }
    })
    }
    .hideTitleBar(true)
    .backgroundColor(this.theme.background)
    .onShown(() => this.handlePageShown())
    .onBackPressed(() => this.handleBackPress())
  }

  @Builder
  sheetBuilder() {
    SheetDialogView({
      theme: this.theme,
      config: this.sheetConfig,
      onTap: (index: number) => {
        this.showSheet = false
        this.sheetCallback(index)
      },
      onClose: () => {
        this.showSheet = false
      }
    })
  }
}
