import { describe, it, expect } from '@ohos/hypium'
import {
  cycleAbbr, cycleFullLabel, cycleDurationLabel, durationLabel, metaLine, formatNextDate,
  formatExpiryYmd, isExpired, statusDateLine, expiryLine,
  statusTagText, statusTagRole, creditAccountLabel
} from '../../../main/ets/components/SubscriptionCard'

export default function SubscriptionCardTest() {
  describe('cycleAbbr', () => {
    it('weekly_返回/周', 0, async () => {
      expect(cycleAbbr('weekly')).assertEqual('/周')
    })
    it('once_weekly_返回/周', 0, async () => {
      expect(cycleAbbr('once_weekly')).assertEqual('/周')
    })
    it('biweekly_返回/2周', 0, async () => {
      expect(cycleAbbr('biweekly')).assertEqual('/2周')
    })
    it('monthly_返回/月', 0, async () => {
      expect(cycleAbbr('monthly')).assertEqual('/月')
    })
    it('quarterly_返回/季', 0, async () => {
      expect(cycleAbbr('quarterly')).assertEqual('/季')
    })
    it('once_quarterly_返回/季', 0, async () => {
      expect(cycleAbbr('once_quarterly')).assertEqual('/季')
    })
    it('semiannually_返回/半年', 0, async () => {
      expect(cycleAbbr('semiannually')).assertEqual('/半年')
    })
    it('annually_返回/年', 0, async () => {
      expect(cycleAbbr('annually')).assertEqual('/年')
    })
    it('once_annually_返回/年', 0, async () => {
      expect(cycleAbbr('once_annually')).assertEqual('/年')
    })
    it('once_返回空', 0, async () => {
      expect(cycleAbbr('once')).assertEqual('')
    })
    it('未知_返回空', 0, async () => {
      expect(cycleAbbr('unknown')).assertEqual('')
    })
  })

  describe('cycleFullLabel', () => {
    it('weekly_返回每周', 0, async () => {
      expect(cycleFullLabel('weekly')).assertEqual('每周')
    })
    it('once_weekly_返回一周', 0, async () => {
      expect(cycleFullLabel('once_weekly')).assertEqual('一周')
    })
    it('biweekly_返回每两周', 0, async () => {
      expect(cycleFullLabel('biweekly')).assertEqual('每两周')
    })
    it('monthly_返回每月', 0, async () => {
      expect(cycleFullLabel('monthly')).assertEqual('每月')
    })
    it('quarterly_返回每季', 0, async () => {
      expect(cycleFullLabel('quarterly')).assertEqual('每季')
    })
    it('once_quarterly_返回一季度', 0, async () => {
      expect(cycleFullLabel('once_quarterly')).assertEqual('一季度')
    })
    it('semiannually_返回每半年', 0, async () => {
      expect(cycleFullLabel('semiannually')).assertEqual('每半年')
    })
    it('annually_返回每年', 0, async () => {
      expect(cycleFullLabel('annually')).assertEqual('每年')
    })
    it('once_annually_返回一年', 0, async () => {
      expect(cycleFullLabel('once_annually')).assertEqual('一年')
    })
    it('once_返回一次性', 0, async () => {
      expect(cycleFullLabel('once')).assertEqual('一次性')
    })
    it('未知_返回空', 0, async () => {
      expect(cycleFullLabel('unknown')).assertEqual('')
    })
  })

  describe('cycleDurationLabel', () => {
    it('monthly_返回一个月', 0, async () => {
      expect(cycleDurationLabel('monthly')).assertEqual('一个月')
    })
    it('quarterly_返回一季度', 0, async () => {
      expect(cycleDurationLabel('quarterly')).assertEqual('一季度')
    })
    it('once_quarterly_返回一季度', 0, async () => {
      expect(cycleDurationLabel('once_quarterly')).assertEqual('一季度')
    })
    it('annually_返回一年', 0, async () => {
      expect(cycleDurationLabel('annually')).assertEqual('一年')
    })
    it('semiannually_返回半年', 0, async () => {
      expect(cycleDurationLabel('semiannually')).assertEqual('半年')
    })
    it('weekly_返回一周', 0, async () => {
      expect(cycleDurationLabel('weekly')).assertEqual('一周')
    })
    it('biweekly_返回两周', 0, async () => {
      expect(cycleDurationLabel('biweekly')).assertEqual('两周')
    })
    it('once_返回一个月', 0, async () => {
      expect(cycleDurationLabel('once')).assertEqual('一个月')
    })
    it('未知_返回空', 0, async () => {
      expect(cycleDurationLabel('unknown')).assertEqual('')
    })
  })

  describe('durationLabel', () => {
    it('整月_返回N个月', 0, async () => {
      expect(durationLabel('monthly', 1)).assertEqual('1个月')
      expect(durationLabel('quarterly', 3)).assertEqual('3个月')
      expect(durationLabel('annually', 12)).assertEqual('12个月')
    })
    it('约一周_返回N周', 0, async () => {
      expect(durationLabel('weekly', 0.25)).assertEqual('1周')
      expect(durationLabel('biweekly', 0.5)).assertEqual('2周')
    })
    it('无月数_回退cycleFullLabel', 0, async () => {
      expect(durationLabel('monthly', 0)).assertEqual('每月')
    })
  })

  describe('metaLine', () => {
    it('分类和周期都有_拼接', 0, async () => {
      expect(metaLine('视频', '1个月')).assertEqual('视频 · 1个月')
    })
    it('只有周期_返回周期', 0, async () => {
      expect(metaLine('', '1个月')).assertEqual('1个月')
    })
    it('只有分类_返回分类', 0, async () => {
      expect(metaLine('视频', '')).assertEqual('视频')
    })
    it('都为空_返回空', 0, async () => {
      expect(metaLine('', '')).assertEqual('')
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
      expect(formatNextDate('invalid')).assertEqual('invalid')
    })
  })

  describe('isExpired', () => {
    it('非active_不过期', 0, async () => {
      expect(isExpired('cancelled', '2020-01-01', -100)).assertEqual(false)
    })
    it('active无日期_不过期', 0, async () => {
      expect(isExpired('active', '', 0)).assertEqual(false)
    })
    it('active且过去_过期', 0, async () => {
      expect(isExpired('active', '2020-01-01', -100)).assertEqual(true)
    })
    it('active且未来_不过期', 0, async () => {
      expect(isExpired('active', '2099-01-01', 100)).assertEqual(false)
    })
  })

  describe('statusDateLine', () => {
    it('cancelled_返回已取消', 0, async () => {
      expect(statusDateLine('cancelled', '', '', false, 0)).assertEqual('已取消')
    })
    it('paused_返回已暂停', 0, async () => {
      expect(statusDateLine('paused', '', '', false, 0)).assertEqual('已暂停')
    })
    it('active无日期_返回待设扣费日', 0, async () => {
      expect(statusDateLine('active', '', '', false, 0)).assertEqual('待设扣费日')
    })
    it('非active无日期_返回空', 0, async () => {
      expect(statusDateLine('other', '', '', false, 0)).assertEqual('')
    })
    it('已过期', 0, async () => {
      const result = statusDateLine('active', '2020-01-01', '1月1日', true, -100)
      expect(result.indexOf('已过期')).assertEqual(0)
    })
    it('今天扣费', 0, async () => {
      expect(statusDateLine('active', '2024-06-01', '6月1日', false, 0)).assertEqual('今天扣费')
    })
    it('明天', 0, async () => {
      const result = statusDateLine('active', '2024-06-02', '6月2日', false, 1)
      expect(result.indexOf('明天')).assertEqual(0)
    })
    it('3天内', 0, async () => {
      const result = statusDateLine('active', '2024-06-03', '6月3日', false, 3)
      expect(result.indexOf('3天后')).assertEqual(0)
    })
    it('14天内', 0, async () => {
      const result = statusDateLine('active', '2024-06-10', '6月10日', false, 10)
      expect(result.indexOf('10天后')).assertEqual(0)
    })
    it('超过14天', 0, async () => {
      const result = statusDateLine('active', '2024-07-01', '7月1日', false, 30)
      expect(result.indexOf('下次')).assertEqual(0)
    })
  })

  describe('formatExpiryYmd', () => {
    it('空_返回空', 0, async () => {
      expect(formatExpiryYmd('')).assertEqual('')
    })
    it('ISO日期_转为补零', 0, async () => {
      expect(formatExpiryYmd('2026-08-14')).assertEqual('2026-08-14')
    })
  })

  describe('expiryLine', () => {
    it('无日期_active_待设扣费日', 0, async () => {
      expect(expiryLine('active', '', false, 0)).assertEqual('待设扣费日')
    })
    it('过期', 0, async () => {
      expect(expiryLine('active', '2020-01-01', true, -10)).assertEqual('2020-01-01 已过期')
    })
    it('今天', 0, async () => {
      expect(expiryLine('active', '2026-08-14', false, 0)).assertEqual('2026-08-14 到期')
    })
    it('明天', 0, async () => {
      expect(expiryLine('active', '2026-08-14', false, 1)).assertEqual('2026-08-14 到期')
    })
    it('N天后', 0, async () => {
      expect(expiryLine('active', '2026-08-14', false, 9)).assertEqual('2026-08-14 到期')
    })
  })

  describe('statusTagText', () => {
    it('active_返回生效中', 0, async () => {
      expect(statusTagText('active')).assertEqual('生效中')
    })
    it('paused_返回已暂停', 0, async () => {
      expect(statusTagText('paused')).assertEqual('已暂停')
    })
    it('cancelled_返回已取消', 0, async () => {
      expect(statusTagText('cancelled')).assertEqual('已取消')
    })
  })

  describe('creditAccountLabel', () => {
    it('名称加尾号', 0, async () => {
      expect(creditAccountLabel('招商信用卡', '8344')).assertEqual('招商信用卡(8344)')
    })
    it('仅名称', 0, async () => {
      expect(creditAccountLabel('招商信用卡', '')).assertEqual('招商信用卡')
    })
    it('仅尾号', 0, async () => {
      expect(creditAccountLabel('', '8344')).assertEqual('尾号8344')
    })
  })

  describe('statusTagRole', () => {
    it('active_返回ok', 0, async () => {
      expect(statusTagRole('active')).assertEqual('ok')
    })
    it('paused_返回warn', 0, async () => {
      expect(statusTagRole('paused')).assertEqual('warn')
    })
    it('cancelled_返回off', 0, async () => {
      expect(statusTagRole('cancelled')).assertEqual('off')
    })
  })
}
