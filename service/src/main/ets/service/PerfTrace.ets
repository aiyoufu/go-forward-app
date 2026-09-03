import { Logger } from 'common'

/**
 * 冷启动 / 首屏可观测点（hilog tag=Perf）
 * T0：进程 Ability onCreate
 * T1：路由进入 Main（Splash 放行）
 * T2：首页 loadHome 完成
 * 过滤：hdc shell hilog | grep Perf
 */
export class PerfTrace {
  private static t0: number = 0
  private static lastMarkAt: number = 0
  private static t1Ms: number = -1
  private static t2Ms: number = -1

  /** Ability 进程入口调用一次 */
  static boot(): void {
    PerfTrace.t0 = Date.now()
    PerfTrace.lastMarkAt = PerfTrace.t0
    PerfTrace.t1Ms = -1
    PerfTrace.t2Ms = -1
    Logger.info('Perf', 'T0 boot')
  }

  /** 相对 T0 的毫秒；未 boot 时以本次为 T0 */
  static mark(name: string): number {
    const now = Date.now()
    if (PerfTrace.t0 <= 0) {
      PerfTrace.t0 = now
      PerfTrace.lastMarkAt = now
    }
    const fromBoot = now - PerfTrace.t0
    const fromLast = now - PerfTrace.lastMarkAt
    PerfTrace.lastMarkAt = now
    if (name === 'T1_main_nav') {
      PerfTrace.t1Ms = fromBoot
    } else if (name === 'T2_home_ready') {
      PerfTrace.t2Ms = fromBoot
    }
    Logger.info('Perf', name + ' +' + fromBoot + 'ms (Δ' + fromLast + 'ms)')
    return fromBoot
  }

  static getT1Ms(): number {
    return PerfTrace.t1Ms
  }

  static getT2Ms(): number {
    return PerfTrace.t2Ms
  }
}
