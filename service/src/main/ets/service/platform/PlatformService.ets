import { DebtType } from 'common'
import { SubscriptionCategory } from 'common'
import { ColorTokens } from 'common'

export class PlatformPreset {
  color: string = ''
  defaultAnnualRateBp: number = 0
  type: DebtType = 'other'
  domain: string = ''

  constructor(color: string, defaultAnnualRateBp: number, type: DebtType, domain: string = '') {
    this.color = color
    this.defaultAnnualRateBp = defaultAnnualRateBp
    this.type = type
    this.domain = domain
  }
}

export class SubscriptionPreset {
  color: string = ''
  category: string = ''
  domain: string = ''

  constructor(color: string, category: string, domain: string = '') {
    this.color = color
    this.category = category
    this.domain = domain
  }
}

export class CategoryInfo {
  label: string = ''
  color: string = ''

  constructor(label: string, color: string) {
    this.label = label
    this.color = color
  }
}

export class BillingCycleInfo {
  label: string = ''
  monthsPerCycle: number = 0

  constructor(label: string, monthsPerCycle: number) {
    this.label = label
    this.monthsPerCycle = monthsPerCycle
  }
}

/** 图标选择面板：可点选的预设品牌（按域名去重） */
export class LogoCatalogItem {
  name: string = ''
  url: string = ''

  constructor(name: string, url: string) {
    this.name = name
    this.url = url
  }
}

/** 品牌视觉：色值 + 短标识（无本地 logo 图时用于头像） */
export class BrandVisual {
  color: string = '#2F3336'
  mark: string = ''
  matchedKey: string = ''

  constructor(color: string, mark: string, matchedKey: string = '') {
    this.color = color
    this.mark = mark
    this.matchedKey = matchedKey
  }
}

export class PlatformService {
  private static readonly PLATFORM_PRESETS: Map<string, PlatformPreset> =
    PlatformService.initPlatformPresets()

  private static readonly SUBSCRIPTION_PRESETS: Map<string, SubscriptionPreset> =
    PlatformService.initSubscriptionPresets()

  private static readonly CATEGORY_CONFIG: Map<string, CategoryInfo> =
    PlatformService.initCategoryConfig()

  private static readonly BILLING_CYCLE_CONFIG: Map<string, BillingCycleInfo> =
    PlatformService.initBillingCycleConfig()

  private static readonly DEBT_TYPE_CONFIG: Map<string, CategoryInfo> =
    PlatformService.initDebtTypeConfig()

  /**
   * 内置信贷平台 logo（rawfile/credit_logos/ 下的 PNG，离线优先命中）。
   * key 必须与 PLATFORM_PRESETS 里的 key 一致；搜「花呗」等场景，搜索面板
   * 优先返回本地图，无网/慢网/平台 logo 缺失都能给出正确视觉。
   */
  private static readonly CREDIT_LOGO_FILES: Map<string, string> =
    PlatformService.initCreditLogoFiles()

  private static initCreditLogoFiles(): Map<string, string> {
    const map = new Map<string, string>()
    map.set('花呗', 'huabei.png')
    map.set('花呗分期', 'huabei.png')
    map.set('借呗', 'alipay.png')
    map.set('花呗借钱', 'huabei.png')
    map.set('微粒贷', 'wechat.png')
    map.set('微信分期', 'wechat.png')
    map.set('京东金条', 'jd_finance.png')
    map.set('京东白条', 'jd_finance.png')
    map.set('度小满', 'duxiaoman.png')
    map.set('招联好期贷', 'zhaolian_hqd.png')
    map.set('美团月付', 'meituan.png')
    map.set('美团', 'meituan.png')
    map.set('抖音月付', 'douyin.png')
    map.set('抖音', 'douyin.png')
    map.set('分期乐', 'fenqile.png')
    map.set('还呗', 'haibei.png')
    map.set('奇富借条', 'qifu_jietiao.png')
    map.set('360借条', 'qifu_jietiao.png')
    map.set('有钱花', 'youqianhua.png')
    map.set('安逸花', 'anyihua.png')
    map.set('招联金融', 'zhaolian.png')
    map.set('放心借', 'douyin.png')
    map.set('滴水贷', 'didi_finance.png')
    map.set('滴滴金融', 'didi_finance.png')
    map.set('唯品花', 'vipshop.png')
    map.set('任性贷', 'xingtu_finance.png')
    map.set('星图金融', 'xingtu_finance.png')
    map.set('天星金融', 'tianxing_finance.png')
    map.set('小米金融', 'tianxing_finance.png')
    map.set('平安普惠', 'pingan_rongyi.png')
    map.set('平安融易', 'pingan_rongyi.png')
    map.set('中邮钱包', 'zhongyou_wallet.png')
    map.set('中邮消费金融', 'zhongyou_wallet.png')
    map.set('中银消费金融', 'bocfc.png')
    map.set('中银消费', 'bocfc.png')
    map.set('拿去花', 'ctrip_finance.png')
    map.set('携程金融', 'ctrip_finance.png')
    map.set('拍拍贷', 'ppdai.png')
    return map
  }

