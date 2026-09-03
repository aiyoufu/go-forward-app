import {
  hdsMaterial,
  SystemMaterialParams
} from '@kit.UIDesignKit'

/**
 * 列表 / 二级页标题栏「沉浸光感」统一材质
 *
 * 文档：https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-spatiality-immersive
 * 章节：列表标题栏适配光感
 *
 * 标准写法（各二级页统一）：
 * ```
 * HdsNavigation() { ...内容... }
 *   .titleBar({
 *     // avoidLayoutSafeArea：全屏窗口下标题内容主动避让状态栏（否则会与时间重叠）
 *     avoidLayoutSafeArea: true,
 *     enableComponentSafeArea: true,
 *     style: {
 *       scrollEffectOpts: {
 *         enableScrollEffect: true,
 *         scrollEffectType: ScrollEffectType.GRADIENT_BLUR
 *       },
 *       systemMaterialEffect: ImmersiveTitleBar.material()
 *     },
 *     content: {
 *       title: { mainTitle: '页面标题' },
 *       backIcon: { label: '返回', action: () => this.goBack() }
 *     }
 *   })
 *   .mode(NavigationMode.Stack) // 宽屏/折叠屏必须 Stack，否则 Auto→Split 内容半屏
 *   .titleMode(HdsNavigationTitleMode.MINI)
 *   .hideBackButton(false)
 *   .bindToScrollable([this.pageScroller])
 * ```
 *
 * 禁止：手写 opaque 顶栏 / 纯色圆形返回键替代官方材质返回按钮。
 */
export class ImmersiveTitleBar {
  /**
   * 列表标题栏光感（官方 titleBar.systemMaterialEffect）
   * ADAPTIVE + ADAPTIVE：跟随环境光，可读性稳定
   */
  static material(): SystemMaterialParams {
    const params: SystemMaterialParams = {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
    return params
  }

  /**
   * 底部悬浮页签 + MiniBar（官方 AdaptiveTabView 原样）
   * IMMERSIVE + ADAPTIVE
   *
   * 注意：不要用 EXQUISITE——材质过透，图表/文字会透出并产生重影。
   */
  static floatingBarMaterial(): SystemMaterialParams {
    const params: SystemMaterialParams = {
      materialType: hdsMaterial.MaterialType.IMMERSIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
    return params
  }
}
