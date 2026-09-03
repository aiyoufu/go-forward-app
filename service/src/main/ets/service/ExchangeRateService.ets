import { CurrencyCode, ExchangeRate } from 'common'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'

class RateCacheItem {
  rate: ExchangeRate = new ExchangeRate()
  expiry: number = 0
}

/**
 * 汇率服务：查询实时汇率
 *
 * 使用 open.er-api.com 免费接口（无需 API Key），按基准币返回全表汇率。
 * 查询失败时返回 null，由表单侧回落为用户手动填写，不阻塞保存。
 */
export class ExchangeRateService {
  private static readonly BASE_URL = 'https://open.er-api.com/v6/latest'
  private static readonly TIMEOUT_MS = 8000
  private static rateCache: Map<string, RateCacheItem> = new Map<string, RateCacheItem>()
  private static readonly CACHE_DURATION_MS = 3600000

  static async getRate(from: CurrencyCode, to: CurrencyCode = 'CNY'): Promise<ExchangeRate | null> {
    if (from === to) {
      const same = new ExchangeRate()
      same.from = from
      same.to = to
      same.rate = 1.0
      same.timestamp = new Date().toISOString()
      return same
    }

    const cacheKey = from + '_' + to
    const cached = ExchangeRateService.rateCache.get(cacheKey)
    if (cached && Date.now() < cached.expiry) {
      return cached.rate
    }

    const rates = await ExchangeRateService.fetchRates(from)
    if (!rates) {
      return null
    }
    const value = rates.get(to)
    if (value === undefined || !Number.isFinite(value) || value <= 0) {
      return null
    }

    const rate = new ExchangeRate()
    rate.from = from
    rate.to = to
    rate.rate = value
    rate.timestamp = new Date().toISOString()

    const item = new RateCacheItem()
    item.rate = rate
    item.expiry = Date.now() + ExchangeRateService.CACHE_DURATION_MS
    ExchangeRateService.rateCache.set(cacheKey, item)

    return rate
  }

  /** 「1 USD ≈ 7.2500 CNY」；查询失败返回空串，由调用方决定提示文案 */
  static async getRateText(from: CurrencyCode, to: CurrencyCode = 'CNY'): Promise<string> {
    if (from === to) {
      return ''
    }
    const info = await ExchangeRateService.getRate(from, to)
    if (!info) {
      return ''
    }
    return '1 ' + from + ' ≈ ' + info.rate.toFixed(4) + ' ' + to
  }

  static clearCache(): void {
    ExchangeRateService.rateCache.clear()
  }

  private static async fetchRates(baseCurrency: CurrencyCode): Promise<Map<string, number> | null> {
    return new Promise<Map<string, number> | null>((resolve) => {
      const url = ExchangeRateService.BASE_URL + '/' + baseCurrency
      const req = http.createHttp()
      req.request(url, {
        method: http.RequestMethod.GET,
        connectTimeout: ExchangeRateService.TIMEOUT_MS,
        readTimeout: ExchangeRateService.TIMEOUT_MS,
        header: { 'Content-Type': 'application/json' }
      }, (err: BusinessError, data: http.HttpResponse) => {
        req.destroy()

        if (err || data.responseCode !== 200) {
          resolve(null)
          return
        }

        try {
          const resultText = typeof data.result === 'string' ? data.result as string : ''
          if (resultText.length === 0) {
            resolve(null)
            return
          }
          const parsed: ESObject = JSON.parse(resultText)
          const ratesObj: ESObject = parsed['rates']
          if (!ratesObj) {
            resolve(null)
            return
          }
          const map = new Map<string, number>()
          const keys = Object.keys(ratesObj as object)
          for (const key of keys) {
            const value: ESObject = ratesObj[key]
            if (typeof value === 'number') {
              map.set(key, value as number)
            }
          }
          resolve(map.size > 0 ? map : null)
        } catch (parseError) {
          resolve(null)
        }
      })
    })
  }
}
