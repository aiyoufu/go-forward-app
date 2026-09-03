import { CurrencyCode, CurrencyInfo } from '../model/CurrencyModel'

/** 币种元数据与换算工具（纯静态，无 IO；类型定义见 model/CurrencyModel） */
export class CurrencyService {
  private static currencyMap: Map<string, CurrencyInfo> = CurrencyService.initMap()

  private static initMap(): Map<string, CurrencyInfo> {
    const map = new Map<string, CurrencyInfo>()
    const cny = new CurrencyInfo()
    cny.code = 'CNY'
    cny.symbol = '¥'
    cny.name = '人民币'
    cny.nameCn = '人民币'
    cny.nameEn = 'Chinese Yuan'
    map.set('CNY', cny)

    const usd = new CurrencyInfo()
    usd.code = 'USD'
    usd.symbol = '$'
    usd.name = '美元'
    usd.nameCn = '美元'
    usd.nameEn = 'US Dollar'
    map.set('USD', usd)

    const eur = new CurrencyInfo()
    eur.code = 'EUR'
    eur.symbol = '€'
    eur.name = '欧元'
    eur.nameCn = '欧元'
    eur.nameEn = 'Euro'
    map.set('EUR', eur)

    const gbp = new CurrencyInfo()
    gbp.code = 'GBP'
    gbp.symbol = '£'
    gbp.name = '英镑'
    gbp.nameCn = '英镑'
    gbp.nameEn = 'British Pound'
    map.set('GBP', gbp)

    const jpy = new CurrencyInfo()
    jpy.code = 'JPY'
    jpy.symbol = '¥'
    jpy.name = '日元'
    jpy.nameCn = '日元'
    jpy.nameEn = 'Japanese Yen'
    jpy.decimals = 0
    map.set('JPY', jpy)

    const hkd = new CurrencyInfo()
    hkd.code = 'HKD'
    hkd.symbol = 'HK$'
    hkd.name = '港币'
    hkd.nameCn = '港币'
    hkd.nameEn = 'Hong Kong Dollar'
    map.set('HKD', hkd)

    return map
  }

  static getCurrencyInfo(code: CurrencyCode): CurrencyInfo {
    const info = CurrencyService.currencyMap.get(code)
    return info ? info : CurrencyService.currencyMap.get('CNY') as CurrencyInfo
  }

  static getAllCurrencies(): CurrencyCode[] {
    return ['CNY', 'USD', 'EUR', 'GBP', 'JPY', 'HKD']
  }

  /** 非法或空值一律回落 CNY，避免旧数据渲染出空符号 */
  static normalize(code: string): CurrencyCode {
    const list = CurrencyService.getAllCurrencies()
    for (const item of list) {
      if (item === code) {
        return item
      }
    }
    return 'CNY'
  }

  static getSymbol(code: string): string {
    return CurrencyService.getCurrencyInfo(CurrencyService.normalize(code)).symbol
  }

  static isBase(code: string): boolean {
    return CurrencyService.normalize(code) === 'CNY'
  }

  /** 原币金额（元）× 汇率 → 人民币「分」，四舍五入到整分 */
  static toBaseFen(originYuan: number, rate: number): number {
    if (!Number.isFinite(originYuan) || !Number.isFinite(rate) || rate <= 0) {
      return 0
    }
    return Math.round(originYuan * rate * 100)
  }

  /** 带货币符号的原币展示串，如 $9.99 */
  static formatOrigin(amountYuan: number, code: string): string {
    const info = CurrencyService.getCurrencyInfo(CurrencyService.normalize(code))
    const safe = Number.isFinite(amountYuan) ? amountYuan : 0
    return info.symbol + safe.toFixed(info.decimals)
  }
}
