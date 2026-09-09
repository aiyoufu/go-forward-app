import { ThemeMode, recommendThemeMode } from './ThemeMode'
import { UserSettings } from '../model/UserSettingsModel'
import { AppStorageKeys } from './AppStorageKeys'

/**
 * 「向前」UI 主题（Cursor 化 v9 · 表面抬升 + 小圆角）
 * - 暗色主标杆：近黑微暖 #0C0B09 + 抬升 surface + 更亮字色（可读优先）
 * - 亮色：微暖白 #F7F7F4 + 近黑反转 CTA
 * - 护眼：暖黑 #100F0B + 金反转（同源语言，仅色相偏暖）
 * - 圆角阶梯：sm4 / md4 / lg8 / xl12 / sheet12 / sheetCard8
 * - 弱边框；微弱阴影 rgba(0,0,0,0.04)；浮层可用 elevatedShadow*
 * - 深色 Sheet 底 surface3（sheetBackground）+ 内选项 chip（sheetItemBackground）；阴影 sheetShadowOptions
 * - 主操作反转块：深色用降档暖白 #E4E0D6（v9.4，不做刺眼纯白块）；浅色近黑反转
 * - 深色画布禁裸 #FFFFFF 字色：彩色块上走 onColorBlock()，primary 底走 onPrimary，红底走 dangerForeground()
 * - 小票纸面统一 paperBackground()（深色压暗暖纸 #E3DBC6）
 * - glow 恒透明；语义色 red/amber 保留；其余收敛 foreground
 * - AI 点缀 aiAccent* 仅 AI Live / 配置（面积 < 5%）
 *
 * 操作按钮语义（全应用统一）：
 * - 主操作：primary 反转块底 + onPrimary 字
 * - 危险操作：statusDanger 字或 red 底 + 白字
 * - 取消/次要：text2
 * - Toggle：selectedColor=primary，switchPointColor=onPrimary
 */
export class ThemeColors {
  background: ResourceColor = '#000000'
  surface: ResourceColor = '#16181C'
  surface2: ResourceColor = '#1E2028'
  surface3: ResourceColor = '#2F3336'
  border: ResourceColor = 'rgba(255,255,255,0.12)'
  borderStrong: ResourceColor = 'rgba(255,255,255,0.22)'

  text: ResourceColor = '#E7E9EA'
  text2: ResourceColor = '#8B98A5'
  text3: ResourceColor = '#71767B'

  // 主操作：深色模式用暖白反转块底（v9.4 降一档亮度，避免纯白块刺眼）+ 近黑字；浅色用黑底白字
  primary: ResourceColor = '#E4E0D6'
  primaryLight: ResourceColor = '#E4E0D6'
  onPrimary: ResourceColor = '#0F1419'

  // accent/blue/purple/green：已收敛为 foreground（仅 red/amber 保留语义）
  accent: ResourceColor = '#0A0A0A'
  green: ResourceColor = '#0A0A0A'
  /** 走势"向好/下降"语义绿，三套主题分别取值（见 buildDark/Light/EyeCare） */
  positiveGreen: ResourceColor = '#1F8A65'
  amber: ResourceColor = '#F59E0B'
  red: ResourceColor = '#CF2D56'
  blue: ResourceColor = '#0A0A0A'
  purple: ResourceColor = '#0A0A0A'

  /**
   * AI 能力点缀（仅 AI Live / AI 配置）
   * - 亮：压饱和日落橙；暗：xAI sunset；护眼：品牌金（避免双暖色）
   */
  aiAccent: ResourceColor = '#FF7A17'
  aiAccentSoft: ResourceColor = 'rgba(255,122,23,0.14)'
  aiAccentMuted: ResourceColor = '#FFC285'

  /** 半模态列表按钮字色：按 role 解析 */
  actionLabelColor(role: string): ResourceColor {
    if (role === 'destructive') {
      return this.red
    }
    if (role === 'cancel') {
      return this.text2
    }
    return this.text
  }

