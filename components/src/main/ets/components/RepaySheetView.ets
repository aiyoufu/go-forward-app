import { Debt } from 'common'
import {ThemeColors, TypeScale, MotionTokens} from 'common'
import { Utils, AppStorageKeys } from 'common'
import { CalculationService, PlatformService, IconPickerService } from 'service'
import { CreditAccountService } from 'service'
import { SheetHeader, sheetBottomInset } from './SheetDialog'
import { LogoImage } from './LogoImage'

@Component
export struct RepaySheetView {
  @Prop @Watch('onDebtChange') debt: Debt = new Debt()
  @Prop theme: ThemeColors = new ThemeColors()
  /** 防窥脱敏态：系统检测到窥视时弹窗内金额/名称/日期/分期打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false

  onConfirmRepay: () => void = () => {}
  onPayoff: () => void = () => {}
  onCancel: () => void = () => {}

  @State iconUrl: string = ''
  @State iconFailed: boolean = false
  @State private iconFromAccount: boolean = false

  private static iconUrlCache: Map<string, string> = new Map<string, string>()

  aboutToAppear() {
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

  private async loadAccountIcon(): Promise<void> {
    const key = this.cacheKey()
    const cached = RepaySheetView.iconUrlCache.get(key)
    if (cached !== undefined) {
      this.iconUrl = cached
    }

    const platform = this.debt.platform || ''

    if (this.debt.credit_account_id && this.debt.credit_account_id.length > 0) {
      try {
        const acc = await CreditAccountService.getCreditAccountById(this.debt.credit_account_id)
        if (acc && acc.icon_url && acc.icon_url.length > 0) {
          this.iconUrl = acc.icon_url
          this.iconFromAccount = true
          RepaySheetView.iconUrlCache.set(key, acc.icon_url)
          return
        }
      } catch (_err) {}
    }

    try {
      const accounts = await CreditAccountService.getCreditAccounts()
      // 先在局部变量里命中，循环结束后再写状态变量，避免循环内访问状态
      let matchedUrl = ''
      for (let i = 0; i < accounts.length; i++) {
        const a = accounts[i]
        if (!a.icon_url || a.icon_url.length === 0) {
          continue
        }
        const an = (a.name || '').toLowerCase()
        const pn = platform.toLowerCase()
        if (an.length > 0 && pn.length > 0 && (an === pn || an.includes(pn) || pn.includes(an))) {
          matchedUrl = a.icon_url
          break
        }
      }
      if (matchedUrl.length > 0) {
        this.iconUrl = matchedUrl
        this.iconFromAccount = true
        RepaySheetView.iconUrlCache.set(key, matchedUrl)
        return
      }
    } catch (_err) {}

    const remote = PlatformService.getLogoUrlForName(platform)
    if (remote.length > 0) {
      this.iconUrl = remote
      this.iconFromAccount = false
      RepaySheetView.iconUrlCache.set(key, remote)
    }
  }

  private showLogo(): boolean {
    return this.iconUrl.length > 0 && !this.iconFailed
  }

  private useCardFace(): boolean {
    if (this.iconFailed) {
      return false
    }
    return this.iconFromAccount || IconPickerService.isCardFaceUrl(this.iconUrl)
  }

  private brandMark(): string {
    return PlatformService.getBrandVisual(this.debt.platform).mark
  }

  private brandColor(): string {
    if (this.debt.platform_color && this.debt.platform_color.length > 0) {
      return this.debt.platform_color
    }
    const visual = PlatformService.getBrandVisual(this.debt.platform)
    if (visual.color && visual.color.length > 0) {
      return visual.color
    }
    return '#2F3336'
  }

  private repaymentMethodLabel(): string {
    const m = this.debt.repayment_method
    if (m === 'equal_payment') {
      return '等额本息'
    }
    if (m === 'fixed_interest') {
      return '先息后本'
    }
    if (m === 'custom') {
      return '自定义'
    }
    return m
  }

  build() {
    Column({ space: 0 }) {
      // 头部标题：左侧标题，右侧关闭按钮（1fr:auto）
      SheetHeader({
        theme: this.theme,
        title: '还款确认',
        onClose: () => {
          this.onCancel()
        }
      })

      // 概览信息小卡片
      Row() {
        Column() {
        // 卡片顶部信息：Logo + 名称 + 类型标签 与 期数
        Row() {
          if (this.showLogo()) {
            LogoImage({
              theme: this.theme,
              url: this.iconUrl,
              logoSize: MotionTokens.listLogoSize,
              radius: MotionTokens.listLogoRadius,
              remoteExact: this.useCardFace(),
              remotePrefix: this.useCardFace() ? 'card_face_' : 'icon_net_',
              onError: () => {
                this.iconFailed = true
              }
            })
              .margin({ right: 10 })
          } else {
            Column() {
              Text(this.brandMark())
                .fontSize(this.brandMark().length > 1 ? 11 : 14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.onColorBlock())
            }
            .width(MotionTokens.listLogoSize)
            .height(MotionTokens.listLogoSize)
            .borderRadius(this.theme.radiusSm)
            .backgroundColor(this.brandColor())
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .margin({ right: 10 })
          }

          Column({ space: 2 }) {
            Text(Utils.maskIf(this.antiPeekMasked, this.debt.platform))
              .fontSize(TypeScale.listPrimarySm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })

            Text(Utils.maskIf(this.antiPeekMasked, this.repaymentMethodLabel()))
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 期数或还款模式角标
          Row() {
            if (this.debt.debt_type === 'installment') {
              Text(Utils.maskIf(this.antiPeekMasked,
                '第 ' + (this.debt.total_periods - this.debt.remaining_periods + 1) + '/' + this.debt.total_periods + ' 期'))
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.statusOk())
            } else {
              Text('一次性/随借')
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.accent)
            }
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.theme.chip)
          .borderRadius(this.theme.radiusSm)
          .border({ width: 1, color: this.theme.border })
        }
        .width('100%')

        // 卡片中部：本期/单期应还金额大字展示
        Column({ space: 6 }) {
          Text(this.debt.debt_type === 'installment' ? '本期应还金额 (元)' : '应还金额 (元)')
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text2)

          Text(Utils.maskIf(this.antiPeekMasked,
            Utils.formatMoney(this.debt.debt_type === 'installment' ? this.debt.monthly_payment : (this.debt.monthly_payment > 0 ? this.debt.monthly_payment : this.debt.current_balance), false),
            Utils.MASK_AMOUNT))
            .fontSize(TypeScale.heroNumber)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
            .fontFamily('Helvetica Neue') // 使用精致数字字体
        }
        .width('100%')
        .margin({ top: 20, bottom: 20 })
        .alignItems(HorizontalAlign.Center)

        // 分割线
        Divider()
          .color(this.theme.border)
          .strokeWidth(0.5)
          .margin({ bottom: 12 })

        // 卡片底部：剩余余额 & 还款日
        Row() {
          Column({ space: 4 }) {
            Text('剩余未还总额')
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
            Text(Utils.maskIf(this.antiPeekMasked,
              Utils.formatMoney(
                this.debt.debt_type === 'installment'
                  ? CalculationService.getInstallmentRemainingDue(this.debt)
                  : this.debt.current_balance, true),
              Utils.MASK_AMOUNT))
              .fontSize(TypeScale.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text2)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column({ space: 4 }) {
            Text(this.debt.debt_type === 'installment' ? '下期还款日' : '还款日')
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
            Text(Utils.maskIf(this.antiPeekMasked,
              this.debt.next_payment_date.length > 0 ? this.debt.next_payment_date : '--'))
              .fontSize(TypeScale.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text2)
          }
          .alignItems(HorizontalAlign.End)
          .layoutWeight(1)
        }
        .width('100%')
      }
        .layoutWeight(1)
        .padding(this.theme.spaceSm)
        .backgroundColor(this.theme.sheetItemBackground())
        .borderRadius(this.theme.sheetCardRadius)
        .border({ width: 1, color: this.theme.borderStrong })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      // 按钮操作区
      Row() {
        Column({ space: 12 }) {
          if (this.debt.debt_type === 'installment') {
            // 分期负债：显示【本期还款】与【一次性还清】两个按钮
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Row() {
                Text(Utils.maskIf(this.antiPeekMasked,
                  '本期还款 ' + Utils.formatMoney(this.debt.monthly_payment, true),
                  '本期还款 ' + Utils.MASK_AMOUNT))
                  .fontSize(TypeScale.listPrimary)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.ctaForeground())
              }
            }
            .width('100%')
            .height(48)
            .backgroundColor(this.theme.ctaBackground())
            .onClick(() => {
              this.onConfirmRepay()
            })

            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Row() {
                Text(Utils.maskIf(this.antiPeekMasked,
                  '一次性还清 ' + Utils.formatMoney(this.debt.current_balance, true), '一次性还清 ' + Utils.MASK_AMOUNT))
                  .fontSize(TypeScale.listPrimarySm)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(this.theme.text)
              }
            }
            .width('100%')
            .height(48)
            .backgroundColor(this.theme.sheetItemBackground())
            .border({ width: 1, color: this.theme.borderStrong })
            .onClick(() => {
              this.onPayoff()
            })
          } else {
            // 一次性/随借负债：仅显示单个【还款】按钮
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Row() {
                Text(Utils.maskIf(this.antiPeekMasked,
                  '还款 ' + Utils.formatMoney(this.debt.monthly_payment > 0 ? this.debt.monthly_payment : this.debt.current_balance, true),
                  '还款 ' + Utils.MASK_AMOUNT))
                  .fontSize(TypeScale.listPrimary)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.ctaForeground())
              }
            }
            .width('100%')
            .height(48)
            .backgroundColor(this.theme.ctaBackground())
            .onClick(() => {
              this.onConfirmRepay()
            })
          }

          // 取消
          Text('暂不还款')
            .fontSize(TypeScale.control)
            .fontColor(this.theme.text2)
            .padding({ top: 4, bottom: 4 })
            .onClick(() => {
              this.onCancel()
            })
        }
        .layoutWeight(1)
        .padding({ bottom: 4 }) // 视觉留白；安全区由外层 sheetBottomInset 统一避让
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      .margin({ top: 20 })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ top: 0, bottom: sheetBottomInset() })
  }
}
