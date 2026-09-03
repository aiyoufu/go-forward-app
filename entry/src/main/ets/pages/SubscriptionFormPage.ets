import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { MotionHelper } from 'common'
import { ImmersiveTitleBar } from 'common'
import { Subscription, CreateSubscriptionInput, UpdateSubscriptionInput, SubscriptionCategory, BillingCycle } from 'common'
import { CurrencyCode, CurrencyService } from 'common'
import { SubscriptionService, ExchangeRateService } from 'service'
import { CreditAccountService } from 'service'
import { CreditAccount } from 'common'
import { UserService } from 'service'
import { Utils } from 'common'
import { PlatformService } from 'service'
import { Constants } from 'common'
import { WidgetUpdateService } from 'service'
import { AILiveDraftKeys, AILiveSubscriptionDraft } from 'service'
import { SheetDatePickerView, SheetDatePickerConfig, AccountOptionIcon, AccountPickerSheet } from 'components'
import { FormLogoHeader, FormFieldInput, FormFieldLabel, FormFieldDateField } from 'components'
import { AppStorageKeys } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { AppRouter } from 'common'
import { fetchEffectiveTheme } from './common/ThemeLoader'

@Component
export struct SubscriptionFormPage {
  @State theme: ThemeColors = ThemeManager.snapshot()
  @State isEdit: boolean = false
  @State subId: string = ''

  @State @Watch('onNameChange') name: string = ''
  @State amount: string = ''
  /** 录入币种；金额输入框内始终是原币金额 */
  @State currency: string = 'CNY'
  /** 1 原币 = ? 人民币；非人民币时用于折算，可手动改写 */
  @State exchangeRate: string = '1'
  @State rateLoading: boolean = false
  @State rateHint: string = ''

  @State iconUrl: string = ''
  @State iconFailed: boolean = false
  @State category: SubscriptionCategory = 'other'
  @State billingCycle: BillingCycle = 'monthly'
  @State startDate: string = Utils.todayString()
  @State endDate: string = ''
  @State nextBillingDate: string = Utils.todayString()
  @State note: string = ''
  @State reminderEnabled: boolean = true
  @State reminderDaysBefore: number = 3
  @State creditAccountId: string = ''
  @State accounts: CreditAccount[] = []
  @State showDatePicker: boolean = false
  @State showAccountPicker: boolean = false
  @State datePickerConfig: SheetDatePickerConfig = new SheetDatePickerConfig()
  private dateCallback: (date: string) => void = () => {}
  private pageScroller: Scroller = new Scroller()

  private categories: SubscriptionCategory[] = ['video', 'music', 'tools', 'learning', 'lifestyle', 'storage', 'fitness', 'programming', 'ai', 'other']
  private cycles: BillingCycle[] = ['weekly', 'biweekly', 'monthly', 'quarterly', 'semiannually', 'annually', 'once', 'once_weekly', 'once_quarterly', 'once_annually']

  @State isCategoryExpanded: boolean = false
  @State isCycleExpanded: boolean = false
  @State isCurrencyExpanded: boolean = false

  private checkExpansion(): void {
    this.isCategoryExpanded = false
    this.isCycleExpanded = false
    this.isCurrencyExpanded = false
  }

  private getCategoryRows(): string[][] {
    if (!this.isCategoryExpanded) {
      return [['video', 'music', 'tools', 'learning']]
    }
    return [
      ['video', 'music', 'tools', 'learning'],
      ['lifestyle', 'storage', 'fitness', 'programming'],
      ['ai', 'other', 'BLANK', 'BLANK']
    ]
  }

  private getCurrencyRows(): string[][] {
    const all = CurrencyService.getAllCurrencies().map((c: CurrencyCode) => c as string)
    if (!this.isCurrencyExpanded) {
      return [[all[0], all[1], all[2], all[3]]]
    }
    return [
      [all[0], all[1], all[2], all[3]],
      [all[4], all[5], 'BLANK', 'BLANK']
    ]
  }

  private getCycleRows(): string[][] {
    if (!this.isCycleExpanded) {
      return [['weekly', 'biweekly', 'monthly', 'quarterly']]
    }
    return [
      ['weekly', 'biweekly', 'monthly', 'quarterly'],
      ['semiannually', 'annually', 'once', 'once_weekly'],
      ['once_quarterly', 'once_annually', 'BLANK', 'BLANK']
    ]
  }

