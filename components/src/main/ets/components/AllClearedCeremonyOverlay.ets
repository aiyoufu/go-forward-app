import { ThemeColors, ThemeManager, TypeScale, MotionTokens, AppStorageKeys } from 'common'

/**
 * 全部还清仪式 · 轻舟已过万重山
 *
 * 全屏盖住 HdsTabs。包含：
 * 1. 顶栏：左关闭
 * 2. 主视觉 + 竖排诗句（仪式层）
 * 3. 不自动关闭
 */
@Component
export struct AllClearedCeremonyOverlay {
  @Link @Watch('onShowChange') show: boolean
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop settledCount: number = 0

  @State private rootOpacity: number = 0
  @State private sceneOpacity: number = 0
  @State private sceneScale: number = 1.08
  @State private titleOpacity: number = 0
  @State private metaOpacity: number = 0
  @State private vignetteOpacity: number = 0
  @State private topSafe: number = 36
  @State private bottomSafe: number = 24

  private titleTimer: number = -1
  private metaTimer: number = -1
  private outTimer: number = -1
  private kenTimer: number = -1
  private dismissing: boolean = false
  @StorageLink('appInBackground') @Watch('onBackground')
  appInBackground: boolean = false

  private readonly poemChars: string[] = ['轻', '舟', '已', '过', '万', '重', '山']

  aboutToAppear(): void {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 36
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 24
    if (this.show) {
      this.startCeremony()
    }
  }

  aboutToDisappear(): void {
    this.clearAllTimers()
  }

  private onShowChange(): void {
    if (this.show) {
      this.startCeremony()
    } else {
      this.clearAllTimers()
      this.rootOpacity = 0
      this.sceneOpacity = 0
      this.sceneScale = 1.08
      this.titleOpacity = 0
      this.metaOpacity = 0
      this.vignetteOpacity = 0
      this.dismissing = false
    }
  }

  private onBackground(): void {
    if (this.appInBackground && this.show && !this.dismissing) {
      this.finishDismiss(true)
    }
  }

  private clearAllTimers(): void {
    if (this.titleTimer !== -1) {
      clearTimeout(this.titleTimer)
      this.titleTimer = -1
    }
    if (this.metaTimer !== -1) {
      clearTimeout(this.metaTimer)
      this.metaTimer = -1
    }
    if (this.outTimer !== -1) {
      clearTimeout(this.outTimer)
      this.outTimer = -1
    }
    if (this.kenTimer !== -1) {
      clearTimeout(this.kenTimer)
      this.kenTimer = -1
    }
  }

  private startCeremony(): void {
    this.clearAllTimers()
    this.dismissing = false
    this.rootOpacity = 0
    this.sceneOpacity = 0
    this.sceneScale = 1.08
    this.titleOpacity = 0
    this.metaOpacity = 0
    this.vignetteOpacity = 0

    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 36
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 24

    // 一 · 沉：全屏入
    this.getUIContext().animateTo({
      duration: MotionTokens.ceremonyMaskIn,
      curve: Curve.EaseOut
    }, () => {
      this.rootOpacity = 1
      this.vignetteOpacity = 1
    })

    // 二 · 景 + 文同步：主视觉与左上诗句同一 animateTo，短延迟后快入
    this.kenTimer = setTimeout(() => {
      this.kenTimer = -1
      this.getUIContext().animateTo({
        duration: MotionTokens.ceremonySceneDuration,
        curve: Curve.EaseOut
      }, () => {
        this.sceneOpacity = 1
        this.sceneScale = 1
        this.titleOpacity = 1
        if (this.settledCount > 0) {
          this.metaOpacity = 1
        }
      })
    }, 32)
    // 不自动关闭
  }

  private requestDismiss(): void {
    if (!this.show || this.dismissing) {
      return
    }
    this.finishDismiss(false)
  }

  private finishDismiss(immediate: boolean): void {
    if (this.dismissing && !immediate) {
      return
    }
    this.dismissing = true
    this.clearAllTimers()
    if (immediate) {
      this.rootOpacity = 0
      this.show = false
      AppStorage.setOrCreate(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY, false)
      return
    }
    this.getUIContext().animateTo({
      duration: MotionTokens.ceremonyOut,
      curve: Curve.EaseIn
    }, () => {
      this.rootOpacity = 0
      this.titleOpacity = 0
      this.metaOpacity = 0
      this.sceneOpacity = 0
    })
    this.outTimer = setTimeout(() => {
      this.outTimer = -1
      this.show = false
      AppStorage.setOrCreate(AppStorageKeys.SHOW_ALL_CLEARED_CEREMONY, false)
    }, MotionTokens.ceremonyOut + 20)
  }

