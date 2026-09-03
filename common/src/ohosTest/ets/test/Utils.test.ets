import { describe, it, expect } from '@ohos/hypium'
import { Utils } from '../../../main/ets/common/Utils'

export default function utilsTest() {
  describe('Utils', () => {

    // ─── yuanToFen ──────────────────────────────────────────
    describe('yuanToFen', () => {
      it('正常金额转换', 0, () => {
        expect(Utils.yuanToFen(1)).assertEqual(100)
        expect(Utils.yuanToFen(10)).assertEqual(1000)
        expect(Utils.yuanToFen(99.99)).assertEqual(9999)
      })
      it('零值转换', 0, () => {
        expect(Utils.yuanToFen(0)).assertEqual(0)
      })
      it('负数转换', 0, () => {
        expect(Utils.yuanToFen(-1)).assertEqual(-100)
        expect(Utils.yuanToFen(-0.01)).assertEqual(-1)
      })
      it('精度处理', 0, () => {
        expect(Utils.yuanToFen(0.1)).assertEqual(10)
        expect(Utils.yuanToFen(0.29)).assertEqual(29)
        expect(Utils.yuanToFen(1.005)).assertEqual(100)
      })
      it('小数金额', 0, () => {
        expect(Utils.yuanToFen(123.45)).assertEqual(12345)
        expect(Utils.yuanToFen(0.01)).assertEqual(1)
      })
    })

    // ─── fenToYuan ──────────────────────────────────────────
    describe('fenToYuan', () => {
      it('正常分转元', 0, () => {
        expect(Utils.fenToYuan(100)).assertEqual(1)
        expect(Utils.fenToYuan(1000)).assertEqual(10)
        expect(Utils.fenToYuan(9999)).assertEqual(99.99)
      })
      it('零分转元', 0, () => {
        expect(Utils.fenToYuan(0)).assertEqual(0)
      })
      it('负分转元', 0, () => {
        expect(Utils.fenToYuan(-100)).assertEqual(-1)
        expect(Utils.fenToYuan(-1)).assertEqual(-0.01)
      })
      it('不足一分', 0, () => {
        expect(Utils.fenToYuan(1)).assertEqual(0.01)
        expect(Utils.fenToYuan(50)).assertEqual(0.5)
      })
      it('四舍五入', 0, () => {
        expect(Utils.fenToYuan(1.4)).assertEqual(0.01)
        expect(Utils.fenToYuan(1.5)).assertEqual(0.02)
      })
    })

    // ─── formatMoney ────────────────────────────────────────
    describe('formatMoney', () => {
      it('正常金额带符号', 0, () => {
        expect(Utils.formatMoney(100)).assertEqual('¥' + Utils.YUAN_GAP + '1.00')
        expect(Utils.formatMoney(12345)).assertEqual('¥' + Utils.YUAN_GAP + '123.45')
      })
      it('零金额', 0, () => {
        expect(Utils.formatMoney(0)).assertEqual('¥' + Utils.YUAN_GAP + '0.00')
      })
      it('负数金额', 0, () => {
        expect(Utils.formatMoney(-100)).assertEqual('-¥' + Utils.YUAN_GAP + '1.00')
        expect(Utils.formatMoney(-123456)).assertEqual('-¥' + Utils.YUAN_GAP + '1,234.56')
      })
      it('超大金额千分位', 0, () => {
        expect(Utils.formatMoney(100000)).assertEqual('¥' + Utils.YUAN_GAP + '1,000.00')
        expect(Utils.formatMoney(123456789)).assertEqual('¥' + Utils.YUAN_GAP + '1,234,567.89')
        expect(Utils.formatMoney(1000000000)).assertEqual('¥' + Utils.YUAN_GAP + '10,000,000.00')
      })
      it('小数位补零', 0, () => {
        expect(Utils.formatMoney(100)).assertEqual('¥' + Utils.YUAN_GAP + '1.00')
        expect(Utils.formatMoney(101)).assertEqual('¥' + Utils.YUAN_GAP + '1.01')
        expect(Utils.formatMoney(110)).assertEqual('¥' + Utils.YUAN_GAP + '1.10')
      })
      it('不显示货币符号', 0, () => {
        expect(Utils.formatMoney(100, false)).assertEqual('1.00')
        expect(Utils.formatMoney(12345, false)).assertEqual('123.45')
        expect(Utils.formatMoney(-100, false)).assertEqual('-1.00')
      })
      it('个位数金额', 0, () => {
        expect(Utils.formatMoney(1)).assertEqual('¥' + Utils.YUAN_GAP + '0.01')
        expect(Utils.formatMoney(99)).assertEqual('¥' + Utils.YUAN_GAP + '0.99')
      })
    })

    describe('formatMoneyCompact', () => {
      it('整元去掉尾随小数', 0, () => {
        expect(Utils.formatMoneyCompact(100)).assertEqual('¥' + Utils.YUAN_GAP + '1')
        expect(Utils.formatMoneyCompact(100000)).assertEqual('¥' + Utils.YUAN_GAP + '1,000')
      })
      it('有分时保留两位', 0, () => {
        expect(Utils.formatMoneyCompact(12345)).assertEqual('¥' + Utils.YUAN_GAP + '123.45')
        expect(Utils.formatMoneyCompact(110)).assertEqual('¥' + Utils.YUAN_GAP + '1.10')
      })
      it('不显示货币符号', 0, () => {
        expect(Utils.formatMoneyCompact(100, false)).assertEqual('1')
        expect(Utils.formatMoneyCompact(12345, false)).assertEqual('123.45')
      })
    })

    // ─── formatDate ─────────────────────────────────────────
    describe('formatDate', () => {
      it('Date对象格式化', 0, () => {
        const d = new Date(2026, 0, 15)
        expect(Utils.formatDate(d)).assertEqual('2026-01-15')
      })
      it('字符串日期格式化', 0, () => {
        const result = Utils.formatDate('2026-06-01')
        expect(result).assertEqual('2026-06-01')
      })
      it('时间戳格式化', 0, () => {
        const ts = new Date(2026, 5, 15).getTime()
        expect(Utils.formatDate(ts)).assertEqual('2026-06-15')
      })
      it('补零格式', 0, () => {
        const d = new Date(2026, 0, 5)
        expect(Utils.formatDate(d)).assertEqual('2026-01-05')
      })
    })

    // ─── formatMonthDay ─────────────────────────────────────
    describe('formatMonthDay', () => {
      it('正常月日格式化', 0, () => {
        const d = new Date(2026, 5, 15)
        expect(Utils.formatMonthDay(d)).assertEqual('06-15')
      })
      it('补零月日', 0, () => {
        const d = new Date(2026, 0, 5)
        expect(Utils.formatMonthDay(d)).assertEqual('01-05')
      })
      it('双位月日', 0, () => {
        const d = new Date(2026, 11, 25)
        expect(Utils.formatMonthDay(d)).assertEqual('12-25')
      })
    })

    // ─── todayString ────────────────────────────────────────
    describe('todayString', () => {
      it('返回YYYY-MM-DD格式', 0, () => {
        const result = Utils.todayString()
        const regex = /^\d{4}-\d{2}-\d{2}$/
        expect(regex.test(result)).assertTrue()
      })
      it('与当前日期一致', 0, () => {
        const result = Utils.todayString()
        const now = new Date()
        const expected = Utils.formatDate(now)
        expect(result).assertEqual(expected)
      })
    })

    // ─── addMonths ──────────────────────────────────────────
    describe('addMonths', () => {
      it('正常加月', 0, () => {
        expect(Utils.addMonths('2026-01-15', 1)).assertEqual('2026-02-15')
        expect(Utils.addMonths('2026-01-15', 3)).assertEqual('2026-04-15')
      })
      it('跨年', 0, () => {
        expect(Utils.addMonths('2026-11-15', 3)).assertEqual('2027-02-15')
      })
      it('负数月份', 0, () => {
        expect(Utils.addMonths('2026-03-15', -2)).assertEqual('2026-01-15')
      })
      it('跨年负数', 0, () => {
        expect(Utils.addMonths('2026-02-15', -3)).assertEqual('2025-11-15')
      })
      it('零月', 0, () => {
        expect(Utils.addMonths('2026-06-15', 0)).assertEqual('2026-06-15')
      })
      it('闰年二月', 0, () => {
        expect(Utils.addMonths('2024-01-29', 1)).assertEqual('2024-02-29')
      })
    })

    // ─── daysBetween ────────────────────────────────────────
    describe('daysBetween', () => {
      it('正差值', 0, () => {
        expect(Utils.daysBetween('2026-01-01', '2026-01-10')).assertEqual(9)
      })
      it('负差值', 0, () => {
        expect(Utils.daysBetween('2026-01-10', '2026-01-01')).assertEqual(-9)
      })
      it('零差值', 0, () => {
        expect(Utils.daysBetween('2026-01-01', '2026-01-01')).assertEqual(0)
      })
      it('跨月', 0, () => {
        expect(Utils.daysBetween('2026-01-01', '2026-02-01')).assertEqual(31)
      })
      it('Date对象输入', 0, () => {
        const a = new Date(2026, 0, 1)
        const b = new Date(2026, 0, 11)
        expect(Utils.daysBetween(a, b)).assertEqual(10)
      })
    })

    // ─── daysFromNow ────────────────────────────────────────
    describe('daysFromNow', () => {
      it('未来日期为正数', 0, () => {
        const future = new Date()
        future.setDate(future.getDate() + 5)
        const futureStr = Utils.formatDate(future)
        expect(Utils.daysFromNow(futureStr)).assertEqual(5)
      })
      it('过去日期为负数', 0, () => {
        const past = new Date()
        past.setDate(past.getDate() - 3)
        const pastStr = Utils.formatDate(past)
        expect(Utils.daysFromNow(pastStr)).assertEqual(-3)
      })
      it('今天为零', 0, () => {
        const todayStr = Utils.todayString()
        expect(Utils.daysFromNow(todayStr)).assertEqual(0)
      })
    })

    // ─── creditCardExpiryToYmd ──────────────────────────────
    describe('creditCardExpiryToYmd', () => {
      it('MM/YY_取当月末', 0, () => {
        expect(Utils.creditCardExpiryToYmd('06/30')).assertEqual('2030-06-30')
        expect(Utils.creditCardExpiryToYmd('12/30')).assertEqual('2030-12-31')
        expect(Utils.creditCardExpiryToYmd('02/28')).assertEqual('2028-02-29')
      })
      it('YYYY-MM_取当月末', 0, () => {
        expect(Utils.creditCardExpiryToYmd('2030-06')).assertEqual('2030-06-30')
        expect(Utils.creditCardExpiryToYmd('2030-12')).assertEqual('2030-12-31')
      })
      it('YYYY-MM-DD_原样返回', 0, () => {
        expect(Utils.creditCardExpiryToYmd('2030-06-15')).assertEqual('2030-06-15')
      })
      it('空或非法_返回空串', 0, () => {
        expect(Utils.creditCardExpiryToYmd('')).assertEqual('')
        expect(Utils.creditCardExpiryToYmd('13/30')).assertEqual('')
        expect(Utils.creditCardExpiryToYmd('abc')).assertEqual('')
      })
    })

    // ─── addDays ────────────────────────────────────────────
    describe('addDays', () => {
      it('正常加天', 0, () => {
        expect(Utils.addDays('2026-01-01', 1)).assertEqual('2026-01-02')
        expect(Utils.addDays('2026-01-01', 10)).assertEqual('2026-01-11')
      })
      it('跨月', 0, () => {
        expect(Utils.addDays('2026-01-30', 5)).assertEqual('2026-02-04')
      })
      it('负数天', 0, () => {
        expect(Utils.addDays('2026-01-10', -5)).assertEqual('2026-01-05')
      })
      it('零天', 0, () => {
        expect(Utils.addDays('2026-06-15', 0)).assertEqual('2026-06-15')
      })
    })

    // ─── nextDateForMonthlyDay ──────────────────────────────
    describe('nextDateForMonthlyDay', () => {
      it('本月还款日未到_取本月', 0, () => {
        expect(Utils.nextDateForMonthlyDay(12, '2026-08-05')).assertEqual('2026-08-12')
        expect(Utils.nextDateForMonthlyDay(12, '2026-08-06')).assertEqual('2026-08-12')
      })
      it('还款日当天_取本月', 0, () => {
        expect(Utils.nextDateForMonthlyDay(12, '2026-08-12')).assertEqual('2026-08-12')
      })
      it('本月还款日已过_取下月', 0, () => {
        expect(Utils.nextDateForMonthlyDay(12, '2026-08-13')).assertEqual('2026-09-12')
      })
      it('次月还款日_跨月正确', 0, () => {
        expect(Utils.nextDateForMonthlyDay(5, '2026-08-06')).assertEqual('2026-09-05')
        expect(Utils.nextDateForMonthlyDay(5, '2026-08-05')).assertEqual('2026-08-05')
      })
      it('31号在小月收敛到月末', 0, () => {
        expect(Utils.nextDateForMonthlyDay(31, '2026-02-10')).assertEqual('2026-02-28')
        expect(Utils.nextDateForMonthlyDay(31, '2024-02-10')).assertEqual('2024-02-29')
        expect(Utils.nextDateForMonthlyDay(31, '2026-03-01')).assertEqual('2026-03-31')
      })
      it('1号_已过取下月', 0, () => {
        expect(Utils.nextDateForMonthlyDay(1, '2026-08-06')).assertEqual('2026-09-01')
        expect(Utils.nextDateForMonthlyDay(1, '2026-08-01')).assertEqual('2026-08-01')
      })
    })

    // ─── generateId ─────────────────────────────────────────
    describe('generateId', () => {
      it('长度为32', 0, () => {
        const id = Utils.generateId()
        expect(id.length).assertEqual(32)
      })
      it('仅包含十六进制字符', 0, () => {
        const id = Utils.generateId()
        const regex = /^[0-9a-f]{32}$/
        expect(regex.test(id)).assertTrue()
      })
      it('唯一性', 0, () => {
        const id1 = Utils.generateId()
        const id2 = Utils.generateId()
        expect(id1 !== id2).assertTrue()
      })
    })

    // ─── generateUuid ───────────────────────────────────────
    describe('generateUuid', () => {
      it('长度为36', 0, () => {
        const uuid = Utils.generateUuid()
        expect(uuid.length).assertEqual(36)
      })
      it('格式为8-4-4-4-12', 0, () => {
        const uuid = Utils.generateUuid()
        const regex = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/
        expect(regex.test(uuid)).assertTrue()
      })
      it('版本号为4', 0, () => {
        const uuid = Utils.generateUuid()
        expect(uuid.charAt(14)).assertEqual('4')
      })
      it('唯一性', 0, () => {
        const uuid1 = Utils.generateUuid()
        const uuid2 = Utils.generateUuid()
        expect(uuid1 !== uuid2).assertTrue()
      })
    })

    // ─── clamp ──────────────────────────────────────────────
    describe('clamp', () => {
      it('值在范围内', 0, () => {
        expect(Utils.clamp(5, 0, 10)).assertEqual(5)
      })
      it('值小于最小值', 0, () => {
        expect(Utils.clamp(-5, 0, 10)).assertEqual(0)
      })
      it('值大于最大值', 0, () => {
        expect(Utils.clamp(15, 0, 10)).assertEqual(10)
      })
      it('值等于边界', 0, () => {
        expect(Utils.clamp(0, 0, 10)).assertEqual(0)
        expect(Utils.clamp(10, 0, 10)).assertEqual(10)
      })
    })

    // ─── bpToPercent ────────────────────────────────────────
    describe('bpToPercent', () => {
      it('正常基点转换', 0, () => {
        expect(Utils.bpToPercent(100)).assertEqual(1)
        expect(Utils.bpToPercent(500)).assertEqual(5)
        expect(Utils.bpToPercent(50)).assertEqual(0.5)
      })
      it('零基点', 0, () => {
        expect(Utils.bpToPercent(0)).assertEqual(0)
      })
      it('负基点', 0, () => {
        expect(Utils.bpToPercent(-100)).assertEqual(-1)
      })
    })

    // ─── formatNotificationTime ─────────────────────────────
    describe('formatNotificationTime', () => {
      it('刚刚（60秒内）', 0, () => {
        const now = new Date()
        const result = Utils.formatNotificationTime(now)
        expect(result).assertEqual('刚刚')
      })
      it('分钟前', 0, () => {
        const d = new Date(Date.now() - 5 * 60 * 1000)
        const result = Utils.formatNotificationTime(d)
        expect(result).assertEqual('5分钟前')
      })
      it('小时前', 0, () => {
        const d = new Date(Date.now() - 3 * 60 * 60 * 1000)
        const result = Utils.formatNotificationTime(d)
        expect(result).assertEqual('3小时前')
      })
    })

    // ─── hexToRgba ──────────────────────────────────────────
    describe('hexToRgba', () => {
      it('6位hex转换', 0, () => {
        expect(Utils.hexToRgba('#FF0000', 0.5)).assertEqual('rgba(255, 0, 0, 0.5)')
        expect(Utils.hexToRgba('#00FF00', 1)).assertEqual('rgba(0, 255, 0, 1)')
        expect(Utils.hexToRgba('#0000FF', 0)).assertEqual('rgba(0, 0, 255, 0)')
      })
      it('黑色和白色', 0, () => {
        expect(Utils.hexToRgba('#000000', 0.5)).assertEqual('rgba(0, 0, 0, 0.5)')
        expect(Utils.hexToRgba('#FFFFFF', 1)).assertEqual('rgba(255, 255, 255, 1)')
      })
      it('非hex字符串直接返回', 0, () => {
        expect(Utils.hexToRgba('rgba(1,2,3,0.5)', 1)).assertEqual('rgba(1,2,3,0.5)')
      })
    })
  })
}
