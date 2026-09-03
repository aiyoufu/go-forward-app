import { sensor } from '@kit.SensorServiceKit'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'

interface AmbientLightData {
  intensity: number
}

export class LightReading {
  lux: number = 0
  timestamp: number = 0
}

export type LightListener = (reading: LightReading) => void

export class LightSensorService {
  /** 引用计数：多页面共享同一订阅，避免重复 sensor.on 与误删他人订阅 */
  private static listeners: LightListener[] = []
  private static subscribed: boolean = false
  private static lastLux: number = -1
  private static lastEmittedLux: number = -1
  private static lastEmitTime: number = 0
  /** 最小上报间隔，避免高频 UI 全量刷新卡死 */
  private static readonly EMIT_INTERVAL_MS: number = 900
  /** 亮度变化阈值，过小也会刷屏 */
  private static readonly EMIT_DELTA: number = 40
  private static lowLightStartTime: number = 0
  private static highLightStartTime: number = 0
  private static eyeCareReminderShown: boolean = false

  /** 注册监听。重复注册与多页面共享均安全，仅在首个监听时真正订阅传感器 */
  static start(onChange: LightListener): void {
    LightSensorService.addListener(onChange)
    LightSensorService.subscribeIfNeeded()
  }

  /** 注销监听，须传入 start 时的同一引用；无监听者时自动断开传感器省电 */
  static stop(onChange?: LightListener): void {
    if (onChange !== undefined && onChange !== null) {
      LightSensorService.removeListener(onChange)
    } else {
      LightSensorService.listeners = []
    }
    if (LightSensorService.listeners.length === 0) {
      LightSensorService.unsubscribe()
    }
  }

  /** 应用退到后台：断开传感器省电，但保留监听列表，回前台可恢复 */
  static suspend(): void {
    LightSensorService.unsubscribe()
  }

  /** 应用回前台：若仍有监听者则恢复订阅 */
  static resume(): void {
    if (LightSensorService.listeners.length > 0) {
      LightSensorService.subscribeIfNeeded()
    }
  }

  private static subscribeIfNeeded(): void {
    if (LightSensorService.subscribed) {
      return
    }
    try {
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, (data: AmbientLightData) => {
        LightSensorService.handleSample(data.intensity)
      })
      LightSensorService.subscribed = true
    } catch (err) {
    }
  }

  private static unsubscribe(): void {
    if (!LightSensorService.subscribed) {
      return
    }
    try {
      sensor.off(sensor.SensorId.AMBIENT_LIGHT)
    } catch (err) {
    }
    LightSensorService.subscribed = false
  }

  private static handleSample(lux: number): void {
    LightSensorService.lastLux = lux
    LightSensorService.checkEyeCare(lux)

    // 节流：时间间隔 + 变化量，防止 ambientLux 风暴拖垮主线程
    const now = Date.now()
    const delta = Math.abs(lux - LightSensorService.lastEmittedLux)
    const elapsed = now - LightSensorService.lastEmitTime
    if (LightSensorService.lastEmittedLux >= 0 && delta < LightSensorService.EMIT_DELTA &&
      elapsed < LightSensorService.EMIT_INTERVAL_MS) {
      return
    }
    LightSensorService.lastEmittedLux = lux
    LightSensorService.lastEmitTime = now

    const reading = new LightReading()
    reading.lux = lux
    reading.timestamp = now
    const list = LightSensorService.listeners
    for (let i = 0; i < list.length; i++) {
      try {
        list[i](reading)
      } catch (_e) {
      }
    }
  }

  private static addListener(listener: LightListener): void {
    const next: LightListener[] = []
    for (let i = 0; i < LightSensorService.listeners.length; i++) {
      if (LightSensorService.listeners[i] !== listener) {
        next.push(LightSensorService.listeners[i])
      }
    }
    next.push(listener)
    LightSensorService.listeners = next
  }

  private static removeListener(listener: LightListener): void {
    const next: LightListener[] = []
    for (let i = 0; i < LightSensorService.listeners.length; i++) {
      if (LightSensorService.listeners[i] !== listener) {
        next.push(LightSensorService.listeners[i])
      }
    }
    LightSensorService.listeners = next
  }

  static getLastLux(): number {
    return LightSensorService.lastLux
  }

  static recommendBrightness(lux: number): number {
    if (lux < 10) {
      return 0.3
    }
    if (lux < 100) {
      return 0.5
    }
    if (lux < 1000) {
      return 0.7
    }
    return 1.0
  }

  static getGlowIntensity(lux: number): number {
    if (lux < 50) {
      return 0.6
    }
    if (lux < 500) {
      return 0.3
    }
    return 0.0
  }

  private static checkEyeCare(lux: number): void {
    const now = Date.now()
    if (lux < 10) {
      if (LightSensorService.lowLightStartTime === 0) {
        LightSensorService.lowLightStartTime = now
      }
      if (now - LightSensorService.lowLightStartTime > 5 * 60 * 1000 && !LightSensorService.eyeCareReminderShown) {
        LightSensorService.eyeCareReminderShown = true
        AppToast.show(ErrorMessages.LIGHT_DARK, 3000)
      }
      LightSensorService.highLightStartTime = 0
    } else if (lux > 10000) {
      if (LightSensorService.highLightStartTime === 0) {
        LightSensorService.highLightStartTime = now
      }
      if (now - LightSensorService.highLightStartTime > 3 * 60 * 1000 && !LightSensorService.eyeCareReminderShown) {
        LightSensorService.eyeCareReminderShown = true
        AppToast.show(ErrorMessages.LIGHT_BRIGHT, 3000)
      }
      LightSensorService.lowLightStartTime = 0
    } else {
      LightSensorService.lowLightStartTime = 0
      LightSensorService.highLightStartTime = 0
      LightSensorService.eyeCareReminderShown = false
    }
  }
}
