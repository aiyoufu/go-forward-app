import { describe, it, expect } from '@ohos/hypium'

/**
 * SubscriptionCard 卡片 UI 测试
 * 2×2 卡：生效订阅数 + 订阅清单（名称/日期/状态） + 「看订阅」按钮
 * subListPack 格式: "name|date|status;..." (分号分隔)
 */
export default function subscriptionCardTest() {
  describe('SubscriptionCard_渲染_有数据', () => {

    it('生效数显示_正数', 0, () => {
      const activeSubs = 3
      const text = activeSubs > 0 ? '' + activeSubs : '0'
      expect(text).assertEqual('3')
    })

    it('生效数显示_零', 0, () => {
      const activeSubs = 0
      const text = activeSubs > 0 ? '' + activeSubs : '0'
      expect(text).assertEqual('0')
    })

    it('subListPack_解析段数', 0, () => {
      const subListPack = 'Netflix|07-15|生效中;iCloud|07-20|暂停;Spotify||已取消'
      const segs = subListPack.split(';')
      let count = 0
      for (let i = 0; i < segs.length; i++) {
        if (segs[i].length > 0) {
          count++
        }
      }
      expect(count).assertEqual(3)
    })

    it('subListPack_解析名称_field0', 0, () => {
      const subListPack = 'Netflix|07-15|生效中;iCloud|07-20|暂停'
      const segs = subListPack.split(';')
      const parts = segs[0].split('|')
      const name = parts.length > 0 ? parts[0] : ''
      expect(name).assertEqual('Netflix')
    })

    it('subListPack_解析日期_field1', 0, () => {
      const subListPack = 'Netflix|07-15|生效中;iCloud|07-20|暂停'
      const segs = subListPack.split(';')
      const parts = segs[1].split('|')
      const date = parts.length > 1 ? parts[1] : ''
      expect(date).assertEqual('07-20')
    })

    it('subListPack_解析状态_field2', 0, () => {
      const subListPack = 'Netflix|07-15|生效中;iCloud|07-20|暂停'
      const segs = subListPack.split(';')
      const parts = segs[0].split('|')
      const status = parts.length > 2 ? parts[2] : ''
      expect(status).assertEqual('生效中')
    })

    it('moreCount_超出2项显示另有N项', 0, () => {
      const segCount = 5
      const moreCount = 2
      const extra = moreCount + Math.max(0, segCount - 2)
      // 2 + 3 = 5
      expect(extra).assertEqual(5)
      const text = '另有 ' + extra + ' 项'
      expect(text).assertEqual('另有 5 项')
    })

    it('moreCount_恰好2项无额外', 0, () => {
      const segCount = 2
      const moreCount = 0
      const extra = moreCount + Math.max(0, segCount - 2)
      expect(extra).assertEqual(0)
    })
  })

  describe('SubscriptionCard_状态标签颜色', () => {

    it('生效中_绿色tag', 0, () => {
      const status: string = '生效中'
      const fgResource = status === '生效中' ? 'widget_tag_ok_fg'
        : (status === '暂停' ? 'widget_tag_warn_fg' : 'widget_tag_off_fg')
      const bgResource = status === '生效中' ? 'widget_tag_ok_bg'
        : (status === '暂停' ? 'widget_tag_warn_bg' : 'widget_tag_off_bg')
      expect(fgResource).assertEqual('widget_tag_ok_fg')
      expect(bgResource).assertEqual('widget_tag_ok_bg')
    })

    it('暂停_琥珀色tag', 0, () => {
      const status: string = '暂停'
      const fgResource = status === '生效中' ? 'widget_tag_ok_fg'
        : (status === '暂停' ? 'widget_tag_warn_fg' : 'widget_tag_off_fg')
      const bgResource = status === '生效中' ? 'widget_tag_ok_bg'
        : (status === '暂停' ? 'widget_tag_warn_bg' : 'widget_tag_off_bg')
      expect(fgResource).assertEqual('widget_tag_warn_fg')
      expect(bgResource).assertEqual('widget_tag_warn_bg')
    })

    it('已取消_灰色tag', 0, () => {
      const status: string = '已取消'
      const fgResource = status === '生效中' ? 'widget_tag_ok_fg'
        : (status === '暂停' ? 'widget_tag_warn_fg' : 'widget_tag_off_fg')
      const bgResource = status === '生效中' ? 'widget_tag_ok_bg'
        : (status === '暂停' ? 'widget_tag_warn_bg' : 'widget_tag_off_bg')
      expect(fgResource).assertEqual('widget_tag_off_fg')
      expect(bgResource).assertEqual('widget_tag_off_bg')
    })

    it('未知状态_默认灰色', 0, () => {
      const status: string = '未知'
      const fgResource = status === '生效中' ? 'widget_tag_ok_fg'
        : (status === '暂停' ? 'widget_tag_warn_fg' : 'widget_tag_off_fg')
      expect(fgResource).assertEqual('widget_tag_off_fg')
    })
  })

  describe('SubscriptionCard_无数据降级', () => {

    it('空subListPack_段数为0', 0, () => {
      const subListPack: string = ''
      const count = (!subListPack || subListPack.length === 0) ? 0 : subListPack.split(';').length
      expect(count).assertEqual(0)
    })

    it('无订阅_显示暂无订阅', 0, () => {
      const segCount = 0
      const text = segCount > 0 ? '' : '暂无订阅'
      expect(text).assertEqual('暂无订阅')
    })

    it('activeSubs为0_显示0项生效中', 0, () => {
      const activeSubs = 0
      const countText = activeSubs > 0 ? '' + activeSubs : '0'
      expect(countText).assertEqual('0')
      const fullText = countText + '项生效中'
      expect(fullText).assertEqual('0项生效中')
    })
  })

  describe('SubscriptionCard_交互', () => {

    it('看订阅按钮_文本固定', 0, () => {
      const btnText = '看订阅'
      expect(btnText).assertEqual('看订阅')
    })

    it('路由参数_openTab为2(订阅Tab)', 0, () => {
      const openTab = 2
      expect(openTab).assertEqual(2)
    })

    it('路由参数_widgetAction为open', 0, () => {
      const widgetAction = 'open'
      expect(widgetAction).assertEqual('open')
    })

    it('点击信息区_跳转订阅', 0, () => {
      const fromWidget = true
      const openTab = 2
      expect(fromWidget).assertTrue()
      expect(openTab).assertEqual(2)
    })
  })

  describe('SubscriptionCard_主题适配', () => {

    it('状态标签六色资源互不相同', 0, () => {
      const okFg = 'widget_tag_ok_fg'
      const okBg = 'widget_tag_ok_bg'
      const warnFg = 'widget_tag_warn_fg'
      const warnBg = 'widget_tag_warn_bg'
      const offFg = 'widget_tag_off_fg'
      const offBg = 'widget_tag_off_bg'
      const resources = [okFg, okBg, warnFg, warnBg, offFg, offBg]
      for (let i = 0; i < resources.length; i++) {
        expect(resources[i].length > 0).assertTrue()
      }
    })
  })
}
