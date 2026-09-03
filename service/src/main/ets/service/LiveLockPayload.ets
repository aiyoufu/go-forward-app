/**
 * 主进程 → 锁屏沉浸实况窗 数据契约
 * 经 liveViewLockScreenAbilityParameters + 公共事件传递
 */
export class LiveLockPayload {
  title: string = ''
  /** 胶囊/副标题：如「3 笔 · ¥1,200」 */
  summary: string = ''
  /** 明细行（最多 2 条） */
  line1: string = ''
  line2: string = ''
  moreText: string = ''
  /** 强调色（hex） */
  accentColor: string = '#0F1419'
  /** 0 无 / 1 今日 / 2 逾期 / 3 本周密集 */
  status: number = 0
  /** 单调序号，便于丢弃乱序事件 */
  sequence: number = 0

  static empty(): LiveLockPayload {
    return new LiveLockPayload()
  }
}

/** 公共事件名（与主进程 publish / Extension subscribe 一致） */
export const LIVE_LOCK_EVENT: string = 'goforward_live_view_lock_screen'
/** AppStorage / LocalStorage 键 */
export const LIVE_LOCK_STORAGE_KEY: string = 'liveLockPayload'