  private static readonly DEFAULT_PRESET: PlatformPreset =
    new PlatformPreset('' + ColorTokens.DEFAULT_FALLBACK, 1800, 'other')

  private static readonly DEFAULT_SUBSCRIPTION_PRESET: SubscriptionPreset =
    new SubscriptionPreset('' + ColorTokens.DEFAULT_FALLBACK, 'other')

  private static initPlatformPresets(): Map<string, PlatformPreset> {
    const map = new Map<string, PlatformPreset>()
    map.set('花呗', new PlatformPreset('#1677FF', 1460, 'installment', 'alipay.com'))
    map.set('花呗分期', new PlatformPreset('#1677FF', 1460, 'installment', 'alipay.com'))
    map.set('借呗', new PlatformPreset('#FF6400', 1460, 'loan', 'alipay.com'))
    map.set('花呗借钱', new PlatformPreset('#FF6400', 1460, 'loan', 'alipay.com'))
    map.set('招商信用卡', new PlatformPreset('#E02020', 1800, 'credit_card', 'cmbchina.com'))
    map.set('建行信用卡', new PlatformPreset('#1677FF', 1800, 'credit_card', 'ccb.com'))
    map.set('工行信用卡', new PlatformPreset('#E02020', 1800, 'credit_card', 'icbc.com.cn'))
    map.set('浦发信用卡', new PlatformPreset('#1677FF', 1800, 'credit_card', 'spdb.com.cn'))
    map.set('京东白条', new PlatformPreset('#E03131', 1460, 'installment', 'jd.com'))
    map.set('京东金条', new PlatformPreset('#E03131', 1800, 'loan', 'jd.com'))
    map.set('微信分期', new PlatformPreset('#07C160', 1800, 'installment', 'tenpay.com'))
    map.set('微粒贷', new PlatformPreset('#07C160', 1800, 'loan', 'webank.com'))
    map.set('度小满', new PlatformPreset('#3B82F6', 1800, 'loan', 'duxiaoman.com'))
    map.set('招联好期贷', new PlatformPreset('#E02020', 1800, 'loan', 'mucfc.com'))
    map.set('美团月付', new PlatformPreset('#FFC300', 1460, 'installment', 'meituan.com'))
    map.set('美团', new PlatformPreset('#FFC300', 1460, 'other', 'meituan.com'))
    map.set('抖音月付', new PlatformPreset('#161823', 1460, 'installment', 'douyin.com'))
    map.set('抖音', new PlatformPreset('#161823', 1460, 'other', 'douyin.com'))
    map.set('中信', new PlatformPreset('#DE1B1B', 1800, 'credit_card', 'citicbank.com'))
    map.set('交通', new PlatformPreset('#092D74', 1800, 'credit_card', 'bankcomm.com'))
    map.set('交行', new PlatformPreset('#092D74', 1800, 'credit_card', 'bankcomm.com'))
    map.set('民生', new PlatformPreset('#005CA1', 1800, 'credit_card', 'cmbc.com.cn'))
    map.set('光大', new PlatformPreset('#701D84', 1800, 'credit_card', 'cebbank.com'))
    map.set('平安', new PlatformPreset('#EA5504', 1800, 'credit_card', 'pingan.com'))
    map.set('兴业', new PlatformPreset('#00469C', 1800, 'credit_card', 'cib.com.cn'))
    map.set('广发', new PlatformPreset('#E20B16', 1800, 'credit_card', 'cgbchina.com.cn'))
    map.set('华夏', new PlatformPreset('#E30613', 1800, 'credit_card', 'hxb.com.cn'))
    map.set('农业', new PlatformPreset('#008566', 1800, 'credit_card', 'abchina.com'))
    map.set('农行', new PlatformPreset('#008566', 1800, 'credit_card', 'abchina.com'))
    map.set('中国银行', new PlatformPreset('#B30024', 1800, 'credit_card', 'boc.cn'))
    map.set('中行', new PlatformPreset('#B30024', 1800, 'credit_card', 'boc.cn'))
    map.set('邮储', new PlatformPreset('#007D40', 1800, 'credit_card', 'psbc.com'))
    map.set('邮政', new PlatformPreset('#007D40', 1800, 'credit_card', 'psbc.com'))
    map.set('浦发', new PlatformPreset('#002D72', 1800, 'credit_card', 'spdb.com.cn'))
    map.set('上海银行', new PlatformPreset('#0055A5', 1800, 'credit_card', 'bankofshanghai.com'))
    map.set('北京银行', new PlatformPreset('#E2001A', 1800, 'credit_card', 'bankofbeijing.com.cn'))
    map.set('放心借', new PlatformPreset('#161823', 1800, 'loan', 'douyin.com'))
    map.set('滴水贷', new PlatformPreset('#FC9153', 1800, 'loan', 'didiglobal.com'))
    map.set('滴滴金融', new PlatformPreset('#FC9153', 1800, 'loan', 'didiglobal.com'))
    map.set('唯品花', new PlatformPreset('#FF2E8A', 1460, 'installment', 'vip.com'))
    map.set('任性贷', new PlatformPreset('#FFAA00', 1800, 'loan', 'suning.com'))
    map.set('星图金融', new PlatformPreset('#FFAA00', 1800, 'loan', 'suning.com'))
    map.set('天星金融', new PlatformPreset('#FF6900', 1800, 'loan', 'mi.com'))
    map.set('小米金融', new PlatformPreset('#FF6900', 1800, 'loan', 'mi.com'))
    map.set('平安普惠', new PlatformPreset('#EA5504', 1800, 'loan', 'pingan.com'))
    map.set('平安融易', new PlatformPreset('#EA5504', 1800, 'loan', 'pingan.com'))
    map.set('中邮钱包', new PlatformPreset('#007D40', 1800, 'loan', 'chinapost.com.cn'))
    map.set('中邮消费金融', new PlatformPreset('#007D40', 1800, 'loan', 'chinapost.com.cn'))
    map.set('中银消费金融', new PlatformPreset('#B30024', 1800, 'loan', 'boc.cn'))
    map.set('中银消费', new PlatformPreset('#B30024', 1800, 'loan', 'boc.cn'))
    map.set('拿去花', new PlatformPreset('#0086F6', 1460, 'installment', 'ctrip.com'))
    map.set('携程金融', new PlatformPreset('#0086F6', 1460, 'installment', 'ctrip.com'))
    map.set('拍拍贷', new PlatformPreset('#0A9AFF', 1800, 'loan', 'ppdai.com'))
    return map
  }

