import { LengthMetrics } from '@kit.ArkUI'
import {ThemeColors, TypeScale} from 'common'
import { UserSettings, AiApiFormat } from 'common'
import { SettingsService } from 'service'
import { AIService, AIConnectionTestResult } from 'service'
import { AIParseOrchestrator } from 'service'
import { UserService } from 'service'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton, SheetHeader, sheetBottomInset } from './SheetDialog'
import { AIConfigPersistMerge } from './AIConfigPersistMerge'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'

interface ProviderPreset {
  name: string
  baseUrl: string
  format: AiApiFormat
  /** 推荐模型 id，选服务商时回填 */
  model: string
}

/** 解析渠道：仅文字底座 + 图片视觉（系统听写不单独占渠道，转写后走文字） */
export type AiChannel = 'text' | 'vision'

/** 渠道状态：0 关闭 1 待完善 2 已接通 */
export type AiChannelDot = 0 | 1 | 2

/**
 * AI 配置 · 大半模态内容
 * - 文字解析：必选底座（键盘 / 系统听写转写文本 / OCR 文本均依赖）
 * - 图片识别：可选视觉模型
 * - 无独立「语音 LLM」渠道；鸿蒙听写见 SpeechService + docs/deprecated/ai-voice-deprecation.md
 * - 编辑为草稿：仅点「完成」写入；关闭/下滑丢弃
 */
@Component
export struct AIConfigSheet {
  @Prop theme: ThemeColors = new ThemeColors()
  /** 每次打开递增，强制从磁盘重载草稿基底 */
  @Prop @Watch('onOpenSession') openSession: number = 0
  /** 关闭主 Sheet（完成并已保存后） */
  onDone?: () => void
  /** 关闭按钮：直接关闭，不落盘 */
  onClose: () => void = () => {}

  @State private active: AiChannel = 'text'
  @State private textEnabled: boolean = false
  @State private textKey: string = ''
  @State private textBaseUrl: string = ''
  @State private textModel: string = ''
  @State private textFormat: AiApiFormat = 'auto'
  @State private textTestFp: string = ''
  @State private visionEnabled: boolean = false
  @State private visionKey: string = ''
  @State private visionBaseUrl: string = ''
  @State private visionModel: string = ''
  @State private visionFormat: AiApiFormat = 'auto'
  @State private visionTestFp: string = ''
  @State private testing: boolean = false
  @State private finishing: boolean = false
  @State private showProviderSheet: boolean = false
  @State private providerConfig: SheetDialogConfig = new SheetDialogConfig()
  /** 选服务商后递增，强制 TextInput 用新 text 重建（避免 Builder 入参不刷新） */
  @State private formEpoch: number = 0
  private providerCallback: (index: number) => void = () => {}
  private loaded: boolean = false
  /** 是否已点「完成」落库；未置位则关闭时不写盘 */
  private committed: boolean = false
  /** 用户点了「清除服务商」才允许把该渠道写成空 */
  private textCleared: boolean = false
  private visionCleared: boolean = false
  /** 切 Tab / 重建表单后短时忽略 TextInput.onChange，防止空串冲掉状态与测通指纹 */
  private fieldChangeGuardUntil: number = 0
  /** 已接通渠道默认折叠为状态摘要，点击展开才显示完整表单 */
  @State private textCollapsed: boolean = false
  @State private visionCollapsed: boolean = false

  private armFieldChangeGuard(): void {
    this.fieldChangeGuardUntil = Date.now() + 500
  }

  private collapsedOf(channel: AiChannel): boolean {
    if (channel === 'text') {
      return this.textCollapsed
    }
    return this.visionCollapsed
  }

  private setCollapsed(channel: AiChannel, v: boolean): void {
    if (channel === 'text') {
      this.textCollapsed = v
    } else {
      this.visionCollapsed = v
    }
  }

  /**
   * 服务商预设（2026-07 文档）
   * Base URL：SDK 根地址；model：推荐默认模型 id
   */
  private providers: ProviderPreset[] = [
    {
      name: '火山引擎 Coding Plan',
      baseUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3',
      format: 'openai',
      // 方舟需填控制台接入点/模型 id，此处不臆造
      model: ''
    },
    {
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      format: 'openai',
      // V4：deepseek-v4-flash / deepseek-v4-pro；旧 deepseek-chat 将于 2026-07-24 弃用
      model: 'deepseek-v4-flash'
    },
    {
      name: 'Kimi',
      baseUrl: 'https://api.moonshot.cn/v1',
      format: 'openai',
      // 旗舰 K2.6；亦可用 moonshot-v1-128k 等 V1 系列
      model: 'kimi-k2.6'
    },
    {
      name: '智谱',
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      format: 'openai',
      // GLM-4.7 轻量免费档；旗舰可用 glm-4.7
      model: 'glm-4.7-flash'
    },
    {
      name: 'MiniMax',
      baseUrl: 'https://api.minimax.chat/v1',
      format: 'openai',
      // M 系列最新：MiniMax-M3（旧 abab6.5 已过时）
      model: 'MiniMax-M3'
    },
    { name: '自定义', baseUrl: '', format: 'auto', model: '' }
  ]

