import { DbService } from '../DbService'
import { DashboardFrameCache } from './LocalDataStore'
import { Logger } from 'common'

/**
 * 首页物化快照（RDB 一行）：比 Preferences 帧更稳，冷启动可只读 1 行先画金额。
 * payload 与 DashboardFrameCache 字段对齐（JSON 字符串）。
 */
export class HomeSnapshotStore {
  static async save(userId: string, frame: DashboardFrameCache): Promise<void> {
    if (userId.length === 0) {
      return
    }
    try {
      const payload = JSON.stringify({
        remainingDebt: frame.remainingDebt,
        thisMonthDue: frame.thisMonthDue,
        nextMonthDue: frame.nextMonthDue,
        activeDebtCount: frame.activeDebtCount,
        subscriptionCount: frame.subscriptionCount,
        subscriptionTotalAmount: frame.subscriptionTotalAmount,
        creditAccountCount: frame.creditAccountCount,
        progressPercent: frame.progressPercent,
        hasRepaymentRecords: frame.hasRepaymentRecords,
        monthPaid: frame.monthPaid,
        todayDueAmount: frame.todayDueAmount,
        overdueCount: frame.overdueCount
      })
      const now = DbService.now()
      const rs = await DbService.query(
        'SELECT user_id FROM home_snapshot WHERE user_id = ?',
        [userId]
      )
      const exists = rs.goToFirstRow()
      rs.close()
      const values = new Map<string, string | number | boolean>()
      values.set('user_id', userId)
      values.set('payload', payload)
      values.set('updated_at', now)
      if (exists) {
        await DbService.update('home_snapshot', values, 'user_id = ?', [userId])
      } else {
        await DbService.insert('home_snapshot', values)
      }
    } catch (e) {
      Logger.warn('HomeSnapshot', 'save fail: ' + (e instanceof Error ? e.message : 'err'))
    }
  }

  static async load(userId: string): Promise<DashboardFrameCache | null> {
    if (userId.length === 0) {
      return null
    }
    try {
      const rs = await DbService.query(
        'SELECT payload FROM home_snapshot WHERE user_id = ?',
        [userId]
      )
      if (!rs.goToFirstRow()) {
        rs.close()
        return null
      }
      const raw = rs.getString(rs.getColumnIndex('payload')) ?? ''
      rs.close()
      if (raw.length < 2) {
        return null
      }
      const o = JSON.parse(raw) as Record<string, Object>
      const f = new DashboardFrameCache()
      f.remainingDebt = Number(o['remainingDebt']) || 0
      f.thisMonthDue = Number(o['thisMonthDue']) || 0
      f.nextMonthDue = Number(o['nextMonthDue']) || 0
      f.activeDebtCount = Number(o['activeDebtCount']) || 0
      f.subscriptionCount = Number(o['subscriptionCount']) || 0
      f.subscriptionTotalAmount = Number(o['subscriptionTotalAmount']) || 0
      f.creditAccountCount = Number(o['creditAccountCount']) || 0
      f.progressPercent = Number(o['progressPercent']) || 0
      f.hasRepaymentRecords = Boolean(o['hasRepaymentRecords'])
      f.monthPaid = Number(o['monthPaid']) || 0
      f.todayDueAmount = Number(o['todayDueAmount']) || 0
      f.overdueCount = Number(o['overdueCount']) || 0
      return f
    } catch (_e) {
      return null
    }
  }

  static async clear(userId: string): Promise<void> {
    try {
      if (userId.length > 0) {
        await DbService.executeSql('DELETE FROM home_snapshot WHERE user_id = ?', [userId])
      }
    } catch (e) {
      Logger.warn('HomeSnapshot', 'clear fail: ' + (e instanceof Error ? e.message : 'err'))
    }
  }
}