  private edgeShade(): string {
    return 'rgba(10,14,12,0.55)'
  }

  private ground(): string {
    return '#0C1210'
  }

  /** 结清元信息（弱化，不作视觉重心） */
  private settleMetaLine(): string {
    if (this.settledCount > 0) {
      return '全部结清 · ' + this.settledCount + ' 笔'
    }
    return '全部结清'
  }

  build() {
    // 层级（自下而上）：静场 → 主视觉(不可点) → 空白关仪式 → 文案(不可点) → 顶栏按钮
    // 注意：主视觉 Image 不可挂 onClick，否则会与顶栏抢触摸；关仪式用独立全屏层。
    Stack({ alignContent: Alignment.Center }) {
      // 背景静场
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.ground())
        .hitTestBehavior(HitTestMode.None)

      // 主视觉（纯展示）
      Image($r('app.media.ceremony_boat_mountains'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Cover)
        .opacity(this.sceneOpacity)
        .scale({ x: this.sceneScale, y: this.sceneScale })
        .hitTestBehavior(HitTestMode.None)

      // 上下渐变阴影
      Column() {
        Column()
          .width('100%')
          .height(140)
          .linearGradient({
            angle: 180,
            colors: [[this.edgeShade(), 0], ['rgba(0,0,0,0)', 1]]
          })
          .opacity(this.vignetteOpacity)
        Blank().layoutWeight(1)
        Column()
          .width('100%')
          .height(160)
          .linearGradient({
            angle: 0,
            colors: [[this.edgeShade(), 0], ['rgba(0,0,0,0)', 1]]
          })
          .opacity(this.vignetteOpacity)
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.None)

      // 空白区域关仪式（在顶栏之下）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.001)')
        .onClick(() => this.requestDismiss())

      // 左上偏下：竖排诗句（与主视觉同步淡入）
      Column() {
        // 顶栏 + 额外下沉，整体更靠下
        Blank().height(Math.max(16, this.topSafe + 8) + 44 + this.theme.spaceLg + this.theme.spaceSm)
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            ForEach(this.poemChars, (char: string, index: number) => {
              Text(char)
                .fontSize(TypeScale.heroTitle)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F5F0E6')
                .textShadow({
                  radius: 12,
                  color: 'rgba(0,0,0,0.65)',
                  offsetX: 0,
                  offsetY: 2
                })
            }, (char: string, index: number) => `poem-${index}-${char}`)
          }

          Column() {
            Column({ space: 2 }) {
              Text('无')
                .fontSize(TypeScale.captionSm)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('债')
                .fontSize(TypeScale.captionSm)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
            }
            .width(24)
            .height(44)
            .backgroundColor('#B82619')
            .borderRadius(this.theme.radiusSm)
            .border({ width: 1, color: '#D94035' })
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .shadow({ radius: 6, color: 'rgba(0,0,0,0.4)', offsetX: 0, offsetY: 2 })
          }
          .margin({ top: 8 })
        }
        .opacity(this.titleOpacity)
        .padding({ left: this.theme.pageHorizontalPadding + this.theme.spaceSm })
        .alignItems(VerticalAlign.Top)

        Blank().layoutWeight(1)
      }
      .width('100%')
      .height('100%')
      .alignItems(HorizontalAlign.Start)
      .hitTestBehavior(HitTestMode.None)

      // 顶栏控制：全高 Column + Start，按钮贴顶；Transparent 空白透传到底层关仪式
      Column() {
        Row() {
          Row() {
            Text('✕')
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Bold)
              .fontColor('#F5F0E6')
          }
          .width(44)
          .height(44)
          .borderRadius(this.theme.radiusPill)
          .backgroundColor('rgba(0,0,0,0.38)')
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
        .justifyContent(FlexAlign.Start)
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Start)
      .hitTestBehavior(HitTestMode.Transparent)
      .zIndex(20)
    }
    .width('100%')
    .height('100%')
    .opacity(this.rootOpacity)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

