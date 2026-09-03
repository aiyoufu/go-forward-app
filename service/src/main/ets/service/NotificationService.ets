import { relationalStore } from '@kit.ArkData'
import { Notification, ReminderType } from 'common'
import { DbService } from './DbService'
import { UserService } from './UserService'

export class NotificationService {
  static async getNotifications(userId: string = UserService.getCurrentUserId()): Promise<Notification[]> {
    const rs = await DbService.query(
      'SELECT * FROM notifications WHERE user_id = ? ORDER BY sent_at DESC LIMIT 100',
      [userId]
    )
    const list: Notification[] = []
    try {
      while (rs.goToNextRow()) {
        list.push(NotificationService.rowToNotification(rs))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return list
  }

  static async getUnreadCount(userId: string = UserService.getCurrentUserId()): Promise<number> {
    const rs = await DbService.query(
      'SELECT COUNT(*) AS cnt FROM notifications WHERE user_id = ? AND is_read = 0',
      [userId]
    )
    let count = 0
    try {
      if (rs.goToNextRow()) {
        count = rs.getLong(rs.getColumnIndex('cnt'))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return count
  }

  static async markAllRead(userId: string = UserService.getCurrentUserId()): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('is_read', 1)
    values.set('read_at', DbService.now())
    await DbService.update('notifications', values, 'user_id = ?', [userId])
  }

  static async markRead(notificationId: string): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('is_read', 1)
    values.set('read_at', DbService.now())
    await DbService.update('notifications', values, 'id = ?', [notificationId])
  }

  static async deleteNotification(notificationId: string): Promise<void> {
    await DbService.delete('notifications', 'id = ?', [notificationId])
  }

  static async deleteAll(userId: string = UserService.getCurrentUserId()): Promise<void> {
    await DbService.delete('notifications', 'user_id = ?', [userId])
  }

  static async createNotification(n: Notification): Promise<void> {
    const values = new Map<string, string | number | boolean>()
    values.set('id', n.id)
    values.set('user_id', n.user_id)
    values.set('debt_id', n.debt_id || '')
    values.set('subscription_id', n.subscription_id || '')
    values.set('reminder_type', n.reminder_type)
    values.set('title', n.title)
    values.set('body', n.body)
    values.set('is_read', DbService.boolToInt(n.is_read))
    values.set('sent_at', n.sent_at || DbService.now())
    values.set('read_at', n.read_at || '')
    await DbService.insert('notifications', values)
  }

  static async hasNotificationForToday(
    userId: string,
    reminderType: ReminderType,
    refId: string
  ): Promise<boolean> {
    const today = new Date().toISOString().slice(0, 10)
    const rs = await DbService.query(
      'SELECT id FROM notifications WHERE user_id = ? AND reminder_type = ? AND sent_at LIKE ? AND (debt_id = ? OR subscription_id = ?) LIMIT 1',
      [userId, reminderType, today + '%', refId, refId]
    )
    let exists = false
    try {
      exists = rs.goToNextRow()
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }
    return exists
  }

  private static rowToNotification(rs: relationalStore.ResultSet): Notification {
    const n = new Notification()
    try {
      n.id = rs.getString(rs.getColumnIndex('id'))
    } catch (_e) {
    }
    try {
      n.user_id = rs.getString(rs.getColumnIndex('user_id'))
    } catch (_e2) {
    }
    try {
      n.debt_id = rs.getString(rs.getColumnIndex('debt_id'))
    } catch (_e3) {
    }
    try {
      const subIdx = rs.getColumnIndex('subscription_id')
      if (subIdx >= 0) {
        n.subscription_id = rs.getString(subIdx)
      }
    } catch (_e4) {
    }
    try {
      n.reminder_type = rs.getString(rs.getColumnIndex('reminder_type')) as ReminderType
    } catch (_e5) {
    }
    try {
      n.title = rs.getString(rs.getColumnIndex('title'))
    } catch (_e6) {
    }
    try {
      n.body = rs.getString(rs.getColumnIndex('body'))
    } catch (_e7) {
    }
    try {
      n.is_read = rs.getLong(rs.getColumnIndex('is_read')) === 1
    } catch (_e8) {
    }
    try {
      n.sent_at = rs.getString(rs.getColumnIndex('sent_at'))
    } catch (_e9) {
    }
    try {
      n.read_at = rs.getString(rs.getColumnIndex('read_at'))
    } catch (_e10) {
    }
    return n
  }
}
