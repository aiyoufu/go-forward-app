import { ThemeColors, TypeScale, MotionTokens, Utils, AppStorageKeys } from 'common'
import { SheetHeader, sheetBottomInset } from './SheetDialog'
import { LogoImage } from './LogoImage'
import { StatusTag } from './StatusTag'

/** 详情字段：label + value */
export class DetailField {
  label: string = ''
  value: string = ''

  constructor(label: string, value: string) {
    this.label = label
    this.value = value
  }
}

/**
 * 详情弹窗配置：由各页面在打开时构建
 * 负债 / 订阅 / 账户共用同一份概览信息卡片布局
 */
export class DetailSheetConfig {
  title: string = ''
  name: string = ''
  subtitle: string = ''
  /** 名称后紧贴的小标签（无分隔符），如信用卡尾号 */
  nameTag: string = ''
  /** 名称与尾号是否拆为两行（账户详情用：名称在上、尾号 pill 在下） */
  nameTagOnNewLine: boolean = false
  badgeText: string = ''
  /** 角标语义：ok 绿 / warn 琥珀 / danger 红 / off 灰（与列表 StatusTag 一致） */
  badgeRole: string = 'off'
  iconUrl: string = ''
  /** 是否为卡面 URL：仅用于 LogoImage 缓存前缀（卡面卡 face_ / 应用图标 icon_net_） */
  cardFace: boolean = false
  mark: string = ''
  markColor: string = '#2F3336'
  heroLabel: string = ''
  heroValue: string = ''
  heroUnit: string = ''
  fields: DetailField[] = []
  /**
   * 可选主操作文案（空则不渲染按钮）。
   * 负债详情：未结清时为「还款」；订阅/账户详情保持空。
   */
  primaryLabel: string = ''
}

/**
 * 统一详情底部弹窗：SheetHeader + 概览信息卡片
 * 卡片为月结小票风格（与 AIParsePreviewCard 同源，纸面统一 theme.paperBackground()）：
 * - 深色：压暗暖纸 + 深墨字（保留纸感，勿用深 surface，会像「深墨块」）
 * - 浅色：暖米纸 + 主题文本（相对白 sheet 可分）
 * 结构：单行身份 → 左对齐 mono 主指标 → 行式字段列表（标签左 / 值右，虚线分隔）
 */
@Component
export struct DetailSheetView {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop @Watch('onConfigChange') config: DetailSheetConfig = new DetailSheetConfig()
  onClose: () => void = () => {}
  /** 主操作点击（仅当 config.primaryLabel 非空时渲染按钮） */
  onPrimaryAction: () => void = () => {}
  /** 防窥脱敏态：系统检测到窥视时弹窗内名称/金额/日期等值打码（AntiPeekService 驱动） */
  @StorageProp(AppStorageKeys.ANTI_PEEK_MASKED) antiPeekMasked: boolean = false
  @State private iconFailed: boolean = false

  /**
   * 月结小票纸底：统一走 theme.paperBackground()
   * - 深/护眼：压暗暖纸 #E3DBC6（保留纸感，不刺眼）
   * - 浅色：暖米纸，相对白 sheet 抬升
   */
  private paperBackground(): ResourceColor {
    return this.theme.paperBackground()
  }

  /** 纸卡描边：统一走 theme.paperBorder() */
  private paperBorderColor(): ResourceColor {
    return this.theme.paperBorder()
  }

  /** 小票墨色（主）：米白纸固定深墨，浅色跟主题 */
  private inkPrimary(): ResourceColor {
    return this.theme.isDarkCanvas() ? '#26251E' : this.theme.text
  }

  /** 小票墨色（次） */
  private inkSecondary(): ResourceColor {
    return this.theme.isDarkCanvas() ? '#5C5A52' : this.theme.text2
  }

  /** 小票墨色（辅） */
  private inkTertiary(): ResourceColor {
    return this.theme.isDarkCanvas() ? '#858379' : this.theme.text3
  }

