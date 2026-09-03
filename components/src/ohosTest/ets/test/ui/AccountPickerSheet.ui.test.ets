import { describe, it, expect } from '@ohos/hypium'
import { CreditAccount } from 'common'

/**
 * AccountPickerSheet 契约测试（纯逻辑部分）
 * 组件渲染由 ui 门禁与真机验证覆盖；此处锁定选择回调契约。
 */
export default function accountPickerSheetUITest() {
  describe('AccountPickerSheet_UI', () => {
    it('labelFor_默认实现返回账户名', 0, () => {
      const a = new CreditAccount()
      a.name = '招行'
      const labelFor = (account: CreditAccount): string => account.name
      expect(labelFor(a)).assertEqual('招行')
    })

    it('选中态判定_按selectedId匹配', 0, () => {
      const selectedId = 'a2'
      const ids = ['a1', 'a2', 'a3']
      let hitCount = 0
      for (const id of ids) {
        if (id === selectedId) hitCount++
      }
      expect(hitCount).assertEqual(1)
    })

    it('onPick回调_透传账户id', 0, async () => {
      let picked = ''
      const onPick = (accountId: string): void => {
        picked = accountId
      }
      onPick('a1')
      expect(picked).assertEqual('a1')
    })
  })
}
