export type CurrencyCode = 'CNY' | 'USD' | 'EUR' | 'GBP' | 'JPY' | 'HKD'

export class CurrencyInfo {
  code: CurrencyCode = 'CNY'
  symbol: string = '¥'
  name: string = '人民币'
  nameCn: string = '人民币'
  nameEn: string = 'Chinese Yuan'
  decimals: number = 2
}

export class ExchangeRate {
  from: CurrencyCode = 'CNY'
  to: CurrencyCode = 'CNY'
  rate: number = 1.0
  timestamp: string = ''
}
