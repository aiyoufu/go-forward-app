import { Subscription } from 'common'
import { ThemeColors, TypeScale, MotionTokens } from 'common'
import { Utils, AppStorageKeys } from 'common'
import { PlatformService, BrandVisual } from 'service'
import { LogoImage } from './LogoImage'
import { StatusTag } from './StatusTag'

/** 纯函数：周期短后缀 */
export function cycleAbbr(billingCycle: string): string {
  const c = billingCycle
  if (c === 'weekly' || c === 'once_weekly') {
    return '/周'
  }
  if (c === 'biweekly') {
    return '/2周'
  }
  if (c === 'monthly') {
    return '/月'
  }
  if (c === 'quarterly' || c === 'once_quarterly') {
    return '/季'
  }
  if (c === 'semiannually') {
    return '/半年'
  }
  if (c === 'annually' || c === 'once_annually') {
    return '/年'
  }
  if (c === 'once') {
    return ''
  }
  return ''
}

/** 纯函数：完整周期文案 */
export function cycleFullLabel(billingCycle: string): string {
  const c = billingCycle
  if (c === 'weekly') {
    return '每周'
  }
  if (c === 'once_weekly') {
    return '一周'
  }
  if (c === 'biweekly') {
    return '每两周'
  }
  if (c === 'monthly') {
    return '每月'
  }
  if (c === 'quarterly') {
    return '每季'
  }
  if (c === 'once_quarterly') {
    return '一季度'
  }
  if (c === 'semiannually') {
    return '每半年'
  }
  if (c === 'annually') {
    return '每年'
  }
  if (c === 'once_annually') {
    return '一年'
  }
  if (c === 'once') {
    return '一次性'
  }
  return ''
}

/**
 * 纯函数：周期时长文案（一X 表述）
 * 周期性与一次性统一为时长：一个月 / 一季度 / 一年 / 一周 / 两周 / 半年
 * （列表与详情沿用 PlatformService.once 的 "一个月" 标签，与编辑页保持一致）
 * 用于详情「扣费周期」与列表副行；表单选择器仍用 label（每X / 一X 区分周期性与一次性），故不改动 label
 */
export function cycleDurationLabel(billingCycle: string): string {
  const c = billingCycle
  if (c === 'weekly' || c === 'once_weekly') {
    return '一周'
  }
  if (c === 'biweekly') {
    return '两周'
  }
  if (c === 'monthly' || c === 'once') {
    return '一个月'
  }
  if (c === 'quarterly' || c === 'once_quarterly') {
    return '一季度'
  }
  if (c === 'semiannually') {
    return '半年'
  }
  if (c === 'annually' || c === 'once_annually') {
    return '一年'
  }
  return ''
}

/** 纯函数：次行左侧元数据行（分类 · 周期时长） */
export function metaLine(categoryLabel: string, cycleLabel: string): string {
  if (categoryLabel.length > 0 && cycleLabel.length > 0) {
    return categoryLabel + ' · ' + cycleLabel
  }
  if (cycleLabel.length > 0) {
    return cycleLabel
  }
  return categoryLabel
}

/**
 * 纯函数：周期时长文案（方案 B）
 * monthsPerCycle 为整月 ->「N个月」；约整周 ->「N周」；否则回退 cycleFullLabel
 */
export function durationLabel(billingCycle: string, monthsPerCycle: number): string {
  if (monthsPerCycle > 0) {
    const whole = Math.round(monthsPerCycle)
    if (Math.abs(monthsPerCycle - whole) < 0.01 && whole >= 1) {
      return whole + '个月'
    }
    const weeks = Math.round(monthsPerCycle * 4)
    if (weeks >= 1) {
      return weeks + '周'
    }
  }
  return cycleFullLabel(billingCycle)
}

/** 纯函数：格式化下次扣费日期（短：6月15日） */
export function formatNextDate(nextBillingDate: string): string {
  if (!nextBillingDate) {
    return ''
  }
  try {
    const d = new Date(nextBillingDate)
    if (isNaN(d.getTime())) {
      return nextBillingDate
    }
    return (d.getMonth() + 1) + '月' + d.getDate() + '日'
  } catch (_e) {
    return nextBillingDate
  }
}

