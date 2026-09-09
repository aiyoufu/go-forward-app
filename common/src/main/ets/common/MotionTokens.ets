/**
 * 动效令牌 — 对齐官方《动画使用指导》bpta-fair-use-animation
 *
 * 原则摘要：
 * 1. 优先系统 animation / animateTo（感知+运行流畅度）
 * 2. 用图形变换 opacity / translate / scale，少改布局属性
 * 3. 同参数多属性放进同一个 animateTo 闭包
 * 4. 显式初值；禁止「可见时先闪灭再播」
 * 5. 克制频率：列表进入缓现一次，滚动/刷新不重播
 * 6. 点击反馈在 touch-down（官方：100–300ms 空窗需按下即反馈）
 * 7. 一镜到底适合同页/Navigation 展开，不用于 Router 跨页切换
 */
export class MotionTokens {
  /** 按下缩放（卡片 / 主按钮）— 微动效 */
  static readonly pressScale: number = 0.97
  /** 轻控件（chip / 次要钮） */
  static readonly pressScaleLight: number = 0.98
  /** 按下动画时长 ms（按下即反馈） */
  static readonly pressDuration: number = 100
  /** 轻反馈（PIN / 扫描高亮）ms */
  static readonly feedbackDuration: number = 150

  /**
   * 列表逐项缓现（Apple per-row 模型：列表不整体动，行各自入场）
   * - 每项 opacity + translateY（图形变换），按 index 错峰
   * - 位移自上落下（负 Y → 0），波从顶部往下展开；禁止自下抬起
   * - 错峰封顶：长表尾部与第 cap 项同时入场，总时长可控
   * - 进入 Tab 播一次；滚动懒挂载按当前进度取值，刷新不重播
   */
  /** 单项缓现时长 ms */
  static readonly listItemRevealDuration: number = 300
  /** 相邻项错峰 ms */
  static readonly listItemRevealStagger: number = 26
  /** 错峰封顶项数 */
  static readonly listItemRevealStaggerCap: number = 8
  /** 单项自上落下位移幅度 vp（transform；起点为 -offsetY，不改布局） */
  static readonly listItemRevealOffsetY: number = 12
  /** 禁止隐式插值：帧驱动属性立刻跟上，避免过冲回落 */
  static readonly instantDuration: number = 0

  /**
   * 通知抽屉入场（自顶向下）
   */
  static readonly drawerEnterDuration: number = 280
  static readonly drawerEnterOffsetY: number = 16
  /** 顶栏抽屉整板滑入位移 vp（向上藏起） */
  static readonly drawerSlideY: number = 36
  static readonly drawerItemStagger: number = 26

  /**
   * 物件门面入场（空态造景 / 金额主舞台）
   * ~0.3s EaseOut；自当前值起可打断；无弹跳
   */
  static readonly objectRevealDuration: number = 300
  static readonly objectRevealOffsetY: number = 12
  static readonly objectRevealScaleFrom: number = 0.98

  /** 图表柱生长 / 金额滚动（特征微动效，帧驱动） */
  static readonly chartGrowDuration: number = 480
  static readonly countDuration: number = 420
  /** 迷你走势线从左到右展开：放慢让过程可见 */
  static readonly trendRevealDuration: number = 1100

  /** 骨架屏脉动（opacity 0.3↔0.7，Alternate） */
  static readonly skeletonPulseDuration: number = 1200
  /** 骨架条目错峰 delay ms */
  static readonly skeletonStagger: number = 80

  /** 主题跨态 / Sheet / 页转 / 庆祝 / 抖动 */
  static readonly themeCrossfadeDuration: number = 400
  static readonly sheetDuration: number = 250
  static readonly sheetQuickDuration: number = 200
  static readonly pageTransitionDuration: number = 320
  /** 顶栏磨砂材质淡入淡出（滚动过阈值的 chrome 切换） */
  static readonly chromeFadeDuration: number = 200
  /** 页转：新页进入起点右侧位移 vp */
  static readonly pageEnterOffsetX: number = 40
  /** 页转：底页让位视差左移 vp */
  static readonly pageParallaxOffsetX: number = 20
  static readonly celebrationDuration: number = 400
  /** 庆祝三阶段：缩小→弹出→归位（遗留；全清仪式改用 ceremony*） */
  static readonly celebrationSquashDuration: number = 100
  static readonly celebrationPopDuration: number = 200
  static readonly celebrationSettleDuration: number = 150
  static readonly shakeStepDuration: number = 40