  /** 小票虚线：米白纸上的深色发丝 */
  private inkDivider(): ResourceColor {
    return this.theme.isDarkCanvas() ? 'rgba(40,30,20,0.14)' : this.theme.border
  }

  private onConfigChange(): void {
    this.iconFailed = false
  }

  private showLogo(): boolean {
    return this.config.iconUrl.length > 0 && !this.iconFailed
  }

  private isLastField(index: number): boolean {
    return index === this.config.fields.length - 1
  }

  /** 防窥脱敏：值类文本统一打码，标签/状态角标保留可读 */
  private masked(text: string): string {
    return Utils.maskIf(this.antiPeekMasked, text)
  }

  /** 小票式虚线分隔（顶部 dashed 发丝线，票据感） */
  @Builder
  receiptDivider() {
    Row()
      .width('100%')
      .height(1)
      .border({ width: { top: 1 }, color: this.inkDivider(), style: BorderStyle.Dashed })
  }

  build() {
    Column({ space: 0 }) {
      SheetHeader({
        theme: this.theme,
        title: this.config.title,
        onClose: () => {
          this.onClose()
        }
      })

      // 概览信息卡片
      Row() {
        Column() {
          // 身份行：Logo + 单行「名称 · 副题」+ 状态角标
          Row() {
            if (this.showLogo()) {
              LogoImage({
                theme: this.theme,
                url: this.config.iconUrl,
                logoSize: MotionTokens.listLogoSize,
                radius: MotionTokens.listLogoRadius,
                remoteExact: this.config.cardFace,
                remotePrefix: this.config.cardFace ? 'card_face_' : 'icon_net_',
                onError: () => {
                  this.iconFailed = true
                }
              })
                .margin({ right: 10 })
            } else {
              Column() {
                Text(this.config.mark)
                  .fontSize(this.config.mark.length > 1 ? 11 : 14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.onColorBlock())
              }
              .width(MotionTokens.listLogoSize)
              .height(MotionTokens.listLogoSize)
              .borderRadius(MotionTokens.listLogoRadius)
              .backgroundColor(this.config.markColor)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .margin({ right: 10 })
            }

            if (this.config.nameTagOnNewLine) {
              // 名称 + 尾号 pill 分两行（账户详情用）：名称在上、尾号 pill 居左
              // 列高与左侧 logo 卡片对齐（listLogoSize）
              Column({ space: 4 }) {
                Text(this.masked(this.config.name))
                  .fontSize(TypeScale.listPrimarySm)
                  .lineHeight(TypeScale.listPrimarySm)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.inkPrimary())
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')

                if (this.config.nameTag.length > 0) {
                  Text(this.masked(this.config.nameTag))
                    .fontSize(TypeScale.caption)
                    .lineHeight(TypeScale.caption)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.isDarkCanvas() ? `${this.theme.paperBackground()}` : '#FFFFFF')
                    .backgroundColor(this.inkPrimary())
                    .borderRadius(this.theme.radiusSm)
                    .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                    .maxLines(1)
                    .alignSelf(ItemAlign.Start)
                }
              }
              .layoutWeight(1)
              .height(MotionTokens.listLogoSize)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Start)
              .margin({ right: 8 })
            } else {
              // 默认布局：名称、尾号、副题挤在同一行（负债/订阅等共用）
              Row() {
                Text(this.masked(this.config.name))
                  .fontSize(TypeScale.listPrimarySm)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.inkPrimary())
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .flexShrink(1)

                if (this.config.nameTag.length > 0) {
                  Text(this.masked(this.config.nameTag))
                    .fontSize(TypeScale.caption)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.isDarkCanvas() ? `${this.theme.paperBackground()}` : '#FFFFFF')
                    .backgroundColor(this.inkPrimary())
                    .borderRadius(this.theme.radiusSm)
                    .padding({ left: 9, right: 9, top: 4, bottom: 4 })
                    .margin({ left: 8 })
                    .maxLines(1)
                    .flexShrink(0)
                }

                if (this.config.subtitle.length > 0) {
                  Text(' · ' + this.masked(this.config.subtitle))
                    .fontSize(TypeScale.caption)
                    .fontColor(this.inkTertiary())
                    .maxLines(1)
                    .flexShrink(0)
                }
              }
              .layoutWeight(1)
              .margin({ right: 8 })
              .alignItems(VerticalAlign.Center)
              .justifyContent(FlexAlign.Start)
            }

