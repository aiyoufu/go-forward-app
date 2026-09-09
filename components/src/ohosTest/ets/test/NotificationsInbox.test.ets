import { describe, it, expect } from '@ohos/hypium'
import { Notification } from 'common'
import {
  notificationTypeLabel,
  notificationTypeRole,
  notificationNavTarget,
  isNotificationActionable,
  notificationDayGroup,
  notificationDayLabel,
  buildNotificationGroups,
  flattenNotificationGroups,
  notificationInboxSubtitle,
  unreadBadgeLabel
} from '../../main/ets/components/NotificationsInbox'

function makeNotif(id: string, sentAt: string, read: boolean = false): Notification {
  const n = new Notification()
  n.id = id
  n.sent_at = sentAt
  n.is_read = read
  return n
}

export default function NotificationsInboxTest() {
  describe('NotificationsInbox_helpers', () => {
    describe('notificationTypeLabel', () => {
      it('还款与订阅', 0, () => {
        expect(notificationTypeLabel('payment_due')).assertEqual('还款提醒')
        expect(notificationTypeLabel('subscription_due')).assertEqual('订阅提醒')
      })
      it('压力与洞察', 0, () => {
        expect(notificationTypeLabel('pressure_alert')).assertEqual('压力预警')
        expect(notificationTypeLabel('ai_insight')).assertEqual('AI 洞察')
      })
      it('其余类型与兜底', 0, () => {
        expect(notificationTypeLabel('monthly_review')).assertEqual('月度回顾')
        expect(notificationTypeLabel('data_stale')).assertEqual('数据同步')
        expect(notificationTypeLabel('milestone')).assertEqual('里程碑')
        expect(notificationTypeLabel('update')).assertEqual('应用更新')
        expect(notificationTypeLabel('unknown')).assertEqual('通知')
      })
    })

    describe('notificationTypeRole', () => {
      it('压力为danger', 0, () => {
        expect(notificationTypeRole('pressure_alert')).assertEqual('danger')
      })
      it('到期为warn', 0, () => {
        expect(notificationTypeRole('payment_due')).assertEqual('warn')
        expect(notificationTypeRole('subscription_due')).assertEqual('warn')
      })
      it('里程碑为ok其余off', 0, () => {
        expect(notificationTypeRole('milestone')).assertEqual('ok')
        expect(notificationTypeRole('ai_insight')).assertEqual('off')
        expect(notificationTypeRole('update')).assertEqual('off')
      })
    })

    describe('notificationNavTarget', () => {
      it('负债优先', 0, () => {
        const n = makeNotif('1', '2026-09-09T00:00:00.000Z')
        n.debt_id = 'd1'
        n.subscription_id = 's1'
        const t = notificationNavTarget(n)
        expect(t.route).assertEqual('DebtFormPage')
        expect(t.storageKey).assertEqual('selectedDebtId')
        expect(t.storageValue).assertEqual('d1')
        expect(isNotificationActionable(n)).assertTrue()
      })
      it('仅订阅', 0, () => {
        const n = makeNotif('2', '2026-09-09T00:00:00.000Z')
        n.subscription_id = 's2'
        const t = notificationNavTarget(n)
        expect(t.route).assertEqual('SubscriptionFormPage')
        expect(t.storageValue).assertEqual('s2')
      })
      it('无目标不可跳转', 0, () => {
        const n = makeNotif('3', '2026-09-09T00:00:00.000Z')
        expect(notificationNavTarget(n).route).assertEqual('')
        expect(isNotificationActionable(n)).assertFalse()
      })
    })

    describe('notificationDayGroup', () => {
      const now = new Date(2026, 8, 9, 12, 0, 0).getTime()
      it('今天', 0, () => {
        expect(notificationDayGroup(new Date(2026, 8, 9, 6, 0, 0).toISOString(), now)).assertEqual('today')
      })
      it('昨天', 0, () => {
        expect(notificationDayGroup(new Date(2026, 8, 8, 22, 0, 0).toISOString(), now)).assertEqual('yesterday')
      })
      it('更早', 0, () => {
        expect(notificationDayGroup(new Date(2026, 8, 1, 0, 0, 0).toISOString(), now)).assertEqual('earlier')
      })
      it('空串与非法', 0, () => {
        expect(notificationDayGroup('', now)).assertEqual('earlier')
        expect(notificationDayGroup('bad', now)).assertEqual('earlier')
      })
    })

    describe('notificationDayLabel', () => {
      it('三档文案', 0, () => {
        expect(notificationDayLabel('today')).assertEqual('今天')
        expect(notificationDayLabel('yesterday')).assertEqual('昨天')
        expect(notificationDayLabel('earlier')).assertEqual('更早')
        expect(notificationDayLabel('x')).assertEqual('更早')
      })
    })

    describe('buildNotificationGroups', () => {
      it('按日分段且跳过空档', 0, () => {
        const now = new Date(2026, 8, 9, 12, 0, 0).getTime()
        const list: Notification[] = [
          makeNotif('a', new Date(2026, 8, 9, 8, 0, 0).toISOString()),
          makeNotif('b', new Date(2026, 8, 1, 8, 0, 0).toISOString())
        ]
        const groups = buildNotificationGroups(list, now)
        expect(groups.length).assertEqual(2)
        expect(groups[0].key).assertEqual('today')
        expect(groups[0].items.length).assertEqual(1)
        expect(groups[1].key).assertEqual('earlier')
        expect(groups[1].label).assertEqual('更早')
      })
      it('空列表', 0, () => {
        expect(buildNotificationGroups([], Date.now()).length).assertEqual(0)
      })
      it('扁平化含标题行', 0, () => {
        const now = new Date(2026, 8, 9, 12, 0, 0).getTime()
        const list: Notification[] = [
          makeNotif('a', new Date(2026, 8, 9, 8, 0, 0).toISOString()),
          makeNotif('c', new Date(2026, 8, 9, 9, 0, 0).toISOString()),
          makeNotif('b', new Date(2026, 8, 1, 8, 0, 0).toISOString())
        ]
        const rows = flattenNotificationGroups(buildNotificationGroups(list, now))
        expect(rows.length).assertEqual(5)
        expect(rows[0].kind).assertEqual('header')
        expect(rows[1].kind).assertEqual('item')
        expect(rows[1].lastInGroup).assertFalse()
        expect(rows[2].kind).assertEqual('item')
        expect(rows[2].lastInGroup).assertTrue()
        expect(rows[3].kind).assertEqual('header')
        expect(rows[3].label).assertEqual('更早')
      })
    })

    describe('notificationInboxSubtitle', () => {
      it('空/已读/未读', 0, () => {
        expect(notificationInboxSubtitle(0, 0)).assertEqual('账单日与还款日的提醒会在这里汇总')
        expect(notificationInboxSubtitle(0, 3)).assertEqual('全部已读')
        expect(notificationInboxSubtitle(2, 5)).assertEqual('2 条未读')
      })
    })

    describe('unreadBadgeLabel', () => {
      it('无未读为空', 0, () => {
        expect(unreadBadgeLabel(0)).assertEqual('')
        expect(unreadBadgeLabel(-1)).assertEqual('')
      })
      it('个位数与两位数', 0, () => {
        expect(unreadBadgeLabel(1)).assertEqual('1')
        expect(unreadBadgeLabel(99)).assertEqual('99')
      })
      it('超过99显示99+', 0, () => {
        expect(unreadBadgeLabel(100)).assertEqual('99+')
        expect(unreadBadgeLabel(250)).assertEqual('99+')
      })
    })
  })
}
