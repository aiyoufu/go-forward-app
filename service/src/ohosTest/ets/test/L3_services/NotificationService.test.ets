import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { NotificationService } from '../../../../main/ets/service/NotificationService'
import { DbService } from '../../mock/DbService.mock'
import { UserService } from '../../mock/UserService.mock'

const userId = 'test-user-001'

function notifRow(overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    id: 'notif-001',
    user_id: userId,
    debt_id: 'debt-001',
    subscription_id: '',
    reminder_type: 'payment_due',
    title: '还款提醒',
    body: '今日有还款需要处理',
    is_read: 0,
    sent_at: '2024-12-15T10:00:00.000Z',
    read_at: ''
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

export default function notificationServiceTest() {
  beforeEach(() => {
    DbService._reset()
    UserService._reset()
  })

  // ── getNotifications ──────────────────────────────
  describe('NotificationService_getNotifications', () => {
    it('空表_返回空数组', 0, async () => {
      const result = await NotificationService.getNotifications(userId)
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回通知列表', 0, async () => {
      DbService._setQueryPreset('FROM notifications', [notifRow(), notifRow({ id: 'notif-002' })])
      const result = await NotificationService.getNotifications(userId)
      expect(result.length).assertEqual(2)
      expect(result[0].id).assertEqual('notif-001')
      expect(result[0].title).assertEqual('还款提醒')
    })
  })

  // ── getUnreadCount ──────────────────────────────
  describe('NotificationService_getUnreadCount', () => {
    it('空表_返回0', 0, async () => {
      const result = await NotificationService.getUnreadCount(userId)
      expect(result).assertEqual(0)
    })

    it('有未读_返回计数', 0, async () => {
      DbService._setQueryPreset('COUNT(*)', [{ cnt: 5 }])
      const result = await NotificationService.getUnreadCount(userId)
      expect(result).assertEqual(5)
    })
  })

  // ── markAllRead ──────────────────────────────
  describe('NotificationService_markAllRead', () => {
    it('标记全部已读_调用update', 0, async () => {
      await NotificationService.markAllRead(userId)
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('UPDATE notifications') >= 0)).assertTrue()
    })
  })

  // ── markRead ──────────────────────────────
  describe('NotificationService_markRead', () => {
    it('标记单条已读', 0, async () => {
      await NotificationService.markRead('notif-001')
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('UPDATE notifications') >= 0)).assertTrue()
    })
  })

  // ── deleteNotification ──────────────────────────────
  describe('NotificationService_deleteNotification', () => {
    it('删除单条通知', 0, async () => {
      await NotificationService.deleteNotification('notif-001')
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('DELETE notifications') >= 0)).assertTrue()
    })
  })

  // ── deleteAll ──────────────────────────────
  describe('NotificationService_deleteAll', () => {
    it('按用户删除全部', 0, async () => {
      await NotificationService.deleteAll(userId)
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('DELETE notifications') >= 0)).assertTrue()
    })
  })

  // ── createNotification ──────────────────────────────
  describe('NotificationService_createNotification', () => {
    it('创建通知_插入成功', 0, async () => {
      const n = {
        id: 'notif-new',
        user_id: userId,
        debt_id: 'debt-001',
        subscription_id: '',
        reminder_type: 'payment_due',
        title: '新提醒',
        body: '有新的还款提醒',
        is_read: false,
        sent_at: '',
        read_at: ''
      }
      await NotificationService.createNotification(n as Object)
      const store = DbService._getStore()
      const rows = store.get('notifications')
      expect(rows !== undefined).assertTrue()
      expect(rows!.length).assertEqual(1)
    })
  })

  // ── hasNotificationForToday ──────────────────────────
  describe('NotificationService_hasNotificationForToday', () => {
    it('无记录_返回false', 0, async () => {
      const result = await NotificationService.hasNotificationForToday(userId, 'payment_due', 'debt-001')
      expect(result).assertFalse()
    })

    it('有今日记录_返回true', 0, async () => {
      DbService._setQueryPreset('FROM notifications', [notifRow()])
      const result = await NotificationService.hasNotificationForToday(userId, 'payment_due', 'debt-001')
      expect(result).assertTrue()
    })
  })

  // ── rowToNotification 字段映射 ──────────────────────────
  describe('NotificationService_rowToNotification_字段映射', () => {
    it('is_read为1_true', 0, async () => {
      DbService._setQueryPreset('FROM notifications', [notifRow({ is_read: 1 })])
      const result = await NotificationService.getNotifications(userId)
      expect(result[0].is_read).assertTrue()
    })

    it('is_read为0_false', 0, async () => {
      DbService._setQueryPreset('FROM notifications', [notifRow({ is_read: 0 })])
      const result = await NotificationService.getNotifications(userId)
      expect(result[0].is_read).assertFalse()
    })

    it('subscription_id存在时正确读取', 0, async () => {
      DbService._setQueryPreset('FROM notifications', [notifRow({ subscription_id: 'sub-001' })])
      const result = await NotificationService.getNotifications(userId)
      expect(result[0].subscription_id).assertEqual('sub-001')
    })
  })
}
