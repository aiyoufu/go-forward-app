import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { MotionHelper } from 'common'
import { ImmersiveTitleBar } from 'common'
import { Debt, CreateDebtInput, UpdateDebtInput, RepaymentMethod, DebtType } from 'common'
import { CurrencyCode, CurrencyService } from 'common'
import { CreditAccount } from 'common'
import { DebtService, ExchangeRateService } from 'service'
import { CreditAccountService } from 'service'
import { CalculationService, CustomScheduleItem } from 'service'
import { SettingsService } from 'service'
import { UserService } from 'service'
import { Utils } from 'common'
import { LiveViewService } from 'service'
import { WidgetUpdateService } from 'service'
import { PlatformService } from 'service'
import { Constants } from 'common'
import { DebtFormFields, DebtFormValidator } from 'service'
import { DebtFormPreview, DebtFormPreviewInput, DebtPreviewItem } from 'service'
import { FormFieldDateField, FormFieldInput, FormFieldLabel, FormLogoHeader } from 'components'
import { AILiveDebtDraft, AILiveDraftKeys } from 'service'
import { SheetDatePickerView, SheetDatePickerConfig, AccountOptionIcon, AccountPickerSheet } from 'components'
import { common } from '@kit.AbilityKit'
import { AppStorageKeys } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { AppRouter } from 'common'
import {
  totalInterestFromPeriod,
  fixedInterestMonthly,
  resolveFirstPaymentDate as resolveFirstPayDate,
  resolvePaymentDay as resolvePayDay,
  annualRateHintText
} from './common/DebtFormMath'
import { fetchEffectiveTheme } from './common/ThemeLoader'

@Component
export struct DebtFormPage {
  @State theme: ThemeColors = ThemeManager.snapshot()
  @State isEdit: boolean = false
  @State debtId: string = ''
  @State showDatePicker: boolean = false
  @State datePickerConfig: SheetDatePickerConfig = new SheetDatePickerConfig()
  private dateCallback: (date: string) => void = () => {}
  private pageScroller: Scroller = new Scroller()

  @State iconUrl: string = ''
  @State iconFailed: boolean = false

  // 表单字段
  @State platform: string = ''
  @State currentBalance: string = ''
  /** 录入币种；金额输入框内均为原币金额 */
  @State currency: string = 'CNY'
  /** 1 原币 = ? 人民币；非人民币时用于折算，可手动改写 */
  @State exchangeRate: string = '1'
  @State rateLoading: boolean = false
  @State rateHint: string = ''
  @State monthlyPayment: string = ''
  @State totalPeriods: string = ''
  @State remainingPeriods: string = ''
  @State annualRate: string = '0'
  @State paymentDay: string = ''
  @State startDate: string = ''
  @State repaymentDate: string = ''
  @State note: string = ''
  @State creditAccountId: string = ''
  @State isInstallment: boolean = false
  @State hasManuallyToggled: boolean = false
  @State repaymentMethod: RepaymentMethod = 'equal_payment'
  @State totalInterest: string = ''
  @State interestConfigMode: 'total' | 'period' = 'period'
  @State periodInterest: string = ''
  @State customSchedule: CustomScheduleItem[] = []
  @State customInputBuffer: Record<string, string> = {}
  private previewCache: DebtPreviewItem[] = []
  private previewCacheKey: string = ''

  @State creditAccounts: CreditAccount[] = []
  @State showAccountPicker: boolean = false
  @State saving: boolean = false
  @State isCurrencyExpanded: boolean = false

  aboutToAppear() {
    this.loadTheme()
    this.startDate = Utils.todayString()
    this.repaymentDate = Utils.addMonths(Utils.todayString(), 1)
    this.loadCreditAccounts()
    const id = AppStorage.get<string>(AppStorageKeys.SELECTED_DEBT_ID) ?? ''
    if (id.length > 0) {
      this.isEdit = true
      this.debtId = id
      this.loadDebt(id)
    } else {
      this.applyAILiveDraft()
    }
    AppStorage.delete('selectedDebtId')
  }

  /** AI Live「修改」：创建态预填草稿后清除 */
  private applyAILiveDraft(): void {
    const raw = AppStorage.get<string>(AILiveDraftKeys.DEBT) ?? ''
    AppStorage.delete(AILiveDraftKeys.DEBT)
    const draft = AILiveDebtDraft.decode(raw)
    if (!draft) {
      return
    }
    this.platform = draft.platform
    this.currentBalance = draft.currentBalance
    this.monthlyPayment = draft.monthlyPayment
    this.totalPeriods = draft.totalPeriods
    this.remainingPeriods = draft.remainingPeriods
    this.annualRate = draft.annualRate
    this.paymentDay = draft.paymentDay
    if (draft.startDate.length > 0) {
      this.startDate = draft.startDate
    }
    if (draft.repaymentDate.length > 0) {
      this.repaymentDate = draft.repaymentDate
    }
    this.isInstallment = draft.debtType === 'installment' ||
      (Number(draft.totalPeriods) > 1) ||
      (Number(draft.remainingPeriods) > 1) ||
      (Number(draft.monthlyPayment) > 0 && Number(draft.totalPeriods) > 1)
    this.pendingCreditAccountHint = draft.creditAccountHint.length > 0 ?
      draft.creditAccountHint : draft.platform
    // 完整还款计划（含已还期）：note 内 custom_schedule
    this.applyScheduleFromDraftNote(draft.note)
  }

  /**
   * 从 AI 草稿 note 恢复自定义分期表（含已还期）。
   * 兼容 { custom_schedule, text }；金额为分。
   */
  private applyScheduleFromDraftNote(noteRaw: string): void {
    this.note = noteRaw
    if (noteRaw.length === 0 || noteRaw.charAt(0) !== '{') {
      return
    }
    const schedule = CalculationService.parseCustomSchedule(noteRaw)
    if (schedule === null || schedule.length === 0) {
      return
    }
    this.customSchedule = schedule
    this.repaymentMethod = 'custom'
    this.isInstallment = true
    // 有完整表时，总期数以表为准，避免只显示剩余期
    if (schedule.length > 0) {
      this.totalPeriods = `${schedule.length}`
    }
    // 备注只给用户自己填：JSON 里 text 为空则清空，不写技术说明
    try {
      const obj = JSON.parse(noteRaw) as Record<string, Object>
      if (obj['text'] !== undefined && obj['text'] !== null) {
        const t = `${obj['text']}`.trim()
        // 过滤历史技术文案
        if (t.length === 0 || t.indexOf('OCR') >= 0 || t.indexOf('本地') >= 0 ||
          t.indexOf('规则') >= 0) {
          this.note = ''
        } else {
          this.note = t
        }
      } else {
        this.note = ''
      }
    } catch (_e) {
      this.note = ''
    }
    // 预填：金额 = 本金，利息 = 服务费（例第 3 期 110.88 + 3.33 = 114.21）
    let interestSumYuan = 0
    let principalSumYuan = 0
    for (let i = 0; i < schedule.length; i++) {
      const s = schedule[i]
      const p = s.period_number
      const principalYuan = s.principal / 100
      const interestYuan = s.interest / 100
      this.customInputBuffer['' + p + '_principal'] = principalYuan.toFixed(2)
      this.customInputBuffer['' + p + '_interest'] = interestYuan.toFixed(2)
      this.customInputBuffer['' + p + '_total'] = (s.total / 100).toFixed(2)
      interestSumYuan += interestYuan
      principalSumYuan += principalYuan
    }
    if (interestSumYuan > 0) {
      this.totalInterest = interestSumYuan.toFixed(2)
    }
    // 分期金额 = 各期本金之和（与截图「分期本金」一致），勿用剩余待还
    if (principalSumYuan > 0) {
      this.currentBalance = principalSumYuan.toFixed(2)
    }
    // 月供 / 还款日：优先 OCR 表内 date + paid
    let firstUnpaidIdx = -1
    for (let i = 0; i < schedule.length; i++) {
      if (!schedule[i].paid) {
        firstUnpaidIdx = i
        break
      }
    }
    if (firstUnpaidIdx < 0) {
      const remainN = Number(this.remainingPeriods)
      const totalN = schedule.length
      firstUnpaidIdx = Math.max(0, totalN - remainN)
    }
    if (firstUnpaidIdx >= 0 && firstUnpaidIdx < schedule.length && schedule[firstUnpaidIdx].total > 0) {
      this.monthlyPayment = (schedule[firstUnpaidIdx].total / 100).toFixed(2)
      if (schedule[firstUnpaidIdx].date.length >= 8) {
        this.repaymentDate = schedule[firstUnpaidIdx].date
      }
    } else if (schedule.length > 0 && schedule[0].total > 0) {
      this.monthlyPayment = (schedule[0].total / 100).toFixed(2)
    }
    // 首期还款日（计划第 1 期），例：2026-07-08
    if (schedule.length > 0 && schedule[0].date.length >= 8) {
      this.startDate = schedule[0].date
    }
  }

