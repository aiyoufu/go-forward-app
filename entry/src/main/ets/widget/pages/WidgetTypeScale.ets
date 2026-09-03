/**
 * 卡片专用字号令牌（ArkTS 卡片容器不支持跨 HAR 导入，本地留副本）
 * 数值须与 common/src/main/ets/common/ThemeManager.ets 的 TypeScale 保持同步
 */
export class TypeScale {
  static readonly FONT_MONO: string = 'HarmonyOS Sans Mono'
  /** 筛选面板、图例次要、加载提示 */
  static readonly bodySm: number = 12
  static readonly caption: number = 11
  static readonly captionSm: number = 10
  /** 列表/筛选主操作、次级大标题 */
  static readonly display: number = 20
  static readonly displaySpacing: number = -0.4
  static readonly kicker: number = 9
}
