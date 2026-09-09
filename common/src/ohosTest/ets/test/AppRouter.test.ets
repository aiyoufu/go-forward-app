import { describe, it, expect } from '@ohos/hypium'
import { AppRouter, RouteNames } from '../../../main/ets/common/AppRouter'

export default function appRouterTest() {
  describe('AppRouter', () => {
    it('RouteNames非空', 0, () => {
      expect(RouteNames.MAIN.length > 0).assertTrue()
      expect(RouteNames.SPLASH.length > 0).assertTrue()
    })
    it('isSecondary_表单与资料为次级', 0, () => {
      expect(RouteNames.isSecondary(RouteNames.DEBT_FORM)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.AVATAR_CROP)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.PROFILE)).assertTrue()
      expect(RouteNames.isSecondary(RouteNames.NOTIFICATIONS)).assertTrue()
    })
    it('isSecondary_Splash与Main非次级', 0, () => {
      expect(RouteNames.isSecondary(RouteNames.MAIN)).assertFalse()
      expect(RouteNames.isSecondary(RouteNames.SPLASH)).assertFalse()
      expect(RouteNames.isSecondary(RouteNames.LOGIN)).assertFalse()
    })
    it('stack存在', 0, () => {
      expect(AppRouter.stack !== null).assertTrue()
    })
    it('size非负', 0, () => {
      expect(AppRouter.size() >= 0).assertTrue()
    })
  })
}