  private static initSubscriptionPresets(): Map<string, SubscriptionPreset> {
    const map = new Map<string, SubscriptionPreset>()
    map.set('Netflix', new SubscriptionPreset('#E50914', 'video', 'netflix.com'))
    map.set('Spotify', new SubscriptionPreset('#1DB954', 'music', 'spotify.com'))
    map.set('Apple Music', new SubscriptionPreset('#FC3C44', 'music', 'apple.com'))
    map.set('YouTube Premium', new SubscriptionPreset('#FF0000', 'video', 'youtube.com'))
    map.set('iCloud', new SubscriptionPreset('#3693F5', 'storage', 'apple.com'))
    map.set('iCloud+', new SubscriptionPreset('#3693F5', 'storage', 'apple.com'))
    map.set('ChatGPT', new SubscriptionPreset('#10A37F', 'tools', 'openai.com'))
    map.set('GitHub Copilot', new SubscriptionPreset('#000000', 'tools', 'github.com'))
    map.set('Notion', new SubscriptionPreset('#000000', 'tools', 'notion.so'))
    map.set('Figma', new SubscriptionPreset('#F24E1E', 'tools', 'figma.com'))
    map.set('1Password', new SubscriptionPreset('#0572EC', 'tools', '1password.com'))
    map.set('百度网盘', new SubscriptionPreset('#09AAFF', 'storage', 'baidu.com'))
    map.set('阿里云盘', new SubscriptionPreset('#FF6A00', 'storage', 'aliyundrive.com'))
    map.set('腾讯视频', new SubscriptionPreset('#FF6A00', 'video', 'tencent.com'))
    map.set('爱奇艺', new SubscriptionPreset('#00BE06', 'video', 'iqiyi.com'))
    map.set('优酷', new SubscriptionPreset('#1A9CFC', 'video', 'youku.com'))
    map.set('芒果TV', new SubscriptionPreset('#FF8000', 'video', 'mgtv.com'))
    map.set('B站大会员', new SubscriptionPreset('#00A1D6', 'video', 'bilibili.com'))
    map.set('哔哩哔哩', new SubscriptionPreset('#00A1D6', 'video', 'bilibili.com'))
    map.set('QQ音乐', new SubscriptionPreset('#31C27C', 'music', 'qq.com'))
    map.set('网易云音乐', new SubscriptionPreset('#C10D0C', 'music', '163.com'))
    map.set('keep', new SubscriptionPreset('#2DBE2D', 'fitness', 'gotokeep.com'))
    map.set('得到', new SubscriptionPreset('#2B7FFF', 'learning', 'dedao.cn'))
    map.set('极客时间', new SubscriptionPreset('#E5433E', 'learning', 'geekbang.org'))
    map.set('微信读书', new SubscriptionPreset('#07C160', 'learning', 'qq.com'))
    map.set('京东PLUS', new SubscriptionPreset('#E03131', 'lifestyle', 'jd.com'))
    map.set('美团外卖月卡', new SubscriptionPreset('#FFC300', 'lifestyle', 'meituan.com'))
    map.set('山姆会员', new SubscriptionPreset('#0060A9', 'lifestyle', 'samsclub.com'))
    map.set('Costco', new SubscriptionPreset('#E31837', 'lifestyle', 'costco.com'))
    return map
  }

