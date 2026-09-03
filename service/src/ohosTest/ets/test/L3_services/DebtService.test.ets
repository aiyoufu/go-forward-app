import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { DebtService } from '../../mock/DebtService.mock'

const userId = 'test-user-001'

function debtObj(id: string = 'debt-001', platform: string = '京东白条', status: string = 'active',
  nextPaymentDate: string = '2024-12-15'): Record<string, string | number | boolean> {
  const base = new Object() as Record<string, string | number | boolean>
  base['id'] = id
  base['user_id'] = userId
  base['platform'] = platform
  base['status'] = status
  base['next_payment_date'] = nextPaymentDate
  return base
}

export default function debtServiceTest() {
  beforeEach(() => {
    DebtService._reset()
  })

  describe('DebtService_getDebts', () => {
    it('空预设_返回空数组', 0, async () => {
      const result = await DebtService.getDebts(userId)
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回全部债务', 0, async () => {
      DebtService._setPresetDebts([debtObj(), debtObj('debt-002')])
      const result = await DebtService.getDebts(userId)
      expect(result.length).assertEqual(2)
      const r0 = result[0] as Record<string, string>
      const r1 = result[1] as Record<string, string>
      expect(r0['id']).assertEqual('debt-001')
      expect(r1['id']).assertEqual('debt-002')
    })

    it('不传userId_也返回全部', 0, async () => {
      DebtService._setPresetDebts([debtObj()])
      const result = await DebtService.getDebts()
      expect(result.length).assertEqual(1)
    })
  })

  describe('DebtService_getDebtsPaged', () => {
    it('分页_第一页', 0, async () => {
      DebtService._setPresetDebts([debtObj('d1'), debtObj('d2'), debtObj('d3')])
      const result = await DebtService.getDebtsPaged(0, 2)
      expect(result.length).assertEqual(2)
      expect((result[0] as Record<string, string>)['id']).assertEqual('d1')
      expect((result[1] as Record<string, string>)['id']).assertEqual('d2')
    })

    it('分页_第二页', 0, async () => {
      DebtService._setPresetDebts([debtObj('d1'), debtObj('d2'), debtObj('d3')])
      const result = await DebtService.getDebtsPaged(2, 2)
      expect(result.length).assertEqual(1)
      expect((result[0] as Record<string, string>)['id']).assertEqual('d3')
    })

    it('分页_超出范围返回空', 0, async () => {
      DebtService._setPresetDebts([debtObj()])
      const result = await DebtService.getDebtsPaged(10, 5)
      expect(result.length).assertEqual(0)
    })
  })

  describe('DebtService_getDebtById', () => {
    it('存在_返回对象', 0, async () => {
      DebtService._setPresetDebts([debtObj(), debtObj('debt-002', '花呗')])
      const result = await DebtService.getDebtById('debt-002')
      expect(result !== null).assertTrue()
      expect((result as Record<string, string>)['id']).assertEqual('debt-002')
    })

    it('不存在_返回null', 0, async () => {
      DebtService._setPresetDebts([debtObj()])
      const result = await DebtService.getDebtById('missing')
      expect(result === null).assertTrue()
    })
  })

  describe('DebtService_mutations_smoke', () => {
    it('createDebt不抛', 0, async () => {
      await DebtService.createDebt(debtObj())
      expect(true).assertTrue()
    })
    it('updateDebt不抛', 0, async () => {
      await DebtService.updateDebt('debt-001', debtObj())
      expect(true).assertTrue()
    })
    it('deleteDebt不抛', 0, async () => {
      await DebtService.deleteDebt('debt-001')
      expect(true).assertTrue()
    })
    it('updateDebtStatus不抛', 0, async () => {
      await DebtService.updateDebtStatus('debt-001', 'completed')
      expect(true).assertTrue()
    })
  })
}