  // ── 业务状态色（全应用统一）────────────────────────────────
  // 红：逾期 / 错误 / 危险操作
  // 琥珀：即将到期 ≤3 天 / 中压警告
  // 正常/成功：foreground（不再单独绿色）
  // 暂停/次要：text2；失效/完成/取消：text3

  /** 危险：逾期、错误、删除 */
  statusDanger(): ResourceColor {
    return this.red
  }

  /** 警告：即将到期 ≤3 天、中压 */
  statusWarning(): ResourceColor {
    return this.amber
  }

  /** 正常/成功/活跃（收敛 foreground） */
  statusOk(): ResourceColor {
    return this.text
  }

  /** 成功态专用绿（徽章、勾选等需要明确绿色语义的场景） */
  statusSuccess(): ResourceColor {
    return '#1F8A65'
  }

  /** 暂停、中性次要状态 */
  statusMuted(): ResourceColor {
    return this.text2
  }

  /** 已完成、已取消、关闭 */
  statusInactive(): ResourceColor {
    return this.text3
  }

  /**
   * 按剩余天数取色：
   * - days < 0 → 红（已逾期/已过期）
   * - days ≤ 3 → 琥珀（即将到期）
   * - 其他 → 次要灰
   */
  dueUrgencyColor(days: number): ResourceColor {
    if (days < 0) {
      return this.red
    }
    if (days <= 3) {
      return this.amber
    }
    return this.text2
  }

  /** 危险态浅底（徽章背景） */
  statusDangerBg(): string {
    return 'rgba(207,45,86,0.12)'
  }

  /** 警告态浅底（徽章背景） */
  statusWarningBg(): string {
    return 'rgba(245,158,11,0.12)'
  }

  /** 中性徽章底 */
  statusMutedBg(): ResourceColor {
    return this.chip
  }

  /** 状态 tag 前景色（活跃绿 / 暂停琥珀 / 逾期红 / 失效灰） */
  statusTagFg(role: string): ResourceColor {
    if (this.isDarkCanvas()) {
      if (role === 'ok') {
        return '#4ADE80'
      }
      if (role === 'warn') {
        return '#FBBF24'
      }
      if (role === 'danger') {
        return '#FB7185'
      }
      return '#C9C5BD'
    }
    if (role === 'ok') {
      return '#16A34A'
    }
    if (role === 'warn') {
      return '#D97706'
    }
    if (role === 'danger') {
      return '#CF2D56'
    }
    return '#5C5A52'
  }

  /** 状态 tag 浅底色（活跃绿 / 暂停琥珀 / 逾期红 / 失效灰） */
  statusTagBg(role: string): ResourceColor {
    if (this.isDarkCanvas()) {
      if (role === 'ok') {
        return 'rgba(34,197,94,0.16)'
      }
      if (role === 'warn') {
        return 'rgba(245,158,11,0.16)'
      }
      if (role === 'danger') {
        return 'rgba(207,45,86,0.18)'
      }
      return '#1C1A17'
    }
    if (role === 'ok') {
      return 'rgba(34,197,94,0.12)'
    }
    if (role === 'warn') {
      return 'rgba(245,158,11,0.12)'
    }
    if (role === 'danger') {
      return 'rgba(207,45,86,0.12)'
    }
    return '#EBEAE5'
  }

  ctaBackground(): ResourceColor {
    return this.primary
  }

  ctaForeground(): ResourceColor {
    return this.onPrimary
  }

  controlSelected(): ResourceColor {
    return this.primary
  }

  controlKnob(): ResourceColor {
    return this.onPrimary
  }

  dangerBackground(): ResourceColor {
    return this.red
  }

  dangerForeground(): ResourceColor {
    // 深色画布上红底白字压成暖白，与字色语言一致；浅色保持纯白
    return this.onColorBlock()
  }

