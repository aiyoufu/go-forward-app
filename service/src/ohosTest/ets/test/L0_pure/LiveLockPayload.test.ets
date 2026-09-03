import { describe, it, expect } from '@ohos/hypium'
import { LiveLockPayload, LIVE_LOCK_EVENT, LIVE_LOCK_STORAGE_KEY } from '../../../../main/ets/service/LiveLockPayload'

export default function liveLockPayloadTest() {
  describe('LiveLockPayload', () => {
    it('默认构造_所有字段为初始值', 0, async () => {
      const p = new LiveLockPayload()
      expect(p.title).assertEqual('')
      expect(p.summary).assertEqual('')
      expect(p.line1).assertEqual('')
      expect(p.line2).assertEqual('')
      expect(p.moreText).assertEqual('')
      expect(p.accentColor).assertEqual('#0F1419')
      expect(p.status).assertEqual(0)
      expect(p.sequence).assertEqual(0)
    })
    it('empty()返回新实例', 0, async () => {
      const p = LiveLockPayload.empty()
      expect((p) !== null && (p) !== undefined).assertTrue()
      expect(p.title).assertEqual('')
      expect(p.status).assertEqual(0)
    })
    it('字段赋值', 0, async () => {
      const p = new LiveLockPayload()
      p.title = '今日还款'
      p.summary = '3 笔 · ¥1,200'
      p.line1 = '花呗 ¥500'
      p.line2 = '借呗 ¥700'
      p.moreText = '查看更多'
      p.accentColor = '#FF6400'
      p.status = 2
      p.sequence = 42
      expect(p.title).assertEqual('今日还款')
      expect(p.summary).assertEqual('3 笔 · ¥1,200')
      expect(p.line1).assertEqual('花呗 ¥500')
      expect(p.line2).assertEqual('借呗 ¥700')
      expect(p.moreText).assertEqual('查看更多')
      expect(p.accentColor).assertEqual('#FF6400')
      expect(p.status).assertEqual(2)
      expect(p.sequence).assertEqual(42)
    })
    it('LIVE_LOCK_EVENT非空', 0, async () => {
      expect(LIVE_LOCK_EVENT.length).assertLarger(0)
    })
    it('LIVE_LOCK_STORAGE_KEY非空', 0, async () => {
      expect(LIVE_LOCK_STORAGE_KEY.length).assertLarger(0)
    })
  })
}
