import { describe, it, expect } from '@ohos/hypium'
import { HomeSubtitleComposer, InspirationalQuotes } from 'common'
import { QuoteService } from '../../../../main/ets/service/QuoteService'

export default function quoteServiceTest() {
  describe('QuoteService_composedPool', () => {
    it('缓存句可接受', 0, () => {
      QuoteService.resetForTest()
      const q = QuoteService.getCachedQuote()
      expect(QuoteService.isAcceptable(q)).assertTrue()
    })

    it('空字符串不可接受', 0, () => {
      expect(QuoteService.isAcceptable('')).assertFalse()
    })

    it('严选成句仍可接受', 0, () => {
      const sample = InspirationalQuotes.QUOTES[0]
      expect(QuoteService.isAcceptable(sample)).assertTrue()
      expect(InspirationalQuotes.contains(sample)).assertTrue()
    })

    it('换句可接受且可与当前不同', 0, async () => {
      QuoteService.resetForTest()
      const first = QuoteService.getCachedQuote()
      const next = await QuoteService.fetchNextQuote()
      expect(QuoteService.isAcceptable(next)).assertTrue()
      expect(next.length > 0).assertTrue()
      expect(first.length > 0).assertTrue()
    })

    it('不同序号走出组合空间', 0, () => {
      const a = QuoteService.lineAt(1)
      const b = QuoteService.lineAt(2)
      const c = QuoteService.lineAt(100)
      expect(QuoteService.isAcceptable(a)).assertTrue()
      expect(QuoteService.isAcceptable(b)).assertTrue()
      expect(QuoteService.isAcceptable(c)).assertTrue()
      expect(HomeSubtitleComposer.capacity() > 1000).assertTrue()
    })
  })
}
