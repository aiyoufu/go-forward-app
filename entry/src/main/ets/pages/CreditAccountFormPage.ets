import { ThemeColors, ThemeManager, TypeScale } from 'common'
import { MotionHelper } from 'common'
import { ImmersiveTitleBar } from 'common'
import { CreditAccount, CreateCreditAccountInput, UpdateCreditAccountInput } from 'common'
import { CreditAccountService } from 'service'
import { WidgetUpdateService } from 'service'
import { SettingsService } from 'service'
import { UserService } from 'service'
import { Constants } from 'common'
import { PlatformService } from 'service'
import { FormLogoHeader, FormFieldInput } from 'components'
import { common } from '@kit.AbilityKit'
import { AppStorageKeys } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { AILiveCreditAccountDraft } from 'service'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { AppRouter } from 'common'
import { fetchEffectiveTheme } from './common/ThemeLoader'

@Component
export struct CreditAccountFormPage {
  @State theme: ThemeColors = ThemeManager.snapshot()
  @State isEdit: boolean = false
  @State accountId: string = ''

  @State @Watch('onNameChange') name: string = ''
  @State lastFour: string = ''

  @State iconUrl: string = ''
  @State iconFailed: boolean = false
  @State color: string = '#18181B'
  @State expiryDate: string = ''
  @State cvv: string = ''
  @State billDay: string = '1'
  @State paymentDay: string = '10'
  @State creditLimit: string = ''
  @State annualFeeSwipes: string = ''
  @State manualSwipes: string = ''
  @State gracePeriodDays: string = ''
  @State interestFreeDays: string = ''
  private pageScroller: Scroller = new Scroller()

  aboutToAppear() {
    this.loadTheme()
    const id = AppStorage.get<string>(AppStorageKeys.SELECTED_CREDIT_ACCOUNT_ID) ?? ''
    if (id.length > 0) {
      this.isEdit = true
      this.accountId = id
      this.loadAccount(id)
    }
    AppStorage.delete('selectedCreditAccountId')
    // AI Live 草稿预填
    const draftRaw = AppStorage.get<string>(AppStorageKeys.AI_LIVE_CREDIT_ACCOUNT_DRAFT) ?? ''
    if (draftRaw.length > 0) {
      AppStorage.delete(AppStorageKeys.AI_LIVE_CREDIT_ACCOUNT_DRAFT)
      const draft = AILiveCreditAccountDraft.decode(draftRaw)
      if (draft !== null) {
        this.name = draft.name
        this.lastFour = draft.lastFour
        this.billDay = draft.billDay
        this.paymentDay = draft.paymentDay
        this.creditLimit = draft.creditLimit
        this.expiryDate = draft.expiryDate
        this.annualFeeSwipes = draft.annualFeeSwipes
        this.gracePeriodDays = draft.gracePeriodDays
        this.interestFreeDays = draft.interestFreeDays
      }
    }
  }

  private async loadTheme(): Promise<void> {
    const storedLux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
    this.theme = await fetchEffectiveTheme(storedLux, AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false)
  }

  private async loadAccount(id: string): Promise<void> {
    const account: CreditAccount | null = await CreditAccountService.getCreditAccountById(id)
    if (!account) return
    this.name = account.name
    this.lastFour = account.last_four
    this.color = account.color
    this.expiryDate = account.expiry_date
    this.cvv = account.cvv
    this.billDay = account.bill_day.toString()
    this.paymentDay = account.payment_day.toString()
    this.creditLimit = account.credit_limit.toString()
    this.annualFeeSwipes = account.annual_fee_required_swipes > 0 ? account.annual_fee_required_swipes.toString() : ''
    this.manualSwipes = account.annual_fee_manual_swipes > 0 ? account.annual_fee_manual_swipes.toString() : ''
    this.gracePeriodDays = account.grace_period_days > 0 ? account.grace_period_days.toString() : ''
    this.interestFreeDays = account.interest_free_days > 0 ? account.interest_free_days.toString() : ''
    this.iconUrl = account.icon_url || ''
  }

  private onNameChange(): void {
    this.iconFailed = false
  }

  private getIconUrl(): string {
    if (this.iconUrl && this.iconUrl.length > 0) {
      return this.iconUrl
    }
    return PlatformService.getLogoUrlForName(this.name)
  }

  private avatarColor(): string {
    const visual = PlatformService.getBrandVisual(this.name)
    if (visual.matchedKey.length > 0 && visual.color.length > 0) {
      return visual.color
    }
    if (this.color && this.color.length > 0) {
      return this.color
    }
    return visual.color.length > 0 ? visual.color : '#18181B'
  }

