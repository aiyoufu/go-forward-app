import { Debt } from 'common'
import { ThemeColors, TypeScale, MotionTokens } from 'common'
import { Utils } from 'common'
import { Constants, AppStorageKeys } from 'common'
import { PlatformService, CreditAccountService, LocalDataStore, IconPickerService } from 'service'
import { CreditAccount } from 'common'
import { LogoImage } from './LogoImage'
import { StatusTag } from './StatusTag'

/** 纯函数：是否逾期 */
export function isOverdue(status: string, nextPaymentDate: string, todayStr: string): boolean {
  if (status !== 'active') {
    return false
  }
  if (!nextPaymentDate || nextPaymentDate.length === 0) {
    return false
  }
  return nextPaymentDate < todayStr
}

/** 纯函数：是否「高利率」（年利率≥阈值） */
export function isHighRate(annualRateBp: number): boolean {
  return annualRateBp >= Constants.HIGH_RATE_BP_THRESHOLD
}

/** 纯函数：期数进度标签（分期：第X/Y期 或 共Y期；一次性：空） */
export function progressLabel(debtType: string, totalPeriods: number, remainingPeriods: number, status: string = ''): string {
  if (debtType === 'installment' && totalPeriods > 0) {
    const paid = totalPeriods - remainingPeriods
    if (status === 'completed') {
      return '共' + totalPeriods + '期'
    }
    return '第' + paid + '/' + totalPeriods + '期'
  }
  return ''
}

/** 纯函数：余额/进度行（中间不显示剩余待还，分期展示期数进度，一次性为空） */
export function balanceLine(currentBalance: number, status: string, progressLabelResult: string, debtType: string = 'installment'): string {
  return progressLabelResult
}

/** 纯函数：主金额文本 */
export function primaryAmountText(status: string, monthlyPayment: number): string {
  if (status === 'completed') {
    return '已结清'
  }
  if (status === 'paused') {
    return '已暂停'
  }
  return Utils.formatMoney(monthlyPayment)
}

/** 纯函数：格式化下次日期 */
export function formatNextDate(nextPaymentDate: string): string {
  if (!nextPaymentDate || nextPaymentDate.length === 0) {
    return ''
  }
  try {
    const d = new Date(nextPaymentDate)
    if (isNaN(d.getTime())) {
      return nextPaymentDate
    }
    return (d.getMonth() + 1) + '月' + d.getDate() + '日'
  } catch (_e) {
    return nextPaymentDate
  }
}

/** 纯函数：还款日 YYYY-MM-DD（补零） */
export function formatDueYmd(nextPaymentDate: string): string {
  if (!nextPaymentDate || nextPaymentDate.length === 0) {
    return ''
  }
  const pad = (n: number): string => (n < 10 ? '0' + n : '' + n)
  if (nextPaymentDate.length >= 10 && nextPaymentDate.charAt(4) === '-') {
    const parts = nextPaymentDate.substring(0, 10).split('-')
    if (parts.length === 3 && parts[0].length === 4) {
      return parts[0] + '-' + pad(Number(parts[1])) + '-' + pad(Number(parts[2]))
    }
  }
  try {
    const d = new Date(nextPaymentDate)
    if (isNaN(d.getTime())) {
      return nextPaymentDate
    }
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate())
  } catch (_e) {
    return nextPaymentDate
  }
}

/** 纯函数：到期行（日期 + 提示词） */
export function dueLine(status: string, nextPaymentDate: string, isOverdueResult: boolean, daysFromNowResult: number, paymentDay: number): string {
  if (status === 'completed') {
    return ''
  }
  if (status === 'paused') {
    return '还款已暂停'
  }
  const dateStr = formatDueYmd(nextPaymentDate)
  if (dateStr.length === 0) {
    if (paymentDay > 0) {
      return '每月' + paymentDay + '日'
    }
    return ''
  }
  if (isOverdueResult) {
    return dateStr + ' 已逾期'
  }
  return dateStr + ' 还款'
}

