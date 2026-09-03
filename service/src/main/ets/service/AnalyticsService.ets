import { util } from '@kit.ArkTS'
import { picker } from '@kit.CoreFileKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { AppStorageKeys } from 'common'
import { Logger } from 'common'
import { CryptoService } from './auth/CryptoService'
import { DbService } from './DbService'
import { PreferencesService } from './PreferencesService'
import { UserService } from './UserService'

/**
 * 分析埋点（docs/product/ANALYTICS_EVENTS.md v1）
 * - 业务只调 track / 语义封装方法
 * - 本地环形缓冲 + hilog；exportJson 可导出
 * - 不上报邮箱、token、单据正文、图片
 */
export class AnalyticsService {
  private static readonly TAG: string = 'Analytics'
  private static readonly PREF_ANON: string = 'analytics_anon_id'
  private static readonly PREF_BUF: string = 'analytics_event_buf_v1'
  private static readonly PREF_EVER: string = 'analytics_ever_record'
  private static readonly MAX_BUF: number = 200

  private static enabled: boolean = true
  private static sessionId: string = ''
  private static coldPending: boolean = true
  private static foregroundAt: number = 0
  private static buffer: string[] = []
  private static ready: boolean = false
  private static appVer: string = '1.0.0'
  private static buildCode: number = 1000000
  private static nextRecordSource: string = 'manual_form'
  private static nextAiLaunch: string = 'keyboard'
  private static persistTimer: number = -1

  static setEnabled(on: boolean): void {
    AnalyticsService.enabled = on
  }

  static setAppMeta(versionName: string, versionCode: number): void {
    if (versionName.length > 0) {
      AnalyticsService.appVer = versionName
    }
    if (versionCode > 0) {
      AnalyticsService.buildCode = versionCode
    }
  }

  /** 下一条 record_create_* 的 source（consume 后恢复 manual_form） */
  static setNextRecordSource(source: string): void {
    AnalyticsService.nextRecordSource = source.length > 0 ? source : 'manual_form'
  }

  static consumeRecordSource(): string {
    const s = AnalyticsService.nextRecordSource
    AnalyticsService.nextRecordSource = 'manual_form'
    return s
  }

  static setNextAiLaunch(mode: string): void {
    AnalyticsService.nextAiLaunch = mode.length > 0 ? mode : 'keyboard'
  }

  static consumeAiLaunch(): string {
    const s = AnalyticsService.nextAiLaunch
    AnalyticsService.nextAiLaunch = 'keyboard'
    return s
  }

  static async init(): Promise<void> {
    if (AnalyticsService.ready) {
      return
    }
    try {
      await AnalyticsService.ensureAnonId()
      const raw = await PreferencesService.getString(AnalyticsService.PREF_BUF, '')
      if (raw.length > 2) {
        // ArkTS：JSON.parse 需显式断言，禁止落入 any/unknown
        const parsed: Object = JSON.parse(raw) as Object
        if (parsed instanceof Array) {
          const arr = parsed as Object[]
          const lines: string[] = []
          for (let i = 0; i < arr.length; i++) {
            if (typeof arr[i] === 'string') {
              lines.push(arr[i] as string)
            }
          }
          AnalyticsService.buffer = lines.slice(-AnalyticsService.MAX_BUF)
        }
      }
    } catch (_e) {
      AnalyticsService.buffer = []
    }
    if (AnalyticsService.sessionId.length === 0) {
      AnalyticsService.sessionId = AnalyticsService.newId()
    }
    AnalyticsService.ready = true
  }

  /**
   * @param name 事件名
   * @param extraJson 仅专用属性的 JSON 对象字符串，如 {"cold":true}
   */
  static track(name: string, extraJson: string = '{}'): void {
    if (!AnalyticsService.enabled || name.length === 0) {
      return
    }
    AnalyticsService.trackAsync(name, extraJson).catch((e: Error) => {
      Logger.warn(AnalyticsService.TAG, 'track fail: ' + e.message)
    })
  }