  private mark(): string {
    const v = PlatformService.getBrandVisual(this.name)
    if (v.mark.length > 0) {
      return v.mark
    }
    const n = this.name || ''
    return n.length > 0 ? n.substring(0, 1) : '户'
  }

  /** 校验失败抖动：保存钮水平位移 */
  @State private shakeOffsetX: number = 0

  private validate(): string {
    if (this.name.trim().length === 0) {
      return '请输入账户名称'
    }
    const billDay = Number(this.billDay)
    const paymentDay = Number(this.paymentDay)
    if (isNaN(billDay) || billDay < 1 || billDay > 31) {
      return '出单日需在 1-31 之间'
    }
    if (isNaN(paymentDay) || paymentDay < 1 || paymentDay > 31) {
      return '还款日需在 1-31 之间'
    }
    const creditLimit = Number(this.creditLimit)
    if (isNaN(creditLimit) || creditLimit < 0) {
      return '额度不能为负数'
    }
    if (this.lastFour.length > 0 && !/^\d{4}$/.test(this.lastFour)) {
      return '尾号应为 4 位数字'
    }
    if (this.expiryDate.length > 0 && !/^\d{2}\/\d{2}$/.test(this.expiryDate)) {
      return '到期日格式应为 MM/YY'
    }
    if (this.cvv.length > 0 && !/^\d{3,4}$/.test(this.cvv)) {
      return '安全码应为 3-4 位数字'
    }
    if (this.gracePeriodDays.trim().length > 0) {
      const grace = Number(this.gracePeriodDays)
      if (isNaN(grace) || grace < 0 || grace > 31) {
        return '宽限期天数应在 0-31 之间'
      }
    }
    if (this.interestFreeDays.trim().length > 0) {
      const ifd = Number(this.interestFreeDays)
      if (isNaN(ifd) || ifd < 0 || ifd > 120) {
        return '免息期应在 0-120 之间'
      }
    }
    return ''
  }

  private formatExpiry(v: string): string {
    const digits = v.replace(/\D/g, '').slice(0, 4)
    if (digits.length <= 2) {
      return digits
    }
    return digits.slice(0, 2) + '/' + digits.slice(2)
  }