/** 纯函数：品牌色 */
export function brandColor(platformColor: string, platform: string): string {
  if (platformColor && platformColor.length > 0) {
    return platformColor
  }
  const visual = PlatformService.getBrandVisual(platform)
  if (visual.color && visual.color.length > 0) {
    return visual.color
  }
  return '#2E2E2E'
}

/** 纯函数：状态 tag 文案（进行中 / 已逾期 / 已暂停 / 已结清） */
export function statusTagText(status: string, nextPaymentDate: string, todayStr: string): string {
  if (status === 'completed') {
    return '已结清'
  }
  if (status === 'paused') {
    return '已暂停'
  }
  if (isOverdue(status, nextPaymentDate, todayStr)) {
    return '已逾期'
  }
  return '进行中'
}

/** 纯函数：状态 tag 语义角色（ok 绿 / warn 琥珀 / danger 红 / off 灰） */
export function statusTagRole(status: string, nextPaymentDate: string, todayStr: string): string {
  if (status === 'completed') {
    return 'off'
  }
  if (status === 'paused') {
    return 'warn'
  }
  if (isOverdue(status, nextPaymentDate, todayStr)) {
    return 'danger'
  }
  return 'ok'
}

/**
 * 负债列表卡 · 两行统一范式（与 SubscriptionCard / CreditAccountCard 对齐，固定 listRowHeight）
 *
 *   Logo | 名称 ……………………………… ¥本期应还
 *        | 进行中  [第x/y期] …………………… YYYY-MM-DD 还款
 */
@Reusable
@Component
export struct DebtCard {
  @Prop @Watch('onDebtChange') debt: Debt = new Debt()
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop isSwiped: boolean = false
  /** 组内首尾行：外露角 radiusXl，中间行直角 */
  @Prop isFirstInGroup: boolean = false
  @Prop isLastInGroup: boolean = false
  /** 批量选择模式：true 时左上标记位渲染为选择圆圈（替换品牌 mark） */
  @Prop selectable: boolean = false
  /** 选择圆圈选中态：primary 反转块 + 白勾（遵循 DESIGN 原则 8） */
  @Prop selected: boolean = false
  /** 防窥脱敏态：系统检测到窥视时金额/名称/日期/分期打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  @State iconUrl: string = ''
  @State iconFailed: boolean = false
  @State private iconFromAccount: boolean = false
  private static iconUrlCache: Map<string, string> = new Map<string, string>()
  private static iconFaceCache: Map<string, boolean> = new Map<string, boolean>()

  /** 与 Tab 顶预览 / 分组列表同色 surface2，避免独立卡落到偏暗 surface */
  private cardBg(): ResourceColor {
    return this.theme.surface2
  }

  /** 整块大卡：首行顶部两角、末行底部两角 radiusXl；侧滑展开时右侧贴平 */
  private cardRadius(): BorderRadiuses {
    return {
      topLeft: this.isFirstInGroup ? this.theme.radiusXl : 0,
      topRight: this.isFirstInGroup && !this.isSwiped ? this.theme.radiusXl : 0,
      bottomLeft: this.isSwiped ? 0 : (this.isLastInGroup ? this.theme.radiusXl : 0),
      bottomRight: this.isLastInGroup && !this.isSwiped ? this.theme.radiusXl : 0
    }
  }

  private showGroupDivider(): boolean {
    return !this.isLastInGroup
  }

  aboutToAppear() {
    this.loadAccountIcon()
  }

  /** 列表复用：@Prop 由框架自动更新，这里只重置本地图标状态（debt 变化时 @Watch 也会重拉） */
  aboutToReuse(): void {
    this.iconUrl = ''
    this.iconFailed = false
    this.iconFromAccount = false
    this.loadAccountIcon()
  }

  private onDebtChange(): void {
    this.iconFailed = false
    this.iconFromAccount = false
    this.loadAccountIcon()
  }

  private cacheKey(): string {
    return (this.debt.credit_account_id || '') + '|' + (this.debt.platform || '')
  }

