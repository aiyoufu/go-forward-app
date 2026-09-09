import {
  AppStorageKeys,
  AppRouter,
  AppToast,
  MotionHelper,
  MotionTokens,
  Notification,
  RouteNames,
  ThemeColors,
  ThemeManager,
  TypeScale,
  Utils
} from 'common'
import { NotificationService } from 'service'
import { EmptyState } from './EmptyState'
import { StatusTag } from './StatusTag'
import { SheetHeader, sheetBottomInset } from './SheetDialog'
import { promptAction } from '@kit.ArkUI'

/** 通知跳转目标：空 route 表示不可跳转 */
export class NotificationNavTarget {
  route: string = ''
  storageKey: string = ''
  storageValue: string = ''
}

export class NotificationGroup {
  key: string = ''
  label: string = ''
  items: Notification[] = []
}

/** 扁平化列表行：分组标题与通知条目同一 ForEach，避免 List 内嵌套 ForEach */
export class InboxRow {
  id: string = ''
  kind: string = 'item'
  label: string = ''
  notification: Notification = new Notification()
  lastInGroup: boolean = false
}

export function flattenNotificationGroups(groups: NotificationGroup[]): InboxRow[] {
  const rows: InboxRow[] = []
  for (let i = 0; i < groups.length; i++) {
    const g = groups[i]
    const header = new InboxRow()
    header.id = 'h-' + g.key
    header.kind = 'header'
    header.label = g.label
    rows.push(header)
    for (let j = 0; j < g.items.length; j++) {
      const row = new InboxRow()
      row.id = g.items[j].id
      row.kind = 'item'
      row.notification = g.items[j]
      row.lastInGroup = j === g.items.length - 1
      rows.push(row)
    }
  }
  return rows
}

export function notificationTypeLabel(t: string): string {
  if (t === 'payment_due') {
    return '还款提醒'
  }
  if (t === 'subscription_due') {
    return '订阅提醒'
  }
  if (t === 'pressure_alert') {
    return '压力预警'
  }
  if (t === 'ai_insight') {
    return 'AI 洞察'
  }
  if (t === 'monthly_review') {
    return '月度回顾'
  }
  if (t === 'data_stale') {
    return '数据同步'
  }
  if (t === 'milestone') {
    return '里程碑'
  }
  if (t === 'update') {
    return '应用更新'
  }
  return '通知'
}

export function notificationTypeRole(t: string): string {
  if (t === 'pressure_alert') {
    return 'danger'
  }
  if (t === 'payment_due' || t === 'subscription_due') {
    return 'warn'
  }
  if (t === 'milestone') {
    return 'ok'
  }
  return 'off'
}

export function notificationNavTarget(n: Notification): NotificationNavTarget {
  const t = new NotificationNavTarget()
  if (n.debt_id.length > 0) {
    t.route = RouteNames.DEBT_FORM
    t.storageKey = AppStorageKeys.SELECTED_DEBT_ID
    t.storageValue = n.debt_id
    return t
  }
  if (n.subscription_id.length > 0) {
    t.route = RouteNames.SUBSCRIPTION_FORM
    t.storageKey = AppStorageKeys.SELECTED_SUBSCRIPTION_ID
    t.storageValue = n.subscription_id
  }
  return t
}

export function isNotificationActionable(n: Notification): boolean {
  return notificationNavTarget(n).route.length > 0
}

export function notificationDayGroup(sentAt: string, nowMs: number): string {
  if (sentAt.length < 10) {
    return 'earlier'
  }
  const d = new Date(sentAt)
  const t = d.getTime()
  if (isNaN(t)) {
    return 'earlier'
  }
  const now = new Date(nowMs)
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()
  const yesterdayStart = todayStart - 86400000
  if (t >= todayStart) {
    return 'today'
  }
  if (t >= yesterdayStart) {
    return 'yesterday'
  }
  return 'earlier'
}

export function notificationDayLabel(key: string): string {
  if (key === 'today') {
    return '今天'
  }
  if (key === 'yesterday') {
    return '昨天'
  }
  return '更早'
}

