import { describe, it, expect } from '@ohos/hypium'
import { NFCShareService, NFCSharePayload } from '../../../../main/ets/service/platform/NFCShareService'
import { Debt } from 'common'
import { CreditAccount } from 'common'

function makeDebt(overrides: Partial<Debt>): Debt {
  const d = new Debt()
  for (const key of Object.keys(overrides)) {
    (d as Record<string, Object>)[key] = (overrides as Record<string, Object>)[key]
  }
  return d
}

export default function nfcShareServiceTest() {
  describe('NFCShareService_buildDebtSummary', () => {
    it('正确映射字段', 0, async () => {
      const debt = makeDebt({
        platform: '花呗', current_balance: 500000, monthly_payment: 100000,
        next_payment_date: '2025-06-01', note: '测试备注'
      })
      const payload = NFCShareService.buildDebtSummary(debt)
      expect(payload.type).assertEqual('debt')
      expect(payload.platform).assertEqual('花呗')
      expect(payload.currentBalanceFen).assertEqual(500000)
      expect(payload.monthlyPaymentFen).assertEqual(100000)
      expect(payload.nextPaymentDate).assertEqual('2025-06-01')
      expect(payload.note).assertEqual('测试备注')
    })
    it('空字段', 0, async () => {
      const debt = makeDebt({})
      const payload = NFCShareService.buildDebtSummary(debt)
      expect(payload.type).assertEqual('debt')
      expect(payload.platform).assertEqual('')
    })
  })

  describe('NFCShareService_buildAccountSummary', () => {
    it('正确映射字段', 0, async () => {
      const account = new CreditAccount()
      account.name = '招商信用卡'
      account.last_four = '1234'
      const payload = NFCShareService.buildAccountSummary(account)
      expect(payload.type).assertEqual('account')
      expect(payload.accountName).assertEqual('招商信用卡')
      expect(payload.accountLastFour).assertEqual('1234')
      expect(payload.note).assertEqual('信用账户分享')
    })
  })

  describe('NFCShareService_parsePayload', () => {
    it('有效JSON', 0, async () => {
      const json = JSON.stringify({ type: 'debt', platform: '花呗', currentBalanceFen: 500000 })
      const payload = NFCShareService.parsePayload(json)
      expect((payload) !== null && (payload) !== undefined).assertTrue()
      expect(payload!.type).assertEqual('debt')
      expect(payload!.platform).assertEqual('花呗')
      expect(payload!.currentBalanceFen).assertEqual(500000)
    })
    it('无效JSON返回null', 0, async () => {
      expect(NFCShareService.parsePayload('not json')).assertNull()
    })
    it('空字符串返回null', 0, async () => {
      expect(NFCShareService.parsePayload('')).assertNull()
    })
    it('roundtrip_buildDebtSummary', 0, async () => {
      const debt = makeDebt({
        platform: '借呗', current_balance: 300000, monthly_payment: 50000,
        next_payment_date: '2025-07-01', note: ''
      })
      const original = NFCShareService.buildDebtSummary(debt)
      const json = JSON.stringify(original)
      const parsed = NFCShareService.parsePayload(json)
      expect((parsed) !== null && (parsed) !== undefined).assertTrue()
      expect(parsed!.platform).assertEqual('借呗')
      expect(parsed!.currentBalanceFen).assertEqual(300000)
    })
  })

  describe('NFCShareService_numberArrayToString', () => {
    it('ASCII字符', 0, async () => {
      const bytes = [72, 101, 108, 108, 111]
      expect(NFCShareService.numberArrayToString(bytes)).assertEqual('Hello')
    })
    it('空数组', 0, async () => {
      expect(NFCShareService.numberArrayToString([])).assertEqual('')
    })
    it('双字节UTF8', 0, async () => {
      // 'é' = U+00E9 = 0xC3 0xA9
      const bytes = [0xC3, 0xA9]
      const result = NFCShareService.numberArrayToString(bytes)
      expect(result).assertEqual('é')
    })
    it('三字节UTF8', 0, async () => {
      // '中' = U+4E2D = 0xE4 0xB8 0xAD
      const bytes = [0xE4, 0xB8, 0xAD]
      const result = NFCShareService.numberArrayToString(bytes)
      expect(result).assertEqual('中')
    })
    it('混合ASCII和中文', 0, async () => {
      // 'A' + '中' = [65, 0xE4, 0xB8, 0xAD]
      const bytes = [65, 0xE4, 0xB8, 0xAD]
      const result = NFCShareService.numberArrayToString(bytes)
      expect(result).assertEqual('A中')
    })
  })

  describe('NFCShareService_MIME_TYPE', () => {
    it('MIME_TYPE正确', 0, async () => {
      expect(NFCShareService.MIME_TYPE).assertEqual('application/vnd.goforward.nfcshare')
    })
  })
}
