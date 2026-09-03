import { AppStorageKeys, ThemeColors, TypeScale, MotionTokens, Utils } from 'common'
import { HandednessService } from 'service'
import { common } from '@kit.AbilityKit'

/**
 * 统一底部弹窗底边避让：安全区（home 指示条）+ 视觉间距
 * - 所有 bindSheet 内容统一调用，保证同屏不同弹窗底边对齐
 * - bottomSafe 由 AppStorage 统一管理（窗口避让区），sheet 打开时 builder 重跑取最新值
 */
export function sheetBottomInset(gap: number = 20): number {
  const safe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 0
  return safe + gap
}

/**
 * 统一底部半模态弹窗组件
 * - 样式对齐 SettingsTab 既有的 bindSheet（圆角/拖拽条/mask/主题色）
 * - 所有交互弹窗（确认/删除/选择/提示）统一从底部弹出
 */

/** 底部弹窗按钮 */
export class SheetDialogButton {
  text: string = ''
  /** 兼容旧调用；实际渲染优先按 role 取主题语义色 */
  /** 兼容旧调用；渲染优先 theme.actionLabelColor(role) */
  color: ResourceColor = '#FAFAFA'
  /**
   * 操作语义（X 产品风，全应用统一）：
   * - default：主操作文案（高对比 text）
   * - cancel：取消（text2）
   * - destructive：危险（red）
   */
  role: string = 'default'
  /** 当前已选中：渲染加粗 + 勾标记，用于服务商/选项回显 */
  selected: boolean = false

  constructor(text: string, color: ResourceColor, role: string = 'default', selected: boolean = false) {
    this.text = text
    this.color = color
    this.role = role
    this.selected = selected
  }
}

/** 底部弹窗配置 */
export class SheetDialogConfig {
  title: string = ''
  message: string = ''
  buttons: SheetDialogButton[] = []

  constructor(title: string = '', message: string = '', buttons: SheetDialogButton[] = []) {
    this.title = title
    this.message = message
    this.buttons = buttons
  }
}

/** 底部日期选择配置 */
export class SheetDatePickerConfig {
  title: string = ''
  start: Date = new Date('2020-01-01')
  end: Date = new Date('2050-12-31')
  selected: Date = new Date()

  constructor(title: string = '', selected: Date = new Date()) {
    this.title = title
    this.selected = selected
  }
}

interface ButtonWithIndex {
  btn: SheetDialogButton
  index: number
}

/** 纯函数：cancel 排底排序 */
export function getOrderedButtons(buttons: SheetDialogButton[]): ButtonWithIndex[] {
  const list: ButtonWithIndex[] = []
  for (let i = 0; i < buttons.length; i++) {
    list.push({ btn: buttons[i], index: i })
  }
  const nonCancel = list.filter(item => item.btn.role !== 'cancel')
  const cancel = list.filter(item => item.btn.role === 'cancel')
  return nonCancel.concat(cancel)
}

/** 双按钮且恰好一个取消：用横排「取消 | 主操作」，不用纵向菜单 */
export function isConfirmButtonPair(buttons: SheetDialogButton[]): boolean {
  if (buttons.length !== 2) {
    return false
  }
  let cancelN = 0
  for (let i = 0; i < buttons.length; i++) {
    if (buttons[i].role === 'cancel') {
      cancelN++
    }
  }
  return cancelN === 1
}

/** 半模态操作行：touch-down 即时 scale */
@Component
struct SheetDialogActionRow {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop label: string = ''
  @Prop role: string = 'default'
  @Prop selected: boolean = false
  onTap: () => void = () => {}
  @State private pressed: boolean = false