export function buildNotificationGroups(list: Notification[], nowMs: number): NotificationGroup[] {
  const today: Notification[] = []
  const yesterday: Notification[] = []
  const earlier: Notification[] = []
  for (let i = 0; i < list.length; i++) {
    const key = notificationDayGroup(list[i].sent_at, nowMs)
    if (key === 'today') {
      today.push(list[i])
    } else if (key === 'yesterday') {
      yesterday.push(list[i])
    } else {
      earlier.push(list[i])
    }
  }
  const groups: NotificationGroup[] = []
  if (today.length > 0) {
    const g = new NotificationGroup()
    g.key = 'today'
    g.label = notificationDayLabel('today')
    g.items = today
    groups.push(g)
  }
  if (yesterday.length > 0) {
    const g = new NotificationGroup()
    g.key = 'yesterday'
    g.label = notificationDayLabel('yesterday')
    g.items = yesterday
    groups.push(g)
  }
  if (earlier.length > 0) {
    const g = new NotificationGroup()
    g.key = 'earlier'
    g.label = notificationDayLabel('earlier')
    g.items = earlier
    groups.push(g)
  }
  return groups
}

export function notificationInboxSubtitle(unreadCount: number, total: number): string {
  if (total <= 0) {
    return '账单日与还款日的提醒会在这里汇总'
  }
  if (unreadCount <= 0) {
    return '全部已读'
  }
  return unreadCount + ' 条未读'
}

export function unreadBadgeLabel(count: number): string {
  if (count <= 0) {
    return ''
  }
  if (count > 99) {
    return '99+'
  }
  return '' + count
}

