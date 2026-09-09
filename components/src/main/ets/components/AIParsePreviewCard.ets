import { ThemeColors, ThemeManager, TypeScale, MotionTokens } from 'common'

/**
 * AI Live 确认态预览卡（单卡汇总，非分散字段列表）
 * - 图标：优先已有账户 icon_url / 品牌 logo，失败回退字标
 * - 信息：标题 + 金额 + meta 一行汇总（期数/月供/出单日等）
 * 纸面统一 theme.paperBackground()：浅色暖米纸、深色压暗暖纸（月结小票）
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct AIParsePreviewCard {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop title: string = ''
  @Prop amountText: string = ''
  @Prop metaLine: string = ''
  @Prop mark: string = ''
  @Prop avatarColor: string = '#2F3336'
  /** 真实 logo / 已有账户 icon_url；空则只显示字标 */
  @Prop @Watch('onIconUrlChange') iconUrl: string = ''
  /** 类型角标：负债 / 订阅 / 信用账户 */
  @Prop typeLabel: string = ''
  /**
   * 智感握姿：主操作（完整编辑）是否靠主手一侧
   * true=左手布局 tag 在左；false=右手布局 tag 在右
   */
  @Prop leftPrimary: boolean = false
  /** 完整编辑：卡内次角 tag，与底栏「保存」分离防误触 */
  onFullEdit: () => void = () => {}
  @State private iconFailed: boolean = false

  private paperBackground(): ResourceColor {
    return this.theme.paperBackground()
  }

  private paperBorder(): ResourceColor {
    return this.theme.paperBorder()
  }

  private inkPrimary(): ResourceColor {
    return this.theme.isDarkCanvas() ? '#26251E' : this.theme.text
  }

  private inkSecondary(): ResourceColor {
    return this.theme.isDarkCanvas() ? '#5C5A52' : this.theme.text2
  }

  private inkDivider(): ResourceColor {
    return this.theme.isDarkCanvas() ? 'rgba(40,30,20,0.14)' : this.theme.border
  }

  private showLogo(): boolean {
    return this.iconUrl.length > 0 && !this.iconFailed
  }

  private onIconUrlChange(): void {
    this.iconFailed = false
  }

  aboutToAppear(): void {
    this.iconFailed = false
  }

  @Builder
  receiptDivider() {
    Row()
      .width('100%')
      .height(1)
      .margin({ top: 10, bottom: 2 })
      .border({ width: { top: 1 }, color: this.inkDivider(), style: BorderStyle.Dashed })
  }

  /** 类型 tag 底：米白纸上略深一档，像 chip */
  private typeTagBackground(): ResourceColor {
    return this.theme.isDarkCanvas() ? 'rgba(38,37,30,0.08)' : 'rgba(38,37,30,0.06)'
  }

  @Builder
  fullEditTag() {
    Text('完整编辑')
      .fontSize(TypeScale.caption)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.inkSecondary())
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(this.typeTagBackground())
      .borderRadius(this.theme.radiusSm)
      .border({ width: 1, color: this.paperBorder() })
      .onClick(() => {
        this.onFullEdit()
      })
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 12 }) {
        // 账户图标：已有账户 logo → 品牌 favicon → 字标
        Stack() {
          Column() {
            Text(this.mark.length > 0 ? this.mark : '·')
              .fontSize(this.mark.length > 1 ? 12 : 15)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.onColorBlock())
          }
          .width(MotionTokens.listLogoSize)
          .height(MotionTokens.listLogoSize)
          .borderRadius(MotionTokens.listLogoRadius)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor(this.avatarColor)

          if (this.showLogo()) {
            Image(this.iconUrl)
              .width(MotionTokens.listLogoSize)
              .height(MotionTokens.listLogoSize)
              .objectFit(ImageFit.Cover)
              .onError(() => {
                this.iconFailed = true
              })
          }
        }

        Column({ space: 4 }) {
          // 标题行：名称 + 类型 tag（负债 / 订阅 / 信用账户）
          Row({ space: 8 }) {
            Text(this.title.length > 0 ? this.title : '未知')
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.inkPrimary())
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)

            if (this.typeLabel.length > 0) {
              Text(this.typeLabel)
                .fontSize(TypeScale.caption)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.inkSecondary())
                .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                .backgroundColor(this.typeTagBackground())
                .borderRadius(this.theme.radiusSm)
                .border({ width: 1, color: this.paperBorder() })
                .flexShrink(0)
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (this.amountText.length > 0) {
            Text(this.amountText)
              .fontSize(TypeScale.listPrimarySm)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.inkPrimary())
              .fontFamily(TypeScale.FONT_MONO)
              .width('100%')
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      // 识别信息汇总进卡内（一期元数据），不再拆成下方多行表单
      if (this.metaLine.length > 0) {
        this.receiptDivider()
        Text(this.metaLine)
          .fontSize(TypeScale.bodySm)
          .fontColor(this.inkSecondary())
          .margin({ top: 8 })
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      // 完整编辑：握姿镜像——左手主操作在左，右手在右
      this.receiptDivider()
      Row() {
        if (this.leftPrimary) {
          this.fullEditTag()
          Blank()
        } else {
          Blank()
          this.fullEditTag()
        }
      }
      .width('100%')
      .margin({ top: 10 })
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor(this.paperBackground())
    .borderRadius(this.theme.radiusLg)
    .border({ width: 1, color: this.paperBorder() })
  }
}
