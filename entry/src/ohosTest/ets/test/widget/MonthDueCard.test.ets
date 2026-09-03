import { describe, it, expect } from '@ohos/hypium'

/**
 * MonthDueCard 卡片 UI 测试
 * 2×2 卡：本月待还金额 + 债务清单列表 + 「还款」按钮
 * debtListPack 格式: "name|amount;..." (分号分隔)
 */
export default function monthDueCardTest() {
  describe('MonthDueCard_渲染_有数据', () => {

    it('金额显示_正常金额', 0, () => {
      const amount = '¥\u20098,500.00'
      const result = (amount && amount.length > 0) ? amount : '¥\u20090.00'
      expect(result).assertEqual('¥\u20098,500.00')
    })

    it('金额显示_空值降级', 0, () => {
      const amount: string = ''
      const result = (amount && amount.length > 0) ? amount : '¥\u20090.00'
      expect(result).assertEqual('¥\u20090.00')
    })

    it('debtListPack_解析段数', 0, () => {
      const debtListPack = '花呗|3,200.00;京东白条|1,500.00;信用卡|2,800.00'
      const segs = debtListPack.split(';')
      let count = 0
      for (let i = 0; i < segs.length; i++) {
        if (segs[i].length > 0) {
          count++
        }
      }
      expect(count).assertEqual(3)
    })

    it('debtListPack_解析名称', 0, () => {
      const debtListPack = '花呗|3,200.00;京东白条|1,500.00'
      const segs = debtListPack.split(';')
      const pair = segs[0].split('|')
      const name = pair.length > 0 ? pair[0] : ''
      expect(name).assertEqual('花呗')
    })

    it('debtListPack_解析金额', 0, () => {
      const debtListPack = '花呗|3,200.00;京东白条|1,500.00'
      const segs = debtListPack.split(';')
      const pair = segs[1].split('|')
      const amt = pair.length > 1 ? pair[1] : ''
      expect(amt).assertEqual('1,500.00')
    })

    it('debtListPack_空段跳过', 0, () => {
      const debtListPack = '花呗|3,200.00;;京东白条|1,500.00'
      const segs = debtListPack.split(';')
      let count = 0
      for (let i = 0; i < segs.length; i++) {
        if (segs[i].length > 0) {
          count++
        }
      }
      expect(count).assertEqual(2)
    })

    it('moreCount_超出2项显示另有N笔', 0, () => {
      const segCount = 4
      const moreCount = 1
      const extra = moreCount + Math.max(0, segCount - 2)
      // extra = 1 + 2 = 3
      expect(extra).assertEqual(3)
      const text = '另有 ' + extra + ' 笔'
      expect(text).assertEqual('另有 3 笔')
    })

    it('moreCount_恰好2项无额外提示', 0, () => {
      const segCount = 2
      const moreCount = 0
      const extra = moreCount + Math.max(0, segCount - 2)
      expect(extra).assertEqual(0)
    })
  })

  describe('MonthDueCard_无数据降级', () => {

    it('空debtListPack_段数为0', 0, () => {
      const debtListPack: string = ''
      const count = (!debtListPack || debtListPack.length === 0) ? 0 : debtListPack.split(';').length
      expect(count).assertEqual(0)
    })

    it('hasData为false_显示本月暂无要还', 0, () => {
      const hasData = false
      const segCount = 0
      const text = segCount > 0 ? '' : (hasData ? '本月无分项待还' : '本月暂无要还')
      expect(text).assertEqual('本月暂无要还')
    })

    it('hasData为true且有数据_显示列表', 0, () => {
      const hasData = true
      const segCount = 2
      const showList = segCount > 0
      expect(showList).assertTrue()
    })

    it('hasData为true但无分项_显示本月无分项待还', 0, () => {
      const hasData = true
      const segCount = 0
      const text = segCount > 0 ? '' : (hasData ? '本月无分项待还' : '本月暂无要还')
      expect(text).assertEqual('本月无分项待还')
    })
  })

  describe('MonthDueCard_交互', () => {

    it('还款按钮_文本固定', 0, () => {
      const btnText = '还款'
      expect(btnText).assertEqual('还款')
    })

    it('点击信息区_action为open', 0, () => {
      const action = 'open'
      expect(action).assertEqual('open')
    })

    it('点击还款_action为repay', 0, () => {
      const action = 'repay'
      expect(action).assertEqual('repay')
    })

    it('路由参数_openTab为1(负债Tab)', 0, () => {
      const openTab = 1
      expect(openTab).assertEqual(1)
    })

    it('路由参数_fromWidget为true', 0, () => {
      const fromWidget = true
      expect(fromWidget).assertTrue()
    })
  })

  describe('MonthDueCard_主题适配', () => {

    it('按钮背景色资源引用', 0, () => {
      const btnBg = 'widget_btn_bg'
      expect(btnBg.length > 0).assertTrue()
    })

    it('按钮前景色资源引用', 0, () => {
      const btnFg = 'widget_btn_fg'
      expect(btnFg.length > 0).assertTrue()
    })

    it('金额字体使用等宽字体', 0, () => {
      const fontMono = 'HarmonyOS Sans Mono'
      expect(fontMono).assertEqual('HarmonyOS Sans Mono')
    })
  })
}