  /** AI 草稿带来的关联账户名，等 creditAccounts 加载后再匹配 */
  private pendingCreditAccountHint: string = ''

  private matchCreditAccountFromHint(): void {
    const hint = this.pendingCreditAccountHint.replace(/\s+/g, '')
    // 循环前缓存状态数组，避免循环内反复读 @State（hp-arkui-no-state-var-access-in-loop）
    const accounts = this.creditAccounts
    if (hint.length === 0 || accounts.length === 0) {
      return
    }
    // 精确 / 互相包含
    for (let i = 0; i < accounts.length; i++) {
      const name = accounts[i].name.replace(/\s+/g, '')
      if (name === hint || name.indexOf(hint) >= 0 || hint.indexOf(name) >= 0) {
        this.creditAccountId = accounts[i].id
        return
      }
    }
    // 关键词：美团/月付/花呗/白条
    const keys: string[] = ['美团', '月付', '花呗', '白条', '京东', '招行', '中信']
    for (let k = 0; k < keys.length; k++) {
      if (hint.indexOf(keys[k]) < 0) {
        continue
      }
      for (let i = 0; i < accounts.length; i++) {
        if (accounts[i].name.indexOf(keys[k]) >= 0) {
          this.creditAccountId = accounts[i].id
          return
        }
      }
    }
  }

  private async loadTheme(): Promise<void> {
    const storedLux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
    this.theme = await fetchEffectiveTheme(storedLux, AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false)
  }

  private async loadCreditAccounts(): Promise<void> {
    this.creditAccounts = await CreditAccountService.getCreditAccounts(UserService.getCurrentUserId())
    // AI 草稿关联账户：账户列表就绪后再匹配
    if (!this.isEdit && this.creditAccountId.length === 0) {
      this.matchCreditAccountFromHint()
    }
  }

  private async loadDebt(id: string): Promise<void> {
    const debt: Debt | null = await DebtService.getDebtById(id)
    if (!debt) return
    this.platform = debt.platform
    // 外币记录用锁定汇率反算回原币口径，避免再次保存时二次折算
    this.currency = CurrencyService.normalize(debt.currency)
    const backRate: number = (!CurrencyService.isBase(this.currency) && debt.locked_exchange_rate > 0)
      ? debt.locked_exchange_rate
      : 1
    this.exchangeRate = backRate.toString()
    if (backRate !== 1) {
      this.rateHint = `1 ${this.currency} ≈ ${backRate} CNY（录入时锁定）`
    }
    this.currentBalance = debt.original_principal_fen > 0
      ? Utils.fenToYuan(debt.original_principal_fen).toString()
      : (Utils.fenToYuan(debt.principal) / backRate).toString()
    this.monthlyPayment = (Utils.fenToYuan(debt.monthly_payment) / backRate).toFixed(2)
    this.totalPeriods = debt.total_periods.toString()
    this.remainingPeriods = debt.remaining_periods.toString()
    this.annualRate = (debt.annual_rate_bp / 100).toString()
    this.paymentDay = debt.payment_day.toString()
    this.startDate = debt.start_date.length > 0 ? debt.start_date : debt.next_payment_date
    this.repaymentDate = debt.next_payment_date
    this.note = CalculationService.getCleanNoteText(debt.note)
    this.creditAccountId = debt.credit_account_id
    // 分期判断以 debt_type / 总期数为准，避免剩最后一期时被误判为一次性
    this.isInstallment = debt.debt_type === 'installment' || debt.total_periods > 1
    this.repaymentMethod = debt.repayment_method
    this.totalInterest = (Utils.fenToYuan(debt.total_interest) / backRate).toString()
    // 云端常漏 total_interest：用 月供×期数 - 本金 反推服务费，避免预览走年化 PMT
    if ((Number(this.totalInterest) || 0) <= 0 && (Number(this.monthlyPayment) || 0) > 0) {
      const periodsN = Number(this.totalPeriods) || 0
      const principalN = Number(this.currentBalance) || 0
      if (periodsN >= 2 && principalN > 0) {
        const inferred = Number(this.monthlyPayment) * periodsN - principalN
        if (inferred > 0.005) {
          this.totalInterest = inferred.toFixed(2)
        }
      }
    }
    this.interestConfigMode = (Number(this.totalInterest) || 0) > 0 ? 'total' : 'period'
    this.periodInterest = (Number(this.totalPeriods) || 0) > 0
      ? ((Number(this.totalInterest) || 0) / Number(this.totalPeriods)).toFixed(2)
      : ''
    // 编辑态：若已存币种位于折叠区（JPY/HKD），自动展开
    const currencyIdx = CurrencyService.getAllCurrencies().indexOf(this.currency as CurrencyCode)
    this.isCurrencyExpanded = currencyIdx >= 4
    const savedSchedule = CalculationService.parseCustomSchedule(debt.note)
    if (savedSchedule) {
      // 自定义分期表按同一锁定汇率还原为原币口径（分）
      this.customSchedule = backRate === 1 ? savedSchedule : savedSchedule.map(item => {
        const ci = new CustomScheduleItem()
        ci.period_number = item.period_number
        ci.principal = item.principal / backRate
        ci.interest = item.interest / backRate
        ci.total = item.total / backRate
        return ci
      })
      // 预填金额/利息输入缓冲，已还/未还同一套框
      for (let i = 0; i < this.customSchedule.length; i++) {
        const s = this.customSchedule[i]
        const p = s.period_number
        this.customInputBuffer['' + p + '_principal'] = (s.principal / 100).toFixed(2)
        this.customInputBuffer['' + p + '_interest'] = (s.interest / 100).toFixed(2)
        this.customInputBuffer['' + p + '_total'] = (s.total / 100).toFixed(2)
      }
    }
    this.iconUrl = debt.icon_url || ''
  }

