import { ThemeColors, TypeScale, Utils, AppStorageKeys, CurrencyService } from 'common'
import { AppToast, ErrorMessages } from 'common'
import { ReceiptLine, ReceiptModel, DebtReceiptModel, AccountReceiptModel } from 'service'
import { ReceiptShareKit } from './ReceiptShareKit'
// SaveButton / SaveDescription / SaveButtonOnClickResult
// 为 ArkUI 安全控件全局类型，勿从 @kit.ArkUI 具名导入（SDK 未导出，会编译失败）

/**
 * 小票票面视图模型：订阅月结小票与负债小票共用的差异位。
 * 票面骨架（顶栏 -> 条目 -> 合计 -> 元信息 -> 锯齿）完全同版式，
 * 只有合计口径、负债专属元信息行与导出/分享配置不同。
 */
export class ReceiptSlipModel {
  lines: ReceiptLine[] = []
  /** 合计行文案：订阅「本月合计」/ 负债「剩余待还」 */
  totalLabel: string = ''
  totalFen: number = 0
  /** 已还进度（0-100），<=0 时整行不显示（订阅小票无此行） */
  progressPercent: number = -1
  /** 预计还清日期，空串不显示该行（仅负债小票有） */
  payoffDate: string = ''
  /** 离屏导出节点 id：同一页面两类小票不冲突即可 */
  posterId: string = 'receiptSlipPoster'
  /** 导出文件名前缀 */
  snapshotPrefix: string = 'goforward_receipt_'
  shareTitle: string = ''
  shareSubject: string = ''

  static fromSubscription(model: ReceiptModel): ReceiptSlipModel {
    const slip = new ReceiptSlipModel()
    slip.lines = model.lines
    slip.totalLabel = '本月合计'
    slip.totalFen = model.totalMonthlyFen
    slip.posterId = 'subscriptionReceiptPoster'
    slip.snapshotPrefix = 'goforward_subs_'
    slip.shareTitle = '我的月度订阅小票'
    slip.shareSubject = '向前 · 订阅月结'
    return slip
  }

  static fromDebt(model: DebtReceiptModel): ReceiptSlipModel {
    const slip = new ReceiptSlipModel()
    slip.lines = model.lines
    slip.totalLabel = '剩余待还'
    slip.totalFen = model.totalRemainingFen
    slip.progressPercent = model.progressPercent
    slip.payoffDate = model.payoffDate
    slip.posterId = 'debtReceiptPoster'
    slip.snapshotPrefix = 'goforward_debt_'
    slip.shareTitle = '我的负债小票'
    slip.shareSubject = '向前 · 负债进度'
    return slip
  }

  static fromAccount(model: AccountReceiptModel): ReceiptSlipModel {
    const slip = new ReceiptSlipModel()
    slip.lines = model.lines
    slip.totalLabel = '总额度'
    slip.totalFen = model.totalLimitFen
    slip.posterId = 'accountReceiptPoster'
    slip.snapshotPrefix = 'goforward_acct_'
    slip.shareTitle = '我的账户小票'
    slip.shareSubject = '向前 · 账户额度'
    return slip
  }
}

/**
 * 小票浮层：白纸黑字热敏票，订阅月结与负债共用同一版式
 * （顶栏居中一行图标+向前 -> 条目 -> 合计 -> 元信息 -> 日期 -> 锯齿）。
 * 一屏看完、不滚动、不分页；多项时整票同步缩小。
 */
@Component
export struct ReceiptSlipOverlay {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop @Watch('onModelChange') model: ReceiptSlipModel = new ReceiptSlipModel()
  /** 防窥脱敏态：系统检测到窥视时票面名称/金额/日期打码并暂停保存分享（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  onClose: () => void = () => {}

  @State private saving: boolean = false
  @State private sharing: boolean = false
  @State private topSafe: number = 0
  @State private bottomSafe: number = 0
  @State private receiptWidth: number = 240
  private readonly slipWidth: number = 240
  private readonly posterPad: number = 52
  private readonly paper: string = '#FDFDFB'
  private readonly ink: string = '#1A1A1A'
  private readonly inkMute: string = '#9A9A9A'
  private readonly lineDot: string = '#D6D6D6'
  private readonly toothHeight: number = 8
  private readonly toothCount: number = 32
  private readonly ruleDotCount: number = 42
  /** 整票等比缩放：多项时同步缩小，下限保证能看清 */
  @State private appliedScale: number = 1
  @State private faceH: number = 0
  @State private hostH: number = 0
  @State private actionsH: number = 0
  private readonly minScale: number = 0.62
  /** 小票与操作条间距：短票/长票都保持这一档，不贴屏底 */
  private readonly ticketActionsGap: number = 10

