import { LengthMetrics } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { MotionTokens, ThemeColors, TypeScale, Constants } from 'common'
import { IconPickerService, IconCloudService, AuthManager } from 'service'
import { LogoImage } from './LogoImage'
import { IconPickerSheet } from './IconPickerSheet'

/**
 * 三表单页（负债/订阅/信用账户）公共图标头像段：
 * 真实 logo / 首字色块 / 相册中性占位 + 右下角编辑笔，点击唤起图标选择 sheet。
 * 图标上传与云同步也收在此处；父页只持有 iconUrl/iconFailed 并负责展示 URL 推导
 * （负债页含关联账户接管逻辑，推导规则不同）。
 */
@Component
export struct FormLogoHeader {
  @Prop theme: ThemeColors = new ThemeColors()
  /** 名称/平台名：非空时展示首字色块并作为标题，空时相册占位 + 标题占位文案 */
  @Prop displayName: string = ''
  /** 展示用标题占位：如「账户名称」「订阅名称」「平台名称」 */
  @Prop titleText: string = ''
  /** 图标下方提示文案 */
  @Prop hintText: string = ''
  /** 首字色块文字（父页按品牌视觉推导，可为多字） */
  @Prop markChar: string = ''
  /** 首字色块底色（空名时统一中性深灰） */
  @Prop markColor: string = '#2F3336'
  /** 解析后的展示图标 URL（自定义 > 关联账户 > 平台预设，由父页推导） */
  @Prop displayUrl: string = ''
  /** 图标云同步桶：Constants.TABLE_* */
  bucketTable: string = ''
  /** 图标选择数据源：'app' 应用图标（负债/订阅）；'card' 银行卡卡面（信用账户） */
  @Prop pickerCatalog: string = 'app'
  /** 是否显示右下角编辑笔角标（新建页提示可点选；编辑页不展示） */
  @Prop showEditBadge: boolean = true
  @Link iconUrl: string
  @Link iconFailed: boolean

  @State private showPicker: boolean = false
  @State private historyIcons: string[] = []

  /** 当前数据源的落盘前缀：卡面 card_face_ / app 图标 icon_，历史与相册共用 */
  private filePrefix(): string {
    return this.pickerCatalog === 'card' ? 'card_face_' : 'icon_'
  }

  private async pickAndUploadIcon(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const path = await IconPickerService.pickAndCopyFromAlbum(ctx, this.filePrefix())
    if (path.length > 0) {
      IconPickerService.recordPickedIcon(ctx, path)
      this.iconUrl = path
      this.iconFailed = false
      await this.uploadLocalIconIfNeeded(path)
    }
  }

  private async uploadLocalIconIfNeeded(path: string): Promise<void> {
    if (!IconCloudService.needsUpload(path)) {
      return
    }
    const session = await AuthManager.loadSession()
    if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return
    }
    const remote = await IconCloudService.ensureRemoteUrl(
      path, IconCloudService.bucketForTable(this.bucketTable), session.userId, session.accessToken
    )
    if (remote.length > 0 && remote !== path) {
      this.iconUrl = remote
    }
  }

  private openIconPicker(): void {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    // 信用账户历史里混存两类：卡面 card_face_ + 信贷平台圆标 icon_net_
    this.historyIcons = this.pickerCatalog === 'card'
      ? IconPickerService.listHistoryIcons(ctx, this.filePrefix(), ['icon_net_'])
      : IconPickerService.listHistoryIcons(ctx, this.filePrefix())
    this.showPicker = true
  }

  build() {
    Column() {
      Row() {
        Stack({ alignContent: Alignment.BottomEnd }) {
          // 有 logo 时不再垫字母色块：radiusSm 比 formLogoRadius 尖，四角会透色
          if (this.displayUrl.length > 0 && !this.iconFailed) {
            LogoImage({
              theme: this.theme,
              url: this.displayUrl,
              logoSize: 54,
              inset: 5,
              radius: MotionTokens.formLogoRadius,
              remoteExact: this.pickerCatalog === 'card',
              remotePrefix: this.pickerCatalog === 'card' ? 'card_face_' : 'icon_net_',
              remoteReadMs: 8000,
              onError: () => {
                this.iconFailed = true
              }
            })
          } else {
            Column() {
              if (this.displayName.length > 0) {
                Text(this.markChar)
                  .fontSize(this.markChar.length > 1 ? TypeScale.sectionTitle : TypeScale.display)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.onColorBlock())
              } else {
                // 未选择：三表单页统一中性占位（相册图形），不用文字
                Image($r('app.media.ic_album'))
                  .width(22)
                  .height(22)
                  .fillColor(this.theme.onColorBlock())
              }
            }
            .width(54)
            .height(54)
            .borderRadius(MotionTokens.formLogoRadius)
            .backgroundColor(this.displayName.length > 0 ? this.markColor : '#2F3336')
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
          }

          // 右下角编辑笔图标（仅新建页展示，编辑页不重复提示）
          if (this.showEditBadge) {
            Column() {
              Image($r('app.media.ic_edit'))
                .width(10)
                .height(10)
                .fillColor(this.theme.onPrimary)
            }
            .width(18)
            .height(18)
            .borderRadius(this.theme.radiusSm)
            .backgroundColor(this.theme.primary)
            .justifyContent(FlexAlign.Center)
            .alignItems(HorizontalAlign.Center)
            .offset({ x: 4, y: 4 })
            .border({ width: 1.5, color: this.theme.background })
          }
        }
        .width(54)
        .height(54)
        .onClick(() => {
          this.openIconPicker()
        })

        Column({ space: 4 }) {
          Text(this.displayName.length > 0 ? this.displayName : this.titleText)
            .fontSize(TypeScale.listPrimarySm)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.text)
          Text(this.hintText)
            .fontSize(TypeScale.caption)
            .fontColor(this.theme.text3)
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16 })
      }
      .width('100%')
      .padding({ left: 4, right: 4 })
    }
    .width('100%')
    .margin({ bottom: 12 })
    .bindSheet($$this.showPicker, this.iconPickerBuilder, {
      height: SheetSize.MEDIUM,
      dragBar: true,
      radius: LengthMetrics.vp(this.theme.sheetRadius),
      showClose: false,
      backgroundColor: this.theme.sheetBackground() as string,
      blurStyle: BlurStyle.NONE,
      maskColor: this.theme.sheetMaskColor(),
      shadow: this.theme.sheetShadowOptions(),
      onDisappear: () => {
        this.showPicker = false
      }
    })
  }

  @Builder
  iconPickerBuilder() {
    IconPickerSheet({
      theme: this.theme,
      historyIcons: this.historyIcons,
      catalog: this.pickerCatalog,
      onPick: (path: string) => {
        this.showPicker = false
        this.iconUrl = path
        this.iconFailed = false
        const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
        IconPickerService.recordPickedIcon(ctx, path)
        this.uploadLocalIconIfNeeded(path)
      },
      onAlbum: () => {
        this.showPicker = false
        this.pickAndUploadIcon()
      },
      onCancel: () => {
        this.showPicker = false
      }
    })
  }
}