  private getIconUrl(): string {
    if (this.iconUrl && this.iconUrl.length > 0) {
      return this.iconUrl
    }
    if (this.creditAccountId && this.creditAccountId.length > 0) {
      const acc = this.creditAccounts.find(a => a.id === this.creditAccountId)
      if (acc) {
        if (acc.icon_url && acc.icon_url.length > 0) {
          return acc.icon_url
        }
        // 关联账户无自定义图标时，按账户名取预设图标，避免随后修改名称导致图标被改变
        return PlatformService.getLogoUrlForName(acc.name)
      }
    }
    const matched = this.creditAccounts.find(a => {
      const an = (a.name || '').toLowerCase()
      const pn = this.platform.toLowerCase()
      return a.icon_url && a.icon_url.length > 0 && an.length > 0 && pn.length > 0 && (an === pn || an.includes(pn) || pn.includes(an))
    })
    if (matched && matched.icon_url) {
      return matched.icon_url
    }
    return PlatformService.getLogoUrlForName(this.platform)
  }

  // 图标下方提示文案：已自定义图标 / 已关联账户接管 / 待关联时预告接管
  private iconHintText(): string {
    if (this.iconUrl && this.iconUrl.length > 0) {
      return '点击图标可重新上传或修改'
    }
    if (this.creditAccountId && this.creditAccountId.length > 0) {
      return '图标已由关联账户接管，点击可手动替换'
    }
    return '关联信用账户后图标将由账户接管，也可点击修改'
  }

  /** 已关联信用账户且账户有还款日（>0）时，表单不再展示「每月还款日」 */
  private hasLinkedAccountPaymentDay(): boolean {
    if (this.creditAccountId.length === 0) {
      return false
    }
    const acc = this.creditAccounts.find(a => a.id === this.creditAccountId)
    return acc !== undefined && acc.payment_day > 0
  }

  /** 写入用的每月还款日：优先关联账户，否则表单输入 */
  private resolvePaymentDay(): number {
    return resolvePayDay(this.creditAccounts, this.creditAccountId, this.paymentDay)
  }

  /**
   * 自定义分期：月供取预览表首个未还期 total（原币元 → 人民币元）。
   * 表单 monthlyPayment 已在草稿预填，作回退。
   */
  private resolveCustomMonthlyYuan(): number {
    const schedule = this.getPreviewSchedule()
    for (let i = 0; i < schedule.length; i++) {
      if (schedule[i].status !== 'paid' && schedule[i].total > 0) {
        return this.toBaseYuan(schedule[i].total / 100)
      }
    }
    const fromField = Number(this.monthlyPayment) || 0
    if (fromField > 0) {
      return this.toBaseYuan(fromField)
    }
    // 最后回退：有计划则取首期，否则本金/总期
    if (schedule.length > 0 && schedule[0].total > 0) {
      return this.toBaseYuan(schedule[0].total / 100)
    }
    const totalP = Math.max(1, Number(this.totalPeriods) || 1)
    const origin = Number(this.currentBalance) || 0
    return this.toBaseYuan(origin / totalP)
  }

  /**
   * 入库 current_balance（剩余待还，人民币元）。
   * 表单「分期金额」是本金，不能整笔写进余额。
   */
  private resolveRemainingBalanceYuan(principalBaseYuan: number): number {
    if (!this.isInstallment) {
      return principalBaseYuan
    }
    const schedule = this.getPreviewSchedule()
    if (this.customSchedule.length > 0 && schedule.length > 0) {
      let sumFen = 0
      let hasUnpaid = false
      for (let i = 0; i < schedule.length; i++) {
        if (schedule[i].status !== 'paid') {
          sumFen += schedule[i].total
          hasUnpaid = true
        }
      }
      if (hasUnpaid) {
        // 预览 total 为原币分 → 元 → 折人民币
        return this.toBaseYuan(sumFen / 100)
      }
    }
    const totalP = Number(this.totalPeriods) || 0
    const remainP = Number(this.remainingPeriods) || 0
    if (totalP > 0 && remainP >= 0 && remainP < totalP) {
      const monthly = this.toBaseYuan(Number(this.monthlyPayment) || 0)
      if (monthly > 0 && remainP > 0) {
        return Math.round(monthly * remainP * 100) / 100
      }
      return Math.round(principalBaseYuan * remainP / totalP * 100) / 100
    }
    return principalBaseYuan
  }

