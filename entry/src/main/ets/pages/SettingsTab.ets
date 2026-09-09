import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens, Utils } from 'common'
import { UserService } from 'service'
import { SettingsService } from 'service'
import { ReminderService } from 'service'
import { AuthManager } from 'service'
import { ProfileService } from 'service'
import { AntiPeekService, AntiPeekSetupOutcome } from 'service'
import { HandednessService } from 'service'
import { image } from '@kit.ImageKit'
import { UserSettings } from 'common'
import { ExportImportPanel } from 'components'
import { ExportImportService } from 'service'
import { SyncScheduler, SyncResult } from 'service'
import { SyncRealtime } from 'service'
import { AppVersionService } from 'service'
import { AIConfigSheet, AIConfigSummaryHelper } from 'components'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton, SheetHeader, SheetDialogFooter, sheetBottomInset } from 'components'
import { bundleManager, common } from '@kit.AbilityKit'
import { Constants } from 'common'
import { AppStorageKeys } from 'common'
import { AppRouter, RouteNames } from 'common'
import { SettingsThemeSheet } from 'components'
import { SettingsVersionSheet } from 'components'
import { ThemeMode } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { LegalDocSheet } from 'components'
import {
  accountLabel as accountLabelText,
  accountSubtitle as accountSubtitleText,
  accountMark as accountMarkChar,
  foundingBadgeText,
  syncStatusText
} from './common/SettingsDisplay'
import { fetchEffectiveTheme } from './common/ThemeLoader'
import {
  applySystemColorMode as applyColorModeToSystem,
  pullSystemDarkFromAbilityConfig as pullSystemDarkFromConfig
} from './common/ThemeApplier'

/** 标题磨砂材质浮现的滚动阈值 vp */
const HEADER_BLUR_THRESHOLD: number = 8


/**
 * 我的 · X 产品风
 * - 顶部账户卡
 * - 分组设置列表
 * - 导入/导出、主题：底部半模态（bindSheet）
 */
