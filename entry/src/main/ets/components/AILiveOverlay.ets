import {ThemeColors, ThemeManager, TypeScale} from 'common'
import { ParseResult, ParseResultItem } from 'service'
import { AIParseOrchestrator } from 'service'
import { AILiveMapping } from 'service'
import { AILiveSaveService } from 'service'
import { OcrService } from 'service'
import { SpeechService } from 'service'
import { HandednessService } from 'service'
import { Utils } from 'common'
import { AppStorageKeys } from 'common'
import { Constants } from 'common'
import { WidgetUpdateService } from 'service'
import { LiveViewService } from 'service'
import { PlatformService } from 'service'
import { DebtService } from 'service'
import { SubscriptionService } from 'service'
import { CreditAccountService } from 'service'
import { AILiveDebtDraft, AILiveDraftKeys, AILiveSubscriptionDraft, AILiveCreditAccountDraft } from 'service'
import { AIParsePreviewCard } from 'components'
import { AILiveScanView } from 'components'
import { AILiveInputBar } from 'components'
import { AILiveVoiceFullscreen } from 'components'
import { AILiveTranscriptCard } from 'components'
import { ThinkingOrb } from 'components'
import { SheetHeader } from 'components'
import { common } from '@kit.AbilityKit'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { AppRouter, RouteNames } from 'common'
import { image } from '@kit.ImageKit'
import {
  ConfirmListRow,
  buildConfirmRows,
  toggleConfirmRow,
  setAllConfirmRows,
  countSelected,
  allRowsSelected
} from 'components'
import { AILiveConfirmRowItem } from 'components'

/**
 * AI 智能录入浮层
 * 入口：文字 / 拍照 / 相册 / 鸿蒙系统听写（转写文本后走文字解析，非独立 AI 语音渠道）
 * launchMode：keyboard | camera | album
 *
 * 交互：
 * - 胶囊条：拍照·相册·短句文字；麦键按住听写
 * - 听写：全屏流式转写 → 转写卡片（长文）→ 解析
 * - 确认：单条就地改字段；多条列表勾选后一次入库
 * - 失败：强化「用表单补全」（无常驻手动入口）
 */
@Component
export struct AILiveOverlay {
  @Link @Watch('onShowChange') show: boolean
  @Prop theme: ThemeColors = ThemeManager.DARK
  /** keyboard | camera | album */
  @Prop launchMode: string = 'keyboard'

  /**
   * keyboard | transcriptCard | voiceFullscreen | picking | parsing |
   * confirm | confirmList | message | scanning
   */
  @State mode: string = 'keyboard'
  @State recognizing: boolean = false
  @State inputText: string = ''
  @State statusText: string = ''
  @State previewTitle: string = ''
  @State previewAmount: string = ''
  @State previewMeta: string = ''
  @State previewMark: string = ''
  @State previewColor: string = '#2F3336'
  /** 预览卡图标：已有账户 icon_url 或品牌 logo */
  @State previewIconUrl: string = ''
  @State previewTypeLabel: string = ''
  @State saving: boolean = false
  @State scanProgress: number = 0
  @State sparklePhase: number = 0
  @State voiceLevel: number = 10
  /** 全屏听写流式文案 */
  @State livePartial: string = ''
  /** 转写卡片正文（不写输入条） */
  @State transcriptDraft: string = ''
  @State cancelArmed: boolean = false
  @State cardEditing: boolean = false
  @State voiceElapsedSec: number = 0
  @State appendMode: boolean = false
  /** 智感握姿：主操作（听写/发送）是否在左侧 */
  @State leftPrimary: boolean = false
  /**
   * 拍照/相册入口：始终显示。
   * 系统 Core Vision OCR + 本地规则不依赖「图片 AI 渠道」；
   * 视觉渠道仅 OCR 无字时的云端兜底，不得挡住上传入口。
   */
  @State mediaVisible: boolean = true
  /** 失败态：是否展示表单补全 */
  @State showFormRescue: boolean = false
  /** 失败态：需要引导去配置 AI */
  @State showConfigCta: boolean = false
  /** 多条列表勾选行 */
  @State listRows: ConfirmListRow[] = []
  private pendingItem: ParseResultItem | null = null
  /** 多条记录支持 */
  private pendingItems: ParseResultItem[] = []
  private currentItemIndex: number = 0
  private bottomSafe: number = 0
  @State private topSafe: number = 0
  private scanTimer: number = -1
  private sparkleTimer: number = -1
  private voiceTimer: number = -1
  private voicePressStartMs: number = 0
  private appendBaseText: string = ''
  private cardEditBackup: string = ''
  private sessionElapsedSec: number = 0
  private voiceEnding: boolean = false
  /** 退后台暂停扫描/闪烁定时器，回前台按当前模式恢复，避免后台空转耗电 */
  @StorageLink('appInBackground') @Watch('onAppBackgroundChange') appInBackground: boolean = false
  private keyboardAllowed: boolean = true
  /** 从半页回到键盘时短暂忽略遮罩点击，避免「重新描述」点穿关闭 */
  private suppressMaskCloseUntil: number = 0
  /**
   * 扫描舞台最短展示时长（毫秒）。
   * 识别再快也至少播 3s 动画；识别更久则等识别完成再切结果。
   */
  private static readonly SCAN_MIN_MS: number = 3000
  private static readonly VOICE_HOLD_MIN_MS: number = 200
  private static readonly VOICE_CANCEL_SLIDE_VP: number = 64
  /** 握姿回调需稳定引用，便于 start/stop 配对 */
  private readonly onHandednessChange = (leftPrimary: boolean): void => {
    // 传感器回调可能不在 UI 线程，必须切回再改 @State
    const apply = (): void => {
      const prev = this.leftPrimary
      this.leftPrimary = leftPrimary
      if (prev !== leftPrimary) {
        AppToast.show(leftPrimary ? '已切换到左手布局' : '已切换到右手布局', 1200)
      }
    }
    try {
      this.getUIContext().runScopedTask(apply)
    } catch (_e) {
      apply()
    }
  }