  aboutToAppear(): void {
    this.reloadDraftFromStore()
  }

  /** 组件销毁（半模态被卸载）兜底：把未提交的草稿写盘 */
  aboutToDisappear(): void {
    this.persistDraftIfDirty()
  }

  private async onOpenSession(): Promise<void> {
    // 上次关闭若走了不触发 aboutToDisappear 的路径（半模态复用宿主不卸载），
    // 这里先把残留草稿写盘，再重载，避免用户填过的内容被静默丢弃
    await this.persistDraftIfDirty()
    this.reloadDraftFromStore()
  }

  private reloadDraftFromStore(): void {
    this.committed = false
    this.loaded = false
    this.active = 'text'
    this.armFieldChangeGuard()
    this.loadSettings()
  }

  private async loadSettings(): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    this.textEnabled = settings.ai_text_enabled
    this.textKey = settings.ai_text_key
    this.textBaseUrl = settings.ai_text_base_url
    this.textModel = settings.ai_text_model
    this.textFormat = settings.ai_text_api_format
    this.textTestFp = settings.ai_text_test_fp
    this.visionEnabled = settings.ai_vision_enabled
    this.visionKey = settings.ai_vision_key
    this.visionBaseUrl = settings.ai_vision_base_url
    this.visionModel = settings.ai_vision_model
    this.visionFormat = settings.ai_vision_api_format
    this.visionTestFp = settings.ai_vision_test_fp
    this.textCleared = false
    this.visionCleared = false
    this.loaded = true
    // 已接通渠道默认折叠；待完善/待测试保持展开
    this.textCollapsed = this.testedOkOf('text')
    this.visionCollapsed = this.testedOkOf('vision')
  }

  private async persist(): Promise<void> {
    if (!this.loaded) {
      return
    }
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    const textKey = AIConfigPersistMerge.pickField(this.textKey, settings.ai_text_key, this.textCleared)
    const textUrl = AIConfigPersistMerge.pickField(this.textBaseUrl, settings.ai_text_base_url, this.textCleared)
    const textModel = AIConfigPersistMerge.pickField(this.textModel, settings.ai_text_model, this.textCleared)
    const visionKey = AIConfigPersistMerge.pickField(this.visionKey, settings.ai_vision_key, this.visionCleared)
    const visionUrl = AIConfigPersistMerge.pickField(
      this.visionBaseUrl, settings.ai_vision_base_url, this.visionCleared)
    const visionModel = AIConfigPersistMerge.pickField(
      this.visionModel, settings.ai_vision_model, this.visionCleared)
    // 关闭渠道时仍保留 Key；有 Key 时自动开启使首页生效
    settings.ai_text_enabled = this.textEnabled || textKey.trim().length > 0
    settings.ai_text_key = textKey
    settings.ai_text_base_url = textUrl
    settings.ai_text_model = textModel
    settings.ai_text_api_format = this.textFormat
    settings.ai_text_test_fp = AIConfigPersistMerge.pickFingerprint(
      this.textTestFp, settings.ai_text_test_fp, textKey, textUrl, textModel, this.textCleared)
    settings.ai_vision_enabled = this.visionEnabled || visionKey.trim().length > 0
    settings.ai_vision_key = visionKey
    settings.ai_vision_base_url = visionUrl
    settings.ai_vision_model = visionModel
    settings.ai_vision_api_format = this.visionFormat
    settings.ai_vision_test_fp = AIConfigPersistMerge.pickFingerprint(
      this.visionTestFp, settings.ai_vision_test_fp, visionKey, visionUrl, visionModel, this.visionCleared)
    await SettingsService.saveSettings(settings)
    this.committed = true
  }

  /** 当前配置指纹；与已存 test_fp 一致 ⇒ 已接通 */
  private configFp(channel: AiChannel): string {
    return this.keyOf(channel) + '\n' + this.baseUrlOf(channel) + '\n' + this.modelOf(channel)
  }

  private storedTestFp(channel: AiChannel): string {
    if (channel === 'text') {
      return this.textTestFp
    }
    return this.visionTestFp
  }

  private testedOkOf(channel: AiChannel): boolean {
    const fp = this.configFp(channel)
    if (fp.length < 3 || this.keyOf(channel).length === 0) {
      return false
    }
    return this.storedTestFp(channel) === fp
  }

  private setTestedOk(channel: AiChannel, ok: boolean): void {
    const fp = ok ? this.configFp(channel) : ''
    if (channel === 'text') {
      this.textTestFp = fp
    } else {
      this.visionTestFp = fp
    }
  }

  /**
   * 0 灰=关闭 1 琥珀=待完善/待测试 2 绿=测通指纹与当前配置一致
   * 勿在 TextInput.onChange 里清指纹：切 Tab 重建输入框会误触发 onChange
   */
  private dotOf(channel: AiChannel): AiChannelDot {
    if (!this.enabledOf(channel)) {
      return 0
    }
    if (this.testedOkOf(channel)) {
      return 2
    }
    return 1
  }

  private dotColor(channel: AiChannel): string {
    const d = this.dotOf(channel)
    if (d === 2) {
      return `${this.theme.statusOk()}`
    }
    if (d === 1) {
      return `${this.theme.statusWarning()}`
    }
    return `${this.theme.statusInactive()}`
  }

  private statusLabel(channel: AiChannel): string {
    if (!this.enabledOf(channel)) {
      return '未开启'
    }
    if (this.testedOkOf(channel)) {
      return '已接通'
    }
    const key = this.keyOf(channel)
    const url = this.baseUrlOf(channel)
    const model = this.modelOf(channel)
    if (key.length === 0 || url.length === 0 || model.length === 0) {
      return '已开启 · 待完善'
    }
    return '已配置 · 待测试'
  }

  private statusColor(channel: AiChannel): ResourceColor {
    const d = this.dotOf(channel)
    if (d === 2) {
      return this.theme.statusOk()
    }
    if (d === 1) {
      return this.theme.statusWarning()
    }
    return this.theme.statusInactive()
  }

  private channelShort(channel: AiChannel): string {
    if (channel === 'text') {
      return '文字'
    }
    return '图片'
  }

  private channelTitle(channel: AiChannel): string {
    if (channel === 'text') {
      return '文字解析'
    }
    return '图片识别'
  }

  private enabledOf(channel: AiChannel): boolean {
    if (channel === 'text') {
      return this.textEnabled
    }
    return this.visionEnabled
  }

  private setEnabled(channel: AiChannel, v: boolean): void {
    if (channel === 'text') {
      this.textEnabled = v
    } else {
      this.visionEnabled = v
    }
  }

  private keyOf(channel: AiChannel): string {
    if (channel === 'text') {
      return this.textKey
    }
    return this.visionKey
  }

  private baseUrlOf(channel: AiChannel): string {
    if (channel === 'text') {
      return this.textBaseUrl
    }
    return this.visionBaseUrl
  }

  private modelOf(channel: AiChannel): string {
    if (channel === 'text') {
      return this.textModel
    }
    return this.visionModel
  }

  private formatOf(channel: AiChannel): AiApiFormat {
    if (channel === 'text') {
      return this.textFormat
    }
    return this.visionFormat
  }

  private setFormat(channel: AiChannel, fmt: AiApiFormat): void {
    let next: AiApiFormat = fmt
    const url = this.normalizeBaseUrl(this.baseUrlOf(channel))
    // 火山 Coding Plan /v3 只能走 OpenAI；误选 Anthropic 会 401 且本端不发 Anthropic 请求
    if (fmt === 'anthropic' && this.isVolcCodingPlanOpenAiUrl(url)) {
      next = 'openai'
      AppToast.show('火山 …/api/coding/v3 须用 OpenAI 格式，已自动改回', 2500)
    }
    if (channel === 'text') {
      this.textFormat = next
    } else {
      this.visionFormat = next
    }
    this.applyDefaultBaseUrlIfNeeded(channel, next)
  }

  /** 是否为火山 Coding Plan 的 OpenAI 根（含 /v3） */
  private isVolcCodingPlanOpenAiUrl(url: string): boolean {
    const u = url.toLowerCase()
    return u.indexOf('volces.com') >= 0 && u.indexOf('/api/coding/v3') >= 0
  }

  /** 是否为火山 Coding Plan 任一根地址 */
  private isVolcCodingPlanUrl(url: string): boolean {
    const u = url.toLowerCase()
    return u.indexOf('volces.com') >= 0 && u.indexOf('/api/coding') >= 0
  }

  private defaultBaseUrlForFormat(fmt: AiApiFormat): string {
    if (fmt === 'anthropic') {
      return 'https://api.anthropic.com'
    }
    return 'https://api.openai.com/v1'
  }

  private isFormatDefaultUrl(url: string): boolean {
    const u = this.normalizeBaseUrl(url)
    if (u.length === 0) {
      return true
    }
    const known: string[] = [
      'https://api.openai.com/v1',
      'https://api.openai.com',
      'https://api.anthropic.com',
      'https://api.anthropic.com/v1'
    ]
    for (let i = 0; i < known.length; i++) {
      if (u === known[i]) {
        return true
      }
    }
    return false
  }

  private applyDefaultBaseUrlIfNeeded(channel: AiChannel, fmt: AiApiFormat): void {
    const current = this.baseUrlOf(channel)
    if (!this.isFormatDefaultUrl(current)) {
      return
    }
    const next = this.defaultBaseUrlForFormat(fmt)
    if (channel === 'text') {
      this.textBaseUrl = next
    } else {
      this.visionBaseUrl = next
    }
  }

  private providerLabel(channel: AiChannel): string {
    const idx = this.currentProviderIndex(channel)
    if (idx < 0) {
      return '选择服务商'
    }
    return this.providers[idx].name
  }

  /**
   * 当前渠道匹配到的服务商下标（用于列表回显选中）
   * - URL 为空 -> -1（未选）
   * - 命中预设（含 DeepSeek / 火山 别名） -> 该预设下标
   * - 非空但未命中 -> 末位「自定义」
   */
  private currentProviderIndex(channel: AiChannel): number {
    const url = this.normalizeBaseUrl(this.baseUrlOf(channel))
    if (url.length === 0) {
      return -1
    }
    for (let i = 0; i < this.providers.length; i++) {
      const p = this.providers[i]
      if (p.baseUrl.length === 0) {
        continue
      }
      const preset = this.normalizeBaseUrl(p.baseUrl)
      if (url === preset) {
        return i
      }
      if (p.name === 'DeepSeek' &&
        (url === 'https://api.deepseek.com/v1' || url === 'https://api.deepseek.com/v1/')) {
        return i
      }
      // 火山 Coding Plan：文档里 Anthropic 根 /api/coding 与 OpenAI 根 /api/coding/v3 均识别
      if (p.name === '火山引擎 Coding Plan' &&
        (url === 'https://ark.cn-beijing.volces.com/api/coding' ||
          url === 'https://ark.cn-beijing.volces.com/api/coding/v3')) {
        return i
      }
    }
    return this.providers.length - 1
  }

  private normalizeBaseUrl(url: string): string {
    let u = url.trim()
    while (u.endsWith('/') && u.length > 1) {
      u = u.substring(0, u.length - 1)
    }
    return u
  }

  private formatLabel(fmt: string): string {
    if (fmt === 'openai') {
      return 'OpenAI'
    }
    if (fmt === 'anthropic') {
      return 'Anthropic'
    }
    if (fmt === 'auto') {
      return '自动'
    }
    return fmt
  }

  private applyProviderPreset(channel: AiChannel, preset: ProviderPreset): void {
    let url = this.normalizeBaseUrl(
      preset.baseUrl.length > 0 ? preset.baseUrl : this.defaultBaseUrlForFormat(preset.format)
    )
    // 火山 Coding Plan 强制 OpenAI 根（带 /v3），避免误用文档里的 Anthropic 地址
    if (preset.name === '火山引擎 Coding Plan') {
      url = 'https://ark.cn-beijing.volces.com/api/coding/v3'
    }
    if (channel === 'text') {
      this.textFormat = preset.format
      this.textBaseUrl = url
      if (preset.model.length > 0) {
        this.textModel = preset.model
      }
    } else {
      this.visionFormat = preset.format
      this.visionBaseUrl = url
      if (preset.model.length > 0) {
        this.visionModel = preset.model
      }
    }
    this.armFieldChangeGuard()
    this.formEpoch = this.formEpoch + 1
  }

  private clearProvider(channel: AiChannel): void {
    if (channel === 'text') {
      this.textKey = ''
      this.textBaseUrl = ''
      this.textFormat = 'auto'
      this.textModel = ''
      this.textTestFp = ''
      this.textCleared = true
    } else {
      this.visionKey = ''
      this.visionBaseUrl = ''
      this.visionFormat = 'auto'
      this.visionModel = ''
      this.visionTestFp = ''
      this.visionCleared = true
    }
    this.armFieldChangeGuard()
    this.formEpoch = this.formEpoch + 1
  }

  private pickProvider(): void {
    const channel = this.active
    const selectedIdx = this.currentProviderIndex(channel)
    const buttons: SheetDialogButton[] = []
    for (let i = 0; i < this.providers.length; i++) {
      buttons.push(new SheetDialogButton(this.providers[i].name, this.theme.text, 'default', i === selectedIdx))
    }
    buttons.push(new SheetDialogButton('清除服务商', this.theme.red, 'destructive'))
    buttons.push(new SheetDialogButton('取消', this.theme.text2, 'cancel'))
    this.providerConfig = new SheetDialogConfig('选择服务商', '', buttons)
    this.providerCallback = (index: number) => {
      if (index === this.providers.length) {
        this.clearProvider(channel)
        return
      }
      if (index > this.providers.length) {
        return
      }
      this.applyProviderPreset(channel, this.providers[index])
    }
    this.showProviderSheet = true
  }

  private fieldValue(channel: AiChannel, field: string): string {
    if (field === 'key') {
      return this.keyOf(channel)
    }
    if (field === 'url') {
      return this.baseUrlOf(channel)
    }
    return this.modelOf(channel)
  }

  private async testConnection(): Promise<void> {
    const channel = this.active
    let key = this.keyOf(channel)
    let baseUrl = this.baseUrlOf(channel)
    const model = this.modelOf(channel)
    if (key.length === 0) {
      AppToast.show(ErrorMessages.AI_NEED_KEY, 2000)
      return
    }
    if (baseUrl.length === 0) {
      AppToast.show(ErrorMessages.AI_NEED_BASE_URL, 2000)
      return
    }
    if (model.length === 0) {
      AppToast.show(ErrorMessages.AI_NEED_MODEL, 2500)
      return
    }
    // 测通前纠偏：火山 + Anthropic 误配 → OpenAI + /v3
    const normUrl = this.normalizeBaseUrl(baseUrl)
    if (this.isVolcCodingPlanUrl(normUrl)) {
      if (this.formatOf(channel) === 'anthropic' || this.formatOf(channel) === 'auto') {
        this.setFormat(channel, 'openai')
      }
      if (!this.isVolcCodingPlanOpenAiUrl(normUrl)) {
        baseUrl = 'https://ark.cn-beijing.volces.com/api/coding/v3'
        if (channel === 'text') {
          this.textBaseUrl = baseUrl
        } else {
          this.visionBaseUrl = baseUrl
        }
      }
    }
    this.testing = true
    let result = new AIConnectionTestResult()
    try {
      result = await AIService.testConnectionDetailed(key, baseUrl, model)
    } catch (err) {
      result.ok = false
      result.message = AIService.hintFromCaughtError(err as Object, baseUrl)
    }
    this.setTestedOk(channel, result.ok)
    // 测通失败也要落盘，避免下滑关闭丢草稿；落盘失败不得盖掉测通文案
    try {
      await this.persist()
    } catch {
    }
    AppToast.show(
      AIService.testResultToast(result.ok, result.message,
        ErrorMessages.AI_CONNECT_OK, ErrorMessages.AI_CONNECT_FAILED),
      result.ok ? 2000 : 4000
    )
    this.testing = false
  }

  private async finish(): Promise<void> {
    if (this.finishing) {
      return
    }
    this.finishing = true
    try {
      if (!this.testedOkOf('text')) {
        this.textTestFp = ''
      }
      if (!this.testedOkOf('vision')) {
        this.visionTestFp = ''
      }
      try {
        await this.persist()
      } catch {
      }
      AppToast.show(ErrorMessages.SAVED, 1500)
    } finally {
      if (this.onDone) {
        this.onDone()
      }
    }
  }

  /**
   * 未提交的草稿落盘：清理失效指纹后写库。
   * 已 persist 过（committed）或尚未读盘完成（loaded=false）时跳过，避免空草稿盖掉已存配置。
   */
  private async persistDraftIfDirty(): Promise<void> {
    if (!this.loaded || this.committed) {
      return
    }
    if (!this.testedOkOf('text')) {
      this.textTestFp = ''
    }
    if (!this.testedOkOf('vision')) {
      this.visionTestFp = ''
    }
    try {
      await this.persist()
    } catch {
    }
  }

  /**
   * 关闭（X / 下滑）前保住已填内容。
   * 原实现关闭即丢草稿，用户填完 Key 却因未点「完成」而白填一次。
   */
  private async closeWithSave(): Promise<void> {
    await this.persistDraftIfDirty()
    this.onClose()
  }

  private disabledHint(): string {
    if (this.active === 'text') {
      return '开启后支持键盘描述、系统听写（Core Speech）与 OCR 文本解析；常见单据可本地规则秒识别。'
    }
    return '开启后图片走系统 OCR（Core Vision）优先；读不出字时才用视觉模型兜底。'
  }

  @Builder
  segmentItem(channel: AiChannel) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Text(this.channelShort(channel))
        .fontSize(TypeScale.control)
        .fontWeight(this.active === channel ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.active === channel ? this.theme.onPrimary : this.theme.text2)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 10, bottom: 10 })

      Column()
        .width(6)
        .height(6)
        .borderRadius(this.theme.radiusSm)
        .backgroundColor(this.dotColor(channel))
        .margin({ top: 5, right: 7 })
    }
    .layoutWeight(1)
    .backgroundColor(this.active === channel ? this.theme.primary : this.theme.surface2)
    .borderRadius(this.theme.radiusSm)
    .onClick(() => {
      this.armFieldChangeGuard()
      this.active = channel
      this.formEpoch = this.formEpoch + 1
    })
  }

  @Builder
  formField(label: string, isPassword: boolean, channel: AiChannel, field: string) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(TypeScale.bodySm)
        .fontColor(this.theme.text3)
        .width('100%')
      TextInput({ text: this.fieldValue(channel, field), placeholder: label })
        .id('ai_fld_' + channel + '_' + field + '_' + this.formEpoch)
        .type(isPassword ? InputType.Password : InputType.Normal)
        .fontSize(TypeScale.listPrimarySm)
        .fontColor(this.theme.text)
        .placeholderColor(this.theme.text3)
        .backgroundColor(Color.Transparent)
        .padding({ left: 0, right: 0 })
        .height(36)
        .onChange((v: string) => {
          if (Date.now() < this.fieldChangeGuardUntil) {
            return
          }
          const prev = this.fieldValue(channel, field)
          if (!AIConfigPersistMerge.shouldAcceptFieldChange(prev, v)) {
            return
          }
          if (field === 'key') {
            if (channel === 'text') {
              this.textKey = v
            } else {
              this.visionKey = v
            }
          } else if (field === 'url') {
            if (channel === 'text') {
              this.textBaseUrl = v
            } else {
              this.visionBaseUrl = v
            }
          } else {
            if (channel === 'text') {
              this.textModel = v
            } else {
              this.visionModel = v
            }
          }
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 14, right: 14, top: 10, bottom: 8 })
  }

  /** 已接通状态下的折叠摘要：状态点 + 服务商 + 模型 + 展开入口 */
  @Builder
  collapsedSummary() {
    Column() {
      Row({ space: 10 }) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(this.theme.radiusSm)
          .backgroundColor(this.dotColor(this.active))

        Text('已接通')
          .fontSize(TypeScale.bodySm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.statusColor(this.active))

        Text('·')
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text3)

        Text(this.providerLabel(this.active))
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text2)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        Text('·')
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text3)

        Text(this.modelOf(this.active))
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        Text('展开 ›')
          .fontSize(TypeScale.caption)
          .fontColor(this.theme.aiAccent)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 14, bottom: 14 })
      .backgroundColor(this.theme.sheetItemBackground())
      .borderRadius(this.theme.sheetCardRadius)
      .border({ width: 1, color: this.theme.borderStrong })
      .onClick(() => {
        this.setCollapsed(this.active, false)
      })
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .margin({ top: 10 })
  }

  /** 展开态下的「收起」入口，仅已接通渠道显示 */
  @Builder
  collapseLinkRow() {
    Row() {
      Text('‹ 收起')
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.aiAccent)
    }
    .width('100%')
    .justifyContent(FlexAlign.End)
    .padding({ left: 24, right: 24, top: 6 })
    .onClick(() => {
      this.setCollapsed(this.active, true)
    })
  }

  build() {
    Column({ space: 0 }) {
      SheetHeader({
        theme: this.theme,
        title: 'AI 配置',
        subtitle: '填写 API Key 即可启用智能识别。密钥仅存本机，请求直连你配置的服务商。',
        onClose: () => {
          this.closeWithSave()
        }
      })

      Row({ space: 6 }) {
        this.segmentItem('text')
        this.segmentItem('vision')
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 4 })
      .margin({ bottom: 14 })

      Column() {
        Row() {
          Column({ space: 2 }) {
            Text(this.channelTitle(this.active))
              .fontSize(TypeScale.listPrimarySm)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text)
            Text(this.statusLabel(this.active))
              .fontSize(TypeScale.bodySm)
              .fontColor(this.statusColor(this.active))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Toggle({ type: ToggleType.Switch, isOn: this.enabledOf(this.active) })
            .selectedColor(this.theme.controlSelected())
            .switchPointColor(this.theme.controlKnob())
            .onChange((v: boolean) => {
              this.setEnabled(this.active, v)
            })
        }
        .width('100%')
        .padding({ left: 14, right: 14, top: 12, bottom: 12 })
        .backgroundColor(this.theme.sheetItemBackground())
        .borderRadius(this.theme.sheetCardRadius)
        .border({ width: 1, color: this.theme.borderStrong })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      if (this.enabledOf(this.active)) {
        if (this.collapsedOf(this.active) && this.testedOkOf(this.active)) {
          this.collapsedSummary()
        } else {
        Scroll() {
          Column() {
            Row() {
              Text('服务商')
                .fontSize(TypeScale.control)
                .fontColor(this.theme.text2)
                .layoutWeight(1)
              Text(this.providerLabel(this.active) + '  ›')
                .fontSize(TypeScale.control)
                .fontColor(this.theme.aiAccent)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 12, bottom: 12 })
            .onClick(() => {
              this.pickProvider()
            })

            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 14, right: 14 })

            if (this.active === 'text') {
              this.formField('API Key', true, 'text', 'key')
              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.formField('Base URL', false, 'text', 'url')
              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.formField('模型', false, 'text', 'model')
            } else {
              this.formField('API Key', true, 'vision', 'key')
              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.formField('Base URL', false, 'vision', 'url')
              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 14, right: 14 })
              this.formField('模型', false, 'vision', 'model')
            }

            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 14, right: 14 })

            Row() {
              Text('API 格式')
                .fontSize(TypeScale.control)
                .fontColor(this.theme.text2)
                .layoutWeight(1)
              Row({ space: 6 }) {
                ForEach(['auto', 'openai', 'anthropic'] as string[], (fmt: string) => {
                  Text(this.formatLabel(fmt))
                    .fontSize(TypeScale.caption)
                    .fontColor(this.formatOf(this.active) === fmt ? this.theme.onPrimary : this.theme.text2)
                    .padding({ top: 5, bottom: 5, left: 9, right: 9 })
                    .backgroundColor(this.formatOf(this.active) === fmt ?
                      this.theme.primary : this.theme.surface2)
                    .borderRadius(this.theme.radiusSm)
                    .onClick(() => {
                      this.setFormat(this.active, fmt as AiApiFormat)
                      this.formEpoch = this.formEpoch + 1
                    })
                }, (fmt: string) => fmt)
              }
            }
            .width('100%')
            .padding({ left: 14, right: 14, top: 10, bottom: 12 })
          }
          .width('100%')
          .backgroundColor(this.theme.sheetItemBackground())
          .borderRadius(this.theme.sheetCardRadius)
          .border({ width: 1, color: this.theme.borderStrong })
        }
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)
        .constraintSize({ maxHeight: 360 })
        .width('100%')
        .padding({ left: 24, right: 24 })
        .margin({ top: 10 })

          if (this.testedOkOf(this.active)) {
            this.collapseLinkRow()
          }
        }

        Text(this.active === 'text' ?
          '用于键盘、系统听写（Core Speech）与 OCR 文本的结构化解析。优先本地规则秒出结果，再调云端。听写不是独立语音 LLM。' :
          '图片优先系统 OCR（Core Vision）+ 本地规则/文字模型；仅 OCR 读不出字时才用视觉模型兜底。Key 仅本地保存。')
          .fontSize(TypeScale.caption)
          .fontColor(this.theme.text3)
          .lineHeight(16)
          .width('100%')
          .padding({ left: 24, right: 24, top: 8 })
      } else {
        Text(this.disabledHint())
          .fontSize(TypeScale.body)
          .fontColor(this.theme.text3)
          .lineHeight(19)
          .width('100%')
          .padding({ left: 24, right: 24, top: 14, bottom: 4 })
      }

      if (this.enabledOf(this.active)) {
        Row({ space: 10 }) {
          Button(this.testing ? '测试中...' : '测试连接')
            .layoutWeight(1)
            .height(48)
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.theme.sheetItemBackground())
            .fontColor(this.theme.text)
            .borderRadius(this.theme.sheetCardRadius)
            .border({ width: 1, color: this.theme.borderStrong })
            .enabled(!this.testing)
            .onClick(() => {
              this.testConnection()
            })

          Button(this.finishing ? '保存中...' : '完成')
            .layoutWeight(1)
            .height(48)
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(this.theme.ctaBackground())
            .fontColor(this.theme.ctaForeground())
            .borderRadius(this.theme.sheetCardRadius)
            .enabled(!this.finishing)
            .onClick(() => {
              this.finish()
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 14, bottom: sheetBottomInset(24) })
      } else {
        Column() {
          Button(this.finishing ? '保存中...' : '完成')
            .width('100%')
            .height(48)
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(this.theme.ctaBackground())
            .fontColor(this.theme.ctaForeground())
            .borderRadius(this.theme.sheetCardRadius)
            .enabled(!this.finishing)
            .onClick(() => {
              this.finish()
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 14, bottom: sheetBottomInset(24) })
      }
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .bindSheet($$this.showProviderSheet, this.providerSheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      radius: LengthMetrics.vp(this.theme.sheetRadius),
      showClose: false,
      backgroundColor: this.theme.sheetBackground() as string,
      blurStyle: BlurStyle.NONE,
      maskColor: this.theme.sheetMaskColor(),
      shadow: this.theme.sheetShadowOptions(),
      onDisappear: () => {
        this.showProviderSheet = false
      }
    })
  }

  @Builder
  providerSheetBuilder() {
    SheetDialogView({
      theme: this.theme,
      config: this.providerConfig,
      onTap: (index: number) => {
        this.showProviderSheet = false
        this.providerCallback(index)
      },
      onClose: () => {
        this.showProviderSheet = false
      }
    })
  }
}