  aboutToAppear() {
    this.topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    this.bottomSafe = AppStorage.get<number>(AppStorageKeys.BOTTOM_SAFE_HEIGHT) ?? 0
    this.receiptWidth = this.slipWidth
    this.appliedScale = this.scaleForCount(this.model.lines.length)
  }

  private onModelChange(): void {
    this.appliedScale = this.scaleForCount(this.model.lines.length)
    this.faceH = 0
  }

  /** 按条数先落到接近一页的比例，避免首帧撑出屏再回缩 */
  private scaleForCount(n: number): number {
    if (n <= 5) {
      return 1
    }
    if (n <= 8) {
      return 0.92
    }
    if (n <= 12) {
      return 0.82
    }
    if (n <= 18) {
      return 0.74
    }
    return 0.68
  }

  /** 票面度量：字号/间距/图标同步乘同一比例 */
  private sz(vp: number): number {
    return vp * this.appliedScale
  }

  /** 票面可用高 = 内容区减去操作条与固定小间距（宿主含安全区 padding） */
  private stageH(): number {
    const pad = this.topSafe + 12 + this.bottomSafe + 16
    const h = this.hostH - pad - this.actionsH - this.ticketActionsGap
    return h > 0 ? h : 0
  }

  /** 仅缩小、不回放；避免 onAreaChange 来回抖 */
  private recomputeFit(): void {
    const stage = this.stageH()
    if (this.faceH <= 1 || stage <= 1) {
      return
    }
    if (this.faceH <= stage + 4) {
      return
    }
    const next = this.appliedScale * stage / this.faceH
    const s = next < this.minScale ? this.minScale : (next > 1 ? 1 : next)
    if (Math.abs(s - this.appliedScale) >= 0.015) {
      this.appliedScale = s
    }
  }

  /** 与列表同口径：一律人民币周期金额（外币已按锁定汇率折合） */
  private money(fen: number, code: string = 'CNY'): string {
    return CurrencyService.getSymbol(code) + Utils.formatMoney(fen, false)
  }

  private metaDate(): string {
    const d = new Date()
    return d.getFullYear() + '年' + (d.getMonth() + 1) + '月' + d.getDate() + '日'
  }

  private vpPx(vp: number): number {
    try {
      const px = this.getUIContext().vp2px(vp)
      return px > 0 ? px : vp * 3
    } catch (_e) {
      return vp * 3
    }
  }

  private tearCommands(): string {
    const w = this.vpPx(this.receiptWidth)
    const h = this.vpPx(this.sz(this.toothHeight))
    const n = this.toothCount
    const tw = w / n
    let p = 'M0 0'
    for (let i = 0; i < n; i++) {
      p += ' L' + (i * tw + tw / 2).toString() + ' ' + h.toString()
      p += ' L' + ((i + 1) * tw).toString() + ' 0'
    }
    p += ' Z'
    return p
  }

  private ruleDotIndexes(): number[] {
    const arr: number[] = []
    for (let i = 0; i < this.ruleDotCount; i++) {
      arr.push(i)
    }
    return arr
  }

