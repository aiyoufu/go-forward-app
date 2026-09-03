import { describe, it, expect } from '@ohos/hypium'
import { SupabaseConfig } from '../../../main/ets/common/SupabaseConfig'

/**
 * 只校验 isConfigured 的判定逻辑，不断言本机是否已填真值：
 * SupabaseConfig.ets 不入库，克隆者填与不填都必须让本套测试通过。
 */
export default function supabaseConfigTest() {
  describe('SupabaseConfig', () => {

    it('URL与ANON_KEY均为字符串', 0, () => {
      expect(typeof SupabaseConfig.URL).assertEqual('string')
      expect(typeof SupabaseConfig.ANON_KEY).assertEqual('string')
    })

    it('isConfigured返回boolean', 0, () => {
      expect(typeof SupabaseConfig.isConfigured()).assertEqual('boolean')
    })

    it('isConfigured等价于两项均非空', 0, () => {
      const expected = SupabaseConfig.URL.length > 0 && SupabaseConfig.ANON_KEY.length > 0
      expect(SupabaseConfig.isConfigured()).assertEqual(expected)
    })

    it('已配置时URL为https', 0, () => {
      if (SupabaseConfig.isConfigured()) {
        expect(SupabaseConfig.URL.startsWith('https://')).assertTrue()
      } else {
        expect(true).assertTrue()
      }
    })
  })
}
