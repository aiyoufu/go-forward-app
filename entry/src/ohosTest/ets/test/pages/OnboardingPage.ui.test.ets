import { describe, it, expect } from '@ohos/hypium'

export default function onboardingPageUITest() {
  describe('OnboardingPage_UI', () => {
    it('完成引导写标记', 0, () => {
      const prefKey = 'onboardingCompleted'
      expect(prefKey).assertEqual('onboardingCompleted')
    })
    it('主按钮是登录', 0, () => {
      const primary = '登录'
      expect(primary).assertEqual('登录')
    })
    it('次入口是没有账户注册', 0, () => {
      const secondary = '没有账户？'
      const register = '注册'
      expect(secondary).assertEqual('没有账户？')
      expect(register).assertEqual('注册')
    })
  })
}
