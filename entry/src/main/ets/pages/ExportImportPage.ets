import { LengthMetrics } from '@kit.ArkUI'
import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'
import { MotionHelper } from 'common'
import { ImmersiveTitleBar } from 'common'
import { SettingsService } from 'service'
import { UserService } from 'service'
import { ExportImportService } from 'service'
import { common } from '@kit.AbilityKit'
import { SheetDialogView, SheetDialogConfig, SheetDialogButton } from 'components'
import { AppStorageKeys } from 'common'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { AppRouter } from 'common'

@Component
export struct ExportImportPage {
  @State theme: ThemeColors = ThemeManager.DARK
  @State busy: boolean = false
  /** export | import | clear | 空 */
  @State busyKind: string = ''
  @State showSheet: boolean = false
  @State sheetConfig: SheetDialogConfig = new SheetDialogConfig()
  private sheetCallback: (index: number) => void = () => {}
  private pageScroller: Scroller = new Scroller()

  aboutToAppear() {
    this.loadTheme()
  }

  private goBack(): void {
    AppRouter.pop()
  }

  private toast(message: string): void {
    AppToast.show(message, 2800)
  }

  private progressTitle(): string {
    if (this.busyKind === 'export') {
      return ErrorMessages.EXPORTING
    }
    if (this.busyKind === 'import') {
      return ErrorMessages.IMPORTING
    }
    if (this.busyKind === 'clear') {
      return ErrorMessages.CLEARING
    }
    return '处理中…'
  }