/** 设置入口 · 单渠道状态 Tag */
export class AIChannelTagInfo {
  name: string = ''
  /** 0 未开 1 待完善/待测试 2 已接通（测通指纹匹配） */
  level: number = 0

  constructor(name: string = '', level: number = 0) {
    this.name = name
    this.level = level
  }
}

/** 设置入口摘要 + 运行时能力判断 */
export class AIConfigSummaryHelper {
  /** 文字解析绿点：开启 + 字段完整 + 测通指纹匹配 */
  static isTextReady(settings: UserSettings): boolean {
    const key = settings.ai_text_key
    const url = settings.ai_text_base_url
    const model = settings.ai_text_model
    const fp = key + '\n' + url + '\n' + model
    return key.length > 0 && url.length > 0 && model.length > 0 &&
      settings.ai_text_test_fp.length > 0 && settings.ai_text_test_fp === fp
  }

  /** 委托 AIParseOrchestrator，避免与 Live/Chat 门槛分叉 */
  static canParseText(settings: UserSettings): boolean {
    return AIParseOrchestrator.canParseText(settings)
  }

  /** 兼容旧字符串摘要 */
  static from(settings: UserSettings): string {
    const tags = AIConfigSummaryHelper.channelTags(settings)
    let ok = 0
    let mid = 0
    for (let i = 0; i < tags.length; i++) {
      if (tags[i].level === 2) {
        ok++
      } else if (tags[i].level === 1) {
        mid++
      }
    }
    if (ok === 0 && mid === 0) {
      return '未配置'
    }
    if (ok === 2) {
      return '文字·图片 已接通'
    }
    return '查看配置状态'
  }

  /** 仅文字 / 图片两渠道 */
  static channelTags(settings: UserSettings): AIChannelTagInfo[] {
    return [
      AIConfigSummaryHelper.oneTag('文字', settings.ai_text_enabled, settings.ai_text_key,
        settings.ai_text_base_url, settings.ai_text_model, settings.ai_text_test_fp),
      AIConfigSummaryHelper.oneTag('图片', settings.ai_vision_enabled, settings.ai_vision_key,
        settings.ai_vision_base_url, settings.ai_vision_model, settings.ai_vision_test_fp)
    ]
  }

  private static oneTag(name: string, enabled: boolean, key: string, url: string, model: string,
    testFp: string): AIChannelTagInfo {
    const fp = key + '\n' + url + '\n' + model
    const hasFields = key.length > 0 && url.length > 0 && model.length > 0
    if (!enabled && !hasFields) {
      return new AIChannelTagInfo(name, 0)
    }
    if (hasFields && testFp.length > 0 && testFp === fp) {
      return new AIChannelTagInfo(name, 2)
    }
    return new AIChannelTagInfo(name, 1)
  }
}
