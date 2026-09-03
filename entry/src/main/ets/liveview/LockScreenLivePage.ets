import { TypeScale } from 'common'
import { ColorTokens } from 'common'
import {
  LiveLockPayload,
  LIVE_LOCK_STORAGE_KEY
} from 'service'

/**
 * 锁屏沉浸实况窗 UI（还款提醒）
 * 对齐 bpta-lock-screen-immersive-live-window：独立 Extension 进程内渲染
 */
@Entry
@Component
struct LockScreenLivePage {
  @StorageLink(LIVE_LOCK_STORAGE_KEY) @Watch('onPayload') payload: LiveLockPayload =
    LiveLockPayload.empty()
  @State private title: string = '还款提醒'
  @State private summary: string = ''
  @State private line1: string = ''
  @State private line2: string = ''
  @State private moreText: string = ''
  @State private accent: string = `${ColorTokens.PRIMARY}`
  @State private statusCode: number = 0

  aboutToAppear(): void {
    this.applyPayload(this.payload)
  }

  private onPayload(): void {
    this.applyPayload(this.payload)
  }

  private applyPayload(p: LiveLockPayload): void {
    if (!p || p.title.length === 0) {
      this.title = '还款提醒'
      this.summary = '暂无紧急还款'
      this.line1 = ''
      this.line2 = ''
      this.moreText = ''
      this.accent = `${ColorTokens.PRIMARY}`
      this.statusCode = 0
      return
    }
    this.title = p.title
    this.summary = p.summary
    this.line1 = p.line1
    this.line2 = p.line2
    this.moreText = p.moreText
    this.accent = p.accentColor.length > 0 ? p.accentColor : `${ColorTokens.PRIMARY}`
    this.statusCode = p.status
  }

  private statusLabel(): string {
    if (this.statusCode === 2) {
      return '逾期'
    }
    if (this.statusCode === 1) {
      return '今日'
    }
    if (this.statusCode === 3) {
      return '本周'
    }
    return '提醒'
  }

  build() {
    Column() {
      Row() {
        Text(this.statusLabel())
          .fontSize(TypeScale.caption)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2F1EF')
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor(this.accent)
          .borderRadius(4)
        Blank()
        Text('向前 · 待还')
          .fontSize(TypeScale.kicker)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor('rgba(237,236,236,0.55)')
          .letterSpacing(TypeScale.kickerSpacing)
      }
      .width('100%')
      .margin({ bottom: 16 })

      Text(this.title)
        .fontSize(TypeScale.heroTitle)
        .fontWeight(FontWeight.Bold)
        .fontColor('#F2F1EF')
        .width('100%')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      if (this.summary.length > 0) {
        Text(this.summary)
          .fontSize(TypeScale.sectionNumber)
          .fontWeight(FontWeight.Medium)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor(this.accent)
          .margin({ top: 8 })
          .width('100%')
      }

      if (this.line1.length > 0 || this.line2.length > 0) {
        Column({ space: 10 }) {
          if (this.line1.length > 0) {
            Text(this.line1)
              .fontSize(TypeScale.body)
              .fontColor('rgba(237,236,236,0.88)')
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.line2.length > 0) {
            Text(this.line2)
              .fontSize(TypeScale.body)
              .fontColor('rgba(237,236,236,0.88)')
              .width('100%')
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          if (this.moreText.length > 0) {
            Text(this.moreText)
              .fontSize(TypeScale.caption)
              .fontColor('rgba(237,236,236,0.5)')
              .width('100%')
          }
        }
        .width('100%')
        .margin({ top: 20 })
        .padding(14)
        .backgroundColor('rgba(237,236,236,0.08)')
        .borderRadius(8)
        .border({ width: 0.5, color: 'rgba(237,236,236,0.12)' })
      }

      Blank()

      Text('点按胶囊可返回应用查看详情')
        .fontSize(TypeScale.captionSm)
        .fontColor('rgba(237,236,236,0.4)')
        .width('100%')
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24, top: 28, bottom: 24 })
    .justifyContent(FlexAlign.Start)
    .alignItems(HorizontalAlign.Start)
    .backgroundColor('#0C0B09')
  }
}