  private static initCategoryConfig(): Map<string, CategoryInfo> {
    const map = new Map<string, CategoryInfo>()
    map.set('video', new CategoryInfo('视频', '#E03131'))
    map.set('music', new CategoryInfo('音乐', '#F59E0B'))
    map.set('tools', new CategoryInfo('工具', '#1677FF'))
    map.set('learning', new CategoryInfo('学习', '#009844'))
    map.set('lifestyle', new CategoryInfo('生活', '#8B5CF6'))
    map.set('storage', new CategoryInfo('云存储', '#06B6D4'))
    map.set('fitness', new CategoryInfo('健身', '#EC4899'))
    map.set('programming', new CategoryInfo('编程', '#3B82F6'))
    map.set('ai', new CategoryInfo('AI', '#10B981'))
    map.set('other', new CategoryInfo('其他', '' + ColorTokens.DEFAULT_FALLBACK))
    return map
  }

  private static initBillingCycleConfig(): Map<string, BillingCycleInfo> {
    const map = new Map<string, BillingCycleInfo>()
    map.set('once', new BillingCycleInfo('一个月', 1))
    map.set('once_weekly', new BillingCycleInfo('一周', 0.25))
    map.set('once_quarterly', new BillingCycleInfo('一季度', 3))
    map.set('once_annually', new BillingCycleInfo('一年', 12))
    map.set('weekly', new BillingCycleInfo('每周', 0.25))
    map.set('biweekly', new BillingCycleInfo('每两周', 0.5))
    map.set('monthly', new BillingCycleInfo('每月', 1))
    map.set('quarterly', new BillingCycleInfo('每季度', 3))
    map.set('semiannually', new BillingCycleInfo('每半年', 6))
    map.set('annually', new BillingCycleInfo('每年', 12))
    return map
  }

  static getPlatformPreset(platformName: string): PlatformPreset {
    if (!platformName || platformName.trim().length === 0) {
      return PlatformService.DEFAULT_PRESET
    }
    const exact = PlatformService.PLATFORM_PRESETS.get(platformName)
    if (exact) {
      return exact
    }
    // 优先最长关键词匹配，避免「中信京东」误命中过短 key
    let bestKey = ''
    const keys = PlatformService.PLATFORM_PRESETS.keys()
    for (const key of keys) {
      if (platformName.includes(key) || key.includes(platformName)) {
        if (key.length > bestKey.length) {
          bestKey = key
        }
      }
    }
    if (bestKey.length > 0) {
      return PlatformService.PLATFORM_PRESETS.get(bestKey) as PlatformPreset
    }
    return PlatformService.DEFAULT_PRESET
  }

