import { ThemeColors, ThemeManager, TypeScale } from 'common'
import { SheetHeader, sheetBottomInset } from './SheetDialog'
import { AppVersionService, VersionLogItem, FeatureItem, VersionReleaseInfo } from 'service'

/**
 * 设置 · 应用版本 / 功能特色与更新日志半模态
 * 
 * 核心逻辑：
 * 1. 首次安装：显示当前应用「特色功能」列表
 * 2. 版本号更新后：直接替换内容为「本次更新点」列表
 * 3. 动态获取：内容完全由 AppVersionService 动态拉取与缓存，不写死
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct SettingsVersionSheet {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop appVersion: string = '1.0.0'
  @Prop isFirstInstall: boolean = false
  @Prop isVersionUpdated: boolean = false
  
  onClose: () => void = () => {}

  @State isLoading: boolean = true
  @State isUpdatedContent: boolean = false
  @State featureItems: FeatureItem[] = []
  @State updateItems: VersionLogItem[] = []

  aboutToAppear() {
    this.loadReleaseData()
  }

  private async loadReleaseData(): Promise<void> {
    this.isLoading = true
    try {
      const info: VersionReleaseInfo = await AppVersionService.getReleaseInfo(this.appVersion)
      this.featureItems = info.features
      this.updateItems = info.releaseNotes

      // 判断内容显示类型：若为更新版本则展示更新点，否则展示特色功能
      if (this.isVersionUpdated || info.isVersionUpdated) {
        this.isUpdatedContent = true
      } else {
        this.isUpdatedContent = false
      }
    } catch (_e) {
      // 降级兜底
      this.featureItems = AppVersionService.getDynamicFeatures()
      this.updateItems = AppVersionService.getDynamicReleaseNotes(this.appVersion)
      this.isUpdatedContent = this.isVersionUpdated
    } finally {
      this.isLoading = false
    }
  }

  @Builder
  featuresList() {
    Column() {
      ForEach(this.featureItems, (item: FeatureItem, idx: number) => {
        Column() {
          if (idx > 0) {
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 16, right: 16 })
          }
          Row() {
            Column() {
              Text(item.title)
                .fontSize(TypeScale.control)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.text)
                .margin({ bottom: 4 })
              Text(item.desc)
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text2)
                .lineHeight(18)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
      }, (item: FeatureItem, idx: number) => `feat_${idx}_${item.title}`)
    }
    .width('100%')
  }

  @Builder
  updatesList() {
    Column() {
      ForEach(this.updateItems, (item: VersionLogItem, idx: number) => {
        Column() {
          if (idx > 0) {
            Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 16, right: 16 })
          }
          Row() {
            Column() {
              Row({ space: 6 }) {
                Text(item.title)
                  .fontSize(TypeScale.control)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.text)
                
                if (item.tag && item.tag.length > 0) {
                  Text(item.tag)
                    .fontSize(TypeScale.captionSm)
                    .fontColor(this.theme.primary)
                    .backgroundColor(this.theme.chip)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .borderRadius(this.theme.radiusSm)
                }
              }
              .margin({ bottom: 4 })

              Text(item.desc)
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text2)
                .lineHeight(18)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        }
      }, (item: VersionLogItem, idx: number) => `upd_${idx}_${item.title}`)
    }
    .width('100%')
  }

  build() {
    Column({ space: 0 }) {
      SheetHeader({
        theme: this.theme,
        title: '应用版本',
        subtitle: '',
        onClose: () => {
          this.onClose()
        }
      })

      Row({ space: 8 }) {
        Text(this.isUpdatedContent ? '本次更新' : '特色功能')
          .fontSize(TypeScale.control)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.text2)

        Text(this.appVersion.startsWith('v') ? this.appVersion : ('v' + this.appVersion))
          .fontSize(TypeScale.captionSm)
          .fontColor(this.theme.text2)
          .backgroundColor(this.theme.chip)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .borderRadius(this.theme.radiusSm)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .padding({ left: 24, right: 24, bottom: 8 })

      // 内容区域：首次安装展示特色功能，版本更新后直接替换为更新点
      Column() {
        if (this.isLoading) {
          Column() {
            LoadingProgress()
              .width(28)
              .height(28)
              .color(this.theme.text)
          }
          .width('100%')
          .height(180)
          .justifyContent(FlexAlign.Center)
        } else {
          Scroll() {
            if (this.isUpdatedContent) {
              this.updatesList()
            } else {
              this.featuresList()
            }
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: 240 })
        }
      }
      .backgroundColor(this.theme.sheetItemBackground())
      .borderRadius(this.theme.sheetCardRadius)
      .border({ width: 1, color: this.theme.borderStrong })
      .clip(true)
      .margin({ left: 24, right: 24 })

      // 底部操作按钮
      Row() {
        Button('我知道了')
          .width('100%')
          .height(48)
          .backgroundColor(this.theme.ctaBackground())
          .fontColor(this.theme.ctaForeground())
          .fontWeight(FontWeight.Medium)
          .borderRadius(this.theme.sheetCardRadius)
          .onClick(() => {
            this.onClose()
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 20, bottom: 8 })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ bottom: sheetBottomInset(24) })
  }
}