  /**
   * 彩色/品牌色块上的前景字（字母标、红底按钮字）：
   * 深色画布用主题暖白，浅色保持纯白。深色禁止裸 #FFFFFF。
   */
  onColorBlock(): ResourceColor {
    return this.isDarkCanvas() ? this.text : '#FFFFFF'
  }

  isDarkCanvas(): boolean {
    const bg = `${this.background}`.toLowerCase()
    // 与 isDarkBg 同步：含 v9.3 近黑微暖 #0C0B09 及抬升 surface 阶梯
    return bg === '#000000' || bg === '#050505' || bg === '#030303' || bg === '#0a0a0a' ||
      bg === '#0c0c0e' || bg === '#08080a' || bg === '#0a0a0c' || bg === '#121214' ||
      bg === '#0d0c08' || bg === '#141416' || bg === '#12110e' || bg === '#14120b' || bg === '#100f0b' ||
      bg === '#1a1916' || bg === '#1b1913' || bg === '#1a1813' || bg === '#0c0b09' ||
      bg === '#161412' || bg === '#1c1a17'
  }

  /**
   * 浮层阴影色（Sheet / 抽屉 / 居中模态；微弱阴影恢复层次）
   */
  elevatedShadowColor(): string {
    return this.isDarkCanvas() ? 'rgba(0,0,0,0.20)' : 'rgba(0,0,0,0.04)'
  }

  /** 浮层阴影模糊半径 vp */
  elevatedShadowRadius(): number {
    return 20
  }

  /** 浮层阴影 Y 偏移 vp */
  elevatedShadowOffsetY(): number {
    return 8
  }

  /**
   * 强浮层阴影色（顶部预览卡「悬浮 hero」专用；比 elevated 更明显的抬升感）
   * 暗色更深以在近黑 canvas 上仍可见浮起，亮色克制饱和只用中性黑
   */
  floatShadowColor(): string {
    return this.isDarkCanvas() ? 'rgba(0,0,0,0.24)' : 'rgba(0,0,0,0.07)'
  }

  /** 强浮层阴影模糊半径 vp */
  floatShadowRadius(): number {
    return 16
  }

  /** 强浮层阴影 Y 偏移 vp */
  floatShadowOffsetY(): number {
    return 6
  }

  /**
   * 页内浮面板阴影一次对象（List 容器 / Tab hero / 设置组 / 骨架组）
   * 用法：`.shadow(this.theme.floatShadowOptions())`，禁止手写三件套以免漂移
   */
  floatShadowOptions(): ShadowOptions {
    return {
      radius: this.floatShadowRadius(),
      color: this.floatShadowColor(),
      offsetX: 0,
      offsetY: this.floatShadowOffsetY()
    }
  }

  /**
   * 物件主舞台 / 首页卡片悬浮阴影（待还总览及同级卡共用；比 float 略厚，仍禁止 glow）
   */
  objectStageShadowOptions(): ShadowOptions {
    return {
      radius: this.isDarkCanvas() ? 22 : 20,
      color: this.isDarkCanvas() ? 'rgba(0,0,0,0.32)' : 'rgba(40,30,20,0.10)',
      offsetX: 0,
      offsetY: this.isDarkCanvas() ? 10 : 8
    }
  }

  /**
   * 订阅小票悬浮阴影：对齐 Tailwind `shadow-xl` 外层
   * `0 20px 25px -5px rgb(0 0 0 / 0.1)`
   * Column.shadow 不接受数组，单层近似（保留外层更可见的扩散与偏移）。
   */
  receiptShadowOptions(): ShadowOptions {
    const color = this.isDarkCanvas() ? 'rgba(0,0,0,0.22)' : 'rgba(0,0,0,0.10)'
    return { radius: 25, color: color, offsetX: 0, offsetY: 20 }
  }

  /**
   * 紧凑弹出菜单阴影（筛选/排序/分类下拉；无全屏压暗时需比 float 更明显托起）
   * 亮色加深扩散；暗色加浓，避免与 surface2 列表融平
   */
  popupShadowColor(): string {
    return this.isDarkCanvas() ? 'rgba(0,0,0,0.55)' : 'rgba(40,30,20,0.18)'
  }

