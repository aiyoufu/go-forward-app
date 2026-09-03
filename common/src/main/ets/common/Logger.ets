import { hilog } from '@kit.PerformanceAnalysisKit'

/** 应用统一日志域，hilog 可按 domain/tag 过滤 */
const LOG_DOMAIN: number = 0xC0F0

/**
 * 统一日志出口：service/executor 层禁用 console.*，一律走 hilog。
 * release 包可通过系统 hilog 等级开关（hdc shell hilog -b）统一控制输出。
 */
export class Logger {
  static debug(tag: string, msg: string): void {
    hilog.debug(LOG_DOMAIN, tag, '%{public}s', msg)
  }

  static info(tag: string, msg: string): void {
    hilog.info(LOG_DOMAIN, tag, '%{public}s', msg)
  }

  static warn(tag: string, msg: string): void {
    hilog.warn(LOG_DOMAIN, tag, '%{public}s', msg)
  }

  static error(tag: string, msg: string): void {
    hilog.error(LOG_DOMAIN, tag, '%{public}s', msg)
  }
}
