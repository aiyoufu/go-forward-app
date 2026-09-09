import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens, ArrayDataSource } from 'common'
import { Debt } from 'common'
import { Subscription } from 'common'
import { DebtService } from 'service'
import { SubscriptionService } from 'service'
import { DebtReceipt } from 'service'
import { PaymentService } from 'service'
import { CreditAccountService } from 'service'
import { CreditAccount } from 'common'
import { UserService } from 'service'
import { DebtCard, debtStatusTagText, debtStatusTagRole, formatDueYmd } from 'components'
import { SegmentProgressBar } from 'components'
import { LiveViewService } from 'service'
import { WidgetUpdateService } from 'service'
import { CalculationService } from 'service'
import { PlatformService, IconPickerService } from 'service'
import { Utils } from 'common'
import { Constants } from 'common'
import { SwipeEditDeleteActions } from 'components'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton } from 'components'
import { RepaySheetView } from 'components'
import { DetailSheetView, DetailSheetConfig, DetailField } from 'components'
import { EmptyState } from 'components'
import { FilterSortMenuPanel } from 'components'
import { SkeletonList } from 'components'
import { DebtsFilterSort } from 'service'
import { LocalDataStore } from 'service'
import { AnalyticsService } from 'service'
import { AppStorageKeys } from 'common'
import { AppRouter, RouteNames } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { willClearAllAfterRepay } from 'service'
import { ListSelection, runBatchDelete } from './common/ListSelection'
import { BatchSelectHeader, BatchActionOverlay } from './common/BatchShell'
import { ListReveal, HeroCounter, listExitTransition, listItemRevealProgress, listItemRevealTranslateY, listItemRevealNoImplicit, scrollListToTopSilent, topBarFadeRatio } from './common/ListReveal'
import { fetchEffectiveTheme } from './common/ThemeLoader'

@Component
export struct DebtsTab {
  @State debts: Debt[] = []
  /** 筛选结果；UI 列表走 listSource + LazyForEach 虚拟化 */
  @State filteredDebts: Debt[] = []
  /** LazyForEach 数据源：仅可视区挂载行（@Reusable DebtCard 配合回收） */
  private listSource: ArrayDataSource = new ArrayDataSource()
  @State allDebts: Debt[] = []
  @State subscriptions: Subscription[] = []
  @State theme: ThemeColors = ThemeManager.DARK
  @State searchQuery: string = ''
  @State filterIndex: number = 0
  @State sortIndex: number = 0
  /** 标题栏右侧：状态/排序展开面板（悬浮卡片，不挤压内容） */
  @State showFilterPanel: boolean = false
  @State showSortPanel: boolean = false
  @State loadingMore: boolean = false
  @State hasMore: boolean = true
  /** 首载骨架：仅首次进入显示，后续刷新不重播 */
  @State private loading: boolean = true
  /** 滚动驱动顶栏背景透明度 0→1 */
  @State private topBarAlpha: number = 0
  private readonly topBarFadeDistance: number = 80
  @StorageProp(AppStorageKeys.TOP_SAFE_HEIGHT) topSafe: number = 0
  /** 防窥脱敏态：系统检测到窥视时主数字/预览指标打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  /** 设置「显示分享」：关则标题栏不渲染分享按钮 */
  @StorageProp(AppStorageKeys.SHARE_ENABLED) shareEnabled: boolean = true
  @State isRefreshing: boolean = false
  @State showSheet: boolean = false
  @State isRepaySheet: boolean = false
  @State repayDebtItem: Debt | null = null
  @State isDetailSheet: boolean = false
  /** 当前详情对应的负债（详情内「还款」用） */
  @State detailDebtItem: Debt | null = null
  @State detailConfig: DetailSheetConfig = new DetailSheetConfig()
  @State sheetConfig: SheetDialogConfig = new SheetDialogConfig()
  private sheetCallback: (index: number) => void = () => {}
  // 摘要数据
  @State totalBalance: number = 0
  @State thisMonthDue: number = 0
  @State nextMonthDue: number = 0
  @State furthestEndDate: string = ''
  @State remainingMonths: number = 0
  @State overallProgress: number = 0
  @State totalPrincipal: number = 0
  /** 是否存在任意还款记录；用于「本月待还 = 0」时区分「已还清」与「无待还」 */
  @State hasPaymentRecords: boolean = false
  private filters: string[] = ['全部', '进行中', '已逾期', '已暂停']
  private sorts: string[] = ['按余额', '按还清日']
  private readonly PAGE_SIZE: number = 20
  private currentPage: number = 0
  @StorageLink('ambientLux') @Watch('onLuxChange') lux: number = -1
  @StorageLink('systemDark') @Watch('onLuxChange') systemDark: boolean = false
  @StorageLink('themeRevision') @Watch('onThemeRevision') themeRevision: number = 0
  private searchTimer: number = -1
  private lastActiveCount: number = 0
  private suppressCelebration: boolean = false
  /** 本页刚本地更新过，忽略紧随其后的 listRefresh 自刷新（只让其它 Tab 吃通知） */
  private suppressNextListRefresh: boolean = false
  @StorageLink('listRefreshToken') @Watch('onListRefresh') listRefreshToken: number = 0
  @State swipingDebtId: string = ''
  /** 批量选择模式 */
  @State selectMode: boolean = false
  /** 已选 id（数组重新赋值驱动 ForEach 选中态刷新） */
  @State selectedIds: string[] = []
  /** 与 MainPage 同步多选态，使返回手势可先退多选 */
  @StorageLink('listSelectMode') @Watch('onSelectModeRemoteChange') selectModeSync: boolean = false
  /**
   * 列表逐项缓现（Apple per-row 模型，bpta-fair-use-animation）
   * - 每项仅 opacity + translate（图形变换），按 index 错峰
   * - 进入 Tab 播一次；离开无动画复位；滚动/刷新不重播
   */
  @State private revealT: number = 0
  private listReveal: ListReveal = new ListReveal()
  @State private heroCountT: number = 1
  private heroCounter: HeroCounter = new HeroCounter()
  private listScroller: ListScroller = new ListScroller()
  @StorageProp('mainTabIndex') @Watch('onTabChange') mainTabIndex: number = 0
  /** 并发 loadData 序号：仅最新一次可写 UI / 投影，避免切 Tab 时旧查询盖回导入前数据 */
  private loadSeq: number = 0
  private lastHandledRefreshToken: number = 0

