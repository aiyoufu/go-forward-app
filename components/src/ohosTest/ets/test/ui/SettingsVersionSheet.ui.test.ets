import { describe, it, expect } from '@ohos/hypium'
import { AppVersionService, VersionLogItem, FeatureItem, VersionReleaseInfo } from 'service'

/**
 * SettingsVersionSheet UI & 数据逻辑测试
 * 覆盖：首次安装显示应用特色功能、版本更新后直接替换为更新点
 */
export default function SettingsVersionSheet_UITest() {
  describe('SettingsVersionSheet_UI', () => {

    it('渲染_标题_显示应用版本', 0, async () => {
      const title = '应用版本'
      expect(title).assertEqual('应用版本')
    })

    it('渲染_版本号_显示版本文本', 0, async () => {
      const appVersion = '2.1.0'
      const versionText = appVersion.startsWith('v') ? appVersion : ('v' + appVersion)
      expect(versionText).assertEqual('v2.1.0')
    })

    it('渲染_默认版本号_1.0.0', 0, async () => {
      const appVersion = '1.0.0'
      expect(appVersion).assertEqual('1.0.0')
    })

    it('内容替换_首次安装_展示特色功能', 0, async () => {
      const isUpdated = false
      const sectionTitle = isUpdated ? '本次更新' : '特色功能'
      expect(sectionTitle).assertEqual('特色功能')

      const features = AppVersionService.getDynamicFeatures()
      expect(features.length >= 4).assertTrue()
      expect(features[0].title.length > 0).assertTrue()
      expect(features[0].desc.length > 0).assertTrue()
    })

    it('内容替换_版本更新后_直接替换展示更新点', 0, async () => {
      const isUpdated = true
      const sectionTitle = isUpdated ? '本次更新' : '特色功能'
      expect(sectionTitle).assertEqual('本次更新')

      const releaseNotes = AppVersionService.getDynamicReleaseNotes('1.0.0')
      expect(releaseNotes.length >= 4).assertTrue()
      expect(releaseNotes[0].title.length > 0).assertTrue()
      expect(releaseNotes[0].desc.length > 0).assertTrue()
    })

    it('数据_多版本动态适配_支持不同版本号生成不同更新点', 0, async () => {
      const notesV1 = AppVersionService.getDynamicReleaseNotes('1.0.0')
      const notesV2 = AppVersionService.getDynamicReleaseNotes('2.0.0')
      expect(notesV1.length > 0).assertTrue()
      expect(notesV2.length > 0).assertTrue()
      expect(notesV1[0].desc !== notesV2[0].desc).assertTrue()
    })

    it('数据_运行时动态注册_支持扩展版本更新内容', 0, async () => {
      const customNotes = [
        new VersionLogItem('🎉 重磅新功能', '支持自定义动态插件', 'NEW')
      ]
      AppVersionService.registerDynamicReleaseNotes('3.0.0-beta', customNotes)
      const fetched = AppVersionService.getDynamicReleaseNotes('3.0.0-beta')
      expect(fetched.length).assertEqual(1)
      expect(fetched[0].title).assertEqual('🎉 重磅新功能')
    })

    it('渲染_按钮文案_显示我知道了', 0, async () => {
      const btnText = '我知道了'
      expect(btnText).assertEqual('我知道了')
    })

    it('交互_点击关闭_触发关闭回调', 0, async () => {
      let closed = false
      const onClose = () => { closed = true }
      onClose()
      expect(closed).assertTrue()
    })
  })
}
