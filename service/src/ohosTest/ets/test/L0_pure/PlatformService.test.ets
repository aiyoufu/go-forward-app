import { describe, it, expect } from '@ohos/hypium'
import {
  PlatformService, PlatformPreset, SubscriptionPreset,
  CategoryInfo, BillingCycleInfo, BrandVisual
} from '../../../../main/ets/service/platform/PlatformService'

export default function platformServiceTest() {
  describe('PlatformService_getPlatformPreset', () => {
    it('精确匹配_花呗', 0, async () => {
      const preset = PlatformService.getPlatformPreset('花呗')
      expect(preset.color).assertEqual('#1677FF')
      expect(preset.type).assertEqual('installment')
      expect(preset.domain).assertEqual('alipay.com')
    })
    it('精确匹配_借呗', 0, async () => {
      const preset = PlatformService.getPlatformPreset('借呗')
      expect(preset.color).assertEqual('#FF6400')
      expect(preset.type).assertEqual('loan')
    })
    it('精确匹配_京东白条', 0, async () => {
      const preset = PlatformService.getPlatformPreset('京东白条')
      expect(preset.type).assertEqual('installment')
      expect(preset.domain).assertEqual('jd.com')
    })
    it('精确匹配_招商信用卡', 0, async () => {
      const preset = PlatformService.getPlatformPreset('招商信用卡')
      expect(preset.type).assertEqual('credit_card')
    })
    it('模糊匹配_包含关键词', 0, async () => {
      const preset = PlatformService.getPlatformPreset('我的花呗分期')
      expect(preset.type).assertEqual('installment')
    })
    it('模糊匹配_短关键词包含长key', 0, async () => {
      const preset = PlatformService.getPlatformPreset('农行')
      expect(preset.color).assertEqual('#008566')
    })
    it('未找到_返回默认', 0, async () => {
      const preset = PlatformService.getPlatformPreset('完全不存在的平台XYZ')
      expect(preset.type).assertEqual('other')
      expect(preset.defaultAnnualRateBp).assertEqual(1800)
    })
    it('空字符串_返回默认', 0, async () => {
      const preset = PlatformService.getPlatformPreset('')
      expect(preset.type).assertEqual('other')
    })
  })

  describe('PlatformService_getSubscriptionPreset', () => {
    it('精确匹配_Netflix', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('Netflix')
      expect(preset.color).assertEqual('#E50914')
      expect(preset.category).assertEqual('video')
    })
    it('精确匹配_Spotify', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('Spotify')
      expect(preset.category).assertEqual('music')
    })
    it('精确匹配_ChatGPT', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('ChatGPT')
      expect(preset.category).assertEqual('tools')
    })
    it('精确匹配_iCloud', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('iCloud')
      expect(preset.category).assertEqual('storage')
    })
    it('模糊匹配', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('我的Netflix会员')
      expect(preset.category).assertEqual('video')
    })
    it('未找到_返回默认', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('不存在的订阅XYZ')
      expect(preset.category).assertEqual('other')
    })
    it('空字符串', 0, async () => {
      const preset = PlatformService.getSubscriptionPreset('')
      expect(preset.category).assertEqual('other')
    })
  })

  describe('PlatformService_getCategoryInfo', () => {
    it('video分类', 0, async () => {
      const info = PlatformService.getCategoryInfo('video')
      expect(info.label).assertEqual('视频')
    })
    it('music分类', 0, async () => {
      const info = PlatformService.getCategoryInfo('music')
      expect(info.label).assertEqual('音乐')
    })
    it('tools分类', 0, async () => {
      const info = PlatformService.getCategoryInfo('tools')
      expect(info.label).assertEqual('工具')
    })
    it('learning分类', 0, async () => {
      const info = PlatformService.getCategoryInfo('learning')
      expect(info.label).assertEqual('学习')
    })
    it('storage分类', 0, async () => {
      const info = PlatformService.getCategoryInfo('storage')
      expect(info.label).assertEqual('云存储')
    })
    it('未知分类返回other', 0, async () => {
      const info = PlatformService.getCategoryInfo('nonexistent')
      expect(info.label).assertEqual('其他')
    })
  })

  describe('PlatformService_getBillingCycleInfo', () => {
    it('monthly', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('monthly')
      expect(info.label).assertEqual('每月')
      expect(info.monthsPerCycle).assertEqual(1)
    })
    it('quarterly', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('quarterly')
      expect(info.monthsPerCycle).assertEqual(3)
    })
    it('annually', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('annually')
      expect(info.monthsPerCycle).assertEqual(12)
    })
    it('weekly', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('weekly')
      expect(info.monthsPerCycle).assertEqual(0.25)
    })
    it('biweekly', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('biweekly')
      expect(info.monthsPerCycle).assertEqual(0.5)
    })
    it('semiannually', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('semiannually')
      expect(info.monthsPerCycle).assertEqual(6)
    })
    it('未知周期_返回默认monthsPerCycle=1', 0, async () => {
      const info = PlatformService.getBillingCycleInfo('custom_cycle')
      expect(info.monthsPerCycle).assertEqual(1)
    })
  })

  describe('PlatformService_getBrandVisual', () => {
    it('空字符串', 0, async () => {
      const bv = PlatformService.getBrandVisual('')
      expect(bv.mark).assertEqual('户')
      expect(bv.color).assertEqual('#2F3336')
    })
    it('花呗', 0, async () => {
      const bv = PlatformService.getBrandVisual('花呗')
      expect(bv.mark).assertEqual('花')
    })
    it('京东白条', 0, async () => {
      const bv = PlatformService.getBrandVisual('京东白条')
      expect(bv.mark).assertEqual('京')
    })
    it('未知平台_取首字', 0, async () => {
      const bv = PlatformService.getBrandVisual('测试平台')
      expect(bv.mark).assertEqual('测')
    })
    it('matchedKey正确设置', 0, async () => {
      const bv = PlatformService.getBrandVisual('花呗')
      expect(bv.matchedKey).assertEqual('花呗')
    })
    it('无匹配时matchedKey为空', 0, async () => {
      const bv = PlatformService.getBrandVisual('测试平台')
      expect(bv.matchedKey).assertEqual('')
    })
  })

  describe('PlatformService_getLogoUrlForName', () => {
    it('空字符串返回空', 0, async () => {
      expect(PlatformService.getLogoUrlForName('')).assertEqual('')
    })
    it('信贷平台_花呗优先返回内置rawfile', 0, async () => {
      const url = PlatformService.getLogoUrlForName('花呗')
      expect(url.startsWith('$rawfile:credit_logos/')).assertTrue()
    })
    it('已知订阅走域名favicon', 0, async () => {
      const url = PlatformService.getLogoUrlForName('Netflix')
      expect(url.includes('netflix.com')).assertTrue()
    })
    it('未知平台返回空', 0, async () => {
      const url = PlatformService.getLogoUrlForName('完全不存在的XYZ平台')
      expect(url).assertEqual('')
    })
  })

  describe('PlatformService_listLogoCatalog', () => {
    it('非空且含Netflix', 0, () => {
      const list = PlatformService.listLogoCatalog()
      expect(list.length > 0).assertTrue()
      let found = false
      for (let i = 0; i < list.length; i++) {
        if (list[i].name === 'Netflix' && list[i].url.indexOf('netflix.com') >= 0) {
          found = true
        }
      }
      expect(found).assertTrue()
    })
    it('同域名只出现一次', 0, () => {
      const list = PlatformService.listLogoCatalog()
      const seen: Map<string, number> = new Map()
      for (let i = 0; i < list.length; i++) {
        const url = list[i].url
        const n = seen.get(url)
        seen.set(url, n === undefined ? 1 : n + 1)
      }
      const urls = seen.keys()
      for (const u of urls) {
        expect(seen.get(u)).assertEqual(1)
      }
    })
  })

  describe('PlatformService_searchLogoCatalog', () => {
    it('空词返回空', 0, () => {
      expect(PlatformService.searchLogoCatalog('').length).assertEqual(0)
      expect(PlatformService.searchLogoCatalog('   ').length).assertEqual(0)
    })
    it('单字母英文不返回', 0, () => {
      expect(PlatformService.searchLogoCatalog('t').length).assertEqual(0)
    })
    it('apple不命中美团', 0, () => {
      const list = PlatformService.searchLogoCatalog('apple')
      for (let i = 0; i < list.length; i++) {
        expect(list[i].name.indexOf('美团') < 0).assertTrue()
      }
    })
    it('无匹配不猜测域名', 0, () => {
      expect(PlatformService.searchLogoCatalog('zzzznotabrand').length).assertEqual(0)
    })
    it('Netflix不区分大小写', 0, () => {
      const list = PlatformService.searchLogoCatalog('netflix')
      expect(list.length > 0).assertTrue()
      expect(list[0].name).assertEqual('Netflix')
    })
    it('花呗命中且短名靠前', 0, () => {
      const list = PlatformService.searchLogoCatalog('花呗')
      expect(list.length > 0).assertTrue()
      expect(list[0].name).assertEqual('花呗')
    })
    it('空格分词命中ChatGPT', 0, () => {
      const list = PlatformService.searchLogoCatalog('chat gpt')
      expect(list.length > 0).assertTrue()
      expect(list[0].name).assertEqual('ChatGPT')
    })
    it('域名片段命中ChatGPT', 0, () => {
      const list = PlatformService.searchLogoCatalog('openai')
      let found = false
      for (let i = 0; i < list.length; i++) {
        if (list[i].name === 'ChatGPT') {
          found = true
        }
      }
      expect(found).assertTrue()
    })
    it('子串gpt命中', 0, () => {
      expect(PlatformService.logoNameMatches('ChatGPT', 'gpt')).assertTrue()
    })
    it('youtube不匹配Instagram', 0, () => {
      expect(PlatformService.logoNameMatches('Instagram', 'youtube')).assertFalse()
      expect(PlatformService.logoNameMatches('YouTube', 'youtube')).assertTrue()
    })
    it('单字母X只匹配首词为X', 0, () => {
      expect(PlatformService.logoNameMatches('X (前身为 Twitter)', 'x')).assertTrue()
      expect(PlatformService.logoNameMatches('Xbox', 'x')).assertFalse()
      expect(PlatformService.logoNameMatches('Spotify', 'x')).assertFalse()
    })
    it('英文域名iqiyi命中爱奇艺', 0, () => {
      const list = PlatformService.searchLogoCatalog('iqiyi')
      let found = false
      for (let i = 0; i < list.length; i++) {
        if (list[i].name === '爱奇艺') {
          found = true
        }
      }
      expect(found).assertTrue()
    })
  })

  describe('PlatformService_getLocalCreditLogoUrl', () => {
    it('花呗走内置alipay.png', 0, () => {
      const url = PlatformService.getLocalCreditLogoUrl('花呗')
      expect(url).assertEqual('$rawfile:credit_logos/alipay.png')
    })
    it('借呗/花呗借钱共用alipay.png', 0, () => {
      expect(PlatformService.getLocalCreditLogoUrl('借呗'))
        .assertEqual('$rawfile:credit_logos/alipay.png')
      expect(PlatformService.getLocalCreditLogoUrl('花呗借钱'))
        .assertEqual('$rawfile:credit_logos/alipay.png')
    })
    it('微粒贷走wechat.png', 0, () => {
      expect(PlatformService.getLocalCreditLogoUrl('微粒贷'))
        .assertEqual('$rawfile:credit_logos/wechat.png')
    })
    it('京东金条走jd_finance.png', 0, () => {
      expect(PlatformService.getLocalCreditLogoUrl('京东金条'))
        .assertEqual('$rawfile:credit_logos/jd_finance.png')
    })
    it('招联好期贷走独立hqd图', 0, () => {
      expect(PlatformService.getLocalCreditLogoUrl('招联好期贷'))
        .assertEqual('$rawfile:credit_logos/zhaolian_hqd.png')
    })
    it('分期乐命中', 0, () => {
      expect(PlatformService.getLocalCreditLogoUrl('分期乐'))
        .assertEqual('$rawfile:credit_logos/fenqile.png')
    })
    it('关键字子串_还呗命中', 0, () => {
      // 「我的还呗账单」包含 key 「还呗」
      expect(PlatformService.getLocalCreditLogoUrl('我的还呗账单'))
        .assertEqual('$rawfile:credit_logos/haibei.png')
    })
    it('未收录平台返回空', 0, () => {
      expect(PlatformService.getLocalCreditLogoUrl('某个野鸡贷款平台'))
        .assertEqual('')
      expect(PlatformService.getLocalCreditLogoUrl('')).assertEqual('')
    })
    it('最长key优先_避免短名盖掉正解', 0, () => {
      // 「微粒贷」(3字) 与「微信分期」(4字) 同名包含；应匹配更长的微信分期
      expect(PlatformService.getLocalCreditLogoUrl('微信分期还款'))
        .assertEqual('$rawfile:credit_logos/wechat.png')
    })
  })

  describe('PlatformService_getLogoUrlForName_优先本地', () => {
    it('花呗返回rawfile而非Clearbit', 0, () => {
      const url = PlatformService.getLogoUrlForName('花呗')
      expect(url.indexOf('rawfile') >= 0).assertTrue()
      expect(url.indexOf('dnspod') < 0).assertTrue()
    })
    it('微粒贷返回rawfile', 0, () => {
      const url = PlatformService.getLogoUrlForName('微粒贷')
      expect(url).assertEqual('$rawfile:credit_logos/wechat.png')
    })
    it('Netflix走Clearbit', 0, () => {
      const url = PlatformService.getLogoUrlForName('Netflix')
      expect(url.indexOf('dnspod') >= 0).assertTrue()
    })
    it('空名返回空', 0, () => {
      expect(PlatformService.getLogoUrlForName('')).assertEqual('')
    })
  })

  describe('PlatformService_getDebtTypeInfo', () => {
    it('installment', 0, async () => {
      const info = PlatformService.getDebtTypeInfo('installment')
      expect(info.label).assertEqual('分期')
    })
    it('credit_card', 0, async () => {
      const info = PlatformService.getDebtTypeInfo('credit_card')
      expect(info.label).assertEqual('信用卡')
    })
    it('loan', 0, async () => {
      const info = PlatformService.getDebtTypeInfo('loan')
      expect(info.label).assertEqual('贷款')
    })
    it('other', 0, async () => {
      const info = PlatformService.getDebtTypeInfo('other')
      expect(info.label).assertEqual('一次性')
    })
    it('未知类型返回other', 0, async () => {
      const info = PlatformService.getDebtTypeInfo('nonexistent')
      expect(info.label).assertEqual('一次性')
    })
  })

  describe('PlatformService_getAllBillingCycles', () => {
    it('返回列表非空', 0, async () => {
      const cycles = PlatformService.getAllBillingCycles()
      expect(cycles.length).assertLarger(0)
    })
    it('包含monthly', 0, async () => {
      const cycles = PlatformService.getAllBillingCycles()
      expect(cycles.includes('monthly')).assertTrue()
    })
    it('包含quarterly', 0, async () => {
      const cycles = PlatformService.getAllBillingCycles()
      expect(cycles.includes('quarterly')).assertTrue()
    })
    it('包含annually', 0, async () => {
      const cycles = PlatformService.getAllBillingCycles()
      expect(cycles.includes('annually')).assertTrue()
    })
    it('包含weekly', 0, async () => {
      const cycles = PlatformService.getAllBillingCycles()
      expect(cycles.includes('weekly')).assertTrue()
    })
    it('包含10个周期', 0, async () => {
      const cycles = PlatformService.getAllBillingCycles()
      expect(cycles.length).assertEqual(10)
    })
  })
}
