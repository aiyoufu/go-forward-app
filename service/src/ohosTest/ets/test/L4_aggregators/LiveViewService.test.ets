import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { LiveViewService } from '../../../../main/ets/service/LiveViewService'
import { Debt } from 'common'
import { DebtService } from '../../mock/DebtService.mock'
import { UserService } from '../../mock/UserService.mock'

function makeDebt(overrides: Record<string, string | number | boolean> = {}): Debt {
  const d = new Debt()
  d.id = 'd1'
  d.user_id = 'test-user-001'
  d.platform = '花呗'
  d.debt_type = 'installment'
  d.principal = 120000
  d.current_balance = 80000
  d.monthly_payment = 12000
  d.total_periods = 12
  d.remaining_periods = 8
  d.repayment_method = 'equal_payment'
  d.annual_rate_bp = 600
  d.payment_day = 15
  d.next_payment_date = '2099-12-15'
  d.start_date = '2024-01-01'
  d.status = 'active'
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(d as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return d
}

export default function liveViewServiceTest() {
  beforeEach(() => {
    DebtService._reset()
    UserService._reset()
  })

  describe('LiveViewService_refresh', () => {
    it('未登录_不抛异常', 0, async () => {
      UserService.setCurrentUserId('')
      await LiveViewService.refresh()
      expect(true).assertTrue()
    })

    it('已登录无债务_不抛异常', 0, async () => {
      UserService.setCurrentUserId('test-user-001')
      await LiveViewService.refresh()
      expect(true).assertTrue()
    })

    it('有今日到期债务_不抛异常', 0, async () => {
      UserService.setCurrentUserId('test-user-001')
      const today = new Date()
      const m = today.getMonth() + 1
      const todayStr = today.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (today.getDate() < 10 ? '0' + today.getDate() : '' + today.getDate())
      DebtService._setPresetDebts([makeDebt({ id: 'd1', next_payment_date: todayStr })])
      await LiveViewService.refresh()
      expect(true).assertTrue()
    })

    it('有逾期债务_不抛异常', 0, async () => {
      UserService.setCurrentUserId('test-user-001')
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', next_payment_date: '2020-01-01' })
      ])
      await LiveViewService.refresh()
      expect(true).assertTrue()
    })

    it('有未来7天到期债务_不抛异常', 0, async () => {
      UserService.setCurrentUserId('test-user-001')
      const future = new Date()
      future.setDate(future.getDate() + 5)
      const m = future.getMonth() + 1
      const futureStr = future.getFullYear() + '-' + (m < 10 ? '0' + m : '' + m) + '-' +
        (future.getDate() < 10 ? '0' + future.getDate() : '' + future.getDate())
      DebtService._setPresetDebts([
        makeDebt({ id: 'd1', next_payment_date: futureStr }),
        makeDebt({ id: 'd2', next_payment_date: futureStr })
      ])
      await LiveViewService.refresh()
      expect(true).assertTrue()
    })

    it('LiveView未启用_不抛异常', 0, async () => {
      UserService.setCurrentUserId('test-user-001')
      // liveViewManager.isLiveViewEnabled 在测试环境通常返回 false 或抛错
      // 内部 try/catch 处理
      await LiveViewService.refresh()
      expect(true).assertTrue()
    })
  })

  describe('LiveViewService_stop', () => {
    it('未启动时stop_不抛异常', 0, async () => {
      await LiveViewService.stop()
      expect(true).assertTrue()
    })

    it('stop后再次stop_不抛异常', 0, async () => {
      await LiveViewService.stop()
      await LiveViewService.stop()
      expect(true).assertTrue()
    })
  })
}