  /**
   * 内置信贷平台 logo 的 rawfile 路径（$rawfile:credit_logos/<file>.png）。
   * 空串表示「无内置图，走网络」。Image 组件直接吃 $rawfile: scheme；
   * 选定时由 IconPickerService 复制到 filesDir 变成 file://，走常规上云链路。
   */
  static getLocalCreditLogoUrl(name: string): string {
    if (!name || name.length === 0) {
      return ''
    }
    const exact = PlatformService.CREDIT_LOGO_FILES.get(name)
    if (exact !== undefined) {
      return '$rawfile:credit_logos/' + exact
    }
    // 优先最长 key 命中：避免「花呗微粒贷」错配到 alipay.png
    let bestKey = ''
    const keys = PlatformService.CREDIT_LOGO_FILES.keys()
    for (const key of keys) {
      if (name.includes(key) || key.includes(name)) {
        if (key.length > bestKey.length) {
          bestKey = key
        }
      }
    }
    if (bestKey.length > 0) {
      return '$rawfile:credit_logos/' + (PlatformService.CREDIT_LOGO_FILES.get(bestKey) as string)
    }
    return ''
  }

  /**
   * 根据平台/账户名称解析可加载的 logo URL（优先本地内置图 → Clearbit / Google Favicon）
   * UI 侧需配合 onError 回退到 getBrandVisual 字标
   */
  static getLogoUrlForName(name: string): string {
    if (!name || name.length === 0) {
      return ''
    }
    const local = PlatformService.getLocalCreditLogoUrl(name)
    if (local.length > 0) {
      return local
    }
    const preset = PlatformService.getPlatformPreset(name)
    if (preset.domain && preset.domain.length > 0) {
      return 'https://statics.dnspod.cn/proxy_favicon/_/favicon?domain=' + preset.domain
    }
    const sub = PlatformService.getSubscriptionPreset(name)
    if (sub && sub.domain && sub.domain.length > 0) {
      return 'https://statics.dnspod.cn/proxy_favicon/_/favicon?domain=' + sub.domain
    }
    return ''
  }

  /**
   * 账户/平台品牌头像视觉
   * 有 icon_url 时由 UI 优先加载真实 logo；此处提供品牌色与官方短标识
   */
  static getBrandVisual(name: string): BrandVisual {
    if (!name || name.length === 0) {
      return new BrandVisual('#2F3336', '户')
    }
    const brandMarks: Map<string, string> = new Map()
    brandMarks.set('花呗', '花')
    brandMarks.set('借呗', '借')
    brandMarks.set('京东白条', '京')
    brandMarks.set('京东金条', '京')
    brandMarks.set('京东PLUS', '京')
    brandMarks.set('京东', '京')
    brandMarks.set('美团月付', '美')
    brandMarks.set('美团', '美')
    brandMarks.set('抖音月付', '抖')
    brandMarks.set('抖音', '抖')
    brandMarks.set('微信', '微')
    brandMarks.set('微粒贷', '微')
    brandMarks.set('招商', '招')
    brandMarks.set('建行', '建')
    brandMarks.set('工行', '工')
    brandMarks.set('中信', '中')
    brandMarks.set('交行', '交')
    brandMarks.set('交通', '交')
    brandMarks.set('民生', '民')
    brandMarks.set('光大', '光')
    brandMarks.set('平安', '平')
    brandMarks.set('兴业', '兴')
    brandMarks.set('广发', '广')
    brandMarks.set('华夏', '华')
    brandMarks.set('农行', '农')
    brandMarks.set('农业', '农')
    brandMarks.set('中行', '中')
    brandMarks.set('中国银行', '中')
    brandMarks.set('邮储', '邮')
    brandMarks.set('邮政', '邮')
    brandMarks.set('浦发', '浦')
    brandMarks.set('度小满', '度')
    brandMarks.set('招联', '联')

    let bestKey = ''
    const markKeys = brandMarks.keys()
    for (const key of markKeys) {
      if (name.includes(key) && key.length > bestKey.length) {
        bestKey = key
      }
    }

    const preset = PlatformService.getPlatformPreset(bestKey.length > 0 ? bestKey : name)
    let color = preset.color
    if (!color || color.length === 0) {
      color = '#2F3336'
    }
    let mark = bestKey.length > 0 ? (brandMarks.get(bestKey) as string) : name.substring(0, 1)
    if (!mark || mark.length === 0) {
      mark = '户'
    }
    return new BrandVisual(color, mark, bestKey)
  }

