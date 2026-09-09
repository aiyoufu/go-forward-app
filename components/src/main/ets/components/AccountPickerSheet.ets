import { CreditAccount } from 'common'
import { ThemeColors, TypeScale, MotionTokens } from 'common'
import { PlatformService } from 'service'
import { LogoImage } from './LogoImage'
import { SheetHeader, sheetBottomInset } from './SheetDialog'

/** 账户选项图标：品牌标 / 自定义 logo / 色块缩写三级回退 */
@Component
export struct AccountOptionIcon {
  @Prop account: CreditAccount = new CreditAccount()
  @Prop theme: ThemeColors = new ThemeColors()
  @State iconFailed: boolean = false

  private hasLogoUrl(): boolean {
    if (this.iconFailed) {
      return false
    }
    if (this.account.icon_url && this.account.icon_url.length > 0) {
      return true
    }
    return PlatformService.getLogoUrlForName(this.account.name).length > 0
  }

  private resolveLogoUrl(): string {
    if (this.account.icon_url && this.account.icon_url.length > 0) {
      return this.account.icon_url
    }
    return PlatformService.getLogoUrlForName(this.account.name)
  }

  private useCardFace(): boolean {
    if (this.iconFailed) {
      return false
    }
    return this.account.icon_url !== undefined && this.account.icon_url.length > 0
  }

  private avatarColor(): string {
    const visual = PlatformService.getBrandVisual(this.account.name)
    if (visual.matchedKey.length > 0 && visual.color.length > 0) {
      return visual.color
    }
    if (this.account.color && this.account.color.length > 0) {
      return this.account.color
    }
    return visual.color
  }

  build() {
    Stack() {
      Column() {
        Text(PlatformService.getBrandVisual(this.account.name).mark)
          .fontSize(PlatformService.getBrandVisual(this.account.name).mark.length > 1 ? 11 : 14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.onColorBlock())
      }
      .width(MotionTokens.listLogoSize)
      .height(MotionTokens.listLogoSize)
      .borderRadius(MotionTokens.listLogoRadius)
      .backgroundColor(this.avatarColor())
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      if (this.hasLogoUrl()) {
        LogoImage({
          theme: this.theme,
          url: this.resolveLogoUrl(),
          logoSize: MotionTokens.listLogoSize,
          radius: MotionTokens.listLogoRadius,
          remoteExact: true,
          remotePrefix: this.useCardFace() ? 'card_face_' : 'icon_net_',
          onError: () => {
            this.iconFailed = true
          }
        })
      }
    }
    .width(MotionTokens.listLogoSize)
    .height(MotionTokens.listLogoSize)
  }
}

/**
 * 关联信用账户选择 Sheet（负债/订阅表单共用）。
 * 行文案由 labelFor 提供：负债页「(尾号)」、订阅页「尾号」格式不同，不在此统一。
 */
@Component
export struct AccountPickerSheet {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop accounts: CreditAccount[] = []
  @Prop selectedId: string = ''
  title: string = ''
  labelFor: (account: CreditAccount) => string = (account: CreditAccount): string => account.name
  onPick: (accountId: string) => void = () => {}
  onClose: () => void = () => {}

  @Builder
  pickRow(account: CreditAccount, showDivider: boolean) {
    Column() {
      Row() {
        AccountOptionIcon({ account: account, theme: this.theme })
          .margin({ right: 10 })
          .flexShrink(0)
        Text(this.labelFor(account))
          .fontSize(TypeScale.listPrimary)
          .fontWeight(account.id === this.selectedId ? FontWeight.Medium : FontWeight.Regular)
          .fontColor(this.theme.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        if (account.id === this.selectedId) {
          Image($r('app.media.ic_check'))
            .width(16)
            .height(16)
            .fillColor(this.theme.text)
            .objectFit(ImageFit.Contain)
            .flexShrink(0)
            .margin({ left: 8 })
        }
      }
      .width('100%')
      .height(48)
      .alignItems(VerticalAlign.Center)
      .padding({
        left: this.theme.spaceMd,
        right: this.theme.spaceMd
      })
      .backgroundColor(account.id === this.selectedId ? this.theme.chip : Color.Transparent)
      .onClick(() => {
        this.onPick(account.id)
      })

      if (showDivider) {
        Divider()
          .color(this.theme.borderSoft)
          .strokeWidth(0.5)
          .margin({ left: 66, right: this.theme.spaceMd })
      }
    }
    .width('100%')
  }

  build() {
    Column() {
      SheetHeader({
        theme: this.theme,
        title: this.title,
        onClose: () => {
          this.onClose()
        }
      })

      Scroll() {
        Column() {
          ForEach(this.accounts, (account: CreditAccount, index: number) => {
            this.pickRow(account, index < this.accounts.length - 1)
          }, (account: CreditAccount) => account.id)
        }
        .width('100%')
      }
      .width('100%')
      .constraintSize({ maxHeight: 336 })
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ bottom: sheetBottomInset() })
  }
}