@Component
export struct SettingsTab {
  /** 首帧同步取最近生效主题快照，避免懒创建时先按 DARK 黑底渲染、loadTheme 落定后再翻转的黑闪 */
  @State theme: ThemeColors = ThemeManager.snapshot()
  @State settings: UserSettings = new UserSettings()
  @State isCloudUser: boolean = false
  @State userEmail: string = ''
  @State appVersion: string = '1.0.0'
  @State isFirstInstall: boolean = false
  @State isVersionUpdated: boolean = false
  @State hasUnreadVersionUpdate: boolean = false
  @StorageProp(AppStorageKeys.TOP_SAFE_HEIGHT) topSafe: number = 0
  @State sessionEmail: string = ''
  @State sessionUserId: string = ''
  @State sessionMode: string = ''
  @State avatarPixelMap: image.PixelMap | null = null
  @State showExportSheet: boolean = false
  @State showThemeSheet: boolean = false
  @State showConfirmSheet: boolean = false
  @State showVersionSheet: boolean = false
  @State showAISheet: boolean = false
  @State showLegalSheet: boolean = false
  @State legalKind: string = 'privacy'
  /** 每次打开 AI Sheet 递增，驱动子组件重载已保存配置 */
  @State aiSheetSession: number = 0
  @State aiSummary: string = '未配置'
  @State confirmConfig: SheetDialogConfig = new SheetDialogConfig()
  private confirmCallback: (index: number) => void = () => {}
  /** 清空进行中：弹窗内 loading、禁用操作；完成后只 toast 一次结果 */
  @State private clearingData: boolean = false
  /** 导入/导出进行中：面板进度可视化，禁止关 sheet */
  @State private exportBusy: boolean = false
  @StorageLink('ambientLux') @Watch('onLuxChange') lux: number = -1
  @StorageLink('systemDark') @Watch('onLuxChange') systemDark: boolean = false
  @StorageLink('themeRevision') @Watch('onThemeRevision') themeRevision: number = 0
  @StorageLink('profileRevision') @Watch('onProfileRevision') profileRevision: number = 0
  /** 清空数据 / 登录登出等会 bump listRefresh；设置页同步刷新账户卡与会话 */
  @StorageLink('listRefreshToken') @Watch('onListRefresh') listRefreshToken: number = 0
  @StorageLink('syncRevision') @Watch('onSyncRevision') syncRevision: number = 0
  /** idle | syncing | ok | error — 驱动同步指示与状态文案 */
  @State private syncPhase: string = 'idle'
  @State private syncRunning: boolean = false
  /** 本轮同步方向：up=上传 / down=下载（调度器快照；UI 仅用相位） */
  @State private syncDirection: string = 'down'
  /** 右侧状态文字（同步中旁挂圆环，结束后旁挂刷新标识） */
  @State private syncStatusText: string = '登录后可用'
  @StorageLink('appLockEnabled') appLockEnabled: boolean = false
  /** 防窥保护开关：系统检测到他人窥视屏幕时自动打码金额/名称/日期等敏感文本 */
  @State antiPeekEnabled: boolean = false
  @State handAwarenessEnabled: boolean = true
  /** 列表页标题栏分享按钮 */
  @State shareEnabled: boolean = true
  /** AI Live「去配置」：切到设置 Tab 并打开 AI 配置 Sheet */
  @StorageLink('settingsOpenAISheet') @Watch('onOpenAISheetRequest') openAISheetFlag: boolean = false
  private isResettingToggle: boolean = false
  /** 页面内所有延时任务句柄，销毁时统一清理，避免回调访问已释放状态 */
  private pendingTimers: number[] = []
  /** 内容区滚动控制器：切入本 Tab 时回到顶部 */
  private contentScroller: Scroller = new Scroller()
  @StorageProp('mainTabIndex') @Watch('onTabChange') mainTabIndex: number = 0
  private lastHandledRefreshToken: number = 0
  private settingsBootstrapped: boolean = false
  /** 滚过阈值：悬浮标题磨砂材质浮现 */
  @State private headerScrolled: boolean = false
  /** 悬浮标题实测高度（含状态栏避让），滚动内容据此留出顶部空间 */
  @State private headerHeight: number = 0

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    AppStorage.setOrCreate(AppStorageKeys.SETTINGS_SHEET_BLOCKING_THEME, false)
    this.consumeOpenAISheetRequest()
    if (this.mainTabIndex === 4) {
      this.ensureBootstrap()
    }
  }

  private onOpenAISheetRequest(): void {
    this.consumeOpenAISheetRequest()
  }

  private onTabChange(): void {
    if (this.mainTabIndex === 4) {
      // 切入本 Tab：内容回到顶部（切前可能停在滚动中段）
      try {
        this.contentScroller.scrollEdge(Edge.Top)
      } catch (_err) {
      }
      this.headerScrolled = false
      const firstEnter = !this.settingsBootstrapped
      this.ensureBootstrap()
      if (!firstEnter) {
        this.pullCloudProfile()
        if (this.listRefreshToken !== this.lastHandledRefreshToken) {
          this.lastHandledRefreshToken = this.listRefreshToken
          this.loadSettings()
          this.loadSession()
        }
      }
    }
  }

  /** 滚过阈值浮现标题磨砂材质，回顶淡出；只在跨越时置态，不逐帧刷新 */
  private onContentDidScroll(): void {
    const scrolled = this.contentScroller.currentOffset().yOffset > HEADER_BLUR_THRESHOLD
    if (scrolled !== this.headerScrolled) {
      this.headerScrolled = scrolled
    }
  }

  private onSyncRevision(): void {
    this.refreshSyncUi()
  }

  private isCloudSession(): boolean {
    return this.sessionMode === 'cloud' && this.sessionUserId.length > 0
  }

  /** 从调度器刷新同步相位与状态文案 */
  private refreshSyncUi(): void {
    const snap = SyncScheduler.getSnapshot()
    this.syncPhase = snap.phase
    this.syncRunning = snap.phase === 'syncing'
    this.syncDirection = snap.direction
    this.syncStatusText = this.syncStatusValue()
  }

  /** 列表行右侧状态文字 */
  private syncStatusValue(): string {
    return syncStatusText(this.isCloudSession(), SyncScheduler.getSnapshot(), this.syncRunning)
  }

  /** 点击「云端同步」：未登录去登录；已登录则手动拉一次同步 */
  private async onCloudSyncTap(): Promise<void> {
    if (!this.isCloudSession()) {
      AppToast.show('登录后可用云端同步', 2000)
      AppRouter.push(RouteNames.LOGIN)
      return
    }
    if (this.syncRunning || this.syncPhase === 'syncing') {
      return
    }
    this.syncRunning = true
    this.syncPhase = 'syncing'
    this.syncStatusText = '同步中'
    try {
      const result: SyncResult = await SyncScheduler.runNow()
      if (result.success) {
        AppToast.show(SyncScheduler.statusLabel(), 1500)
      } else if (result.message !== '同步进行中') {
        const msg = result.message.length > 0 ? result.message : ErrorMessages.SYNC_FAILED
        AppToast.show(msg, 2500)
      }
    } catch {
      AppToast.show(ErrorMessages.SYNC_FAILED, 2500)
    } finally {
      this.refreshSyncUi()
    }
  }

  private consumeOpenAISheetRequest(): void {
    if (!this.openAISheetFlag) {
      return
    }
    this.openAISheetFlag = false
    this.aiSheetSession = this.aiSheetSession + 1
    this.showAISheet = true
  }

  aboutToDisappear() {
    AppStorage.setOrCreate(AppStorageKeys.SETTINGS_SHEET_BLOCKING_THEME, false)
    for (const id of this.pendingTimers) {
      clearTimeout(id)
    }
    this.pendingTimers = []
  }

  /** setTimeout 登记化：句柄入 pendingTimers，触发或销毁时移除 */
  private deferTimer(fn: () => void, delay: number): void {
    const id = setTimeout(() => {
      this.pendingTimers = this.pendingTimers.filter((t: number) => t !== id)
      fn()
    }, delay)
    this.pendingTimers.push(id)
  }

  private ensureBootstrap(): void {
    if (this.settingsBootstrapped) {
      return
    }
    this.settingsBootstrapped = true
    this.bootstrap()
  }

  private async bootstrap(): Promise<void> {
    try {
      await this.loadSettings()
      this.lastHandledRefreshToken = this.listRefreshToken
      await this.loadTheme(false, true)
      await this.loadSession()
      await this.pullCloudProfile()
      await this.loadVersion()
      this.refreshSyncUi()
    } catch {
    }
  }

  private async loadVersion(): Promise<void> {
    try {
      const info = await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      this.appVersion = info.versionName
    } catch {
      this.appVersion = '1.0.0'
    }
    try {
      const state = await AppVersionService.checkVersionState(this.appVersion)
      this.isFirstInstall = state.isFirstInstall
      this.isVersionUpdated = state.isVersionUpdated
      this.hasUnreadVersionUpdate = await AppVersionService.hasUnreadVersionUpdate(this.appVersion)
    } catch {
    }
  }

  private onLuxChange(): void {
    // 半模态打开时勿刷新主题：宿主重建会让 bindSheet 反复播弹出动画并与 onDisappear 竞态关窗
    this.loadTheme(false)
  }

  private onThemeRevision(): void {
    this.loadTheme(false)
  }

  private async loadTheme(_animate: boolean = false, force: boolean = false): Promise<void> {
    if (!force && this.isAnySheetOpen()) {
      return
    }
    const next = await fetchEffectiveTheme(this.lux, this.systemDark)
    // await 后 sheet 状态可能已变
    if (!force && this.isAnySheetOpen()) {
      return
    }
    if (!force && ThemeManager.isSame(this.theme, next)) {
      return
    }
    this.theme = next
  }

  private isAnySheetOpen(): boolean {
    return this.showConfirmSheet || this.showExportSheet || this.showThemeSheet ||
      this.showVersionSheet || this.showAISheet || this.showLegalSheet
  }

  private openLegalSheet(kind: string): void {
    this.legalKind = kind
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showLegalSheet = true
    })
    this.syncSheetThemeBlock()
  }

  private refreshAISummary(): void {
    this.aiSummary = AIConfigSummaryHelper.from(this.settings)
  }

  private async reloadSettingsAndAISummary(): Promise<void> {
    this.settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    this.refreshAISummary()
    AppStorage.setOrCreate(AppStorageKeys.AI_CONFIG_REVISION,
      (AppStorage.get<number>(AppStorageKeys.AI_CONFIG_REVISION) ?? 0) + 1)
  }

  private themeModeLabel(mode: string): string {
    if (mode === 'light') {
      return '浅色'
    }
    if (mode === 'dark') {
      return '深色'
    }
    return '跟随系统'
  }

  private async setThemeMode(mode: 'light' | 'dark' | 'system'): Promise<void> {
    if (this.settings.theme_mode === mode) {
      return
    }
    // 1) 立刻更新选中态
    this.settings.theme_mode = mode

    // 2) 跟随系统必须先 setColorMode(NOT_SET) 再读 config，才能拿到系统真值
    //    （强制浅/深时 config 是应用生效值；Environment/ArkUI ColorMode 与 Configuration 数值相反不可混用）
    if (mode === 'system') {
      this.applySystemColorMode('system')
      this.theme = ThemeManager.currentTheme(this.settings, this.systemDark, this.lux)
      this.syncSheetThemeBlock()
      // 框架落定后再读一次，并广播全站
      this.deferTimer(() => {
        this.pullSystemDarkFromAbilityConfig()
        this.theme = ThemeManager.currentTheme(this.settings, this.systemDark, this.lux)
        this.syncSheetThemeBlock()
        Constants.notifyThemeChange()
      }, 50)
    } else {
      this.theme = ThemeManager.currentTheme(this.settings, this.systemDark, this.lux)
      this.syncSheetThemeBlock()
    }

    // 3) 落库 + 强制浅/深的 setColorMode 延后，避免切换卡顿
    const applyMode = mode
    this.deferTimer(async () => {
      try {
        await SettingsService.updateThemeMode(applyMode)
        if (applyMode !== 'system') {
          this.applySystemColorMode(applyMode)
        }
        Constants.notifyThemeChange()
      } catch (_e) {
        AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      }
    }, 48)
  }

  private pullSystemDarkFromAbilityConfig(): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      return
    }
    pullSystemDarkFromConfig(context)
  }

  private applySystemColorMode(mode: 'light' | 'dark' | 'system'): void {
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      return
    }
    applyColorModeToSystem(context, mode)
  }

  private async loadSettings(): Promise<void> {
    this.settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    this.appLockEnabled = this.settings.app_lock_enabled
    AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, this.appLockEnabled)
    this.antiPeekEnabled = AntiPeekService.isEnabled()
    this.handAwarenessEnabled = this.settings.hand_awareness_enabled
    this.shareEnabled = this.settings.share_enabled
    AppStorage.setOrCreate(AppStorageKeys.SHARE_ENABLED, this.shareEnabled)
    this.refreshAISummary()
    this.loadAvatar()
  }

  /**
   * 防窥保护开关：走系统受限权限 + 引导开启系统级防窥开关；
   * 失败按结果回弹开关并弹窗说明原因。
   */
  private async onAntiPeekToggle(on: boolean): Promise<void> {
    if (!on) {
      this.antiPeekEnabled = false
      await AntiPeekService.setEnabled(false)
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    const outcome = await AntiPeekService.enable(context)
    if (outcome === AntiPeekSetupOutcome.OK) {
      this.antiPeekEnabled = true
      AppToast.show('已开启防窥保护', 1500)
      return
    }
    // 未开启成功：回弹开关，并说明原因
    this.antiPeekEnabled = false
    let title: string = '无法开启防窥保护'
    let message: string = ''
    if (outcome === AntiPeekSetupOutcome.UNSUPPORTED) {
      message = '当前设备不支持防窥保护功能'
    } else if (outcome === AntiPeekSetupOutcome.PERMISSION_DENIED) {
      message = '未获得窥视状态权限，可在系统设置中手动授权后重试'
    } else {
      message = '需在系统「设置 > 隐私和安全 > 防窥保护」中录入人脸并为本应用开启开关'
    }
    const config = new SheetDialogConfig(title, message, [
      new SheetDialogButton('知道了', this.theme.text, 'default')
    ])
    this.openConfirm(config, () => {})
  }

  /** 智感握姿开关：持久化 + 让运行中的服务立即生效/退订 */
  private async onHandAwarenessToggle(on: boolean): Promise<void> {
    try {
      HandednessService.setEnabled(on)
      await SettingsService.updateHandAwareness(on)
    } catch (_e) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      HandednessService.setEnabled(!on)
    }
  }

  /** 分享按钮总开关：持久化 + 立刻反映到负债/订阅/账户标题栏 */
  private async onShareEnabledToggle(on: boolean): Promise<void> {
    const prev = this.shareEnabled
    this.shareEnabled = on
    this.settings.share_enabled = on
    AppStorage.setOrCreate(AppStorageKeys.SHARE_ENABLED, on)
    try {
      await SettingsService.updateShareEnabled(on)
      AppToast.show(on ? '已显示分享' : '已隐藏分享', 1500)
    } catch (_e) {
      this.shareEnabled = prev
      this.settings.share_enabled = prev
      AppStorage.setOrCreate(AppStorageKeys.SHARE_ENABLED, prev)
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    }
  }

  private async loadSession(): Promise<void> {
    const session = await AuthManager.loadSession()
    if (session) {
      this.sessionMode = session.mode
      this.sessionEmail = session.email
      this.sessionUserId = session.userId
    } else {
      this.sessionMode = ''
      this.sessionEmail = ''
      this.sessionUserId = ''
    }
    this.refreshSyncUi()
  }

  private async loadAvatar(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.avatarPixelMap = await ProfileService.loadAvatarPixelMap(ctx, this.settings.profile_avatar_path)
  }

  private async pullCloudProfile(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      await ProfileService.pullFromCloud(ctx)
      this.settings = await SettingsService.getSettings(UserService.getCurrentUserId())
      await this.loadAvatar()
    } catch (_e) {
    }
  }

  private accountLabel(): string {
    return accountLabelText(this.settings.profile_nickname, this.sessionEmail, this.isCloudSession())
  }

  private accountSubtitle(): string {
    return accountSubtitleText(this.settings.profile_nickname, this.sessionEmail)
  }

  private accountMark(): string {
    return accountMarkChar(this.settings.profile_nickname, this.sessionEmail)
  }

  /** 创始版徽章文案：有创始编号时追加 No.xxxx，否则仅显示「创始版」 */
  private foundingBadge(): string {
    return foundingBadgeText(this.settings.founding_member_no)
  }

  private showVersionInfo(): void {
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showVersionSheet = true
    })
    this.syncSheetThemeBlock()
  }

  private signOut(): void {
    const config = new SheetDialogConfig(
      '退出登录',
      '退出后返回登录页，本地数据保留。',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('确认退出', this.theme.red, 'destructive')
      ]
    )
    this.openConfirm(config, (index: number) => {
      if (index === 1) {
        this.doSignOut()
      }
    })
  }

  private async doSignOut(): Promise<void> {
    try {
      SyncRealtime.stop()
      SyncScheduler.stopForegroundPulse()
      await AuthManager.signOut()
      AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 0)
      AppToast.show('已退出登录', 1500)
      AppRouter.replace(RouteNames.LOGIN)
    } catch (_e) {
      AppToast.show(ErrorMessages.UNKNOWN, 2000)
    }
  }

  private goToAppLockPage(): void {
    const param: Record<string, Object> = { 'isFromSettings': true }
    AppRouter.push(RouteNames.APP_LOCK, param)
  }

  /**
   * 强制应用锁开关视觉态
   * Toggle onChange 后 isOn 可能暂留 true，需立刻按真实状态拉回
   */
  private forceAppLockToggle(on: boolean): void {
    this.isResettingToggle = true
    this.appLockEnabled = !on
    AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, !on)
    // 双帧复位，覆盖 Toggle 内部乐观更新
    this.deferTimer(() => {
      this.appLockEnabled = on
      AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, on)
      this.deferTimer(() => {
        this.isResettingToggle = false
      }, 50)
    }, 16)
  }

  /** 资料页保存后刷新账户卡（Tab 内组件无 onPageShow，靠 PROFILE_REVISION 通知） */
  onProfileRevision(): void {
    this.loadSettings()
    this.loadSession()
  }

  /** 清空数据 / 其它业务刷新令牌：重载设置与会话展示 */
  private onListRefresh(): void {
    // 半模态打开时勿重建宿主：bindSheet 会丢点击（测通落盘曾因此让「完成」失灵）
    if (this.isAnySheetOpen()) {
      return
    }
    if (this.mainTabIndex !== 4) {
      return
    }
    this.lastHandledRefreshToken = this.listRefreshToken
    this.loadSettings()
    this.loadSession()
  }

  /** 从子页返回：锁开关 + 账户卡/会话 + 设置项 */
  onPageShow(): void {
    this.refreshAppLockToggleFromDisk()
    this.loadSettings()
    this.loadSession()
  }

  private async refreshAppLockToggleFromDisk(): Promise<void> {
    try {
      const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
      const enabled = settings.app_lock_enabled === true
      this.settings.app_lock_enabled = enabled
      this.isResettingToggle = true
      this.appLockEnabled = enabled
      AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, enabled)
      this.deferTimer(() => {
        this.isResettingToggle = false
      }, 80)
    } catch {
      this.forceAppLockToggle(false)
    }
  }

  private confirmDisableAppLock(): void {
    const config = new SheetDialogConfig(
      '关闭应用锁',
      '关闭后安全密码将被清除',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('确认关闭', this.theme.red, 'destructive')
      ]
    )
    this.openConfirm(config, async (index: number) => {
      if (index === 1) {
        try {
          await SettingsService.removeAppLock()
          this.appLockEnabled = false
          AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, false)
          AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_VERIFIED, false)
          AppToast.show(ErrorMessages.LOCK_OFF, 2000)
        } catch (err) {
          AppToast.show(ErrorMessages.LOCK_FAILED, 2000)
          this.isResettingToggle = true
          this.appLockEnabled = true
          AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, true)
          this.deferTimer(() => {
            this.isResettingToggle = false
          }, 100)
        }
      } else {
        this.isResettingToggle = true
        this.appLockEnabled = false
        this.deferTimer(() => {
          this.appLockEnabled = true
          AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, true)
          this.deferTimer(() => {
            this.isResettingToggle = false
          }, 100)
        }, 50)
      }
    })
  }

  private clearAllData(): void {
    if (this.clearingData) {
      return
    }
    const config = new SheetDialogConfig(
      '确认清空？',
      '将删除本机负债、订阅、信用账户和还款记录。若已登录云端，云端数据也会清空。此操作不可恢复。',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('确认清空', this.theme.red, 'destructive')
      ]
    )
    this.openConfirm(config, async (index: number) => {
      if (index === 1) {
        await this.doClearAll()
      }
    })
  }

  private async doClearAll(): Promise<void> {
    if (this.clearingData) {
      return
    }
    this.clearingData = true
    // 保持数据管理 sheet 打开，用面板 loading 代替「正在清空…」短 toast
    this.showExportSheet = true
    this.syncSheetThemeBlock()
    try {
      const result = await ExportImportService.clearAllUserData()
      if (!result.localCleared) {
        AppToast.show(ErrorMessages.CLEAR_FAILED, 2000)
        return
      }
      // 仅收尾 toast 一次，避免「清空中消失 → 几秒后再出已清空」
      if (result.cloudDataFailed) {
        AppToast.show(ErrorMessages.CLEAR_CLOUD_FAILED, 2800)
      } else {
        AppToast.show(ErrorMessages.DATA_CLEARED, 2000)
      }
      this.showExportSheet = false
    } catch (err) {
      AppToast.show(ErrorMessages.CLEAR_FAILED, 2000)
    } finally {
      this.clearingData = false
      this.syncSheetThemeBlock()
    }
  }

  private openConfirm(config: SheetDialogConfig, callback: (index: number) => void): void {
    // 已打开时只更新内容，避免 true→true 或关开循环触发多次弹出动画
    this.confirmCallback = callback
    this.confirmConfig = config
    if (!this.showConfirmSheet) {
      this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
        this.showConfirmSheet = true
      })
      this.syncSheetThemeBlock()
    }
  }

  /** 通知 MainPage：设置页半模态打开期间不要因光感刷新主题（避免父树重建打掉 sheet） */
  private syncSheetThemeBlock(): void {
    AppStorage.setOrCreate(AppStorageKeys.SETTINGS_SHEET_BLOCKING_THEME, this.isAnySheetOpen())
  }

  private async toggleReminderBefore(enabled: boolean): Promise<void> {
    const prev = this.settings.remind_before_due
    this.settings.remind_before_due = enabled
    try {
      await SettingsService.saveSettings(this.settings)
      ReminderService.scheduleRefresh()
      AppToast.show(enabled ? '已开启到期前提醒' : '已关闭到期前提醒', 1500)
    } catch (_e) {
      this.settings.remind_before_due = prev
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    }
  }

  private async toggleReminderOnDue(enabled: boolean): Promise<void> {
    const prev = this.settings.remind_on_due_day
    this.settings.remind_on_due_day = enabled
    try {
      await SettingsService.saveSettings(this.settings)
      ReminderService.scheduleRefresh()
      AppToast.show(enabled ? '已开启当日提醒' : '已关闭当日提醒', 1500)
    } catch (_e) {
      this.settings.remind_on_due_day = prev
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    }
  }

  private async togglePressureAlert(enabled: boolean): Promise<void> {
    const prev = this.settings.pressure_alert_enabled
    this.settings.pressure_alert_enabled = enabled
    try {
      await SettingsService.saveSettings(this.settings)
      AppToast.show(enabled ? '已开启压力预警' : '已关闭压力预警', 1500)
    } catch (_e) {
      this.settings.pressure_alert_enabled = prev
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    }
  }

  @Builder
  exportSheetBuilder() {
    Column() {
      SheetHeader({
        theme: this.theme,
        title: '数据管理',
        onClose: () => {
          // 清空/导入导出进行中禁止关窗，避免中断与状态错乱
          if (!this.clearingData && !this.exportBusy) {
            this.showExportSheet = false
          }
        }
      })

      ExportImportPanel({
        theme: this.theme,
        clearing: this.clearingData,
        onClearAllData: () => {
          this.clearAllData()
        },
        onBusyChange: (busy: boolean) => {
          this.exportBusy = busy
          this.syncSheetThemeBlock()
        }
      })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
  }

  @Builder
  confirmSheetBuilder() {
    SheetDialogView({
      theme: this.theme,
      config: this.confirmConfig,
      onTap: (index: number) => {
        const cb = this.confirmCallback
        this.confirmCallback = () => {}
        this.showConfirmSheet = false
        // 先关 sheet 再执行回调，避免关窗动画与路由/状态更新叠加重入
        cb(index)
      },
      onClose: () => {
        this.showConfirmSheet = false
      }
    })
  }

  @Builder
  aiSheetBuilder() {
    AIConfigSheet({
      theme: this.theme,
      openSession: this.aiSheetSession,
      onDone: () => {
        this.showAISheet = false
        this.syncSheetThemeBlock()
        this.reloadSettingsAndAISummary()
      },
      onClose: () => {
        this.showAISheet = false
        this.syncSheetThemeBlock()
        this.reloadSettingsAndAISummary()
        this.loadTheme(false)
      }
    })
  }

  @Builder
  versionSheetBuilder() {
    SettingsVersionSheet({
      theme: this.theme,
      appVersion: this.appVersion,
      isFirstInstall: this.isFirstInstall,
      isVersionUpdated: this.isVersionUpdated,
      onClose: () => {
        this.showVersionSheet = false
        this.hasUnreadVersionUpdate = false
        AppVersionService.markVersionViewed(this.appVersion).catch(() => {})
        this.syncSheetThemeBlock()
        this.loadTheme(false)
      }
    })
  }

  @Builder
  themeSheetBuilder() {
    SettingsThemeSheet({
      theme: this.theme,
      themeMode: this.settings.theme_mode,
      onSelect: (mode: ThemeMode) => {
        this.setThemeMode(mode)
      },
      onClose: () => {
        this.showThemeSheet = false
        this.syncSheetThemeBlock()
        this.loadTheme(false)
      }
    })
  }

  @Builder
  legalSheetBuilder() {
    LegalDocSheet({
      theme: this.theme,
      kind: this.legalKind,
      onClose: () => {
        this.showLegalSheet = false
        this.syncSheetThemeBlock()
        this.loadTheme(false)
      }
    })
  }

  @Builder
  sectionLabel(title: string) {
    Text(title)
      .fontSize(TypeScale.body)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.text3)
      .width('100%')
      .padding({ left: 4, top: this.theme.spaceMd, bottom: this.theme.spaceXs })
  }

  build() {
    // 外层挂主题 Sheet；内层挂导入导出 Sheet
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
        // 内容全高滚动，从标题下方穿过
        Scroll(this.contentScroller) {
          Column() {
          // 账户卡（略增高，避免过扁）
          Row({ space: 14 }) {
            if (this.avatarPixelMap !== null) {
              Image(this.avatarPixelMap)
                .width(60)
                .height(60)
                .borderRadius(this.theme.radiusPill)
                .objectFit(ImageFit.Cover)
            } else {
              Column() {
                Text(this.accountMark())
                  .fontSize(TypeScale.sectionNumber)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.onColorBlock())
              }
              .width(60)
              .height(60)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.theme.accent)
              .justifyContent(FlexAlign.Center)
            }

            Column({ space: 4 }) {
              Text(this.accountLabel())
                .fontSize(TypeScale.listPrimarySm)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })

              if (this.settings.founding_member_no > 0) {
                // 创始版 徽章：仅购买会员（已分配创始编号）时显示
                Text(this.foundingBadge())
                  .fontSize(TypeScale.captionSm)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#D4AF37')
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('rgba(212, 175, 55, 0.1)')
                  .borderRadius(this.theme.radiusSm)
                  .border({ width: 0.5, color: 'rgba(212, 175, 55, 0.4)' })
                  .margin({ top: 4 })
              }

              if (this.accountSubtitle().length > 0) {
                Text(this.accountSubtitle())
                  .fontSize(TypeScale.body)
                  .fontColor(this.theme.text3)
                  .margin({ top: this.settings.founding_member_no > 0 ? 4 : 0 })
              }

              if (this.settings.profile_signature.length > 0) {
                Text(this.settings.profile_signature)
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .margin({ top: 2 })
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('›')
              .fontSize(TypeScale.metric)
              .fontColor(this.theme.text3)
              .flexShrink(0)
          }
          .width('100%')
          .padding({
            left: this.theme.spaceSm,
            right: this.theme.spaceSm,
            top: this.theme.spaceSm,
            bottom: this.theme.spaceSm
          })
          .backgroundColor(this.theme.surface2)
          .borderRadius(this.theme.radiusXl)
          .border({ width: 1, color: this.theme.borderSoft })
          .shadow(this.theme.floatShadowOptions())
          .hoverEffect(HoverEffect.Auto)
          .margin({ bottom: this.theme.spaceXs })
          .onClick(() => {
            if (this.isCloudSession()) {
              AppRouter.push(RouteNames.PROFILE)
            } else {
              AppRouter.push(RouteNames.LOGIN)
            }
          })

          // 提醒与预警
          this.sectionLabel('提醒与预警')
          Column() {
            SettingsItem({
              icon: $r('app.media.ic_bell'),
              label: '还款前提醒',
              value: '提前 3 天',
              theme: this.theme,
              toggle: true,
              toggled: this.settings.remind_before_due,
              onToggle: (v: boolean) => {
                this.toggleReminderBefore(v)
              }
            })
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            SettingsItem({
              icon: $r('app.media.ic_bell'),
              label: '当日还款提醒',
              value: '',
              theme: this.theme,
              toggle: true,
              toggled: this.settings.remind_on_due_day,
              onToggle: (v: boolean) => {
                this.toggleReminderOnDue(v)
              }
            })
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            SettingsItem({
              icon: $r('app.media.ic_bell'),
              label: '还款压力预警',
              value: '密集·超额·逾期',
              theme: this.theme,
              toggle: true,
              toggled: this.settings.pressure_alert_enabled,
              onToggle: (v: boolean) => {
                this.togglePressureAlert(v)
              }
            })
          }
          .width('100%')
          .clip(true)
          .backgroundColor(this.theme.surface2)
          .borderRadius(this.theme.radiusXl)
          .border({ width: 1, color: this.theme.borderSoft })
          .shadow(this.theme.floatShadowOptions())
          .hoverEffect(HoverEffect.Auto)

          // AI 与数据
          // 注意：每个 bindSheet 必须挂在独立宿主上；同一节点链式多个 bindSheet 会互抢导致闪一下即关
          this.sectionLabel('AI 与数据')
          Column() {
            Column() {
              // AI 入口：与其它 SettingsItem 同构（单色图标 + 右侧摘要）
              SettingsItem({
                icon: $r('app.media.ic_settings_ai'),
                label: 'AI 配置',
                value: this.aiSummary,
                theme: this.theme,
                onItemClick: () => {
                  this.aiSheetSession = this.aiSheetSession + 1
                  this.showAISheet = true
                  this.syncSheetThemeBlock()
                }
              })
            }
            .width('100%')
            .bindSheet($$this.showAISheet, this.aiSheetBuilder, {
              // 随内容收缩，避免未开启时固定大高度留下整屏空白
              height: SheetSize.FIT_CONTENT,
              dragBar: true,
              radius: LengthMetrics.vp(this.theme.sheetRadius),
              showClose: false,
              backgroundColor: this.theme.sheetBackground() as string,
              blurStyle: BlurStyle.NONE,
              maskColor: this.theme.sheetMaskColor(),
              shadow: this.theme.sheetShadowOptions(),
              onDisappear: () => {
                this.showAISheet = false
                this.syncSheetThemeBlock()
                this.reloadSettingsAndAISummary()
                this.loadTheme(false)
                this.deferTimer(() => {
                  Constants.notifyListRefresh()
                }, 320)
              }
            })

            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })

            Column() {
              SettingsItem({
                icon: $r('app.media.ic_settings_archive'),
                label: '数据管理',
                value: '备份、恢复与清空',
                theme: this.theme,
                onItemClick: () => {
                  this.showExportSheet = true
                  this.syncSheetThemeBlock()
                }
              })
            }
            .width('100%')
            .bindSheet($$this.showExportSheet, this.exportSheetBuilder, {
              height: SheetSize.FIT_CONTENT,
              dragBar: true,
              radius: LengthMetrics.vp(this.theme.sheetRadius),
              showClose: false,
              backgroundColor: this.theme.sheetBackground() as string,
              blurStyle: BlurStyle.NONE,
              maskColor: this.theme.sheetMaskColor(),
              shadow: this.theme.sheetShadowOptions(),
              onDisappear: () => {
                // 清空/导入导出中被系统滑关：立刻拉回，并继续占用 blocking
                if (this.clearingData || this.exportBusy) {
                  this.showExportSheet = true
                  this.syncSheetThemeBlock()
                  return
                }
                this.showExportSheet = false
                this.syncSheetThemeBlock()
                this.loadTheme(false)
              }
            })
          }
          .width('100%')
          .clip(true)
          .backgroundColor(this.theme.surface2)
          .borderRadius(this.theme.radiusXl)
          .border({ width: 1, color: this.theme.borderSoft })
          .shadow(this.theme.floatShadowOptions())
          .hoverEffect(HoverEffect.Auto)

          // 通用
          this.sectionLabel('通用')
          Column() {
            SettingsItem({
              icon: $r('app.media.ic_settings_cloud'),
              label: '云端同步',
              // 右侧：同步中安静圆环；结束后状态文字 + 刷新标识（提示可点手动同步）
              value: this.syncStatusText,
              theme: this.theme,
              showSyncIndicator: true,
              syncPhase: this.syncPhase,
              syncRunning: this.syncRunning,
              onItemClick: () => {
                this.onCloudSyncTap()
              }
            })
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            Column() {
              SettingsItem({
                icon: $r('app.media.ic_settings_moon'),
                label: '主题模式',
                value: this.themeModeLabel(this.settings.theme_mode),
                theme: this.theme,
                onItemClick: () => {
                  this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
                    this.showThemeSheet = true
                  })
                  this.syncSheetThemeBlock()
                }
              })
            }
            .width('100%')
            .bindSheet($$this.showThemeSheet, this.themeSheetBuilder, {
              height: SheetSize.FIT_CONTENT,
              dragBar: true,
              radius: LengthMetrics.vp(this.theme.sheetRadius),
              showClose: false,
              backgroundColor: this.theme.sheetBackground() as string,
              blurStyle: BlurStyle.NONE,
              maskColor: this.theme.sheetMaskColor(),
              shadow: this.theme.sheetShadowOptions(),
              onDisappear: () => {
                this.showThemeSheet = false
                this.syncSheetThemeBlock()
                this.loadTheme(false)
              }
            })
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            SettingsItem({
              icon: $r('app.media.ic_settings_lock'),
              label: '应用锁',
              theme: this.theme,
              toggle: true,
              toggled: this.appLockEnabled,
              onToggle: (v: boolean) => {
                if (this.isResettingToggle) {
                  return
                }
                if (v) {
                  if (this.appLockEnabled) {
                    // 已是开（如设 PIN 成功返回同步），忽略
                    return
                  }
                  // 仅进入设 PIN；开关保持关，设成功后由 AppLockPage 写 AppStorage 同步打开
                  this.forceAppLockToggle(false)
                  this.goToAppLockPage()
                } else {
                  if (!this.appLockEnabled) {
                    // 本来就是关，忽略
                    return
                  }
                  this.confirmDisableAppLock()
                }
              },
              onItemClick: () => {
                if (!this.appLockEnabled) {
                  this.forceAppLockToggle(false)
                  this.goToAppLockPage()
                } else {
                  this.confirmDisableAppLock()
                }
              }
            })
            if (this.appLockEnabled) {
              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
              SettingsItem({
                icon: $r('app.media.ic_settings_lock'),
                label: '修改 PIN 码',
                value: '',
                theme: this.theme,
                onItemClick: () => {
                  const param: Record<string, Object> = { 'isFromSettings': true, 'mode': 'change' }
                  AppRouter.push(RouteNames.APP_LOCK, param)
                }
              })
            }
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            SettingsItem({
              icon: $r('app.media.ic_eye_open'),
              label: '防窥保护',
              value: '',
              theme: this.theme,
              toggle: true,
              toggled: this.antiPeekEnabled,
              onToggle: (v: boolean) => {
                this.onAntiPeekToggle(v)
              }
            })
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            SettingsItem({
              icon: $r('app.media.ic_ai_spark'),
              label: '智感握姿',
              value: '',
              theme: this.theme,
              toggle: true,
              toggled: this.handAwarenessEnabled,
              onToggle: (v: boolean) => {
                this.onHandAwarenessToggle(v)
              }
            })
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
            SettingsItem({
              icon: $r('app.media.ic_share'),
              label: '显示分享',
              value: '',
              theme: this.theme,
              toggle: true,
              toggled: this.shareEnabled,
              onToggle: (v: boolean) => {
                this.onShareEnabledToggle(v)
              }
            })
          }
          .width('100%')
          .clip(true)
          .backgroundColor(this.theme.surface2)
          .borderRadius(this.theme.radiusXl)
          .border({ width: 1, color: this.theme.borderSoft })
          .shadow(this.theme.floatShadowOptions())
          .hoverEffect(HoverEffect.Auto)

          // 关于
          this.sectionLabel('关于')
          Column() {
            Column() {
              SettingsItem({
                icon: $r('app.media.ic_settings_cloud'),
                label: '应用版本',
                value: this.appVersion,
                badgeText: this.hasUnreadVersionUpdate ? 'NEW' : '',
                theme: this.theme,
                onItemClick: () => {
                  this.showVersionInfo()
                }
              })
            }
            .width('100%')
            .bindSheet($$this.showVersionSheet, this.versionSheetBuilder, {
              height: SheetSize.FIT_CONTENT,
              dragBar: true,
              radius: LengthMetrics.vp(this.theme.sheetRadius),
              showClose: false,
              backgroundColor: this.theme.sheetBackground() as string,
              blurStyle: BlurStyle.NONE,
              maskColor: this.theme.sheetMaskColor(),
              shadow: this.theme.sheetShadowOptions(),
              onDisappear: () => {
                this.showVersionSheet = false
                this.hasUnreadVersionUpdate = false
                AppVersionService.markVersionViewed(this.appVersion).catch(() => {})
                this.syncSheetThemeBlock()
                this.loadTheme(false)
              }
            })

            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })

            Column() {
              SettingsItem({
                icon: $r('app.media.ic_settings_archive'),
                label: '用户协议',
                value: '',
                theme: this.theme,
                onItemClick: () => {
                  this.openLegalSheet('terms')
                }
              })
              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 52 })
              SettingsItem({
                icon: $r('app.media.ic_settings_lock'),
                label: '隐私政策',
                value: '',
                theme: this.theme,
                onItemClick: () => {
                  this.openLegalSheet('privacy')
                }
              })
            }
            .width('100%')
            .bindSheet($$this.showLegalSheet, this.legalSheetBuilder, {
              height: '80%',
              dragBar: true,
              radius: LengthMetrics.vp(this.theme.sheetRadius),
              showClose: false,
              backgroundColor: this.theme.sheetBackground() as string,
              blurStyle: BlurStyle.NONE,
              maskColor: this.theme.sheetMaskColor(),
              shadow: this.theme.sheetShadowOptions(),
              onDisappear: () => {
                this.showLegalSheet = false
                this.syncSheetThemeBlock()
                this.loadTheme(false)
              }
            })
          }
          .width('100%')
          .clip(true)
          .backgroundColor(this.theme.surface2)
          .borderRadius(this.theme.radiusXl)
          .border({ width: 1, color: this.theme.borderSoft })
          .shadow(this.theme.floatShadowOptions())
          .hoverEffect(HoverEffect.Auto)

          // 退出登录
          Row() {
            Text('退出登录')
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ctaForeground())
          }
          .width('100%')
          .height(50)
          .justifyContent(FlexAlign.Center)
          .backgroundColor(this.theme.ctaBackground())
          .borderRadius(this.theme.radiusXl)
          .onClick(() => {
            this.signOut()
          })
          // 尾部间距由滚动容器 padding 统一负责，按钮不再自带 bottom margin
          .margin({ top: this.theme.spaceLg + this.theme.spaceSm })
          .bindSheet($$this.showConfirmSheet, this.confirmSheetBuilder, {
            height: SheetSize.FIT_CONTENT,
            dragBar: true,
            radius: LengthMetrics.vp(this.theme.sheetRadius),
            showClose: false,
            backgroundColor: this.theme.sheetBackground() as string,
            blurStyle: BlurStyle.NONE,
            maskColor: this.theme.sheetMaskColor(),
            shadow: this.theme.sheetShadowOptions(),
            onDisappear: () => {
              this.showConfirmSheet = false
              this.syncSheetThemeBlock()
              this.loadTheme(false)
              
              // 检查当物理开关在未确认解除时被关掉了，要强制恢复开关为 ON 状态
              SettingsService.getSettings(UserService.getCurrentUserId()).then((settings) => {
                if (settings.app_lock_enabled && !this.appLockEnabled) {
                  this.isResettingToggle = true
                  this.appLockEnabled = false
                  this.deferTimer(() => {
                    this.appLockEnabled = true
                    AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_ENABLED, true)
                    this.deferTimer(() => {
                      this.isResettingToggle = false
                    }, 100)
                  }, 50)
                }
              })
            }
          })

        }
        .padding({
          left: this.theme.pageHorizontalPadding,
          right: this.theme.pageHorizontalPadding,
          top: this.headerHeight,
          // CLEARANCE 已含底栏+呼吸间距；HdsTabs 自避让安全区，勿再叠 bottomSafe（双重计算）
          bottom: Constants.FLOATING_TAB_CLEARANCE
        })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .onDidScroll(() => this.onContentDidScroll())

        // 悬浮标题：位置不变；滚过阈值后磨砂材质淡入（与底栏 BlurStyle.Thin 同材质）
        // 磨砂层高度必须用实测值：'100%' 在 Stack 内会解析成整屏高，把标题挤到屏幕中央
        Stack() {
          Column()
            .width('100%')
            .height(this.headerHeight)
            .backgroundBlurStyle(BlurStyle.Thin)
            .backgroundColor(Utils.hexToRgba(this.theme.background, 0.8))
            .border({ width: { bottom: 0.5 }, color: this.theme.borderSoft })
            .opacity(this.headerScrolled ? 1 : 0)
            .animation({ duration: MotionTokens.chromeFadeDuration, curve: Curve.EaseOut })

          // 标题
          Row() {
            Column({ space: 4 }) {
              Text('我的')
                .fontSize(TypeScale.heroTitle)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.text)
                .letterSpacing(TypeScale.heroTitleSpacing)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .padding({
            left: this.theme.pageHorizontalPadding,
            right: this.theme.pageHorizontalPadding,
            top: 10 + this.topSafe,
            bottom: 8
          })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            const measured = Number(newArea.height)
            if (measured !== this.headerHeight) {
              this.headerHeight = measured
            }
          })
        }
        .width('100%')
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
  }
}