  private onTabChange(): void {
    this.showFilterPanel = false
    this.showSortPanel = false
    this.exitSelectMode()
    this.closeAllSwipes()
    if (this.mainTabIndex === 1) {
      // 切入本 Tab：列表回到顶部（切前可能停在滚动中段）
      this.resetListScrollToTop()
      const stale = this.listRefreshToken !== this.lastHandledRefreshToken
      const alreadyShown = this.allDebts.length > 0 && this.revealT >= 1
      if (stale || !alreadyShown) {
        this.lastHandledRefreshToken = this.listRefreshToken
        // 缓现波由 loadData 在行挂载同 tick 起播，不在此提前起播（未命中缓存时波会先于行空跑，入场看似自底反向）
        this.loadData(true)
        this.playHeroCount()
      }
    } else {
      // 离开本 Tab：清空搜索词并立即重过滤，切回时恢复全量数据（避免停留在「无匹配结果」）
      this.resetSearchState()
      this.resetListRevealSilent()
    }
  }

  /** 离开本 Tab：清空搜索词并立即重过滤，列表恢复全量数据 */
  private resetSearchState(): void {
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer)
      this.searchTimer = -1
    }
    if (this.searchQuery.length === 0) {
      return
    }
    this.searchQuery = ''
    this.applyFilterSort()
  }

  /** 切入本 Tab：无动画回顶，避免 Spring 过冲「上移再落下」；列表未挂载时静默忽略 */
  private resetListScrollToTop(): void {
    scrollListToTopSilent(this.listScroller)
  }

  private cancelListRevealTimer(): void {
    this.listReveal.cancel()
  }

  /** 离开 Tab：静默初值（用户看不见，不闪） */
  private resetListRevealSilent(): void {
    this.listReveal.resetSilent((t: number) => {
      this.revealT = t
    })
  }

  /** 列表逐项缓现：revealT 0→1，行按 index 错峰各自入场 */
  private softRevealList(): void {
    this.listReveal.softReveal((t: number) => {
      this.revealT = t
    })
  }

  private bumpListEnter(): void {
    this.playHeroCount()
    // 当前 Tab 的缓现波由 loadData 在行挂载同 tick 起播；非当前 Tab 静默复位
    if (this.mainTabIndex !== 1) {
      this.resetListRevealSilent()
    }
  }

  private playHeroCount(): void {
    this.heroCounter.play((t: number) => {
      this.heroCountT = t
    })
  }

  private heroDueText(): string {
    return Utils.maskIf(this.antiPeekMasked,
      Utils.formatMoney(Math.round(this.totalBalance * this.heroCountT)), Utils.MASK_AMOUNT)
  }

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.loadTheme(false)
    // Tab 常驻：仅当前就是本页时拉数，避免进首页连带扫负债表
    if (this.mainTabIndex === 1) {
      this.loadData(true)
      this.lastHandledRefreshToken = this.listRefreshToken
      this.bumpListEnter()
    } else {
      this.resetListRevealSilent()
    }
  }

  aboutToDisappear() {
    this.cancelListRevealTimer()
    this.exitSelectMode()
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer)
      this.searchTimer = -1
    }
    this.heroCounter.cancel()
  }

  private onLuxChange(): void {
    this.loadTheme(false)
  }

  private onThemeRevision(): void {
    this.loadTheme(false)
  }

  private onListRefresh(): void {
    if (this.suppressNextListRefresh) {
      this.suppressNextListRefresh = false
      return
    }
    if (this.mainTabIndex !== 1) {
      return
    }
    this.lastHandledRefreshToken = this.listRefreshToken
    this.closeAllSwipes()
    this.loadData()
    this.playHeroCount()
    if (this.mainTabIndex === 1) {
      this.revealT = 1
    }
  }

  /** 本页已本地更新 UI：广播刷新时跳过自己，避免删一次刷两次 */
  private notifyOthersListRefresh(): void {
    this.suppressNextListRefresh = true
    Constants.notifyListRefresh()
  }

  /** 收起所有左滑菜单并清 isSwiped 态 */
  private closeAllSwipes(): void {
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (_err) {
    }
    this.swipingDebtId = ''
  }

  private async loadTheme(_animate: boolean = false): Promise<void> {
    const next = await fetchEffectiveTheme(this.lux, this.systemDark)
    if (ThemeManager.isSame(this.theme, next)) {
      return
    }
    this.theme = next
  }

  private async loadData(revealOnArrive: boolean = false): Promise<void> {
    const seq = this.loadSeq + 1
    this.loadSeq = seq
    const epochAtStart = LocalDataStore.getEpoch()
    this.currentPage = 0
    this.hasMore = true
    // P2-1：有投影则先秒开，再 RDB hydrate
    const cachedDebts = LocalDataStore.getDebts()
    if (cachedDebts !== null && seq === this.loadSeq) {
      this.allDebts = cachedDebts
      this.debts = cachedDebts
      this.hasMore = false
      const cachedSubs = LocalDataStore.getSubscriptions()
      if (cachedSubs !== null) {
        this.subscriptions = cachedSubs
      }
      this.calculateSummary()
      this.applyFilterSort()
      this.loading = false
      // 缓存命中：行已同 tick 挂载，波即从 0 起播（与账户页一致）；晚于挂载起播会让顶部行先行就位，波看似自底反向
      if (revealOnArrive && this.filteredDebts.length > 0) {
        this.softRevealList()
      }
    }
    // 缓存未命中（骨架屏期、列表未挂载）：数据就位同 tick 再整波从 0 起播，见函数尾
    const revealPending = revealOnArrive && this.loading
    // 列表与摘要均以全量 allDebts 为准（分页仅作 loadMore 备用；过滤勿再只吃首页切片）
    const allDebts = await DebtService.getDebts()
    if (seq !== this.loadSeq) {
      return
    }
    const subs = await SubscriptionService.getSubscriptions(UserService.getCurrentUserId())
    if (seq !== this.loadSeq) {
      return
    }
    // 「本月待还 = 0」时区分「已还清 / 无待还」需要这个标志，单独一次取
    const hasPaymentRecords = await PaymentService.hasPaymentRecords(UserService.getCurrentUserId())
    if (seq !== this.loadSeq) {
      return
    }
    // 仅当 hydrate 期间投影未再失效时写回，防止旧查询污染缓存
    if (LocalDataStore.isEpochCurrent(epochAtStart)) {
      LocalDataStore.setDebts(allDebts)
      LocalDataStore.setSubscriptions(subs)
    }
    // 单帧提交：概览/搜索/列表同帧挂载（对齐账户页），避免概览先挂载把骨架屏顶下去的布局位移
    this.allDebts = allDebts
    this.debts = allDebts
    this.hasMore = false
    this.currentPage = 0
    this.subscriptions = subs
    this.hasPaymentRecords = hasPaymentRecords
    this.calculateSummary()
    this.applyFilterSort()
    this.checkAllClearedCelebration()
    this.loading = false
    this.consumeOpenDetail()
    // 首帧数据与列表同 tick 就位：整波从 0 起播，行首帧即处于入场起点，波自顶部往下错峰展开
    //（与账户页一致；否则行会挂载在入场动画中途——顶部行已半就位、底部行才起步，波看似从底部往上跑）
    if (revealPending && this.filteredDebts.length > 0) {
      this.softRevealList()
    }
  }

  private consumeOpenDetail(): void {
    const id = AppStorage.get<string>(AppStorageKeys.OPEN_DEBT_DETAIL_ID) ?? ''
    if (id.length === 0) {
      return
    }
    AppStorage.setOrCreate(AppStorageKeys.OPEN_DEBT_DETAIL_ID, '')
    const found = this.allDebts.find((d: Debt) => d.id === id)
    if (found) {
      this.openDebtDetail(found)
    }
  }

  private async doRefresh(): Promise<void> {
    try {
      await this.loadData()
    } finally {
      this.isRefreshing = false
    }
  }

  private checkAllClearedCelebration(): void {
    const activeCount = this.allDebts.filter(d => d.status !== 'completed').length
    const paidCount = this.allDebts.filter(d => d.status === 'completed').length
    // 至少 5 笔结清才播仪式，避免少量债务也全屏打断惊喜感
    if (activeCount === 0 && paidCount >= 5 && !this.suppressCelebration && this.lastActiveCount > 0) {
      // 全屏仪式由 MainPage 挂载，盖住底栏
      AppStorage.setOrCreate(AppStorageKeys.ALL_CLEARED_SETTLED_COUNT, paidCount)
      AppStorage.setOrCreate(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY, true)
    }
    this.lastActiveCount = activeCount
    this.suppressCelebration = false
  }

  private showCompositionTooltip(metric: 'total' | 'thisMonth' | 'nextMonth'): void {
    // 防窥脱敏态：构成明细含名称与金额，静默跳过
    if (this.antiPeekMasked) {
      return
    }
    const activeDebts = this.allDebts.filter(d => d.status !== 'completed')
    const groups = new Map<string, number>()
    let total = 0
    // 月份 key 在循环外算好，避免循环内重复创建 Date
    const now = new Date()
    const thisMk = now.getFullYear() + '-' + (now.getMonth() + 1 < 10 ? '0' + (now.getMonth() + 1) : '' + (now.getMonth() + 1))
    now.setMonth(now.getMonth() + 1)
    const nextMk = now.getFullYear() + '-' + (now.getMonth() + 1 < 10 ? '0' + (now.getMonth() + 1) : '' + (now.getMonth() + 1))
    for (const d of activeDebts) {
      const key = d.platform || '未命名'
      let amount = 0
      if (metric === 'total') {
        amount = d.current_balance
      } else if (metric === 'thisMonth') {
        amount = CalculationService.getDebtPaymentForMonthAccrued(d, thisMk, thisMk)
      } else {
        amount = CalculationService.getDebtPaymentForMonth(d, nextMk)
      }
      if (amount <= 0) continue
      groups.set(key, (groups.get(key) ?? 0) + amount)
      total += amount
    }
    if (total === 0) {
      AppToast.show(ErrorMessages.NO_BREAKDOWN, 1500)
      return
    }
    const entries = Array.from(groups.entries()).sort((a, b) => b[1] - a[1]).slice(0, 5)
    const lines: string[] = []
    for (const entry of entries) {
      const name = entry[0]
      const amt = entry[1]
      const pct = Math.round(amt / total * 100)
      lines.push(name + ': ' + Utils.formatMoney(amt) + ' (' + pct + '%)')
    }
    AppToast.show(lines.join('\n'), 4000)
  }

  private calculateSummary(): void {
    const now = new Date()
    const thisMonthKey = now.getFullYear() + '-' + (now.getMonth() + 1 < 10 ? '0' + (now.getMonth() + 1) : '' + (now.getMonth() + 1))
    const nextDate = new Date(now.getFullYear(), now.getMonth() + 1, 1)
    const nextMonthKey = nextDate.getFullYear() + '-' + (nextDate.getMonth() + 1 < 10 ? '0' + (nextDate.getMonth() + 1) : '' + (nextDate.getMonth() + 1))

    const activeDebts = this.allDebts.filter(d => d.status !== 'completed')

    // 剩余待还 = 负债余额之和（纯负债口径）
    // 勿加订阅月摊：与列表卡「剩余待还」、点按拆解、首页「总待还」、桌面小组件同口径
    let balance = 0
    let principal = 0
    for (const d of activeDebts) {
      balance += d.current_balance
      principal += d.principal
    }

    this.totalBalance = balance
    this.totalPrincipal = principal
    this.overallProgress = principal > 0
      ? Math.min(100, Math.max(0, Math.round(((principal - balance) / principal) * 100)))
      : 0

    // 本月/下月待还：仅负债（与主数字、点按拆解一致）；订阅月摊不进此两格
    this.thisMonthDue = CalculationService.getDueAmountForMonth(this.allDebts, this.subscriptions, thisMonthKey, thisMonthKey).debtAmount
    this.nextMonthDue = CalculationService.getDueAmountForMonth(this.allDebts, this.subscriptions, nextMonthKey, thisMonthKey).debtAmount

    // 预计还清日期
    let furthest = ''
    for (const d of activeDebts) {
      if (d.estimated_end_date && (!furthest || d.estimated_end_date > furthest)) {
        furthest = d.estimated_end_date
      }
    }
    if (!furthest) {
      const def = new Date()
      def.setMonth(def.getMonth() + 24)
      furthest = Utils.formatDate(def)
    }
    this.furthestEndDate = furthest
    const furthestDate = new Date(furthest)
    this.remainingMonths = Math.max(1, (furthestDate.getFullYear() - now.getFullYear()) * 12 + (furthestDate.getMonth() - now.getMonth()))
  }

  private async loadMore(): Promise<void> {
    if (this.loadingMore || !this.hasMore) {
      return
    }
    this.loadingMore = true
    const nextPage = this.currentPage + 1
    this.currentPage = nextPage
    const page = await DebtService.getDebtsPaged(nextPage * this.PAGE_SIZE, this.PAGE_SIZE)
    if (page.length === 0) {
      this.hasMore = false
      this.loadingMore = false
      return
    }
    // 先拼本地数组再一次写回 @State，避免 this.debts = this.debts.concat 多次触发状态读
    const merged = this.debts.concat(page)
    this.debts = merged
    this.hasMore = page.length === this.PAGE_SIZE
    this.applyFilterSort()
    this.loadingMore = false
  }

  private applyFilterSort(): void {
    // 必须用 allDebts：loadData 里 this.debts 只是首页分页切片，
    // 导入后若仍按 debts 过滤，列表会像「只剩默认几条」；摘要却来自 allDebts，体感错乱。
    this.filteredDebts = DebtsFilterSort.filterAndSort(
      this.allDebts,
      this.searchQuery,
      this.filterIndex,
      this.sortIndex,
      Utils.todayString()
    )
    this.syncListSource()
  }

  /** 将 filteredDebts 同步到 LazyForEach 数据源 */
  private syncListSource(): void {
    const objs: Object[] = []
    for (let i = 0; i < this.filteredDebts.length; i++) {
      objs.push(this.filteredDebts[i])
    }
    this.listSource.reload(objs)
  }

  private debtFromItem(item: Object): Debt {
    return item as Debt
  }

  private deleteDebt(debt: Debt): void {
    // 先关左滑再弹确认，避免确认后菜单仍挂开
    this.closeAllSwipes()
    const config = new SheetDialogConfig(
      '删除确认',
      '确定删除 "' + debt.platform + '" 吗？相关还款记录也会被删除。',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('删除', this.theme.red, 'destructive')
      ]
    )
    this.openSheet(config, (index: number) => {
      if (index === 1) {
        this.doDelete(debt.id)
      }
    })
  }

  private openSheet(config: SheetDialogConfig, callback: (index: number) => void): void {
    this.sheetConfig = config
    this.sheetCallback = callback
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showSheet = true
    })
  }

  private async doDelete(debtId: string): Promise<void> {
    const wasLastActive = this.allDebts.filter(d => d.status !== 'completed' && d.id !== debtId).length === 0
    if (wasLastActive) {
      this.suppressCelebration = true
    }
    try {
      this.closeAllSwipes()
      await DebtService.deleteDebt(debtId)
      // 本页：本地移除一次；其它 Tab：notify 一次（不叠 quietReload）
      this.removeDebtLocally(debtId)
      this.calculateSummary()
      this.checkAllClearedCelebration()
      await LiveViewService.refresh()
      await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      this.notifyOthersListRefresh()
      AppToast.show(ErrorMessages.DELETE_OK, 1500)
    } catch (_e) {
      AppToast.show(ErrorMessages.DELETE_FAILED, 2500)
    }
  }

  /** 本地移除：更新 @State 数组触发 ForEach 退场 */
  private removeDebtLocally(debtId: string): void {
    this.debts = this.debts.filter(d => d.id !== debtId)
    this.allDebts = this.allDebts.filter(d => d.id !== debtId)
    this.getUIContext().animateTo({
      duration: MotionTokens.listItemExitDuration,
      curve: Curve.EaseOut
    }, () => {
      this.filteredDebts = this.filteredDebts.filter(d => d.id !== debtId)
      this.syncListSource()
    })
  }

  // ===== 批量选择 =====

  private onSelectModeRemoteChange(): void {
    if (!this.selectModeSync && this.selectMode) {
      this.exitSelectMode()
    }
  }

  private enterSelectMode(preselectId?: string): void {
    this.closeAllSwipes()
    this.showFilterPanel = false
    this.showSortPanel = false
    this.selectedIds = ListSelection.initialSelection(preselectId)
    this.selectMode = true
    this.selectModeSync = true
  }

  private exitSelectMode(): void {
    this.selectMode = false
    this.selectedIds = []
    this.selectModeSync = false
  }

  private isItemSelected(id: string): boolean {
    return ListSelection.isSelected(this.selectedIds, id)
  }

  private isAllSelected(): boolean {
    return ListSelection.isAllSelected(this.selectedIds, this.filteredDebts.map(d => d.id))
  }

  private toggleSelect(id: string): void {
    this.selectedIds = ListSelection.toggle(this.selectedIds, id)
  }

  private toggleSelectAll(): void {
    this.selectedIds = ListSelection.toggleAll(this.selectedIds, this.filteredDebts.map(d => d.id))
  }

  private confirmDeleteBatch(): void {
    const count = this.selectedIds.length
    if (count === 0) {
      return
    }
    this.closeAllSwipes()
    const config = new SheetDialogConfig(
      '删除确认',
      '确定删除 ' + count + ' 项负债吗？相关还款记录也会被删除。',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('删除', this.theme.red, 'destructive')
      ]
    )
    this.openSheet(config, (index: number) => {
      if (index === 1) {
        this.doDeleteBatch()
      }
    })
  }

  private async doDeleteBatch(): Promise<void> {
    const ids = this.selectedIds.slice()
    if (ids.length === 0) {
      return
    }
    this.closeAllSwipes()
    // 删除后若再无进行中负债，跳过全清仪式（与单删 doDelete 一致）
    const activeRemaining = this.allDebts.filter(d => d.status !== 'completed' && ids.indexOf(d.id) < 0).length
    if (activeRemaining === 0) {
      this.suppressCelebration = true
    }
    const failed = await runBatchDelete(ids, (id: string): Promise<void> => DebtService.deleteDebt(id))
    const succeeded = ListSelection.splitSucceeded(ids, failed)
    if (succeeded.length > 0) {
      this.removeDebtsLocallyBatch(succeeded)
      this.calculateSummary()
      this.checkAllClearedCelebration()
      await LiveViewService.refresh()
      await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      this.notifyOthersListRefresh()
    }
    this.exitSelectMode()
    AppToast.show(ListSelection.batchDeleteToast(succeeded.length, failed.length, '项'), failed.length === 0 ? 1500 : 2500)
  }

  /** 本地批量移除：一次 animateTo 退场 */
  private removeDebtsLocallyBatch(ids: string[]): void {
    const idSet: Set<string> = new Set()
    for (let i = 0; i < ids.length; i++) {
      idSet.add(ids[i])
    }
    this.debts = this.debts.filter(d => !idSet.has(d.id))
    this.allDebts = this.allDebts.filter(d => !idSet.has(d.id))
    this.getUIContext().animateTo({
      duration: MotionTokens.listItemExitDuration,
      curve: Curve.EaseOut
    }, () => {
      this.filteredDebts = this.filteredDebts.filter(d => !idSet.has(d.id))
      this.syncListSource()
    })
  }

  private goToEdit(debt: Debt): void {
    this.closeAllSwipes()
    AppStorage.setOrCreate(AppStorageKeys.SELECTED_DEBT_ID, debt.id)
    AppRouter.push(RouteNames.DEBT_FORM)
  }

  private debtStatusText(debt: Debt): string {
    return debtStatusTagText(debt.status, debt.next_payment_date, Utils.todayString())
  }

  /** 详情角标角色：与列表 StatusTag 一致（ok/warn/danger/off） */
  private debtStatusRole(debt: Debt): string {
    return debtStatusTagRole(debt.status, debt.next_payment_date, Utils.todayString())
  }

  /** 详情弹窗：概览信息卡片数据 */
  private buildDebtDetail(debt: Debt): DetailSheetConfig {
    const c = new DetailSheetConfig()
    c.title = '负债详情'
    c.name = debt.platform
    c.badgeText = this.debtStatusText(debt)
    c.badgeRole = this.debtStatusRole(debt)
    const visual = PlatformService.getBrandVisual(debt.platform)
    c.mark = visual.mark
    c.markColor = debt.platform_color && debt.platform_color.length > 0 ? debt.platform_color :
      (visual.color.length > 0 ? visual.color : '#2F3336')
    c.iconUrl = debt.icon_url && debt.icon_url.length > 0 ? debt.icon_url :
      PlatformService.getLogoUrlForName(debt.platform)
    c.cardFace = IconPickerService.isCardFaceUrl(c.iconUrl)
    c.heroLabel = debt.debt_type === 'installment' ? '剩余未还总额' : '应还金额'
    // 分期：月供 × 待还期数（含当期、含服务费）；兼容 PC remaining 不含当期
    const remainingTotal = debt.debt_type === 'installment'
      ? CalculationService.getInstallmentRemainingDue(debt)
      : debt.current_balance
    c.heroValue = Utils.formatMoney(remainingTotal, false)
    c.heroUnit = '元'
    const fields: DetailField[] = []
    if (debt.debt_type === 'installment') {
      fields.push(new DetailField('每期应还', Utils.formatMoney(debt.monthly_payment, true)))
      fields.push(new DetailField('下次还款日', debt.next_payment_date ? debt.next_payment_date : '—'))
      fields.push(new DetailField('期数进度', debt.total_periods > 0
        ? (debt.total_periods - debt.remaining_periods) + '/' + debt.total_periods + ' 期'
        : '—'))
      fields.push(new DetailField('年利率', debt.annual_rate_bp > 0 ? Utils.bpToPercent(debt.annual_rate_bp) + '%' : '—'))
    } else {
      fields.push(new DetailField('还款日', debt.next_payment_date ? debt.next_payment_date : '—'))
    }
    // 不展示「自动扣款」：识别/手动录入均无该入口，固定 false 无信息量
    c.fields = fields
    // 未结清：详情内可直接还款（不必关弹窗再左滑）
    if (debt.status !== 'completed') {
      c.primaryLabel = '还款'
    }
    return c
  }

  private openDebtDetail(debt: Debt): void {
    this.isRepaySheet = false
    this.repayDebtItem = null
    this.detailDebtItem = debt
    this.detailConfig = this.buildDebtDetail(debt)
    this.isDetailSheet = true
    this.resolveDetailIcon(debt)
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showSheet = true
    })
  }

  /** 详情内点「还款」：同一 bindSheet 切换到还款确认（优先 isRepaySheet） */
  private repayFromDetail(): void {
    const debt = this.detailDebtItem
    if (!debt) {
      return
    }
    this.isDetailSheet = false
    this.detailDebtItem = null
    this.repayDebt(debt)
  }

  /** 详情弹窗图标：关联账户时锚定账户本身；未关联时按平台名匹配同名账户；最后才用负债自定义 */
  private async resolveDetailIcon(debt: Debt): Promise<void> {
    let url = ''
    let cardFace = false
    const linkedId = debt.credit_account_id
    if (linkedId && linkedId.length > 0) {
      try {
        const acc: CreditAccount | null = await CreditAccountService.getCreditAccountById(linkedId)
        if (acc) {
          if (acc.icon_url && acc.icon_url.length > 0) {
            url = acc.icon_url
            cardFace = true
          } else {
            url = PlatformService.getLogoUrlForName(acc.name)
          }
        }
      } catch (_err) {
      }
    }
    if (url.length === 0 && (!linkedId || linkedId.length === 0)) {
      const pn = (debt.platform || '').toLowerCase()
      const accounts = LocalDataStore.getAccounts()
      if (accounts !== null) {
        for (let i = 0; i < accounts.length; i++) {
          const a: CreditAccount = accounts[i]
          if (!a.icon_url || a.icon_url.length === 0) {
            continue
          }
          const an = (a.name || '').toLowerCase()
          if (an.length > 0 && pn.length > 0 && (an === pn || an.includes(pn) || pn.includes(an))) {
            url = a.icon_url
            cardFace = true
            break
          }
        }
      }
    }
    if (url.length === 0 && debt.icon_url && debt.icon_url.length > 0) {
      url = debt.icon_url
      cardFace = IconPickerService.isCardFaceUrl(url)
    }
    if (url.length > 0 && this.isDetailSheet) {
      const next = this.buildDebtDetail(debt)
      next.iconUrl = url
      next.cardFace = cardFace
      this.detailConfig = next
    }
  }

  private repayDebt(debt: Debt): void {
    if (debt.status === 'completed') {
      AppToast.show(ErrorMessages.DEBT_ALREADY_SETTLED, 1500)
      return
    }
    this.isDetailSheet = false
    this.detailDebtItem = null
    this.repayDebtItem = debt
    this.isRepaySheet = true
    this.showSheet = true
  }

  private async doRepay(debt: Debt, mode: 'period' | 'payoff'): Promise<void> {
    const fresh: Debt | null = await DebtService.getDebtById(debt.id)
    if (!fresh || fresh.status === 'completed') {
      AppToast.show(ErrorMessages.DEBT_STATUS_CHANGED, 1500)
      this.loadData()
      return
    }
    // 还款前快照：将触发全清仪式时跳过 Toast（≥5 笔结清门槛与仪式一致）
    const activeBefore = this.allDebts.filter(d => d.status !== 'completed').length
    const paidBefore = this.allDebts.filter(d => d.status === 'completed').length
    const skipToast = willClearAllAfterRepay(activeBefore, mode, fresh.remaining_periods, paidBefore + 1)
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
      // 还款后本页也要重算列表/摘要，走一次 loadData；其它 Tab 靠 notify
      this.suppressNextListRefresh = true
      Constants.notifyListRefresh()
      this.loadData()
    } catch (e) {
      AnalyticsService.trackRepayFail('unknown')
      AppToast.show(ErrorMessages.REPAY_FAILED, 1500)
    }
  }

  /** 列表项过渡：进入为逐项自上落下缓现（滚动懒挂载按当前进度取值，不重播），退出左滑淡出 */


  /** 顶栏背景：随列表滚动淡入 surface2（不加阴影，阴影仅托出 Sheet/模态） */
  private topBarBg(): ResourceColor {
    if (this.topBarAlpha <= 0) {
      return Color.Transparent
    }
    return Utils.hexToRgba(this.theme.surface2 as string, this.topBarAlpha)
  }

  private onListDidScroll(): void {
    const y = this.listScroller.currentOffset().yOffset
    this.topBarAlpha = topBarFadeRatio(y, this.topBarFadeDistance, this.topBarAlpha)
  }

  /** List 子节点必须是 ListItem */
  @Builder
  debtListItem(debt: Debt, index: number, total: number) {
    if (this.selectMode) {
      ListItem() {
        DebtCard({
          debt: debt,
          theme: this.theme,
          isSwiped: false,
          selectable: true,
          selected: this.isItemSelected(debt.id),
          isFirstInGroup: index === 0,
          isLastInGroup: index === total - 1
        })
      }
      .height(MotionTokens.listRowHeight)
      .opacity(listItemRevealProgress(this.revealT, index))
      .translate({ y: listItemRevealTranslateY(this.revealT, index) })
      .onClick(() => {
        this.toggleSelect(debt.id)
      })
      .transition(listExitTransition())
    } else {
      ListItem() {
        DebtCard({
          debt: debt,
          theme: this.theme,
          isSwiped: this.swipingDebtId === debt.id,
          isFirstInGroup: index === 0,
          isLastInGroup: index === total - 1
        })
      }
      .height(MotionTokens.listRowHeight)
      .opacity(listItemRevealProgress(this.revealT, index))
      .translate({ y: listItemRevealTranslateY(this.revealT, index) })
      .transition(listExitTransition())
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 1 })
            .onAction(() => {
              this.openDebtDetail(debt)
            }),
          LongPressGesture({ repeat: false, duration: 400 })
            .onAction(() => {
              this.enterSelectMode(debt.id)
            })
        )
      )
      .swipeAction({
        end: {
          builder: () => {
            this.debtSwipeActions(debt)
          }
        },
        onOffsetChange: (offset: number) => {
          if (offset < 0) {
            if (this.swipingDebtId !== debt.id) {
              this.swipingDebtId = debt.id
            }
          } else if (offset === 0) {
            if (this.swipingDebtId === debt.id) {
              this.swipingDebtId = ''
            }
          }
        }
      })
    }
  }

  @Builder
  debtSwipeActions(debt: Debt) {
    SwipeEditDeleteActions({
      theme: this.theme,
      actionHeight: 74,
      cornerRadius: this.theme.radiusSm,
      onRepay: debt.status === 'completed' ? undefined : () => {
        this.closeAllSwipes()
        this.repayDebt(debt)
      },
      onEdit: () => {
        this.goToEdit(debt)
      },
      onDelete: () => {
        this.deleteDebt(debt)
      }
    })
  }


  private openDebtReceipt(): void {
    const model = DebtReceipt.build(this.allDebts)
    if (model.itemCount === 0) {
      AppToast.show('没有进行中的负债', 1600)
      return
    }
    AppStorage.setOrCreate(AppStorageKeys.DEBT_RECEIPT_MODEL, model)
    AppStorage.setOrCreate(AppStorageKeys.SHOW_DEBT_RECEIPT_OVERLAY, true)
    this.showFilterPanel = false
    this.showSortPanel = false
  }

  private getActiveCount(): number {
    return this.allDebts.filter(d => d.status !== 'completed').length
  }

  private paidCount(): number {
    return this.allDebts.filter(d => d.status === 'completed').length
  }

  private isStatusFiltered(): boolean {
    return this.filterIndex !== 0
  }

  private isSortFiltered(): boolean {
    return this.sortIndex !== 0
  }

  private toggleFilterPanel(): void {
    this.showFilterPanel = !this.showFilterPanel
    if (this.showFilterPanel) {
      this.showSortPanel = false
    }
  }

  private toggleSortPanel(): void {
    this.showSortPanel = !this.showSortPanel
    if (this.showSortPanel) {
      this.showFilterPanel = false
    }
  }

  private endDateLabel(): string {
    const label = formatDueYmd(this.furthestEndDate)
    if (label.length > 0) {
      return Utils.maskIf(this.antiPeekMasked, label)
    }
    return '----'
  }

  /**
   * 「本月待还」= 0 时的状态文本：
   * - 存在还款记录 → 「已还清」（语义：本月账单已结）
   * - 没有任何还款记录 → 「无待还」（语义：本月没有需要还的款）
   * 其他场景返回空，调用方按金额格式化
   */
  private thisMonthDueZeroLabel(): string {
    if (this.thisMonthDue !== 0) {
      return ''
    }
    return this.hasPaymentRecords ? '已还清' : '无待还'
  }

  private thisMonthDueZeroColor(): ResourceColor {
    if (this.hasPaymentRecords) {
      return this.theme.positiveGreen
    }
    return this.theme.text2
  }

  private selectFilter(index: number): void {
    this.filterIndex = index
    this.applyFilterSort()
    this.showFilterPanel = false
    this.showSortPanel = false
  }

  private selectSort(index: number): void {
    this.sortIndex = index
    this.applyFilterSort()
    this.showFilterPanel = false
    this.showSortPanel = false
  }

  /** 顶部预览：主指标 + 次要条 + 进度（压缩高度，让出列表可视区） */
  @Builder
  summaryHero() {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text('剩余待还')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          if (this.antiPeekMasked) {
            Text(this.heroDueText())
              .fontSize(TypeScale.heroNumber)
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
              Span(Utils.formatMoney(Math.round(this.totalBalance * this.heroCountT), false))
                .fontSize(TypeScale.heroNumber)
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
        .layoutWeight(1)
        .onClick(() => {
          this.showCompositionTooltip('total')
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      Row({ space: this.theme.spaceSm }) {
        Column({ space: 2 }) {
          Text('本月待还')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          if (this.thisMonthDue === 0) {
            // 本月无待还：分「已还清 / 无待还」两态；脱敏态统一遮蔽
            Text(this.antiPeekMasked ? Utils.MASK_AMOUNT : this.thisMonthDueZeroLabel())
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.antiPeekMasked ? this.theme.text : this.thisMonthDueZeroColor())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text(Utils.maskIf(this.antiPeekMasked,
              Utils.formatMoneyCompact(this.thisMonthDue), Utils.MASK_AMOUNT))
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.showCompositionTooltip('thisMonth')
        })

        Column({ space: 2 }) {
          Text('下月待还')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          Text(Utils.maskIf(this.antiPeekMasked,
            Utils.formatMoneyCompact(this.nextMonthDue), Utils.MASK_AMOUNT))
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Medium)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .onClick(() => {
          this.showCompositionTooltip('nextMonth')
        })

        Column({ space: 2 }) {
          Text('预计还清')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          Text(this.endDateLabel())
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Medium)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: this.theme.spaceSm })
      .border({ width: { top: 1 }, color: this.theme.borderSoft, style: BorderStyle.Dashed })

      if (this.overallProgress > 0) {
        Row() {
          SegmentProgressBar({
            progress: this.overallProgress,
            segmentCount: 24,
            theme: this.theme,
            segWidth: 3,
            segHeight: 16
          })
            .layoutWeight(1)

          Text(this.overallProgress + '%')
            .fontSize(TypeScale.captionSm)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
            .fontWeight(FontWeight.Medium)
            .margin({ left: 8 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusXl)
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow(this.theme.floatShadowOptions())
  }

  /** 标题栏右上：分享/状态/排序悬浮胶囊（surface2 + pill + floatShadow） */
  @Builder
  filterSortCapsule() {
    Row({ space: 0 }) {
      if (this.shareEnabled) {
        this.shareBtn()
        Row()
          .width(0.5)
          .height(16)
          .backgroundColor(this.theme.borderSoft)
          .margin({ left: 2, right: 2 })
      }
      this.filterStatusBtn()
      this.sortFilterBtn()
    }
    .padding({ left: 3, right: 3, top: 3, bottom: 3 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusPill)
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow(this.theme.floatShadowOptions())
  }

  @Builder
  shareBtn() {
    Column() {
      Image($r('app.media.ic_share'))
        .width(20)
        .height(20)
        .fillColor(this.theme.text2)
        .objectFit(ImageFit.Contain)
    }
    .width(36)
    .height(32)
    .justifyContent(FlexAlign.Center)
    .onClick(() => {
      this.openDebtReceipt()
    })
  }

  @Builder
  filterStatusBtn() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Image($r('app.media.ic_filter_status'))
          .width(20)
          .height(20)
          .fillColor(this.isStatusFiltered() || this.showFilterPanel ? this.theme.primary : this.theme.text2)
          .objectFit(ImageFit.Contain)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.showFilterPanel ? Utils.hexToRgba(this.theme.primary, 0.12) : Color.Transparent)
      .borderRadius(this.theme.radiusPill)

      if (this.isStatusFiltered()) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(this.theme.radiusPill)
          .backgroundColor(this.theme.primary)
          .margin({ top: 4, right: 4 })
      }
    }
    .width(32)
    .height(32)
    .onClick(() => {
      this.toggleFilterPanel()
    })
  }

  @Builder
  sortFilterBtn() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Image($r('app.media.ic_filter_sort'))
          .width(20)
          .height(20)
          .fillColor(this.isSortFiltered() || this.showSortPanel ? this.theme.primary : this.theme.text2)
          .objectFit(ImageFit.Contain)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.showSortPanel ? Utils.hexToRgba(this.theme.primary, 0.12) : Color.Transparent)
      .borderRadius(this.theme.radiusPill)

      if (this.isSortFiltered()) {
        Column()
          .width(6)
          .height(6)
          .borderRadius(this.theme.radiusPill)
          .backgroundColor(this.theme.primary)
          .margin({ top: 4, right: 4 })
      }
    }
    .width(32)
    .height(32)
    .onClick(() => {
      this.toggleSortPanel()
    })
  }

  /** 状态筛选：右上紧凑纵向勾选菜单 */
  @Builder
  filterPanel() {
    FilterSortMenuPanel({
      theme: this.theme,
      title: '状态',
      icon: $r('app.media.ic_filter_status'),
      options: this.filters,
      selectedIndex: this.filterIndex,
      onSelect: (index: number) => {
        this.selectFilter(index)
      }
    })
  }

  /** 排序：右上紧凑纵向勾选菜单 */
  @Builder
  sortPanel() {
    FilterSortMenuPanel({
      theme: this.theme,
      title: '排序',
      icon: $r('app.media.ic_filter_sort'),
      options: this.sorts,
      selectedIndex: this.sortIndex,
      onSelect: (index: number) => {
        this.selectSort(index)
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
        // 标题栏：选择态 居中已选N；正常态 标题 + 筛选/排序/管理胶囊
        if (this.selectMode) {
          BatchSelectHeader({
            theme: this.theme,
            selectedCount: this.selectedIds.length,
            topSafe: this.topSafe,
            topBarBg: this.topBarBg()
          })
        } else {
          Row({ space: 8 }) {
            Column({ space: 4 }) {
              Text('负债')
                .fontSize(TypeScale.heroTitle)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.text)
                .letterSpacing(TypeScale.heroTitleSpacing)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            if (this.getActiveCount() > 0) {
              this.filterSortCapsule()
            }
          }
          .width('100%')
          .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, top: 10 + this.topSafe, bottom: 8 })
          .justifyContent(FlexAlign.SpaceBetween)
          .alignItems(VerticalAlign.Center)
          .backgroundColor(this.topBarBg())
        }

        // 顶部预览
        if (this.getActiveCount() > 0 && !this.selectMode) {
          Column() {
            this.summaryHero()
          }
          .width('100%')
          .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, bottom: 14 })
        }

        // 搜索（全宽；筛选/排序已上移标题栏；批量选择时隐藏以保持选择集稳定）
        if (this.getActiveCount() > 0 && !this.selectMode) {
          Column() {
            TextInput({ placeholder: '如：花呗', text: this.searchQuery })
              .placeholderColor(this.theme.text3)
              .fontColor(this.theme.text)
              .fontSize(TypeScale.control)
              .backgroundColor(this.theme.fieldBackground())
              .borderRadius(this.theme.radiusLg)
              .border({ width: 1, color: this.theme.borderSoft })
              .height(40)
              .padding({ left: 12, right: 12 })
              .width('100%')
              .cancelButton({
                style: CancelButtonStyle.INPUT,
                icon: {
                  color: this.theme.text3
                }
              })
              .enterKeyType(EnterKeyType.Search)
              .onSubmit(() => {
                if (this.searchTimer !== -1) {
                  clearTimeout(this.searchTimer)
                  this.searchTimer = -1
                }
                this.applyFilterSort()
              })
              .onChange((value: string) => {
                this.searchQuery = value
                if (this.searchTimer !== -1) {
                  clearTimeout(this.searchTimer)
                }
                this.searchTimer = setTimeout(() => {
                  this.searchTimer = -1
                  this.applyFilterSort()
                }, 300)
              })
          }
          .width('100%')
          .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, bottom: 8 })
        }

        if (this.loading) {
          // 首载骨架：脉动占位，避免空白闪烁
          Column() {
            SkeletonList({ theme: this.theme, count: 5 })
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding })
        } else if (this.filteredDebts.length === 0) {
          // 顶栏以下可用区垂直居中
          if (this.getActiveCount() === 0) {
            EmptyState({
              theme: this.theme,
              showIllustration: true,
              objectStage: true,
              illustration: $r('app.media.empty_debt'),
              title: '暂无负债',
              subtitle: '添加待还记录，跟进还款进度',
              hint: ''
            })
              .width('100%')
              .layoutWeight(1)
          } else {
            EmptyState({
              theme: this.theme,
              icon: $r('app.media.ic_search_empty'),
              iconColor: this.theme.text2,
              title: '无匹配结果',
              subtitle: '调整搜索词或筛选条件',
              outlineLabel: this.searchQuery.trim().length > 0
                ? (this.filterIndex !== 0 ? '重置条件' : '清空搜索')
                : '重置筛选',
              outlineAction: () => {
                this.searchQuery = ''
                this.filterIndex = 0
                this.applyFilterSort()
              }
            })
              .width('100%')
              .layoutWeight(1)
          }
        } else {
          Refresh({ refreshing: $$this.isRefreshing }) {
            // 列表铺满可用区（可滚入悬浮 Tab 下方）；底栏避让用尾部 ListItem 占位，勿对 List/Column 做 bottom padding
            Column() {
              // LazyForEach：仅可视区+cachedCount 挂载；勿与额外 ListItem 混用
              List({ space: 0, scroller: this.listScroller }) {
                LazyForEach(this.listSource, (item: Object, index: number) => {
                  this.debtListItem(
                    this.debtFromItem(item),
                    index,
                    this.listSource.totalCount()
                  )
                }, (item: Object) => {
                  const d = this.debtFromItem(item)
                  return d.id + '#' + d.updated_at
                })

                ListItem() {
                  // CLEARANCE 已含底栏+呼吸间距；HdsTabs 自避让安全区，勿再叠 bottomSafe（双重计算）
                  Column()
                    .width('100%')
                    .height(Constants.FLOATING_TAB_CLEARANCE + (this.selectMode ? 72 : 0))
                }
              }
              .width('100%')
              .layoutWeight(1)
              .cachedCount(6)
              .clip(true)
              .animation(listItemRevealNoImplicit())
              .scrollBar(BarState.Off)
              .edgeEffect(EdgeEffect.Spring)
              .onReachEnd(() => this.loadMore())
              .onDidScroll(() => this.onListDidScroll())
            }
            .width('100%')
            .height('100%')
            .padding({
              left: this.theme.pageHorizontalPadding,
              right: this.theme.pageHorizontalPadding
            })
          }
          .layoutWeight(1)
          .onRefreshing(() => this.doRefresh())
        }
      }
      .width('100%')
      .height('100%')

      // 筛选/排序菜单：右上紧凑浮层（无压暗；极淡底才能接到点击，Color.Transparent 会被跳过）
      if (!this.selectMode && this.getActiveCount() > 0 && (this.showFilterPanel || this.showSortPanel)) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('rgba(0,0,0,0.001)')
          .hitTestBehavior(HitTestMode.Default)
          .onClick(() => {
            this.showFilterPanel = false
            this.showSortPanel = false
          })

        Column() {
          if (this.showFilterPanel) {
            this.filterPanel()
          }
          if (this.showSortPanel) {
            this.sortPanel()
          }
        }
        .width('100%')
        .height('100%')
        .alignItems(HorizontalAlign.End)
        .padding({ top: this.topSafe + 58, right: this.theme.pageHorizontalPadding })
        .hitTestBehavior(HitTestMode.Transparent)
      }

      // 批量选择模式底部操作栏（浮于列表之上，避让悬浮 Tab；空白区点击穿透回列表）
      if (this.selectMode) {
        BatchActionOverlay({
          theme: this.theme,
          selectedCount: this.selectedIds.length,
          allSelected: this.isAllSelected(),
          onToggleAll: () => {
            this.toggleSelectAll()
          },
          onDelete: () => {
            this.confirmDeleteBatch()
          },
          onCancel: () => {
            this.exitSelectMode()
          }
        })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
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
        this.isRepaySheet = false
        this.repayDebtItem = null
        this.isDetailSheet = false
        this.detailDebtItem = null
      }
    })
  }

  @Builder
  sheetBuilder() {
    if (this.isRepaySheet && this.repayDebtItem) {
      RepaySheetView({
        theme: this.theme,
        debt: this.repayDebtItem,
        onConfirmRepay: () => {
          this.showSheet = false
          this.doRepay(this.repayDebtItem!, 'period')
        },
        onPayoff: () => {
          this.showSheet = false
          this.doRepay(this.repayDebtItem!, 'payoff')
        },
        onCancel: () => {
          this.showSheet = false
        }
      })
    } else if (this.isDetailSheet) {
      DetailSheetView({
        theme: this.theme,
        config: this.detailConfig,
        onClose: () => {
          this.showSheet = false
        },
        onPrimaryAction: () => {
          this.repayFromDetail()
        }
      })
    } else {
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
}