  aboutToAppear() {
    this.loadTheme()
    this.loadAccounts()
    const id = AppStorage.get<string>(AppStorageKeys.SELECTED_SUBSCRIPTION_ID) ?? ''
    if (id.length > 0) {
      this.isEdit = true
      this.subId = id
      this.loadSubscription(id)
    } else {
      this.applyAILiveDraft()
      this.checkExpansion()
    }
    AppStorage.delete('selectedSubscriptionId')
  }

  /** AI Live「修改」：创建态预填草稿后清除 */
  private applyAILiveDraft(): void {
    const raw = AppStorage.get<string>(AILiveDraftKeys.SUBSCRIPTION) ?? ''
    AppStorage.delete(AILiveDraftKeys.SUBSCRIPTION)
    const draft = AILiveSubscriptionDraft.decode(raw)
    if (!draft) {
      return
    }
    this.name = draft.name
    this.amount = draft.amount
    this.category = (draft.category as SubscriptionCategory) ?? 'other'
    this.billingCycle = (draft.billingCycle as BillingCycle) ?? 'monthly'
    if (draft.nextBillingDate.length > 0) {
      this.nextBillingDate = draft.nextBillingDate
    }
    if (draft.startDate.length > 0) {
      this.startDate = draft.startDate
    }
    this.endDate = draft.endDate
    this.note = draft.note
  }

  private async loadTheme(): Promise<void> {
    const storedLux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
    this.theme = await fetchEffectiveTheme(storedLux, AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false)
  }

  private async loadAccounts(): Promise<void> {
    this.accounts = await CreditAccountService.getCreditAccounts(UserService.getCurrentUserId())
  }

  private async loadSubscription(id: string): Promise<void> {
    const sub: Subscription | null = await SubscriptionService.getSubscriptionById(id)
    if (!sub) return
    this.name = sub.name
    // 外币记录回填原币金额与锁定汇率，避免二次折算
    this.currency = CurrencyService.normalize(sub.currency)
    if (CurrencyService.isBase(this.currency) || sub.original_amount_fen <= 0) {
      this.amount = Utils.fenToYuan(sub.amount).toString()
      this.exchangeRate = '1'
    } else {
      this.amount = Utils.fenToYuan(sub.original_amount_fen).toString()
      this.exchangeRate = (sub.locked_exchange_rate > 0 ? sub.locked_exchange_rate : 1).toString()
      this.rateHint = `1 ${this.currency} ≈ ${this.exchangeRate} CNY（录入时锁定）`
    }
    this.category = sub.category
    this.billingCycle = sub.billing_cycle
    this.startDate = sub.start_date
    this.endDate = sub.end_date
    this.nextBillingDate = sub.next_billing_date
    this.note = sub.note
    this.reminderEnabled = sub.reminder_enabled
    this.reminderDaysBefore = sub.reminder_days_before
    this.creditAccountId = sub.credit_account_id
    this.iconUrl = sub.icon_url || ''
    this.checkExpansion()
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
    const v = PlatformService.getBrandVisual(this.name)
    return v.color.length > 0 ? v.color : '#2F3336'
  }

  private mark(): string {
    const v = PlatformService.getBrandVisual(this.name)
    if (v.mark.length > 0) {
      return v.mark
    }
    const n = this.name || ''
    return n.length > 0 ? n.substring(0, 1) : '订'
  }

  /** 校验失败抖动：保存钮水平位移 */
  @State private shakeOffsetX: number = 0

  /** 切换币种：人民币直接归位，其余联网取汇率；失败则保留手填 */
  private async onCurrencyChange(code: string): Promise<void> {
    this.currency = code
    if (CurrencyService.isBase(code)) {
      this.exchangeRate = '1'
      this.rateHint = ''
      return
    }
    this.rateLoading = true
    this.rateHint = ''
    const rate = await ExchangeRateService.getRate(code as CurrencyCode, 'CNY')
    this.rateLoading = false
    if (rate) {
      this.exchangeRate = rate.rate.toFixed(4)
      this.rateHint = `1 ${code} ≈ ${rate.rate.toFixed(4)} CNY`
    } else {
      this.rateHint = '汇率获取失败，请手动填写'
    }
  }