  popupShadowRadius(): number {
    return 28
  }

  popupShadowOffsetY(): number {
    return 12
  }

  /**
   * 弹出菜单阴影一次对象（FilterSortMenuPanel 等）
   * 用法：`.shadow(this.theme.popupShadowOptions())`，禁止手写三件套
   */
  popupShadowOptions(): ShadowOptions {
    return {
      radius: this.popupShadowRadius(),
      color: this.popupShadowColor(),
      offsetX: 0,
      offsetY: this.popupShadowOffsetY()
    }
  }

  /**
   * Sheet / 抽屉 / 模态 elevated 阴影一次对象
   * 用法：`.shadow(this.theme.elevatedShadowOptions())`
   */
  elevatedShadowOptions(): ShadowOptions {
    return {
      radius: this.elevatedShadowRadius(),
      color: this.elevatedShadowColor(),
      offsetX: 0,
      offsetY: this.elevatedShadowOffsetY()
    }
  }

  /** 无阴影（嵌组行 nestInGroup） */
  noneShadowOptions(): ShadowOptions {
    return {
      radius: 0,
      color: 'rgba(0,0,0,0)',
      offsetX: 0,
      offsetY: 0
    }
  }

  /**
   * 条件浮起：enabled=true 用 float；false 用 none（列表行 / 嵌组）
   */
  floatShadowOptionsWhen(enabled: boolean): ShadowOptions {
    return enabled ? this.floatShadowOptions() : this.noneShadowOptions()
  }

  /**
   * 列表 logo 紧阴影：白底 logo 在浅色卡片上边缘不可见，用一圈极淡的环影托出轮廓。
   * 深色下边框已可见，阴影收敛到几乎不可见，避免白底图标在深色 canvas 上发光。
   */
  listLogoShadowOptions(): ShadowOptions {
    return {
      radius: this.isDarkCanvas() ? 1 : 2,
      color: this.isDarkCanvas() ? 'rgba(0,0,0,0.18)' : 'rgba(40,30,20,0.16)',
      offsetX: 0,
      offsetY: 0
    }
  }

  sheetMaskColor(): string {
    // 深色更不透明，托出通知/还款等浮层
    return this.isDarkCanvas() ? 'rgba(0, 0, 0, 0.82)' : 'rgba(0, 0, 0, 0.45)'
  }

  /**
   * AI Live 全屏遮罩压暗（输入/示例态主层次）。
   * 折中：比「太透」略压一层，比「太糊」仍用黑色薄罩而非大半径雾片。
   */
  aiMaskDim(): string {
    return this.isDarkCanvas() ? 'rgba(0, 0, 0, 0.32)' : 'rgba(0, 0, 0, 0.14)'
  }

  /**
   * 输入态极轻 blur 的罩色（叠在 dim 之上，几乎无额外染色）
   */
  aiGlassTint(): string {
    return this.isDarkCanvas() ? 'rgba(0, 0, 0, 0.02)' : 'rgba(255, 255, 255, 0.02)'
  }

  /**
   * 输入态 / scanning 统一用很小半径：只柔边，不糊掉块面轮廓。
   * 实测 18+ 偏糊、0 又太透，取 10。
   */
  aiGlassBlurRadius(): number {
    return 10
  }

  aiGlassBrightness(): number {
    return 1.0
  }

  aiGlassSaturation(): number {
    return 1.0
  }

  /**
   * 半模态面板底：
   * - 深/护眼：surface3，抬离近黑 canvas 与页内 surface2 卡（黑蒙层叠近黑底几乎无差）
   * - 浅：surface2 白底，相对奶油画布可分
   */
  sheetBackground(): ResourceColor {
    return this.isDarkCanvas() ? this.surface3 : this.surface2
  }

  /**
   * 半模态内选项卡 / 操作块底：必须与 sheetBackground 区分
   * - 深/护眼：chip（再抬一级）
   * - 浅：surface3 暖灰
   */
  sheetItemBackground(): ResourceColor {
    return this.isDarkCanvas() ? this.chip : this.surface3
  }

