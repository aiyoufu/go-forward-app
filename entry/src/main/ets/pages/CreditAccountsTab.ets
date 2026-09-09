import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens, ArrayDataSource } from 'common'
import { Utils } from 'common'
import { CreditAccount } from 'common'
import { CreditAccountService } from 'service'
import { WidgetUpdateService } from 'service'
import { UserService } from 'service'
import { LocalDataStore } from 'service'
import { CreditAccountCard } from 'components'
import { SwipeEditDeleteActions } from 'components'
import { PlatformService } from 'service'
import { Constants } from 'common'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton } from 'components'
import { DetailSheetView, DetailSheetConfig, DetailField } from 'components'
import { EmptyState } from 'components'
import { FilterSortMenuPanel } from 'components'
import { SkeletonList } from 'components'
import { AppStorageKeys } from 'common'
import { AppRouter, RouteNames } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { ListSelection, runBatchDelete } from './common/ListSelection'
import { BatchSelectHeader, BatchActionOverlay } from './common/BatchShell'
import { ListReveal, HeroCounter, listExitTransition, listItemRevealProgress, listItemRevealTranslateY, topBarFadeRatio } from './common/ListReveal'
import { fetchEffectiveTheme } from './common/ThemeLoader'

@Component
export struct CreditAccountsTab {
  @State accounts: CreditAccount[] = []
  /** 筛选结果；列表走 listSource + LazyForEach */
  @State filteredAccounts: CreditAccount[] = []
  private listSource: ArrayDataSource = new ArrayDataSource()
  @State theme: ThemeColors = ThemeManager.DARK
  @StorageProp(AppStorageKeys.TOP_SAFE_HEIGHT) topSafe: number = 0
  /** 防窥脱敏态：系统检测到窥视时额度主数字打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  @State accountCount: number = 0
  @State totalCreditLimit: number = 0
  @State expiringCount: number = 0
  @State billingCycleCount: number = 0
  @State keyword: string = ''
  /** 0 出单日 · 1 还款日 · 2 额度（默认） */
  @State sortIndex: number = 0
  /** 标题栏右侧：排序展开面板（悬浮卡片，不挤压内容） */
  @State showSortPanel: boolean = false
  @State showSheet: boolean = false
  @State isRefreshing: boolean = false
  @State isDetailSheet: boolean = false
  @State detailConfig: DetailSheetConfig = new DetailSheetConfig()
  @State sheetConfig: SheetDialogConfig = new SheetDialogConfig()
  private sheetCallback: (index: number) => void = () => {}
  private readonly sorts: string[] = ['出单日', '还款日', '额度']
  @StorageLink('ambientLux') @Watch('onLuxChange') lux: number = -1
  @StorageLink('systemDark') @Watch('onLuxChange') systemDark: boolean = false
  @StorageLink('themeRevision') @Watch('onThemeRevision') themeRevision: number = 0
  private searchTimer: number = -1
  /** 首载骨架：仅首次进入显示，后续刷新不重播 */
  @State private loading: boolean = true
  /** 滚动驱动顶栏背景透明度 0→1 */
  @State private topBarAlpha: number = 0
  private readonly topBarFadeDistance: number = 80
  /** 本页刚本地更新过，忽略紧随其后的 listRefresh 自刷新 */
  private suppressNextListRefresh: boolean = false
  @StorageLink('listRefreshToken') @Watch('onListRefresh') listRefreshToken: number = 0
  @State swipingAccountId: string = ''
  /** 批量选择模式 */
  @State selectMode: boolean = false
  /** 已选 id（数组重新赋值驱动 ForEach 选中态刷新） */
  @State selectedIds: string[] = []
  /** 与 MainPage 同步多选态，使返回手势可先退多选 */
  @StorageLink('listSelectMode') @Watch('onSelectModeRemoteChange') selectModeSync: boolean = false
  /** 列表逐项缓现（Apple per-row 模型，bpta-fair-use-animation）：行按 index 错峰，滚动/刷新不重播 */
  @State private revealT: number = 0
  private listReveal: ListReveal = new ListReveal()
  /** 顶部数字 0→目标 滚动 */
  @State private heroCountT: number = 1
  private heroCounter: HeroCounter = new HeroCounter()
  private listScroller: ListScroller = new ListScroller()
  @StorageProp('mainTabIndex') @Watch('onTabChange') mainTabIndex: number = 0
  private lastHandledRefreshToken: number = 0

