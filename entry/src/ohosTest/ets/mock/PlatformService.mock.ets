// PlatformService.mock.ets — entry 模块测试用
export class BillingCycleInfo {
  label: string = ''
  monthsPerCycle: number = 0
  constructor(label: string, monthsPerCycle: number) {
    this.label = label
    this.monthsPerCycle = monthsPerCycle
  }
}

export class PlatformService {
  static getBillingCycleInfo(cycle: string): BillingCycleInfo {
    if (cycle === 'monthly') return new BillingCycleInfo('每月', 1)
    if (cycle === 'annually') return new BillingCycleInfo('每年', 12)
    if (cycle === 'quarterly') return new BillingCycleInfo('每季度', 3)
    return new BillingCycleInfo(cycle, 1)
  }
}