@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
struct SettingsItem {
  @Prop icon: Resource = $r('app.media.ic_tab_home')
  @Prop label: string = ''
  @Prop value: string = ''
  @Prop badgeText: string = ''
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop toggle: boolean = false
  @Prop toggled: boolean = false
  @Prop isDestructive: boolean = false
  /**
   * 右侧：同步中安静圆环；结束后状态文字 + 刷新标识
   * 对齐 Login / 导出导入的 LoadingProgress；安静不压迫
   */
  @Prop showSyncIndicator: boolean = false
  @Prop syncPhase: string = 'idle'
  @Prop syncRunning: boolean = false
  onItemClick?: () => void
  onToggle?: (value: boolean) => void

  private isSyncing(): boolean {
    return this.syncRunning || this.syncPhase === 'syncing'
  }

  build() {
    Row() {
      // 统一 20×20 槽位；SVG 需自身填满 viewBox，避免「看起来更小」
      Column() {
        Image(this.icon)
          .width(20)
          .height(20)
          .fillColor(this.isDestructive ? this.theme.red : this.theme.text2)
          .objectFit(ImageFit.Contain)
      }
      .width(20)
      .height(20)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .flexShrink(0)
      .margin({ right: 14 })

      // 标题单行，避免被右侧 value / Toggle 挤换行
      Text(this.label)
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Regular)
        .fontColor(this.isDestructive ? this.theme.red : this.theme.text)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.badgeText.length > 0) {
        Text(this.badgeText)
          .fontSize(TypeScale.captionSm)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.ctaForeground())
          .backgroundColor(this.theme.ctaBackground())
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(this.theme.radiusSm)
          .margin({ right: 6 })
          .flexShrink(0)
      }

      if (this.toggle) {
        if (this.value.length > 0) {
          Text(this.value)
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text3)
            .margin({ right: 8 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 120 })
            .flexShrink(1)
        }
        Toggle({ type: ToggleType.Switch, isOn: this.toggled })
          .selectedColor(this.theme.controlSelected())
          .switchPointColor(this.theme.controlKnob())
          .flexShrink(0)
          .onChange((v: boolean) => {
            if (this.onToggle) {
              this.onToggle(v)
            }
          })
      } else if (this.showSyncIndicator) {
        // 状态文字在左；右侧槽位：同步中圆环 / 结束后刷新标识（与其它行 › 同侧）
        if (this.value.length > 0) {
          Text(this.value)
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text3)
            .margin({ right: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: 120 })
            .flexShrink(0)
        }
        if (this.isSyncing()) {
          LoadingProgress()
            .width(16)
            .height(16)
            .color(this.theme.text3)
            .flexShrink(0)
        } else {
          Image($r('app.media.ic_settings_sync'))
            .width(16)
            .height(16)
            .fillColor(this.theme.text3)
            .objectFit(ImageFit.Contain)
            .flexShrink(0)
        }
      } else {
        if (this.value.length > 0) {
          Text(this.value)
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text3)
            .margin({ right: 6 })
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .constraintSize({ maxWidth: '42%' })
            .flexShrink(0)
        }
        Text('›')
          .fontSize(TypeScale.metric)
          .fontColor(this.theme.text3)
          .flexShrink(0)
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundColor(this.theme.surface)
    .onClick(() => {
      if (this.onItemClick) {
        this.onItemClick()
      }
    })
  }
}
