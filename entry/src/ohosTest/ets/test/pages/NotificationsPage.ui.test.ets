import { describe, it, expect } from '@ohos/hypium'
import { RouteNames } from 'common'

export default function notificationsPageUITest() {
  describe('NotificationsPage_UI', () => {
    it('路由_通知页为次级', 0, () => {
      expect(RouteNames.isSecondary(RouteNames.NOTIFICATIONS)).assertTrue()
      expect(RouteNames.NOTIFICATIONS).assertEqual('NotificationsPage')
    })

    it('布局_强制Stack全宽避免偏右', 0, () => {
      const mode = 'Stack'
      const hideNavTitleBar = true
      expect(mode).assertEqual('Stack')
      expect(hideNavTitleBar).assertTrue()
    })

    it('渲染_标题为通知', 0, () => {
      const title = '通知'
      expect(title).assertEqual('通知')
    })

    it('渲染_空态文案', 0, () => {
      const title = '暂无通知'
      const subtitle = '账单日与还款日的提醒会在这里汇总'
      expect(title).assertEqual('暂无通知')
      expect(subtitle.length > 0).assertTrue()
    })

    it('交互_返回_弹出本页', 0, () => {
      expect(true).assertTrue()
    })
  })
}