  private async loadTheme(): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    const storedLux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
    const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false
    if (settings.eye_care_enabled) {
      this.theme = ThemeManager.eyeCareTheme(systemDark)
    } else if (settings.light_sense_enabled && storedLux >= 0) {
      this.theme = ThemeManager.autoTheme(storedLux, systemDark)
    } else {
      this.theme = ThemeManager.currentTheme(settings, systemDark, storedLux)
    }
  }

  private async exportJson(): Promise<void> {
    if (this.busy) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      this.toast(ErrorMessages.CONTEXT_UNAVAILABLE)
      return
    }
    this.busyKind = 'export'
    this.busy = true
    try {
      const ok = await ExportImportService.saveJsonToFile(context)
      this.toast(ok ? ErrorMessages.EXPORT_JSON_OK : ErrorMessages.EXPORT_FAILED)
    } finally {
      this.busy = false
      this.busyKind = ''
    }
  }

  private async exportCsv(): Promise<void> {
    if (this.busy) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      this.toast(ErrorMessages.CONTEXT_UNAVAILABLE)
      return
    }
    this.busyKind = 'export'
    this.busy = true
    try {
      const ok = await ExportImportService.saveCsvToFile(context)
      this.toast(ok ? ErrorMessages.EXPORT_CSV_OK : ErrorMessages.EXPORT_FAILED)
    } finally {
      this.busy = false
      this.busyKind = ''
    }
  }

  private async importData(): Promise<void> {
    if (this.busy) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      this.toast(ErrorMessages.CONTEXT_UNAVAILABLE)
      return
    }
    this.busyKind = 'import'
    this.busy = true
    try {
      const result = await ExportImportService.importFromFile(context)
      this.toast(result.message.length > 0 ? result.message :
        (result.success ? ErrorMessages.IMPORT_OK : ErrorMessages.IMPORT_FAILED))
    } finally {
      this.busy = false
      this.busyKind = ''
    }
  }

  private async importStatementCsv(): Promise<void> {
    if (this.busy) {
      return
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext
    if (!context) {
      this.toast(ErrorMessages.CONTEXT_UNAVAILABLE)
      return
    }
    this.busyKind = 'import'
    this.busy = true
    try {
      const result = await ExportImportService.importStatementCsv(context)
      this.toast(result.message.length > 0 ? result.message :
        (result.success ? ErrorMessages.IMPORT_OK : ErrorMessages.IMPORT_FAILED))
    } finally {
      this.busy = false
      this.busyKind = ''
    }
  }

  private clearAllData(): void {
    if (this.busy) {
      return
    }
    const config = new SheetDialogConfig(
      '确认清空？',
      '将删除本机负债、订阅、信用账户和还款记录。若已登录云端，云端数据也会清空。此操作不可恢复。',
      [
        new SheetDialogButton('取消', this.theme.text2, 'cancel'),
        new SheetDialogButton('确认清空', this.theme.red, 'destructive')
      ]
    )
    this.openSheet(config, (index: number) => {
      if (index === 1) {
        this.doClearAll()
      }
    })
  }

  private openSheet(config: SheetDialogConfig, callback: (index: number) => void): void {
    this.sheetConfig = config
    this.sheetCallback = callback
    this.getUIContext().animateTo({ duration: MotionTokens.sheetDuration, curve: Curve.FastOutSlowIn }, () => {
      this.showSheet = true
    })
  }

  private async doClearAll(): Promise<void> {
    if (this.busy) {
      return
    }
    this.busyKind = 'clear'
    this.busy = true
    // 过程中不 toast「正在清空」；完成后只 toast 一次结果（与设置页数据管理一致）
    try {
      const result = await ExportImportService.clearAllUserData()
      if (!result.localCleared) {
        this.toast(ErrorMessages.CLEAR_FAILED)
      } else if (result.cloudDataFailed) {
        this.toast(ErrorMessages.CLEAR_CLOUD_FAILED)
      } else {
        this.toast(ErrorMessages.DATA_CLEARED)
      }
    } catch (_e) {
      this.toast(ErrorMessages.CLEAR_FAILED)
    } finally {
      this.busy = false
      this.busyKind = ''
    }
  }

  /** 页转场位移/透明度（MotionHelper.navPageTransition 驱动） */
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  @Builder
  ProgressOverlay() {
    Column({ space: this.theme.spaceSm }) {
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
      .backgroundColor(this.theme.surface2)
      .borderRadius(this.theme.radiusXl)
      .border({ width: 0.5, color: this.theme.borderSoft })
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
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.theme.sheetMaskColor())
    .onClick(() => {
      // 吞点击，阻止穿透操作
    })
  }

  build() {
    NavDestination() {
    Stack() {
    HdsNavigation() {
      Scroll(this.pageScroller) {
        Column({ space: 16 }) {
          Text('导出')
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text3)
            .alignSelf(ItemAlign.Start)
          Button('导出 JSON 备份')
            .width('100%')
            .height(48)
            .fontSize(TypeScale.listPrimarySm)
            .backgroundColor(this.theme.ctaBackground())
            .fontColor(this.theme.ctaForeground())
            .borderRadius(this.theme.radiusSm)
            .enabled(!this.busy)
            .onClick(() => this.exportJson())

          Button('导出 CSV')
            .width('100%')
            .height(48)
            .fontSize(TypeScale.listPrimarySm)
            .backgroundColor(this.theme.surface)
            .fontColor(this.theme.text)
            .borderRadius(this.theme.radiusSm)
            .border({ width: 1, color: this.theme.border })
            .enabled(!this.busy)
            .onClick(() => this.exportCsv())

          Text('导入')
            .fontSize(TypeScale.body)
            .fontColor(this.theme.text3)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 8 })
          Button('从 JSON 备份恢复')
            .width('100%')
            .height(48)
            .fontSize(TypeScale.listPrimarySm)
            .backgroundColor(this.theme.surface)
            .fontColor(this.theme.text)
            .borderRadius(this.theme.radiusSm)
            .border({ width: 1, color: this.theme.border })
            .enabled(!this.busy)
            .onClick(() => this.importData())

          Button('导入 CSV 交易流水 (自动匹配还款)')
            .width('100%')
            .height(48)
            .fontSize(TypeScale.control)
            .backgroundColor(this.theme.surface)
            .fontColor(this.theme.text)
            .borderRadius(this.theme.radiusSm)
            .border({ width: 1, color: this.theme.border })
            .enabled(!this.busy)
            .onClick(() => this.importStatementCsv())

          Text('危险区')
            .fontSize(TypeScale.body)
            .fontColor(this.theme.red)
            .alignSelf(ItemAlign.Start)
            .margin({ top: 16 })
          Button('清空所有数据')
            .width('100%')
            .height(48)
            .fontSize(TypeScale.listPrimarySm)
            .backgroundColor(this.theme.dangerBackground())
            .fontColor(this.theme.dangerForeground())
            .borderRadius(this.theme.radiusSm)
            .enabled(!this.busy)
            .onClick(() => this.clearAllData())
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 24 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .clip(false)
    }
    .titleBar({
      avoidLayoutSafeArea: true,
      enableComponentSafeArea: true,
      style: {
        scrollEffectOpts: {
          enableScrollEffect: true,
          scrollEffectType: ScrollEffectType.GRADIENT_BLUR
        },
        systemMaterialEffect: ImmersiveTitleBar.material()
      },
      content: {
        title: {
          mainTitle: '导入 / 导出'
        },
        backIcon: {
          label: '返回',
          action: () => {
            if (!this.busy) {
              this.goBack()
            }
          }
        }
      }
    })
    // 宽屏/折叠屏默认 Auto→Split 会把内容挤到半屏，二级页强制 Stack 全宽
    .mode(NavigationMode.Stack)
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(false)
    .bindToScrollable([this.pageScroller])
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.background)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .bindSheet(this.showSheet, this.sheetBuilder, {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      radius: LengthMetrics.vp(this.theme.sheetRadius),
      showClose: false,
      backgroundColor: this.theme.sheetBackground() as string,
      blurStyle: BlurStyle.NONE,
      maskColor: this.theme.sheetMaskColor(),
      shadow: this.theme.sheetShadowOptions(),
      onDisappear: () => {
        this.showSheet = false
      }
    })

    if (this.busy) {
      this.ProgressOverlay()
    }
    }
    .width('100%')
    .height('100%')
    }
    .hideTitleBar(true)
    .backgroundColor(this.theme.background)
    .translate({ x: this.navTransX })
    .opacity(this.navAlpha)
    .customTransition((op: NavigationOperation, isEnter: boolean) => MotionHelper.navPageTransition(op, isEnter,
      (x: number, alpha: number) => {
        this.navTransX = x
        this.navAlpha = alpha
      }))
  }

  @Builder
  sheetBuilder() {
    SheetDialogView({
      theme: this.theme,
      config: this.sheetConfig,
      onTap: (index: number) => {
        this.showSheet = false
        this.sheetCallback(index)
      },
      onClose: () => {
        this.showSheet = false
      }
    })
  }
}
