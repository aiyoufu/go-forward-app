import { ThemeColors, ThemeManager, TypeScale, MotionTokens, AppStorageKeys } from 'common'
import { Constants } from 'common'
import { PreferencesService } from 'service'

/**
 * MiniBar 长短按说明 · 首次进入主页仅展示一次
 *
 * 方案 A（无挖孔）：
 * - 全屏半透明遮罩（不裁剪孔洞）
 * - 分步：① 点按 AI 录入 → ② 长按展开新增
 * - 右下角目标标记指向真实 MiniBar 位置
 * - 卡片内手势演示动效（涟漪 / 长按进度环）
 * - 关闭后写入 PREF_MINI_BAR_GUIDE_SHOWN
 */
@Component
export struct MiniBarGuideOverlay {
  @Link @Watch('onShowChange') show: boolean
  @Prop theme: ThemeColors = ThemeManager.DARK

  /** 0 = 点按，1 = 长按 */
  @State private step: number = 0
  @State private rootOpacity: number = 0
  @State private contentOpacity: number = 0
  @State private contentTransY: number = 24
  @State private bottomSafe: number = 0
  @State private topSafe: number = 0

  // —— 演示动效状态 ——
  /** 点按：按钮按下缩放 */
  @State private demoPressScale: number = 1
  /** 点按：涟漪半径（0→1） */
  @State private demoRipple: number = 0
  @State private demoRippleOpacity: number = 0
  /** 长按：进度 0→1 */
  @State private demoHold: number = 0
  /** 长按完成后展开三选项 */
  @State private demoExpanded: boolean = false
  /** 目标环呼吸 */
  @State private targetPulse: number = 1
  @State private targetPulseOpacity: number = 0.45

  private enterTimer: number = -1
  private outTimer: number = -1
  private demoTimer: number = -1
  private bounceTimer: number = -1
  private dismissing: boolean = false

  /** 与 MainPage.miniBarBuilder 折叠态一致（官方定宽 56） */
  private readonly miniBarSize: number = 56
  /** 与 MainPage.getBarBottomMargin 一致（28vp，HdsTabs 已避让安全区） */
  private readonly miniBarBottomOffset: number = 28
  /**
   * 与 AdaptiveTabView 悬浮栏在手机端的左右外边距一致（16vp）
   * 真实 MiniBar 折叠态贴悬浮栏最右侧 = 距屏幕右侧 16vp
   * targetMarker 外层 76vp 比 56vp 实心圆大 20vp（左右各留 10vp 呼吸空间）
   * 因此容器 padding.right = 16 - 10 = 6vp，使 56 实心圆右边缘距屏幕右侧精准为 16vp
   */
  private readonly miniBarRightOffset: number = 6
  /**
   * 结果态停留（非运动时长）
   * - 点按：手势反馈结束后，保持结果态再重播
   * - 长按：菜单完全展开后，静态展示再收起
   */
  private readonly demoTapDwellMs: number = 3200
  /** 长按：展开菜单静态停留（看清「新增负债/订阅/账户」） */
  private readonly demoHoldExpandedDwellMs: number = 5600
  /** 收起/复位后，再开下一轮前的间隔 */
  private readonly demoLoopGapMs: number = 900

  aboutToAppear(): void {
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 0
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 36
    if (this.show) {
      this.startGuide()
    }
  }

  aboutToDisappear(): void {
    this.clearTimers()
  }

  private onShowChange(): void {
    if (this.show) {
      this.startGuide()
    } else {
      if (this.rootOpacity > 0 || this.dismissing) {
        this.persistShownFlag()
      }
      this.resetStates()
    }
  }

  private clearTimers(): void {
    if (this.enterTimer !== -1) {
      clearTimeout(this.enterTimer)
      this.enterTimer = -1
    }
    if (this.outTimer !== -1) {
      clearTimeout(this.outTimer)
      this.outTimer = -1
    }
    if (this.demoTimer !== -1) {
      clearTimeout(this.demoTimer)
      this.demoTimer = -1
    }
    if (this.bounceTimer !== -1) {
      clearTimeout(this.bounceTimer)
      this.bounceTimer = -1
    }
  }

  private resetStates(): void {
    this.step = 0
    this.rootOpacity = 0
    this.contentOpacity = 0
    this.contentTransY = 24
    this.demoPressScale = 1
    this.demoRipple = 0
    this.demoRippleOpacity = 0
    this.demoHold = 0
    this.demoExpanded = false
    this.targetPulse = 1
    this.targetPulseOpacity = 0.45
    this.dismissing = false
  }