  /**
   * 全部还清仪式「轻舟已过万重山」
   * 入场宜快：遮罩入 → 景/文同现（不自动关闭）
   */
  static readonly ceremonyMaskIn: number = 260
  /** 自动关闭总等待（遗留；当前仪式不自动关） */
  static readonly ceremonyHold: number = 5600
  static readonly ceremonyOut: number = 320
  /** 主标题 / 诗句 / 累计 相对仪式开始的 delay（遗留时序） */
  static readonly ceremonyTitleDelay: number = 3600
  static readonly ceremonyPoemDelay: number = 4100
  static readonly ceremonyMetaDelay: number = 4500
  static readonly ceremonyTextFade: number = 320
  /** 主视觉 + 诗句淡入时长 */
  static readonly ceremonySceneDuration: number = 1100

  /** 列表项进入动画时长 */
  static readonly listItemEnterDuration: number = 300
  /** 列表项退出动画时长 */
  static readonly listItemExitDuration: number = 250
  /** 列表项退出左滑位移 vp */
  static readonly listItemExitOffsetX: number = 60

  /**
   * 列表 logo
   * 裁切圆角需 ≥ 图标自带烘焙圆角（约 22%），否则白底会在角部露出（深色模式尤其明显）
   */
  static readonly listLogoSize: number = 36
  static readonly listLogoRadius: number = 8
  /**
   * 列表迷你卡面高度：略低于两行文字块（行内 42），避免顶满
   * 宽 = height × cardFaceRatio
   */
  static readonly listCardHeight: number = 38
  /** 列表迷你卡面圆角 */
  static readonly listCardRadius: number = 4
  /** 表单/选择器大尺寸 logo（54~56px）的裁切圆角 */
  static readonly formLogoRadius: number = 12
  /** ISO/IEC 7810 ID-1 卡面宽高比（85.60×53.98 mm） */
  static readonly cardFaceRatio: number = 1.586
  /**
   * 实体卡圆角。规范 3.18mm / 85.60mm ≈ 3.7% 宽；
   * 选择器缩小后按 6vp，远看仍像一张卡，而不是图标方块。
   */
  static readonly cardFaceRadius: number = 6
  /** 三列搜索卡面相对格子内缩 */
  static readonly cardPickerInset: number = 4
  /** 列表行高（负债/订阅/账户/成就墙 统一） */
  static readonly listRowHeight: number = 74

  /** 通知条目错峰 delay */
  static drawerItemDelay(index: number): number {
    const i = index < 0 ? 0 : index
    const cap = 8
    const capped = i > cap ? cap : i
    return capped * MotionTokens.drawerItemStagger
  }

  /** 列表项缓现错峰 delay（封顶，长表不无限拖长） */
  static listItemRevealDelay(index: number): number {
    const i = index < 0 ? 0 : index
    const capped = i > MotionTokens.listItemRevealStaggerCap ? MotionTokens.listItemRevealStaggerCap : i
    return capped * MotionTokens.listItemRevealStagger
  }

  /** 列表逐项缓现总时长（封顶 delay + 单项时长） */
  static listItemRevealTotal(): number {
    return MotionTokens.listItemRevealStaggerCap * MotionTokens.listItemRevealStagger +
      MotionTokens.listItemRevealDuration
  }

  /** 柱图错峰：第 index 根柱在全局 t∈[0,1] 下的生长比例 */
  static barStaggerProgress(t: number, index: number, count: number): number {
    const n = count > 0 ? count : 1
    const slot = 0.55 / n
    const start = index * slot
    if (t <= start) {
      return 0
    }
    const span = 1 - start
    if (span <= 0.001) {
      return 1
    }
    const p = (t - start) / span
    return p > 1 ? 1 : (p < 0 ? 0 : p)
  }
}