  /** 折算后的人民币金额（元），service 内部再转分 */
  private baseAmountYuan(): number {
    const origin = Number(this.amount) || 0
    if (CurrencyService.isBase(this.currency)) {
      return origin
    }
    const rate = Number(this.exchangeRate) || 0
    return CurrencyService.toBaseFen(origin, rate) / 100
  }

  private validate(): string {
    if (this.name.trim().length === 0) {
      return '请输入订阅名称'
    }
    const amount = Number(this.amount)
    if (isNaN(amount) || amount < 0) {
      return '金额不能为负数'
    }
    if (!CurrencyService.isBase(this.currency)) {
      const rate = Number(this.exchangeRate)
      if (isNaN(rate) || rate <= 0) {
        return '请填写有效汇率'
      }
    }
    if (!/^\d{4}-\d{2}-\d{2}$/.test(this.nextBillingDate)) {
      return '下次扣费日格式应为 YYYY-MM-DD'
    }
    if (this.endDate.length > 0 && !/^\d{4}-\d{2}-\d{2}$/.test(this.endDate)) {
      return '结束日期格式应为 YYYY-MM-DD'
    }
    if (this.reminderEnabled && (this.reminderDaysBefore < 1 || this.reminderDaysBefore > 30)) {
      return '提前提醒天数应在 1-30 之间'
    }
    return ''
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

    const input = new CreateSubscriptionInput()
    input.name = this.name.trim()
    input.amount = this.baseAmountYuan()
    input.currency = CurrencyService.normalize(this.currency)
    input.original_amount_fen = Math.round((Number(this.amount) || 0) * 100)
    input.locked_exchange_rate = CurrencyService.isBase(this.currency) ? 1 : (Number(this.exchangeRate) || 1)
    input.category = this.category
    input.billing_cycle = this.billingCycle
    input.next_billing_date = this.nextBillingDate
    input.start_date = this.startDate
    input.end_date = this.endDate
    input.note = this.note
    input.reminder_enabled = this.reminderEnabled
    input.reminder_days_before = this.reminderDaysBefore
    input.credit_account_id = this.creditAccountId
    input.icon_url = this.iconUrl

    try {
      if (this.isEdit) {
        const updates = new UpdateSubscriptionInput()
        updates.name = input.name
        updates.amount = input.amount
        updates.category = input.category
        updates.billing_cycle = input.billing_cycle
        updates.next_billing_date = input.next_billing_date
        updates.start_date = input.start_date
        updates.end_date = input.end_date
        updates.note = input.note
        updates.reminder_enabled = input.reminder_enabled
        updates.reminder_days_before = input.reminder_days_before
        updates.credit_account_id = input.credit_account_id
        updates.icon_url = input.icon_url
        updates.currency = input.currency
        updates.original_amount_fen = input.original_amount_fen
        updates.locked_exchange_rate = input.locked_exchange_rate
        await SubscriptionService.updateSubscription(this.subId, updates)
      } else {
        await SubscriptionService.createSubscription(input)
      }
      await WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      Constants.notifyListRefresh()
      AppToast.show(this.isEdit ? ErrorMessages.UPDATE_OK : ErrorMessages.CREATE_OK, 1500)
      AppRouter.pop()
    } catch (_e) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 3000)
    }
  }

  private pickDate(initial: string, onPick: (d: string) => void): void {
    const d = initial.length > 0 ? new Date(initial) : new Date()
    this.datePickerConfig = new SheetDatePickerConfig('选择日期', d)
    this.dateCallback = onPick
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showDatePicker = true
    })
  }

  private accountLabel(account: CreditAccount): string {
    return account.name + (account.last_four ? ' 尾号' + account.last_four : '')
  }

  private selectedAccountLabel(): string {
    const account = this.accounts.find((a) => a.id === this.creditAccountId)
    return account ? this.accountLabel(account) : '未关联'
  }

  private selectedAccount(): CreditAccount {
    const account = this.accounts.find((a) => a.id === this.creditAccountId)
    return account !== undefined ? account : new CreditAccount()
  }

  private selectAccount(accountId: string): void {
    this.creditAccountId = accountId
    this.showAccountPicker = false
  }

  private openAccountPicker(): void {
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showAccountPicker = true
    })
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
          Column({ space: 12 }) {
          // 订阅图标预览（真实图标/首字母+预设色，点击更换）
          FormLogoHeader({
            theme: this.theme,
            displayName: this.name,
            titleText: '订阅名称',
            hintText: '点击图标可重新上传或修改',
            markChar: this.mark(),
            markColor: this.avatarColor(),
            displayUrl: this.getIconUrl(),
            showEditBadge: false,
            bucketTable: Constants.TABLE_SUBSCRIPTIONS,
            iconUrl: $iconUrl,
            iconFailed: $iconFailed
          })

          FormFieldInput({ label: '订阅名称', value: $name, theme: this.theme })

          LabelWithToggle({
            text: '币种',
            theme: this.theme,
            expanded: this.isCurrencyExpanded,
            onToggle: () => { this.isCurrencyExpanded = !this.isCurrencyExpanded }
          })
          Column({ space: 8 }) {
            ForEach(this.getCurrencyRows(), (row: string[], rowIndex: number) => {
              Row({ space: 8 }) {
                ForEach(row, (item: string, itemIndex: number) => {
                  if (item === 'BLANK') {
                    Blank()
                      .layoutWeight(1)
                  } else {
                    Text(CurrencyService.getSymbol(item) + ' ' + item)
                      .fontSize(TypeScale.bodySm)
                      .fontColor(this.currency === item ? this.theme.onPrimary as string : this.theme.text2 as string)
                      .padding({ top: 8, bottom: 8 })
                      .backgroundColor(this.currency === item ? this.theme.primary : this.theme.fieldBackground())
                      .borderRadius(this.theme.radiusSm)
                      .border({
                        width: this.theme.fieldBorderWidth(),
                        color: this.currency === item ? this.theme.primary : this.theme.fieldBorder()
                      })
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => {
                        this.onCurrencyChange(item)
                      })
                  }
                }, (item: string, itemIndex: number) => `cur_item_${rowIndex}_${itemIndex}_${item}`)
              }
              .width('100%')
            }, (row: string[], idx: number) => `cur_row_${idx}`)
          }
          .width('100%')
          .margin({ bottom: 12 })

          FormFieldInput({
            label: '金额 (' + CurrencyService.getSymbol(this.currency) + ')',
            value: $amount,
            theme: this.theme,
            inputType: InputType.NUMBER_DECIMAL
          })

          if (!CurrencyService.isBase(this.currency)) {
            FormFieldInput({
              label: '汇率 (1 ' + this.currency + ' = ? CNY)',
              value: $exchangeRate,
              theme: this.theme,
              inputType: InputType.NUMBER_DECIMAL
            })
            Row({ space: 6 }) {
              if (this.rateLoading) {
                LoadingProgress()
                  .width(TypeScale.caption)
                  .height(TypeScale.caption)
                  .color(this.theme.text3)
                Text('正在获取汇率…')
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
              } else {
                Text(this.rateHint.length > 0
                  ? this.rateHint
                  : '折合 ¥' + this.baseAmountYuan().toFixed(2))
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
              }
            }
            .width('100%')
            .padding({ left: 4, bottom: 4 })

            if (!this.rateLoading && this.rateHint.length > 0) {
              Text('折合 ¥' + this.baseAmountYuan().toFixed(2))
                .fontSize(TypeScale.caption)
                .fontColor(this.theme.text3)
                .width('100%')
                .padding({ left: 4, bottom: 4 })
            }
          }

          LabelWithToggle({
            text: '分类',
            theme: this.theme,
            expanded: this.isCategoryExpanded,
            onToggle: () => { this.isCategoryExpanded = !this.isCategoryExpanded }
          })
          Column({ space: 8 }) {
            ForEach(this.getCategoryRows(), (row: string[], rowIndex: number) => {
              Row({ space: 8 }) {
                ForEach(row, (item: string, itemIndex: number) => {
                  if (item === 'BLANK') {
                    Blank()
                      .layoutWeight(1)
                  } else {
                    Text(PlatformService.getCategoryInfo(item).label)
                      .fontSize(TypeScale.bodySm)
                      .fontColor(this.category === item ? this.theme.onPrimary as string : this.theme.text2 as string)
                      .padding({ top: 8, bottom: 8 })
                      .backgroundColor(this.category === item ? this.theme.primary : this.theme.fieldBackground())
                      .borderRadius(this.theme.radiusSm)
                      .border({
                        width: this.theme.fieldBorderWidth(),
                        color: this.category === item ? this.theme.primary : this.theme.fieldBorder()
                      })
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.category = item as SubscriptionCategory)
                  }
                }, (item: string, itemIndex: number) => `cat_item_${rowIndex}_${itemIndex}_${item}`)
              }
              .width('100%')
            }, (row: string[], idx: number) => `cat_row_${idx}`)
          }
          .width('100%')
          .margin({ bottom: 4 })

          LabelWithToggle({
            text: '计费周期',
            theme: this.theme,
            expanded: this.isCycleExpanded,
            onToggle: () => { this.isCycleExpanded = !this.isCycleExpanded }
          })
          Column({ space: 8 }) {
            ForEach(this.getCycleRows(), (row: string[], rowIndex: number) => {
              Row({ space: 8 }) {
                ForEach(row, (item: string, itemIndex: number) => {
                  if (item === 'BLANK') {
                    Blank()
                      .layoutWeight(1)
                  } else {
                    Text(PlatformService.getBillingCycleInfo(item).label)
                      .fontSize(TypeScale.bodySm)
                      .fontColor(this.billingCycle === item ? this.theme.onPrimary as string : this.theme.text2 as string)
                      .padding({ top: 8, bottom: 8 })
                      .backgroundColor(this.billingCycle === item ? this.theme.primary : this.theme.fieldBackground())
                      .borderRadius(this.theme.radiusSm)
                      .border({
                        width: this.theme.fieldBorderWidth(),
                        color: this.billingCycle === item ? this.theme.primary : this.theme.fieldBorder()
                      })
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => this.billingCycle = item as BillingCycle)
                  }
                }, (item: string, itemIndex: number) => `cycle_item_${rowIndex}_${itemIndex}_${item}`)
              }
              .width('100%')
            }, (row: string[], idx: number) => `cycle_row_${idx}`)
          }
          .width('100%')
          .margin({ bottom: 4 })

          FormFieldLabel({ label: '开始日期', theme: this.theme })
          FormFieldDateField({ value: this.startDate, theme: this.theme, onPick: () => this.pickDate(this.startDate, (d) => this.startDate = d) })

          FormFieldLabel({ label: '结束日期', theme: this.theme })
          FormFieldDateField({
            value: this.endDate,
            placeholder: '可选，留空=无限期',
            theme: this.theme,
            onPick: () => this.pickDate(this.endDate.length > 0 ? this.endDate : Utils.todayString(), (d) => this.endDate = d)
          })

          FormFieldLabel({ label: '下次扣费日', theme: this.theme })
          FormFieldDateField({ value: this.nextBillingDate, theme: this.theme, onPick: () => this.pickDate(this.nextBillingDate, (d) => this.nextBillingDate = d) })

          Row() {
            Text('到期提醒')
              .fontSize(TypeScale.body)
              .fontColor(this.theme.text2)
              .layoutWeight(1)
            Toggle({ type: ToggleType.Switch, isOn: this.reminderEnabled })
              .selectedColor(this.theme.controlSelected())
              .switchPointColor(this.theme.controlKnob())
              .onChange((on: boolean) => this.reminderEnabled = on)
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.theme.fieldBackground())
          .borderRadius(this.theme.radiusSm)
          .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })

          if (this.reminderEnabled) {
            Row() {
              Text('提前提醒天数')
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text2)
                .layoutWeight(1)
              TextInput({ text: this.reminderDaysBefore.toString() })
                .type(InputType.Number)
                .width(80)
                .height(36)
                .fontColor(this.theme.text)
                .backgroundColor(this.theme.fieldBackground())
                .borderRadius(this.theme.radiusLg)
                .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
                .onChange((v) => this.reminderDaysBefore = Math.max(1, Math.min(30, Number(v) || 3)))
            }
            .width('100%')
            .padding(12)
            .backgroundColor(this.theme.fieldBackground())
            .borderRadius(this.theme.radiusSm)
            .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
          }

          if (this.accounts.length > 0) {
            Column() {
            Row() {
              Text('扣款账户')
                .fontSize(TypeScale.bodySm)
                .fontColor(this.theme.text2)
                .layoutWeight(1)
              if (this.creditAccountId.length > 0) {
                Text('去关联')
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
                  .padding({ left: this.theme.spaceXs, top: 4, bottom: 4 })
                  .onClick(() => {
                    this.selectAccount('')
                  })
              }
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
            .margin({ top: 4 })
            Row() {
              if (this.creditAccountId.length > 0) {
                AccountOptionIcon({ account: this.selectedAccount(), theme: this.theme })
                  .margin({ right: 10 })
              }
              Text(this.selectedAccountLabel())
                .fontSize(TypeScale.control)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.text)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .layoutWeight(1)
              Image($r('app.media.ic_chevron_down'))
                .width(16)
                .height(16)
                .fillColor(this.theme.text3)
                .objectFit(ImageFit.Contain)
                .flexShrink(0)
            }
            .width('100%')
            .height(44)
            .padding({ left: 14, right: 14 })
            .backgroundColor(this.theme.fieldBackground())
            .borderRadius(this.theme.radiusLg)
            .border({
              width: this.theme.fieldBorderWidth(),
              color: this.theme.fieldBorder()
            })
            .onClick(() => {
              this.openAccountPicker()
            })
            }
            .width('100%')
            .bindSheet($$this.showAccountPicker, this.accountPickerBuilder, {
              height: SheetSize.FIT_CONTENT,
              dragBar: true,
              radius: LengthMetrics.vp(this.theme.sheetRadius),
              showClose: false,
              backgroundColor: this.theme.sheetBackground() as string,
              blurStyle: BlurStyle.NONE,
              maskColor: this.theme.sheetMaskColor(),
              shadow: this.theme.sheetShadowOptions(),
              onDisappear: () => {
                this.showAccountPicker = false
              }
            })
          }

          FormFieldInput({ label: '备注', value: $note, theme: this.theme, placeholder: '备注（可选）' })
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
      .bindSheet($$this.showDatePicker, this.datePickerBuilder, {
        height: SheetSize.FIT_CONTENT,
        dragBar: true,
        radius: LengthMetrics.vp(this.theme.sheetRadius),
        showClose: false,
        backgroundColor: this.theme.sheetBackground() as string,
        blurStyle: BlurStyle.NONE,
        maskColor: this.theme.sheetMaskColor(),
        shadow: this.theme.sheetShadowOptions(),
        onDisappear: () => {
          this.showDatePicker = false
        }
      })
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
          mainTitle: this.isEdit ? '编辑订阅' : '添加订阅'
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

  @Builder
  datePickerBuilder() {
    SheetDatePickerView({
      theme: this.theme,
      config: this.datePickerConfig,
      onConfirm: (date: Date) => {
        this.showDatePicker = false
        this.dateCallback(Utils.formatDate(date))
      },
      onCancel: () => {
        this.showDatePicker = false
      }
    })
  }

  @Builder
  accountPickerBuilder() {
    AccountPickerSheet({
      theme: this.theme,
      accounts: this.accounts,
      selectedId: this.creditAccountId,
      title: '扣款账户',
      labelFor: (account: CreditAccount): string => this.accountLabel(account),
      onPick: (accountId: string): void => {
        this.selectAccount(accountId)
      },
      onClose: () => {
        this.showAccountPicker = false
      }
    })
  }
}

@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
struct LabelWithToggle {
  @Prop text: string = ''
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop expanded: boolean = false
  onToggle: () => void = () => {}

  build() {
    Row() {
      Text(this.text)
        .fontSize(TypeScale.bodySm)
        .fontColor(this.theme.text2)
        .layoutWeight(1)
      Text(this.expanded ? '收起 ▲' : '展开 ▼')
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text3 as string)
        .padding({ left: 12, top: 4, bottom: 4 })
        .onClick(() => this.onToggle())
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 4 })
  }
}