  private startGuide(): void {
    this.clearTimers()
    this.resetStates()

    this.getUIContext().animateTo({
      duration: MotionTokens.sheetDuration,
      curve: Curve.EaseOut
    }, () => {
      this.rootOpacity = 1
    })

    this.enterTimer = setTimeout(() => {
      this.enterTimer = -1
      this.getUIContext().animateTo({
        duration: MotionTokens.celebrationDuration,
        curve: Curve.EaseOut
      }, () => {
        this.contentOpacity = 1
        this.contentTransY = 0
      })
      this.loopDemo()
      this.loopChromeAnim()
    }, 80)
  }

  /** 目标环呼吸（循环） */
  private loopChromeAnim(): void {
    if (!this.show || this.dismissing) {
      return
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.skeletonPulseDuration,
      curve: Curve.EaseInOut
    }, () => {
      this.targetPulse = this.targetPulse > 1.05 ? 1 : 1.12
      this.targetPulseOpacity = this.targetPulseOpacity > 0.4 ? 0.18 : 0.5
    })
    this.bounceTimer = setTimeout(() => {
      this.bounceTimer = -1
      this.loopChromeAnim()
    }, MotionTokens.skeletonPulseDuration)
  }

  /** 按当前步骤循环手势演示 */
  private loopDemo(): void {
    if (!this.show || this.dismissing) {
      return
    }
    if (this.step === 0) {
      this.playTapDemo()
    } else {
      this.playHoldDemo()
    }
  }

  /** 点按演示：按下 → 涟漪 →【结果态停留】→ 间隔 → 再循环 */
  private playTapDemo(): void {
    this.demoExpanded = false
    this.demoHold = 0
    this.demoRipple = 0
    this.demoRippleOpacity = 0
    this.demoPressScale = 1

    // 按下
    this.getUIContext().animateTo({
      duration: MotionTokens.pressDuration,
      curve: Curve.EaseOut
    }, () => {
      this.demoPressScale = MotionTokens.pressScale
    })

    this.demoTimer = setTimeout(() => {
      this.demoTimer = -1
      if (this.step !== 0 || !this.show || this.dismissing) {
        return
      }
      // 涟漪初值写在两组 animateTo 之前，避免「animateTo 之间更新状态」告警；
      // 两组动画仍并发：松手缩放 + 涟漪扩散/淡出
      this.demoRippleOpacity = 0.55
      this.getUIContext().animateTo({
        duration: MotionTokens.feedbackDuration,
        curve: Curve.EaseOut
      }, () => {
        this.demoPressScale = 1
      })
      this.getUIContext().animateTo({
        duration: MotionTokens.celebrationDuration,
        curve: Curve.EaseOut
      }, () => {
        this.demoRipple = 1
        this.demoRippleOpacity = 0
      })

      // 运动结束后：静态结果态停留，再清涟漪并间隔重播
      this.demoTimer = setTimeout(() => {
        this.demoTimer = -1
        this.demoRipple = 0
        this.demoTimer = setTimeout(() => {
          this.demoTimer = -1
          if (this.step === 0 && this.show && !this.dismissing) {
            this.loopDemo()
          }
        }, this.demoLoopGapMs)
      }, MotionTokens.celebrationDuration + this.demoTapDwellMs)
    }, MotionTokens.feedbackDuration + 80)
  }

  /**
   * 长按演示：进度环 → 展开菜单 →【菜单静态停留】→ 收起 → 间隔再播
   * 停留只算展开完成后的静态展示，不含进度/展开运动时间
   */
  private playHoldDemo(): void {
    this.demoRipple = 0
    this.demoRippleOpacity = 0
    this.demoPressScale = 1
    this.demoHold = 0
    this.demoExpanded = false

    this.getUIContext().animateTo({
      duration: MotionTokens.pressDuration,
      curve: Curve.EaseOut
    }, () => {
      this.demoPressScale = MotionTokens.pressScaleLight
    })

    // 进度环：沿用 chartGrow，不拉长运动
    this.getUIContext().animateTo({
      duration: MotionTokens.chartGrowDuration,
      curve: Curve.Linear
    }, () => {
      this.demoHold = 1
    })

    this.demoTimer = setTimeout(() => {
      this.demoTimer = -1
      if (this.step !== 1 || !this.show || this.dismissing) {
        return
      }
      // 展开菜单
      this.getUIContext().animateTo({
        duration: MotionTokens.sheetDuration,
        curve: Curve.EaseOut
      }, () => {
        this.demoExpanded = true
        this.demoPressScale = 1
      })

      // 等展开动画结束后，再开始「菜单静态停留」
      this.demoTimer = setTimeout(() => {
        this.demoTimer = -1
        if (this.step !== 1 || !this.show || this.dismissing) {
          return
        }
        this.demoTimer = setTimeout(() => {
          this.demoTimer = -1
          if (this.step !== 1 || !this.show || this.dismissing) {
            return
          }
          // 收起菜单
          this.getUIContext().animateTo({
            duration: MotionTokens.sheetQuickDuration,
            curve: Curve.EaseIn
          }, () => {
            this.demoExpanded = false
            this.demoHold = 0
          })
          this.demoTimer = setTimeout(() => {
            this.demoTimer = -1
            if (this.step === 1 && this.show && !this.dismissing) {
              this.loopDemo()
            }
          }, MotionTokens.sheetQuickDuration + this.demoLoopGapMs)
        }, this.demoHoldExpandedDwellMs)
      }, MotionTokens.sheetDuration)
    }, MotionTokens.chartGrowDuration + 40)
  }

  private goNext(): void {
    if (this.step === 0) {
      // 切到第二步，重启动效
      if (this.demoTimer !== -1) {
        clearTimeout(this.demoTimer)
        this.demoTimer = -1
      }
      this.step = 1
      this.demoPressScale = 1
      this.demoRipple = 0
      this.demoRippleOpacity = 0
      this.demoHold = 0
      this.demoExpanded = false
      this.loopDemo()
      return
    }
    this.requestDismiss()
  }

  private requestDismiss(): void {
    if (!this.show || this.dismissing) {
      return
    }
    this.dismissing = true
    this.clearTimers()
    this.getUIContext().animateTo({
      duration: MotionTokens.sheetQuickDuration,
      curve: Curve.EaseIn
    }, () => {
      this.rootOpacity = 0
      this.contentOpacity = 0
      this.contentTransY = 12
    })
    this.outTimer = setTimeout(() => {
      this.outTimer = -1
      this.show = false
    }, MotionTokens.sheetQuickDuration + 20)
  }

  private async persistShownFlag(): Promise<void> {
    try {
      await PreferencesService.putBool(Constants.PREF_MINI_BAR_GUIDE_SHOWN, true)
    } catch (_e) {
    }
  }

  private maskColor(): string {
    return this.theme.isDarkCanvas() ? 'rgba(0,0,0,0.55)' : 'rgba(15,20,25,0.42)'
  }

  private chipBg(): string {
    return this.theme.isDarkCanvas() ? 'rgba(255,255,255,0.10)' : 'rgba(38,37,30,0.08)'
  }

  private stepChipBg(): string {
    if (this.step === 0) {
      // AI 点缀：仅点按步
      return this.theme.isDarkCanvas() ? 'rgba(245,78,0,0.18)' : 'rgba(245,78,0,0.12)'
    }
    return this.theme.isDarkCanvas() ? 'rgba(255,255,255,0.12)' : 'rgba(38,37,30,0.08)'
  }

  private stepChipColor(): ResourceColor {
    if (this.step === 0) {
      return this.theme.aiAccent
    }
    return this.theme.text
  }

  private stepLabel(): string {
    return this.step === 0 ? '点按' : '长按'
  }

  private stepTitle(): string {
    return this.step === 0 ? 'AI 智能录入' : '展开新增菜单'
  }

  private stepSubtitle(): string {
    return this.step === 0 ? '用一句话描述单据' : '负债 · 订阅 · 账户'
  }

  private stepHint(): string {
    return this.step === 0 ? '点按右下角按钮开始录入' : '长按展开手动新增菜单'
  }

  private primaryLabel(): string {
    return this.step === 0 ? '下一步' : '完成'
  }

  private progressIndex(): string {
    return `${this.step + 1} / 2`
  }

  /** 卡片内：点按涟漪演示（真实 MiniBar 尺寸 56x56） */
  @Builder
  private tapDemoBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      // 涟漪
      Column()
        .width(32 + this.demoRipple * 36)
        .height(32 + this.demoRipple * 36)
        .borderRadius(this.theme.radiusPill)
        .border({
          width: 1.5,
          color: this.theme.aiAccent
        })
        .opacity(this.demoRippleOpacity)

      // 假按钮（与真实 MiniBar 56x56 对齐）
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_ai_spark'))
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
      }
      .width(56)
      .height(56)
      .borderRadius(this.theme.radiusPill)
      .backgroundColor(this.theme.surface2)
      .border({ width: 1, color: this.theme.borderSoft })
      .shadow(this.theme.floatShadowOptions())
      .scale({ x: this.demoPressScale, y: this.demoPressScale })
    }
    .width('100%')
    .height(76)
  }

  /**
   * 卡片内长按演示（真实 MiniBar 尺寸 56x56 / 展开高 56）
   * 折叠：真实 MiniBar 折叠态（56x56）
   * 展开：左侧菜单圆（56x56）+ 右侧胶囊（高 56，仅含「新增负债 / 新增订阅 / 新增账户」）
   */
  @Builder
  private holdDemoBuilder() {
    Row({ space: 8 }) {
      if (this.demoExpanded) {
        // 左侧：菜单圆（对应底栏主菜单圆）
        Stack({ alignContent: Alignment.Center }) {
          Image($r('app.media.ic_tab_home'))
            .width(22)
            .height(22)
            .fillColor(this.theme.text)
            .objectFit(ImageFit.Contain)
        }
        .width(56)
        .height(56)
        .borderRadius(this.theme.radiusPill)
        .backgroundColor(this.theme.surface2)
        .border({ width: 1, color: this.theme.borderSoft })
        .shadow(this.theme.floatShadowOptions())
        .flexShrink(0)
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.scale({ x: 0.85, y: 0.85 }))
            .animation({
              duration: MotionTokens.sheetDuration,
              curve: Curve.EaseOut
            })
        )

        // 右侧：展开菜单胶囊（高度 56，与真实 MiniBar 一致）
        Row({ space: 0 }) {
          this.pillItemBuilder($r('app.media.ic_tab_debt'), '新增负债')
          this.pillItemBuilder($r('app.media.ic_tab_subscription'), '新增订阅')
          this.pillItemBuilder($r('app.media.ic_tab_account'), '新增账户')
        }
        .height(56)
        .layoutWeight(1)
        .padding({ left: 6, right: 6 })
        .justifyContent(FlexAlign.SpaceEvenly)
        .alignItems(VerticalAlign.Center)
        .backgroundColor(this.theme.surface2)
        .borderRadius(this.theme.radiusPill)
        .border({ width: 1, color: this.theme.borderSoft })
        .shadow(this.theme.floatShadowOptions())
        .clip(true)
        .transition(
          TransitionEffect.OPACITY
            .combine(TransitionEffect.translate({ x: 16 }))
            .combine(TransitionEffect.scale({ x: 0.9, y: 0.9 }))
            .animation({
              duration: MotionTokens.sheetDuration,
              curve: Curve.EaseOut
            })
        )
      } else {
        // 折叠：星芒圆 56x56 + 长按进度环
        Stack({ alignContent: Alignment.Center }) {
          Progress({
            value: this.demoHold * 100,
            total: 100,
            type: ProgressType.Ring
          })
            .width(50)
            .height(50)
            .color(this.theme.text)
            .backgroundColor(this.theme.border)
            .style({ strokeWidth: 2.5 })

          Image($r('app.media.ic_ai_spark'))
            .width(30)
            .height(30)
            .objectFit(ImageFit.Contain)
        }
        .width(56)
        .height(56)
        .borderRadius(this.theme.radiusPill)
        .backgroundColor(this.theme.surface2)
        .border({ width: 1, color: this.theme.borderSoft })
        .shadow(this.theme.floatShadowOptions())
        .scale({ x: this.demoPressScale, y: this.demoPressScale })
      }
    }
    .width('100%')
    .height(76)
    .justifyContent(this.demoExpanded ? FlexAlign.Start : FlexAlign.End)
    .alignItems(VerticalAlign.Center)
    .padding({ left: 8, right: 8 })
  }

  /** 右侧展开胶囊内单项（图标 + 完整文案，对齐 MainPage） */
  @Builder
  private pillItemBuilder(icon: Resource, label: string) {
    Column({ space: 2 }) {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor(this.theme.text)
      Text(label)
        .fontSize(TypeScale.kicker)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text)
        .maxLines(1)
    }
    .layoutWeight(1)
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  private cardBuilder() {
    Column({ space: this.theme.spaceSm }) {
      // 步骤进度
      Text(this.progressIndex())
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text3)
        .width('100%')

      // 标题行
      Row({ space: 8 }) {
        Text(this.stepLabel())
          .fontSize(TypeScale.kicker)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.stepChipColor())
          .letterSpacing(TypeScale.kickerSpacing)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.stepChipBg())
          .borderRadius(this.theme.radiusSm)

        Text(this.stepTitle())
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .maxLines(1)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Text(this.stepSubtitle())
        .fontSize(TypeScale.body)
        .fontColor(this.theme.text2)
        .width('100%')

      // 演示区
      Column() {
        if (this.step === 0) {
          this.tapDemoBuilder()
        } else {
          this.holdDemoBuilder()
        }
      }
      .width('100%')
      .padding({ top: 4, bottom: 4 })
      .backgroundColor(this.theme.sheetItemBackground())
      .borderRadius(this.theme.radiusLg)
      .border({ width: 1, color: this.theme.borderStrong })
      .clip(true)

      Text(this.stepHint())
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text3)
        .width('100%')

      // 主操作
      Text(this.primaryLabel())
        .fontSize(TypeScale.listPrimarySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.ctaForeground())
        .width('100%')
        .height(44)
        .textAlign(TextAlign.Center)
        .backgroundColor(this.theme.ctaBackground())
        .borderRadius(this.theme.radiusSm)
        .onClick(() => this.goNext())
    }
    .width(268)
    .padding(this.theme.spaceSm)
    .backgroundColor(this.theme.sheetBackground())
    .borderRadius(this.theme.radiusXl)
    .border({ width: 1, color: this.theme.sheetEdgeColor() })
    .shadow(this.theme.sheetShadowOptions())
  }

  /**
   * 右下角目标标记：仅定位真实 MiniBar（呼吸环 + 星芒）
   * 展开/长按演示只在弹窗卡片内播，底部不重复
   */
  @Builder
  private targetMarkerBuilder() {
    Stack({ alignContent: Alignment.Center }) {
      // 呼吸环
      Column()
        .width(this.miniBarSize + 16)
        .height(this.miniBarSize + 16)
        .borderRadius(this.theme.radiusPill)
        .border({
          width: 2,
          color: this.step === 0 ? this.theme.aiAccent : this.theme.text
        })
        .opacity(this.targetPulseOpacity)
        .scale({ x: this.targetPulse, y: this.targetPulse })

      // 实心标记（提示「就是这里」，与真实 MiniBar 56x56 对齐）
      Stack({ alignContent: Alignment.Center }) {
        Image($r('app.media.ic_ai_spark'))
          .width(32)
          .height(32)
          .objectFit(ImageFit.Contain)
      }
      .width(this.miniBarSize)
      .height(this.miniBarSize)
      .borderRadius(this.theme.radiusPill)
      .backgroundColor(this.theme.surface2)
      .border({ width: 1, color: this.theme.borderSoft })
      .shadow(this.theme.floatShadowOptions())
    }
    .width(this.miniBarSize + 20)
    .height(this.miniBarSize + 20)
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 全屏遮罩（无挖孔）：点击关闭
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.maskColor())
        .onClick(() => this.requestDismiss())

      // 关闭（顶栏）
      Row() {
        Blank().layoutWeight(1)
        Row() {
          Text('✕')
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
        }
        .width(40)
        .height(40)
        .borderRadius(this.theme.radiusPill)
        .backgroundColor(this.chipBg())
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .onClick(() => this.requestDismiss())
      }
      .width('100%')
      .padding({
        left: this.theme.pageHorizontalPadding,
        right: this.theme.pageHorizontalPadding,
        top: Math.max(16, this.topSafe + 8)
      })
      .opacity(this.rootOpacity)

      /**
       * 右下锚点：说明卡 + 目标标记（已移除中间箭头）
       * 用全屏 Column + Blank 顶开，保证贴底
       * 底边 = 28，右边 = 16，与 MainPage 悬浮底栏折叠 MiniBar 像素级重合
       * Blank 不参与命中，空白区点穿到遮罩关闭；卡片区自行吞点击
       */
      Column() {
        Blank()
          .layoutWeight(1)
          .hitTestBehavior(HitTestMode.None)

        Column({ space: this.theme.spaceXs }) {
          Column() {
            this.cardBuilder()
          }
          .margin({ right: 10 })

          this.targetMarkerBuilder()
        }
        .width(268 + 10)
        .alignItems(HorizontalAlign.End)
        .opacity(this.contentOpacity)
        .translate({ y: this.contentTransY })
        // 吞掉点击，避免点卡片时误关遮罩
        .onClick(() => {
        })
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.End)
      .padding({
        right: this.miniBarRightOffset,
        // 环比按钮大 10vp，使 56 实心圆与真实 MiniBar（getBarBottomMargin=28）像素级重合
        bottom: this.miniBarBottomOffset - 10
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .opacity(this.rootOpacity)
    .clip(false)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}
