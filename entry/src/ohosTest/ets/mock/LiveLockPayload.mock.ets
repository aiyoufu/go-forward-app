// LiveLockPayload.mock.ets — entry 模块测试用
export const LIVE_LOCK_EVENT = 'com.goforward.app.LIVE_LOCK'
export const LIVE_LOCK_STORAGE_KEY = 'live_lock_payload'

export class LiveLockPayload {
  sequence: number = 0
  title: string = ''
  subtitle: string = ''
  detail: string = ''

  static empty(): LiveLockPayload {
    return new LiveLockPayload()
  }
}