  /**
   * 半模态阴影：近黑画布上 elevated 0.20 黑影不可见，复用 popup 档
   */
  sheetShadowOptions(): ShadowOptions {
    return this.popupShadowOptions()
  }

  /**
   * 表单输入底：略抬于页 canvas，避免「白底白框 / 黑底黑框」
   * - 深：surface2
   * - 浅：chip
   */
  fieldBackground(): ResourceColor {
    return this.isDarkCanvas() ? this.surface2 : this.chip
  }

  /**
   * 表单输入描边：比 border 更清晰，浅色/深色均可辨
   */
  fieldBorder(): ResourceColor {
    return this.isDarkCanvas() ? 'rgba(255,255,255,0.24)' : 'rgba(0,0,0,0.18)'
  }

  fieldBorderWidth(): number {
    return 1
  }

  /**
   * 月结小票纸面（详情弹窗 / AI 解析卡共用）：
   * - 深/护眼：压暗暖纸 #E3DBC6（保留纸感，不做刺眼大亮块）
   * - 浅色：暖米纸 #E8E0CC
   */
  paperBackground(): ResourceColor {
    return this.isDarkCanvas() ? '#E3DBC6' : '#E8E0CC'
  }

  /** 纸卡描边：深色纸用深墨发丝线；浅色用 borderStrong */
  paperBorder(): ResourceColor {
    return this.isDarkCanvas() ? 'rgba(40,30,20,0.12)' : this.borderStrong
  }

  /** AI 扫描高亮底（复用 aiAccentSoft） */
  aiHighlightBg(): string {
    return `${this.aiAccentSoft}`
  }

  /** AI 扫描高亮描边（与当前 aiAccent 同色相） */
  aiHighlightBorder(): string {
    const a = `${this.aiAccent}`.toLowerCase()
    if (a === '#e5b83a') {
      return 'rgba(229,184,58,0.40)'
    }
    if (a === '#f54e00') {
      return 'rgba(245,78,0,0.35)'
    }
    return 'rgba(255,122,23,0.35)'
  }

  /** 半模态外轮廓发丝线（内容根节点可选描边；深色需足够亮才能在近黑底上看见圆角） */
  sheetEdgeColor(): ResourceColor {
    return this.isDarkCanvas() ? 'rgba(255,255,255,0.28)' : this.border
  }

  glow: ResourceColor = 'rgba(255,255,255,0.0)'
  glowCenter: ResourceColor = 'rgba(255,255,255,0.0)'
  glowEdge: ResourceColor = 'rgba(0,0,0,0)'

  borderSoft: ResourceColor = 'rgba(0,0,0,0.055)'
  bar: ResourceColor = '#D8D8D8'
  barSoft: ResourceColor = '#E8E8E8'
  chip: ResourceColor = '#F2F2F2'

  /**
   * 圆角阶梯 v9（冻结；业务禁止裸数字，一律 theme.radius*）
   * - sm：chip / 输入 / 列表内小块
   * - md：独立列表卡
   * - lg：组容器 / 摘要组
   * - xl：少用大抬升块
   * - sheet：半模态外轮廓
   */
  radiusSm: number = 4
  radiusMd: number = 4
  radiusLg: number = 8
  radiusXl: number = 12
  radiusPill: number = 999

  /**
   * 底部半模态外轮廓圆角
   * bindSheet: radius: LengthMetrics.vp(theme.sheetRadius)
   */
  sheetRadius: number = 12
  /** 半模态内选项列表 / 内容卡圆角 */
  sheetCardRadius: number = 8

  /**
   * 间距 4 网格
   * 4 · 8 · 16 · 24 · 32
   */
  spaceXxs: number = 4
  spaceXs: number = 8
  spaceSm: number = 16
  spaceBase: number = 24
  spaceMd: number = 24
  spaceLg: number = 32