  private async save(): Promise<void> {
    const error = this.validate()
    if (error.length > 0) {
      AppToast.show(error, 2000)
      MotionHelper.shake(this.getUIContext(), (x: number) => {
        this.shakeOffsetX = x
      })
      return
    }

    const input = new CreateCreditAccountInput()
    input.name = this.name.trim()
    input.last_four = this.lastFour
    input.color = this.color
    input.expiry_date = this.expiryDate
    input.cvv = this.cvv
    input.bill_day = Number(this.billDay) || 1
    input.payment_day = Number(this.paymentDay) || 1
    input.credit_limit = Number(this.creditLimit) || 0
    input.annual_fee_required_swipes = Number(this.annualFeeSwipes) || 0
    input.annual_fee_manual_swipes = Number(this.manualSwipes) || 0
    input.grace_period_days = Number(this.gracePeriodDays) || 0
    input.interest_free_days = Number(this.interestFreeDays) || 0
    input.icon_url = this.iconUrl

    try {
      if (this.isEdit) {
        const updates = new UpdateCreditAccountInput()
        updates.name = input.name
        updates.last_four = input.last_four
        updates.color = input.color
        updates.expiry_date = input.expiry_date
        updates.cvv = input.cvv
        updates.bill_day = input.bill_day
        updates.payment_day = input.payment_day
        updates.credit_limit = input.credit_limit
        updates.annual_fee_required_swipes = input.annual_fee_required_swipes
        updates.annual_fee_manual_swipes = input.annual_fee_manual_swipes
        updates.grace_period_days = input.grace_period_days
        updates.interest_free_days = input.interest_free_days
        updates.icon_url = input.icon_url
        await CreditAccountService.updateCreditAccount(this.accountId, updates)
      } else {
        await CreditAccountService.createCreditAccount(input)
      }
      Constants.notifyListRefresh()
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      if (ctx) {
        WidgetUpdateService.updateAll(ctx)
      }
      AppToast.show(this.isEdit ? ErrorMessages.UPDATE_OK : ErrorMessages.CREATE_OK, 1500)
      AppRouter.pop()
    } catch (_e) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 3000)
    }
  }

  private goBack(): void {
    AppRouter.pop()
  }

  /** 页转场位移/透明度（MotionHelper.navPageTransition 驱动） */
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  build() {
    NavDestination() {
    HdsNavigation() {
      Column() {
        Scroll(this.pageScroller) {
          Column({ space: 16 }) {
          // 账户头像预览与更换（真实图标/首字母+预设色，点击更换）
          FormLogoHeader({
            theme: this.theme,
            displayName: this.name,
            titleText: '账户名称',
            hintText: '点击图标可重新上传或修改',
            markChar: this.mark(),
            markColor: this.avatarColor(),
            displayUrl: this.getIconUrl(),
            pickerCatalog: 'card',
            showEditBadge: false,
            bucketTable: Constants.TABLE_CREDIT_ACCOUNTS,
            iconUrl: $iconUrl,
            iconFailed: $iconFailed
          })

          // ── 分组一：基本信息 ──
          Column({ space: 12 }) {
            FormFieldInput({ label: '账户名称', value: $name, theme: this.theme, placeholder: '例如：招商银行经典白' })
            FormFieldInput({ label: '信用额度 (万元)', value: $creditLimit, theme: this.theme, inputType: InputType.NUMBER_DECIMAL, placeholder: '可选' })
          }
          .width('100%')

          // ── 分组二：卡片属性 ──
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              FormFieldInput({ label: '尾号后四位', value: $lastFour, theme: this.theme, inputType: InputType.Number, placeholder: '如 8888 (可选)' })
                .layoutWeight(1)

              Column({ space: 6 }) {
                Text('到期日 (MM/YY)')
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.theme.text2)
                  .alignSelf(ItemAlign.Start)
                TextInput({ text: this.expiryDate, placeholder: '如 06/30 (可选)' })
                  .type(InputType.Normal)
                  .fontColor(this.theme.text)
                  .placeholderColor(this.theme.text3)
                  .backgroundColor(this.theme.fieldBackground())
                  .borderRadius(this.theme.radiusLg)
                  .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
                  .height(44)
                  .onChange((v) => this.expiryDate = this.formatExpiry(v))
              }
              .layoutWeight(1)
              .width('100%')
            }
            .width('100%')

            FormFieldInput({ label: '安全码 CVV', value: $cvv, theme: this.theme, inputType: InputType.Number, placeholder: '如 123 (可选)' })
          }
          .width('100%')

          // ── 分组三：单据与还款 ──
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              FormFieldInput({ label: '出单日', value: $billDay, theme: this.theme, inputType: InputType.Number, placeholder: '1' })
                .layoutWeight(1)
              FormFieldInput({ label: '还款日', value: $paymentDay, theme: this.theme, inputType: InputType.Number, placeholder: '10' })
                .layoutWeight(1)
            }
            .width('100%')

            FormFieldInput({ label: '宽限期天数', value: $gracePeriodDays, theme: this.theme, inputType: InputType.Number, placeholder: '可选，一般为 1-3 天' })
            FormFieldInput({ label: '免息期 (天)', value: $interestFreeDays, theme: this.theme, inputType: InputType.Number, placeholder: '可选，一般为 20-56 天' })
          }
          .width('100%')

          // ── 分组四：年费考核 ──
          Column({ space: 12 }) {
            Row({ space: 10 }) {
              FormFieldInput({ label: '免年费刷卡次数', value: $annualFeeSwipes, theme: this.theme, inputType: InputType.Number, placeholder: '可选' })
                .layoutWeight(1)
              FormFieldInput({ label: '已刷卡次数', value: $manualSwipes, theme: this.theme, inputType: InputType.Number, placeholder: '可选' })
                .layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
        }
          .padding({ left: 16, right: 16, top: 12, bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .clip(false)
        .width('100%')

        Button('保存')
          .width('90%')
          .height(48)
          .fontSize(TypeScale.listPrimarySm)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.theme.ctaBackground())
          .fontColor(this.theme.ctaForeground())
          .borderRadius(this.theme.radiusSm)
          .margin({ bottom: 24 })
          .translate({ x: this.shakeOffsetX })
          .onClick(() => this.save())
      }
      .width('100%')
      .height('100%')
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: ImmersiveTitleBar.material()
      },
      content: {
        title: {
          mainTitle: this.isEdit ? '编辑账户' : '添加账户'
        },
        backIcon: {
          label: '返回',
          action: () => {
            this.goBack()
          }
        }
      }
    })
    // 宽屏/折叠屏默认 Auto→Split 会把内容挤到半屏，二级页强制 Stack 全宽
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.pageScroller])
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .backgroundColor(this.theme.background)
    .translate({ x: this.navTransX })
    .opacity(this.navAlpha)
    .customTransition((op: NavigationOperation, isEnter: boolean) => MotionHelper.navPageTransition(op, isEnter,
      (x: number, alpha: number) => {
        this.navTransX = x
        this.navAlpha = alpha
      }))
  }
}
