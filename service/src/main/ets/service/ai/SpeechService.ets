import { speechRecognizer } from '@kit.CoreSpeechKit'
import { Logger } from 'common'
import { audio } from '@kit.AudioKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { Utils } from 'common'

/**
 * 鸿蒙系统语音转文字（CoreSpeechKit），仅产出文本。
 * 不对接第三方「语音 LLM」；转写结果交 AIParseOrchestrator.parseText（文字解析渠道）。
 * 策略见 docs/deprecated/ai-voice-deprecation.md。
 */

/** 听写结束：text 为转写文案；cancelled 为 true 表示用户取消，勿解析 */
export type SpeechResultCallback = (text: string, cancelled: boolean) => void
export type SpeechLevelCallback = (level: number) => void
/** 听写过程累计文本（与 final 同一累加策略，供全屏实时展示） */
export type SpeechPartialCallback = (accumulatedText: string) => void

/**
 * 鸿蒙 Core Speech Kit 语音识别（端侧听写）。
 * 官方：@kit.CoreSpeechKit · speechRecognizer
 * 仅产出文本，结构化交给 AIParseOrchestrator（本地规则 / 文字 LLM）。
 */
export class SpeechService {
  private static engine: speechRecognizer.SpeechRecognitionEngine | null = null
  private static capturer: audio.AudioCapturer | null = null
  private static sessionId: string = ''
  private static recognizedText: string = ''
  private static resolveCallback: SpeechResultCallback | null = null
  private static rejectCallback: ((err: string) => void) | null = null
  private static levelCallback: SpeechLevelCallback | null = null
  private static partialCallback: SpeechPartialCallback | null = null
  private static isRunning: boolean = false
  private static cancelled: boolean = false
  private static finished: boolean = false
  /** 启动链路是否完成（引擎+采集器就绪）；未完成时 engine.finish 无从触发系统回调 */
  private static startReady: boolean = false
  /** 会话代号：每次 recognize 自增；旧会话的异步续体据此判失效，防快速连点竞态 */
  private static sessionGen: number = 0

  /** 当前调用是否已过期（被新按压接管 / 已结案 / 已取消） */
  private static stale(gen: number): boolean {
    return gen !== SpeechService.sessionGen || SpeechService.finished || SpeechService.cancelled
  }

  /** 会话已结案但硬件可能晚到：补一次延迟卸载；已被新会话接管则不动共享状态 */
  private static abandonIfStale(gen: number): void {
    if (gen !== SpeechService.sessionGen || (!SpeechService.finished && !SpeechService.cancelled)) {
      return
    }
    SpeechService.releaseHardwareDeferred(gen)
  }

  /**
   * 设备是否声明语音识别能力（供 UI 展示；未知时返回 true，由引擎启动结果兜底）。
   */
  static isAvailable(): boolean {
    try {
      if (canIUse('SystemCapability.AI.SpeechRecognizer')) {
        return true
      }
      // 部分 SDK 版本 capability 字符串不同
      return canIUse('SystemCapability.Voice.SpeechRecognizer')
    } catch (_e) {
      return true
    }
  }

  static setLevelCallback(cb: SpeechLevelCallback | null): void {
    SpeechService.levelCallback = cb
  }

  static setPartialCallback(cb: SpeechPartialCallback | null): void {
    SpeechService.partialCallback = cb
  }

  static isRecognizing(): boolean {
    return SpeechService.isRunning
  }