  static getSubscriptionPreset(name: string): SubscriptionPreset {
    if (!name || name.trim().length === 0) {
      return PlatformService.DEFAULT_SUBSCRIPTION_PRESET
    }
    const exact = PlatformService.SUBSCRIPTION_PRESETS.get(name)
    if (exact) {
      return exact
    }
    const keys = PlatformService.SUBSCRIPTION_PRESETS.keys()
    for (const key of keys) {
      if (name.includes(key) || key.includes(name)) {
        return PlatformService.SUBSCRIPTION_PRESETS.get(key) as SubscriptionPreset
      }
    }
    return PlatformService.DEFAULT_SUBSCRIPTION_PRESET
  }

  static getCategoryInfo(category: string): CategoryInfo {
    const info = PlatformService.CATEGORY_CONFIG.get(category)
    return info ? info : PlatformService.CATEGORY_CONFIG.get('other') as CategoryInfo
  }

  static getBillingCycleInfo(cycle: string): BillingCycleInfo {
    const info = PlatformService.BILLING_CYCLE_CONFIG.get(cycle)
    return info ? info : new BillingCycleInfo(cycle, 1)
  }

  /** 选择图标用的预设目录：有域名的订阅/平台，按域名去重 */
  static listLogoCatalog(): LogoCatalogItem[] {
    const seen: Map<string, boolean> = new Map()
    const out: LogoCatalogItem[] = []
    const subKeys = PlatformService.SUBSCRIPTION_PRESETS.keys()
    for (const key of subKeys) {
      const preset = PlatformService.SUBSCRIPTION_PRESETS.get(key)
      if (preset === undefined || preset.domain.length === 0 || seen.get(preset.domain) === true) {
        continue
      }
      seen.set(preset.domain, true)
      const url = PlatformService.getLogoUrlForName(key)
      if (url.length > 0) {
        out.push(new LogoCatalogItem(key, url))
      }
    }
    const platKeys = PlatformService.PLATFORM_PRESETS.keys()
    for (const key of platKeys) {
      const preset = PlatformService.PLATFORM_PRESETS.get(key)
      if (preset === undefined || preset.domain.length === 0 || seen.get(preset.domain) === true) {
        continue
      }
      seen.set(preset.domain, true)
      const url = PlatformService.getLogoUrlForName(key)
      if (url.length > 0) {
        out.push(new LogoCatalogItem(key, url))
      }
    }
    return out
  }

  /** 按品牌名搜索可下载图标；空词不返回，避免摊开整表 */
  static searchLogoCatalog(query: string): LogoCatalogItem[] {
    const q = query.trim().toLowerCase()
    if (q.length === 0) {
      return []
    }
    if (PlatformService.isLatinQuery(q) && q.length < 2) {
      return []
    }
    const out: LogoCatalogItem[] = []
    const seen: Map<string, boolean> = new Map()
    const subKeys = PlatformService.SUBSCRIPTION_PRESETS.keys()
    for (const key of subKeys) {
      PlatformService.pushLogoHit(key, q, seen, out)
    }
    const platKeys = PlatformService.PLATFORM_PRESETS.keys()
    for (const key of platKeys) {
      PlatformService.pushLogoHit(key, q, seen, out)
    }
    out.sort((a: LogoCatalogItem, b: LogoCatalogItem) => {
      const sa = PlatformService.logoFuzzyScore(a.name, q)
      const sb = PlatformService.logoFuzzyScore(b.name, q)
      if (sa !== sb) {
        return sa - sb
      }
      return a.name.length - b.name.length
    })
    if (out.length > 20) {
      return out.slice(0, 20)
    }
    return out
  }

  /** 去空白/符号后做包含、分词、域名模糊匹配（非全名相等） */
  static logoNameMatches(name: string, query: string): boolean {
    return PlatformService.logoFuzzyScore(name, query) < 90
  }