/** 纯函数：到期日 YYYY-MM-DD（补零） */
export function formatExpiryYmd(nextBillingDate: string): string {
  if (!nextBillingDate || nextBillingDate.length === 0) {
    return ''
  }
  const pad = (n: number): string => (n < 10 ? '0' + n : '' + n)
  if (nextBillingDate.length >= 10 && nextBillingDate.charAt(4) === '-') {
    const parts = nextBillingDate.substring(0, 10).split('-')
    if (parts.length === 3 && parts[0].length === 4) {
      return parts[0] + '-' + pad(Number(parts[1])) + '-' + pad(Number(parts[2]))
    }
  }
  try {
    const d = new Date(nextBillingDate)
    if (isNaN(d.getTime())) {
      return nextBillingDate
    }
    return d.getFullYear() + '-' + pad(d.getMonth() + 1) + '-' + pad(d.getDate())
  } catch (_e) {
    return nextBillingDate
  }
}

/** 纯函数：是否已过期 */
export function isExpired(status: string, nextBillingDate: string, daysFromNowResult: number): boolean {
  if (status !== 'active') {
    return false
  }
  if (!nextBillingDate) {
    return false
  }
  return daysFromNowResult < 0
}

/**
 * 纯函数：底行到期文案（日期 + 提示词）
 * 例：2026-08-20 到期 / 2026-08-20 已过期
 */
export function expiryLine(
  status: string,
  ymd: string,
  isExpiredResult: boolean,
  daysFromNowResult: number
): string {
  if (ymd.length === 0) {
    if (status === 'active') {
      return '待设扣费日'
    }
    return ''
  }
  if (isExpiredResult) {
    return ymd + ' 已过期'
  }
  return ymd + ' 到期'
}

/**
 * 纯函数：旧版短到期行（兼容导出/测试；卡片主路径用 expiryLine）
 */
export function statusDateLine(status: string, nextBillingDate: string, formatNextDateResult: string, isExpiredResult: boolean, daysFromNowResult: number): string {
  if (status === 'cancelled') {
    return '已取消'
  }
  if (status === 'paused') {
    return '已暂停'
  }
  if (formatNextDateResult.length === 0) {
    return status === 'active' ? '待设扣费日' : ''
  }
  if (isExpiredResult) {
    return '已过期 · ' + formatNextDateResult
  }
  if (daysFromNowResult === 0) {
    return '今天扣费'
  }
  if (daysFromNowResult === 1) {
    return '明天 · ' + formatNextDateResult
  }
  if (daysFromNowResult <= 3) {
    return daysFromNowResult + '天后 · ' + formatNextDateResult
  }
  if (daysFromNowResult <= 14) {
    return daysFromNowResult + '天后 · ' + formatNextDateResult
  }
  return '下次 ' + formatNextDateResult
}

/** 纯函数：状态 tag 文案（生效中 / 已暂停 / 已取消） */
export function statusTagText(status: string): string {
  if (status === 'paused') {
    return '已暂停'
  }
  if (status === 'cancelled') {
    return '已取消'
  }
  return '生效中'
}

/** 纯函数：状态 tag 语义角色（ok 绿 / warn 琥珀 / off 灰） */
export function statusTagRole(status: string): string {
  if (status === 'paused') {
    return 'warn'
  }
  if (status === 'cancelled') {
    return 'off'
  }
  return 'ok'
}

/** 纯函数：绑定账户展示「名称(尾号)」 */
export function creditAccountLabel(name: string, lastFour: string): string {
  const n = name || ''
  const four = lastFour || ''
  if (n.length === 0 && four.length === 0) {
    return ''
  }
  if (n.length === 0) {
    return '尾号' + four
  }
  if (four.length === 0) {
    return n
  }
  return n + '(' + four + ')'
}

/**
 * 订阅列表卡 · 两行统一范式（与 DebtCard / CreditAccountCard 对齐，固定 listRowHeight）
 *
 *   Logo | 名称 ……………………………… ¥金额
 *        | 生效中  分类 · 时长 ……………… YYYY-M-D 到期
 */
@Component
@Reusable
export struct SubscriptionCard {
  @Prop subscription: Subscription = new Subscription()
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop isSwiped: boolean = false
  /** 组内首尾行：外露角 radiusXl，中间行直角 */
  @Prop isFirstInGroup: boolean = false
  @Prop isLastInGroup: boolean = false
  /** 批量选择模式：true 时左上标记位渲染为选择圆圈（替换 mark/logo） */
  @Prop selectable: boolean = false
  /** 选择圆圈选中态：primary 反转块 + 白勾（遵循 DESIGN 原则 8） */
  @Prop selected: boolean = false
  /** 防窥脱敏态：系统检测到窥视时金额/名称/周期/日期打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  @State private iconFailed: boolean = false

  /** 列表复用：@Prop 自动更新，仅重置本地图标态 */
  aboutToReuse(): void {
    this.iconFailed = false
  }

