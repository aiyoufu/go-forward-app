import { describe, it, expect } from '@ohos/hypium'
import { AchievementCard } from '../../../../main/ets/model/AchievementCardModel'

export default function achievementCardModelTest() {
  describe('AchievementCardModel', () => {

    describe('AchievementCard', () => {
      it('默认值正确', 0, () => {
        const c = new AchievementCard()
        expect(c.id).assertEqual('')
        expect(c.user_id).assertEqual('')
        expect(c.debt_id).assertEqual('')
        expect(c.platform).assertEqual('')
        expect(c.total_paid).assertEqual(0)
        expect(c.total_interest).assertEqual(0)
        expect(c.duration_days).assertEqual(0)
        expect(c.completed_at).assertEqual('')
        expect(c.card_data).assertEqual('')
        expect(c.created_at).assertEqual('')
      })
      it('可赋值', 0, () => {
        const c = new AchievementCard()
        c.id = 'ach-1'
        c.user_id = 'user-1'
        c.debt_id = 'debt-1'
        c.platform = '花呗'
        c.total_paid = 5000000
        c.total_interest = 500000
        c.duration_days = 365
        c.completed_at = '2026-07-28'
        c.card_data = '{"badge":"gold"}'
        expect(c.id).assertEqual('ach-1')
        expect(c.user_id).assertEqual('user-1')
        expect(c.debt_id).assertEqual('debt-1')
        expect(c.platform).assertEqual('花呗')
        expect(c.total_paid).assertEqual(5000000)
        expect(c.total_interest).assertEqual(500000)
        expect(c.duration_days).assertEqual(365)
        expect(c.completed_at).assertEqual('2026-07-28')
        expect(c.card_data).assertEqual('{"badge":"gold"}')
      })
    })
  })
}