  private static async trackAsync(name: string, extraJson: string): Promise<void> {
    await AnalyticsService.init()
    const baseJson = await AnalyticsService.buildBaseJson()
    const extraTrim = extraJson.trim().length > 0 ? extraJson.trim() : '{}'
    // 合并：{"event":"...", ...base, ...extra}
    let extraBody = extraTrim
    if (extraBody.startsWith('{')) {
      extraBody = extraBody.substring(1)
    }
    if (extraBody.endsWith('}')) {
      extraBody = extraBody.substring(0, extraBody.length - 1)
    }
    let baseBody = baseJson
    if (baseBody.startsWith('{')) {
      baseBody = baseBody.substring(1)
    }
    if (baseBody.endsWith('}')) {
      baseBody = baseBody.substring(0, baseBody.length - 1)
    }
    let line = '{"event":' + JSON.stringify(name)
    if (baseBody.length > 0) {
      line += ',' + baseBody
    }
    if (extraBody.length > 0) {
      line += ',' + extraBody
    }
    line += '}'
    AnalyticsService.buffer.push(line)
    while (AnalyticsService.buffer.length > AnalyticsService.MAX_BUF) {
      AnalyticsService.buffer.shift()
    }
    Logger.info(AnalyticsService.TAG, name + ' ' + extraJson)
    AnalyticsService.schedulePersist()
  }

  private static schedulePersist(): void {
    if (AnalyticsService.persistTimer !== -1) {
      return
    }
    AnalyticsService.persistTimer = setTimeout(() => {
      AnalyticsService.persistTimer = -1
      AnalyticsService.persistBuffer().catch(() => {
      })
    }, 400) as number
  }

  private static async persistBuffer(): Promise<void> {
    try {
      await PreferencesService.putString(
        AnalyticsService.PREF_BUF,
        JSON.stringify(AnalyticsService.buffer)
      )
    } catch (_e) {
    }
  }

  static async exportJson(): Promise<string> {
    await AnalyticsService.init()
    await AnalyticsService.persistBuffer()
    return '[' + AnalyticsService.buffer.join(',') + ']'
  }

  static async clearBuffer(): Promise<void> {
    AnalyticsService.buffer = []
    await PreferencesService.putString(AnalyticsService.PREF_BUF, '[]')
  }

  static bufferSize(): number {
    return AnalyticsService.buffer.length
  }

  /** Debug：导出环形缓冲为 JSON 文件 */
  static async saveBufferToFile(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const json = await AnalyticsService.exportJson()
      const documentSaveOptions = new picker.DocumentSaveOptions()
      documentSaveOptions.newFileNames = ['analytics_' + Date.now().toString() + '.json']
      const documentPicker = new picker.DocumentViewPicker(context)
      const result = await documentPicker.save(documentSaveOptions)
      if (!result || result.length === 0) {
        return false
      }
      const uri = result[0]
      const file = fileIo.openSync(uri, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      const encoder = new util.TextEncoder()
      const buffer = encoder.encodeInto(json)
      fileIo.writeSync(file.fd, buffer.buffer)
      fileIo.closeSync(file)
      return true
    } catch (_e) {
      return false
    }
  }

  static trackCrash(message: string): void {
    const m = message.length > 200 ? message.substring(0, 200) : message
    AnalyticsService.track('app_crash', '{"message":' + JSON.stringify(m) + '}')
  }

  // —— 语义封装 ——

  static trackLaunch(cold: boolean): void {
    AnalyticsService.track('app_launch', '{"cold":' + (cold ? 'true' : 'false') + '}')
  }

  static trackForeground(): void {
    AnalyticsService.foregroundAt = Date.now()
    const cold = AnalyticsService.coldPending
    AnalyticsService.coldPending = false
    AnalyticsService.trackLaunch(cold)
    AnalyticsService.track('app_foreground', '{}')
  }