  static normalizeLogoQuery(raw: string): string {
    let s = raw.trim().toLowerCase()
    let out = ''
    for (let i = 0; i < s.length; i++) {
      const ch = s.charAt(i)
      const code = s.charCodeAt(i)
      const az = code >= 97 && code <= 122
      const num = code >= 48 && code <= 57
      if (az || num || ch === '-' || (code > 127)) {
        out += ch
      }
    }
    return out
  }

  private static logoFuzzyScore(name: string, query: string): number {
    const q = PlatformService.normalizeLogoQuery(query)
    if (q.length === 0) {
      return 99
    }
    if (PlatformService.isLatinQuery(q) && q.length === 1) {
      return PlatformService.firstToken(name) === q ? 0 : 99
    }
    const n = PlatformService.normalizeLogoQuery(name)
    if (n === q) {
      return 0
    }
    if (n.startsWith(q)) {
      return 1
    }
    if (n.indexOf(q) >= 0) {
      return 2
    }
    const domain = PlatformService.presetDomain(name)
    if (q.length >= 3 && PlatformService.domainLabelMatches(domain, q)) {
      return 3
    }
    const tokens = query.trim().toLowerCase().split(' ')
    let allTokens = tokens.length > 1
    for (let i = 0; i < tokens.length; i++) {
      const t = PlatformService.normalizeLogoQuery(tokens[i])
      if (t.length === 0 || n.indexOf(t) < 0) {
        allTokens = false
        break
      }
    }
    if (allTokens) {
      return 4
    }
    return 99
  }

  private static firstToken(name: string): string {
    const s = name.trim()
    let raw = ''
    for (let i = 0; i < s.length; i++) {
      const ch = s.charAt(i)
      if (ch === ' ' || ch === '(' || ch === '（' || ch === '-' || ch === '—' || ch === ':' || ch === '：') {
        break
      }
      raw += ch
    }
    return PlatformService.normalizeLogoQuery(raw)
  }

  private static isLatinQuery(q: string): boolean {
    for (let i = 0; i < q.length; i++) {
      if (q.charCodeAt(i) > 127) {
        return false
      }
    }
    return true
  }

  /** 只匹配域名标签本身（apple / iqiyi），避免 t 命中 meituan.com */
  private static domainLabelMatches(domain: string, q: string): boolean {
    if (domain.length === 0 || q.length < 3) {
      return false
    }
    const parts = domain.toLowerCase().split('.')
    for (let i = 0; i < parts.length; i++) {
      const p = parts[i]
      if (p.length < 3 || p === 'com' || p === 'net' || p === 'org' || p === 'www') {
        continue
      }
      if (p === q || p.startsWith(q) || (q.startsWith(p) && p.length >= 4)) {
        return true
      }
    }
    return false
  }

  private static presetDomain(name: string): string {
    const sub = PlatformService.SUBSCRIPTION_PRESETS.get(name)
    if (sub !== undefined && sub.domain.length > 0) {
      return sub.domain
    }
    const plat = PlatformService.PLATFORM_PRESETS.get(name)
    if (plat !== undefined && plat.domain.length > 0) {
      return plat.domain
    }
    return ''
  }

  private static pushLogoHit(key: string, q: string, seen: Map<string, boolean>,
    out: LogoCatalogItem[]): void {
    if (seen.get(key) === true || !PlatformService.logoNameMatches(key, q)) {
      return
    }
    const url = PlatformService.getLogoUrlForName(key)
    if (url.length === 0) {
      return
    }
    seen.set(key, true)
    out.push(new LogoCatalogItem(key, url))
  }

  static getAllBillingCycles(): string[] {
    const keys: string[] = []
    const iter = PlatformService.BILLING_CYCLE_CONFIG.keys()
    for (const key of iter) {
      keys.push(key)
    }
    return keys
  }

  private static initDebtTypeConfig(): Map<string, CategoryInfo> {
    const map = new Map<string, CategoryInfo>()
    map.set('installment', new CategoryInfo('分期', '#1677FF'))
    map.set('credit_card', new CategoryInfo('信用卡', '#E02020'))
    map.set('loan', new CategoryInfo('贷款', '#FF9F00'))
    map.set('other', new CategoryInfo('一次性', '#A1A1AA'))
    return map
  }

  static getDebtTypeInfo(type: string): CategoryInfo {
    const info = PlatformService.DEBT_TYPE_CONFIG.get(type)
    return info ? info : PlatformService.DEBT_TYPE_CONFIG.get('other') as CategoryInfo
  }
}