  private matchAccountIcon(accounts: CreditAccount[], platform: string): string {
    const pn = platform.toLowerCase()
    if (pn.length === 0) {
      return ''
    }
    for (let i = 0; i < accounts.length; i++) {
      const a = accounts[i]
      if (!a.icon_url || a.icon_url.length === 0) {
        continue
      }
      const an = (a.name || '').toLowerCase()
      if (an.length > 0 && (an === pn || an.includes(pn) || pn.includes(an))) {
        return a.icon_url
      }
    }
    return ''
  }

  private async loadAccountIcon(): Promise<void> {
    const key = this.cacheKey()
    const cached = DebtCard.iconUrlCache.get(key)
    if (cached !== undefined) {
      this.iconUrl = cached
      this.iconFromAccount = DebtCard.iconFaceCache.get(key) === true
      return
    }
    const platform = this.debt.platform || ''
    if (this.debt.credit_account_id && this.debt.credit_account_id.length > 0) {
      try {
        const acc = await CreditAccountService.getCreditAccountById(this.debt.credit_account_id)
        if (acc) {
          if (acc.icon_url && acc.icon_url.length > 0) {
            this.setIcon(key, acc.icon_url, true)
            return
          }
          const presetUrl = PlatformService.getLogoUrlForName(acc.name)
          if (presetUrl.length > 0) {
            this.setIcon(key, presetUrl, true)
            return
          }
        }
      } catch (_err) {
      }
    }
    if (!this.debt.credit_account_id || this.debt.credit_account_id.length === 0) {
      const projected = LocalDataStore.getAccounts()
      if (projected !== null) {
        const matchedUrl = this.matchAccountIcon(projected, platform)
        if (matchedUrl.length > 0) {
          this.setIcon(key, matchedUrl, true)
          return
        }
      }
    }
    if (this.debt.icon_url && this.debt.icon_url.length > 0) {
      this.setIcon(key, this.debt.icon_url, IconPickerService.isCardFaceUrl(this.debt.icon_url))
      return
    }
    const remote = PlatformService.getLogoUrlForName(platform)
    if (remote.length > 0) {
      this.setIcon(key, remote, false)
    }
  }

  private setIcon(key: string, url: string, fromAccount: boolean): void {
    this.iconUrl = url
    this.iconFromAccount = fromAccount
    DebtCard.iconUrlCache.set(key, url)
    DebtCard.iconFaceCache.set(key, fromAccount)
  }

  private showLogo(): boolean {
    return this.iconUrl.length > 0 && !this.iconFailed
  }

  private brandMark(): string {
    return PlatformService.getBrandVisual(this.debt.platform).mark
  }

  private brandColor(): string {
    return brandColor(this.debt.platform_color, this.debt.platform)
  }

  private isOverdue(): boolean {
    return isOverdue(this.debt.status, this.debt.next_payment_date, Utils.todayString())
  }

  /** 高利率：年利率≥阈值（18%） */
  private isHighRate(): boolean {
    return isHighRate(this.debt.annual_rate_bp)
  }

  /** 进度/类型：用户关心「还到哪了」 */
  private progressLabel(): string {
    return Utils.maskIf(this.antiPeekMasked,
      progressLabel(this.debt.debt_type, this.debt.total_periods, this.debt.remaining_periods, this.debt.status))
  }

  /** 次行左侧：余额上下文 */
  private balanceLine(): string {
    return balanceLine(this.debt.current_balance, this.debt.status, this.progressLabel(), this.debt.debt_type)
  }

  /** 右上：本期应还（行动金额）；已完成/暂停为状态文案非金额，不打码 */
  private primaryAmountText(): string {
    if (this.antiPeekMasked && this.debt.status === 'active') {
      return Utils.MASK_AMOUNT
    }
    return primaryAmountText(this.debt.status, this.debt.monthly_payment)
  }

  private primaryAmountColor(): ResourceColor {
    if (this.debt.status === 'completed' || this.debt.status === 'paused') {
      return this.theme.text3
    }
    return this.theme.text
  }

  private statusTagText(): string {
    return statusTagText(this.debt.status, this.debt.next_payment_date, Utils.todayString())
  }

  private statusTagRole(): string {
    return statusTagRole(this.debt.status, this.debt.next_payment_date, Utils.todayString())
  }

