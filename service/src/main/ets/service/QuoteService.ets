import { HomeSubtitleComposer, InspirationalQuotes } from 'common'
import { PreferencesService } from './PreferencesService'

/**
 * 首页副文：组合句式 + 严选成句，不拉外网。
 * 关键词筛开放语料堵不住语义漏洞；纯成句库又会轮完。
 * 组合空间由 HomeSubtitleComposer.capacity 给出，按序号散列取句。
 */
export class QuoteService {
  private static readonly PREF_KEY_LINE: string = 'home_subtitle_line_v2'
  private static readonly PREF_KEY_SEQ: string = 'home_subtitle_seq_v2'
  private static cachedQuote: string = ''
  private static seq: number = -1

  static isAcceptable(text: string): boolean {
    return InspirationalQuotes.contains(text) || HomeSubtitleComposer.isComposed(text)
  }

  static lineAt(seed: number): string {
    const composed = HomeSubtitleComposer.capacity()
    const classic = InspirationalQuotes.QUOTES.length
    const total = composed + classic
    const h = QuoteService.mix(seed)
    const slot = h % total
    if (slot < classic) {
      return InspirationalQuotes.QUOTES[slot]
    }
    return HomeSubtitleComposer.composeAt(slot - classic)
  }

  static getCachedQuote(): string {
    if (QuoteService.cachedQuote.length > 0) {
      return QuoteService.cachedQuote
    }
    const saved = PreferencesService.getStringSync(QuoteService.PREF_KEY_LINE, '')
    if (QuoteService.isAcceptable(saved)) {
      QuoteService.cachedQuote = saved
      return saved
    }
    const seed = QuoteService.readSeq()
    const next = QuoteService.lineAt(seed)
    QuoteService.cachedQuote = next
    return next
  }

  static async fetchNextQuote(): Promise<string> {
    let seed = QuoteService.readSeq() + 1
    let next = QuoteService.lineAt(seed)
    if (next === QuoteService.cachedQuote) {
      seed = seed + 1
      next = QuoteService.lineAt(seed)
    }
    QuoteService.seq = seed
    QuoteService.cachedQuote = next
    await PreferencesService.putNumber(QuoteService.PREF_KEY_SEQ, seed)
    await PreferencesService.putString(QuoteService.PREF_KEY_LINE, next)
    await PreferencesService.flush()
    return next
  }

  static resetForTest(): void {
    QuoteService.cachedQuote = ''
    QuoteService.seq = -1
    InspirationalQuotes.resetForTest()
  }

  private static readSeq(): number {
    if (QuoteService.seq >= 0) {
      return QuoteService.seq
    }
    QuoteService.seq = PreferencesService.getNumberSync(QuoteService.PREF_KEY_SEQ, 0)
    return QuoteService.seq
  }

  /** 打散连续序号，避免按槽位顺序播完 */
  private static mix(seed: number): number {
    let x = seed + 1
    x = (x ^ 61) ^ (x >> 16)
    x = x + (x << 3)
    x = x ^ (x >> 4)
    x = x * 0x27d4eb2d
    x = x ^ (x >> 15)
    if (x < 0) {
      return -x
    }
    return x
  }
}
