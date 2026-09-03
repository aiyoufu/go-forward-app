import { LiveViewLockScreenExtensionAbility } from '@kit.LiveViewKit'
import { UIExtensionContentSession, Want } from '@kit.AbilityKit'
import { BusinessError, commonEventManager } from '@kit.BasicServicesKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import {
  LiveLockPayload,
  LIVE_LOCK_EVENT,
  LIVE_LOCK_STORAGE_KEY
} from 'service'

const TAG = 'LiveViewLockScreen'
const DOMAIN = 0x0000

/**
 * 锁屏沉浸实况窗 Extension
 * 官方：bpta-lock-screen-immersive-live-window
 * - onSessionCreate 加载锁屏页
 * - 订阅公共事件接收主进程刷新数据
 */
export default class LiveViewLockScreenAbility extends LiveViewLockScreenExtensionAbility {
  private subscriber: commonEventManager.CommonEventSubscriber | null = null
  private lastSequence: number = -1

  onCreate(): void {
    hilog.info(DOMAIN, TAG, 'onCreate')
  }

  onSessionCreate(want: Want, session: UIExtensionContentSession): void {
    hilog.info(DOMAIN, TAG, 'onSessionCreate')
    const storage = new LocalStorage()
    // 初始参数（创建实况窗时传入）
    try {
      const params = want?.parameters
      if (params !== undefined && params !== null) {
        const raw = params['payload'] as string
        if (raw !== undefined && raw !== null && raw.length > 0) {
          const p = JSON.parse(raw) as LiveLockPayload
          storage.setOrCreate(LIVE_LOCK_STORAGE_KEY, p)
          AppStorage.setOrCreate(LIVE_LOCK_STORAGE_KEY, p)
          if (p.sequence > 0) {
            this.lastSequence = p.sequence
          }
        }
      }
    } catch (_e) {
      hilog.warn(DOMAIN, TAG, 'parse want parameters failed')
    }
    if (storage.get(LIVE_LOCK_STORAGE_KEY) === undefined) {
      storage.setOrCreate(LIVE_LOCK_STORAGE_KEY, LiveLockPayload.empty())
      AppStorage.setOrCreate(LIVE_LOCK_STORAGE_KEY, LiveLockPayload.empty())
    }

    try {
      // 路径相对 entry/src/main/ets（无 .ets 后缀）
      session.loadContent('liveview/LockScreenLivePage', storage)
    } catch (e) {
      const err = e as BusinessError
      hilog.error(DOMAIN, TAG, 'loadContent failed: %{public}s', err.message ?? '')
    }

    this.subscribeUpdates()
  }

  onSessionDestroy(session: UIExtensionContentSession): void {
    hilog.info(DOMAIN, TAG, 'onSessionDestroy')
    this.unsubscribeUpdates()
  }

  onDestroy(): void {
    this.unsubscribeUpdates()
  }

  private subscribeUpdates(): void {
    const info: commonEventManager.CommonEventSubscribeInfo = {
      events: [LIVE_LOCK_EVENT],
      publisherBundleName: 'com.goforward.app',
      priority: 0
    }
    commonEventManager.createSubscriber(info,
      (error: BusinessError, data: commonEventManager.CommonEventSubscriber) => {
        if (error) {
          hilog.error(DOMAIN, TAG, 'createSubscriber failed: %{public}s', error.message)
          return
        }
        this.subscriber = data
        commonEventManager.subscribe(this.subscriber,
          (err: BusinessError, eventData: commonEventManager.CommonEventData) => {
            if (err) {
              hilog.error(DOMAIN, TAG, 'subscribe failed: %{public}s', err.message)
              return
            }
            try {
              const params = eventData.parameters
              if (params === undefined || params === null) {
                return
              }
              const raw = params['payload'] as string
              if (raw === undefined || raw === null || raw.length === 0) {
                return
              }
              const p = JSON.parse(raw) as LiveLockPayload
              if (p.sequence > 0 && p.sequence < this.lastSequence) {
                return
              }
              this.lastSequence = p.sequence
              AppStorage.setOrCreate(LIVE_LOCK_STORAGE_KEY, p)
            } catch (_e) {
              hilog.warn(DOMAIN, TAG, 'update payload parse failed')
            }
          })
      })
  }

  private unsubscribeUpdates(): void {
    if (this.subscriber === null) {
      return
    }
    try {
      commonEventManager.unsubscribe(this.subscriber, (error: BusinessError) => {
        if (error) {
          hilog.warn(DOMAIN, TAG, 'unsubscribe: %{public}s', error.message)
        }
      })
    } catch (_e) {
    }
    this.subscriber = null
  }
}
