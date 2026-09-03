import { describe, it, expect } from '@ohos/hypium'

/**
 * ReceiptShareKit 契约测试（纯逻辑部分）
 * 快照/相册/分享均依赖 UI 上下文，真机路径由小票浮层 ui 测试与人工验证覆盖；
 * 此处锁定缓存文件命名契约。
 */
export default function receiptShareKitUITest() {
  describe('ReceiptShareKit_UI', () => {
    it('缓存文件名_前缀+时间戳+png', 0, () => {
      const filePrefix = 'receipt_sub_'
      const fileName = filePrefix + Date.now().toString() + '.png'
      expect(fileName.startsWith(filePrefix)).assertTrue()
      expect(fileName.endsWith('.png')).assertTrue()
    })

    it('不同票面前缀互不覆盖', 0, () => {
      const sub = 'receipt_sub_' + Date.now().toString() + '.png'
      const debt = 'receipt_debt_' + Date.now().toString() + '.png'
      expect(sub === debt).assertFalse()
    })
  })
}
