// PlatformService.mock.ets
// Mock preset: 预设品牌/周期数据

export class PlatformPreset {
  color: string = '#1677FF'
  defaultAnnualRateBp: number = 1800
  type: string = 'installment'
  domain: string = ''

  constructor(color: string, defaultAnnualRateBp: number, type: string, domain: string = '') {
    this.color = color
    this.defaultAnnualRateBp = defaultAnnualRateBp
    this.type = type
    this.domain = domain
  }
}

export class SubscriptionPreset {
  color: string = '#1677FF'
  category: string = 'other'
  domain: string = ''

  constructor(color: string, category: string, domain: string = '') {
    this.color = color
    this.category = category
    this.domain = domain
  }
}

export class CategoryInfo {
  label: string = ''
  color: string = ''

  constructor(label: string, color: string) {
    this.label = label
    this.color = color
  }
}

export class BillingCycleInfo {
  label: string = ''
  monthsPerCycle: number = 0

  constructor(label: string, monthsPerCycle: number) {
    this.label = label
    this.monthsPerCycle = monthsPerCycle
  }
}

export class BrandVisual {
  color: string = '#2F3336'
  mark: string = ''
  matchedKey: string = ''

  constructor(color: string, mark: string, matchedKey: string = '') {
    this.color = color
    this.mark = mark
    this.matchedKey = matchedKey
  }
}

export class PlatformService {
  static getPlatformPreset(platformName: string): PlatformPreset {
    return new PlatformPreset('#1677FF', 1800, 'installment')
  }

  static getLogoUrlForName(name: string): string {
    return ''
  }

  static getBrandVisual(name: string): BrandVisual {
    return new BrandVisual('#1677FF', name.substring(0, 1) || '户')
  }

  static getSubscriptionPreset(name: string): SubscriptionPreset {
    return new SubscriptionPreset('#1677FF', 'other')
  }

  static getCategoryInfo(category: string): CategoryInfo {
    return new CategoryInfo(category, '#1677FF')
  }

  static getBillingCycleInfo(cycle: string): BillingCycleInfo {
    if (cycle === 'monthly') {
      return new BillingCycleInfo('每月', 1)
    } else if (cycle === 'annually') {
      return new BillingCycleInfo('每年', 12)
    } else if (cycle === 'quarterly') {
      return new BillingCycleInfo('每季度', 3)
    }
    return new BillingCycleInfo(cycle, 1)
  }

  static getAllBillingCycles(): string[] {
    return ['once', 'monthly', 'quarterly', 'annually']
  }

  static getDebtTypeInfo(type: string): CategoryInfo {
    return new CategoryInfo(type, '#1677FF')
  }
}
