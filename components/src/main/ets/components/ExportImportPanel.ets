import { ThemeColors, TypeScale, MotionTokens } from 'common'
import { ExportImportService, ImportResult } from 'service'
import { common } from '@kit.AbilityKit'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import { sheetBottomInset } from './SheetDialog'

/** 进度态文案：export / import / clear（clearing 优先） */
export function exportImportProgressTitle(clearing: boolean, busyKind: string): string {
  if (clearing) {
    return ErrorMessages.CLEARING
  }
  if (busyKind === 'export') {
    return ErrorMessages.EXPORTING
  }
  if (busyKind === 'import') {
    return ErrorMessages.IMPORTING
  }
  return '处理中…'
}

/**
 * 导入/导出 · 底部半模态内容
 * - 导出/导入/清空：过程中展示圆角卡片 + 环形 LoadingProgress（参考进度可视化）
 * - 结束后 toast 结果；清空由父级 clearing 驱动
 */
@Component
export struct ExportImportPanel {
  @Prop theme: ThemeColors = new ThemeColors()
  /** 父级正在清空：展示进度、禁用交互 */
  @Prop clearing: boolean = false
  @State private busy: boolean = false
  /** export | import | 空 */
  @State private busyKind: string = ''
  @State private pressedKey: string = ''
  onClearAllData?: () => void
  /** 导入/导出 busy 变化，供父级禁止关 sheet */
  onBusyChange?: (busy: boolean) => void

  private hostContext(): common.UIAbilityContext | null {
    try {
      return this.getUIContext().getHostContext() as common.UIAbilityContext
    } catch {
      return null
    }
  }

  private toast(message: string): void {
    AppToast.show(message, 2800)
  }

  /** 清空中或单次导入导出进行中：禁止再点 */
  private isBlocked(): boolean {
    return this.busy || this.clearing
  }

  private showProgress(): boolean {
    return this.busy || this.clearing
  }

  private progressTitle(): string {
    return exportImportProgressTitle(this.clearing, this.busyKind)
  }

  private async runExport(
    kind: string,
    work: (ctx: common.UIAbilityContext) => Promise<boolean>,
    okMsg: string
  ): Promise<void> {
    if (this.isBlocked()) {
      return
    }
    const context = this.hostContext()
    if (!context) {
      this.toast(ErrorMessages.CONTEXT_UNAVAILABLE)
      return
    }
    this.busyKind = kind
    this.busy = true
    if (this.onBusyChange) {
      this.onBusyChange(true)
    }
    try {
      const ok = await work(context)
      this.toast(ok ? okMsg : ErrorMessages.EXPORT_FAILED)
    } finally {
      this.busy = false
      this.busyKind = ''
      if (this.onBusyChange) {
        this.onBusyChange(false)
      }
    }
  }

  private async runImport(
    work: (ctx: common.UIAbilityContext) => Promise<ImportResult>
  ): Promise<void> {
    if (this.isBlocked()) {
      return
    }
    const context = this.hostContext()
    if (!context) {
      this.toast(ErrorMessages.CONTEXT_UNAVAILABLE)
      return
    }
    this.busyKind = 'import'
    this.busy = true
    if (this.onBusyChange) {
      this.onBusyChange(true)
    }
    try {
      const result = await work(context)
      this.toast(result.message.length > 0 ? result.message :
        (result.success ? ErrorMessages.IMPORT_OK : ErrorMessages.IMPORT_FAILED))
    } finally {
      this.busy = false
      this.busyKind = ''
      if (this.onBusyChange) {
        this.onBusyChange(false)
      }
    }
  }

  private async exportJson(): Promise<void> {
    await this.runExport('export', (ctx: common.UIAbilityContext) => {
      return ExportImportService.saveJsonToFile(ctx)
    }, ErrorMessages.EXPORT_JSON_OK)
  }

  private async exportCsv(): Promise<void> {
    await this.runExport('export', (ctx: common.UIAbilityContext) => {
      return ExportImportService.saveCsvToFile(ctx)
    }, ErrorMessages.EXPORT_CSV_OK)
  }

  private async importData(): Promise<void> {
    await this.runImport((ctx: common.UIAbilityContext) => {
      return ExportImportService.importFromFile(ctx)
    })
  }

  private async importStatementCsv(): Promise<void> {
    await this.runImport((ctx: common.UIAbilityContext) => {
      return ExportImportService.importStatementCsv(ctx)
    })
  }