  /** 页面内容区水平内边距（v9：10） */
  pageHorizontalPadding: number = 10
}

export class ThemeManager {
  static readonly DARK: ThemeColors = ThemeManager.buildDark()
  static readonly LIGHT: ThemeColors = ThemeManager.buildLight()
  static readonly EYE_CARE: ThemeColors = ThemeManager.buildEyeCare()

  /**
   * 最近一次 currentTheme 计算出的生效主题快照。
   * 供新页首帧同步初始化，避免异步 loadTheme 落定前先用固定色渲染再翻转造成的背景闪烁。
   */
  private static lastEffective: ThemeColors = ThemeManager.copy(ThemeManager.DARK)

  /** 返回最近生效主题的副本，供页面 @State 首帧同步初始化（无闪烁） */
  static snapshot(): ThemeColors {
    return ThemeManager.copy(ThemeManager.lastEffective)
  }

  static getTheme(mode: ThemeMode, systemDark: boolean): ThemeColors {
    if (mode === 'dark') {
      return ThemeManager.copy(ThemeManager.DARK)
    }
    if (mode === 'light') {
      return ThemeManager.copy(ThemeManager.LIGHT)
    }
    return systemDark ? ThemeManager.copy(ThemeManager.DARK) : ThemeManager.copy(ThemeManager.LIGHT)
  }

  static isEffectivelyDark(settings: UserSettings, systemDark: boolean): boolean {
    if (settings.eye_care_enabled) {
      return true
    }
    if (settings.theme_mode === 'dark') {
      return true
    }
    if (settings.theme_mode === 'light') {
      return false
    }
    if (settings.light_sense_enabled) {
      const lux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
      if (lux >= 0) {
        const rec = recommendThemeMode(lux)
        if (rec === 'dark') {
          return true
        }
        if (rec === 'light') {
          return false
        }
      }
    }
    return systemDark
  }

  static currentTheme(settings: UserSettings, systemDark: boolean = false, lux: number = -1): ThemeColors {
    let theme: ThemeColors
    if (settings.eye_care_enabled) {
      theme = ThemeManager.eyeCareTheme(systemDark)
    } else if (settings.theme_mode === 'light' || settings.theme_mode === 'dark') {
      theme = ThemeManager.getTheme(settings.theme_mode, systemDark)
    } else if (settings.light_sense_enabled && lux >= 0) {
      theme = ThemeManager.autoTheme(lux, systemDark)
    } else {
      theme = ThemeManager.getTheme(settings.theme_mode, systemDark)
    }
    ThemeManager.lastEffective = theme
    return theme
  }

  static isSame(a: ThemeColors, b: ThemeColors): boolean {
    return a.background === b.background
      && a.surface === b.surface
      && a.surface2 === b.surface2
      && a.surface3 === b.surface3
      && a.border === b.border
      && a.text === b.text
      && a.text2 === b.text2
      && a.text3 === b.text3
      && a.primary === b.primary
      && a.onPrimary === b.onPrimary
      && a.accent === b.accent
      && a.green === b.green
      && a.positiveGreen === b.positiveGreen
      && a.glow === b.glow
      && a.glowCenter === b.glowCenter
  }

  static autoTheme(lux: number, systemDark: boolean): ThemeColors {
    const mode = recommendThemeMode(lux)
    const theme = ThemeManager.getTheme(mode, systemDark)
    return ThemeManager.applyAmbientGlow(theme, lux)
  }

  static eyeCareTheme(_systemDark: boolean): ThemeColors {
    return ThemeManager.copy(ThemeManager.EYE_CARE)
  }

