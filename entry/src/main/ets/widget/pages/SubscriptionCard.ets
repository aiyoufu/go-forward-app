import { TypeScale } from './WidgetTypeScale'

const W_BG: Resource = $r('app.color.widget_bg')
const W_TEXT: Resource = $r('app.color.widget_text')
const W_MUTED: Resource = $r('app.color.widget_muted')
const W_DIM: Resource = $r('app.color.widget_dim')
const W_BTN_BG: Resource = $r('app.color.widget_btn_bg')
const W_BTN_FG: Resource = $r('app.color.widget_btn_fg')
const W_TAG_OK_FG: Resource = $r('app.color.widget_tag_ok_fg')
const W_TAG_OK_BG: Resource = $r('app.color.widget_tag_ok_bg')
const W_TAG_WARN_FG: Resource = $r('app.color.widget_tag_warn_fg')
const W_TAG_WARN_BG: Resource = $r('app.color.widget_tag_warn_bg')
const W_TAG_OFF_FG: Resource = $r('app.color.widget_tag_off_fg')
const W_TAG_OFF_BG: Resource = $r('app.color.widget_tag_off_bg')
const W_RADIUS: number = 8
const W_CHIP_RADIUS: number = 4

interface RouterParams {
  fromWidget: boolean
  openTab: number
  widgetAction: string
}

interface RouterAction {
  action: string
  abilityName: string
  params: RouterParams
}

let storage = new LocalStorage()

/**
 * 订阅 · 2×2
 * 上：标题 + 生效数 + 清单（到期日期/状态，不展示金额）；底：全宽「看订阅」铺满
 */
@Entry(storage)
@Component
struct SubscriptionCard {
  @LocalStorageProp('activeSubs') activeSubs: number = 0
  @LocalStorageProp('hasData') hasData: boolean = false
  @LocalStorageProp('subListPack') subListPack: string = ''
  @LocalStorageProp('moreCount') moreCount: number = 0

  private countText(): string {
    if (this.activeSubs > 0) {
      return '' + this.activeSubs
    }
    return '0'
  }

  /** 状态彩色 tag：生效中绿、暂停琥珀、已取消灰 */
  private tagFg(text: string): Resource {
    if (text === '生效中') {
      return W_TAG_OK_FG
    }
    if (text === '暂停') {
      return W_TAG_WARN_FG
    }
    return W_TAG_OFF_FG
  }

  private tagBg(text: string): Resource {
    if (text === '生效中') {
      return W_TAG_OK_BG
    }
    if (text === '暂停') {
      return W_TAG_WARN_BG
    }
    return W_TAG_OFF_BG
  }

  private segCount(): number {
    if (!this.subListPack || this.subListPack.length === 0) {
      return 0
    }
    const segs = this.subListPack.split(';')
    let n = 0
    for (let i = 0; i < segs.length; i++) {
      if (segs[i].length > 0) {
        n++
      }
    }
    return n
  }

  private rowField(index: number, field: number): string {
    const segs = this.subListPack.split(';')
    let seen = 0
    for (let i = 0; i < segs.length; i++) {
      if (segs[i].length === 0) {
        continue
      }
      if (seen === index) {
        const parts = segs[i].split('|')
        return parts.length > field ? parts[field] : ''
      }
      seen++
    }
    return ''
  }

  private openSubscriptions(): void {
    postCardAction(this, {
      'action': 'router',
      'abilityName': 'EntryAbility',
      'params': {
        'fromWidget': true,
        'openTab': 2,
        'widgetAction': 'open'
      } as RouterParams
    } as RouterAction)
  }

  @Builder
  subRow(index: number) {
    Row() {
      Text(this.rowField(index, 0))
        .fontSize(TypeScale.captionSm)
        .fontColor(W_MUTED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ right: 6 })
      Text(this.rowField(index, 1))
        .fontSize(TypeScale.captionSm)
        .fontFamily(TypeScale.FONT_MONO)
        .fontColor(W_TEXT)
        .maxLines(1)
        .flexShrink(0)
        .margin({ right: 6 })
      Text(this.rowField(index, 2))
        .fontSize(TypeScale.captionSm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.tagFg(this.rowField(index, 2)))
        .backgroundColor(this.tagBg(this.rowField(index, 2)))
        .borderRadius(W_CHIP_RADIUS)
        .padding({ left: 5, right: 5, top: 1, bottom: 1 })
        .maxLines(1)
        .flexShrink(0)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Column() {
      // 上：信息区
      Column() {
        Text('订阅')
          .fontSize(TypeScale.caption)
          .fontColor(W_MUTED)
          .width('100%')

        // 生效数代替月支出金额
        Row({ space: 4 }) {
          Text(this.countText())
            .fontSize(TypeScale.display)
            .fontWeight(FontWeight.Bold)
            .fontFamily(TypeScale.FONT_MONO)
            .fontColor(W_TEXT)
            .letterSpacing(TypeScale.displaySpacing)
            .maxLines(1)
          Text('项生效中')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_MUTED)
            .margin({ bottom: 3 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)
        .margin({ top: 2 })

        // 生效数与列表间距拉开
        Column()
          .width('100%')
          .height(12)

        if (this.segCount() > 0) {
          Column({ space: 3 }) {
            this.subRow(0)
            if (this.segCount() > 1) {
              this.subRow(1)
            }
            // 2×2 空间有限：最多 2 行 + 另有 N 项，给底钮留位
            if (this.moreCount + Math.max(0, this.segCount() - 2) > 0) {
              Text('另有 ' + (this.moreCount + Math.max(0, this.segCount() - 2)) + ' 项')
                .fontSize(TypeScale.captionSm)
                .fontColor(W_DIM)
                .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        } else {
          Text('暂无订阅')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_DIM)
            .width('100%')
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openSubscriptions()
      })

      // 底：全宽铺开「看订阅」
      Text('看订阅')
        .fontSize(TypeScale.bodySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(W_BTN_FG)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 9, bottom: 9 })
        .backgroundColor(W_BTN_BG)
        .borderRadius(W_RADIUS)
        .margin({ top: 8 })
        .onClick(() => {
          this.openSubscriptions()
        })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 12 })
    .backgroundColor(W_BG)
    .borderRadius(W_RADIUS)
    .clip(true)
  }
}
