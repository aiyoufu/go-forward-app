import { describe, it, expect } from '@ohos/hypium'
import { AppVersionService, VersionLogItem, FeatureItem, VersionReleaseInfo } from '../../../../../Index'

export default function AppVersionServiceTest() {
  describe('AppVersionServiceTest', () => {

    it('getDynamicFeatures_返回特色功能列表', 0, () => {
      const features: FeatureItem[] = AppVersionService.getDynamicFeatures()
      expect(features.length >= 4).assertTrue()
      expect(features[0].title.length > 0).assertTrue()
      expect(features[0].desc.length > 0).assertTrue()
    })

    it('getDynamicReleaseNotes_动态匹配不同版本', 0, () => {
      const notesV1: VersionLogItem[] = AppVersionService.getDynamicReleaseNotes('1.0.0')
      const notesV2: VersionLogItem[] = AppVersionService.getDynamicReleaseNotes('2.0.0')
      expect(notesV1.length > 0).assertTrue()
      expect(notesV2.length > 0).assertTrue()
      expect(notesV1[0].desc !== notesV2[0].desc).assertTrue()
    })

    it('registerDynamicReleaseNotes_支持运行时动态注册', 0, () => {
      const testVersion = '9.9.9-test'
      const customItems = [
        new VersionLogItem('🚀 测试更新', '测试动态注册的更新日志', 'TEST')
      ]
      AppVersionService.registerDynamicReleaseNotes(testVersion, customItems)
      const retrieved = AppVersionService.getDynamicReleaseNotes(testVersion)
      expect(retrieved.length).assertEqual(1)
      expect(retrieved[0].title).assertEqual('🚀 测试更新')
      expect(retrieved[0].tag).assertEqual('TEST')
    })

    it('VersionReleaseInfo_默认结构完整', 0, () => {
      const info = new VersionReleaseInfo()
      expect(info.versionName).assertEqual('1.0.0')
      expect(info.isFirstInstall).assertFalse()
      expect(info.isVersionUpdated).assertFalse()
      expect(Array.isArray(info.features)).assertTrue()
      expect(Array.isArray(info.releaseNotes)).assertTrue()
    })
  })
}