  static applyAmbientGlow(theme: ThemeColors, lux: number): ThemeColors {
    const merged = ThemeManager.copy(theme)
    const isDark = ThemeManager.isDarkBg(`${theme.background}`)
    if (lux < 10) {
      if (isDark) {
        merged.background = '#030303'
      }
    } else if (lux < 100) {
      if (isDark) {
        merged.background = '#08080A'
      }
    } else if (lux > 1000) {
      if (isDark) {
        // 强光下略抬 canvas，仍保持近黑阶梯
        merged.background = '#12110E'
      }
    }
    merged.glow = 'rgba(0,0,0,0)'
    merged.glowCenter = 'rgba(0,0,0,0)'
    merged.glowEdge = 'rgba(0,0,0,0)'
    return merged
  }

  private static isDarkBg(bg: string): boolean {
    const b = bg.toLowerCase()
    return b === '#000000' || b === '#050505' || b === '#030303' || b === '#0a0a0a' ||
      b === '#0c0c0e' || b === '#08080a' || b === '#0a0a0c' || b === '#121214' ||
      b === '#0d0c08' || b === '#141416' || b === '#12110e' || b === '#14120b' || b === '#100f0b' ||
      b === '#1a1916' || b === '#1b1913' || b === '#1a1813' || b === '#0c0b09' ||
      b === '#161412' || b === '#1c1a17'
  }

  static ambientLabel(lux: number): string {
    if (lux < 0) {
      return '无环境光数据'
    }
    if (lux < 10) {
      return '暗光环境 · 已开启氛围光'
    }
    if (lux < 100) {
      return '弱光环境 · 已柔化显示'
    }
    if (lux > 1000) {
      return '强光环境 · 已提亮显示'
    }
    return '光线适中'
  }

  private static copy(source: ThemeColors): ThemeColors {
    const t = new ThemeColors()
    t.background = source.background
    t.surface = source.surface
    t.surface2 = source.surface2
    t.surface3 = source.surface3
    t.border = source.border
    t.borderStrong = source.borderStrong
    t.text = source.text
    t.text2 = source.text2
    t.text3 = source.text3
    t.primary = source.primary
    t.primaryLight = source.primaryLight
    t.onPrimary = source.onPrimary
    t.accent = source.accent
    t.green = source.green
    t.positiveGreen = source.positiveGreen
    t.amber = source.amber
    t.red = source.red
    t.blue = source.blue
    t.purple = source.purple
    t.aiAccent = source.aiAccent
    t.aiAccentSoft = source.aiAccentSoft
    t.aiAccentMuted = source.aiAccentMuted
    t.glow = source.glow
    t.glowCenter = source.glowCenter
    t.glowEdge = source.glowEdge
    t.borderSoft = source.borderSoft
    t.bar = source.bar
    t.barSoft = source.barSoft
    t.chip = source.chip
    t.radiusSm = source.radiusSm
    t.radiusMd = source.radiusMd
    t.radiusLg = source.radiusLg
    t.radiusXl = source.radiusXl
    t.radiusPill = source.radiusPill
    t.sheetRadius = source.sheetRadius
    t.sheetCardRadius = source.sheetCardRadius
    t.spaceXxs = source.spaceXxs
    t.spaceXs = source.spaceXs
    t.spaceSm = source.spaceSm
    t.spaceBase = source.spaceBase
    t.spaceMd = source.spaceMd
    t.spaceLg = source.spaceLg
    t.pageHorizontalPadding = source.pageHorizontalPadding
    return t
  }

