import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens, MotionHelper } from 'common'
import {
  DashboardService,
  DashboardSummary,
  DashboardHomeSnapshot,
  LocalDataStore,
  DashboardFrameCache,
  HomeActionItem,
  HomeActionBuckets,
  HomeInsight,
  HomeInsightInput,
  HomeInsights,
  DebtService,
  PaymentService,
  LiveViewService,
  WidgetUpdateService,
  UserService,
  AuthManager,
  SettingsService,
  AnalyticsService,
  SyncScheduler,
  PerfTrace,
  HomeSnapshotStore,
  QuoteService,
  NotificationService
} from 'service'
import { MonthlyPressure } from 'common'
import { PressureChart, Sparkline, remainingDebtTrendTag } from 'components'
import { EmptyState } from 'components'
import { SkeletonList } from 'components'
import { RepaySheetView } from 'components'
import { NotificationsInbox, unreadBadgeLabel } from 'components'
import { willClearAllAfterRepay } from 'service'
import { Utils } from 'common'
import { AppStorageKeys } from 'common'
import { Constants } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { Debt } from 'common'
import { fetchEffectiveTheme } from './common/ThemeLoader'
import { greetingName } from './common/SettingsDisplay'

/** 标题磨砂材质浮现的滚动阈值 vp */
const HEADER_BLUR_THRESHOLD: number = 8
/** 通知抽屉尚未测到高度时的离屏位移兜底 vp */
const DRAWER_HIDE_FALLBACK: number = 720