  static async recognize(
    callback: SpeechResultCallback,
    onError: (err: string) => void,
    context?: common.UIAbilityContext
  ): Promise<void> {
    if (SpeechService.isRunning) {
      onError('正在识别中，请稍候')
      return
    }
    // 上一次会话可能残留未卸硬件（快速连点），先同步清场再开新会话
    SpeechService.releaseHardware()
    const gen: number = SpeechService.sessionGen + 1
    SpeechService.sessionGen = gen
    SpeechService.isRunning = true
    SpeechService.cancelled = false
    SpeechService.finished = false
    SpeechService.startReady = false
    SpeechService.recognizedText = ''
    SpeechService.resolveCallback = callback
    SpeechService.rejectCallback = onError
    SpeechService.sessionId = Utils.generateId()

    try {
      if (context !== undefined && context !== null) {
        const ok = await SpeechService.ensureMicPermission(context)
        if (!ok) {
          SpeechService.failAndCleanup('需要麦克风权限才能语音录入', gen)
          return
        }
        if (SpeechService.stale(gen)) {
          SpeechService.abandonIfStale(gen)
          return
        }
      }

      await SpeechService.createEngine(gen)
      if (SpeechService.stale(gen)) {
        SpeechService.abandonIfStale(gen)
        return
      }
      SpeechService.setListener(gen)
      await SpeechService.createCapturer()
      if (SpeechService.stale(gen)) {
        SpeechService.abandonIfStale(gen)
        return
      }
      SpeechService.startListening()
      await SpeechService.startCapture()
      if (SpeechService.stale(gen)) {
        SpeechService.abandonIfStale(gen)
        return
      }
      SpeechService.startReady = true
    } catch (err) {
      if (SpeechService.stale(gen)) {
        // 已取消/已被接管：stop 路径或新会话负责收尾，此处静默退出
        SpeechService.abandonIfStale(gen)
        return
      }
      SpeechService.failAndCleanup('系统听写启动失败: ' + SpeechService.friendlyError(err), gen)
    }
  }