  private openAccountPicker(): void {
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showAccountPicker = true
    })
  }

  private selectAccount(accountId: string): void {
    this.onCreditAccountChange(accountId)
    this.showAccountPicker = false
  }

  // 信用账户选择联动
  private onCreditAccountChange(id: string): void {
    this.creditAccountId = id
    if (id.length > 0) {
      const acc = this.creditAccounts.find(a => a.id === id)
      if (acc) {
        // 关联账户时只同步平台名与还款日，不触发自动分期检测
        this.onPlatformChange(acc.name, true)
        if (acc.payment_day > 0) {
          this.paymentDay = acc.payment_day.toString()
        }
      }
    }
  }

  // 平台名称变化时自动检测预设
  private onPlatformChange(name: string, fromAccount: boolean = false): void {
    this.platform = name
    this.iconFailed = false
    // 已关联信用账户时，无论是否改名均跳过自动分期检测，
    // 避免选择关联账户后修改名称导致负债类型被自动切换到「分期」
    const linkedAcc = this.creditAccounts.find(a => a.id === this.creditAccountId)
    const isFromLinkedAccount = fromAccount || (linkedAcc !== undefined)
    if (!isFromLinkedAccount && !this.isEdit && !this.hasManuallyToggled && name.trim().length > 0) {
      const preset = PlatformService.getPlatformPreset(name)
      if (preset && preset.color !== '#A1A1AA') {
        this.isInstallment = preset.type === 'installment'
      }
    }
  }

  private handlePeriodInterestChange(val: string): void {
    this.periodInterest = val
    const interestNum = Number(val)
    const periodsNum = Number(this.totalPeriods)
    const balanceNum = Number(this.currentBalance)
    if (!isNaN(interestNum) && !isNaN(periodsNum) && periodsNum > 0) {
      this.totalInterest = totalInterestFromPeriod(interestNum, periodsNum)
      if (this.repaymentMethod === 'fixed_interest' && !isNaN(balanceNum) && balanceNum > 0) {
        this.monthlyPayment = fixedInterestMonthly(balanceNum, periodsNum, interestNum)
      }
    }
    this.recalculateAnnualRate()
  }

  private handleTotalPeriodsChange(val: string): void {
    this.totalPeriods = val
    const periodsNum = Number(val)
    if (this.interestConfigMode === 'period' && this.repaymentMethod === 'fixed_interest') {
      const interestNum = Number(this.periodInterest)
      const balanceNum = Number(this.currentBalance)
      if (!isNaN(interestNum) && !isNaN(periodsNum) && periodsNum > 0) {
        this.totalInterest = totalInterestFromPeriod(interestNum, periodsNum)
        if (!isNaN(balanceNum) && balanceNum > 0) {
          this.monthlyPayment = fixedInterestMonthly(balanceNum, periodsNum, interestNum)
        }
      }
    }
    this.recalculateAnnualRate()
  }

  private handleCurrentBalanceChange(val: string): void {
    this.currentBalance = val
    const balanceNum = Number(val)
    // 仅等本等息按「本金/期数+每期利息」回写月供；等额本息必须保留用户/银行月供（如 58.31）
    if (this.interestConfigMode === 'period' && this.repaymentMethod === 'fixed_interest') {
      const interestNum = Number(this.periodInterest)
      const periodsNum = Number(this.totalPeriods)
      if (!isNaN(interestNum) && !isNaN(periodsNum) && periodsNum > 0 && !isNaN(balanceNum) && balanceNum > 0) {
        this.monthlyPayment = fixedInterestMonthly(balanceNum, periodsNum, interestNum)
      }
    }
    this.recalculateAnnualRate()
  }

  private handleMonthlyPaymentChange(val: string): void {
    this.monthlyPayment = val
    this.recalculateAnnualRate()
  }

  private handleTotalInterestChange(val: string): void {
    this.totalInterest = val
    this.recalculateAnnualRate()
  }

  /**
   * 自动反推年利率（仅分期）。
   * - equal_payment：本金+月供+期数 → 二分法求月利率。
   * - fixed_interest：总利息+本金+期数 → 总利息/本金/年数。
   * - custom：保持用户输入，不自动覆盖。
   * principal 取 currentBalance（新建态即原始本金；编辑态为剩余本金，仅作估算参考）。
   */
  private recalculateAnnualRate(): void {
    if (!this.isInstallment) {
      return
    }
    if (this.repaymentMethod === 'custom') {
      return
    }
    const principal = Number(this.currentBalance) || 0
    const monthlyPaymentNum = Number(this.monthlyPayment) || 0
    const totalPeriodsNum = Number(this.totalPeriods) || 0
    const totalInterestNum = Number(this.totalInterest) || 0
    if (principal <= 0 || totalPeriodsNum <= 0) {
      return
    }
    const rateBp = CalculationService.calculateAnnualRateBp(
      principal,
      monthlyPaymentNum,
      totalPeriodsNum,
      this.repaymentMethod,
      totalInterestNum
    )
    if (rateBp > 0) {
      const percent = rateBp / 100
      this.annualRate = percent.toFixed(2)
    }
  }

  /** 年利率说明：参考常见范围 + 自动计算结果提示 */
  private annualRateHint(): string {
    return annualRateHintText(
      Number(this.currentBalance) || 0,
      Number(this.monthlyPayment) || 0,
      Number(this.totalPeriods) || 0,
      Number(this.totalInterest) || 0,
      this.repaymentMethod
    )
  }

  private handleConfigModeChange(mode: 'total' | 'period'): void {
    this.interestConfigMode = mode
    if (mode === 'period') {
      const totalInterestNum = Number(this.totalInterest)
      const periodsNum = Number(this.totalPeriods)
      const balanceNum = Number(this.currentBalance)
      if (!isNaN(totalInterestNum) && !isNaN(periodsNum) && periodsNum > 0) {
        const initial = (totalInterestNum / periodsNum).toFixed(2)
        this.periodInterest = initial
        if (this.repaymentMethod === 'fixed_interest' && !isNaN(balanceNum) && balanceNum > 0) {
          this.monthlyPayment = fixedInterestMonthly(balanceNum, periodsNum, Number(initial))
        }
      }
    }
  }

  /**
   * 关联信用账户时按账户账单日/还款日推算首期应还日。
   * periodShift：中途录入时向后的期数偏移（预览取 0，保存取推算值）。
   * 无可推算条件（无账户、账单表已含显式还款日、开始日与还款日相同）时返回 ''。
   */
  private linkedAccountFirstDueDate(periodShift: number = 0): string {
    if (this.creditAccountId.length === 0) {
      return ''
    }
    for (let i = 0; i < this.customSchedule.length; i++) {
      if (this.customSchedule[i].date.length >= 8) {
        return ''
      }
    }
    if (this.startDate.length === 0 || this.startDate === this.repaymentDate) {
      return ''
    }
    const acc = this.creditAccounts.find(a => a.id === this.creditAccountId)
    if (acc === undefined || acc.payment_day <= 0) {
      return ''
    }
    return CalculationService.firstDueDateForAccount(this.startDate, acc.bill_day, acc.payment_day,
      periodShift)
  }

  /** 中途录入时首期应还日向后偏移的期数（=总期 - 剩余 - 1） */
  private currentPeriodShift(): number {
    const total = Number(this.totalPeriods) || 0
    const remain = Number(this.remainingPeriods) || 0
    if (total <= 0 || remain <= 0) {
      return 0
    }
    return Math.max(0, total - remain - 1)
  }

  private resolveFirstPaymentDate(): string {
    const fromAccount = this.linkedAccountFirstDueDate()
    if (fromAccount.length > 0) {
      return fromAccount
    }
    return resolveFirstPayDate(this.startDate, this.repaymentDate, this.totalPeriods, this.remainingPeriods)
  }

  private previewStamp(): string {
    let custom = ''
    for (let i = 0; i < this.customSchedule.length; i++) {
      const it = this.customSchedule[i]
      custom += it.period_number + ':' + it.principal + ':' + it.interest + ':' + it.total + ':' +
        (it.paid ? '1' : '0') + ';'
    }
    return this.currentBalance + '|' + this.monthlyPayment + '|' + this.totalInterest + '|' +
      this.totalPeriods + '|' + this.remainingPeriods + '|' + this.annualRate + '|' +
      this.repaymentDate + '|' + this.startDate + '|' + (this.isInstallment ? '1' : '0') + '|' +
      this.repaymentMethod + '|' + this.creditAccountId + '|' + custom
  }

  /** 生成预览还款计划（同输入复用缓存，避免 build 里多次摊还） */
  private getPreviewSchedule(): DebtPreviewItem[] {
    const key = this.previewStamp()
    if (key === this.previewCacheKey) {
      return this.previewCache
    }
    const input = new DebtFormPreviewInput()
    input.currentBalanceYuan = this.currentBalance
    input.monthlyPaymentYuan = this.monthlyPayment
    input.totalInterestYuan = this.totalInterest
    input.totalPeriods = this.totalPeriods
    input.remainingPeriods = this.remainingPeriods
    input.annualRate = this.annualRate
    input.repaymentDate = this.repaymentDate
    input.firstPaymentDate = this.resolveFirstPaymentDate()
    input.isInstallment = this.isInstallment
    input.repaymentMethod = this.repaymentMethod
    input.customSchedule = this.customSchedule
    this.previewCache = DebtFormPreview.buildSchedule(input)
    this.previewCacheKey = key
    return this.previewCache
  }

  private handleCustomPeriodChange(periodNumber: number, field: 'total' | 'interest' | 'principal',
    valueYuanStr: string): void {
    const bufferKey = '' + periodNumber + '_' + field
    const prevYuanStr = this.customInputBuffer[bufferKey] ?? ''
    if (prevYuanStr.length > 1 && valueYuanStr.length === 0) {
      return
    }
    const valueYuan = parseFloat(valueYuanStr) || 0
    const valueFen = Utils.yuanToFen(valueYuan)
    this.customInputBuffer[bufferKey] = valueYuanStr

    const preview = this.getPreviewSchedule()
    const currentItemInPreview = preview.find(x => x.period_number === periodNumber)
    const fallbackP = currentItemInPreview ? currentItemInPreview.principal : 0
    const fallbackI = currentItemInPreview ? currentItemInPreview.interest : 0
    const fallbackT = currentItemInPreview ? currentItemInPreview.total : 0

    const existingIdx = this.customSchedule.findIndex(x => x.period_number === periodNumber)
    const currentItem = existingIdx >= 0
      ? this.customSchedule[existingIdx]
      : new CustomScheduleItem()
    currentItem.period_number = periodNumber
    currentItem.principal = fallbackP
    currentItem.interest = fallbackI
    currentItem.total = fallbackT

    if (field === 'interest') {
      currentItem.interest = valueFen
      currentItem.total = currentItem.principal + currentItem.interest
    } else if (field === 'principal') {
      // 金额 = 本金（图中 110.88）；总额 = 本金 + 利息
      currentItem.principal = valueFen
      currentItem.total = currentItem.principal + currentItem.interest
    } else {
      currentItem.total = valueFen
      currentItem.principal = Math.max(0, currentItem.total - currentItem.interest)
    }

    if (existingIdx >= 0) {
      this.customSchedule[existingIdx] = currentItem
    } else {
      this.customSchedule.push(currentItem)
    }
    this.customSchedule = this.customSchedule.slice()
  }

  private pickDate(callback: (date: string) => void, initial: string): void {
    const d = initial.length > 0 ? new Date(initial) : new Date()
    this.datePickerConfig = new SheetDatePickerConfig('选择日期', d)
    this.dateCallback = callback
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showDatePicker = true
    })
  }

  /** 校验失败抖动：保存钮水平位移 */
  @State private shakeOffsetX: number = 0

  private validate(): string {
    const f = new DebtFormFields()
    f.platform = this.platform
    f.currentBalance = this.currentBalance
    f.isInstallment = this.isInstallment
    f.creditAccountId = this.creditAccountId
    f.paymentDay = this.paymentDay
    f.repaymentMethod = this.repaymentMethod
    f.monthlyPayment = this.monthlyPayment
    f.remainingPeriods = this.remainingPeriods
    f.totalPeriods = this.totalPeriods
    f.repaymentDate = this.repaymentDate
    const baseError = DebtFormValidator.validate(f)
    if (baseError.length > 0) {
      return baseError
    }
    if (!CurrencyService.isBase(this.currency)) {
      const rate = Number(this.exchangeRate)
      if (isNaN(rate) || rate <= 0) {
        return '请填写有效汇率'
      }
    }
    return ''
  }

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

  /** 币种选择网格：折叠显示前 4 + 切换钮，展开补齐 JPY/HKD */
  private getCurrencyRows(): string[][] {
    const all = CurrencyService.getAllCurrencies().map((c: CurrencyCode) => c as string)
    if (!this.isCurrencyExpanded) {
      return [[all[0], all[1], all[2], all[3], 'TOGGLE']]
    }
    return [
      [all[0], all[1], all[2], all[3], 'TOGGLE'],
      [all[4], all[5], 'BLANK', 'BLANK', 'BLANK']
    ]
  }

  /** 当前生效汇率：人民币恒为 1 */
  private effectiveRate(): number {
    if (CurrencyService.isBase(this.currency)) {
      return 1
    }
    const rate = Number(this.exchangeRate)
    return Number.isFinite(rate) && rate > 0 ? rate : 1
  }

  /** 原币金额（元）→ 人民币金额（元），保留两位小数 */
  private toBaseYuan(originYuan: number): number {
    if (CurrencyService.isBase(this.currency)) {
      return originYuan
    }
    return CurrencyService.toBaseFen(originYuan, this.effectiveRate()) / 100
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

    this.saving = true
    // 表单「分期金额」= 本金口径（原币）；剩余待还另算，不可等同
    const originPrincipal = Number(this.currentBalance) || 0
    const principalBaseYuan = this.toBaseYuan(originPrincipal)
    let finalPayment = principalBaseYuan
    let finalPeriods = 1
    let finalPaymentDay = 10
    let finalNextPaymentDate: string | undefined = undefined

    if (this.isInstallment) {
      finalPaymentDay = this.resolvePaymentDay()
      if (this.repaymentMethod === 'custom') {
        finalPayment = this.resolveCustomMonthlyYuan()
      } else {
        finalPayment = this.toBaseYuan(Number(this.monthlyPayment) || 0)
      }
      finalPeriods = Number(this.remainingPeriods)
      const derivedInstallment = this.linkedAccountFirstDueDate(this.currentPeriodShift())
      finalNextPaymentDate = derivedInstallment.length > 0 ? derivedInstallment : this.repaymentDate
    } else {
      if (this.creditAccountId.length === 0) {
        const parts = this.repaymentDate.split('-')
        finalPaymentDay = parts.length === 3 ? Number(parts[2]) : 10
        finalNextPaymentDate = this.repaymentDate
      } else {
        finalPaymentDay = this.resolvePaymentDay()
        const acc = this.creditAccounts.find(a => a.id === this.creditAccountId)
        if (acc !== undefined && acc.payment_day > 0) {
          const derivedOnce = this.linkedAccountFirstDueDate()
          finalNextPaymentDate = derivedOnce.length > 0
            ? derivedOnce
            : Utils.nextDateForMonthlyDay(acc.payment_day)
        }
      }
    }

    const calculatedDebtType: DebtType = this.isInstallment
      ? 'installment'
      : ((): DebtType => {
        const preset = PlatformService.getPlatformPreset(this.platform)
        return preset && preset.type !== 'installment' ? preset.type : 'other'
      })()

    let finalNote = this.note.trim()
    if (this.isInstallment && this.customSchedule.length > 0) {
      const customScheduleData = this.getPreviewSchedule().map(item => {
        const ci = new CustomScheduleItem()
        ci.period_number = item.period_number
        // 预览表金额为「分」；toBaseYuan 在 CNY 下等价原值写入 note（与既有 custom_schedule 分口径一致）
        ci.principal = this.toBaseYuan(item.principal)
        ci.interest = this.toBaseYuan(item.interest)
        ci.total = this.toBaseYuan(item.total)
        // 保留识别/预览中的还款日与已还状态
        ci.date = item.date
        ci.paid = item.status === 'paid'
        return ci
      })
      finalNote = JSON.stringify({ custom_schedule: customScheduleData, text: this.note.trim() })
    }

    // 剩余待还：自定义表用未还期 total 之和；否则按本金×剩余/总期粗算
    const remainingBaseYuan = this.resolveRemainingBalanceYuan(principalBaseYuan)

    try {
      if (this.isEdit) {
        const updates = new UpdateDebtInput()
        updates.platform = this.platform.trim()
        updates.debt_type = calculatedDebtType
        updates.principal = principalBaseYuan
        updates.current_balance = remainingBaseYuan
        updates.monthly_payment = finalPayment
        updates.total_periods = Number(this.totalPeriods) || 1
        updates.remaining_periods = finalPeriods
        updates.repayment_method = this.repaymentMethod
        updates.total_interest = this.toBaseYuan(Number(this.totalInterest) || 0)
        updates.annual_rate_bp = Math.round((Number(this.annualRate) || 0) * 100)
        updates.payment_day = finalPaymentDay
        updates.start_date = this.startDate
        updates.next_payment_date = finalNextPaymentDate ?? this.startDate
        updates.note = finalNote
        updates.credit_account_id = this.creditAccountId
        updates.icon_url = this.iconUrl
        updates.currency = CurrencyService.normalize(this.currency)
        updates.original_principal_fen = Math.round(originPrincipal * 100)
        updates.locked_exchange_rate = this.effectiveRate()
        await DebtService.updateDebt(this.debtId, updates)
      } else {
        const input = new CreateDebtInput()
        input.platform = this.platform.trim()
        input.debt_type = calculatedDebtType
        input.principal = principalBaseYuan
        input.current_balance = remainingBaseYuan
        input.monthly_payment = finalPayment
        input.total_periods = Number(this.totalPeriods) || 1
        input.remaining_periods = finalPeriods
        input.repayment_method = this.repaymentMethod
        input.total_interest = this.toBaseYuan(Number(this.totalInterest) || 0)
        input.annual_rate_bp = Math.round((Number(this.annualRate) || 0) * 100)
        input.payment_day = finalPaymentDay
        input.start_date = this.startDate
        input.next_payment_date = finalNextPaymentDate ?? this.startDate
        input.note = finalNote
        input.credit_account_id = this.creditAccountId
        input.is_auto_payment = false
        input.icon_url = this.iconUrl
        input.currency = CurrencyService.normalize(this.currency)
        input.original_principal_fen = Math.round(originPrincipal * 100)
        input.locked_exchange_rate = this.effectiveRate()
        await DebtService.createDebt(input)
      }
      LiveViewService.refresh()
      WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      Constants.notifyListRefresh()
      AppToast.show(this.isEdit ? ErrorMessages.UPDATE_OK : ErrorMessages.CREATE_OK, 1500)
      this.saving = false
      AppRouter.pop()
    } catch (err) {
      this.saving = false
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
    // 官方：列表标题栏适配光感（HdsNavigation + systemMaterialEffect + GRADIENT_BLUR）
    HdsNavigation() {
      Column() {
        Scroll(this.pageScroller) {
          Column({ space: 14 }) {
          // 平台图标预览（真实图标/首字母+预设色，点击更换）
          // bindSheet 挂在 FormLogoHeader 独立宿主上：与账户选择链式挂在 HdsNavigation 上会闪关
          FormLogoHeader({
            theme: this.theme,
            displayName: this.platform,
            titleText: '平台名称',
            hintText: this.iconHintText(),
            markChar: this.platform.length > 0 ? this.platform.charAt(0) : '',
            markColor: this.platform.length > 0 ? PlatformService.getPlatformPreset(this.platform).color : '#2F3336',
            displayUrl: this.getIconUrl(),
            showEditBadge: false,
            bucketTable: Constants.TABLE_DEBTS,
            iconUrl: $iconUrl,
            iconFailed: $iconFailed
          })

          // 名称
          FormFieldInput({
            label: '名称',
            value: $platform,
            placeholder: '例如：花呗、招商信用卡',
            theme: this.theme,
            onChange: (v: string) => this.onPlatformChange(v)
          })

          // 负债类型切换
          Row() {
            Text('负债类型')
              .fontSize(TypeScale.bodySm)
              .fontColor(this.theme.text2)
              .layoutWeight(1)

            Text('一次性')
              .fontSize(TypeScale.bodySm)
              .fontColor(!this.isInstallment ? this.theme.text : this.theme.text3)
              .margin({ right: 8 })

            Toggle({ type: ToggleType.Switch, isOn: this.isInstallment })
              .selectedColor(this.theme.controlSelected())
              .switchPointColor(this.theme.controlKnob())
              .onChange((val: boolean) => {
                this.isInstallment = val
                this.hasManuallyToggled = true
              })

            Text('分期')
              .fontSize(TypeScale.bodySm)
              .fontColor(this.isInstallment ? this.theme.text : this.theme.text3)
              .margin({ left: 8 })
          }
          .width('100%')
          .padding(14)
          .backgroundColor(this.theme.fieldBackground())
          .borderRadius(this.theme.radiusSm)
          .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })

          // 还款方式（仅分期）
          if (this.isInstallment) {
            FormFieldLabel({ label: '还款方式', theme: this.theme })
            Row({ space: 8 }) {
              ForEach(['equal_payment', 'fixed_interest', 'custom'] as RepaymentMethod[], (m: RepaymentMethod) => {
                Text(this.methodLabel(m))
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.repaymentMethod === m ? this.theme.onPrimary : this.theme.text2)
                  .padding({ top: 8, bottom: 8, left: 14, right: 14 })
                  .backgroundColor(this.repaymentMethod === m ? this.theme.primary : this.theme.fieldBackground())
                  .borderRadius(this.theme.radiusSm)
                  .border({
                    width: this.theme.fieldBorderWidth(),
                    color: this.repaymentMethod === m ? this.theme.primary : this.theme.fieldBorder()
                  })
                  .onClick(() => this.repaymentMethod = m)
              })
            }
            .width('100%')
          }

          // 币种（选中态与还款方式一致：primary 底 + onPrimary 字，深色可辨）
          FormFieldLabel({ label: '币种', theme: this.theme })
          Column({ space: 8 }) {
            ForEach(this.getCurrencyRows(), (row: string[], rowIndex: number) => {
              Row({ space: 8 }) {
                ForEach(row, (item: string, itemIndex: number) => {
                  if (item === 'TOGGLE') {
                    Text(this.isCurrencyExpanded ? '收起 ▲' : '展开 ▼')
                      .fontSize(TypeScale.bodySm)
                      .fontColor(this.theme.text3)
                      .padding({ top: 8, bottom: 8 })
                      .backgroundColor(this.theme.fieldBackground())
                      .borderRadius(this.theme.radiusSm)
                      .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
                      .layoutWeight(1)
                      .textAlign(TextAlign.Center)
                      .onClick(() => {
                        this.isCurrencyExpanded = !this.isCurrencyExpanded
                      })
                  } else if (item === 'BLANK') {
                    Blank()
                      .layoutWeight(1)
                  } else {
                    Text(CurrencyService.getSymbol(item) + ' ' + item)
                      .fontSize(TypeScale.bodySm)
                      .fontColor(this.currency === item ? this.theme.onPrimary : this.theme.text2)
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

          // 汇率（非人民币时显示）
          if (!CurrencyService.isBase(this.currency)) {
            FormFieldInput({
              label: '汇率 (1 ' + this.currency + ' = ? CNY)',
              value: $exchangeRate,
              placeholder: '0.0000',
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
                Text(this.rateHint.length > 0 ? this.rateHint : '按当前汇率折算入库')
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
              }
            }
            .width('100%')
            .padding({ left: 4, bottom: 8 })
          }

          // 分期金额
          FormFieldInput({
            label: (this.isInstallment ? '分期金额 (' : '负债金额 (')
              + CurrencyService.getSymbol(this.currency) + ')',
            value: $currentBalance,
            placeholder: '0.00',
            theme: this.theme,
            inputType: InputType.NUMBER_DECIMAL,
            onChange: (v: string) => this.handleCurrentBalanceChange(v)
          })

          // 折合人民币提示
          if (!CurrencyService.isBase(this.currency) && (Number(this.currentBalance) || 0) > 0) {
            Text('折合 ¥' + this.toBaseYuan(Number(this.currentBalance) || 0).toFixed(2))
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
              .width('100%')
              .padding({ left: 4, bottom: 8 })
          }

          // 每月应还（分期且非自定义时显示）
          if (this.isInstallment && this.repaymentMethod !== 'custom') {
            FormFieldInput({
              label: '每月应还 (' + CurrencyService.getSymbol(this.currency) + ')',
              value: $monthlyPayment,
              placeholder: '0.00',
              theme: this.theme,
              inputType: InputType.NUMBER_DECIMAL,
              onChange: (v: string) => this.handleMonthlyPaymentChange(v)
            })
          }

          // 总利息（仅等本等息时显示）
          if (this.isInstallment && this.repaymentMethod === 'fixed_interest') {
            FormFieldLabel({ label: '利息配置方式', theme: this.theme })
            Row({ space: 8 }) {
              Text('按每期利息')
                .fontSize(TypeScale.bodySm)
                .fontColor(this.interestConfigMode === 'period' ? this.theme.onPrimary : this.theme.text2)
                .padding({ top: 8, bottom: 8, left: 14, right: 14 })
                .backgroundColor(this.interestConfigMode === 'period' ? this.theme.primary : this.theme.surface2)
                .borderRadius(this.theme.radiusSm)
                .onClick(() => this.handleConfigModeChange('period'))
              Text('按总利息')
                .fontSize(TypeScale.bodySm)
                .fontColor(this.interestConfigMode === 'total' ? this.theme.onPrimary : this.theme.text2)
                .padding({ top: 8, bottom: 8, left: 14, right: 14 })
                .backgroundColor(this.interestConfigMode === 'total' ? this.theme.primary : this.theme.surface2)
                .borderRadius(this.theme.radiusSm)
                .onClick(() => this.handleConfigModeChange('total'))
            }
            .width('100%')

            if (this.interestConfigMode === 'period') {
              FormFieldInput({
                label: '每期利息 (元)',
                value: $periodInterest,
                placeholder: '0.00',
                theme: this.theme,
                inputType: InputType.NUMBER_DECIMAL,
                onChange: (v: string) => this.handlePeriodInterestChange(v)
              })
              Text('自动算总利息: ' + (this.totalInterest || '0.00') + ' 元')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
                .alignSelf(ItemAlign.Start)
            } else {
              FormFieldInput({
                label: '总利息 (元)',
                value: $totalInterest,
                placeholder: '0.00',
                theme: this.theme,
                inputType: InputType.NUMBER_DECIMAL,
                onChange: (v: string) => this.handleTotalInterestChange(v)
              })
              Text('银行App中的总手续费/利息')
                .fontSize(TypeScale.captionSm)
                .fontColor(this.theme.text3)
                .alignSelf(ItemAlign.Start)
            }
          }

          // 年利率
          if (this.isInstallment && this.repaymentMethod !== 'fixed_interest') {
            FormFieldInput({
              label: '年利率 (%)',
              value: $annualRate,
              placeholder: '0',
              theme: this.theme,
              inputType: InputType.NUMBER_DECIMAL
            })
            Text(this.annualRateHint())
              .fontSize(TypeScale.captionSm)
              .fontColor(this.theme.text3)
              .width('100%')
              .padding({ left: 4, bottom: 8 })
          }

          // 总期数 / 剩余期数
          if (this.isInstallment) {
            Row({ space: 10 }) {
              FormFieldInput({
                label: '总期数 (期)',
                value: $totalPeriods,
                placeholder: '12',
                theme: this.theme,
                inputType: InputType.Number,
                onChange: (v: string) => this.handleTotalPeriodsChange(v)
              })
                .layoutWeight(1)
              FormFieldInput({
                label: '剩余期数 (当期之后)',
                value: $remainingPeriods,
                placeholder: '12',
                theme: this.theme,
                inputType: InputType.Number
              })
                .layoutWeight(1)
            }
            .width('100%')

            Row({ space: 10 }) {
              // 已还期数（自动计算，只读）
              Column({ space: 6 }) {
                Text('已还期数 (期)')
                  .fontSize(TypeScale.bodySm)
                  .fontColor(this.theme.text2)
                  .alignSelf(ItemAlign.Start)
                Text('' + Math.max(0, Number(this.totalPeriods || 0) - Number(this.remainingPeriods || 0) - 1))
                  .fontSize(TypeScale.listPrimarySm)
                  .fontColor(this.theme.text3)
                  .width('100%')
                  .height(44)
                  .padding({ left: 14 })
                  .backgroundColor(this.theme.fieldBackground())
                  .borderRadius(this.theme.radiusSm)
                  .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
                  .textAlign(TextAlign.Start)
                  .alignSelf(ItemAlign.Start)
              }
              .layoutWeight(1)

              // 关联信用账户且账户有还款日时，不展示（与「下次还款日」一致，跟账户走）
              if (!this.hasLinkedAccountPaymentDay()) {
                FormFieldInput({
                  label: '每月还款日 (号)',
                  value: $paymentDay,
                  placeholder: '10',
                  theme: this.theme,
                  inputType: InputType.Number
                })
                  .layoutWeight(1)
              }
            }
            .width('100%')
          }

          // 开始日期
          FormFieldLabel({ label: '开始日期', theme: this.theme })
          FormFieldDateField({
            value: this.startDate,
            theme: this.theme,
            onPick: () => this.pickDate((d: string) => this.startDate = d, this.startDate)
          })

          // 下次还款日（未关联信用账户时）
          if (this.creditAccountId.length === 0) {
            FormFieldLabel({ label: this.isInstallment ? '下次还款日' : '还款日期', theme: this.theme })
            FormFieldDateField({
              value: this.repaymentDate,
              theme: this.theme,
              onPick: () => this.pickDate((d: string) => this.repaymentDate = d, this.repaymentDate)
            })
          } else {
            Text('还款日期将根据所选的信用账户出单周期自动计算决定。')
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
              .padding(14)
              .backgroundColor(this.theme.fieldBackground())
              .borderRadius(this.theme.radiusSm)
              .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
              .width('100%')
          }

          // 关联信用账户
          if (this.creditAccounts.length > 0) {
            Column() {
            Row() {
              Text('关联信用账户')
                .fontSize(TypeScale.bodySm)
                .fontColor(this.theme.text2)
                .layoutWeight(1)
              if (this.creditAccountId.length > 0) {
                Text('去关联')
                  .fontSize(TypeScale.caption)
                  .fontColor(this.theme.text3)
                  .padding({ left: this.theme.spaceXs, top: 4, bottom: 4 })
                  .onClick(() => {
                    this.creditAccountId = ''
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
              Text(this.getAccountDisplayText())
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
          } else {
            FormFieldLabel({ label: '关联信用账户', theme: this.theme })
            Text('暂无信用账户，可前往「账户」页面新增后关联。')
              .fontSize(TypeScale.caption)
              .fontColor(this.theme.text3)
              .padding(14)
              .backgroundColor(this.theme.fieldBackground())
              .borderRadius(this.theme.radiusSm)
              .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
              .width('100%')
          }

          // 备注
          FormFieldInput({
            label: '备注',
            value: $note,
            placeholder: '备注（可选）',
            theme: this.theme
          })

          // 还款计划预览
          if (this.isInstallment) {
            this.previewSection()
          }
          }
          .padding({ left: 16, right: 16, top: 4, bottom: 24 })
          .width('100%')
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .clip(false)
        .width('100%')

        // 保存按钮
        Button(this.saving ? '保存中...' : '保存')
          .width('90%')
          .height(48)
          .fontSize(TypeScale.listPrimarySm)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.theme.ctaBackground())
          .fontColor(this.theme.ctaForeground())
          .borderRadius(this.theme.radiusSm)
          .margin({ bottom: 24 })
          .translate({ x: this.shakeOffsetX })
          .enabled(!this.saving)
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
      // 全屏布局下标题/返回键主动避让状态栏，避免与系统时间重叠
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
          mainTitle: this.isEdit ? '编辑负债' : '添加负债'
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
      accounts: this.creditAccounts,
      selectedId: this.creditAccountId,
      title: '关联信用账户',
      labelFor: (account: CreditAccount): string => this.accountLabel(account),
      onPick: (accountId: string): void => {
        this.selectAccount(accountId)
      },
      onClose: () => {
        this.showAccountPicker = false
      }
    })
  }

  private methodLabel(m: RepaymentMethod): string {
    if (m === 'equal_payment') return '等额本息'
    if (m === 'fixed_interest') return '等本等息'
    return '自定义'
  }

  private selectedAccount(): CreditAccount {
    const acc = this.creditAccounts.find(a => a.id === this.creditAccountId)
    return acc ?? new CreditAccount()
  }

  private accountLabel(acc: CreditAccount): string {
    return acc.name + (acc.last_four ? ' (' + acc.last_four + ')' : '')
  }

  private getAccountDisplayText(): string {
    if (this.creditAccountId.length === 0) {
      return '未关联'
    }
    const acc = this.creditAccounts.find(a => a.id === this.creditAccountId)
    return acc ? this.accountLabel(acc) : '未关联'
  }

  @Builder
  previewSection() {
    Column() {
      Text('还款计划预览')
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.text)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 10 })

      if (this.getPreviewSchedule().length === 0) {
        Column() {
          Text('暂无预览计划')
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text3)
            .margin({ bottom: 4 })
          Text('请填写有效的负债金额、总期数、剩余期数与月供以生成预览')
            .fontSize(TypeScale.captionSm)
            .fontColor(this.theme.text3)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding(24)
        .alignItems(HorizontalAlign.Center)
      } else {
        ForEach(this.getPreviewSchedule(), (item: DebtPreviewItem) => {
          Row() {
            Column() {
              Row() {
                Text(String(item.period_number).padStart(2, '0') + '/' + String(this.totalPeriods).padStart(2, '0') + '期')
                  .fontSize(TypeScale.bodySm)
                  .fontWeight(FontWeight.Bold)
                  // 已还：次级色 text2（浅于主文、深于 text3），浅色下可读
                  .fontColor(item.status === 'paid' ? this.theme.text2 : this.theme.text)
                if (item.status === 'paid') {
                  Text('已还')
                    .fontSize(TypeScale.kicker)
                    .fontWeight(FontWeight.Medium)
                    // 深/浅均用 text2，避免深色 text3 偏糊
                    .fontColor(this.theme.text2)
                    .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                    // 深：surface3 抬离行底；浅：白底 surface2；均加软边
                    .backgroundColor(this.theme.isDarkCanvas()
                      ? this.theme.surface3
                      : this.theme.surface2)
                    .border({
                      width: 1,
                      color: this.theme.borderSoft
                    })
                    .borderRadius(this.theme.radiusSm)
                    .margin({ left: 4 })
                }
              }
              Text(item.date)
                .fontSize(TypeScale.captionSm)
                .fontColor(item.status === 'paid' ? this.theme.text2 : this.theme.text3)
                .margin({ top: 2 })
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Start)

            // 统一结构：每期都是「金额 + 利息」两框；已还仅禁编辑，布局一致
            Row({ space: 8 }) {
              Column({ space: 2 }) {
                Text('金额')
                  .fontSize(TypeScale.captionSm)
                  .fontColor(this.theme.text3)
                TextInput({
                  // 金额 = 本金（如第 3 期 110.88）；应付 = 本金 + 利息
                  text: this.customInputBuffer['' + item.period_number + '_principal'] ??
                    ((item.principal || 0) / 100).toFixed(2)
                })
                  .type(InputType.NUMBER_DECIMAL)
                  .width(72)
                  .height(32)
                  .fontSize(TypeScale.captionSm)
                  .fontColor(item.status === 'paid' ? this.theme.text2 : this.theme.text)
                  // 输入底保持 field；已还行本身抬升，框相对更「凹」
                  .backgroundColor(this.theme.fieldBackground())
                  .borderRadius(this.theme.radiusLg)
                  .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
                  .enabled(item.status !== 'paid')
                  .opacity(item.status === 'paid' ? 0.92 : 1)
                  .onChange((v: string) => {
                    if (item.status !== 'paid') {
                      this.handleCustomPeriodChange(item.period_number, 'principal', v)
                    }
                  })
              }
              .alignItems(HorizontalAlign.Start)
              Column({ space: 2 }) {
                Text('利息')
                  .fontSize(TypeScale.captionSm)
                  .fontColor(this.theme.text3)
                TextInput({
                  text: this.customInputBuffer['' + item.period_number + '_interest'] ??
                    ((item.interest || 0) / 100).toFixed(2)
                })
                  .type(InputType.NUMBER_DECIMAL)
                  .width(72)
                  .height(32)
                  .fontSize(TypeScale.captionSm)
                  .fontColor(item.status === 'paid' ? this.theme.text2 : this.theme.text)
                  .backgroundColor(this.theme.fieldBackground())
                  .borderRadius(this.theme.radiusLg)
                  .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
                  .enabled(item.status !== 'paid')
                  .opacity(item.status === 'paid' ? 0.92 : 1)
                  .onChange((v: string) => {
                    if (item.status !== 'paid') {
                      this.handleCustomPeriodChange(item.period_number, 'interest', v)
                    }
                  })
              }
              .alignItems(HorizontalAlign.Start)
            }
          }
          .width('100%')
          .padding(10)
          // 行底：深色已还行用 surface3 与外框区分
          .backgroundColor(item.status === 'paid' && this.theme.isDarkCanvas()
            ? this.theme.surface3
            : this.theme.fieldBackground())
          .borderRadius(this.theme.radiusSm)
          .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
          .margin({ bottom: 6 })
        }, (item: DebtPreviewItem, index: number) => index + '_' + item.status + '_' + item.date)
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.theme.fieldBackground())
    .borderRadius(this.theme.radiusSm)
    .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
    .margin({ top: 8 })
  }
}