  /**
   * 暗色：近黑微暖 canvas + 更亮字色（对标高对比深色 UI 可读性）
   * canvas #0C0B09 → surface 抬升；次要字色不低于 ~#A39E95
   */
  private static buildDark(): ThemeColors {
    const t = new ThemeColors()
    t.background = '#0C0B09'
    t.surface = '#161412'
    t.surface2 = '#1C1A17'
    t.surface3 = '#2A2720'
    t.border = 'rgba(245,240,230,0.12)'
    t.borderStrong = 'rgba(245,240,230,0.20)'
    t.borderSoft = 'rgba(245,240,230,0.12)'
    t.text = '#F2F1EF'
    t.text2 = '#C9C5BD'
    t.text3 = '#A39E95'
    t.primary = '#E4E0D6'
    t.primaryLight = '#E4E0D6'
    t.onPrimary = '#0C0B09'
    t.accent = '#E4E0D6'
    t.green = '#E4E0D6'
    t.positiveGreen = '#34D399'
    t.amber = '#F59E0B'
    t.red = '#CF2D56'
    t.blue = '#E4E0D6'
    t.purple = '#E4E0D6'
    t.aiAccent = '#F54E00'
    t.aiAccentSoft = 'rgba(245,78,0,0.16)'
    t.aiAccentMuted = '#F5A882'
    t.bar = '#3F3B34'
    t.barSoft = '#2A2720'
    t.chip = '#2E2B24'
    t.glow = 'rgba(0,0,0,0)'
    t.glowCenter = 'rgba(0,0,0,0)'
    t.glowEdge = 'rgba(0,0,0,0)'
    return t
  }

  /**
   * 亮色：Cursor 官网奶油纸（对标 cursor.com 营销页）
   * canvas #F7F7F4 → surface 暖白 → surface2 浅米 → chip 暖灰
   */
  private static buildLight(): ThemeColors {
    const t = new ThemeColors()
    t.background = '#F7F7F4'
    t.surface = '#FFFFFF'
    t.surface2 = '#FFFFFF'
    t.surface3 = '#E0DFD8'
    t.border = 'rgba(40,30,20,0.08)'
    t.borderStrong = 'rgba(40,30,20,0.14)'
    t.borderSoft = 'rgba(40,30,20,0.10)'
    t.text = '#26251E'
    t.text2 = '#5C5A52'
    t.text3 = '#858379'
    t.primary = '#26251E'
    t.primaryLight = '#26251E'
    t.onPrimary = '#F7F7F4'
    t.accent = '#26251E'
    t.green = '#26251E'
    t.positiveGreen = '#1F8A65'
    t.amber = '#F59E0B'
    t.red = '#CF2D56'
    t.blue = '#26251E'
    t.purple = '#26251E'
    t.aiAccent = '#F54E00'
    t.aiAccentSoft = 'rgba(245,78,0,0.12)'
    t.aiAccentMuted = '#B8440A'
    t.bar = '#D6D0C4'
    t.barSoft = '#E5E0D6'
    t.chip = '#E8E4DB'
    t.glow = 'rgba(0,0,0,0)'
    t.glowCenter = 'rgba(0,0,0,0)'
    t.glowEdge = 'rgba(0,0,0,0)'
    return t
  }

  /** 护眼：更暖暗底 + 金反转（与 Cursor 暖色同源） */
  private static buildEyeCare(): ThemeColors {
    const t = new ThemeColors()
    t.background = '#100F0B'
    t.surface = '#1E1B14'
    t.surface2 = '#1E1B14'
    t.surface3 = '#2A261C'
    t.border = 'rgba(240,234,214,0.10)'
    t.borderStrong = 'rgba(240,234,214,0.16)'
    t.borderSoft = 'rgba(240,234,214,0.10)'
    t.text = '#F0EAD6'
    t.text2 = '#B8B094'
    t.text3 = '#8A856E'
    t.primary = '#E5B83A'
    t.primaryLight = '#E5B83A'
    t.onPrimary = '#100F0B'
    t.accent = '#F0EAD6'
    t.green = '#F0EAD6'
    t.positiveGreen = '#1B8A63'
    t.amber = '#E5B83A'
    t.red = '#CF2D56'
    t.blue = '#F0EAD6'
    t.purple = '#F0EAD6'
    t.aiAccent = '#E5B83A'
    t.aiAccentSoft = 'rgba(229,184,58,0.16)'
    t.aiAccentMuted = '#F0EAD6'
    t.bar = '#3D382A'
    t.barSoft = '#2A261E'
    t.chip = '#1E1B14'
    t.glow = 'rgba(0,0,0,0)'
    t.glowCenter = 'rgba(0,0,0,0)'
    t.glowEdge = 'rgba(0,0,0,0)'
    return t
  }
}