  static trackBackground(): void {
    const ms = AnalyticsService.foregroundAt > 0
      ? Date.now() - AnalyticsService.foregroundAt
      : 0
    AnalyticsService.track('app_background', '{"foreground_ms":' + ms + '}')
  }

  static trackPrivacyAccept(from: string): void {
    AnalyticsService.track('privacy_accept', '{"from":' + JSON.stringify(from) + '}')
  }

  static trackOnboardingComplete(): void {
    AnalyticsService.track('onboarding_complete', '{}')
  }

  static async trackRecordCreateSuccess(kind: string): Promise<void> {
    const source = AnalyticsService.consumeRecordSource()
    const ever = await PreferencesService.getBool(AnalyticsService.PREF_EVER, false)
    const isFirst = !ever
    if (isFirst) {
      await PreferencesService.putBool(AnalyticsService.PREF_EVER, true)
    }
    AnalyticsService.track('record_create_success',
      '{"kind":' + JSON.stringify(kind) +
      ',"source":' + JSON.stringify(source) +
      ',"is_first_ever":' + (isFirst ? 'true' : 'false') + '}')
  }

  static trackRecordCreateFail(kind: string, reason: string): void {
    const source = AnalyticsService.consumeRecordSource()
    AnalyticsService.track('record_create_fail',
      '{"kind":' + JSON.stringify(kind) +
      ',"source":' + JSON.stringify(source) +
      ',"reason":' + JSON.stringify(reason) + '}')
  }

  static trackTabView(tab: string): void {
    AnalyticsService.track('tab_view', '{"tab":' + JSON.stringify(tab) + '}')
  }

  static trackHomeActionTap(kind: string, urgency: string, action: string): void {
    AnalyticsService.track('home_action_tap',
      '{"kind":' + JSON.stringify(kind) +
      ',"urgency":' + JSON.stringify(urgency) +
      ',"action":' + JSON.stringify(action) + '}')
  }

  static trackRepaySuccess(mode: string): void {
    AnalyticsService.track('repay_success', '{"mode":' + JSON.stringify(mode) + '}')
  }

  static trackRepayFail(reason: string): void {
    AnalyticsService.track('repay_fail', '{"reason":' + JSON.stringify(reason) + '}')
  }

  static trackAiLiveOpen(): void {
    const launch = AnalyticsService.consumeAiLaunch()
    AnalyticsService.track('ai_live_open', '{"launch":' + JSON.stringify(launch) + '}')
  }

  static trackAiParseResult(ok: boolean, channel: string, itemCount: number, failStage: string = ''): void {
    let j = '{"ok":' + (ok ? 'true' : 'false') +
      ',"channel":' + JSON.stringify(channel) +
      ',"item_count":' + itemCount
    if (failStage.length > 0) {
      j += ',"fail_stage":' + JSON.stringify(failStage)
    }
    j += '}'
    AnalyticsService.track('ai_parse_result', j)
  }

  static trackAuthSuccess(method: string): void {
    AnalyticsService.track('auth_success', '{"method":' + JSON.stringify(method) + '}')
  }

  static trackAuthFail(method: string, reason: string): void {
    const r = reason.length > 80 ? reason.substring(0, 80) : reason
    AnalyticsService.track('auth_fail',
      '{"method":' + JSON.stringify(method) + ',"reason":' + JSON.stringify(r) + '}')
  }

  static trackSyncResult(ok: boolean, trigger: string, errorCode: string = ''): void {
    let j = '{"ok":' + (ok ? 'true' : 'false') + ',"trigger":' + JSON.stringify(trigger)
    if (errorCode.length > 0) {
      const code = errorCode.length > 64 ? errorCode.substring(0, 64) : errorCode
      j += ',"error_code":' + JSON.stringify(code)
    }
    j += '}'
    AnalyticsService.track('sync_result', j)
  }