  build() {
    Stack() {
      Row() {
        Text(this.label)
          .fontSize(TypeScale.listPrimary)
          .fontWeight(this.selected ? FontWeight.Bold :
            (this.role === 'cancel' ? FontWeight.Regular : FontWeight.Medium))
          .fontColor(this.theme.actionLabelColor(this.role))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)

      if (this.selected) {
        Row() {
          Image($r('app.media.ic_check'))
            .width(18)
            .height(18)
            .fillColor(this.theme.accent)
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      }
    }
    .width('100%')
    .padding({ top: 16, bottom: 16, left: 16, right: 16 })
    .backgroundColor(this.pressed
      ? this.theme.chip
      : (this.selected ? Utils.hexToRgba(this.theme.primary, 0.12) : Color.Transparent))
    .scale({
      x: this.pressed ? MotionTokens.pressScaleLight : 1,
      y: this.pressed ? MotionTokens.pressScaleLight : 1
    })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (e.type === TouchType.Down) {
        this.pressed = true
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.pressed = false
      }
    })
    .onClick(() => {
      this.onTap()
    })
  }
}

/**
 * 双按钮底栏：主操作贴智感握姿主手一侧，取消在对侧
 * （右手：取消 | 主操作；左手：主操作 | 取消）
 */
@Component
export struct SheetDialogFooter {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop cancelLabel: string = '取消'
  @Prop actionLabel: string = ''
  @Prop actionRole: string = 'default'
  @Prop actionEnabled: boolean = true
  @Prop cancelEnabled: boolean = true
  onCancel: () => void = () => {}
  onAction: () => void = () => {}
  @State private cancelPressed: boolean = false
  @State private actionPressed: boolean = false
  @State private leftPrimary: boolean = false
  private readonly onHandednessChange = (leftPrimary: boolean): void => {
    const apply = (): void => {
      this.leftPrimary = leftPrimary
    }
    try {
      this.getUIContext().runScopedTask(apply)
    } catch (_e) {
      apply()
    }
  }

  aboutToAppear() {
    this.leftPrimary = HandednessService.isLeftPrimary()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    HandednessService.start(this.onHandednessChange, context)
  }

  aboutToDisappear() {
    HandednessService.stop(this.onHandednessChange)
  }

  private actionIsDestructive(): boolean {
    return this.actionRole === 'destructive'
  }

