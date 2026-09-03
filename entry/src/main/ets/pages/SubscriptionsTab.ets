import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens, ArrayDataSource } from 'common'
import { Subscription, SubscriptionStatus, SubscriptionCategory } from 'common'
import { SubscriptionService } from 'service'
import { UserService } from 'service'
import { LocalDataStore } from 'service'
import { CreditAccountService } from 'service'
import { SubscriptionCard, statusTagText, statusTagRole, cycleDurationLabel, creditAccountLabel, formatExpiryYmd } from 'components'
import { Utils } from 'common'
import { Constants } from 'common'
import { WidgetUpdateService } from 'service'
import { PlatformService } from 'service'
import { CalculationService } from 'service'
import { SwipeEditDeleteActions } from 'components'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton } from 'components'
import { DetailSheetView, DetailSheetConfig, DetailField } from 'components'
import { EmptyState } from 'components'
import { FilterSortMenuPanel } from 'components'
import { SkeletonList } from 'components'
import { SubscriptionReceipt } from 'service'
import { AppStorageKeys } from 'common'
import { AppRouter, RouteNames } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { ListSelection, runBatchDelete } from './common/ListSelection'
import { BatchSelectHeader, BatchActionOverlay } from './common/BatchShell'
import { ListReveal, HeroCounter, listExitTransition, listItemRevealProgress, listItemRevealTranslateY, topBarFadeRatio } from './common/ListReveal'
import { fetchEffectiveTheme } from './common/ThemeLoader'

@Component
export struct SubscriptionsTab {
  @State subscriptions: Subscription[] = []
  /** 筛选结果；列表走 listSource + LazyForEach */
  @State filtered: Subscription[] = []
  private listSource: ArrayDataSource = new ArrayDataSource()
  @State theme: ThemeColors = ThemeManager.DARK
  @State activeSubCount: number = 0
  @State totalCount: number = 0
  @StorageProp(AppStorageKeys.TOP_SAFE_HEIGHT) topSafe: number = 0
  @State keyword: string = ''
  @State thisMonthTotal: number = 0
  @State nextMonthTotal: number = 0
  @State grandTotal: number = 0
  @State nearestExpiryDate: string = ''
  /** 防窥脱敏态：系统检测到窥视时主数字/预览指标打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  @State statusFilter: SubscriptionStatus | 'all' = 'all'
  @State categoryFilter: SubscriptionCategory | 'all' = 'all'
  /** 标题栏右侧：状态/分类展开面板（悬浮卡片，不挤压内容） */
  @State showStatusPanel: boolean = false
  @State showCategoryPanel: boolean = false
  @State searchDebounce: number = -1
  /** 首载骨架：仅首次进入显示，后续刷新不重播 */
  @State private loading: boolean = true
  /** 滚动驱动顶栏背景透明度 0→1 */
  @State private topBarAlpha: number = 0
  private readonly topBarFadeDistance: number = 80
  /** 本页刚本地更新过，忽略紧随其后的 listRefresh 自刷新 */
  private suppressNextListRefresh: boolean = false
  @State showSheet: boolean = false
  @State isRefreshing: boolean = false
  @State isDetailSheet: boolean = false
  @State detailConfig: DetailSheetConfig = new DetailSheetConfig()
  @State sheetConfig: SheetDialogConfig = new SheetDialogConfig()
  private sheetCallback: (index: number) => void = () => {}
  @StorageLink('ambientLux') @Watch('onLuxChange') lux: number = -1
  @StorageLink('systemDark') @Watch('onLuxChange') systemDark: boolean = false
  @StorageLink('themeRevision') @Watch('onThemeRevision') themeRevision: number = 0
  /** 表单保存后刷新列表（Tab 常驻不会再次 aboutToAppear） */
  @StorageLink('listRefreshToken') @Watch('onListRefresh') listRefreshToken: number = 0
  @State swipingSubId: string = ''
  /** 批量选择模式 */
  @State selectMode: boolean = false
  /** 已选 id（数组重新赋值驱动 ForEach 选中态刷新） */
  @State selectedIds: string[] = []
  /** 与 MainPage 同步多选态，使返回手势可先退多选 */
  @StorageLink('listSelectMode') @Watch('onSelectModeRemoteChange') selectModeSync: boolean = false
  /** 列表逐项缓现（Apple per-row 模型，bpta-fair-use-animation）：行按 index 错峰，滚动/刷新不重播 */
  @State private revealT: number = 0
  private listReveal: ListReveal = new ListReveal()
  @State private heroCountT: number = 1
  private heroCounter: HeroCounter = new HeroCounter()
  private listScroller: ListScroller = new ListScroller()
  @StorageProp('mainTabIndex') @Watch('onTabChange') mainTabIndex: number = 0
  private lastHandledRefreshToken: number = 0

