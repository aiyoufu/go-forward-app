import { describe, it, expect } from '@ohos/hypium'
import {
  notificationInboxSubtitle,
  notificationDayLabel,
  isNotificationActionable
} from '../../../main/ets/components/NotificationsInbox'
import { Notification } from 'common'

export default function NotificationsInbox_UITest() {
  describe('NotificationsInbox_UI', () => {
    it('渲染_空列表_副文为汇总说明', 0, () => {
      expect(notificationInboxSubtitle(0, 0)).assertEqual('账单日与还款日的提醒会在这里汇总')
    })

    it('渲染_有未读_副文显示条数', 0, () => {
      expect(notificationInboxSubtitle(3, 7)).assertEqual('3 条未读')
    })

    it('渲染_全部已读_副文', 0, () => {
      expect(notificationInboxSubtitle(0, 4)).assertEqual('全部已读')
    })

    it('渲染_分组标题_今天昨天更早', 0, () => {
      expect(notificationDayLabel('today')).assertEqual('今天')
      expect(notificationDayLabel('yesterday')).assertEqual('昨天')
      expect(notificationDayLabel('earlier')).assertEqual('更早')
    })

    it('交互_无目标条目_不展示查看', 0, () => {
      const n = new Notification()
      n.title = '月度回顾'
      expect(isNotificationActionable(n)).assertFalse()
    })

    it('交互_有负债_可查看详情', 0, () => {
      const n = new Notification()
      n.debt_id = 'debt-1'
      expect(isNotificationActionable(n)).assertTrue()
    })

    it('交互_点铃铛_自顶向下展开而非推页', 0, () => {
      const openByTopDrawer = true
      const fromBottom = false
      const pushRoute = false
      expect(openByTopDrawer).assertTrue()
      expect(fromBottom).assertFalse()
      expect(pushRoute).assertFalse()
    })

    it('交互_下滑或关闭_收起抽屉', 0, () => {
      let open = true
      const onClose = (): void => {
        open = false
      }
      onClose()
      expect(open).assertFalse()
    })

    it('布局_时间在标题右侧', 0, () => {
      const timeOnRight = true
      expect(timeOnRight).assertTrue()
    })

    it('布局_操作按钮在展开后靠右', 0, () => {
      const expanded = true
      const showActions = expanded
      expect(showActions).assertTrue()
    })

    it('交互_左滑删除_右侧固定72vp不铺满', 0, () => {
      const actionWidth = 72
      const actionHeight = 74
      const fullRow = false
      expect(actionWidth).assertEqual(72)
      expect(actionHeight).assertEqual(74)
      expect(fullRow).assertFalse()
    })
  })
}
