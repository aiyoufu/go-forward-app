import { ThemeColors, TypeScale, MotionTokens, AppToast, ErrorMessages, ArrayDataSource } from 'common'
import { IconPickerService, LogoCatalogItem, PlatformService } from 'service'
import { common } from '@kit.AbilityKit'
import { image } from '@kit.ImageKit'
import { SheetHeader, sheetBottomInset } from './SheetDialog'
import { LogoImage } from './LogoImage'

/**
 * 图标选择底部面板
 * - 按名称查图标：catalog='app' 查应用图标（iTunes + 本地预设），catalog='card' 查内置信贷平台图标
 * - 搜索中 / 无结果都有明确状态反馈，不再"静默空白"
 * - 点选记入历史清单；最近使用（app 图标 / 卡面）免搜索直接复用
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct IconPickerSheet {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop historyIcons: string[] = []
  /** 数据源：'app' 应用图标（负债/订阅）；'card' 内置信贷平台图标（信用账户） */
  @Prop catalog: string = 'app'
  onPick: (path: string) => void = () => {}
  onAlbum: () => void = () => {}
  onCancel: () => void = () => {}
  @State private query: string = ''
  @State private hits: LogoCatalogItem[] = []
  @State private picking: boolean = false
  /** 请求在途（含 300ms 防抖窗口） */
  @State private searching: boolean = false
  /** 当前关键词已出结果（区分"没搜到"和"还没搜"） */
  @State private searched: boolean = false
  private hitSource: ArrayDataSource = new ArrayDataSource()
  private searchTimer: number = -1
  private searchSeq: number = 0

  private trimmedQuery(): string {
    return this.query.trim()
  }

  private onQueryChange(value: string): void {
    this.query = value
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer)
      this.searchTimer = -1
    }
    const trimmed = value.trim()
    if (trimmed.length === 0) {
      this.searchSeq++
      this.hits = []
      this.hitSource.clear()
      this.searching = false
      this.searched = false
      return
    }
    this.searching = true
    this.searched = false
    this.searchTimer = setTimeout(() => {
      this.searchTimer = -1
      this.runSearch(trimmed)
    }, 300)
  }

  /** 回车立即搜索，不等防抖 */
  private onSubmitQuery(): void {
    const trimmed = this.trimmedQuery()
    if (trimmed.length === 0) {
      return
    }
    if (this.searchTimer !== -1) {
      clearTimeout(this.searchTimer)
      this.searchTimer = -1
    }
    this.runSearch(trimmed)
  }

  private async runSearch(q: string): Promise<void> {
    this.searchSeq++
    const seq = this.searchSeq
    this.searching = true
    let list: LogoCatalogItem[] = []
    if (this.catalog === 'card') {
      // 只收内置 rawfile 圆标：无内置图的预设会返回站点 favicon（方图），套横卡版式会被裁切
      const platformHits = PlatformService.searchLogoCatalog(q)
      for (let i = 0; i < platformHits.length; i++) {
        if (IconPickerService.isRawfilePath(platformHits[i].url)) {
          list.push(platformHits[i])
        }
      }
    } else {
      list = await IconPickerService.searchIconsByName(q)
    }
    if (seq !== this.searchSeq) {
      return
    }
    this.hits = list
    const objs: Object[] = []
    for (let i = 0; i < list.length; i++) {
      objs.push(list[i])
    }
    this.hitSource.reload(objs)
    this.searched = true
    this.searching = false
  }

  private async pickCatalog(item: LogoCatalogItem): Promise<void> {
    if (this.picking) {
      return
    }
    this.picking = true
    try {
      const host = this.getUIContext().getHostContext()
      if (host === undefined || host === null) {
        AppToast.show(ErrorMessages.CONTEXT_UNAVAILABLE, 1800)
        return
      }
      // 平台圆标走 icon_net_ 前缀：与 isCardFaceUrl 的横卡/圆标判定同源
      const path = await IconPickerService.resolveIconPath(host as common.UIAbilityContext, item.url)
      if (path.length === 0) {
        AppToast.show(ErrorMessages.ICON_FETCH_FAILED, 2000)
        return
      }
      this.onPick(path)
    } catch (_e) {
      AppToast.show(ErrorMessages.ICON_FETCH_FAILED, 2000)
    } finally {
      this.picking = false
    }
  }

  @Builder
  albumPickRow() {
    Row() {
      Stack() {
        Row({ space: 8 }) {
          Image($r('app.media.ic_album'))
            .width(20)
            .height(20)
            .fillColor('#1A1A1A')
          Text('从相册选择新图')
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
      }
      .layoutWeight(1)
      .height(56)
      .linearGradient({
        angle: 135,
        colors: [
          ['#FFFBF5', 0.0],
          ['#FFF5FA', 0.28],
          ['#F8F5FF', 0.52],
          ['#F5FBFF', 0.76],
          ['#F5FFF8', 1.0]
        ]
      })
      .borderRadius(this.theme.sheetCardRadius)
      .shadow({
        radius: 20,
        color: 'rgba(0, 0, 0, 0.05)',
        offsetX: 0,
        offsetY: 4
      })
      .padding({ left: 20, right: 20 })
      .onClick(() => {
        this.onAlbum()
      })
    }
    .width('100%')
    .padding({ left: 24, right: 24 })
    .margin({ bottom: 12 })
  }

  /** 平台圆标格：app 目录主用，card 目录混排信贷平台图标时复用 */
  @Builder
  platformHitCell(item: LogoCatalogItem) {
    Column({ space: 6 }) {
      Stack() {
        Column() {
          Text(item.name.length > 0 ? item.name.substring(0, 1) : '·')
            .fontSize(TypeScale.body)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text2)
        }
        .width(56)
        .height(56)
        .borderRadius(MotionTokens.formLogoRadius)
        .backgroundColor(this.theme.sheetItemBackground())
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)

        LogoImage({
          theme: this.theme,
          url: item.url,
          logoSize: 56,
          radius: MotionTokens.formLogoRadius,
          fit: ImageFit.Cover,
          remoteExact: true,
          remotePrefix: 'icon_net_',
          remoteReadMs: 8000
        })
      }
      Text(item.name)
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text2)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.pickCatalog(item)
    })
  }

  /** 平台圆标瓦片：横卡足迹 + 卡片背景色，圆标居中不拉伸 */
  @Builder
  iconFaceTile(url: string) {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(MotionTokens.cardFaceRadius)
        .backgroundColor(this.theme.sheetItemBackground())

      LogoImage({
        theme: this.theme,
        url: url,
        logoSize: 40,
        radius: MotionTokens.formLogoRadius,
        framed: false,
        fit: ImageFit.Contain
      })
    }
    .width('100%')
    .aspectRatio(MotionTokens.cardFaceRatio)
  }

  /** 信贷平台圆标命中格：瓦片铺满列宽（网格均分 3 列靠左铺开），名称在下 */
  @Builder
  platformTileHitCell(item: LogoCatalogItem) {
    Column({ space: 6 }) {
      this.iconFaceTile(item.url)
      Text(item.name)
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text2)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .textAlign(TextAlign.Center)
        .width('100%')
    }
    .width('100%')
    .padding({ left: MotionTokens.cardPickerInset, right: MotionTokens.cardPickerInset })
    .alignItems(HorizontalAlign.Center)
    .onClick(() => {
      this.pickCatalog(item)
    })
  }

  /** 居中"搜索中"（还没有可保留的旧结果时） */
  @Builder
  searchingCenter() {
    Column({ space: 10 }) {
      LoadingProgress()
        .width(28)
        .height(28)
        .color(this.theme.text3)
      Text('搜索中…')
        .fontSize(TypeScale.body)
        .fontColor(this.theme.text3)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  /** 搜索完成但无结果的空状态 */
  @Builder
  noResultCenter() {
    Column({ space: 6 }) {
      Text('没有找到相关图标')
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text2)
      Text('换个关键词试试，或从相册选择新图')
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text3)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24 })
  }

  /** 空关键词且无最近使用时的引导 */
  @Builder
  idleCenter() {
    Column({ space: 6 }) {
      Text('输入名称搜索图标')
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text2)
      Text('也可以从相册选择一张新图')
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text3)
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .padding({ left: 24, right: 24 })
  }

  @Builder
  recentSection() {
    Scroll() {
      Column({ space: 12 }) {
        Text('最近使用')
          .fontSize(TypeScale.caption)
          .fontColor(this.theme.text3)
          .width('100%')
        if (this.catalog === 'card') {
          Grid() {
            ForEach(this.historyIcons, (path: string, index: number) => {
              GridItem() {
                // 历史里混存卡面（card_face_）与平台圆标（icon_net_），按前缀区分渲染
                if (IconPickerService.isCardFaceUrl(path)) {
                  HistoryFaceCell({
                    theme: this.theme,
                    path: path,
                    onPick: (p: string) => {
                      this.onPick(p)
                    }
                  })
                } else {
                  Column() {
                    this.iconFaceTile(path)
                  }
                  .width('100%')
                  .onClick(() => {
                    this.onPick(path)
                  })
                }
              }
            }, (path: string, index: number) => 'h_' + index + '_' + path)
          }
          .columnsTemplate('1fr 1fr 1fr')
          .columnsGap(8)
          .rowsGap(12)
          .width('100%')
        } else {
          Grid() {
            ForEach(this.historyIcons, (path: string, index: number) => {
              GridItem() {
                LogoImage({
                  theme: this.theme,
                  url: path,
                  logoSize: 56,
                  radius: MotionTokens.formLogoRadius,
                  fit: ImageFit.Cover
                })
                  .onClick(() => {
                    this.onPick(path)
                  })
              }
            }, (path: string, index: number) => 'h_' + index + '_' + path)
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .width('100%')
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 12 })
      .alignItems(HorizontalAlign.Start)
    }
    .layoutWeight(1)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }

  @Builder
  appHitsGrid() {
    Grid() {
      ForEach(this.hits, (item: LogoCatalogItem) => {
        GridItem() {
          this.platformHitCell(item)
        }
      }, (item: LogoCatalogItem) => 's_' + item.url)
    }
    .columnsTemplate('1fr 1fr 1fr 1fr')
    .columnsGap(8)
    .rowsGap(12)
    .width('100%')
  }

  /**
   * 常驻第三方图标声明：面板任何状态都可见，避免用户误以为本应用与金融机构有关联。
   * 只讲无关联无背书；侵权删除是对权利人的仓库层承诺，写在 README / THIRD_PARTY_NOTICES.md。
   */
  @Builder
  legalNotice() {
    Text('第三方机构图标仅用于识别账户，与本应用无关联、无背书')
      .fontSize(TypeScale.caption)
      .fontColor(this.theme.text3)
      .textAlign(TextAlign.Center)
      .width('100%')
      .padding({ left: 24, right: 24, top: 8, bottom: 4 })
  }

  build() {
    Column({ space: 0 }) {
      // 标题栏：左侧标题，右侧关闭按钮（1fr:auto）
      SheetHeader({
        theme: this.theme,
        title: '选择图标',
        onClose: () => {
          this.onCancel()
        }
      })

      this.albumPickRow()

      Column() {
        TextInput({ text: this.query, placeholder: this.catalog === 'card' ? '如：花呗、京东白条' : '如：Visa' })
          .placeholderColor(this.theme.text3)
          .fontColor(this.theme.text)
          .fontSize(TypeScale.control)
          .backgroundColor(this.theme.fieldBackground())
          .borderRadius(this.theme.radiusLg)
          .border({ width: 1, color: this.theme.borderSoft })
          .height(40)
          .padding({ left: 12, right: 12 })
          .width('100%')
          .cancelButton({
            style: CancelButtonStyle.INPUT,
            icon: {
              color: this.theme.text3
            }
          })
          .enterKeyType(EnterKeyType.Search)
          .onChange((value: string) => {
            this.onQueryChange(value)
          })
          .onSubmit(() => {
            this.onSubmitQuery()
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, bottom: 8 })

      if (this.trimmedQuery().length === 0) {
        if (this.historyIcons.length > 0) {
          this.recentSection()
        } else {
          this.idleCenter()
        }
      } else if (this.searching && this.hits.length === 0) {
        this.searchingCenter()
      } else if (this.searched && this.hits.length === 0) {
        this.noResultCenter()
      } else {
        Column() {
          if (this.searching) {
            Row({ space: 6 }) {
              LoadingProgress()
                .width(14)
                .height(14)
                .color(this.theme.text3)
              Text('搜索中…')
                .fontSize(TypeScale.caption)
                .fontColor(this.theme.text3)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
            .padding({ top: 4, bottom: 4 })
          }
          if (this.catalog === 'card') {
            Grid() {
              LazyForEach(this.hitSource, (raw: Object) => {
                GridItem() {
                  this.platformTileHitCell(raw as LogoCatalogItem)
                }
              }, (raw: Object) => 's_' + (raw as LogoCatalogItem).url)
            }
            .columnsTemplate('1fr 1fr 1fr')
            .columnsGap(8)
            .rowsGap(12)
            .width('100%')
            .layoutWeight(1)
            .cachedCount(4)
            .padding({ left: 24, right: 24, bottom: 12 })
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
          } else {
            Scroll() {
              Column() {
                this.appHitsGrid()
              }
              .width('100%')
              .padding({ left: 24, right: 24, bottom: 12 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .edgeEffect(EdgeEffect.Spring)
            .align(Alignment.Top)
          }
        }
        .width('100%')
        .layoutWeight(1)
      }

      this.legalNotice()
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ top: 0, bottom: sheetBottomInset() })
  }
}

/**
 * 最近使用卡面格：横卡面铺满整格；老历史混入的方图（平台圆标 / 相册方图）
 * 居中不拉伸、外层卡片背景色。横/方按图头解码宽高比判定
 *（getImageInfo 只读文件头，开销低）。
 */
@Component
// 需 @State 承载横/方判定结果，不宜降为 @Builder
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
struct HistoryFaceCell {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop path: string = ''
  onPick: (path: string) => void = () => {}
  @State private square: boolean = false
  @State private probed: boolean = false

  aboutToAppear(): void {
    this.probe()
  }

  private async probe(): Promise<void> {
    const abs = this.path.startsWith('file://') ? this.path.substring(7) : this.path
    try {
      const src = image.createImageSource(abs)
      try {
        const info = await src.getImageInfo()
        const w = info.size.width
        const h = info.size.height
        if (w > 0 && h > 0) {
          // 宽高比 < 1.2 视为方图
          this.square = w * 5 <= h * 6
        }
      } finally {
        try {
          src.release()
        } catch (_se) {
        }
      }
    } catch (_e) {
    }
    this.probed = true
  }

  private isSquare(): boolean {
    return this.probed && this.square
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .borderRadius(MotionTokens.cardFaceRadius)
        .backgroundColor(this.theme.sheetItemBackground())
        .clip(true)
      Image(this.path)
        .width(this.isSquare() ? 40 : '100%')
        .height(this.isSquare() ? 40 : '100%')
        .borderRadius(this.isSquare() ? MotionTokens.formLogoRadius : MotionTokens.cardFaceRadius)
        .clip(true)
        .objectFit(this.probed && !this.square ? ImageFit.Cover : ImageFit.Contain)
    }
    .width('100%')
    .aspectRatio(MotionTokens.cardFaceRatio)
    .onClick(() => {
      this.onPick(this.path)
    })
  }
}