  /**
   * 右下：到期紧迫（用户决策核心）
   * 与订阅卡 expiryLine 同源语义：日期在前 · 提示在后
   */
  private dueLine(): string {
    return Utils.maskIf(this.antiPeekMasked, dueLine(this.debt.status, this.debt.next_payment_date,
      this.isOverdue(),
      this.debt.next_payment_date ? Utils.daysFromNow(this.debt.next_payment_date) : 0,
      this.debt.payment_day))
  }

  private dueLineColor(): ResourceColor {
    if (this.debt.status === 'completed' || this.debt.status === 'paused') {
      return this.theme.statusInactive()
    }
    if (!this.debt.next_payment_date || this.debt.next_payment_date.length === 0) {
      return this.theme.text3
    }
    return this.theme.dueUrgencyColor(Utils.daysFromNow(this.debt.next_payment_date))
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        if (this.selectable) {
          Stack({ alignContent: Alignment.Center }) {
            if (this.selected) {
              Image($r('app.media.ic_check'))
                .width(16)
                .height(16)
                .fillColor(this.theme.onPrimary)
                .objectFit(ImageFit.Contain)
            }
          }
          .width(MotionTokens.listLogoSize)
          .height(MotionTokens.listLogoSize)
          .borderRadius(this.theme.radiusPill)
          .backgroundColor(this.selected ? this.theme.primary : Color.Transparent)
          .border({ width: 1.5, color: this.selected ? this.theme.primary : this.theme.border })
          .margin({ right: 12 })
        } else if (this.showLogo()) {
          LogoImage({
            theme: this.theme,
            url: this.iconUrl,
            logoSize: MotionTokens.listLogoSize,
            radius: MotionTokens.listLogoRadius,
            onError: () => {
              this.iconFailed = true
            }
          })
            .margin({ right: 12 })
        } else {
          Column() {
            Text(this.brandMark())
              .fontSize(this.brandMark().length > 1 ? 12 : 15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.onColorBlock())
          }
          .width(MotionTokens.listLogoSize)
          .height(MotionTokens.listLogoSize)
          .borderRadius(MotionTokens.listLogoRadius)
          .backgroundColor(this.brandColor())
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ right: 12 })
        }

        // 两行：主行只放名称+本期应还；状态与余额/期数共用次行，避免长名被 tag 裁切
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(Utils.maskIf(this.antiPeekMasked, this.debt.platform))
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(this.primaryAmountText())
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Bold)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.primaryAmountColor())
              .letterSpacing(TypeScale.listNumberSpacing)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .flexShrink(0)
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row({ space: 6 }) {
            StatusTag({
              theme: this.theme,
              text: this.statusTagText(),
              role: this.statusTagRole()
            })

            if (this.isHighRate()) {
              StatusTag({ theme: this.theme, text: '高利率', role: 'danger' })
            }

            if (this.progressLabel().length > 0) {
              Text(this.progressLabel())
                .fontSize(TypeScale.caption)
                .fontColor(this.theme.text3)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
                .margin({ right: 10 })
            } else {
              Blank()
                .layoutWeight(1)
            }

            if (this.dueLine().length > 0) {
              Text(this.dueLine())
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.dueLineColor())
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .flexShrink(0)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .justifyContent(FlexAlign.Center)
      }
      .width('100%')
      .height(MotionTokens.listRowHeight)
      .padding({ left: 16, right: 16, top: 16, bottom: 16 })
      .alignItems(VerticalAlign.Center)

      if (this.showGroupDivider()) {
        Row()
          .width('100%')
          .height(1)
          .backgroundColor(this.theme.border)
      }
    }
    .width('100%')
    .height(MotionTokens.listRowHeight)
    .backgroundColor(this.cardBg())
    .borderRadius(this.cardRadius())
    .clip(true)
    // 整块大卡：每行 float 阴影，行间被相邻卡覆盖，仅外缘露出一圈
    .shadow(this.theme.floatShadowOptions())
    .hoverEffect(HoverEffect.Auto)
  }
}