  @Builder
  ProgressCard() {
    Column({ space: this.theme.spaceSm }) {
      // 圆角浮卡 + 环形进度（对齐参考图的卡片进度可视化）
      Column() {
        LoadingProgress()
          .width(40)
          .height(40)
          .color(this.theme.text3)
      }
      .width(80)
      .height(80)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor(this.theme.sheetItemBackground())
      .borderRadius(this.theme.radiusXl)
      .border({ width: 0.5, color: this.theme.borderStrong })
      .shadow(this.theme.floatShadowOptions())

      Text(this.progressTitle())
        .fontSize(TypeScale.listPrimary)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text)
      Text('请稍候，完成后会提示结果')
        .fontSize(TypeScale.bodySm)
        .fontColor(this.theme.text3)
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 28, bottom: sheetBottomInset(40) })
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  build() {
    if (this.showProgress()) {
      this.ProgressCard()
    } else {
    Column({ space: 12 }) {
      Text('清空')
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text3)
        .width('100%')

      Column({ space: 6 }) {
        Text('清空本机数据')
          .fontSize(TypeScale.listPrimary)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.red)
        Text('删除负债、订阅、信用账户与还款记录；登录云端时云端数据一并清空。不可恢复。')
          .fontSize(TypeScale.bodySm)
          .fontColor(this.theme.text3)
      }
      .width('100%')
      .padding(this.theme.spaceSm)
      .alignItems(HorizontalAlign.Start)
      .backgroundColor(this.theme.sheetItemBackground())
      .borderRadius(this.theme.radiusSm)
      .border({ width: 1, color: this.theme.borderStrong })
      .opacity((this.isBlocked() ? 0.5 : 1) * (this.pressedKey === 'clear' ? 0.92 : 1))
      .scale({ x: this.pressedKey === 'clear' ? MotionTokens.pressScale : 1,
        y: this.pressedKey === 'clear' ? MotionTokens.pressScale : 1 })
      .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
      .onTouch((e: TouchEvent) => {
        if (e.type === TouchType.Down) {
          this.pressedKey = 'clear'
        } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
          this.pressedKey = ''
        }
      })
      .onClick(() => {
        if (!this.isBlocked() && this.onClearAllData) {
          this.onClearAllData()
        }
      })

      Text('导入')
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text3)
        .width('100%')
        .margin({ top: 4 })

      Row({ space: 10 }) {
        Column({ space: 6 }) {
          Text('JSON')
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
          Text('从备份恢复')
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text3)
        }
        .layoutWeight(1)
        .padding(this.theme.spaceSm)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.theme.sheetItemBackground())
        .borderRadius(this.theme.radiusSm)
        .border({ width: 1, color: this.theme.borderStrong })
        .opacity((this.isBlocked() ? 0.5 : 1) * (this.pressedKey === 'importJson' ? 0.92 : 1))
        .scale({ x: this.pressedKey === 'importJson' ? MotionTokens.pressScale : 1,
          y: this.pressedKey === 'importJson' ? MotionTokens.pressScale : 1 })
        .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedKey = 'importJson'
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedKey = ''
          }
        })
        .onClick(() => {
          this.importData()
        })

        Column({ space: 6 }) {
          Text('CSV')
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
          Text('交易流水')
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text3)
        }
        .layoutWeight(1)
        .padding(this.theme.spaceSm)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.theme.sheetItemBackground())
        .borderRadius(this.theme.radiusSm)
        .border({ width: 1, color: this.theme.borderStrong })
        .opacity((this.isBlocked() ? 0.5 : 1) * (this.pressedKey === 'importCsv' ? 0.92 : 1))
        .scale({ x: this.pressedKey === 'importCsv' ? MotionTokens.pressScale : 1,
          y: this.pressedKey === 'importCsv' ? MotionTokens.pressScale : 1 })
        .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedKey = 'importCsv'
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedKey = ''
          }
        })
        .onClick(() => {
          this.importStatementCsv()
        })
      }
      .width('100%')

      Text('导出')
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text3)
        .width('100%')
        .margin({ top: 4 })

      Row({ space: 10 }) {
        Column({ space: 6 }) {
          Text('JSON')
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
          Text('完整备份')
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text3)
        }
        .layoutWeight(1)
        .padding(this.theme.spaceSm)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.theme.sheetItemBackground())
        .borderRadius(this.theme.radiusSm)
        .border({ width: 1, color: this.theme.borderStrong })
        .opacity((this.isBlocked() ? 0.5 : 1) * (this.pressedKey === 'exportJson' ? 0.92 : 1))
        .scale({ x: this.pressedKey === 'exportJson' ? MotionTokens.pressScale : 1,
          y: this.pressedKey === 'exportJson' ? MotionTokens.pressScale : 1 })
        .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedKey = 'exportJson'
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedKey = ''
          }
        })
        .onClick(() => {
          this.exportJson()
        })

        Column({ space: 6 }) {
          Text('CSV')
            .fontSize(TypeScale.listPrimary)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.text)
          Text('表格导出')
            .fontSize(TypeScale.bodySm)
            .fontColor(this.theme.text3)
        }
        .layoutWeight(1)
        .padding(this.theme.spaceSm)
        .alignItems(HorizontalAlign.Start)
        .backgroundColor(this.theme.sheetItemBackground())
        .borderRadius(this.theme.radiusSm)
        .border({ width: 1, color: this.theme.borderStrong })
        .opacity((this.isBlocked() ? 0.5 : 1) * (this.pressedKey === 'exportCsv' ? 0.92 : 1))
        .scale({ x: this.pressedKey === 'exportCsv' ? MotionTokens.pressScale : 1,
          y: this.pressedKey === 'exportCsv' ? MotionTokens.pressScale : 1 })
        .animation({ duration: MotionTokens.pressDuration, curve: Curve.EaseOut })
        .onTouch((e: TouchEvent) => {
          if (e.type === TouchType.Down) {
            this.pressedKey = 'exportCsv'
          } else if (e.type === TouchType.Up || e.type === TouchType.Cancel) {
            this.pressedKey = ''
          }
        })
        .onClick(() => {
          this.exportCsv()
        })
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 4, bottom: sheetBottomInset(28) })
    }
  }
}