  private static async buildBaseJson(): Promise<string> {
    const anon = await AnalyticsService.ensureAnonId()
    const theme = AnalyticsService.readTheme()
    const cloud = await AnalyticsService.isCloudUser()
    const hasBiz = await AnalyticsService.hasBusinessCached()
    let j = '{"ts":' + Date.now() +
      ',"session_id":' + JSON.stringify(AnalyticsService.sessionId) +
      ',"app_ver":' + JSON.stringify(AnalyticsService.appVer) +
      ',"build":' + AnalyticsService.buildCode +
      ',"os_ver":""' +
      ',"device_class":"phone"' +
      ',"theme":' + JSON.stringify(theme) +
      ',"user_state":' + JSON.stringify(cloud ? 'cloud' : 'guest') +
      ',"has_business":' + (hasBiz ? 'true' : 'false') +
      ',"anon_id":' + JSON.stringify(anon)
    if (cloud) {
      const uid = UserService.getCurrentUserId()
      if (uid.length > 0) {
        const h = await AnalyticsService.hashUserId(uid)
        if (h.length > 0) {
          j += ',"user_id_hash":' + JSON.stringify(h)
        }
      }
    }
    j += '}'
    return j
  }

  private static async ensureAnonId(): Promise<string> {
    let id = await PreferencesService.getString(AnalyticsService.PREF_ANON, '')
    if (id.length === 0) {
      id = AnalyticsService.newId()
      await PreferencesService.putString(AnalyticsService.PREF_ANON, id)
    }
    return id
  }

  private static newId(): string {
    try {
      return util.generateRandomUUID()
    } catch (_e) {
      return 'a' + Date.now().toString(16) + Math.floor(Math.random() * 1e6).toString(16)
    }
  }

  private static readTheme(): string {
    const dark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK)
    if (dark === true) {
      return 'dark'
    }
    if (dark === false) {
      return 'light'
    }
    return 'unknown'
  }

  private static async isCloudUser(): Promise<boolean> {
    try {
      // 与 AuthManager.KEY_MODE 同值；不 import AuthManager 以免循环依赖
      const mode = await PreferencesService.getString('auth_mode', '')
      return mode === 'cloud'
    } catch (_e) {
      return false
    }
  }

  private static async hasBusinessCached(): Promise<boolean> {
    const ever = await PreferencesService.getBool(AnalyticsService.PREF_EVER, false)
    if (ever) {
      return true
    }
    try {
      if (!DbService.isReady()) {
        return false
      }
      const uid = UserService.getCurrentUserId()
      if (uid.length === 0) {
        return false
      }
      const n = await AnalyticsService.countRows('debts', uid)
        + await AnalyticsService.countRows('subscriptions', uid)
        + await AnalyticsService.countRows('credit_accounts', uid)
      if (n > 0) {
        await PreferencesService.putBool(AnalyticsService.PREF_EVER, true)
        return true
      }
      return false
    } catch (_e) {
      return false
    }
  }

  private static async countRows(table: string, uid: string): Promise<number> {
    const rs = await DbService.query(
      'SELECT COUNT(1) AS c FROM ' + table + ' WHERE user_id = ?',
      [uid]
    )
    let n = 0
    try {
      if (rs.goToNextRow()) {
        n = Number(rs.getLong(rs.getColumnIndex('c'))) || 0
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return n
  }

  private static async hashUserId(uid: string): Promise<string> {
    try {
      const bytes = CryptoService.stringToBytes(uid)
      const dig = await CryptoService.sha256(bytes)
      let hex = ''
      const lim = dig.length < 8 ? dig.length : 8
      for (let i = 0; i < lim; i++) {
        const h = dig[i].toString(16)
        hex += h.length === 1 ? '0' + h : h
      }
      return hex
    } catch (_e) {
      return ''
    }
  }
}