  private async saveToAlbum(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    try {
      const cachePath =
        await ReceiptShareKit.snapshotToFile(this.getUIContext(), this.model.posterId, this.model.snapshotPrefix)
      if (cachePath === undefined) {
        AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
        return
      }
      if (await ReceiptShareKit.saveToAlbum(this.getUIContext(), cachePath)) {
        AppToast.show('已保存到相册', 2000)
        this.onClose()
      }
    } catch (_e) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    } finally {
      this.saving = false
    }
  }

  private async shareSystem(): Promise<void> {
    if (this.sharing) {
      return
    }
    this.sharing = true
    try {
      const cachePath =
        await ReceiptShareKit.snapshotToFile(this.getUIContext(), this.model.posterId, this.model.snapshotPrefix)
      if (cachePath === undefined) {
        AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
        return
      }
      if (await ReceiptShareKit.shareSystem(this.getUIContext(), cachePath, this.model.shareTitle, this.model.shareSubject)) {
        this.onClose()
      }
    } catch (_e) {
      AppToast.show('分享失败，请重试', 2000)
    } finally {
      this.sharing = false
    }
  }

  @Builder
  dottedLine() {
    Row({ space: 2 }) {
      ForEach(this.ruleDotIndexes(), (i: number) => {
        Column()
          .width(2)
          .height(1)
          .backgroundColor(this.lineDot)
      }, (i: number) => 'rd_' + i)
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(VerticalAlign.Center)
    .height(this.sz(2))
  }

  @Builder
  metaRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(this.sz(TypeScale.caption))
        .fontColor(this.inkMute)
      Blank()
      Text(value)
        .fontSize(this.sz(TypeScale.caption))
        .fontFamily(TypeScale.FONT_MONO)
        .fontColor(this.ink)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  itemRow(line: ReceiptLine) {
    Row() {
      Column({ space: this.sz(3) }) {
        Text(Utils.maskIf(this.antiPeekMasked, line.name))
          .fontSize(this.sz(TypeScale.body))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.ink)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
        if (line.subtitle.length > 0) {
          Text(Utils.maskIf(this.antiPeekMasked, line.subtitle))
            .fontSize(this.sz(TypeScale.caption))
            .fontColor(this.inkMute)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: this.sz(12) })

      Text(Utils.maskIf(this.antiPeekMasked, this.money(line.cnyFen), Utils.MASK_AMOUNT))
        .fontSize(this.sz(TypeScale.body))
        .fontWeight(FontWeight.Medium)
        .fontFamily(TypeScale.FONT_MONO)
        .fontColor(this.ink)
        .flexShrink(0)
        .maxLines(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  receiptFace(withShadow: boolean = true) {
    Column() {
      Column({ space: this.sz(14) }) {
        Row({ space: this.sz(8) }) {
          Image($r('app.media.ic_app_logo'))
            .width(this.sz(28))
            .height(this.sz(28))
            .objectFit(ImageFit.Cover)
            .backgroundColor(this.ink)
            .flexShrink(0)
          Text('向前')
            .fontSize(this.sz(TypeScale.body))
            .fontWeight(FontWeight.Medium)
            .fontColor(this.ink)
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(VerticalAlign.Center)
        .margin({ bottom: this.sz(6) })

        this.dottedLine()

        Column({ space: this.sz(12) }) {
          ForEach(this.model.lines, (line: ReceiptLine, index: number) => {
            this.itemRow(line)
          }, (line: ReceiptLine, index: number) => 'ln_' + index + '_' + line.name)
        }
        .width('100%')

        this.dottedLine()

        Row() {
          Text(this.model.totalLabel)
            .fontSize(this.sz(TypeScale.body))
            .fontColor(this.ink)
          Blank()
          Text(Utils.maskIf(this.antiPeekMasked, this.money(this.model.totalFen), Utils.MASK_AMOUNT))
            .fontSize(this.sz(TypeScale.body))
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(this.ink)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        this.dottedLine()

        Column({ space: this.sz(8) }) {
          if (this.model.progressPercent > 0) {
            this.metaRow('已还进度', Utils.maskIf(this.antiPeekMasked, this.model.progressPercent + '%'))
          }
          if (this.model.payoffDate.length > 0) {
            this.metaRow('预计还清', Utils.maskIf(this.antiPeekMasked, this.model.payoffDate))
          }
          this.metaRow('日期', Utils.maskIf(this.antiPeekMasked, this.metaDate()))
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: this.sz(20),
        right: this.sz(20),
        top: this.sz(36),
        bottom: this.sz(32)
      })
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.paper)
      .borderRadius({ topLeft: 2, topRight: 2, bottomLeft: 0, bottomRight: 0 })
      .clip(true)
      .shadow(withShadow ? this.theme.receiptShadowOptions() : this.theme.noneShadowOptions())

      Shape() {
        Path()
          .width(this.receiptWidth)
          .height(this.sz(this.toothHeight))
          .commands(this.tearCommands())
          .fill(this.paper)
          .stroke(Color.Transparent)
          .strokeWidth(0)
      }
      .width(this.receiptWidth)
      .height(this.sz(this.toothHeight))
      .margin({ top: -1 })
    }
    .width(this.slipWidth)
    .alignItems(HorizontalAlign.Center)
    .clip(false)
    .onAreaChange((_old, area) => {
      const w = area.width as number
      const h = area.height as number
      if (w > 0 && Math.abs(w - this.receiptWidth) > 1) {
        this.receiptWidth = w
      }
      if (h > 0 && Math.abs(h - this.faceH) > 1) {
        this.faceH = h
        this.recomputeFit()
      }
    })
  }

  @Builder
  bottomBar() {
    Row({ space: 12 }) {
      SaveButton({ text: SaveDescription.SAVE_IMAGE, buttonType: ButtonType.Capsule })
        .width((this.slipWidth - 12) / 2)
        .height(44)
        .fontSize(TypeScale.control)
        .fontColor(this.paper)
        .backgroundColor(this.ink)
        .enabled(!this.saving && !this.sharing && !this.antiPeekMasked)
        .onClick((_event: ClickEvent, result: SaveButtonOnClickResult) => {
          if (result === SaveButtonOnClickResult.SUCCESS) {
            this.saveToAlbum()
          }
        })

      Button() {
        Row({ space: 6 }) {
          Image($r('app.media.ic_share'))
            .width(16)
            .height(16)
            .fillColor(this.ink)
          Text('分享')
            .fontSize(TypeScale.control)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.ink)
        }
      }
      .width((this.slipWidth - 12) / 2)
      .height(44)
      .backgroundColor(this.paper)
      .borderRadius(this.theme.radiusPill)
      .enabled(!this.saving && !this.sharing && !this.antiPeekMasked)
      .onClick(() => {
        this.shareSystem()
      })
    }
    .width(this.slipWidth)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 半透明磨砂背景：点小票周围关闭（整组不再铺满全屏抢点击）
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .backgroundBlurStyle(BlurStyle.Thin)
        .onClick(() => {
          this.onClose()
        })
        .onAreaChange((_old: Area, area: Area) => {
          const h = area.height as number
          if (h > 0 && Math.abs(h - this.hostH) > 1) {
            this.hostH = h
            this.recomputeFit()
          }
        })

      // 仅票+操作条占位；周围空白落到背景上
      Column() {
        this.receiptFace(true)

        Column({ space: 8 }) {
          this.bottomBar()
        }
        .width(this.slipWidth)
        .alignItems(HorizontalAlign.Center)
        .margin({ top: this.ticketActionsGap })
        .flexShrink(0)
        .onAreaChange((_old: Area, area: Area) => {
          const h = area.height as number
          if (h > 0 && Math.abs(h - this.actionsH) > 1) {
            this.actionsH = h
            this.recomputeFit()
          }
        })
      }
      .alignItems(HorizontalAlign.Center)
      .clip(false)
      .margin({
        top: this.topSafe + 12,
        bottom: this.bottomSafe + 16,
        left: 32,
        right: 32
      })
      .onClick(() => {
        // 点在票或按钮上不关闭
      })

      // 离屏导出：透明底，只出小票；四周留白给悬浮阴影
      Column() {
        this.receiptFace(true)
      }
      .id(this.model.posterId)
      .width(this.slipWidth + this.posterPad * 2)
      .padding(this.posterPad)
      .backgroundColor(Color.Transparent)
      .clip(false)
      .position({ x: -4000, y: 0 })
    }
    .width('100%')
    .height('100%')
  }
}
