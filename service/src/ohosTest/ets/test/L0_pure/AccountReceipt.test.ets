import { describe, it, expect } from '@ohos/hypium'
import { CreditAccount } from 'common'
import { AccountReceipt } from '../../../../main/ets/service/AccountReceipt'

function account(name: string, wan: number, payDay: number = 12, lastFour: string = ''): CreditAccount {
  const a = new CreditAccount()
  a.name = name
  a.credit_limit = wan
  a.payment_day = payDay
  a.last_four = lastFour
  return a
}

export default function accountReceiptTest() {
  describe('AccountReceipt', () => {
    it('wanToFen_万元换算分', 0, async () => {
      expect(AccountReceipt.wanToFen(5)).assertEqual(5000000)
      expect(AccountReceipt.wanToFen(5.29)).assertEqual(5290000)
      expect(AccountReceipt.wanToFen(0)).assertEqual(0)
    })
    it('build_空列表安全', 0, async () => {
      const model = AccountReceipt.build([])
      expect(model.itemCount).assertEqual(0)
      expect(model.totalLimitFen).assertEqual(0)
    })
    it('build_按额度降序并汇总', 0, async () => {
      const model = AccountReceipt.build([
        account('招行', 5, 12, '1234'),
        account('工行', 10, 8, '5678')
      ])
      expect(model.itemCount).assertEqual(2)
      expect(model.totalLimitFen).assertEqual(15000000)
      expect(model.lines[0].name).assertEqual('工行')
      expect(model.lines[1].name).assertEqual('招行')
      expect(model.lines[0].cnyFen).assertEqual(10000000)
    })
    it('build_无名用未命名', 0, async () => {
      const model = AccountReceipt.build([account('', 1)])
      expect(model.lines[0].name).assertEqual('未命名账户')
    })
    it('lineSubtitle_还款日与尾号', 0, async () => {
      expect(AccountReceipt.lineSubtitle(account('招行', 5, 12, '1234')))
        .assertEqual('还款 12日 · 尾号 1234')
      expect(AccountReceipt.lineSubtitle(account('招行', 5, 0, ''))).assertEqual('')
      expect(AccountReceipt.lineSubtitle(account('招行', 5, 8, ''))).assertEqual('还款 8日')
    })
  })
}
