import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { CreditAccountService } from '../../mock/CreditAccountService.mock'

const userId = 'test-user-001'

function caObj(overrides: Record<string, string | number | boolean> = {}): Record<string, string | number | boolean> {
  const base: Record<string, string | number | boolean> = {
    id: 'ca-001',
    user_id: userId,
    name: '招行信用卡',
    last_four: '1234'
  }
  const keys = Object.keys(overrides)
  for (const k of keys) {
    base[k] = overrides[k]
  }
  return base
}

export default function creditAccountServiceTest() {
  beforeEach(() => {
    CreditAccountService._reset()
  })

  // ── getCreditAccounts ──────────────────────────────
  describe('CreditAccountService_getCreditAccounts', () => {
    it('空预设_返回空数组', 0, async () => {
      const result = await CreditAccountService.getCreditAccounts(userId)
      expect(result.length).assertEqual(0)
    })

    it('预设数据_返回账户列表', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([caObj(), caObj({ id: 'ca-002' })])
      const result = await CreditAccountService.getCreditAccounts(userId)
      expect(result.length).assertEqual(2)
      expect((result[0] as Record<string, string>).id).assertEqual('ca-001')
    })

    it('不传userId_也返回全部', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([caObj()])
      const result = await CreditAccountService.getCreditAccounts()
      expect(result.length).assertEqual(1)
    })
  })

  // ── getCreditAccountById ──────────────────────────────
  describe('CreditAccountService_getCreditAccountById', () => {
    it('存在_返回账户对象', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([caObj(), caObj({ id: 'ca-002', name: '中信信用卡' })])
      const result = await CreditAccountService.getCreditAccountById('ca-002')
      expect(result !== null).assertTrue()
      expect((result as Record<string, string>).name).assertEqual('中信信用卡')
    })

    it('不存在_返回null', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([caObj()])
      const result = await CreditAccountService.getCreditAccountById('nonexistent')
      expect(result === null).assertTrue()
    })

    it('空预设_返回null', 0, async () => {
      const result = await CreditAccountService.getCreditAccountById('any')
      expect(result === null).assertTrue()
    })
  })

  // ── createCreditAccount ──────────────────────────────
  describe('CreditAccountService_createCreditAccount', () => {
    it('返回空对象', 0, async () => {
      const result = await CreditAccountService.createCreditAccount({ name: '测试' })
      expect(result !== undefined).assertTrue()
    })
  })

  // ── updateCreditAccount ──────────────────────────────
  describe('CreditAccountService_updateCreditAccount', () => {
    it('调用不抛异常', 0, async () => {
      await CreditAccountService.updateCreditAccount('ca-001', { name: '新名称' })
    })
  })

  // ── deleteCreditAccount ──────────────────────────────
  describe('CreditAccountService_deleteCreditAccount', () => {
    it('调用不抛异常', 0, async () => {
      await CreditAccountService.deleteCreditAccount('ca-001')
    })
  })

  // ── deleteAllByUser ──────────────────────────────
  describe('CreditAccountService_deleteAllByUser', () => {
    it('调用不抛异常', 0, async () => {
      await CreditAccountService.deleteAllByUser(userId)
    })
  })

  // ── updateSortOrder ──────────────────────────────
  describe('CreditAccountService_updateSortOrder', () => {
    it('调用不抛异常', 0, async () => {
      await CreditAccountService.updateSortOrder(['ca-001', 'ca-002', 'ca-003'])
    })

    it('空列表_调用不抛异常', 0, async () => {
      await CreditAccountService.updateSortOrder([])
    })
  })

  // ── _reset ──────────────────────────────────────
  describe('CreditAccountService__reset', () => {
    it('重置后getCreditAccounts返回空', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([caObj()])
      CreditAccountService._reset()
      const result = await CreditAccountService.getCreditAccounts(userId)
      expect(result.length).assertEqual(0)
    })
  })

  // ── matchAccountByFileName ──────────────────────────────
  describe('CreditAccountService_matchAccountByFileName', () => {
    it('空文件名_返回空', 0, () => {
      const r = CreditAccountService.matchAccountByFileName('', [caObj({ name: '招商银行信用卡' })])
      expect(r).assertEqual('')
    })

    it('空账户列表_返回空', 0, () => {
      const r = CreditAccountService.matchAccountByFileName('招商.jpg', [])
      expect(r).assertEqual('')
    })

    it('子串命中_账户名完整出现在文件名中', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        '招商银行信用卡单据.jpg',
        [caObj({ name: '招商银行信用卡' })]
      )
      expect(r).assertEqual('招商银行信用卡')
    })

    it('首段token命中_账户名包含文件名首段', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        'CMB_2024.jpg',
        [caObj({ name: 'CMB信用卡' })]
      )
      expect(r).assertEqual('CMB信用卡')
    })

    it('多账户命中_取最长账户名', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        '花呗分期单据.jpg',
        [caObj({ id: 'ca-a', name: '花呗' }), caObj({ id: 'ca-b', name: '花呗分期' })]
      )
      expect(r).assertEqual('花呗分期')
    })

    it('扩展名剥离_仍能命中', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        '花呗.png',
        [caObj({ name: '花呗' })]
      )
      expect(r).assertEqual('花呗')
    })

    it('大小写不敏感_ASCII匹配', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        'cmb.jpg',
        [caObj({ name: 'CMB' })]
      )
      expect(r).assertEqual('CMB')
    })

    it('无命中_返回空串', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        'IMG_001.jpg',
        [caObj({ name: '招商银行信用卡' })]
      )
      expect(r).assertEqual('')
    })

    it('单字符token_不触发token命中', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        'A_2024.jpg',
        [caObj({ name: 'A信用卡' })]
      )
      expect(r).assertEqual('')
    })

    it('账户名为空_跳过该账户', 0, () => {
      const r = CreditAccountService.matchAccountByFileName(
        '招商.jpg',
        [caObj({ name: '' }), caObj({ id: 'ca-b', name: '招商' })]
      )
      expect(r).assertEqual('招商')
    })
  })
}