  private delayMs(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve()
      }, ms)
    })
  }

  aboutToAppear() {
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 0
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.startHandednessWatch()
    if (this.show) {
      this.openLive()
    }
  }

  aboutToDisappear() {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer)
      this.scanTimer = -1
    }
    if (this.sparkleTimer !== -1) {
      clearInterval(this.sparkleTimer)
      this.sparkleTimer = -1
    }
    this.stopVoiceTimer()
    HandednessService.stop(this.onHandednessChange)
    SpeechService.setLevelCallback(null)
    SpeechService.setPartialCallback(null)
    if (SpeechService.isRecognizing()) {
      SpeechService.stop(true)
    }
  }

  private onShowChange(): void {
    if (!this.show) {
      this.teardown()
    } else {
      // 再次打开时重新订阅握姿
      this.startHandednessWatch()
    }
  }

  private onAppBackgroundChange(): void {
    if (this.appInBackground) {
      if (this.scanTimer !== -1) {
        clearInterval(this.scanTimer)
        this.scanTimer = -1
      }
      this.stopSparkle()
      // 听写中退后台：尽量结束并落入卡片（安全松手）
      if (this.mode === 'voiceFullscreen' && SpeechService.isRecognizing()) {
        this.cancelArmed = false
        SpeechService.stop(false)
      }
      return
    }
    if (!this.show) {
      return
    }
    if (this.mode === 'scanning' && this.scanTimer === -1) {
      this.startScanAnim()
    } else if (this.mode === 'parsing' && this.sparkleTimer === -1) {
      this.startSparkle()
    }
  }

  private startHandednessWatch(): void {
    // 先同步缓存，避免等权限时布局空白
    this.leftPrimary = HandednessService.isLeftPrimary()
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    HandednessService.start(this.onHandednessChange, context)
  }

  private async refreshMediaVisible(): Promise<void> {
    // 始终开放拍照/相册；解析链路内部再决定 OCR / 本地规则 / 文字 Key / 视觉兜底
    this.mediaVisible = true
  }

  private openLive(): void {
    this.pendingItem = null
    this.pendingItems = []
    this.listRows = []
    this.currentItemIndex = 0
    this.inputText = ''
    this.statusText = ''
    this.saving = false
    this.recognizing = false
    this.showFormRescue = false
    this.showConfigCta = false
    this.suppressMaskCloseUntil = 0
    this.clearTranscriptState()
    this.voiceLevel = 10
    this.startHandednessWatch()
    this.refreshMediaVisible()
    if (this.launchMode === 'camera') {
      this.keyboardAllowed = false
      this.mode = 'picking'
      this.imageInput('camera', false)
    } else if (this.launchMode === 'album') {
      this.keyboardAllowed = false
      this.mode = 'picking'
      this.imageInput('album', false)
    } else {
      this.keyboardAllowed = true
      this.mode = 'keyboard'
    }
  }

  private teardown(): void {
    this.stopScanAnim()
    this.stopSparkle()
    this.stopVoiceTimer()
    HandednessService.stop(this.onHandednessChange)
    SpeechService.setLevelCallback(null)
    SpeechService.setPartialCallback(null)
    if (SpeechService.isRecognizing()) {
      SpeechService.stop(true)
    }
    this.pendingItem = null
    this.pendingItems = []
    this.listRows = []
    this.currentItemIndex = 0
    this.mode = 'keyboard'
    this.inputText = ''
    this.statusText = ''
    this.saving = false
    this.recognizing = false
    this.keyboardAllowed = true
    this.showFormRescue = false
    this.showConfigCta = false
    this.clearTranscriptState()
  }

  private close(): void {
    this.stopScanAnim()
    this.stopSparkle()
    this.stopVoiceTimer()
    SpeechService.setLevelCallback(null)
    SpeechService.setPartialCallback(null)
    if (SpeechService.isRecognizing()) {
      SpeechService.stop(true)
    }
    this.show = false
  }

  private clearTranscriptState(): void {
    this.transcriptDraft = ''
    this.livePartial = ''
    this.cancelArmed = false
    this.cardEditing = false
    this.appendMode = false
    this.voiceElapsedSec = 0
    this.sessionElapsedSec = 0
    this.appendBaseText = ''
    this.cardEditBackup = ''
  }

  private finishToIdle(): void {
    this.pendingItem = null
    this.pendingItems = []
    this.listRows = []
    this.currentItemIndex = 0
    this.statusText = ''
    this.showFormRescue = false
    this.showConfigCta = false
    this.clearTranscriptState()
    if (this.keyboardAllowed) {
      // 从全高 message 半页切回键盘：同一触摸易点穿遮罩导致整层关闭
      this.suppressMaskCloseUntil = Date.now() + 500
      this.mode = 'keyboard'
    } else {
      this.close()
    }
  }

  /** 明确回到可编辑输入（重新描述） */
  private retryDescribe(): void {
    this.pendingItem = null
    this.pendingItems = []
    this.listRows = []
    this.currentItemIndex = 0
    this.statusText = ''
    this.showFormRescue = false
    this.showConfigCta = false
    this.keyboardAllowed = true
    this.clearTranscriptState()
    this.suppressMaskCloseUntil = Date.now() + 500
    this.mode = 'keyboard'
  }

  private markMessage(status: string, formRescue: boolean, configCta: boolean): void {
    this.mode = 'message'
    this.statusText = status
    // 配置引导与表单互斥：未进入识别不得给表单
    this.showConfigCta = configCta
    this.showFormRescue = configCta ? false : formRescue
  }

  // ---------- 解析 / 保存 ----------

  private async applyParseResult(result: ParseResult): Promise<void> {
    if (result.clarifyQuestion.length > 0) {
      this.pendingItem = result.items.length > 0 ? result.items[0] : null
      this.pendingItems = result.items
      this.currentItemIndex = 0
      const q = result.clarifyQuestion
      const needConfig = this.isConfigRelatedMessage(q)
      // 配置类问题：未真正识别，不给出表单；其它澄清/失败才可表单补全
      this.markMessage(q, !needConfig, needConfig)
      return
    }
    if (result.items.length > 0) {
      // record_type 缺失时默认 debt（与 AIService.parseJson 兜底一致）
      const validItems: ParseResultItem[] = []
      for (const it of result.items) {
        if (it.recordType.length === 0) {
          it.recordType = 'debt'
        }
        validItems.push(it)
      }
      this.pendingItems = validItems
      this.currentItemIndex = 0
      this.showFormRescue = false
      this.showConfigCta = false

      // 多条 → 列表勾选一次确认
      if (validItems.length > 1) {
        this.pendingItem = null
        this.buildListRows(validItems)
        this.mode = 'confirmList'
        return
      }

      const item = validItems[0]
      if (item.isComplete) {
        this.pendingItem = item
        await this.fillPreview(item)
        this.mode = 'confirm'
        return
      }
      // 不完整：保留 partial 供表单补全
      this.pendingItem = item
      this.markMessage('信息不完整。可补充说明，或使用表单补全已识别字段。', true, false)
      return
    }
    this.pendingItem = null
    this.pendingItems = []
    this.markMessage('未识别到可用内容。请调整表述后重试，或补充名称、金额等信息。', true, false)
  }

  private isConfigRelatedMessage(msg: string): boolean {
    return msg.indexOf('配置') >= 0 ||
      msg.indexOf('设置') >= 0 ||
      msg.indexOf('接通') >= 0 ||
      msg.indexOf('API Key') >= 0 ||
      msg.indexOf('文字解析') >= 0
  }

  private buildListRows(items: ParseResultItem[]): void {
    this.listRows = buildConfirmRows(items, `${this.theme.surface3}`)
  }

  private selectedCount(): number {
    return countSelected(this.listRows)
  }

  private allSelected(): boolean {
    return allRowsSelected(this.listRows)
  }

  private toggleListRow(index: number): void {
    this.listRows = toggleConfirmRow(this.listRows, index)
  }

  private setAllListSelected(selected: boolean): void {
    this.listRows = setAllConfirmRows(this.listRows, selected)
  }

  /** 列表：单条进详情确认（单卡预览，完整编辑走表单） */
  private async openListItemDetail(index: number): Promise<void> {
    if (index < 0 || index >= this.pendingItems.length) {
      return
    }
    this.currentItemIndex = index
    const item = this.pendingItems[index]
    this.pendingItem = item
    await this.fillPreview(item)
    this.mode = 'confirm'
  }

  /** 列表：单条进表单补全 */
  private editListItemForm(index: number): void {
    if (index < 0 || index >= this.pendingItems.length) {
      return
    }
    this.pendingItem = this.pendingItems[index]
    this.pushFormWithPending()
  }

  private async sendText(): Promise<void> {
    const t = this.inputText.trim()
    if (t.length === 0) {
      AppToast.show(ErrorMessages.INPUT_REQUIRED, 1500)
      return
    }
    await this.parseText(t)
  }

  private async parseText(userText: string, skipParsingState?: boolean): Promise<void> {
    if (userText.length === 0) {
      return
    }
    // 进入解析后清空转写卡，避免与确认流并存
    this.transcriptDraft = ''
    this.cardEditing = false
    this.livePartial = ''
    if (!skipParsingState) {
      this.mode = 'parsing'
      this.startSparkle()
    }
    this.pendingItem = null
    this.inputText = userText

    try {
      const result = await AIParseOrchestrator.parseText(userText)
      if (result.rawContent === 'TEXT_DISABLED') {
        const msg = result.clarifyQuestion.length > 0 ?
          result.clarifyQuestion : AIParseOrchestrator.MSG_TEXT_PARSE_REQUIRED
        // 未配置 = 未进入识别：只引导去配置 / 重新描述，不给表单入口
        this.markMessage(msg, false, true)
        return
      }
      if (result.items.length === 0 && result.rawContent.length > 0 &&
        (result.rawContent.indexOf('HTTP_') === 0 ||
          result.rawContent.indexOf('PARSING_') === 0 ||
          result.rawContent.indexOf('VISION_') === 0 ||
          result.rawContent.indexOf('FORMAT_') === 0)) {
        if (result.rawContent.indexOf('FORMAT_UNSUPPORTED_ANTHROPIC') === 0) {
          this.markMessage(AIParseOrchestrator.MSG_FORMAT_ANTHROPIC, false, true)
          return
        }
        if (result.rawContent.indexOf('HTTP_ERROR_401') === 0 ||
          result.rawContent.indexOf('HTTP_ERROR_403') === 0) {
          this.markMessage(AIParseOrchestrator.MSG_VISION_AUTH, false, true)
          return
        }
        this.markMessage(ErrorMessages.PARSE_FAILED, true, false)
        return
      }
      await this.applyParseResult(result)
    } catch (_e) {
      // 异常不得卡在 parsing：给出可操作提示
      this.markMessage(ErrorMessages.PARSE_FAILED, true, false)
    } finally {
      this.stopSparkle()
    }
  }

  /**
   * 名称模糊匹配：互相包含（忽略空白），用于关联已有账户图标
   */
  private nameLikelyMatch(a: string, b: string): boolean {
    const x = a.replace(/\s+/g, '').toLowerCase()
    const y = b.replace(/\s+/g, '').toLowerCase()
    if (x.length === 0 || y.length === 0) {
      return false
    }
    return x === y || x.indexOf(y) >= 0 || y.indexOf(x) >= 0
  }

  /**
   * 解析预览：汇总进单卡 + 尝试挂已有账户 icon_url，否则品牌 logo
   */
  private async fillPreview(item: ParseResultItem): Promise<void> {
    const data = AILiveMapping.buildPreviewData(item)
    this.previewTitle = data.title
    this.previewAmount = data.amountFen !== 0 ? Utils.formatMoney(data.amountFen) : ''
    this.previewMeta = data.meta
    const isSubRecord = item.recordType === 'subscription'
    const isCreditRecord = item.recordType === 'credit_account'
    if (isCreditRecord) {
      this.previewTypeLabel = '信用账户'
    } else if (isSubRecord) {
      this.previewTypeLabel = '订阅'
    } else {
      this.previewTypeLabel = '负债'
    }
    const visual = PlatformService.getBrandVisual(data.title)
    this.previewMark = visual.mark.length > 0 ? visual.mark :
      (data.title.length > 0 ? data.title.substring(0, 1) : '·')
    this.previewColor = visual.color.length > 0 ? visual.color : `${this.theme.surface3}`
    // 本地变量收集图标 URL，循环内避免反复读写 @State（hp-arkui-use-local-var-to-replace-state-var）
    let previewIconUrl = ''
    // 1) 已有账户 / 负债图标（负债优先匹配关联信用账户，再匹配同名负债）
    try {
      const title = data.title
      const hint = `${item.parsedFields.get('credit_account_hint') ?? ''}`
      if (item.recordType === 'subscription') {
        const list = await SubscriptionService.getSubscriptions()
        for (let i = 0; i < list.length; i++) {
          const s = list[i]
          if (this.nameLikelyMatch(s.name, title) && s.icon_url.length > 0) {
            previewIconUrl = s.icon_url
            break
          }
        }
      } else if (item.recordType === 'credit_account') {
        const list = await CreditAccountService.getCreditAccounts()
        for (let i = 0; i < list.length; i++) {
          const a = list[i]
          if (this.nameLikelyMatch(a.name, title) && a.icon_url.length > 0) {
            previewIconUrl = a.icon_url
            break
          }
        }
      } else {
        // 负债：先按 credit_account_hint / 平台名 匹配信用账户图标
        const accounts = await CreditAccountService.getCreditAccounts()
        const names: string[] = []
        if (hint.length > 0) {
          names.push(hint)
        }
        names.push(title)
        for (let n = 0; n < names.length && previewIconUrl.length === 0; n++) {
          for (let i = 0; i < accounts.length; i++) {
            const a = accounts[i]
            if (this.nameLikelyMatch(a.name, names[n]) && a.icon_url.length > 0) {
              previewIconUrl = a.icon_url
              // 同步写回关联 id，表单/保存可直接用
              item.parsedFields.set('credit_account_id', a.id)
              break
            }
          }
        }
        // 再匹配历史负债图标
        if (previewIconUrl.length === 0) {
          const list = await DebtService.getDebts()
          for (let i = 0; i < list.length; i++) {
            const d = list[i]
            if (this.nameLikelyMatch(d.platform, title) && d.icon_url.length > 0) {
              previewIconUrl = d.icon_url
              break
            }
          }
        }
      }
    } catch (_e) {
      // 查询失败不影响预览
    }
    // 2) 品牌域名 logo（美团/花呗等）
    if (previewIconUrl.length === 0) {
      const hint = `${item.parsedFields.get('credit_account_hint') ?? ''}`
      const logoName = hint.length > 0 ? hint : data.title
      previewIconUrl = PlatformService.getLogoUrlForName(logoName)
      if (previewIconUrl.length === 0 && data.title !== logoName) {
        previewIconUrl = PlatformService.getLogoUrlForName(data.title)
      }
    }
    this.previewIconUrl = previewIconUrl
  }

  /** 扫描结束后是否已进入结果态（用 string 比较，避免 mode 字面量收窄报错） */
  private isPostScanResultMode(): boolean {
    const m: string = this.mode
    return m === 'confirm' || m === 'confirmList' || m === 'message'
  }

  private startScanAnim(): void {
    this.stopScanAnim()
    this.scanProgress = 0
    this.sparklePhase = 0
    // 星尘缓慢呼吸：~55ms 步进 +1，避免连闪
    this.scanTimer = setInterval(() => {
      this.scanProgress = this.scanProgress + 0.01
      if (this.scanProgress > 1) {
        this.scanProgress = 0
      }
      this.sparklePhase = (this.sparklePhase + 1) % 60
    }, 55)
  }

  private stopScanAnim(): void {
    if (this.scanTimer !== -1) {
      clearInterval(this.scanTimer)
      this.scanTimer = -1
    }
    this.scanProgress = 0
  }

  private startSparkle(): void {
    this.stopSparkle()
    this.sparklePhase = 0
    this.sparkleTimer = setInterval(() => {
      this.sparklePhase = (this.sparklePhase + 1) % 40
    }, 50)
  }

  private stopSparkle(): void {
    if (this.sparkleTimer !== -1) {
      clearInterval(this.sparkleTimer)
      this.sparkleTimer = -1
    }
  }

  // ---------- 鸿蒙系统听写：按住全屏 → 转写卡片 → parseText ----------

  private stopVoiceTimer(): void {
    if (this.voiceTimer !== -1) {
      clearInterval(this.voiceTimer)
      this.voiceTimer = -1
    }
  }

  private startVoiceTimer(): void {
    this.stopVoiceTimer()
    this.voiceElapsedSec = 0
    this.voiceTimer = setInterval(() => {
      this.voiceElapsedSec = this.voiceElapsedSec + 1
    }, 1000)
  }

  private onVoicePressStart(): void {
    if (this.cardEditing) {
      return
    }
    if (this.recognizing || this.mode === 'voiceFullscreen') {
      return
    }
    if (this.mode !== 'keyboard' && this.mode !== 'transcriptCard') {
      return
    }
    if (SpeechService.isRecognizing()) {
      return
    }

    this.appendMode = this.mode === 'transcriptCard'
    this.appendBaseText = this.appendMode ? this.transcriptDraft : ''
    this.voicePressStartMs = Date.now()
    this.cancelArmed = false
    this.voiceEnding = false
    this.livePartial = ''
    this.voiceLevel = 10
    // 全屏层 HitTestMode.None，InputBar 保持挂载以延续按住 touch
    this.mode = 'voiceFullscreen'
    this.startVoiceTimer()

    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    SpeechService.setLevelCallback((level: number) => {
      this.voiceLevel = level
    })
    SpeechService.setPartialCallback((text: string) => {
      this.livePartial = text
    })
    SpeechService.recognize((text: string, cancelled: boolean) => {
      SpeechService.setLevelCallback(null)
      SpeechService.setPartialCallback(null)
      this.stopVoiceTimer()
      this.sessionElapsedSec = this.voiceElapsedSec
      this.voiceEnding = false

      if (cancelled) {
        // 上滑取消可能已乐观退全屏；此处幂等收尾
        if (this.mode === 'voiceFullscreen') {
          this.leaveVoiceFullscreenCancelled()
        } else {
          this.cancelArmed = false
          this.voiceLevel = 10
        }
        return
      }

      const t = text.trim()
      if (t.length === 0) {
        AppToast.show('未识别到语音，请长按重试', 2000)
        if (this.appendMode && this.appendBaseText.trim().length > 0) {
          this.transcriptDraft = this.appendBaseText
          this.mode = 'transcriptCard'
        } else if (this.appendMode) {
          this.mode = 'transcriptCard'
        } else {
          this.mode = 'keyboard'
        }
        this.livePartial = ''
        this.cancelArmed = false
        this.appendMode = false
        this.appendBaseText = ''
        return
      }

      if (this.appendMode && this.appendBaseText.trim().length > 0) {
        this.transcriptDraft = this.appendBaseText + '\n' + t
      } else {
        this.transcriptDraft = t
      }
      this.livePartial = ''
      this.cancelArmed = false
      this.cardEditing = false
      this.appendMode = false
      this.appendBaseText = ''
      this.mode = 'transcriptCard'
    }, (err: string) => {
      SpeechService.setLevelCallback(null)
      SpeechService.setPartialCallback(null)
      this.stopVoiceTimer()
      this.voiceEnding = false
      if (this.appendMode && this.appendBaseText.trim().length > 0) {
        this.transcriptDraft = this.appendBaseText
        this.mode = 'transcriptCard'
      } else if (this.transcriptDraft.trim().length > 0) {
        this.mode = 'transcriptCard'
      } else {
        this.mode = 'keyboard'
      }
      this.livePartial = ''
      this.cancelArmed = false
      this.appendMode = false
      this.appendBaseText = ''
      AppToast.show(err.length > 0 ? err : '未能识别，请重试或改用文字输入', 2500)
    }, context)
  }

  private onVoicePressMove(deltaY: number): void {
    if (this.mode !== 'voiceFullscreen') {
      return
    }
    this.cancelArmed = deltaY >= AILiveOverlay.VOICE_CANCEL_SLIDE_VP
  }

  private onVoicePressEnd(): void {
    this.finishVoiceHold()
  }

  /** 松手结束听写（InputBar 延续 touch；全屏层不拦截命中） */
  private finishVoiceHold(): void {
    if (this.mode !== 'voiceFullscreen' || this.voiceEnding) {
      return
    }
    this.voiceEnding = true
    const elapsed = Date.now() - this.voicePressStartMs
    if (elapsed < AILiveOverlay.VOICE_HOLD_MIN_MS || this.cancelArmed) {
      // 上滑/过短：先退全屏再 cancel，避免等硬件释放卡顿
      this.leaveVoiceFullscreenCancelled()
      SpeechService.stop(true)
      return
    }
    if (SpeechService.isRecognizing()) {
      SpeechService.stop(false)
    } else {
      this.mode = this.appendMode && this.appendBaseText.trim().length > 0 ? 'transcriptCard' : 'keyboard'
      this.voiceEnding = false
    }
  }

  /** 取消听写时立刻卸全屏层（Speech 回调可能稍后到达，需幂等） */
  private leaveVoiceFullscreenCancelled(): void {
    SpeechService.setLevelCallback(null)
    SpeechService.setPartialCallback(null)
    this.stopVoiceTimer()
    if (this.appendMode && this.appendBaseText.trim().length > 0) {
      this.transcriptDraft = this.appendBaseText
      this.mode = 'transcriptCard'
    } else if (this.appendMode) {
      this.mode = 'transcriptCard'
    } else {
      this.mode = 'keyboard'
    }
    this.livePartial = ''
    this.cancelArmed = false
    this.appendMode = false
    this.appendBaseText = ''
    this.voiceLevel = 10
    this.voiceEnding = false
  }

  private onTranscriptRerecord(): void {
    this.clearTranscriptState()
    this.mode = 'keyboard'
  }

  private onTranscriptStartEdit(): void {
    this.cardEditBackup = this.transcriptDraft
    this.cardEditing = true
  }

  private onTranscriptEditCancel(): void {
    this.transcriptDraft = this.cardEditBackup
    this.cardEditing = false
  }

  private onTranscriptEditDone(text: string): void {
    this.transcriptDraft = text
    this.cardEditing = false
    if (this.transcriptDraft.trim().length === 0) {
      AppToast.show('内容为空', 1500)
    }
  }

  private onTranscriptParse(): void {
    const t = this.transcriptDraft.trim()
    if (t.length === 0) {
      AppToast.show('内容为空', 1500)
      return
    }
    this.cardEditing = false
    this.parseText(t)
  }

  /**
   * 图片录入
   */
  private async imageInput(source: string = 'album', returnToKeyboard: boolean = false): Promise<void> {
    if (this.recognizing) {
      return
    }
    // 有未解析转写时进媒体：丢弃卡片（规格）
    if (this.mode === 'transcriptCard' || this.mode === 'voiceFullscreen') {
      if (SpeechService.isRecognizing()) {
        SpeechService.stop(true)
      }
      this.clearTranscriptState()
    }
    this.recognizing = true
    if (this.mode === 'keyboard' || this.mode === 'transcriptCard' || this.mode === 'voiceFullscreen') {
      this.mode = 'picking'
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      this.recognizing = false
      AppToast.show(ErrorMessages.CONTEXT_UNAVAILABLE, 2000)
      if (returnToKeyboard) {
        this.mode = 'keyboard'
      } else {
        this.close()
      }
      return
    }

    let pixelMap: image.PixelMap | null = null
    let fileName = ''
    let pickError = ''
    if (source === 'camera') {
      const captured = await OcrService.captureImageToPixelMap(context)
      pixelMap = captured.pixelMap
      fileName = captured.fileName
      pickError = captured.error
    } else {
      const picked = await OcrService.pickImageToPixelMap(context)
      pixelMap = picked.pixelMap
      fileName = picked.fileName
      pickError = picked.error
    }
    if (!pixelMap) {
      this.recognizing = false
      if (pickError.length > 0) {
        AppToast.show(pickError, 2500)
      }
      if (returnToKeyboard) {
        this.mode = 'keyboard'
      } else {
        this.close()
      }
      return
    }

    this.mode = 'scanning'
    this.startScanAnim()
    const scanStarted = Date.now()
    let handled = false
    try {
      // 识别可并行跑完，但结果必须等满 SCAN_MIN_MS 再上屏，否则本地规则毫秒级结束，动画一闪而过
      const outcome = await AIParseOrchestrator.parsePixelMap(pixelMap, fileName)
      const elapsed = Date.now() - scanStarted
      const remain = AILiveOverlay.SCAN_MIN_MS - elapsed
      if (remain > 0) {
        await this.delayMs(remain)
      }
      // 仍停在 scanning 才应用结果（用户中途关闭则不再改 mode）
      // 注意：勿写 mode !== 'scanning' 后早退再比 confirm——ArkTS 会把 mode 收窄成字面量 scanning
      if (this.mode === 'scanning') {
        if (outcome.path === 'vision_cloud') {
          AppToast.show('AI 识图', 1200)
        }
        if (outcome.kind === 'vision' && outcome.visionResult !== null) {
          await this.applyParseResult(outcome.visionResult)
          handled = this.isPostScanResultMode()
        } else {
          const msg = outcome.message.length > 0 ? outcome.message : AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL
          const needConfig = this.isConfigRelatedMessage(msg)
          this.markMessage(msg, !needConfig, needConfig)
          handled = true
        }
      } else {
        handled = true
      }
    } catch (_err) {
      // 异常也先撑满最短动画再提示
      const elapsed = Date.now() - scanStarted
      const remain = AILiveOverlay.SCAN_MIN_MS - elapsed
      if (remain > 0 && this.mode === 'scanning') {
        await this.delayMs(remain)
      }
      if (this.mode === 'scanning') {
        this.markMessage(AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL, true, false)
        handled = true
      }
    } finally {
      try {
        pixelMap.release()
      } catch (_e) {
      }
      this.stopScanAnim()
      this.recognizing = false
      // 仍停在 scanning：成功路径应已切到 confirm/message；此处只收尾残留 scanning
      if (this.mode === 'scanning') {
        if (handled) {
          this.markMessage(AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL, true, false)
        } else if (returnToKeyboard) {
          this.mode = 'keyboard'
          AppToast.show(AIParseOrchestrator.MSG_EMPTY_IMAGE, 2000)
        } else {
          AppToast.show(AIParseOrchestrator.MSG_EMPTY_IMAGE, 2000)
          this.close()
        }
      }
    }
  }

  private async savePending(): Promise<void> {
    if (this.pendingItem === null || this.saving) {
      return
    }
    this.saving = true
    try {
      await AILiveSaveService.saveParseItem(this.pendingItem)
      WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
      LiveViewService.refresh()
      // 从多条列表点进详情保存：移除该项后回到列表（若还有剩余）
      if (this.listRows.length > 0 && this.pendingItems.length > 1) {
        this.removePendingAt(this.currentItemIndex)
        Constants.notifyListRefresh()
        if (this.pendingItems.length > 1) {
          this.buildListRows(this.pendingItems)
          this.pendingItem = null
          this.mode = 'confirmList'
          AppToast.show(ErrorMessages.SAVED, 1500)
        } else if (this.pendingItems.length === 1) {
          const only = this.pendingItems[0]
          this.listRows = []
          this.pendingItem = only
          this.currentItemIndex = 0
          await this.fillPreview(only)
          this.mode = 'confirm'
          AppToast.show('已保存，请确认最后一条', 1500)
        } else {
          AppToast.show(ErrorMessages.SAVE_OK, 2000)
          this.inputText = ''
          this.finishToIdle()
        }
      } else {
        AppToast.show(ErrorMessages.SAVE_OK, 2000)
        Constants.notifyListRefresh()
        this.pendingItem = null
        this.pendingItems = []
        this.listRows = []
        this.currentItemIndex = 0
        this.inputText = ''
        this.finishToIdle()
      }
    } catch (err) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 3000)
    } finally {
      this.saving = false
    }
  }

  /** 多条列表：批量入库已勾选且完整的条目 */
  private async saveSelectedList(): Promise<void> {
    if (this.saving) {
      return
    }
    const selectedIndices: number[] = []
    let incompleteSelected = 0
    for (let i = 0; i < this.listRows.length; i++) {
      const row = this.listRows[i]
      if (!row.selected) {
        continue
      }
      if (!row.complete) {
        incompleteSelected++
        continue
      }
      selectedIndices.push(row.index)
    }
    if (selectedIndices.length === 0) {
      if (incompleteSelected > 0) {
        AppToast.show('勾选项信息不完整，请使用「表单补全」后再保存', 2500)
      } else {
        AppToast.show('请先勾选要入库的记录', 2000)
      }
      return
    }
    this.saving = true
    const successIndices: number[] = []
    let fail = 0
    try {
      for (let k = 0; k < selectedIndices.length; k++) {
        const idx = selectedIndices[k]
        if (idx < 0 || idx >= this.pendingItems.length) {
          fail++
          continue
        }
        try {
          await AILiveSaveService.saveParseItem(this.pendingItems[idx])
          successIndices.push(idx)
        } catch (_e) {
          fail++
        }
      }
      const remain: ParseResultItem[] = []
      for (let i = 0; i < this.pendingItems.length; i++) {
        let done = false
        for (let s = 0; s < successIndices.length; s++) {
          if (successIndices[s] === i) {
            done = true
            break
          }
        }
        if (!done) {
          remain.push(this.pendingItems[i])
        }
      }
      this.pendingItems = remain
      if (successIndices.length > 0) {
        WidgetUpdateService.updateAll(this.getUIContext().getHostContext() as Context)
        LiveViewService.refresh()
      }
      Constants.notifyListRefresh()
      if (successIndices.length > 0 && remain.length === 0) {
        AppToast.show('已保存 ' + successIndices.length.toString() + ' 条', 2000)
        this.inputText = ''
        this.finishToIdle()
      } else if (successIndices.length > 0 && remain.length > 0) {
        AppToast.show('已保存 ' + successIndices.length.toString() + ' 条，剩余 ' +
          remain.length.toString() + ' 条待处理', 2500)
        if (remain.length === 1) {
          this.listRows = []
          this.pendingItem = remain[0]
          this.currentItemIndex = 0
          await this.fillPreview(remain[0])
          if (remain[0].isComplete) {
            this.mode = 'confirm'
          } else {
            this.markMessage('仍有一条信息不完整，可补充说明，或使用表单补全已识别字段。', true, false)
          }
        } else {
          this.buildListRows(remain)
          this.pendingItem = null
          this.mode = 'confirmList'
        }
      } else {
        AppToast.show(fail > 0 ? ErrorMessages.SAVE_FAILED : '请先勾选要入库的记录', 2500)
      }
    } catch (_err) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 3000)
    } finally {
      this.saving = false
    }
  }

  private removePendingAt(index: number): void {
    const remain: ParseResultItem[] = []
    for (let i = 0; i < this.pendingItems.length; i++) {
      if (i !== index) {
        remain.push(this.pendingItems[i])
      }
    }
    this.pendingItems = remain
  }

  private discardPending(): void {
    this.finishToIdle()
  }

  /** 详情确认返回多条列表（未保存） */
  private backToListFromDetail(): void {
    if (this.pendingItems.length > 1) {
      this.buildListRows(this.pendingItems)
      this.pendingItem = null
      this.mode = 'confirmList'
      return
    }
    this.discardPending()
  }

  private editPending(): void {
    if (this.pendingItem === null) {
      return
    }
    this.pushFormWithPending()
  }

  /** 失败救场：带 partial 进表单 */
  private rescueToForm(): void {
    if (this.pendingItem !== null) {
      this.pushFormWithPending()
      return
    }
    // 无 partial：默认负债表单
    this.close()
    AppRouter.push(RouteNames.DEBT_FORM)
  }

  private pushFormWithPending(): void {
    if (this.pendingItem === null) {
      return
    }
    const item = this.pendingItem
    if (item.recordType === 'credit_account') {
      const draft = AILiveCreditAccountDraft.fromParseItem(item)
      AppStorage.setOrCreate(AILiveDraftKeys.CREDIT_ACCOUNT, draft.encode())
      this.close()
      AppRouter.push(RouteNames.CREDIT_ACCOUNT_FORM)
    } else if (item.recordType === 'subscription') {
      const draft = AILiveSubscriptionDraft.fromParseItem(item)
      AppStorage.setOrCreate(AILiveDraftKeys.SUBSCRIPTION, draft.encode())
      this.close()
      AppRouter.push(RouteNames.SUBSCRIPTION_FORM)
    } else {
      const draft = AILiveDebtDraft.fromParseItem(item)
      AppStorage.setOrCreate(AILiveDraftKeys.DEBT, draft.encode())
      this.close()
      AppRouter.push(RouteNames.DEBT_FORM)
    }
  }

  private goConfigure(): void {
    this.close()
    AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 4)
    AppStorage.setOrCreate(AILiveDraftKeys.OPEN_AI_SHEET, true)
  }

  private onMaskClick(): void {
    // scanning 允许点遮罩取消；确认/解析/听写等态不关
    if (this.mode === 'confirm' || this.mode === 'confirmList' || this.mode === 'parsing' ||
      this.mode === 'picking' || this.mode === 'voiceFullscreen') {
      return
    }
    if (Date.now() < this.suppressMaskCloseUntil) {
      return
    }
    // 紧凑提示半页：点遮罩等同重新描述 / 收起
    if (this.mode === 'message') {
      this.retryDescribe()
      return
    }
    // 识别中：先切走 mode，避免异步解析回来仍写结果
    if (this.mode === 'scanning') {
      this.mode = 'keyboard'
      this.stopScanAnim()
      this.recognizing = false
      AppToast.show('已取消识别', 1200)
      this.close()
      return
    }
    this.close()
  }

  private partialSummary(): string {
    if (this.pendingItem === null) {
      return ''
    }
    const f = this.pendingItem.parsedFields
    const parts: string[] = []
    if (this.pendingItem.recordType === 'credit_account') {
      const name = `${f.get('name') ?? ''}`
      if (name.length > 0) {
        parts.push('名称 ' + name)
      }
      const lastFour = `${f.get('last_four') ?? ''}`
      if (lastFour.length > 0) {
        parts.push('尾号 ' + lastFour)
      }
      const limit = f.get('credit_limit')
      if (limit !== undefined && limit !== null && `${limit}`.length > 0) {
        parts.push('额度 ' + `${limit}`)
      }
    } else if (this.pendingItem.recordType === 'subscription') {
      const name = `${f.get('name') ?? f.get('platform') ?? ''}`
      if (name.length > 0) {
        parts.push('订阅 ' + name)
      }
      const amt = f.get('amount') ?? f.get('current_balance')
      if (amt !== undefined && amt !== null && `${amt}`.length > 0) {
        parts.push('每期 ' + `${amt}`)
      }
      const cycle = `${f.get('billing_cycle') ?? ''}`
      if (cycle.length > 0) {
        parts.push(cycle)
      }
    } else {
      const platform = `${f.get('platform') ?? f.get('name') ?? ''}`
      if (platform.length > 0) {
        parts.push('平台 ' + platform)
      }
      const amt = f.get('current_balance') ?? f.get('amount') ?? f.get('principal')
      if (amt !== undefined && amt !== null && `${amt}`.length > 0) {
        parts.push('金额 ' + `${amt}`)
      }
      const totalP = f.get('total_periods')
      const remainP = f.get('remaining_periods')
      if (totalP !== undefined && totalP !== null && `${totalP}`.length > 0) {
        parts.push('总期数 ' + `${totalP}`)
        if (remainP !== undefined && remainP !== null && `${remainP}`.length > 0) {
          parts.push('剩余 ' + `${remainP}`)
        }
      } else if (remainP !== undefined && remainP !== null && `${remainP}`.length > 0) {
        parts.push('剩余期数 ' + `${remainP}`)
      } else {
        parts.push('期数 未识别')
      }
      const monthly = f.get('monthly_payment')
      if (monthly !== undefined && monthly !== null && `${monthly}`.length > 0) {
        parts.push('月供 ' + `${monthly}`)
      }
      const dt = `${f.get('debt_type') ?? ''}`
      const totalNum = Number(`${totalP ?? 0}`)
      if (dt === 'installment' || totalNum > 1) {
        parts.push('分期')
      } else if (dt.length > 0) {
        parts.push(dt === 'credit_card' ? '一次性' : dt)
      }
    }
    return parts.length > 0 ? '已识别：' + parts.join(' · ') : ''
  }

  build() {
    if (!this.show) {
      // 不占位
    } else {
      Stack({ alignContent: Alignment.Bottom }) {
        if (this.mode === 'picking') {
          // 空壳，等系统 Picker
        } else {
          // 全屏遮罩：压暗 + 极轻 blur（折中「太糊 / 太透」）
          // 层次靠 aiMaskDim；blur 只 radius 10 级柔边，勿叠 AdaptiveColor
          // scanning 识别态再压一层，避免截图底图太透
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(this.mode === 'scanning'
              ? (this.theme.isDarkCanvas() ? 'rgba(0, 0, 0, 0.58)' : 'rgba(0, 0, 0, 0.36)')
              : this.theme.aiMaskDim())
            .backgroundEffect({
              radius: this.theme.aiGlassBlurRadius(),
              saturation: this.theme.aiGlassSaturation(),
              brightness: this.theme.aiGlassBrightness(),
              color: this.theme.aiGlassTint()
            })
            .onClick(() => this.onMaskClick())

          // 提示/配置：底部紧凑半页，避免大片空白
          if (this.mode === 'message') {
            Column({ space: 0 }) {
              this.panelChrome()
              Column({ space: 10 }) {
                this.messageBody()
              }
              .width('100%')
              .padding({
                left: 16,
                right: 16,
                bottom: this.bottomSafe > 0 ? this.bottomSafe + 8 : 16
              })
            }
            .width('100%')
            .backgroundColor(this.theme.sheetBackground())
            .borderRadius({ topLeft: this.theme.sheetRadius, topRight: this.theme.sheetRadius })
            .border({
              width: { top: 0.5, left: 0, right: 0, bottom: 0 },
              color: this.theme.sheetEdgeColor()
            })
          } else if (this.mode === 'scanning' || this.mode === 'confirmList') {
            Column() {
              Row()
                .width('100%')
                .height(this.topSafe)

              Column() {
                if (this.mode === 'scanning') {
                  AILiveScanView({
                    theme: this.theme,
                    scanProgress: this.scanProgress,
                    sparklePhase: this.sparklePhase,
                    bottomSafe: this.bottomSafe
                  })
                } else {
                  Column({ space: 0 }) {
                    this.panelChrome()
                    Column({ space: 10 }) {
                      this.confirmListBody()
                    }
                    .layoutWeight(1)
                    .width('100%')
                    .padding({
                      left: 16,
                      right: 16,
                      bottom: this.bottomSafe > 0 ? this.bottomSafe + 8 : 12
                    })
                  }
                  .width('100%')
                  .height('100%')
                }
              }
              .layoutWeight(1)
              .width('100%')
              .backgroundColor(this.mode === 'scanning' ? Color.Transparent : this.theme.sheetBackground())
              .borderRadius({ topLeft: this.theme.sheetRadius, topRight: this.theme.sheetRadius })
              .border(this.mode === 'scanning' ? { width: 0 } : {
                width: { top: 0.5, left: 0, right: 0, bottom: 0 },
                color: this.theme.sheetEdgeColor()
              })
              .clip(true)
              // 识别舞台不抢点击，点空白落到遮罩以取消
              .hitTestBehavior(this.mode === 'scanning' ? HitTestMode.None : HitTestMode.Default)
            }
            .width('100%')
            .height('100%')
            .hitTestBehavior(this.mode === 'scanning' ? HitTestMode.None : HitTestMode.Default)
          } else if (this.mode === 'parsing' || this.mode === 'confirm') {
            Column({ space: 0 }) {
              this.panelChrome()
              Column({ space: 10 }) {
                if (this.mode === 'parsing') {
                  this.parsingBody()
                } else {
                  this.confirmBody()
                }
              }
              .width('100%')
              .padding({
                left: 16,
                right: 16,
                bottom: this.bottomSafe > 0 ? this.bottomSafe + 8 : 16
              })
            }
            .width('100%')
            .backgroundColor(this.theme.sheetBackground())
            .borderRadius({ topLeft: this.theme.sheetRadius, topRight: this.theme.sheetRadius })
            .border({
              width: { top: 0.5, left: 0, right: 0, bottom: 0 },
              color: this.theme.sheetEdgeColor()
            })
          } else if (this.mode === 'keyboard' || this.mode === 'transcriptCard' ||
            this.mode === 'voiceFullscreen') {
            // voiceFullscreen 时仍挂载 InputBar，保证按住 touch 不被拆掉
            // transcriptCard 弹窗需要 sheetBackground + 顶圆角 + 顶发丝线，与 message/parsing/confirm 保持一致；
            // 否则浅色主题下弹窗与页面近白融平，听写卡片像是"飘"在页面上、没有容器。
            Column({ space: 8 }) {
              if (this.mode === 'transcriptCard') {
                AILiveTranscriptCard({
                  theme: this.theme,
                  draftText: this.transcriptDraft,
                  elapsedSec: this.sessionElapsedSec,
                  editing: this.cardEditing,
                  onRerecord: () => {
                    this.onTranscriptRerecord()
                  },
                  onStartEdit: () => {
                    this.onTranscriptStartEdit()
                  },
                  onEditCancel: () => {
                    this.onTranscriptEditCancel()
                  },
                  onEditDone: (text: string) => {
                    this.onTranscriptEditDone(text)
                  },
                  onParse: () => {
                    this.onTranscriptParse()
                  }
                })
              }
              if (!this.cardEditing) {
                AILiveInputBar({
                  theme: this.theme,
                  inputText: this.inputText,
                  recognizing: this.recognizing,
                  barMode: (this.mode === 'transcriptCard' || this.appendMode) ? 'transcript' : 'idle',
                  leftPrimary: this.leftPrimary,
                  mediaVisible: this.mediaVisible,
                  onCamera: () => {
                    this.imageInput('camera', true)
                  },
                  onAlbum: () => {
                    this.imageInput('album', true)
                  },
                  onTextChange: (v: string) => {
                    this.inputText = v
                  },
                  onSend: () => {
                    this.sendText()
                  },
                  onVoicePressStart: () => {
                    this.onVoicePressStart()
                  },
                  onVoicePressMove: (deltaY: number) => {
                    this.onVoicePressMove(deltaY)
                  },
                  onVoicePressEnd: () => {
                    this.onVoicePressEnd()
                  }
                })
              }
            }
            .width('100%')
            .padding({
              left: 14,
              right: 14,
              top: this.mode === 'voiceFullscreen' ? 0 : 16,
              bottom: this.bottomSafe > 0 ? this.bottomSafe + 8 : 16
            })
            .backgroundColor(this.mode === 'voiceFullscreen' ? Color.Transparent : this.theme.sheetBackground())
            .borderRadius({ topLeft: this.theme.sheetRadius, topRight: this.theme.sheetRadius })
            .border(this.mode === 'voiceFullscreen' ? { width: 0 } : {
              width: { top: 0.5, left: 0, right: 0, bottom: 0 },
              color: this.theme.sheetEdgeColor()
            })
          }

          // 全屏视觉盖顶，但不抢 touch（延续麦钮按住）
          if (this.mode === 'voiceFullscreen') {
            AILiveVoiceFullscreen({
              theme: this.theme,
              partialText: this.livePartial,
              voiceLevel: this.voiceLevel,
              elapsedSec: this.voiceElapsedSec,
              cancelArmed: this.cancelArmed,
              appendMode: this.appendMode,
              bottomSafe: this.bottomSafe
            })
              .hitTestBehavior(HitTestMode.None)
          }
        }
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
  }

  @Builder
  panelChrome() {
    SheetHeader({
      theme: this.theme,
      title: this.panelTitle(),
      onClose: () => this.close()
    })
  }

  private panelTitle(): string {
    if (this.mode === 'confirmList') {
      return '确认录入 · ' + this.listRows.length.toString() + ' 条'
    }
    if (this.mode === 'confirm') {
      return this.listRows.length > 0 || this.pendingItems.length > 1 ? '确认详情' : '确认录入'
    }
    if (this.mode === 'parsing') {
      return '解析中'
    }
    if (this.mode === 'message') {
      if (this.showConfigCta) {
        return '需要配置'
      }
      return this.showFormRescue ? '需要补充' : '提示'
    }
    return '添加记录'
  }

  @Builder
  parsingBody() {
    Column({ space: 10 }) {
      ThinkingOrb({ theme: this.theme, orbSize: 64, orbState: 'working' })
      Text('正在核对名称、金额等关键信息…')
        .fontSize(TypeScale.bodySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text2)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: 24, bottom: 24 })
  }

  @Builder
  confirmBody() {
    Column({ space: 14 }) {
      if (this.pendingItems.length > 1) {
        Row() {
          Text('← 列表')
            .fontSize(TypeScale.bodySm)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text2)
            .onClick(() => this.backToListFromDetail())
          Blank()
          Text((this.currentItemIndex + 1) + ' / ' + this.pendingItems.length)
            .fontSize(TypeScale.caption)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text3)
        }
        .width('100%')
      }

      // 单张预览卡：完整编辑按握姿贴主手一侧；底栏保存同侧
      AIParsePreviewCard({
        theme: this.theme,
        title: this.previewTitle,
        amountText: this.previewAmount,
        metaLine: this.previewMeta,
        mark: this.previewMark,
        avatarColor: this.previewColor,
        iconUrl: this.previewIconUrl,
        typeLabel: this.previewTypeLabel,
        leftPrimary: this.leftPrimary,
        onFullEdit: () => {
          this.editPending()
        }
      })

      // 底栏：握姿镜像——左手保存在左，右手保存在右
      Row({ space: 8 }) {
        if (this.leftPrimary) {
          this.confirmSaveBtn()
          this.confirmDiscardBtn()
        } else {
          this.confirmDiscardBtn()
          this.confirmSaveBtn()
        }
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  confirmDiscardBtn() {
    Button(this.pendingItems.length > 1 ? '返回列表' : '丢弃')
      .layoutWeight(1)
      .height(42)
      .fontSize(TypeScale.control)
      .fontColor(this.theme.text2)
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: this.theme.border })
      .borderRadius(this.theme.radiusSm)
      .onClick(() => {
        if (this.pendingItems.length > 1) {
          this.backToListFromDetail()
        } else {
          this.discardPending()
        }
      })
  }

  @Builder
  confirmSaveBtn() {
    Button(this.saving ? '…' : '保存')
      .layoutWeight(1.2)
      .height(42)
      .fontSize(TypeScale.control)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.ctaForeground())
      .backgroundColor(this.theme.ctaBackground())
      .borderRadius(this.theme.radiusSm)
      .enabled(!this.saving)
      .onClick(() => {
        this.savePending()
      })
  }

  @Builder
  confirmListBody() {
    Column({ space: 10 }) {
      Row() {
        Text('识别到 ' + this.listRows.length.toString() + ' 条，勾选后一次入库')
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text2)
          .layoutWeight(1)
        Text(this.allSelected() ? '取消全选' : '全选')
          .fontSize(TypeScale.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .onClick(() => this.setAllListSelected(!this.allSelected()))
      }
      .width('100%')

      Scroll() {
        Column({ space: 8 }) {
          ForEach(this.listRows, (row: ConfirmListRow) => {
            AILiveConfirmRowItem({
              theme: this.theme,
              row: row,
              onToggle: (index: number) => this.toggleListRow(index),
              onDetail: (index: number) => this.openListItemDetail(index),
              onEditForm: (index: number) => this.editListItemForm(index)
            })
          }, (row: ConfirmListRow) => 'r' + row.index.toString() + '_' + (row.selected ? '1' : '0') +
            '_' + (row.complete ? 'c' : 'i'))
        }
        .width('100%')
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)

      // 握姿镜像：确认入库贴主手一侧
      Row({ space: 8 }) {
        if (this.leftPrimary) {
          this.confirmListSaveBtn()
          this.confirmListDiscardBtn()
        } else {
          this.confirmListDiscardBtn()
          this.confirmListSaveBtn()
        }
      }
      .width('100%')
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  confirmListDiscardBtn() {
    Button('丢弃全部')
      .layoutWeight(1)
      .height(42)
      .fontSize(TypeScale.control)
      .fontColor(this.theme.text2)
      .backgroundColor(Color.Transparent)
      .border({ width: 1, color: this.theme.border })
      .borderRadius(this.theme.radiusSm)
      .enabled(!this.saving)
      .onClick(() => this.discardPending())
  }

  @Builder
  confirmListSaveBtn() {
    Button(this.saving ? '…' :
      ('确认入库' + (this.selectedCount() > 0 ? ' ' + this.selectedCount().toString() : '')))
      .layoutWeight(1.35)
      .height(42)
      .fontSize(TypeScale.control)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.theme.ctaForeground())
      .backgroundColor(this.theme.ctaBackground())
      .borderRadius(this.theme.radiusSm)
      .enabled(!this.saving)
      .onClick(() => {
        this.saveSelectedList()
      })
  }

  @Builder
  messageBody() {
    Column({ space: 14 }) {
      Text(this.statusText)
        .fontSize(TypeScale.control)
        .fontColor(this.theme.text2)
        .width('100%')
        .lineHeight(20)

      // 仅真正识别失败/不完整时展示已识别片段
      if (!this.showConfigCta && this.partialSummary().length > 0) {
        Text(this.partialSummary())
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text2)
          .width('100%')
          .padding(12)
          .borderRadius(this.theme.radiusSm)
          .backgroundColor(this.theme.sheetItemBackground())
          .border({ width: 1, color: this.theme.borderStrong })
      }

      Column({ space: 8 }) {
        // 未配置 AI：未进入识别 → 只引导配置，不给出表单
        if (this.showConfigCta) {
          Button('去配置 AI 解析')
            .width('100%')
            .height(44)
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.ctaForeground())
            .backgroundColor(this.theme.ctaBackground())
            .borderRadius(this.theme.radiusSm)
            .onClick(() => this.goConfigure())
        }
        // 表单仅在「真正识别失败/不完整」时出现
        if (this.showFormRescue) {
          Button('用表单补全')
            .width('100%')
            .height(44)
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.ctaForeground())
            .backgroundColor(this.theme.ctaBackground())
            .borderRadius(this.theme.radiusSm)
            .onClick(() => this.rescueToForm())
        }
        Button(this.showFormRescue || this.showConfigCta ? '重新输入' : '返回')
          .width('100%')
          .height(42)
          .fontSize(TypeScale.control)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text2)
          .backgroundColor(Color.Transparent)
          .border({ width: 1, color: this.theme.border })
          .borderRadius(this.theme.radiusSm)
          .onClick(() => this.retryDescribe())
      }
      .width('100%')
      .margin({ top: 4 })
    }
    .width('100%')
  }
}