  private static async ensureMicPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const permission: Permissions = 'ohos.permission.MICROPHONE'
      const status = await atManager.checkAccessToken(context.applicationInfo.accessTokenId, permission)
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true
      }
      const result = await atManager.requestPermissionsFromUser(context, [permission])
      if (result.authResults !== undefined && result.authResults.length > 0) {
        return result.authResults[0] === 0
      }
      return false
    } catch (_e) {
      return true
    }
  }

  private static isBizError(err: BusinessError | undefined | null): boolean {
    return err !== undefined && err !== null && err.code !== undefined && err.code !== 0
  }

  private static friendlyError(err: Object | BusinessError | string | undefined | null): string {
    const raw = SpeechService.errorMessage(err)
    const lower = raw.toLowerCase()
    if (lower.indexOf('system error') >= 0 || lower.indexOf('system_error') >= 0) {
      return '系统听写不可用（模拟器常无麦克风，请用真机或改键盘录入）'
    }
    if (raw.indexOf('201') >= 0 || lower.indexOf('permission') >= 0) {
      return '麦克风权限被拒绝或设备不支持'
    }
    return raw
  }

  private static errorMessage(err: Object | BusinessError | string | undefined | null): string {
    if (err === undefined || err === null) {
      return '未知错误'
    }
    if (typeof err === 'string') {
      return err
    }
    try {
      const be = err as BusinessError
      if (be.message !== undefined && be.message !== null && `${be.message}`.length > 0) {
        return `${be.message}`
      }
      if (be.code !== undefined && be.code !== null) {
        return '错误码 ' + be.code
      }
    } catch (_e) {
    }
    try {
      return JSON.stringify(err)
    } catch (_e2) {
    }
    return '未知错误'
  }

  /**
   * 结束识别。
   * @param cancel true=取消：立即中止 UI 回调，硬件异步释放（避免上滑取消卡顿）
   */
  static stop(cancel: boolean = false): void {
    if (!cancel && !SpeechService.isRunning) {
      return
    }
    const gen: number = SpeechService.sessionGen
    if (cancel) {
      SpeechService.cancelled = true
      SpeechService.recognizedText = ''
      SpeechService.completeCancel(gen)
      return
    }
    // 启动链路未完成（权限/建引擎/开麦仍在途）时 engine.finish 无从触发系统回调，
    // 全屏会永远停在「正在听你说」；按已累计文本就地结案（通常为空）
    if (!SpeechService.startReady || SpeechService.engine === null || SpeechService.engine === undefined) {
      SpeechService.finishWithResult(gen)
      return
    }
    try {
      if (SpeechService.engine && SpeechService.sessionId.length > 0) {
        SpeechService.engine.finish(SpeechService.sessionId)
      }
      if (SpeechService.capturer) {
        SpeechService.capturer.stop()
      }
    } catch (_err) {
      // finish 抛错也要兜底结案，避免 UI 卡在全屏
      SpeechService.finishWithResult(gen)
    }
  }

  private static completeCancel(gen: number): void {
    if (gen !== SpeechService.sessionGen) {
      return
    }
    if (SpeechService.finished) {
      // 启动竞态：cancel 后仍可能 createEngine 成功，需再卸硬件
      SpeechService.releaseHardwareDeferred(gen)
      return
    }
    SpeechService.finished = true
    const cb = SpeechService.resolveCallback
    SpeechService.isRunning = false
    SpeechService.startReady = false
    SpeechService.resolveCallback = null
    SpeechService.rejectCallback = null
    SpeechService.partialCallback = null
    SpeechService.levelCallback = null
    // 先回调让 UI 立刻退全屏，再异步卸麦/引擎
    if (cb !== null) {
      cb('', true)
    }
    SpeechService.releaseHardwareDeferred(gen)
  }

  private static failAndCleanup(msg: string, gen: number): void {
    if (gen !== SpeechService.sessionGen) {
      return
    }
    if (SpeechService.finished) {
      SpeechService.releaseHardwareDeferred(gen)
      return
    }
    SpeechService.finished = true
    const errCb = SpeechService.rejectCallback
    SpeechService.isRunning = false
    SpeechService.cancelled = false
    SpeechService.startReady = false
    SpeechService.resolveCallback = null
    SpeechService.rejectCallback = null
    SpeechService.partialCallback = null
    SpeechService.levelCallback = null
    if (errCb !== null) {
      errCb(msg)
    }
    SpeechService.releaseHardwareDeferred(gen)
  }

  private static async createEngine(gen: number): Promise<void> {
    try {
      await SpeechService.createEngineWithOnline(gen, 0)
    } catch (_offlineErr) {
      await SpeechService.createEngineWithOnline(gen, 1)
    }
  }

  private static createEngineWithOnline(gen: number, online: number): Promise<void> {
    return new Promise<void>((resolve, reject) => {
      const params: speechRecognizer.CreateEngineParams = {
        language: 'zh-CN',
        online: online
      }
      speechRecognizer.createEngine(params, (err: BusinessError, engine: speechRecognizer.SpeechRecognitionEngine) => {
        if (SpeechService.stale(gen)) {
          // 会话已被接管或已结案：卸掉刚建好的引擎，不碰共享状态
          if (!SpeechService.isBizError(err) && engine !== undefined && engine !== null) {
            try {
              engine.shutdown()
            } catch (_e) {
            }
          }
          resolve()
          return
        }
        if (SpeechService.isBizError(err)) {
          reject(err)
          return
        }
        if (engine === undefined || engine === null) {
          reject({ code: -1, message: '语音引擎创建失败' } as BusinessError)
          return
        }
        SpeechService.engine = engine
        resolve()
      })
    })
  }

  private static setListener(gen: number): void {
    if (!SpeechService.engine) {
      return
    }
    SpeechService.engine.setListener({
      onStart: (_sessionId: string, _eventMessage: string) => {
        // 不记录听写原文 / 事件体，避免财务口述进日志
      },
      onEvent: (_sessionId: string, _eventCode: number, _eventMessage: string) => {
      },
      onResult: (_sessionId: string, result: speechRecognizer.SpeechRecognitionResult) => {
        if (gen !== SpeechService.sessionGen || SpeechService.cancelled || SpeechService.finished) {
          return
        }
        if (result.result !== undefined && result.result.length > 0) {
          // CoreSpeechKit onResult 流式回调返回的是当前全量文本，直接覆盖而非累加
          SpeechService.recognizedText = result.result
          if (SpeechService.partialCallback !== null) {
            SpeechService.partialCallback(SpeechService.recognizedText)
          }
        }
        if (result.isLast) {
          SpeechService.finishWithResult(gen)
        }
      },
      onComplete: (_sessionId: string, _eventMessage: string) => {
        SpeechService.finishWithResult(gen)
      },
      onError: (_sessionId: string, errorCode: number, errorMessage: string) => {
        if (gen !== SpeechService.sessionGen || SpeechService.cancelled || SpeechService.finished) {
          return
        }
        Logger.error('SpeechService', 'SpeechRecognition error code=' + errorCode)
        const msg = SpeechService.friendlyError({
          code: errorCode,
          message: errorMessage
        } as BusinessError)
        SpeechService.failAndCleanup(msg, gen)
      }
    })
  }

  private static finishWithResult(gen: number): void {
    if (gen !== SpeechService.sessionGen) {
      return
    }
    if (SpeechService.finished) {
      return
    }
    if (SpeechService.cancelled) {
      SpeechService.completeCancel(gen)
      return
    }
    SpeechService.finished = true
    const cb = SpeechService.resolveCallback
    const text = SpeechService.recognizedText
    SpeechService.isRunning = false
    SpeechService.startReady = false
    SpeechService.resolveCallback = null
    SpeechService.rejectCallback = null
    SpeechService.partialCallback = null
    SpeechService.levelCallback = null
    if (cb !== null) {
      cb(text, false)
    }
    SpeechService.releaseHardwareDeferred(gen)
  }

  private static async createCapturer(): Promise<void> {
    const audioStreamInfo: audio.AudioStreamInfo = {
      samplingRate: audio.AudioSamplingRate.SAMPLE_RATE_16000,
      channels: audio.AudioChannel.CHANNEL_1,
      sampleFormat: audio.AudioSampleFormat.SAMPLE_FORMAT_S16LE,
      encodingType: audio.AudioEncodingType.ENCODING_TYPE_RAW
    }
    const capturerInfo: audio.AudioCapturerInfo = {
      source: audio.SourceType.SOURCE_TYPE_MIC,
      capturerFlags: 0
    }
    const options: audio.AudioCapturerOptions = {
      streamInfo: audioStreamInfo,
      capturerInfo: capturerInfo
    }
    try {
      SpeechService.capturer = await audio.createAudioCapturer(options)
    } catch (err) {
      throw new Error('无法打开麦克风: ' + SpeechService.errorMessage(err as Object))
    }
  }

  private static startListening(): void {
    if (!SpeechService.engine) {
      return
    }
    const startParams: speechRecognizer.StartParams = {
      sessionId: SpeechService.sessionId,
      audioInfo: {
        audioType: 'pcm',
        sampleRate: 16000,
        soundChannel: 1,
        sampleBit: 16
      }
    }
    try {
      SpeechService.engine.startListening(startParams)
    } catch (_e) {
    }
  }

  private static async startCapture(): Promise<void> {
    if (!SpeechService.capturer) {
      return
    }
    // read() 已废弃，改用 on('readData') 事件驱动接收 PCM
    try {
      SpeechService.capturer.on('readData', SpeechService.onAudioData)
    } catch (_e) {
    }
    await SpeechService.capturer.start()
  }

  /** 麦克风数据回调：驱动电平动画并投喂识别引擎 */
  private static onAudioData(audioBuffer: ArrayBuffer): void {
    if (!SpeechService.isRunning || SpeechService.cancelled || SpeechService.finished) {
      return
    }
    if (audioBuffer === undefined || audioBuffer === null || audioBuffer.byteLength === 0) {
      return
    }
    if (SpeechService.levelCallback !== null) {
      SpeechService.levelCallback(SpeechService.pcmLevel(audioBuffer))
    }
    if (SpeechService.engine !== null) {
      const audioData = new Uint8Array(audioBuffer)
      try {
        SpeechService.engine.writeAudio(SpeechService.sessionId, audioData)
      } catch (_e) {
      }
    }
  }

  /** PCM s16le → 柱高 4~28 */
  private static pcmLevel(buf: ArrayBuffer): number {
    const view = new Int16Array(buf)
    if (view.length === 0) {
      return 4
    }
    let sum = 0
    const step = Math.max(1, Math.floor(view.length / 80))
    let n = 0
    for (let i = 0; i < view.length; i += step) {
      const v = view[i] / 32768
      sum += v * v
      n++
    }
    const rms = Math.sqrt(sum / Math.max(1, n))
    const boosted = Math.min(1, rms * 6)
    return Math.min(28, Math.max(4, Math.round(4 + boosted * 24)))
  }

  /**
   * 下一 macrotask 卸硬件，避免 stop/shutdown/release 堵 UI 线程。
   * 会话已被新按压接管则跳过（新 recognize 入口已同步清场），防止误杀新会话引擎。
   */
  private static releaseHardwareDeferred(gen: number): void {
    setTimeout(() => {
      if (gen !== SpeechService.sessionGen) {
        return
      }
      SpeechService.releaseHardware()
    }, 0)
  }

  private static releaseHardware(): void {
    try {
      if (SpeechService.engine) {
        try {
          SpeechService.engine.shutdown()
        } catch (_e) {
        }
        SpeechService.engine = null
      }
    } catch (_e2) {
    }
    try {
      if (SpeechService.capturer) {
        try {
          SpeechService.capturer.off('readData', SpeechService.onAudioData)
        } catch (_e6) {
        }
        try {
          SpeechService.capturer.stop()
        } catch (_e3) {
        }
        try {
          SpeechService.capturer.release()
        } catch (_e4) {
        }
        SpeechService.capturer = null
      }
    } catch (_e5) {
    }
  }
}