@Component
export struct DashboardTab {
  @State summary: DashboardSummary = new DashboardSummary()
  @State pressureData: MonthlyPressure[] = []
  @State debtTrend: number[] = []
  @State actionBuckets: HomeActionBuckets = new HomeActionBuckets()
  @State theme: ThemeColors = ThemeManager.DARK
  @State loading: boolean = true
  /** 首页非业务励志副文（组合句式 + 严选成句） */
  @State private subtitleQuote: string = ''
  /** 首载骨架：仅首次进入显示，listRefreshToken 刷新不重播 */
  @State private firstLoad: boolean = true
  @State monthPaid: number = 0
  @StorageProp(AppStorageKeys.TOP_SAFE_HEIGHT) topSafe: number = 0
  /** 防窥脱敏态：系统检测到窥视时金额/名称/日期打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  /** 通知未读数：链 NotificationsInbox 写入，驱动铃铛红点 */
  @StorageProp(AppStorageKeys.NOTIFICATION_UNREAD_COUNT) unreadCount: number = 0
  /** 问候语里的名字：资料页昵称 > 云端昵称 > 邮箱前缀，空 = 只留问候语 */
  @State displayName: string = ''
  /** 资料页改昵称/头像后 bump；Tab 内组件无 onPageShow，靠此刷新问候名 */
  @StorageLink(AppStorageKeys.PROFILE_REVISION) @Watch('onProfileRevision') profileRevision: number = 0
  @StorageLink('ambientLux') @Watch('onLuxChange') lux: number = -1
  @StorageLink('systemDark') @Watch('onLuxChange') systemDark: boolean = false
  @StorageLink('themeRevision') @Watch('onThemeRevision') themeRevision: number = 0
  @StorageLink('listRefreshToken') @Watch('onListRefresh') listRefreshToken: number = 0
  /** 行动桶是否已 hydrate（避免帧秒开时误显空清单） */
  @State private actionsReady: boolean = false
  /** 还款 Sheet（对齐 DebtsTab） */
  @State private showRepaySheet: boolean = false
  @State private repayDebtItem: Debt | null = null
  /** 通知抽屉：从屏幕顶部下拉盖住问候语，点关闭/遮罩收起 */
  @State private showNotificationsDrawer: boolean = false
  @State private drawerOpen: boolean = false
  @State private drawerOffsetY: number = -DRAWER_HIDE_FALLBACK
  @State private drawerMaskOpacity: number = 0
  @State private drawerPanelH: number = 0
  @State private bellPressed: boolean = false
  private drawerAnimTimer: number = -1
  private drawerGen: number = 0
  /** 活跃负债数（全清仪式 Toast 判断） */
  @State private activeDebtCountForRepay: number = 0
  @State private completedDebtCountForRepay: number = 0
  @StorageProp('mainTabIndex') @Watch('onMainTabForEnter') mainTabForEnter: number = 0
  private lastHandledRefreshToken: number = 0
  private loadSeq: number = 0
  /** 内容区滚动控制器：切入本 Tab 时回到顶部 */
  private contentScroller: Scroller = new Scroller()
  /** 金额主舞台入场（可打断） */
  @State private stageOpacity: number = 0
  @State private stageOffsetY: number = MotionTokens.objectRevealOffsetY
  @State private stageScale: number = MotionTokens.objectRevealScaleFrom
  private stageRevealPlayed: boolean = false
  /** 滚过阈值：悬浮标题磨砂材质浮现 */
  @State private headerScrolled: boolean = false
  /** 悬浮标题实测高度（含状态栏避让），滚动内容据此留出顶部空间 */
  @State private headerHeight: number = 0
  /** 首页洞察：loadData 时算一次，build 只读 */
  @State private insightList: HomeInsight[] = []
  /** 待还总览右侧走势图：与「下月…预计还清」次要列同高、铺满剩余宽 */
  @State private heroChartW: number = 156
  @State private heroChartH: number = 96

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.loadInitialQuote()
    this.loadTheme(false)
    this.loadDisplayName()
    this.applyStoreOrDiskFrame()
    this.loadData()
    this.loadUnreadCount()
    this.lastHandledRefreshToken = this.listRefreshToken
  }

  aboutToDisappear() {
    if (this.drawerAnimTimer !== -1) {
      clearTimeout(this.drawerAnimTimer)
      this.drawerAnimTimer = -1
    }
  }

  private loadUnreadCount(): void {
    NotificationService.getUnreadCount().then((c: number) => {
      AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_UNREAD_COUNT, c)
    }).catch(() => {})
  }

  private unreadBadgeText(): string {
    return unreadBadgeLabel(this.unreadCount)
  }

  private goNotifications(): void {
    if (this.showNotificationsDrawer && this.drawerOpen) {
      this.closeNotificationsDrawer()
      return
    }
    this.openNotificationsDrawer()
  }

  private drawerHiddenY(): number {
    if (this.drawerPanelH > 0) {
      return this.drawerPanelH
    }
    return DRAWER_HIDE_FALLBACK
  }

  private openNotificationsDrawer(): void {
    if (this.drawerAnimTimer !== -1) {
      clearTimeout(this.drawerAnimTimer)
      this.drawerAnimTimer = -1
    }
    this.drawerGen += 1
    const gen = this.drawerGen
    this.drawerOffsetY = -this.drawerHiddenY()
    this.drawerMaskOpacity = 0
    this.drawerOpen = false
    this.showNotificationsDrawer = true
    this.drawerAnimTimer = setTimeout(() => {
      this.drawerAnimTimer = -1
      if (gen !== this.drawerGen) {
        return
      }
      this.getUIContext().animateTo({
        duration: MotionTokens.drawerEnterDuration,
        curve: Curve.EaseOut
      }, () => {
        if (gen !== this.drawerGen) {
          return
        }
        this.drawerOffsetY = 0
        this.drawerMaskOpacity = 1
        this.drawerOpen = true
      })
    }, MotionHelper.LIST_REVEAL_FRAME_MS)
  }

  private closeNotificationsDrawer(): void {
    if (!this.showNotificationsDrawer) {
      return
    }
    this.drawerGen += 1
    const gen = this.drawerGen
    this.drawerOpen = false
    this.getUIContext().animateTo({
      duration: MotionTokens.sheetDuration,
      curve: Curve.EaseIn,
      onFinish: () => {
        if (gen === this.drawerGen) {
          this.showNotificationsDrawer = false
        }
      }
    }, () => {
      this.drawerOffsetY = -this.drawerHiddenY()
      this.drawerMaskOpacity = 0
    })
  }

  private loadInitialQuote(): void {
    this.subtitleQuote = QuoteService.getCachedQuote()
    QuoteService.fetchNextQuote().then((fresh: string) => {
      if (fresh && fresh.length > 0) {
        this.subtitleQuote = fresh
      }
    })
  }

  private playStageReveal(): void {
    // 冷启动首屏：直接到位，省 300ms 动效与整卡重建
    if (!this.stageRevealPlayed) {
      this.stageRevealPlayed = true
      this.stageOpacity = 1
      this.stageOffsetY = 0
      this.stageScale = 1
      return
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.objectRevealDuration,
      curve: Curve.EaseOut
    }, () => {
      this.stageOpacity = 1
      this.stageOffsetY = 0
      this.stageScale = 1
    })
  }

  /** 有进程内投影 / 落盘帧 / RDB 物化快照时先展示，跳过首屏 skeleton */
  private applyStoreOrDiskFrame(): void {
    const cached = LocalDataStore.getSummary()
    if (cached !== null) {
      this.summary = cached
      const pressure = LocalDataStore.getPressure()
      if (pressure !== null) {
        this.pressureData = pressure
      }
      const trend = LocalDataStore.getDebtTrend()
      if (trend !== null) {
        this.debtTrend = trend
      }
      const paid = LocalDataStore.getMonthPaid()
      if (paid >= 0) {
        this.monthPaid = paid
      }
      this.loading = false
      this.firstLoad = false
      this.rebuildInsights()
      if (this.summary.thisMonthDue > 0 || this.summary.remainingDebt > 0) {
        this.playStageReveal()
      }
      return
    }
    const uid = UserService.getCurrentUserId()
    LocalDataStore.loadDashboardFrame(uid).then((frame) => {
      if (frame !== null && this.firstLoad) {
        this.applyFrameCache(frame)
        return
      }
      // Preferences 无帧：读 RDB 物化快照
      HomeSnapshotStore.load(uid).then((snap) => {
        if (snap !== null && this.firstLoad) {
          this.applyFrameCache(snap)
        }
      })
    })
  }

  private applyFrameCache(frame: DashboardFrameCache): void {
    const s = new DashboardSummary()
    frame.applyTo(s)
    this.summary = s
    this.monthPaid = frame.monthPaid
    this.loading = false
    this.firstLoad = false
    this.rebuildInsights()
    if (s.thisMonthDue > 0 || s.remainingDebt > 0) {
      this.playStageReveal()
    }
  }

  private onMainTabForEnter(): void {
    if (this.mainTabForEnter === 0) {
      // 切入首页：内容回到顶部（切前可能停在滚动中段）
      this.resetScrollToTop()
      if (this.listRefreshToken !== this.lastHandledRefreshToken) {
        this.lastHandledRefreshToken = this.listRefreshToken
        this.loadData()
      }
    }
  }

  /** 切入本 Tab：内容滚回顶部；Scroll 未挂载时静默忽略 */
  private resetScrollToTop(): void {
    try {
      this.contentScroller.scrollEdge(Edge.Top)
    } catch (_err) {
    }
    this.headerScrolled = false
  }

  /** 滚过阈值浮现标题磨砂材质，回顶淡出；只在跨越时置态，不逐帧刷新 */
  private onContentDidScroll(): void {
    const scrolled = this.contentScroller.currentOffset().yOffset > HEADER_BLUR_THRESHOLD
    if (scrolled !== this.headerScrolled) {
      this.headerScrolled = scrolled
    }
  }

  private async loadDisplayName(): Promise<void> {
    try {
      // loadSession 会把 userId 写回内存态，须先于 getSettings 调用
      const session = await AuthManager.loadSession()
      const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
      this.displayName = greetingName(settings.profile_nickname,
        session === null ? '' : session.email)
    } catch {
      this.displayName = ''
    }
  }

  /** 资料页改昵称后刷新问候名 */
  onProfileRevision(): void {
    this.loadDisplayName()
  }

  private greetingHello(): string {
    const h = new Date().getHours()
    if (h < 5) {
      return '夜深了'
    }
    if (h < 11) {
      return '早上好'
    }
    if (h < 14) {
      return '中午好'
    }
    if (h < 18) {
      return '下午好'
    }
    return '晚上好'
  }

  private greetingTitle(): string {
    const hello = this.greetingHello()
    if (this.displayName.length > 0) {
      return hello + '，' + this.displayName
    }
    return hello
  }

  private onListRefresh(): void {
    if (this.mainTabForEnter !== 0) {
      return
    }
    this.lastHandledRefreshToken = this.listRefreshToken
    this.loadData()
    this.loadUnreadCount()
  }

  private onLuxChange(): void {
    this.loadTheme(false)
  }

  private onThemeRevision(): void {
    this.loadTheme(false)
  }

  private async loadTheme(_animate: boolean): Promise<void> {
    const next = await fetchEffectiveTheme(this.lux, this.systemDark)
    if (ThemeManager.isSame(this.theme, next)) {
      return
    }
    this.theme = next
  }

  private async loadData(): Promise<void> {
    const seq = this.loadSeq + 1
    this.loadSeq = seq
    const epochAtStart = LocalDataStore.getEpoch()
    if (this.firstLoad) {
      this.loading = true
    }
    if (seq !== this.loadSeq) {
      return
    }
    const uid = UserService.getCurrentUserId()
    try {
      // 三表一次读 + 内存派生，避免 summary/pressure/buckets 三次扫 debts
      const home: DashboardHomeSnapshot = await DashboardService.loadHome(uid)
      if (seq !== this.loadSeq) {
        return
      }
      this.summary = home.summary
      this.pressureData = home.pressure
      this.debtTrend = home.debtTrend
      this.actionBuckets = home.buckets
      this.actionsReady = true
      this.monthPaid = home.monthPaid
      this.activeDebtCountForRepay = home.summary.activeDebtCount
      this.completedDebtCountForRepay = home.summary.completedDebtCount
      if (LocalDataStore.isEpochCurrent(epochAtStart)) {
        LocalDataStore.setSummary(this.summary)
        LocalDataStore.setPressure(this.pressureData)
        LocalDataStore.setDebtTrend(this.debtTrend)
        LocalDataStore.setMonthPaid(this.monthPaid)
        LocalDataStore.persistDashboardFrame(this.summary, this.monthPaid, uid)
        const frame = DashboardFrameCache.fromSummary(this.summary, this.monthPaid)
        HomeSnapshotStore.save(uid, frame)
      }
      if (this.showAmountCard()) {
        this.playStageReveal()
      }
    } finally {
      if (seq === this.loadSeq) {
        this.loading = false
        this.firstLoad = false
        this.rebuildInsights()
        SyncScheduler.markHomeHydrated()
        PerfTrace.mark('T2_home_ready')
      }
    }
  }

  /** 切换主 Tab：0 首页 1 负债 2 订阅 3 账户 4 我的 */
  private goToMainTab(index: number): void {
    AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, index)
  }

  private hasBusinessData(): boolean {
    return this.summary.activeDebtCount > 0 ||
      this.summary.remainingDebt > 0 ||
      this.summary.subscriptionCount > 0 ||
      this.summary.creditAccountCount > 0 ||
      this.summary.completedDebtCount > 0
  }

  /**
   * 负债 hero：仅当有本月应还或总负债时展示。
   * 避免仅订阅/账户业务时出空债卡；主数字永不 ¥0。
   */
  private showAmountCard(): boolean {
    return this.summary.thisMonthDue > 0 || this.summary.remainingDebt > 0
  }

  /** true = 本月待还模式；false = 总负债模式（本月无应还） */
  private isMonthDueHeroMode(): boolean {
    return this.summary.thisMonthDue > 0
  }

  private debtHeroTitle(): string {
    return this.isMonthDueHeroMode() ? '本月待还' : '总负债'
  }

  private debtHeroAmount(): number {
    return this.isMonthDueHeroMode() ? this.summary.thisMonthDue : this.summary.remainingDebt
  }

  private compactMaskedMoney(fen: number): string {
    return Utils.maskIf(this.antiPeekMasked,
      Utils.formatMoneyCompact(fen), Utils.MASK_AMOUNT)
  }

  /** 行动卡：仅当存在需要处理或即将到期的行动项时展示，避免空卡 */
  private showActionCard(): boolean {
    return this.actionsReady && (this.needActionCount() > 0 || this.upcomingCount() > 0)
  }

  /**
   * 无行动清单时的底座洞察：一句话结论，不复述首页已可见事实。
   * 只在 loadData / 帧缓存落地时重算，不在 build 里扫表。
   */
  private rebuildInsights(): void {
    if (this.firstLoad || !this.actionsReady || this.showActionCard()) {
      this.insightList = []
      return
    }
    const uid = UserService.getCurrentUserId()
    const input = new HomeInsightInput()
    input.thisMonthDue = this.summary.thisMonthDue
    input.nextMonthDue = this.summary.nextMonthDue
    input.remainingDebt = this.summary.remainingDebt
    const debts = LocalDataStore.getDebts(uid)
    if (debts !== null) {
      input.debts = debts
    }
    const subs = LocalDataStore.getSubscriptions(uid)
    if (subs !== null) {
      input.subscriptions = subs
    }
    const accounts = LocalDataStore.getAccounts(uid)
    if (accounts !== null) {
      input.accounts = accounts
    }
    this.insightList = HomeInsights.build(input, this.pressureData)
  }

  private showInsightCard(): boolean {
    return HomeInsights.shouldShow(this.showActionCard(), this.insightList.length, this.firstLoad)
  }

  private showPressureSection(): boolean {
    if (!this.hasBusinessData()) {
      return false
    }
    for (let i = 0; i < this.pressureData.length; i++) {
      if (this.pressureData[i].amount > 0) {
        return true
      }
    }
    return false
  }

  private isCompletelyEmpty(): boolean {
    return !this.loading && !this.hasBusinessData()
  }

  private needActionCount(): number {
    return this.actionBuckets.needAction.length
  }

  private upcomingCount(): number {
    return this.actionBuckets.upcoming.length
  }

  private async openRepay(entityId: string): Promise<void> {
    try {
      const debt = await DebtService.getDebtById(entityId)
      if (debt === null) {
        AppToast.show(ErrorMessages.DEBT_STATUS_CHANGED, 1500)
        this.loadData()
        return
      }
      if (debt.status === 'completed') {
        AppToast.show(ErrorMessages.DEBT_ALREADY_SETTLED, 1500)
        return
      }
      this.repayDebtItem = debt
      this.showRepaySheet = true
    } catch {
      AppToast.show(ErrorMessages.REPAY_FAILED, 1500)
    }
  }

  /** 对齐 DebtsTab.doRepay */
  private async doRepay(debt: Debt, mode: 'period' | 'payoff'): Promise<void> {
    const fresh: Debt | null = await DebtService.getDebtById(debt.id)
    if (!fresh || fresh.status === 'completed') {
      AppToast.show(ErrorMessages.DEBT_STATUS_CHANGED, 1500)
      this.loadData()
      return
    }
    const skipToast = willClearAllAfterRepay(
      this.activeDebtCountForRepay,
      mode,
      fresh.remaining_periods,
      this.completedDebtCountForRepay + 1
    )
    try {
      if (mode === 'period') {
        // 绝对期号；total_periods=0 时至少记为 1（与 generatePaymentSchedule startPeriod 对齐）
        const period = fresh.total_periods > 0
          ? Math.max(1, fresh.total_periods - fresh.remaining_periods + 1)
          : 1
        await PaymentService.markPeriodPaid(fresh, period)
        if (!skipToast) {
          AppToast.show(ErrorMessages.REPAY_PERIOD_OK, 1500)
        }
      } else {
        await PaymentService.payoffDebt(fresh)
        if (!skipToast) {
          AppToast.show(ErrorMessages.REPAY_PAYOFF_OK, 1500)
        }
      }
      await LiveViewService.refresh()
      await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      Constants.notifyListRefresh()
      this.loadData()
    } catch (_e) {
      AnalyticsService.trackRepayFail('unknown')
      AppToast.show(ErrorMessages.REPAY_FAILED, 1500)
    }
  }

  private onActionPrimary(item: HomeActionItem): void {
    const action = item.primaryAction === 'record_payment' ? 'repay' : 'view'
    AnalyticsService.trackHomeActionTap(item.kind, item.urgency, action)
    if (item.primaryAction === 'record_payment' && item.kind === 'debt') {
      this.openRepay(item.entityId)
      return
    }
    this.viewEntity(item)
  }

  private viewEntity(item: HomeActionItem): void {
    if (item.kind === 'debt') {
      AppStorage.setOrCreate(AppStorageKeys.OPEN_DEBT_DETAIL_ID, item.entityId)
      this.goToMainTab(1)
      return
    }
    if (item.kind === 'subscription') {
      AppStorage.setOrCreate(AppStorageKeys.OPEN_SUB_DETAIL_ID, item.entityId)
      this.goToMainTab(2)
      return
    }
    if (item.kind === 'account') {
      AppStorage.setOrCreate(AppStorageKeys.OPEN_ACCOUNT_DETAIL_ID, item.entityId)
      this.goToMainTab(3)
    }
  }

  private subtitleColor(item: HomeActionItem): ResourceColor {
    if (item.urgency === 'overdue') {
      return this.theme.statusDanger()
    }
    if (item.urgency === 'today') {
      return this.theme.amber
    }
    return this.theme.text2
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.isCompletelyEmpty()) {
        // 与 Debts/订阅/账户一致：悬浮标题 + EmptyState 在标题下方区域居中
        // 底栏避让只由 EmptyState 内部 bottomClearance 处理，禁止外层再垫一层（否则插画偏上）
        Column() {
          EmptyState({
            theme: this.theme,
            showIllustration: true,
            objectStage: true,
            watermark: '',
            kicker: '',
            title: '暂无记录',
            subtitle: '记录放在这里，清楚摊开',
            hint: ''
          })
            .width('100%')
            .layoutWeight(1)
        }
        .width('100%')
        .height('100%')
        .padding({ top: this.headerHeight })
      } else {
        // 内容：金额主舞台优先，清单/图卡退为底座；全高滚动从标题下方穿过
        Scroll(this.contentScroller) {
          Column({ space: 12 }) {
            if (this.firstLoad) {
              this.homeSkeletonBuilder()
            } else {
              if (this.showAmountCard()) {
                this.debtCardBuilder()
              }
              if (this.showActionCard()) {
                this.actionCardBuilder()
              }
              if (this.showPressureSection()) {
                this.pressureCardBuilder()
              }
              if (this.showInsightCard()) {
                this.insightCardBuilder()
              }
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
          .constraintSize({ minHeight: '100%' })
          .padding({
            left: this.theme.pageHorizontalPadding,
            right: this.theme.pageHorizontalPadding,
            top: this.headerHeight + this.theme.spaceSm,
            // CLEARANCE 已含底栏+呼吸间距；HdsTabs 自避让安全区，勿再叠 bottomSafe（双重计算）
            bottom: Constants.FLOATING_TAB_CLEARANCE
          })
        }
        .width('100%')
        .height('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
        .onDidScroll(() => this.onContentDidScroll())
      }

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

        Column() {
          this.dashboardHeaderBuilder()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding({
          left: this.theme.pageHorizontalPadding,
          right: this.theme.spaceSm,
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

      if (this.showNotificationsDrawer) {
        this.notificationsDrawerOverlayBuilder()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
    .animation({ duration: MotionTokens.themeCrossfadeDuration, curve: Curve.EaseOut })
    .bindSheet(this.showRepaySheet, this.repaySheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      dragBar: false,
      radius: LengthMetrics.vp(this.theme.sheetRadius),
      showClose: false,
      backgroundColor: this.theme.sheetBackground() as string,
      blurStyle: BlurStyle.NONE,
      maskColor: this.theme.sheetMaskColor(),
      shadow: this.theme.sheetShadowOptions(),
      onDisappear: () => {
        this.showRepaySheet = false
        this.repayDebtItem = null
      }
    })
  }

  @Builder
  homeSkeletonBuilder() {
    Column({ space: 12 }) {
      Column() {
        SkeletonList({ theme: this.theme, count: 4 })
      }
      .width('100%')
      .backgroundColor(this.theme.surface2)
      .borderRadius(this.theme.radiusXl)
      .border({ width: 1, color: this.theme.borderSoft })
      .clip(true)
      .shadow(this.theme.objectStageShadowOptions())
      Column()
        .width('100%')
        .height(120)
        .backgroundColor(this.theme.surface2)
        .borderRadius(this.theme.radiusXl)
        .border({ width: 1, color: this.theme.borderSoft })
        .shadow(this.theme.objectStageShadowOptions())
    }
    .width('100%')
  }

  @Builder
  dashboardHeaderBuilder() {
    // 与 DebtsTab 标题行同级字号（heroTitle），下方增加轻量鼓励副文（每次打开不重复）
    Row() {
      Column({ space: this.theme.spaceXs }) {
        Text(this.greetingTitle())
          .fontSize(TypeScale.heroTitle)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .letterSpacing(TypeScale.heroTitleSpacing)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')

        Text(this.subtitleQuote.length > 0 ? this.subtitleQuote : '保持节奏，稳步向前')
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .justifyContent(FlexAlign.Start)

      Stack({ alignContent: Alignment.TopEnd }) {
        Row() {
          Image($r('app.media.ic_bell'))
            .width(22)
            .height(22)
            .fillColor(this.showNotificationsDrawer ? this.theme.text : this.theme.text2)
            .objectFit(ImageFit.Contain)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)

        if (this.unreadBadgeText().length > 0) {
          Text(this.unreadBadgeText())
            .fontSize(TypeScale.captionSm)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.dangerForeground())
            .backgroundColor(this.theme.red)
            .borderRadius(this.theme.radiusPill)
            .constraintSize({ minWidth: 16, minHeight: 16 })
            .padding({ left: 5, right: 5 })
            .textAlign(TextAlign.Center)
            .margin({ top: 1, right: 1 })
        }
      }
      .width(52)
      .height(40)
      .margin({ left: this.theme.spaceXs })
      .flexShrink(0)
      .scale({
        x: this.bellPressed ? MotionTokens.pressScaleLight : 1,
        y: this.bellPressed ? MotionTokens.pressScaleLight : 1
      })
      .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.bellPressed = true
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.bellPressed = false
        }
      })
      .onClick(() => this.goNotifications())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  notificationsDrawerOverlayBuilder() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.sheetMaskColor())
        .opacity(this.drawerMaskOpacity)
        .onClick(() => this.closeNotificationsDrawer())

      Column() {
        NotificationsInbox({
          theme: this.theme,
          showSheetChrome: true,
          dockTop: true,
          emptyIcon: $r('app.media.ic_bell'),
          onClose: () => {
            this.closeNotificationsDrawer()
          },
          onNavigate: () => {
            this.closeNotificationsDrawer()
          }
        })
      }
      .width('100%')
      .height('80%')
      .padding({ top: this.topSafe })
      .backgroundColor(this.theme.sheetBackground())
      .borderRadius({
        bottomLeft: this.theme.sheetRadius,
        bottomRight: this.theme.sheetRadius
      })
      .border({
        width: { bottom: 0.5, left: 0, right: 0, top: 0 },
        color: this.theme.sheetEdgeColor()
      })
      .shadow(this.theme.sheetShadowOptions())
      .clip(true)
      .translate({ y: this.drawerOffsetY })
      .onAreaChange((_oldArea: Area, newArea: Area) => {
        const measured = Number(newArea.height)
        if (measured > 0 && measured !== this.drawerPanelH) {
          this.drawerPanelH = measured
        }
      })
    }
    .width('100%')
    .height('100%')
  }

  /**
   * 金额主舞台（表盘感）：
   * - 唯一焦点数字 heroNumberDial；下月/总待还/还清为次要列
   * - 右走势图与次要列同高；悬浮阴影走 objectStage（首页卡片共用）
   */
  @Builder
  debtCardBuilder() {
    Column() {
      Row() {
        Text('待还总览')
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text)
          .layoutWeight(1)
          .maxLines(1)

        if (this.summary.overdueCount > 0) {
          Text('逾期 ' + this.summary.overdueCount + ' 笔')
            .fontSize(TypeScale.captionSm)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.statusDanger())
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(this.theme.statusDangerBg())
            .borderRadius(this.theme.radiusPill)
            .flexShrink(0)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: this.theme.spaceMd })

      Column({ space: this.theme.spaceXxs }) {
        Text(this.debtHeroTitle())
          .fontSize(TypeScale.captionSm)
          .fontColor(this.theme.text3)
        if (this.antiPeekMasked) {
          Text(Utils.MASK_AMOUNT)
            .fontSize(TypeScale.heroNumberDial)
            .fontWeight(FontWeight.Bold)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
            .letterSpacing(TypeScale.heroNumberSpacing)
            .maxLines(1)
        } else {
          // 单 Text 多 Span：¥ 与数字共享一条基线、字形贴底；Row 包围盒贴底会让小字沉到基线下
          Text() {
            Span('¥' + Utils.YUAN_GAP)
              .fontSize(TypeScale.heroNumberSymbol)
              .fontWeight(FontWeight.Bold)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.theme.text)
            Span(Utils.formatMoney(this.debtHeroAmount(), false))
              .fontSize(TypeScale.heroNumberDial)
              .fontWeight(FontWeight.Bold)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.theme.text)
              .letterSpacing(TypeScale.heroNumberSpacing)
          }
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        }
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .margin({ bottom: this.theme.spaceSm })

      // 走势图只与「下月…预计还清」次要列同高，不对齐主数字
      Row() {
        Column({ space: this.theme.spaceSm }) {
          if (this.isMonthDueHeroMode()) {
            Column({ space: this.theme.spaceXxs }) {
              Text('下月')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
              Text(this.compactMaskedMoney(this.summary.nextMonthDue))
                .fontSize(TypeScale.bodySm)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)

            Column({ space: this.theme.spaceXxs }) {
              Text('总待还')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
              Text(this.compactMaskedMoney(this.summary.remainingDebt))
                .fontSize(TypeScale.bodySm)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
          } else {
            // 「总负债」模式：主数字是 remainingDebt；副列「本月」= thisMonthDue 恒为 0
            // 不再裸出 0，标为「已还清」；未来月份（如下月）为 0 仍按 0 展示
            Column({ space: this.theme.spaceXxs }) {
              Text('本月')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
              if (this.summary.thisMonthDue === 0) {
                Text(this.antiPeekMasked ? Utils.MASK_AMOUNT : '已还清')
                  .fontSize(TypeScale.bodySm)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.antiPeekMasked ? this.theme.text : this.theme.positiveGreen)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              } else {
                Text(this.compactMaskedMoney(this.summary.thisMonthDue))
                  .fontSize(TypeScale.bodySm)
                  .fontWeight(FontWeight.Medium)
                  .fontFamily(TypeScale.FONT_MONO)
                  .fontColor(this.theme.text)
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .alignItems(HorizontalAlign.Start)

            Column({ space: this.theme.spaceXxs }) {
              Text('下月')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
              Text(this.compactMaskedMoney(this.summary.nextMonthDue))
                .fontSize(TypeScale.bodySm)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
          }

          if (this.summary.payoffDate.length > 0) {
            Column({ space: this.theme.spaceXxs }) {
              Text('预计还清')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
              Text(Utils.maskIf(this.antiPeekMasked, this.summary.payoffDate))
                .fontSize(TypeScale.bodySm)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
          }
        }
        .layoutWeight(1)
        .constraintSize({ minWidth: 0 })
        .alignItems(HorizontalAlign.Start)
        .onAreaChange((_oldArea: Area, newArea: Area) => {
          this.syncHeroChartHeight(Number(newArea.height))
        })

        if (this.heroTrendValues().length >= 2) {
          Stack({ alignContent: Alignment.TopEnd }) {
            Sparkline({
              values: this.heroTrendValues(),
              theme: this.theme,
              colorful: true,
              chartWidth: this.heroChartW,
              chartHeight: this.heroChartH
            })
              .align(Alignment.Center)

            if (this.showHeroTrendTag()) {
              Text(this.heroTrendTagText())
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.statusTagFg(this.heroTrendTagRole()))
                .maxLines(1)
                .padding({
                  left: this.theme.spaceXs,
                  right: this.theme.spaceXs,
                  top: this.theme.spaceXxs,
                  bottom: this.theme.spaceXxs
                })
                .backgroundColor(this.theme.statusTagBg(this.heroTrendTagRole()))
                .borderRadius(this.theme.radiusPill)
                .align(Alignment.TopEnd)
            }
          }
          .layoutWeight(1)
          .height(this.heroChartH)
          .margin({ left: this.theme.spaceSm })
          .constraintSize({ minWidth: 0 })
          .onAreaChange((_oldArea: Area, newArea: Area) => {
            this.syncHeroChartWidth(Number(newArea.width))
          })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding(16)
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusXl)
    .border({ width: 1, color: this.theme.borderSoft })
    .clip(true)
    .shadow(this.theme.objectStageShadowOptions())
    .opacity(this.stageOpacity)
    .translate({ y: this.stageOffsetY })
    .scale({ x: this.stageScale, y: this.stageScale })
  }

  private heroTrendValues(): number[] {
    return this.debtTrend
  }

  private syncHeroChartHeight(h: number): void {
    if (h < 8) {
      return
    }
    const next = Math.round(h)
    if (Math.abs(next - this.heroChartH) > 1) {
      this.heroChartH = next
    }
  }

  private syncHeroChartWidth(w: number): void {
    if (w < 8) {
      return
    }
    const next = Math.round(w)
    if (Math.abs(next - this.heroChartW) > 1) {
      this.heroChartW = next
    }
  }

  /**
   * 需要关注：仅 need/upcoming 非空时渲染；悬浮阴影与待还总览同 objectStage
   */
  @Builder
  actionCardBuilder() {
    Column() {
      Text('需要关注')
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.text)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: this.theme.spaceXs })

      if (this.needActionCount() > 0) {
        ForEach(this.actionBuckets.needAction, (item: HomeActionItem, index: number) => {
          this.actionRowBuilder(
            item,
            index < this.needActionCount() - 1 || this.upcomingCount() > 0
          )
        }, (item: HomeActionItem) => item.id)
      }

      if (this.upcomingCount() > 0) {
        ForEach(this.actionBuckets.upcoming, (item: HomeActionItem, index: number) => {
          this.actionRowBuilder(item, index < this.upcomingCount() - 1)
        }, (item: HomeActionItem) => item.id)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusLg)
    .border({ width: 1, color: this.theme.borderSoft })
    .clip(true)
    .shadow(this.theme.objectStageShadowOptions())
  }

  @Builder
  actionRowBuilder(item: HomeActionItem, showDivider: boolean) {
    Column() {
      Row() {
        Column({ space: 4 }) {
          Text(Utils.maskIf(this.antiPeekMasked, item.title))
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
          Text(Utils.maskIf(this.antiPeekMasked, item.subtitle))
            .fontSize(TypeScale.caption)
            .fontColor(this.subtitleColor(item))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: this.theme.spaceXs })

        if (item.primaryAction === 'record_payment') {
          Text('还款')
            .fontSize(TypeScale.caption)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.onPrimary)
            .padding({
              left: this.theme.spaceXs + 2,
              right: this.theme.spaceXs + 2,
              top: this.theme.spaceXxs + 2,
              bottom: this.theme.spaceXxs + 2
            })
            .backgroundColor(this.theme.primary)
            .borderRadius(this.theme.radiusMd)
            .onClick(() => {
              this.onActionPrimary(item)
            })
        } else {
          Text('查看')
            .fontSize(TypeScale.caption)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
            .padding({
              left: this.theme.spaceXs + 2,
              right: this.theme.spaceXs + 2,
              top: this.theme.spaceXxs + 2,
              bottom: this.theme.spaceXxs + 2
            })
            .border({ width: 1, color: this.theme.borderSoft })
            .borderRadius(this.theme.radiusMd)
            .onClick(() => {
              this.onActionPrimary(item)
            })
        }
      }
      .width('100%')
      .padding({
        top: this.theme.spaceSm,
        bottom: this.theme.spaceSm
      })
      .alignItems(VerticalAlign.Center)
      .onClick(() => {
        this.onActionPrimary(item)
      })

      if (showDivider) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(this.theme.borderSoft)
      }
    }
    .width('100%')
  }

  private showHeroTrendTag(): boolean {
    return remainingDebtTrendTag(this.heroTrendValues()) !== null
  }

  private heroTrendTagText(): string {
    const tag = remainingDebtTrendTag(this.heroTrendValues())
    if (tag === null) {
      return ''
    }
    // 防窥脱敏：保留 ↑/↓ 方向（无敏感信息），把金额替换为占位
    if (this.antiPeekMasked) {
      const arrow = tag.text.charAt(0)
      return arrow + ' ' + Utils.MASK_AMOUNT
    }
    return tag.text
  }

  private heroTrendTagRole(): string {
    const tag = remainingDebtTrendTag(this.heroTrendValues())
    return tag !== null ? tag.role : 'off'
  }

  @Builder
  pressureCardBuilder() {
    Column() {
      Text('未来待还趋势')
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.text)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ bottom: this.theme.spaceMd })

      PressureChart({
        data: this.pressureData,
        theme: this.theme,
        framed: false,
        chartHeight: 108,
        showValues: true,
        skipGrow: true
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusLg)
    .border({ width: 1, color: this.theme.borderSoft })
    .clip(true)
    .shadow(this.theme.objectStageShadowOptions())
  }

  /**
   * AI 洞察：底座卡，与趋势图同级；每条一句话结论，单行不展开。
   */
  @Builder
  insightCardBuilder() {
    Column() {
      // 头部：图标+标题
      Row({ space: this.theme.spaceXs }) {
        Image($r('app.media.ic_ai_spark'))
          .width(16)
          .height(16)
          .objectFit(ImageFit.Contain)
          .flexShrink(0)
        Text('AI 洞察')
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text)
          .maxLines(1)
      }
      .alignItems(VerticalAlign.Center)
      .margin({ bottom: this.theme.spaceSm })

      // 内容区：一行一条结论
      Column({ space: this.theme.spaceXs }) {
        ForEach(this.insightList, (item: HomeInsight) => {
          Row() {
            if (item.tag.length > 0) {
              Text(item.tag)
                .fontSize(TypeScale.kicker)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.aiAccent)
                .padding({
                  left: this.theme.spaceXs,
                  right: this.theme.spaceXs,
                  top: 6,
                  bottom: 6
                })
                .backgroundColor(this.theme.aiAccentSoft)
                .borderRadius(this.theme.radiusSm)
                .margin({ right: this.theme.spaceXs })
                .flexShrink(0)
            }
            Text(item.title)
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .padding({
            left: this.theme.spaceXs,
            right: this.theme.spaceXs,
            top: 10,
            bottom: 10
          })
          .backgroundColor(this.theme.isDarkCanvas() ? this.theme.surface : this.theme.chip)
          .borderRadius(this.theme.radiusMd)
          .border({ width: 1, color: this.theme.borderSoft })
        }, (item: HomeInsight) => item.id)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusLg)
    .border({ width: 1, color: this.theme.borderSoft })
    .clip(true)
    .shadow(this.theme.objectStageShadowOptions())
  }

  @Builder
  repaySheetBuilder() {
    if (this.repayDebtItem !== null) {
      RepaySheetView({
        theme: this.theme,
        debt: this.repayDebtItem as Debt,
        onConfirmRepay: () => {
          const d = this.repayDebtItem
          this.showRepaySheet = false
          if (d !== null) {
            this.doRepay(d, 'period')
          }
        },
        onPayoff: () => {
          const d = this.repayDebtItem
          this.showRepaySheet = false
          if (d !== null) {
            this.doRepay(d, 'payoff')
          }
        },
        onCancel: () => {
          this.showRepaySheet = false
        }
      })
    }
  }
}