  private onTabChange(): void {
    this.showStatusPanel = false
    this.showCategoryPanel = false
    this.exitSelectMode()
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (err) {
    }
    this.swipingSubId = ''
    if (this.mainTabIndex === 2) {
      this.resetListScrollToTop()
      const stale = this.listRefreshToken !== this.lastHandledRefreshToken
      const alreadyShown = this.subscriptions.length > 0 && this.revealT >= 1
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
    if (this.searchDebounce !== -1) {
      clearTimeout(this.searchDebounce)
      this.searchDebounce = -1
    }
    if (this.keyword.length === 0) {
      return
    }
    this.keyword = ''
    this.applyFilter()
  }

  /** 切入本 Tab：列表滚回顶部；列表未挂载（空态/骨架）时静默忽略 */
  private resetListScrollToTop(): void {
    try {
      this.listScroller.scrollEdge(Edge.Top)
    } catch (_err) {
    }
  }

  private cancelListRevealTimer(): void {
    this.listReveal.cancel()
  }

  private resetListRevealSilent(): void {
    this.listReveal.resetSilent((t: number) => {
      this.revealT = t
    })
  }

  /** 列表逐项缓现：revealT 0->1，行按 index 错峰各自入场 */
  private softRevealList(): void {
    this.listReveal.softReveal((t: number) => {
      this.revealT = t
    })
  }

  private bumpListEnter(): void {
    this.playHeroCount()
    // 当前 Tab 的缓现波由 loadData 在行挂载同 tick 起播；非当前 Tab 静默复位
    if (this.mainTabIndex !== 2) {
      this.resetListRevealSilent()
    }
  }

  private playHeroCount(): void {
    this.heroCounter.play((t: number) => {
      this.heroCountT = t
    })
  }

  private heroMonthText(): string {
    return Utils.maskIf(this.antiPeekMasked,
      Utils.formatMoney(Math.round(this.grandTotal * this.heroCountT)), Utils.MASK_AMOUNT)
  }

  private categories: (SubscriptionCategory | 'all')[] = ['all', 'video', 'music', 'tools', 'learning', 'lifestyle', 'storage', 'fitness', 'programming', 'ai', 'other']
  private statuses: (SubscriptionStatus | 'all')[] = ['all', 'active', 'paused', 'cancelled']

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.loadTheme(false)
    // Tab 常驻：仅当前就是本页时拉数，避免进首页连带扫订阅表
    if (this.mainTabIndex === 2) {
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
    if (this.searchDebounce !== -1) {
      clearTimeout(this.searchDebounce)
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
    if (this.mainTabIndex !== 2) {
      return
    }
    this.lastHandledRefreshToken = this.listRefreshToken
    this.loadData()
    this.playHeroCount()
    if (this.mainTabIndex === 2) {
      this.revealT = 1
    }
  }

  private notifyOthersListRefresh(): void {
    this.suppressNextListRefresh = true
    Constants.notifyListRefresh()
  }

  private async loadTheme(_animate: boolean = false): Promise<void> {
    const next = await fetchEffectiveTheme(this.lux, this.systemDark)
    if (ThemeManager.isSame(this.theme, next)) {
      return
    }
    this.theme = next
  }

  /** 并发 loadData 序号：切 Tab / 导入后仅最新一次写 UI */
  private loadSeq: number = 0

  private async loadData(revealOnArrive: boolean = false): Promise<void> {
    const seq = this.loadSeq + 1
    this.loadSeq = seq
    const epochAtStart = LocalDataStore.getEpoch()
    const cached = LocalDataStore.getSubscriptions()
    if (cached !== null && seq === this.loadSeq) {
      this.subscriptions = cached
      this.computeSummary()
      this.applyFilter()
      this.loading = false
      // 缓存命中：行已同 tick 挂载，波即从 0 起播（与账户页一致）；晚于挂载起播会让顶部行先行就位，波看似自底反向
      if (revealOnArrive && this.filtered.length > 0) {
        this.softRevealList()
      }
    }
    // 缓存未命中（骨架屏期、列表未挂载）：数据就位同 tick 再整波从 0 起播，见函数尾
    const revealPending = revealOnArrive && this.loading
    const list = await SubscriptionService.getSubscriptions()
    if (seq !== this.loadSeq) {
      return
    }
    this.subscriptions = list
    if (LocalDataStore.isEpochCurrent(epochAtStart)) {
      LocalDataStore.setSubscriptions(this.subscriptions)
    }
    this.computeSummary()
    this.applyFilter()
    this.loading = false
    this.consumeOpenDetail()
    // 首帧数据与列表同 tick 就位：整波从 0 起播，行首帧即处于入场起点，波自顶部往下错峰展开
    //（与账户页一致；否则行会挂载在入场动画中途--顶部行已半就位、底部行才起步，波看似从底部往上跑）
    if (revealPending && this.filtered.length > 0) {
      this.softRevealList()
    }
  }

  private consumeOpenDetail(): void {
    const id = AppStorage.get<string>(AppStorageKeys.OPEN_SUB_DETAIL_ID) ?? ''
    if (id.length === 0) {
      return
    }
    AppStorage.setOrCreate(AppStorageKeys.OPEN_SUB_DETAIL_ID, '')
    const found = this.subscriptions.find((s: Subscription) => s.id === id)
    if (found) {
      this.openSubDetail(found)
    }
  }

  private async doRefresh(): Promise<void> {
    try {
      await this.loadData()
    } finally {
      this.isRefreshing = false
    }
  }

  private computeSummary(): void {
    this.totalCount = this.subscriptions.length
    this.activeSubCount = this.subscriptions.filter(s => s.status === 'active').length

    const now = new Date()
    const thisYear = now.getFullYear()
    const thisMonth = now.getMonth() + 1
    
    const nextDate = new Date(now.getFullYear(), now.getMonth() + 1, 1)
    const nextYear = nextDate.getFullYear()
    const nextMonth = nextDate.getMonth() + 1

    let thisMonthSum = 0
    let nextMonthSum = 0
    let grandSum = 0

    for (const sub of this.subscriptions) {
      if (sub.status !== 'active') continue
      
      grandSum += sub.amount

      if (CalculationService.isSubscriptionDueInMonth(sub, thisYear, thisMonth)) {
        thisMonthSum += sub.amount
      }
      if (CalculationService.isSubscriptionDueInMonth(sub, nextYear, nextMonth)) {
        nextMonthSum += sub.amount
      }
    }

    // 顶部「到期日期」：取活跃订阅中未来到期的最早日期；优先 end_date，无结束日则兜底 next_billing_date
    let nearestDate = ''
    const todayYmd = Utils.todayString()
    const activeExpirySubs = this.subscriptions.filter(s =>
      s.status === 'active' &&
      (
        (s.end_date.length > 0 && s.end_date >= todayYmd) ||
        (s.end_date.length === 0 && s.next_billing_date.length > 0 && s.next_billing_date >= todayYmd)
      )
    )
    if (activeExpirySubs.length > 0) {
      activeExpirySubs.sort((a, b) => {
        const aDate = a.end_date.length > 0 ? a.end_date : a.next_billing_date
        const bDate = b.end_date.length > 0 ? b.end_date : b.next_billing_date
        return aDate.localeCompare(bDate)
      })
      nearestDate = activeExpirySubs[0].end_date.length > 0
        ? activeExpirySubs[0].end_date
        : activeExpirySubs[0].next_billing_date
    }

    this.thisMonthTotal = thisMonthSum
    this.nextMonthTotal = nextMonthSum
    this.grandTotal = grandSum
    this.nearestExpiryDate = nearestDate
  }

  private applyFilter(): void {
    let list = this.subscriptions.slice()
    if (this.keyword.trim().length > 0) {
      const k = this.keyword.trim().toLowerCase()
      list = list.filter(s => s.name.toLowerCase().indexOf(k) >= 0 || s.note.toLowerCase().indexOf(k) >= 0)
    }
    if (this.statusFilter !== 'all') {
      list = list.filter(s => s.status === this.statusFilter)
    }
    if (this.categoryFilter !== 'all') {
      list = list.filter(s => s.category === this.categoryFilter)
    }
    this.filtered = list
    this.syncListSource()
  }

  private syncListSource(): void {
    const objs: Object[] = []
    for (let i = 0; i < this.filtered.length; i++) {
      objs.push(this.filtered[i])
    }
    this.listSource.reload(objs)
  }

  private subFromItem(item: Object): Subscription {
    return item as Subscription
  }

  private onKeywordChange(v: string): void {
    this.keyword = v
    if (this.searchDebounce !== -1) {
      clearTimeout(this.searchDebounce)
    }
    this.searchDebounce = setTimeout(() => this.applyFilter(), 300)
  }

  private deleteSubscription(sub: Subscription): void {
    const config = new SheetDialogConfig(
      '删除确认',
      '确定删除订阅 "' + sub.name + '" 吗？',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('删除', this.theme.red, 'destructive')
      ]
    )
    this.openSheet(config, (index: number) => {
      if (index === 1) {
        this.doDelete(sub.id)
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

  private async doDelete(id: string): Promise<void> {
    try {
      try {
        this.listScroller.closeAllSwipeActions()
      } catch (_e) {
      }
      this.swipingSubId = ''
      await SubscriptionService.deleteSubscription(id)
      this.removeSubLocally(id)
      await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      this.notifyOthersListRefresh()
      AppToast.show(ErrorMessages.DELETE_OK, 1500)
    } catch (_e) {
      AppToast.show(ErrorMessages.DELETE_FAILED, 2500)
    }
  }

  /** 本地移除：更新 @State 数组触发 ForEach 退场 transition */
  private removeSubLocally(id: string): void {
    this.subscriptions = this.subscriptions.filter(s => s.id !== id)
    this.getUIContext().animateTo({
      duration: MotionTokens.listItemExitDuration,
      curve: Curve.EaseOut
    }, () => {
      this.filtered = this.filtered.filter(s => s.id !== id)
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
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (_e) {
    }
    this.swipingSubId = ''
    this.showStatusPanel = false
    this.showCategoryPanel = false
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
    return ListSelection.isAllSelected(this.selectedIds, this.filtered.map(s => s.id))
  }

  private toggleSelect(id: string): void {
    this.selectedIds = ListSelection.toggle(this.selectedIds, id)
  }

  private toggleSelectAll(): void {
    this.selectedIds = ListSelection.toggleAll(this.selectedIds, this.filtered.map(s => s.id))
  }

  private confirmDeleteBatch(): void {
    const count = this.selectedIds.length
    if (count === 0) {
      return
    }
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (_e) {
    }
    this.swipingSubId = ''
    const config = new SheetDialogConfig(
      '删除确认',
      '确定删除 ' + count + ' 项订阅吗？',
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
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (_e) {
    }
    this.swipingSubId = ''
    const failed = await runBatchDelete(ids, (id: string): Promise<void> => SubscriptionService.deleteSubscription(id))
    const succeeded = ListSelection.splitSucceeded(ids, failed)
    if (succeeded.length > 0) {
      this.removeSubsLocallyBatch(succeeded)
      this.computeSummary()
      await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      this.notifyOthersListRefresh()
    }
    this.exitSelectMode()
    AppToast.show(ListSelection.batchDeleteToast(succeeded.length, failed.length, '项'), failed.length === 0 ? 1500 : 2500)
  }

  /** 本地批量移除：一次 animateTo 退场 */
  private removeSubsLocallyBatch(ids: string[]): void {
    const idSet: Set<string> = new Set()
    for (let i = 0; i < ids.length; i++) {
      idSet.add(ids[i])
    }
    this.subscriptions = this.subscriptions.filter(s => !idSet.has(s.id))
    this.getUIContext().animateTo({
      duration: MotionTokens.listItemExitDuration,
      curve: Curve.EaseOut
    }, () => {
      this.filtered = this.filtered.filter(s => !idSet.has(s.id))
      this.syncListSource()
    })
  }

  private async togglePause(sub: Subscription): Promise<void> {
    const next: SubscriptionStatus = sub.status === 'active' ? 'paused' : 'active'
    await SubscriptionService.updateSubscriptionStatus(sub.id, next)
    await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
    // 本页 loadData 一次；其它 Tab 靠 notify（suppress 避免再刷本页）
    this.suppressNextListRefresh = true
    Constants.notifyListRefresh()
    this.loadData()
  }

  private goToEdit(sub: Subscription): void {
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (err) {
    }
    this.swipingSubId = ''
    AppStorage.setOrCreate(AppStorageKeys.SELECTED_SUBSCRIPTION_ID, sub.id)
    AppRouter.push(RouteNames.SUBSCRIPTION_FORM)
  }

  private subStatusRole(sub: Subscription): string {
    return statusTagRole(sub.status)
  }

  private subMark(sub: Subscription): string {
    const mark = PlatformService.getBrandVisual(sub.name).mark
    if (mark.length > 0) {
      return mark
    }
    const n = sub.name || ''
    return n.length > 0 ? n.substring(0, 1) : '订'
  }

  private subMarkColor(sub: Subscription): string {
    if (sub.color && sub.color.length > 0) {
      return sub.color
    }
    const v = PlatformService.getBrandVisual(sub.name)
    return v.color.length > 0 ? v.color : '#2F3336'
  }

  /** 详情弹窗：概览信息卡片数据 */
  private buildSubDetail(sub: Subscription, accountLabel: string): DetailSheetConfig {
    const cycleLabel = cycleDurationLabel(sub.billing_cycle)
    const c = new DetailSheetConfig()
    c.title = '订阅详情'
    c.name = sub.name
    c.subtitle = PlatformService.getCategoryInfo(sub.category).label
    c.badgeText = statusTagText(sub.status)
    c.badgeRole = this.subStatusRole(sub)
    c.mark = this.subMark(sub)
    c.markColor = this.subMarkColor(sub)
    c.iconUrl = sub.icon_url && sub.icon_url.length > 0 ? sub.icon_url : PlatformService.getLogoUrlForName(sub.name)
    c.heroLabel = '扣费金额'
    c.heroValue = Utils.formatMoney(sub.amount, false)
    c.heroUnit = '元'
    c.fields = [
      new DetailField('订阅期限', cycleLabel.length > 0 ? cycleLabel : '—'),
      new DetailField('下次扣费日', sub.next_billing_date ? sub.next_billing_date : '—'),
      new DetailField('扣费账户', accountLabel.length > 0 ? accountLabel : '未绑定'),
      new DetailField('扣费提醒', sub.reminder_enabled ? '提前 ' + sub.reminder_days_before + ' 天' : '已关闭')
    ]
    return c
  }

  private async loadAccountLabel(accountId: string): Promise<string> {
    const id = accountId || ''
    if (id.length === 0) {
      return ''
    }
    try {
      const acc = await CreditAccountService.getCreditAccountById(id)
      if (acc) {
        return creditAccountLabel(acc.name || '', acc.last_four || '')
      }
    } catch (_e) {
    }
    return ''
  }

  private async openSubDetail(sub: Subscription): Promise<void> {
    const accountLabel = await this.loadAccountLabel(sub.credit_account_id)
    this.detailConfig = this.buildSubDetail(sub, accountLabel)
    this.isDetailSheet = true
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showSheet = true
    })
  }

  private statusLabel(s: SubscriptionStatus | 'all'): string {
    if (s === 'all') {
      return '全部'
    }
    if (s === 'active') {
      return '生效中'
    }
    if (s === 'paused') {
      return '暂停'
    }
    return '已取消'
  }

  private categoryLabel(c: SubscriptionCategory | 'all'): string {
    if (c === 'all') {
      return '全部'
    }
    return PlatformService.getCategoryInfo(c).label
  }

  /** 列表项过渡：进入为逐项缓现（滚动懒挂载按当前进度取值，不重播），退出左滑淡出 */


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
  subListItem(sub: Subscription, index: number, total: number) {
    if (this.selectMode) {
      ListItem() {
        SubscriptionCard({
          subscription: sub,
          theme: this.theme,
          isSwiped: false,
          selectable: true,
          selected: this.isItemSelected(sub.id),
          isFirstInGroup: index === 0,
          isLastInGroup: index === total - 1
        })
      }
      .height(MotionTokens.listRowHeight)
      .opacity(listItemRevealProgress(this.revealT, index))
      .translate({ y: listItemRevealTranslateY(this.revealT, index) })
      .onClick(() => {
        this.toggleSelect(sub.id)
      })
      .transition(listExitTransition())
    } else {
      ListItem() {
        SubscriptionCard({
          subscription: sub,
          theme: this.theme,
          isSwiped: this.swipingSubId === sub.id,
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
              this.openSubDetail(sub)
            }),
          LongPressGesture({ repeat: false, duration: 400 })
            .onAction(() => {
              this.enterSelectMode(sub.id)
            })
        )
      )
      .swipeAction({
        end: {
          builder: () => {
            this.subSwipeActions(sub)
          }
        },
        onOffsetChange: (offset: number) => {
          if (offset < 0) {
            if (this.swipingSubId !== sub.id) {
              this.swipingSubId = sub.id
            }
          } else if (offset === 0) {
            if (this.swipingSubId === sub.id) {
              this.swipingSubId = ''
            }
          }
        }
      })
    }
  }

  @Builder
  subSwipeActions(sub: Subscription) {
    SwipeEditDeleteActions({
      theme: this.theme,
      actionHeight: 74,
      cornerRadius: this.theme.radiusSm,
      onEdit: () => {
        this.goToEdit(sub)
      },
      onDelete: () => {
        this.deleteSubscription(sub)
      }
    })
  }

  private expiryDateLabel(): string {
    const label = formatExpiryYmd(this.nearestExpiryDate)
    if (label.length > 0) {
      return Utils.maskIf(this.antiPeekMasked, label)
    }
    return '----'
  }

  /** 月度费用为 0 时的状态文案；脱敏态下统一遮蔽为金额占位 */
  private monthTotalZeroLabel(): string {
    return this.antiPeekMasked ? Utils.MASK_AMOUNT : '无费用'
  }

  private isNearestDateExpired(): boolean {
    if (!this.nearestExpiryDate) {
      return false
    }
    return Utils.daysFromNow(this.nearestExpiryDate) < 0
  }

  @Builder
  summaryHero() {
    Column({ space: 8 }) {
      // 主指标：总费用
      Row() {
        Column({ space: 2 }) {
          Text('总费用')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          if (this.antiPeekMasked) {
            Text(this.heroMonthText())
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
              Span(Utils.formatMoney(Math.round(this.grandTotal * this.heroCountT), false))
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
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)

      // 次要指标条：与负债页同源 — 虚线上纯文字组
      Row({ space: this.theme.spaceSm }) {
        Column({ space: 2 }) {
          Text('本月费用')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          if (this.thisMonthTotal === 0) {
            // 本月无扣费：标「无费用」；脱敏态统一遮蔽
            Text(this.monthTotalZeroLabel())
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.antiPeekMasked ? this.theme.text : this.theme.text2)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text(Utils.maskIf(this.antiPeekMasked,
              Utils.formatMoneyCompact(this.thisMonthTotal), Utils.MASK_AMOUNT))
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

        Column({ space: 2 }) {
          Text('下月费用')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          if (this.nextMonthTotal === 0) {
            // 下月无扣费：标「无费用」；脱敏态统一遮蔽
            Text(this.monthTotalZeroLabel())
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.antiPeekMasked ? this.theme.text : this.theme.text2)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          } else {
            Text(Utils.maskIf(this.antiPeekMasked,
              Utils.formatMoneyCompact(this.nextMonthTotal), Utils.MASK_AMOUNT))
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

        Column({ space: 2 }) {
          Text('到期日期')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          Text(this.expiryDateLabel())
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Medium)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.isNearestDateExpired() ? this.theme.statusDanger() : this.theme.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({ top: this.theme.spaceSm })
      .border({ width: { top: 1 }, color: this.theme.borderSoft, style: BorderStyle.Dashed })
    }
    .width('100%')
    .padding(16)
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusXl)
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow(this.theme.floatShadowOptions())
  }

  private isStatusFiltered(): boolean {
    return this.statusFilter !== 'all'
  }

  private isCategoryFiltered(): boolean {
    return this.categoryFilter !== 'all'
  }

  private toggleStatusPanel(): void {
    this.showStatusPanel = !this.showStatusPanel
    if (this.showStatusPanel) {
      this.showCategoryPanel = false
    }
  }

  private toggleCategoryPanel(): void {
    this.showCategoryPanel = !this.showCategoryPanel
    if (this.showCategoryPanel) {
      this.showStatusPanel = false
    }
  }

  private selectStatus(s: SubscriptionStatus | 'all'): void {
    this.statusFilter = s
    this.applyFilter()
    this.showStatusPanel = false
    this.showCategoryPanel = false
  }

  private selectCategory(c: SubscriptionCategory | 'all'): void {
    this.categoryFilter = c
    this.applyFilter()
    this.showStatusPanel = false
    this.showCategoryPanel = false
  }

  private openReceipt(): void {
    const model = SubscriptionReceipt.build(this.subscriptions, new Date().getFullYear())
    if (model.itemCount === 0) {
      AppToast.show('没有生效中的订阅', 1600)
      return
    }
    AppStorage.setOrCreate(AppStorageKeys.RECEIPT_MODEL, model)
    AppStorage.setOrCreate(AppStorageKeys.SHOW_RECEIPT_OVERLAY, true)
    this.showStatusPanel = false
    this.showCategoryPanel = false
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
      this.openReceipt()
    })
  }

  /** 标题栏右上：分享/状态/分类悬浮胶囊（surface2 + pill + floatShadow） */
  @Builder
  filterCapsule() {
    Row({ space: 0 }) {
      this.shareBtn()
      Row()
        .width(0.5)
        .height(16)
        .backgroundColor(this.theme.borderSoft)
        .margin({ left: 2, right: 2 })
      this.statusFilterBtn()
      this.categoryFilterBtn()
    }
    .padding({ left: 3, right: 3, top: 3, bottom: 3 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusPill)
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow(this.theme.floatShadowOptions())
  }


  @Builder
  statusFilterBtn() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Image($r('app.media.ic_filter_status'))
          .width(20)
          .height(20)
          .fillColor(this.isStatusFiltered() || this.showStatusPanel ? this.theme.primary : this.theme.text2)
          .objectFit(ImageFit.Contain)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.showStatusPanel ? Utils.hexToRgba(this.theme.primary, 0.12) : Color.Transparent)
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
      this.toggleStatusPanel()
    })
  }

  @Builder
  categoryFilterBtn() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Image($r('app.media.ic_filter_category'))
          .width(20)
          .height(20)
          .fillColor(this.isCategoryFiltered() || this.showCategoryPanel ? this.theme.primary : this.theme.text2)
          .objectFit(ImageFit.Contain)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.showCategoryPanel ? Utils.hexToRgba(this.theme.primary, 0.12) : Color.Transparent)
      .borderRadius(this.theme.radiusPill)

      if (this.isCategoryFiltered()) {
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
      this.toggleCategoryPanel()
    })
  }

  private statusOptionLabels(): string[] {
    const labels: string[] = []
    for (let i = 0; i < this.statuses.length; i++) {
      labels.push(this.statusLabel(this.statuses[i]))
    }
    return labels
  }

  private categoryOptionLabels(): string[] {
    const labels: string[] = []
    for (let i = 0; i < this.categories.length; i++) {
      labels.push(this.categoryLabel(this.categories[i]))
    }
    return labels
  }

  private statusSelectedIndex(): number {
    for (let i = 0; i < this.statuses.length; i++) {
      if (this.statuses[i] === this.statusFilter) {
        return i
      }
    }
    return 0
  }

  private categorySelectedIndex(): number {
    for (let i = 0; i < this.categories.length; i++) {
      if (this.categories[i] === this.categoryFilter) {
        return i
      }
    }
    return 0
  }

  /** 状态筛选：右上紧凑纵向勾选菜单 */
  @Builder
  statusPanel() {
    FilterSortMenuPanel({
      theme: this.theme,
      title: '状态',
      icon: $r('app.media.ic_filter_status'),
      options: this.statusOptionLabels(),
      selectedIndex: this.statusSelectedIndex(),
      onSelect: (index: number) => {
        if (index >= 0 && index < this.statuses.length) {
          this.selectStatus(this.statuses[index])
        }
      }
    })
  }

  /** 分类筛选：右上紧凑纵向勾选菜单 */
  @Builder
  categoryPanel() {
    FilterSortMenuPanel({
      theme: this.theme,
      title: '分类',
      icon: $r('app.media.ic_filter_category'),
      options: this.categoryOptionLabels(),
      selectedIndex: this.categorySelectedIndex(),
      menuWidth: 144,
      maxBodyHeight: 360,
      onSelect: (index: number) => {
        if (index >= 0 && index < this.categories.length) {
          this.selectCategory(this.categories[index])
        }
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      // 标题栏：选择态 居中已选N；正常态 标题 + 状态/分类/管理胶囊
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
            Text('订阅')
              .fontSize(TypeScale.heroTitle)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .letterSpacing(TypeScale.heroTitleSpacing)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.subscriptions.length > 0) {
            this.filterCapsule()
          }
        }
        .width('100%')
        .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, top: 10 + this.topSafe, bottom: 8 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.topBarBg())
      }

      // 顶部预览：主指标 + 次要条
      if (this.subscriptions.length > 0 && !this.selectMode) {
        Column() {
          this.summaryHero()
        }
        .width('100%')
        .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, bottom: 14 })
      }

      // 搜索（全宽；筛选已上移标题栏；批量选择时隐藏以保持选择集稳定）
      if (this.subscriptions.length > 0 && !this.selectMode) {
        Column() {
          TextInput({ text: this.keyword, placeholder: '如：爱奇艺' })
            .fontSize(TypeScale.control)
            .fontColor(this.theme.text)
            .placeholderColor(this.theme.text3)
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
              if (this.searchDebounce !== -1) {
                clearTimeout(this.searchDebounce)
                this.searchDebounce = -1
              }
              this.applyFilter()
            })
            .onChange((v: string) => this.onKeywordChange(v))
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
      } else if (this.subscriptions.length === 0) {
        EmptyState({
          theme: this.theme,
          showIllustration: true,
          objectStage: true,
          illustration: $r('app.media.empty_subscription'),
          title: '暂无订阅',
          subtitle: '记录订阅服务与扣费日',
          hint: ''
        })
          .width('100%')
          .layoutWeight(1)
      } else if (this.filtered.length === 0) {
        EmptyState({
          theme: this.theme,
          icon: $r('app.media.ic_search_empty'),
          iconColor: this.theme.text2,
          title: '无匹配结果',
          subtitle: '调整搜索词或筛选条件',
          outlineLabel: this.keyword.trim().length > 0
            ? (this.isStatusFiltered() || this.isCategoryFiltered() ? '重置条件' : '清空搜索')
            : '重置筛选',
          outlineAction: () => {
            this.keyword = ''
            this.statusFilter = 'all'
            this.categoryFilter = 'all'
            this.applyFilter()
          }
        })
          .width('100%')
          .layoutWeight(1)
      } else {
        Refresh({ refreshing: $$this.isRefreshing }) {
          // 列表铺满可用区（可滚入悬浮 Tab 下方）；底栏避让用尾部 ListItem 占位，勿对 List/Column 做 bottom padding
          Column() {
            List({ space: 0, scroller: this.listScroller }) {
              LazyForEach(this.listSource, (item: Object, index: number) => {
                this.subListItem(this.subFromItem(item), index, this.listSource.totalCount())
              }, (item: Object) => {
                const s = this.subFromItem(item)
                return s.id + '#' + s.updated_at
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
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
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

    // 筛选菜单：右上紧凑浮层（无压暗；极淡底才能接到点击，Color.Transparent 会被跳过）
    if (!this.selectMode && this.subscriptions.length > 0 && (this.showStatusPanel || this.showCategoryPanel)) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.001)')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          this.showStatusPanel = false
          this.showCategoryPanel = false
        })

      Column() {
        if (this.showStatusPanel) {
          this.statusPanel()
        }
        if (this.showCategoryPanel) {
          this.categoryPanel()
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
        this.isDetailSheet = false
      }
    })
  }

  @Builder
  sheetBuilder() {
    if (this.isDetailSheet) {
      DetailSheetView({
        theme: this.theme,
        config: this.detailConfig,
        onClose: () => {
          this.showSheet = false
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
