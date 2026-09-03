import { describe, it, expect } from '@ohos/hypium'
import { UserSettings } from 'common'
import { SettingsAiBackup, AiBackupSnapshot } from '../../../../main/ets/service/SettingsAiBackup'

export default function settingsAiBackupTest() {
  describe('SettingsAiBackup', () => {
    it('空库用快照恢复文字路径', 0, () => {
      const s = new UserSettings()
      const snap = new AiBackupSnapshot()
      snap.textKey = 'sk-live'
      snap.textUrl = 'https://api.deepseek.com'
      snap.textModel = 'deepseek-v4-flash'
      snap.textFp = 'sk-live\nhttps://api.deepseek.com\ndeepseek-v4-flash'
      snap.textEnabled = true
      expect(SettingsAiBackup.hydrate(s, snap)).assertTrue()
      expect(s.ai_text_key).assertEqual('sk-live')
      expect(s.ai_text_base_url).assertEqual('https://api.deepseek.com')
      expect(s.ai_text_enabled).assertTrue()
    })

    it('库里已有URL不覆盖', 0, () => {
      const s = new UserSettings()
      s.ai_text_base_url = 'https://keep.example'
      const snap = new AiBackupSnapshot()
      snap.textUrl = 'https://other.example'
      SettingsAiBackup.hydrate(s, snap)
      expect(s.ai_text_base_url).assertEqual('https://keep.example')
    })

    it('有Key则开启文字渠道', 0, () => {
      const s = new UserSettings()
      s.ai_text_key = 'sk'
      SettingsAiBackup.repairEnabled(s)
      expect(s.ai_text_enabled).assertTrue()
    })
  })
}