  @Builder
  cancelBtn() {
    Row() {
      Text(this.cancelLabel)
        .fontSize(TypeScale.listPrimarySm)
        .fontWeight(FontWeight.Regular)
        .fontColor(this.theme.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme.sheetItemBackground())
    .borderRadius(this.theme.sheetCardRadius)
    .border({ width: 1, color: this.theme.borderSoft })
    .opacity(this.cancelEnabled ? 1 : 0.4)
    .scale({
      x: this.cancelPressed ? MotionTokens.pressScaleLight : 1,
      y: this.cancelPressed ? MotionTokens.pressScaleLight : 1
    })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (!this.cancelEnabled) {
        return
      }
      if (e.type === TouchType.Down) {
        this.cancelPressed = true
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.cancelPressed = false
      }
    })
    .onClick(() => {
      if (this.cancelEnabled) {
        this.onCancel()
      }
    })
  }

  @Builder
  actionBtn() {
    Row() {
      Text(this.actionLabel)
        .fontSize(TypeScale.listPrimarySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.actionIsDestructive() ? this.theme.red : this.theme.ctaForeground())
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .layoutWeight(1)
    .height(48)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.actionIsDestructive() ? this.theme.sheetItemBackground() : this.theme.ctaBackground())
    .borderRadius(this.theme.sheetCardRadius)
    .border({
      width: 1,
      color: this.actionIsDestructive() ? this.theme.borderSoft : Color.Transparent
    })
    .opacity(this.actionEnabled ? 1 : 0.4)
    .scale({
      x: this.actionPressed ? MotionTokens.pressScaleLight : 1,
      y: this.actionPressed ? MotionTokens.pressScaleLight : 1
    })
    .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
    .onTouch((e: TouchEvent) => {
      if (!this.actionEnabled) {
        return
      }
      if (e.type === TouchType.Down) {
        this.actionPressed = true
      } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
        this.actionPressed = false
      }
    })
    .onClick(() => {
      if (this.actionEnabled) {
        this.onAction()
      }
    })
  }

  build() {
    Row({ space: 12 }) {
      if (this.leftPrimary) {
        this.actionBtn()
        this.cancelBtn()
      } else {
        this.cancelBtn()
        this.actionBtn()
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}

/**
 * 统一底部半模态弹窗标题栏
 * - 第一行：标题 + 关闭（关闭不挤占介绍宽度）
 * - 第二行：介绍全宽排版，先占满再换行
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct SheetHeader {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop title: string = ''
  @Prop subtitle: string = ''
  onClose: () => void = () => {}

  build() {
    Column({ space: 6 }) {
      // 标题行：左标题、右关闭
      Row() {
        if (this.title.length > 0) {
          Text(this.title)
            .fontSize(TypeScale.metric)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
            .letterSpacing(TypeScale.metricSpacing)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ right: 8 })
        } else {
          Blank().layoutWeight(1)
        }

        Row() {
          Image($r('app.media.ic_close_circle'))
            .width(28)
            .height(28)
            .fillColor(this.theme.text2)
        }
        .width(44)
        .height(44)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .flexShrink(0)
        .onClick(() => {
          this.onClose()
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 介绍独立全宽：不被关闭钮挤占
      if (this.subtitle.length > 0) {
        Text(this.subtitle)
          .fontSize(TypeScale.body)
          .fontColor(this.theme.text2)
          .lineHeight(20)
          .maxLines(4)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 24, right: 16, top: 14, bottom: 16 })
  }
}

/**
 * 通用底部弹窗视图：标题 + 正文 + 按钮列表
 * 由各页面通过 bindSheet 挂载，配合 @State showSheet + @State config 驱动
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct SheetDialogView {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop config: SheetDialogConfig = new SheetDialogConfig()
  onTap: (index: number) => void = () => {}
  onClose: () => void = () => {}

  getOrderedButtons(): ButtonWithIndex[] {
    return getOrderedButtons(this.config.buttons)
  }

  private pairCancelIndex(): number {
    for (let i = 0; i < this.config.buttons.length; i++) {
      if (this.config.buttons[i].role === 'cancel') {
        return i
      }
    }
    return 0
  }

  private pairActionIndex(): number {
    for (let i = 0; i < this.config.buttons.length; i++) {
      if (this.config.buttons[i].role !== 'cancel') {
        return i
      }
    }
    return 0
  }

  private pairCancelLabel(): string {
    return this.config.buttons[this.pairCancelIndex()].text
  }

  private pairActionLabel(): string {
    return this.config.buttons[this.pairActionIndex()].text
  }

  private pairActionRole(): string {
    return this.config.buttons[this.pairActionIndex()].role
  }

  private firePair(isCancel: boolean): void {
    const index = isCancel ? this.pairCancelIndex() : this.pairActionIndex()
    this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
      this.onTap(index)
    })
  }

  build() {
    Column({ space: 0 }) {
      // 标题区：左侧标题+介绍，右侧关闭按钮（1fr:auto）
      if (this.config.title.length > 0 || this.config.message.length > 0) {
        SheetHeader({
          theme: this.theme,
          title: this.config.title,
          subtitle: this.config.message,
          onClose: () => {
            this.onClose()
          }
        })
      }

      if (isConfirmButtonPair(this.config.buttons)) {
        SheetDialogFooter({
          theme: this.theme,
          cancelLabel: this.pairCancelLabel(),
          actionLabel: this.pairActionLabel(),
          actionRole: this.pairActionRole(),
          onCancel: () => {
            this.firePair(true)
          },
          onAction: () => {
            this.firePair(false)
          }
        })
          .padding({ left: 24, right: 24 })
          .margin({ bottom: 8 })
      } else {
        Row() {
          Column() {
            ForEach(this.getOrderedButtons(), (item: ButtonWithIndex, index: number) => {
              if (index > 0) {
                Divider().color(this.theme.borderSoft).strokeWidth(0.5).margin({ left: 16, right: 16 })
              }
              SheetDialogActionRow({
                theme: this.theme,
                label: item.btn.text,
                role: item.btn.role,
                selected: item.btn.selected,
                onTap: () => {
                  this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
                    this.onTap(item.index)
                  })
                }
              })
            }, (item: ButtonWithIndex, index: number) => item.index.toString())
          }
          .layoutWeight(1)
          .backgroundColor(this.theme.sheetItemBackground())
          .borderRadius(this.theme.sheetCardRadius)
          .border({ width: 1, color: this.theme.borderStrong })
          .clip(true)
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .margin({ bottom: 8 })
      }
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ top: 0, bottom: sheetBottomInset() })
  }
}

/** 日历单元格数据（date 按需由 year/month/day 构造，避免网格生成时批量 new Date） */
export class CalendarDayCell {
  year: number = 2026
  month: number = 0
  day: number = 1
  isCurrentMonth: boolean = true
  isToday: boolean = false
  isSelected: boolean = false

  constructor(year: number, month: number, day: number, isCurrentMonth: boolean, isToday: boolean, isSelected: boolean) {
    this.year = year
    this.month = month
    this.day = day
    this.isCurrentMonth = isCurrentMonth
    this.isToday = isToday
    this.isSelected = isSelected
  }

  /** 点击选中时再创建 Date，避免 getCalendarDays 循环内 42 次 new Date */
  toDate(): Date {
    return new Date(this.year, this.month, this.day)
  }
}

/**
 * 底部日期选择视图：标题栏(取消/确定) + 日历网格面板 (无滚轮)
 * 替代系统 DatePickerDialog 滚轮，提供直观的日历选日体验
 */
@Component
export struct SheetDatePickerView {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop config: SheetDatePickerConfig = new SheetDatePickerConfig()
  @State selected: Date = new Date()
  @State viewYear: number = new Date().getFullYear()
  @State viewMonth: number = new Date().getMonth()
  onConfirm: (date: Date) => void = () => {}
  onCancel: () => void = () => {}

  private weekHeaderLabels: string[] = ['日', '一', '二', '三', '四', '五', '六']

  aboutToAppear(): void {
    this.selected = this.config.selected
    this.viewYear = this.selected.getFullYear()
    this.viewMonth = this.selected.getMonth()
  }

  private getCalendarDays(): CalendarDayCell[] {
    const days: CalendarDayCell[] = []
    const today = new Date()
    const todayY = today.getFullYear()
    const todayM = today.getMonth()
    const todayD = today.getDate()

    // 循环前缓存状态，避免循环内反复读 @State
    const selected = this.selected
    const viewYear = this.viewYear
    const viewMonth = this.viewMonth
    const selY = selected.getFullYear()
    const selM = selected.getMonth()
    const selD = selected.getDate()

    // 月份边界 Date 只建 3 次（非循环）；格内不再 new Date
    const firstDayOfWeek = new Date(viewYear, viewMonth, 1).getDay()
    const daysInCurrentMonth = new Date(viewYear, viewMonth + 1, 0).getDate()
    const daysInPrevMonth = new Date(viewYear, viewMonth, 0).getDate()

    // 1. 上月补位
    const prevM = viewMonth === 0 ? 11 : viewMonth - 1
    const prevY = viewMonth === 0 ? viewYear - 1 : viewYear
    for (let i = firstDayOfWeek - 1; i >= 0; i--) {
      const d = daysInPrevMonth - i
      const isToday = prevY === todayY && prevM === todayM && d === todayD
      const isSel = prevY === selY && prevM === selM && d === selD
      days.push(new CalendarDayCell(prevY, prevM, d, false, isToday, isSel))
    }

    // 2. 当月日期
    for (let d = 1; d <= daysInCurrentMonth; d++) {
      const isToday = viewYear === todayY && viewMonth === todayM && d === todayD
      const isSel = viewYear === selY && viewMonth === selM && d === selD
      days.push(new CalendarDayCell(viewYear, viewMonth, d, true, isToday, isSel))
    }

    // 3. 下月补位 (凑满42格: 6周x7天)
    const remaining = 42 - days.length
    const nextM = viewMonth === 11 ? 0 : viewMonth + 1
    const nextY = viewMonth === 11 ? viewYear + 1 : viewYear
    for (let d = 1; d <= remaining; d++) {
      const isToday = nextY === todayY && nextM === todayM && d === todayD
      const isSel = nextY === selY && nextM === selM && d === selD
      days.push(new CalendarDayCell(nextY, nextM, d, false, isToday, isSel))
    }

    return days
  }

  private prevMonth(): void {
    if (this.viewMonth === 0) {
      this.viewYear -= 1
      this.viewMonth = 11
    } else {
      this.viewMonth -= 1
    }
  }

  private nextMonth(): void {
    if (this.viewMonth === 11) {
      this.viewYear += 1
      this.viewMonth = 0
    } else {
      this.viewMonth += 1
    }
  }

  build() {
    Column({ space: 0 }) {
      // 1. 顶部操作栏
      Row() {
        Text('取消')
          .fontSize(TypeScale.listPrimary)
          .fontColor(this.theme.text2)
          .onClick(() => {
            this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
              this.onCancel()
            })
          })

        Text(this.config.title.length > 0 ? this.config.title : '选择日期')
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Text('确定')
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.accent)
          .onClick(() => {
            this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
              this.onConfirm(this.selected)
            })
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 14, bottom: 12 })

      // 2. 年月切换导航栏
      Row() {
        Row() {
          Text('‹')
            .fontSize(TypeScale.metric)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
            this.prevMonth()
          })
        })

        Text(`${this.viewYear}年 ${this.viewMonth + 1}月`)
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .margin({ left: 12, right: 12 })

        Row() {
          Text('›')
            .fontSize(TypeScale.metric)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
        }
        .width(36)
        .height(36)
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => {
          this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
            this.nextMonth()
          })
        })
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
      .padding({ top: 4, bottom: 8 })

      // 3. 星期表头栏
      Row() {
        ForEach(this.weekHeaderLabels, (label: string) => {
          Text(label)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text3)
        }, (label: string) => label)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 8 })

      // 4. 日历网格
      Grid() {
        ForEach(this.getCalendarDays(), (cell: CalendarDayCell) => {
          GridItem() {
            Column() {
              Stack({ alignContent: Alignment.Center }) {
                if (cell.isSelected) {
                  Row()
                    .width(32)
                    .height(32)
                    .borderRadius(this.theme.radiusPill)
                    .backgroundColor(this.theme.accent)
                } else if (cell.isToday) {
                  Row()
                    .width(32)
                    .height(32)
                    .borderRadius(this.theme.radiusPill)
                    .border({ width: 1, color: this.theme.accent })
                }

                Text(`${cell.day}`)
                  .fontSize(TypeScale.listPrimary)
                  .fontWeight(cell.isSelected ? FontWeight.Bold : FontWeight.Regular)
                  .fontColor(cell.isSelected ? this.theme.onPrimary : (cell.isCurrentMonth ? this.theme.text : this.theme.text3))
              }
              .width(36)
              .height(36)
            }
            .width('100%')
            .height(40)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .onClick(() => {
              this.getUIContext().animateTo({ duration: MotionTokens.sheetQuickDuration, curve: Curve.FastOutSlowIn }, () => {
                this.selected = cell.toDate()
                if (!cell.isCurrentMonth) {
                  this.viewYear = cell.year
                  this.viewMonth = cell.month
                }
              })
            })
          }
        }, (cell: CalendarDayCell) => `${cell.year}-${cell.month}-${cell.day}-${cell.isCurrentMonth}-${cell.isSelected}-${cell.isToday}`)
      }
      .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr')
      .rowsGap(2)
      .columnsGap(2)
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ bottom: sheetBottomInset() })
  }
}
