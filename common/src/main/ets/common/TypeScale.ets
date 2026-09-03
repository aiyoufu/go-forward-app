/**
 * 字号令牌（移动端等比缩放，对应设计文档桌面值的适配版）
 * - mono 等宽字体仅作编号/kicker/数字点缀（约 30%），主信息中文优先
 * - 字重组件内用 FontWeight 枚举（Bold/Medium/Regular）
 */
export class TypeScale {
  static readonly FONT_MONO: string = 'HarmonyOS Sans Mono'
  static readonly heroTitle: number = 28
  /** 大标题收紧（约 −0.03em @ 28） */
  static readonly heroTitleSpacing: number = -0.8
  static readonly heroNumber: number = 36
  /** 首页金额主舞台（表盘感，略大于列表语境 heroNumber） */
  static readonly heroNumberDial: number = 40
  /** 主金额 mono 收紧 */
  static readonly heroNumberSpacing: number = -1.2
  static readonly heroNumberSymbol: number = 16
  static readonly sectionNumber: number = 22
  static readonly sectionNumberSpacing: number = -0.5
  /** 列表/筛选主操作、次级大标题 */
  static readonly display: number = 20
  static readonly displaySpacing: number = -0.4
  /** 账户额度、摘要指标 */
  static readonly metric: number = 18
  static readonly metricSpacing: number = -0.3
  /** 列表主行名称/金额 */
  static readonly listPrimary: number = 16
  static readonly listNumberSpacing: number = -0.2
  /** 负债平台名等略小于 listPrimary */
  static readonly listPrimarySm: number = 15
  /** 搜索框、次级按钮 */
  static readonly control: number = 14
  static readonly sectionTitle: number = 13
  static readonly body: number = 13
  static readonly bodyNav: number = 12.5
  /** 筛选面板、图例次要、加载提示 */
  static readonly bodySm: number = 12
  static readonly caption: number = 11
  static readonly captionSm: number = 10
  static readonly kicker: number = 9
  static readonly kickerSpacing: number = 1.2
  /** 空状态水印（发丝色填充 + 字距；Text 无 stroke API 时的兼容方案） */
  static readonly watermark: number = 56
  static readonly watermarkSpacing: number = 3
  /** 空状态虚线框内 + */
  static readonly emptyPlus: number = 20
}
