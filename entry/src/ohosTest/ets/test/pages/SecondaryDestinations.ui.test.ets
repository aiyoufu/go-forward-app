import { describe, it, expect } from '@ohos/hypium'
import { RouteNames } from 'common'

export default function secondaryDestinationsUITest() {
  describe('SecondaryDestinations', () => {
    it('表单页为次级路由', 0, () => {
      expect(RouteNames.isSecondary(RouteNames.DEBT_FORM)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.SUBSCRIPTION_FORM)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.CREDIT_ACCOUNT_FORM)).assertTrue()
    })
    it('导出资料法律通知为次级', 0, () => {
      expect(RouteNames.isSecondary(RouteNames.EXPORT_IMPORT)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.PROFILE)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.LEGAL)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.NOTIFICATIONS)).assertTrue()
    })
    it('Main与Splash非次级', 0, () => {
      expect(RouteNames.isSecondary(RouteNames.MAIN)).assertFalse()
      expect(RouteNames.isSecondary(RouteNames.SPLASH)).assertFalse()
      expect(RouteNames.isSecondary(RouteNames.LOGIN)).assertFalse()
    })
  })
}