  private onTabChange(): void {
    this.showSortPanel = false
    this.exitSelectMode()
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (err) {
    }
    this.swipingAccountId = ''
    if (this.mainTabIndex === 3) {
      this.resetListScrollToTop()
      const stale = this.listRefreshToken !== this.lastHandledRefreshToken
      const alreadyShown = this.accounts.length > 0 && this.revealT >= 1
      if (stale || !alreadyShown) {
        this.lastHandledRefreshToken = this.listRefreshToken
        this.loadData()
        this.playHeroCount()
        this.softRevealList()
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
    if (this.mainTabIndex === 3) {
      this.softRevealList()
    } else {
      this.resetListRevealSilent()
    }
  }

  private playHeroCount(): void {
    this.heroCounter.play((t: number) => {
      this.heroCountT = t
    })
  }

  private heroCountText(): string {
    return '' + Math.round(this.accountCount * this.heroCountT)
  }

  private heroLimitText(): string {
    if (this.antiPeekMasked) {
      return Utils.MASK_TEXT
    }
    const v = this.totalCreditLimit * this.heroCountT
    if (v <= 0) {
      return '0'
    }
    if (v >= 100) {
      return v.toFixed(0)
    }
    const s = v.toFixed(2)
    if (s.endsWith('00')) {
      return v.toFixed(0)
    }
    if (s.endsWith('0')) {
      return v.toFixed(1)
    }
    return s
  }

  private heroExpiringText(): string {
    return '' + Math.round(this.expiringCount * this.heroCountT)
  }

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.loadTheme(false)
    // Tab 常驻：仅当前就是本页时拉数，避免进首页连带扫账户表
    if (this.mainTabIndex === 3) {
      this.loadData()
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
    if (this.mainTabIndex !== 3) {
      return
    }
    this.lastHandledRefreshToken = this.listRefreshToken
    this.loadData()
    this.playHeroCount()
    if (this.mainTabIndex === 3) {
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

  private async loadData(): Promise<void> {
    const seq = this.loadSeq + 1
    this.loadSeq = seq
    const epochAtStart = LocalDataStore.getEpoch()
    try {
      const cached = LocalDataStore.getAccounts()
      if (cached !== null && seq === this.loadSeq) {
        this.applyAccountList(cached, false)
        this.loading = false
      }
      const list = await CreditAccountService.getCreditAccounts()
      if (seq !== this.loadSeq) {
        return
      }
      if (LocalDataStore.isEpochCurrent(epochAtStart)) {
        LocalDataStore.setAccounts(list)
      }
      this.applyAccountList(list, true)
    } catch {
      if (seq !== this.loadSeq) {
        return
      }
      this.accounts = []
      this.filteredAccounts = []
      this.listSource.clear()
      this.accountCount = 0
      this.totalCreditLimit = 0
      this.expiringCount = 0
      this.billingCycleCount = 0
    }
    if (seq === this.loadSeq) {
      this.loading = false
      this.consumeOpenDetail()
    }
  }

  private consumeOpenDetail(): void {
    const id = AppStorage.get<string>(AppStorageKeys.OPEN_ACCOUNT_DETAIL_ID) ?? ''
    if (id.length === 0) {
      return
    }
    AppStorage.setOrCreate(AppStorageKeys.OPEN_ACCOUNT_DETAIL_ID, '')
    const found = this.accounts.find((a: CreditAccount) => a.id === id)
    if (found) {
      this.openAccountDetail(found)
    }
  }

  /** playHero：仅 RDB hydrate 后且数字变化时重播 */
  private applyAccountList(list: CreditAccount[], playHero: boolean): void {
    let limit = 0
    let expiring = 0
    let billing = 0
    const now = new Date()
    const inThreeMonths = new Date(now.getFullYear(), now.getMonth() + 3, now.getDate())
    const exp = new Date()

    for (let i = 0; i < list.length; i++) {
      const a: CreditAccount = list[i]
      const lim = Number(a.credit_limit)
      if (!Number.isNaN(lim)) {
        limit += lim
      }
      if (a.bill_day > 0 && a.payment_day > 0) {
        billing++
      }
      if (a.expiry_date && a.expiry_date.length > 0) {
        const parts = a.expiry_date.split('/')
        if (parts.length === 2) {
          const mm = Number(parts[0])
          const yy = Number(parts[1]) + 2000
          if (!Number.isNaN(mm) && !Number.isNaN(yy) && mm >= 1 && mm <= 12) {
            exp.setFullYear(yy, mm - 1, 1)
            exp.setHours(0, 0, 0, 0)
            if (exp.getTime() <= inThreeMonths.getTime()) {
              expiring++
            }
          }
        }
      }
    }

    const prevCount = this.accountCount
    const prevLimit = this.totalCreditLimit
    const prevExpiring = this.expiringCount
    this.accounts = list
    this.accountCount = list.length
    this.totalCreditLimit = limit
    this.expiringCount = expiring
    this.billingCycleCount = billing
    this.applyFilter()
    if (playHero && (prevCount !== this.accountCount ||
      prevLimit !== this.totalCreditLimit ||
      prevExpiring !== this.expiringCount)) {
      this.playHeroCount()
    }
  }

  private async doRefresh(): Promise<void> {
    try {
      await this.loadData()
    } finally {
      this.isRefreshing = false
    }
  }

  private onKeywordChange(v: string): void {
    this.keyword = v
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer)
    }
    this.searchTimer = setTimeout(() => {
      this.searchTimer = -1
      this.applyFilter()
    }, 250)
  }

  private applyFilter(): void {
    const q = this.keyword.trim().toLowerCase()
    let result: CreditAccount[] = []
    if (q.length === 0) {
      result = this.accounts.slice()
    } else {
      for (let i = 0; i < this.accounts.length; i++) {
        const a = this.accounts[i]
        const name = (a.name || '').toLowerCase()
        const last = (a.last_four || '').toLowerCase()
        if (name.includes(q) || last.includes(q)) {
          result.push(a)
        }
      }
    }
    this.sortAccounts(result)
    this.filteredAccounts = result
    this.syncListSource()
  }

  private syncListSource(): void {
    const objs: Object[] = []
    for (let i = 0; i < this.filteredAccounts.length; i++) {
      objs.push(this.filteredAccounts[i])
    }
    this.listSource.reload(objs)
  }

  private accountFromItem(item: Object): CreditAccount {
    return item as CreditAccount
  }

  private sortAccounts(list: CreditAccount[]): void {
    const mode = this.sortIndex
    list.sort((a: CreditAccount, b: CreditAccount) => {
      if (mode === 0) {
        // 出单日升序
        return (a.bill_day || 0) - (b.bill_day || 0)
      }
      if (mode === 1) {
        // 还款日升序
        return (a.payment_day || 0) - (b.payment_day || 0)
      }
      // 额度降序
      return (Number(b.credit_limit) || 0) - (Number(a.credit_limit) || 0)
    })
  }

  private selectSort(index: number): void {
    this.sortIndex = index
    this.showSortPanel = false
    this.applyFilter()
    this.playHeroCount()
  }

  private isSortActive(): boolean {
    return this.sortIndex !== 0
  }

  private toggleSortPanel(): void {
    this.showSortPanel = !this.showSortPanel
  }

  private totalLimitLabel(): string {
    const v = this.totalCreditLimit
    if (v <= 0) {
      return '0'
    }
    if (v >= 100) {
      return v.toFixed(0)
    }
    // 去掉多余尾零：32.60 → 32.6
    const s = v.toFixed(2)
    if (s.endsWith('00')) {
      return v.toFixed(0)
    }
    if (s.endsWith('0')) {
      return v.toFixed(1)
    }
    return s
  }

  private avgLimitLabel(): string {
    if (this.accountCount <= 0) {
      return '0'
    }
    // 随主数字同倍率入场（heroCountT），与数量/即将到期保持一致
    const avg = this.totalCreditLimit * this.heroCountT / this.accountCount
    if (avg >= 100) {
      return avg.toFixed(0)
    }
    const s = avg.toFixed(1)
    if (s.endsWith('.0')) {
      return avg.toFixed(0)
    }
    return s
  }

  /** 顶部预览：总额度为主数字，账户数量/平均额度/即将到期退三联次要行（与负债/订阅页同构） */
  @Builder
  summaryHero() {
    Column({ space: 8 }) {
      Column({ space: 2 }) {
        Text('总额度')
          .fontSize(TypeScale.captionSm)
          .fontColor(this.theme.text3)
        // 单 Text 多 Span：数字与「万」共享一条基线、字形贴底；Row 包围盒贴底会让小字沉到基线下
        Text() {
          Span(this.heroLimitText())
            .fontSize(TypeScale.heroNumber)
            .fontWeight(FontWeight.Bold)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
            .letterSpacing(TypeScale.heroNumberSpacing)
          if (!this.antiPeekMasked) {
            Span(' 万')
              .fontSize(TypeScale.heroNumberSymbol)
              .fontWeight(FontWeight.Bold)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.theme.text)
          }
        }
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')

      // 次要三联：虚线上纯文字组，无 chip 框；「即将到期」保留条件展示
      Row({ space: this.theme.spaceSm }) {
        Column({ space: 2 }) {
          Text('账户数量')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          Text(this.heroCountText() + ' 个')
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Medium)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Text('平均额度')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
          Text(this.avgLimitLabel() + '万')
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Medium)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.theme.text)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.expiringCount > 0) {
          Column({ space: 2 }) {
            Text('即将到期')
              .fontSize(TypeScale.captionSm)
              .fontColor(this.theme.text3)
            Text(this.heroExpiringText() + ' 张')
              .fontSize(TypeScale.bodySm)
              .fontWeight(FontWeight.Medium)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.theme.statusWarning())
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
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

  private deleteAccount(account: CreditAccount): void {
    const config = new SheetDialogConfig(
      '删除确认',
      '确定删除账户 "' + account.name + '" 吗？关联的负债/订阅将解除绑定。',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('删除', this.theme.red, 'destructive')
      ]
    )
    this.openSheet(config, (index: number) => {
      if (index === 1) {
        this.doDelete(account.id)
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
      this.swipingAccountId = ''
      await CreditAccountService.deleteCreditAccount(id)
      this.removeAccountLocally(id)
      this.notifyOthersListRefresh()
      const ctx = this.getUIContext().getHostContext() as Context
      if (ctx) {
        WidgetUpdateService.updateAll(ctx)
      }
      AppToast.show(ErrorMessages.DELETE_OK, 1500)
    } catch (_e) {
      AppToast.show(ErrorMessages.DELETE_FAILED, 2500)
    }
  }

  /** 本地移除：更新 @State 数组触发 ForEach 退场 transition */
  private removeAccountLocally(id: string): void {
    this.accounts = this.accounts.filter(a => a.id !== id)
    this.getUIContext().animateTo({
      duration: MotionTokens.listItemExitDuration,
      curve: Curve.EaseOut
    }, () => {
      this.filteredAccounts = this.filteredAccounts.filter(a => a.id !== id)
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
    this.swipingAccountId = ''
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
    return ListSelection.isAllSelected(this.selectedIds, this.filteredAccounts.map(a => a.id))
  }

  private toggleSelect(id: string): void {
    this.selectedIds = ListSelection.toggle(this.selectedIds, id)
  }

  private toggleSelectAll(): void {
    this.selectedIds = ListSelection.toggleAll(this.selectedIds, this.filteredAccounts.map(a => a.id))
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
    this.swipingAccountId = ''
    const config = new SheetDialogConfig(
      '删除确认',
      '确定删除 ' + count + ' 个账户吗？关联的负债/订阅将解除绑定。',
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
    this.swipingAccountId = ''
    const failed = await runBatchDelete(ids, (id: string): Promise<void> => CreditAccountService.deleteCreditAccount(id))
    const succeeded = ListSelection.splitSucceeded(ids, failed)
    if (succeeded.length > 0) {
      this.removeAccountsLocallyBatch(succeeded)
      // 重算摘要（数量/额度/到期）并刷新过滤，保持 hero 与列表一致
      this.applyAccountList(this.accounts, false)
      this.notifyOthersListRefresh()
    }
    this.exitSelectMode()
    AppToast.show(ListSelection.batchDeleteToast(succeeded.length, failed.length, '个'), failed.length === 0 ? 1500 : 2500)
  }

  /** 本地批量移除：一次 animateTo 退场 */
  private removeAccountsLocallyBatch(ids: string[]): void {
    const idSet: Set<string> = new Set()
    for (let i = 0; i < ids.length; i++) {
      idSet.add(ids[i])
    }
    this.accounts = this.accounts.filter(a => !idSet.has(a.id))
    this.getUIContext().animateTo({
      duration: MotionTokens.listItemExitDuration,
      curve: Curve.EaseOut
    }, () => {
      this.filteredAccounts = this.filteredAccounts.filter(a => !idSet.has(a.id))
      this.syncListSource()
    })
  }

  private goToEdit(account: CreditAccount): void {
    try {
      this.listScroller.closeAllSwipeActions()
    } catch (err) {
    }
    this.swipingAccountId = ''
    AppStorage.setOrCreate(AppStorageKeys.SELECTED_CREDIT_ACCOUNT_ID, account.id)
    AppRouter.push(RouteNames.CREDIT_ACCOUNT_FORM)
  }

  private accountLimitText(account: CreditAccount): string {
    const limit = Number(account.credit_limit) || 0
    if (limit <= 0) {
      return '—'
    }
    if (limit >= 100) {
      return limit.toFixed(0)
    }
    const s = limit.toFixed(2)
    if (s.endsWith('00')) {
      return limit.toFixed(0)
    }
    if (s.endsWith('0')) {
      return limit.toFixed(1)
    }
    return s
  }

  private accountMarkColor(account: CreditAccount): string {
    const visual = PlatformService.getBrandVisual(account.name)
    if (visual.matchedKey.length > 0 && visual.color.length > 0) {
      return visual.color
    }
    if (account.color && account.color.length > 0) {
      return account.color
    }
    return visual.color.length > 0 ? visual.color : '#2F3336'
  }

  /** 详情弹窗：概览信息卡片数据 */
  private buildAccountDetail(account: CreditAccount): DetailSheetConfig {
    const hasLimit = (Number(account.credit_limit) || 0) > 0
    const c = new DetailSheetConfig()
    c.title = '账户详情'
    c.name = account.name ? account.name : '未命名账户'
    c.nameTag = account.last_four && account.last_four.trim().length > 0 ? account.last_four.trim() : ''
    c.nameTagOnNewLine = true
    const visual = PlatformService.getBrandVisual(account.name)
    c.mark = visual.mark
    c.markColor = this.accountMarkColor(account)
    c.iconUrl = account.icon_url && account.icon_url.length > 0 ? account.icon_url :
      PlatformService.getLogoUrlForName(account.name)
    c.cardFace = account.icon_url !== undefined && account.icon_url.length > 0
    c.heroLabel = '信用额度'
    c.heroValue = this.accountLimitText(account)
    c.heroUnit = hasLimit ? '万' : ''
    c.fields = [
      new DetailField('出单日', account.bill_day > 0 ? '每月 ' + account.bill_day + ' 日' : '未设置'),
      new DetailField('还款日', account.payment_day > 0 ? '每月 ' + account.payment_day + ' 日' : '未设置'),
      new DetailField('免息期', account.interest_free_days > 0 ? account.interest_free_days + ' 天' : '—'),
      new DetailField('宽限期', account.grace_period_days > 0 ? account.grace_period_days + ' 天' : '—'),
      new DetailField('年费进度', account.annual_fee_required_swipes > 0
        ? account.annual_fee_manual_swipes + '/' + account.annual_fee_required_swipes + ' 次'
        : '—'),
      new DetailField('有效期', account.expiry_date || '—')
    ]
    return c
  }

  private openAccountDetail(account: CreditAccount): void {
    this.detailConfig = this.buildAccountDetail(account)
    this.isDetailSheet = true
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showSheet = true
    })
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
  accountListItem(account: CreditAccount, index: number, total: number) {
    if (this.selectMode) {
      ListItem() {
        CreditAccountCard({
          account: account,
          theme: this.theme,
          isSwiped: false,
          selectable: true,
          selected: this.isItemSelected(account.id),
          isFirstInGroup: index === 0,
          isLastInGroup: index === total - 1
        })
      }
      // 与卡片固定高度一致，避免侧滑区被撑高
      .height(MotionTokens.listRowHeight)
      .opacity(listItemRevealProgress(this.revealT, index))
      .translate({ y: listItemRevealTranslateY(this.revealT, index) })
      .onClick(() => {
        this.toggleSelect(account.id)
      })
      .transition(listExitTransition())
    } else {
      ListItem() {
        CreditAccountCard({
          account: account,
          theme: this.theme,
          isSwiped: this.swipingAccountId === account.id,
          isFirstInGroup: index === 0,
          isLastInGroup: index === total - 1
        })
      }
      // 与卡片固定高度一致，避免侧滑区被撑高
      .height(MotionTokens.listRowHeight)
      .opacity(listItemRevealProgress(this.revealT, index))
      .translate({ y: listItemRevealTranslateY(this.revealT, index) })
      .transition(listExitTransition())
      .gesture(
        GestureGroup(GestureMode.Exclusive,
          TapGesture({ count: 1 })
            .onAction(() => {
              this.openAccountDetail(account)
            }),
          LongPressGesture({ repeat: false, duration: 400 })
            .onAction(() => {
              this.enterSelectMode(account.id)
            })
        )
      )
      .swipeAction({
        end: {
          builder: () => {
            this.accountSwipeActions(account)
          }
        },
        onOffsetChange: (offset: number) => {
          if (offset < 0) {
            if (this.swipingAccountId !== account.id) {
              this.swipingAccountId = account.id
            }
          } else if (offset === 0) {
            if (this.swipingAccountId === account.id) {
              this.swipingAccountId = ''
            }
          }
        }
      })
    }
  }

  @Builder
  accountSwipeActions(account: CreditAccount) {
    SwipeEditDeleteActions({
      theme: this.theme,
      actionHeight: 74,
      cornerRadius: this.theme.radiusSm,
      onEdit: () => {
        this.goToEdit(account)
      },
      onDelete: () => {
        this.deleteAccount(account)
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column() {
      // 标题栏：选择态 居中已选N；正常态 标题 + 排序/管理胶囊
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
            Text('账户')
              .fontSize(TypeScale.heroTitle)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .letterSpacing(TypeScale.heroTitleSpacing)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          if (this.accounts.length > 0) {
            this.sortCapsule()
          }
        }
        .width('100%')
        .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, top: 10 + this.topSafe, bottom: 8 })
        .justifyContent(FlexAlign.SpaceBetween)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.topBarBg())
      }

      // 顶部预览：与订阅页同结构
      if (this.accounts.length > 0 && !this.selectMode) {
        Column() {
          this.summaryHero()
        }
        .width('100%')
        .padding({ left: this.theme.pageHorizontalPadding, right: this.theme.pageHorizontalPadding, bottom: 14 })
      }

      // 搜索（全宽；排序已上移标题栏；批量选择时隐藏以保持选择集稳定）
      if (this.accounts.length > 0 && !this.selectMode) {
        Column() {
          TextInput({ text: this.keyword, placeholder: '如：招商' })
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
              if (this.searchTimer !== -1) {
                clearTimeout(this.searchTimer)
                this.searchTimer = -1
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
      } else if (this.accounts.length === 0) {
        EmptyState({
          theme: this.theme,
          showIllustration: true,
          objectStage: true,
          illustration: $r('app.media.empty_account'),
          title: '暂无账户',
          subtitle: '记录额度、出单日与还款日',
          hint: ''
        })
          .width('100%')
          .layoutWeight(1)
      } else if (this.filteredAccounts.length === 0) {
        EmptyState({
          theme: this.theme,
          icon: $r('app.media.ic_search_empty'),
          iconColor: this.theme.text2,
          title: '无匹配结果',
          subtitle: '调整搜索词',
          outlineLabel: '清空搜索',
          outlineAction: () => {
            this.keyword = ''
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
                this.accountListItem(this.accountFromItem(item), index, this.listSource.totalCount())
              }, (item: Object) => {
                const a = this.accountFromItem(item)
                return a.id + '#' + a.updated_at
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

    // 排序菜单：右上紧凑浮层（无压暗；极淡底才能接到点击，Color.Transparent 会被跳过）
    if (!this.selectMode && this.accounts.length > 0 && this.showSortPanel) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.001)')
        .hitTestBehavior(HitTestMode.Default)
        .onClick(() => {
          this.showSortPanel = false
        })

      Column() {
        this.sortPanel()
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

  /** 标题栏右上：排序/管理悬浮胶囊（surface2 + pill + floatShadow） */
  @Builder
  sortCapsule() {
    Row({ space: 0 }) {
      this.sortFilterBtn()
    }
    .padding({ left: 3, right: 3, top: 3, bottom: 3 })
    .backgroundColor(this.theme.surface2)
    .borderRadius(this.theme.radiusPill)
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow(this.theme.floatShadowOptions())
  }


  @Builder
  sortFilterBtn() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        Image($r('app.media.ic_filter_sort'))
          .width(20)
          .height(20)
          .fillColor(this.isSortActive() || this.showSortPanel ? this.theme.primary : this.theme.text2)
          .objectFit(ImageFit.Contain)
      }
      .width(32)
      .height(32)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.showSortPanel ? Utils.hexToRgba(this.theme.primary, 0.12) : Color.Transparent)
      .borderRadius(this.theme.radiusPill)

      if (this.isSortActive()) {
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
