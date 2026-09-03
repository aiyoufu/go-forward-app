/**
 * 通用「请求 - 重试 - 退避」执行器。
 * 从 SyncService 抽离，使同步流程与重试机制解耦：SyncService 只描述「何时算成功/不可重试」
 * 与「退避多久」，重试循环本身由本类统一承载，便于复用与单测。
 */
export class RetryHelper {
  /**
   * @param request    发起一次请求
   * @param shouldStop 返回 true 表示无需再重试（成功，或遇到不可重试的错误），立即返回该结果
   * @param fallback   maxAttempts 内均未产生结果时的兜底返回
   * @param backoffMs  第 attempt 次（从 0 起）失败后、重试前的等待毫秒数
   * @param maxAttempts 最多尝试次数
   */
  static async run<T>(
    request: () => Promise<T>,
    shouldStop: (result: T) => boolean,
    fallback: T,
    backoffMs: (attempt: number) => number,
    maxAttempts: number = 3
  ): Promise<T> {
    let last = fallback
    for (let attempt = 0; attempt < maxAttempts; attempt++) {
      last = await request()
      if (shouldStop(last)) {
        return last
      }
      if (attempt < maxAttempts - 1) {
        await new Promise<void>((resolve) => setTimeout(resolve, backoffMs(attempt)))
      }
    }
    return last
  }
}
