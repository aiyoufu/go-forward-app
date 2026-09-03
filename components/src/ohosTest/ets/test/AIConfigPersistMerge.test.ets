import { describe, it, expect } from '@ohos/hypium'
import { AIConfigPersistMerge } from '../../main/ets/components/AIConfigPersistMerge'

export default function aiConfigPersistMergeTest() {
  describe('AIConfigPersistMerge', () => {
    it('空草稿保留已存URL', 0, () => {
      expect(AIConfigPersistMerge.pickField('', 'https://api.deepseek.com', false))
        .assertEqual('https://api.deepseek.com')
    })

    it('清除后允许写成空', 0, () => {
      expect(AIConfigPersistMerge.pickField('', 'https://api.deepseek.com', true)).assertEqual('')
    })

    it('一次跳到空串拒绝', 0, () => {
      expect(AIConfigPersistMerge.shouldAcceptFieldChange('https://api.deepseek.com', '')).assertFalse()
    })

    it('伪清空后指纹仍匹配则保留', 0, () => {
      const key = 'sk-test'
      const url = 'https://api.deepseek.com'
      const model = 'deepseek-v4-flash'
      const fp = key + '\n' + url + '\n' + model
      expect(AIConfigPersistMerge.pickFingerprint('', fp, key, url, model, false)).assertEqual(fp)
    })
  })
}
