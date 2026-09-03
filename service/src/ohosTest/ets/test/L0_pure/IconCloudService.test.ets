import { describe, it, expect } from '@ohos/hypium'
import { IconCloudService } from '../../../../main/ets/service/platform/IconCloudService'
import { Constants } from 'common'

export default function iconCloudServiceTest() {
  describe('IconCloudService_needsUpload', () => {
    it('file与internal需要上传', 0, () => {
      expect(IconCloudService.needsUpload('file:///data/storage/el2/base/files/icon_1.png')).assertTrue()
      expect(IconCloudService.needsUpload('internal://cache/icon.png')).assertTrue()
    })
    it('http(s)与空串不上传', 0, () => {
      expect(IconCloudService.needsUpload('https://x.supabase.co/storage/v1/object/public/debt-icons/a.png')).assertFalse()
      expect(IconCloudService.needsUpload('http://cdn.example/a.png')).assertFalse()
      expect(IconCloudService.needsUpload('')).assertFalse()
    })
  })

  describe('IconCloudService_bucketForTable', () => {
    it('按表名分桶', 0, () => {
      expect(IconCloudService.bucketForTable(Constants.TABLE_DEBTS)).assertEqual('debt-icons')
      expect(IconCloudService.bucketForTable(Constants.TABLE_CREDIT_ACCOUNTS)).assertEqual('credit-account-icons')
      expect(IconCloudService.bucketForTable(Constants.TABLE_SUBSCRIPTIONS)).assertEqual('subscription-icons')
    })
  })

  describe('IconCloudService_localAbsPath', () => {
    it('去掉file前缀', 0, () => {
      expect(IconCloudService.localAbsPath('file:///data/a.png')).assertEqual('/data/a.png')
    })
  })
}
