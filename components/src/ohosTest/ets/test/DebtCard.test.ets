import { describe, it, expect } from '@ohos/hypium'
import { Utils } from 'common'
import {
  isOverdue, progressLabel, balanceLine, primaryAmountText,
  formatNextDate, dueLine, isHighRate, statusTagText, statusTagRole
} from '../../../main/ets/components/DebtCard'

export default function DebtCardTest() {
  describe('isOverdue', () => {
    it('非active_不逾期', 0, async () => {
      expect(isOverdue('completed', '2020-01-01', '2024-06-01')).assertEqual(false)
    })
    it('active但无日期_不逾期', 0, async () => {
      expect(isOverdue('active', '', '2024-06-01')).assertEqual(false)
    })
    it('active且日期在过去_逾期', 0, async () => {
      expect(isOverdue('active', '2020-01-01', '2024-06-01')).assertEqual(true)
    })
    it('active且日期在未来_不逾期', 0, async () => {
      expect(isOverdue('active', '2099-01-01', '2024-06-01')).assertEqual(false)
    })
  })

  describe('isHighRate', () => {
    it('利率为0_返回false', 0, async () => {
      expect(isHighRate(0)).assertEqual(false)
    })
    it('低利率_返回false', 0, async () => {
      expect(isHighRate(1200)).assertEqual(false)
    })
    it('利率达阈值_返回true', 0, async () => {
      expect(isHighRate(1800)).assertEqual(true)
    })
    it('利率超阈值_返回true', 0, async () => {
      expect(isHighRate(2400)).assertEqual(true)
    })
    it('利率略低于阈值_返回false', 0, async () => {
      expect(isHighRate(1799)).assertEqual(false)
    })
  })

  describe('progressLabel', () => {
    it('分期已完成', 0, async () => {
      expect(progressLabel('installment', 12, 0, 'completed')).assertEqual('共12期')
    })
    it('分期进行中', 0, async () => {
      expect(progressLabel('installment', 12, 6, 'active')).assertEqual('第6/12期')
    })
    it('一次性已完成', 0, async () => {
      expect(progressLabel('credit_card', 0, 0, 'completed')).assertEqual('')
    })
    it('一次性进行中', 0, async () => {
      expect(progressLabel('credit_card', 0, 0, 'active')).assertEqual('')
    })
    it('分期但totalPeriods为0_走一次性分支', 0, async () => {
      expect(progressLabel('installment', 0, 0, 'active')).assertEqual('')
    })
  })

  describe('balanceLine', () => {
    it('已完成_分期返回期数', 0, async () => {
      expect(balanceLine(0, 'completed', '共12期')).assertEqual('共12期')
    })
    it('分期进行中_返回期数进度', 0, async () => {
      const result = balanceLine(500000, 'active', '第6/12期', 'installment')
      expect(result).assertEqual('第6/12期')
    })
    it('一次性进行中_返回空', 0, async () => {
      const result = balanceLine(500000, 'active', '', 'credit_card')
      expect(result).assertEqual('')
    })
  })

  describe('primaryAmountText', () => {
    it('已完成_返回已结清', 0, async () => {
      expect(primaryAmountText('completed', 10000)).assertEqual('已结清')
    })
    it('已暂停_返回已暂停', 0, async () => {
      expect(primaryAmountText('paused', 10000)).assertEqual('已暂停')
    })
    it('active_返回格式化金额', 0, async () => {
      expect(primaryAmountText('active', 10000)).assertEqual('¥' + Utils.YUAN_GAP + '100.00')
    })
  })

  describe('formatNextDate', () => {
    it('空字符串_返回空', 0, async () => {
      expect(formatNextDate('')).assertEqual('')
    })
    it('正常日期', 0, async () => {
      expect(formatNextDate('2024-06-15')).assertEqual('6月15日')
    })
    it('无效日期_返回原值', 0, async () => {
      expect(formatNextDate('not-a-date')).assertEqual('not-a-date')
    })
  })

  describe('dueLine', () => {
    it('completed_返回空', 0, async () => {
      expect(dueLine('completed', '', false, 0, 0)).assertEqual('')
    })
    it('paused_返回还款已暂停', 0, async () => {
      expect(dueLine('paused', '', false, 0, 0)).assertEqual('还款已暂停')
    })
    it('无日期有paymentDay_返回每月X日', 0, async () => {
      expect(dueLine('active', '', false, 0, 15)).assertEqual('每月15日')
    })
    it('无日期无paymentDay_返回空', 0, async () => {
      expect(dueLine('active', '', false, 0, 0)).assertEqual('')
    })
    it('逾期', 0, async () => {
      const result = dueLine('active', '2020-01-01', true, -100, 0)
      expect(result).assertEqual('2020-01-01 已逾期')
    })
    it('今天还款', 0, async () => {
      expect(dueLine('active', '2024-06-01', false, 0, 0)).assertEqual('2024-06-01 还款')
    })
    it('明天', 0, async () => {
      const result = dueLine('active', '2024-06-02', false, 1, 0)
      expect(result).assertEqual('2024-06-02 还款')
    })
    it('3天内', 0, async () => {
      const result = dueLine('active', '2024-06-03', false, 3, 0)
      expect(result).assertEqual('2024-06-03 还款')
    })
    it('14天内', 0, async () => {
      const result = dueLine('active', '2024-06-10', false, 10, 0)
      expect(result).assertEqual('2024-06-10 还款')
    })
    it('超过14天', 0, async () => {
      const result = dueLine('active', '2024-07-01', false, 30, 0)
      expect(result).assertEqual('2024-07-01 还款')
    })
  })

  describe('statusTagText', () => {
    it('active未逾期_返回进行中', 0, async () => {
      expect(statusTagText('active', '2099-01-01', '2024-06-01')).assertEqual('进行中')
    })
    it('active逾期_返回已逾期', 0, async () => {
      expect(statusTagText('active', '2020-01-01', '2024-06-01')).assertEqual('已逾期')
    })
    it('paused_返回已暂停', 0, async () => {
      expect(statusTagText('paused', '2020-01-01', '2024-06-01')).assertEqual('已暂停')
    })
    it('completed_返回已结清', 0, async () => {
      expect(statusTagText('completed', '', '2024-06-01')).assertEqual('已结清')
    })
  })

  describe('statusTagRole', () => {
    it('active未逾期_ok', 0, async () => {
      expect(statusTagRole('active', '2099-01-01', '2024-06-01')).assertEqual('ok')
    })
    it('active逾期_danger', 0, async () => {
      expect(statusTagRole('active', '2020-01-01', '2024-06-01')).assertEqual('danger')
    })
    it('paused_warn', 0, async () => {
      expect(statusTagRole('paused', '', '2024-06-01')).assertEqual('warn')
    })
    it('completed_off', 0, async () => {
      expect(statusTagRole('completed', '', '2024-06-01')).assertEqual('off')
    })
  })
}
