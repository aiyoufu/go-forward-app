// IntentService.mock.ets — entry 模块测试用
let handleWantCallLog: Object[] = []

export class IntentService {
  static handleWant(want: Object): void {
    handleWantCallLog.push(want)
  }

  static _getCallLog(): Object[] {
    return handleWantCallLog
  }

  static _reset(): void {
    handleWantCallLog = []
  }
}
