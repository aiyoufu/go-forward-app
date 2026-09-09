import { CreditAccount } from 'common'
import { ThemeColors, TypeScale, MotionTokens } from 'common'
import { PlatformService, BrandVisual } from 'service'
import { Utils, AppStorageKeys } from 'common'
import { LogoImage } from './LogoImage'

/**
 * 信用账户列表卡 · 功能优先
 * 用户决策：哪张卡？额度多少？单据/还款日何时？
 * 结构：左品牌 · 中身份(名+尾号)/周期 · 右额度
 */
@Component
@Reusable
export struct CreditAccountCard {
  @Prop account: CreditAccount = new CreditAccount()
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop isSwiped: boolean = false
  /** 组内首尾行：外露角 radiusXl，中间行直角 */
  @Prop isFirstInGroup: boolean = false
  @Prop isLastInGroup: boolean = false
  /** 批量选择模式：true 时左上标记位渲染为选择圆圈（替换 mark/logo） */
  @Prop selectable: boolean = false
  /** 选择圆圈选中态：primary 反转块 + 白勾（遵循 DESIGN 原则 8） */
  @Prop selected: boolean = false
  /** 防窥脱敏态：系统检测到窥视时名称/尾号/额度/周期打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  @State private iconFailed: boolean = false

  /** 列表复用：@Prop 自动更新，仅重置本地图标失败标记 */
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
    return PlatformService.getBrandVisual(this.account.name)
  }

  private hasLogoUrl(): boolean {
    if (this.iconFailed) {
      return false
    }
    if (this.account.icon_url !== undefined && this.account.icon_url.length > 0) {
      return true
    }
    return PlatformService.getLogoUrlForName(this.account.name).length > 0
  }

  private resolveLogoUrl(): string {
    if (this.account.icon_url !== undefined && this.account.icon_url.length > 0) {
      return this.account.icon_url
    }
    return PlatformService.getLogoUrlForName(this.account.name)
  }

  private hasLastFour(): boolean {
    return this.account.last_four !== undefined && this.account.last_four.trim().length > 0
  }

  private avatarColor(): string {
    const visual = this.brandVisual()
    if (visual.matchedKey.length > 0 && visual.color.length > 0) {
      return visual.color
    }
    if (this.account.color && this.account.color.length > 0) {
      return this.account.color
    }
    return visual.color
  }

  /** 主行身份：名称 · 尾号（辨认卡片） */
  private identityTitle(): string {
    const name = this.account.name || '未命名账户'
    if (this.hasLastFour()) {
      return Utils.maskIf(this.antiPeekMasked, name + ' · ' + this.account.last_four.trim())
    }
    return Utils.maskIf(this.antiPeekMasked, name)
  }

  private limitValue(): string {
    const limit = Number(this.account.credit_limit) || 0
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

  private hasLimit(): boolean {
    return (Number(this.account.credit_limit) || 0) > 0
  }

  /**
   * 次行：出单日/还款周期（用户记卡用）
   * 年费进度仅在有配置时附带
   */
  private cycleLine(): string {
    const parts: string[] = []
    if (this.account.bill_day > 0) {
      parts.push('单据 ' + this.account.bill_day + '日')
    }
    if (this.account.payment_day > 0) {
      parts.push('还款 ' + this.account.payment_day + '日')
    }
    if (this.account.annual_fee_required_swipes > 0) {
      parts.push('年费 ' + this.account.annual_fee_manual_swipes + '/' +
        this.account.annual_fee_required_swipes)
    }
    if (parts.length === 0) {
      return Utils.maskIf(this.antiPeekMasked, '未设置出单周期')
    }
    return Utils.maskIf(this.antiPeekMasked, parts.join(' · '))
  }

  /** 距还款日远近（本月口径，仅提示临近） */
  private paymentHint(): string {
    if (this.antiPeekMasked) {
      return ''
    }
    if (this.account.payment_day <= 0) {
      return ''
    }
    const today = new Date()
    const day = today.getDate()
    const payDay = this.account.payment_day
    let days = payDay - day
    if (days < 0) {
      // 下月
      const y = today.getFullYear()
      const m = today.getMonth()
      const nextMonth = new Date(y, m + 1, payDay)
      days = Utils.daysFromNow(Utils.formatDate(nextMonth))
    } else if (days === 0) {
      return '今天还款日'
    }
    if (days > 0 && days <= 3) {
      return days === 1 ? '明天还款日' : (days + '天后还款')
    }
    return ''
  }

  private paymentHintColor(): ResourceColor {
    const hint = this.paymentHint()
    if (hint.indexOf('今天') >= 0) {
      return this.theme.dueUrgencyColor(0)
    }
    if (hint.indexOf('明天') >= 0) {
      return this.theme.dueUrgencyColor(1)
    }
    if (hint.length > 0) {
      return this.theme.dueUrgencyColor(2)
    }
    return this.theme.text3
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
        } else if (this.hasLogoUrl()) {
          LogoImage({
            theme: this.theme,
            url: this.resolveLogoUrl(),
            logoSize: MotionTokens.listLogoSize,
            radius: MotionTokens.listLogoRadius,
            onError: () => {
              this.iconFailed = true
            }
          })
            .margin({ right: 12 })
        } else {
          Column() {
            Text(this.brandVisual().mark)
              .fontSize(this.brandVisual().mark.length > 1 ? 12 : 15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.onColorBlock())
          }
          .width(MotionTokens.listLogoSize)
          .height(MotionTokens.listLogoSize)
          .borderRadius(MotionTokens.listLogoRadius)
          .backgroundColor(this.avatarColor())
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .margin({ right: 12 })
        }

        Column({ space: 6 }) {
          Row() {
            Text(this.identityTitle())
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ right: 8 })

            if (this.hasLimit()) {
              Row() {
                Text(Utils.maskIf(this.antiPeekMasked, this.limitValue()))
                  .fontSize(TypeScale.listPrimary)
                  .fontWeight(FontWeight.Bold)
                  .fontFamily(TypeScale.FONT_MONO)
                  .fontColor(this.theme.text)
                  .letterSpacing(TypeScale.listNumberSpacing)
                Text('万')
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
                  .margin({ left: 2, bottom: 2 })
              }
              .alignItems(VerticalAlign.Bottom)
              .flexShrink(0)
            } else {
              Text('未填额度')
                .fontSize(TypeScale.caption)
                .fontColor(this.theme.text3)
                .flexShrink(0)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          Row() {
            Text(this.cycleLine())
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ right: 10 })

            if (this.paymentHint().length > 0) {
              Text(this.paymentHint())
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontFamily(TypeScale.FONT_MONO)
                .fontColor(this.paymentHintColor())
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