/**
 * 通知收件箱：首页半模态抽屉与二级页共用。
 * - 全宽铺开（禁止贴铃铛右对齐）
 * - 点条目展开/收起详情与操作；「查看」才跳转
 * - 未读数回写 AppStorageKeys.NOTIFICATION_UNREAD_COUNT
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct NotificationsInbox {
  @Prop theme: ThemeColors = ThemeManager.DARK
  /** true：抽屉/半模态（SheetHeader + 关闭）；false：二级页（外层 HdsNavigation 提供标题） */
  @Prop showSheetChrome: boolean = false
  /** true：自顶向下抽屉，底边圆角、底内边距不加安全区 */
  @Prop dockTop: boolean = false
  @Prop emptyIcon: Resource = $r('app.media.ic_add')
  onClose: () => void = () => {
  }
  /** 跳转前调用，供宿主收起抽屉 */
  onNavigate: () => void = () => {
  }

  @State private notifications: Notification[] = []
  @State private rows: InboxRow[] = []
  @State private unreadCount: number = 0
  @State private loading: boolean = true
  @State private expandedId: string = ''
  @State private swipeDeletePressedId: string = ''
  @State private revealT: number = 0
  private pageScroller: Scroller = new Scroller()
  private revealTimer: number = -1

  aboutToAppear() {
    this.revealT = 0
    this.loadAll()
    this.revealTimer = setTimeout(() => {
      this.getUIContext().animateTo({
        duration: MotionTokens.drawerEnterDuration,
        curve: Curve.EaseOut
      }, () => {
        this.revealT = 1
      })
    }, MotionHelper.LIST_REVEAL_FRAME_MS)
  }

  aboutToDisappear() {
    if (this.revealTimer !== -1) {
      clearTimeout(this.revealTimer)
      this.revealTimer = -1
    }
  }

  private contentPad(): number {
    return this.showSheetChrome ? 24 : this.theme.pageHorizontalPadding
  }

  private rebuildGroups(): void {
    this.rows = flattenNotificationGroups(buildNotificationGroups(this.notifications, Date.now()))
  }

  private refreshUnreadToStorage(): void {
    AppStorage.setOrCreate(AppStorageKeys.NOTIFICATION_UNREAD_COUNT, this.unreadCount)
  }

  private async loadAll(): Promise<void> {
    try {
      const result = await Promise.all([
        NotificationService.getNotifications(),
        NotificationService.getUnreadCount()
      ])
      this.notifications = result[0] as Notification[]
      const cnt: number = result[1] as number
      this.unreadCount = cnt
      this.rebuildGroups()
      this.refreshUnreadToStorage()
    } catch (_e) {
    } finally {
      this.loading = false
    }
  }

  private markReadLocal(n: Notification): void {
    if (n.is_read) {
      return
    }
    n.is_read = true
    this.unreadCount = Math.max(0, this.unreadCount - 1)
    this.refreshUnreadToStorage()
    this.notifications = [...this.notifications]
    this.rebuildGroups()
    NotificationService.markRead(n.id).catch(() => {
    })
  }

  private hasItem(id: string): boolean {
    for (let i = 0; i < this.notifications.length; i++) {
      if (this.notifications[i].id === id) {
        return true
      }
    }
    return false
  }

  private onItemTap(n: Notification): void {
    if (!this.hasItem(n.id)) {
      return
    }
    this.markReadLocal(n)
    if (this.expandedId === n.id) {
      this.expandedId = ''
    } else {
      this.expandedId = n.id
    }
  }

  private onOpenTarget(n: Notification): void {
    this.markReadLocal(n)
    const target = notificationNavTarget(n)
    if (target.route.length === 0) {
      return
    }
    this.onNavigate()
    AppStorage.setOrCreate(target.storageKey, target.storageValue)
    AppRouter.push(target.route)
  }

  private markAllRead(): void {
    if (this.unreadCount === 0) {
      return
    }
    this.notifications.forEach((item: Notification) => {
      item.is_read = true
    })
    this.notifications = [...this.notifications]
    this.unreadCount = 0
    this.rebuildGroups()
    this.refreshUnreadToStorage()
    NotificationService.markAllRead().catch(() => {
    })
    AppToast.show('已全部标为已读', 1200)
  }

  private deleteItem(n: Notification): void {
    if (this.expandedId === n.id) {
      this.expandedId = ''
    }
    this.notifications = this.notifications.filter((item: Notification) => item.id !== n.id)
    if (!n.is_read) {
      this.unreadCount = Math.max(0, this.unreadCount - 1)
      this.refreshUnreadToStorage()
    }
    this.rebuildGroups()
    NotificationService.deleteNotification(n.id).catch(() => {
    })
    AppToast.show('已删除', 1200)
  }

  private confirmClear(): void {
    promptAction.showDialog({
      title: '全部清除',
      message: '将删除全部通知记录，且不可恢复。',
      buttons: [
        { text: '取消', color: '#9A9A9A' },
        { text: '清除', color: '#CF2D56' }
      ]
    }).then((d: promptAction.ShowDialogSuccessResponse) => {
      if (d.index === 1) {
        this.doClearAll()
      }
    }).catch(() => {
    })
  }

  private doClearAll(): void {
    this.notifications = []
    this.rows = []
    this.unreadCount = 0
    this.expandedId = ''
    this.refreshUnreadToStorage()
    NotificationService.deleteAll().catch(() => {
    })
    AppToast.show('已清除全部通知', 1200)
  }

  @Builder
  deleteAction(n: Notification) {
    Column({ space: 4 }) {
      Image($r('app.media.ic_delete'))
        .width(18)
        .height(18)
        .fillColor(this.theme.dangerForeground())
        .objectFit(ImageFit.Contain)
        .flexShrink(0)
      Text('删除')
        .fontSize(TypeScale.captionSm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.dangerForeground())
        .flexShrink(0)
    }
    .width(72)
    .height(MotionTokens.listRowHeight)
    .constraintSize({
      minWidth: 72,
      maxWidth: 72,
      minHeight: MotionTokens.listRowHeight,
      maxHeight: MotionTokens.listRowHeight
    })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme.dangerBackground())
    .borderRadius({
      topLeft: 0,
      topRight: this.theme.radiusLg,
      bottomLeft: 0,
      bottomRight: this.theme.radiusLg
    })
    .clip(true)
    .scale({
      x: this.swipeDeletePressedId === n.id ? MotionTokens.pressScaleLight : 1,
      y: this.swipeDeletePressedId === n.id ? MotionTokens.pressScaleLight : 1
    })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.swipeDeletePressedId = n.id
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.swipeDeletePressedId = ''
      }
    })
    .onClick(() => this.deleteItem(n))
  }

  @Builder
  toolbarBuilder() {
    Row() {
      Text('全部已读')
        .fontSize(TypeScale.bodySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.unreadCount > 0 ? this.theme.text : this.theme.text3)
        .onClick(() => this.markAllRead())
      Blank()
      Text('全部清除')
        .fontSize(TypeScale.bodySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.statusDanger())
        .onClick(() => this.confirmClear())
    }
    .width('100%')
    .padding({
      left: this.contentPad(),
      right: this.contentPad(),
      top: this.showSheetChrome ? 0 : 8,
      bottom: 4
    })
  }

  @Builder
  notificationItem(n: Notification, lastInGroup: boolean) {
    ListItem() {
      Row({ space: 10 }) {
        Column() {
          Circle({ width: 8, height: 8 })
            .fill(n.is_read ? '#00000000' : this.theme.red)
        }
        .width(8)
        .padding({ top: 5 })
        .alignItems(HorizontalAlign.Center)

        Column({ space: 4 }) {
          Row({ space: 8 }) {
            Text(n.title)
              .fontSize(TypeScale.listPrimary)
              .fontWeight(n.is_read ? FontWeight.Regular : FontWeight.Medium)
              .fontColor(this.theme.text)
              .maxLines(this.expandedId === n.id ? 3 : 1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(Utils.formatNotificationTime(n.sent_at))
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
              .maxLines(1)
              .flexShrink(0)
          }
          .width('100%')
          .alignItems(VerticalAlign.Top)

          if (n.body.length > 0) {
            Text(n.body)
              .fontSize(TypeScale.body)
              .fontColor(this.theme.text2)
              .maxLines(this.expandedId === n.id ? 6 : 1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }

          Row({ space: 8 }) {
            StatusTag({
              theme: this.theme,
              text: notificationTypeLabel(n.reminder_type),
              role: notificationTypeRole(n.reminder_type)
            })
            Blank()
            if (this.expandedId === n.id) {
              if (isNotificationActionable(n)) {
                Text('查看')
                  .fontSize(TypeScale.bodySm)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.text)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .hitTestBehavior(HitTestMode.Default)
                  .onClick(() => this.onOpenTarget(n))
              }
              Text('删除')
                .fontSize(TypeScale.bodySm)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.statusDanger())
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .hitTestBehavior(HitTestMode.Default)
                .onClick(() => this.deleteItem(n))
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
          .margin({ top: 2 })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .padding({
        left: this.contentPad(),
        right: this.contentPad(),
        top: 12,
        bottom: 12
      })
      .alignItems(VerticalAlign.Top)
      .border({
        width: { bottom: lastInGroup ? 0 : 0.5 },
        color: this.theme.border
      })
    }
    .swipeAction({
      end: {
        builder: () => {
          this.deleteAction(n)
        },
        actionAreaDistance: 72
      }
    })
    .onClick(() => this.onItemTap(n))
  }

  @Builder
  inboxRowBuilder(row: InboxRow) {
    if (row.kind === 'header') {
      ListItem() {
        Text(row.label)
          .fontSize(TypeScale.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text3)
          .width('100%')
          .padding({
            left: this.contentPad(),
            right: this.contentPad(),
            top: 12,
            bottom: 4
          })
      }
    } else {
      this.notificationItem(row.notification, row.lastInGroup)
    }
  }

  @Builder
  listBuilder() {
    List({ space: 0, scroller: this.pageScroller }) {
      ForEach(this.rows, (row: InboxRow) => {
        this.inboxRowBuilder(row)
      }, (row: InboxRow) => row.id)
    }
    .width('100%')
    .layoutWeight(1)
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .padding({
      bottom: this.dockTop ? this.theme.spaceXs : (this.showSheetChrome ? sheetBottomInset(12) : 20)
    })
    .opacity(this.revealT)
    .translate({
      y: (1 - this.revealT) * MotionTokens.drawerEnterOffsetY * (this.dockTop ? -1 : 1)
    })
  }

  build() {
    Column() {
      if (this.showSheetChrome) {
        SheetHeader({
          theme: this.theme,
          title: '通知',
          subtitle: notificationInboxSubtitle(this.unreadCount, this.notifications.length),
          onClose: () => {
            this.onClose()
          }
        })
      }

      if (this.notifications.length > 0) {
        this.toolbarBuilder()
      }

      if (this.loading) {
        Column()
          .width('100%')
          .layoutWeight(1)
      } else if (this.notifications.length === 0) {
        EmptyState({
          theme: this.theme,
          icon: this.emptyIcon,
          iconColor: this.theme.text3,
          title: '暂无通知',
          subtitle: '账单日与还款日的提醒会在这里汇总',
          bottomExtra: this.showSheetChrome ? 0 : 24
        })
          .width('100%')
          .layoutWeight(1)
      } else {
        this.listBuilder()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.showSheetChrome ? this.theme.sheetBackground() : this.theme.background)
    .border({
      width: { top: this.showSheetChrome && !this.dockTop ? 0.5 : 0, left: 0, right: 0, bottom: 0 },
      color: this.theme.sheetEdgeColor()
    })
  }
}