  /** 与 Tab 顶预览同色 surface2 */
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

  private brandVisual(): BrandVisual {
    return PlatformService.getBrandVisual(this.subscription.name)
  }

  private avatarColor(): string {
    if (this.subscription.color && this.subscription.color.length > 0) {
      return this.subscription.color
    }
    const v = this.brandVisual()
    return v.color.length > 0 ? v.color : '#2F3336'
  }

  private mark(): string {
    const v = this.brandVisual()
    if (v.mark.length > 0) {
      return v.mark
    }
    const n = this.subscription.name || ''
    return n.length > 0 ? n.substring(0, 1) : '订'
  }

  private getIconUrl(): string {
    if (this.subscription.icon_url && this.subscription.icon_url.length > 0) {
      return this.subscription.icon_url
    }
    return PlatformService.getLogoUrlForName(this.subscription.name)
  }

  private categoryLabel(): string {
    return PlatformService.getCategoryInfo(this.subscription.category).label
  }

  /** 周期文案：与详情「扣费周期」统一，使用 cycleDurationLabel（一X 时长表述） */
  private cycleLabel(): string {
    return cycleDurationLabel(this.subscription.billing_cycle)
  }

  private metaLine(): string {
    return Utils.maskIf(this.antiPeekMasked, metaLine(this.categoryLabel(), this.cycleLabel()))
  }

  private daysNow(): number {
    if (!this.subscription.next_billing_date) {
      return 0
    }
    return Utils.daysFromNow(this.subscription.next_billing_date)
  }

  private isExpired(): boolean {
    return isExpired(this.subscription.status, this.subscription.next_billing_date, this.daysNow())
  }

  private expiryLine(): string {
    return Utils.maskIf(this.antiPeekMasked, expiryLine(
      this.subscription.status,
      formatExpiryYmd(this.subscription.next_billing_date),
      this.isExpired(),
      this.daysNow()
    ))
  }

  private expiryColor(): ResourceColor {
    if (this.subscription.status === 'cancelled') {
      return this.theme.statusInactive()
    }
    if (this.subscription.status === 'paused') {
      return this.theme.statusMuted()
    }
    if (!this.subscription.next_billing_date) {
      return this.theme.statusInactive()
    }
    return this.theme.dueUrgencyColor(this.daysNow())
  }

  private statusTagText(): string {
    return statusTagText(this.subscription.status)
  }

  private statusTagRole(): string {
    return statusTagRole(this.subscription.status)
  }

  private amountColor(): ResourceColor {
    if (this.subscription.status === 'cancelled' || this.subscription.status === 'paused') {
      return this.theme.text3
    }
    return this.theme.text
  }

  @Builder
  private logoBuilder() {
    if (this.getIconUrl().length > 0 && !this.iconFailed) {
      LogoImage({
        theme: this.theme,
        url: this.getIconUrl(),
        logoSize: MotionTokens.listLogoSize,
        radius: MotionTokens.listLogoRadius,
        onError: () => {
          this.iconFailed = true
        }
      })
    } else {
      Column() {
        Text(this.mark())
          .fontSize(TypeScale.caption)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.onColorBlock())
      }
      .width(MotionTokens.listLogoSize)
      .height(MotionTokens.listLogoSize)
      .borderRadius(MotionTokens.listLogoRadius)
      .backgroundColor(this.avatarColor())
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
    }
  }

  @Builder
  private selectionIndicator() {
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
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Row() {
        Column() {
          if (this.selectable) {
            this.selectionIndicator()
          } else {
            this.logoBuilder()
          }
        }
        .flexShrink(0)
        .margin({ right: 12 })

        // 两行：主行只放名称+金额；状态与分类/周期共用次行，避免长名被 tag 裁切
        Column({ space: 6 }) {
          Row({ space: 8 }) {
            Text(Utils.maskIf(this.antiPeekMasked, this.subscription.name))
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            Text(Utils.maskIf(this.antiPeekMasked,
              Utils.formatMoney(this.subscription.amount), Utils.MASK_AMOUNT))
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Bold)
              .fontFamily(TypeScale.FONT_MONO)
              .fontColor(this.amountColor())
              .letterSpacing(TypeScale.listNumberSpacing)
              .maxLines(1)
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

            Text(this.metaLine().length > 0 ? this.metaLine() : '－')
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ right: 10 })

            if (this.expiryLine().length > 0) {
              Text(this.expiryLine())
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.expiryColor())
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
          .backgroundColor(this.theme.borderSoft)
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