            if (this.config.badgeText.length > 0) {
              StatusTag({
                theme: this.theme,
                text: this.config.badgeText,
                role: this.config.badgeRole,
                onPaper: true
              })
            }
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          // 主指标：左对齐 mono 大数字
          Column({ space: 6 }) {
            Text(this.config.heroLabel)
              .fontSize(TypeScale.bodySm)
              .fontColor(this.inkSecondary())

            Row({ space: 4 }) {
              Text(this.antiPeekMasked ? Utils.MASK_AMOUNT : this.config.heroValue)
                .fontSize(TypeScale.heroNumber)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.inkPrimary())
                .fontFamily(TypeScale.FONT_MONO)
                .letterSpacing(TypeScale.heroNumberSpacing)
              if (this.config.heroUnit.length > 0 && !this.antiPeekMasked) {
                Text(this.config.heroUnit)
                  .fontSize(TypeScale.heroNumberSymbol)
                  .fontColor(this.inkTertiary())
                  .margin({ bottom: 5 })
              }
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .width('100%')
          .margin({ top: 20, bottom: 16 })
          .alignItems(HorizontalAlign.Start)

          this.receiptDivider()

          // 行式字段列表：标签左 / 值右，行间小票式虚线分隔
          Column({ space: 0 }) {
            ForEach(this.config.fields, (field: DetailField, index: number) => {
              Column({ space: 0 }) {
                Row() {
                  Text(field.label)
                    .fontSize(TypeScale.body)
                    .fontColor(this.inkTertiary())
                    .flexShrink(0)
                    .margin({ right: 16 })

                  Blank()

                  Text(this.masked(field.value))
                    .fontSize(TypeScale.body)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.inkSecondary())
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
                .width('100%')
                .padding({ top: 10, bottom: 10 })
                .alignItems(VerticalAlign.Center)

                if (!this.isLastField(index)) {
                  this.receiptDivider()
                }
              }
              .width('100%')
            }, (field: DetailField, index: number) => 'detail_field_' + index + '_' + field.label)
          }
          .width('100%')
        }
        .layoutWeight(1)
        .padding(this.theme.spaceSm)
        .backgroundColor(this.paperBackground())
        .borderRadius(this.theme.sheetCardRadius)
        .border({ width: 1, color: this.paperBorderColor() })
        // 米白小票在深/浅 sheet 上都用微弱阴影托轮廓
        .shadow(this.theme.elevatedShadowOptions())
      }
      .width('100%')
      .padding({ left: 24, right: 24 })
      // 与 SheetDialogView 内卡一致：底部留白，避免贴底
      .margin({ bottom: this.config.primaryLabel.length > 0 ? 0 : this.theme.spaceXs })

      // 主操作：反转块（对齐 DESIGN 主 CTA / RepaySheetView）
      if (this.config.primaryLabel.length > 0) {
        Row() {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text(this.config.primaryLabel)
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.ctaForeground())
          }
          .width('100%')
          .height(48)
          .backgroundColor(this.theme.ctaBackground())
          .onClick(() => {
            this.onPrimaryAction()
          })
        }
        .width('100%')
        .padding({ left: 24, right: 24 })
        .margin({ top: this.theme.spaceSm, bottom: this.theme.spaceXs })
      }
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    // 安全区 + 统一视觉间距（与全站底部弹窗底边对齐）
    .padding({ top: 0, bottom: sheetBottomInset() })
  }
}
