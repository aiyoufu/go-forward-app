import { TypeScale } from './WidgetTypeScale'

const W_BG: Resource = $r('app.color.widget_bg')
const W_TEXT: Resource = $r('app.color.widget_text')
const W_MUTED: Resource = $r('app.color.widget_muted')
const W_DIM: Resource = $r('app.color.widget_dim')
const W_BTN_BG: Resource = $r('app.color.widget_btn_bg')
const W_BTN_FG: Resource = $r('app.color.widget_btn_fg')
const W_RADIUS: number = 8

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
 * 本月待还 · 2×2
 * 上：标题 + 总额 + 清单；底：全宽「还款」铺满
 */
@Entry(storage)
@Component
struct MonthDueCard {
  @LocalStorageProp('amount') amount: string = '¥\u20090.00'
  @LocalStorageProp('hasData') hasData: boolean = false
  @LocalStorageProp('debtListPack') debtListPack: string = ''
  @LocalStorageProp('moreCount') moreCount: number = 0

  private amountText(): string {
    if (this.amount && this.amount.length > 0) {
      return this.amount
    }
    return '¥\u20090.00'
  }

  private segCount(): number {
    if (!this.debtListPack || this.debtListPack.length === 0) {
      return 0
    }
    const segs = this.debtListPack.split(';')
    let n = 0
    for (let i = 0; i < segs.length; i++) {
      if (segs[i].length > 0) {
        n++
      }
    }
    return n
  }

  private rowName(index: number): string {
    const segs = this.debtListPack.split(';')
    let seen = 0
    for (let i = 0; i < segs.length; i++) {
      if (segs[i].length === 0) {
        continue
      }
      if (seen === index) {
        const pair = segs[i].split('|')
        return pair.length > 0 ? pair[0] : ''
      }
      seen++
    }
    return ''
  }

  private rowAmt(index: number): string {
    const segs = this.debtListPack.split(';')
    let seen = 0
    for (let i = 0; i < segs.length; i++) {
      if (segs[i].length === 0) {
        continue
      }
      if (seen === index) {
        const pair = segs[i].split('|')
        return pair.length > 1 ? pair[1] : ''
      }
      seen++
    }
    return ''
  }

  private openDebts(action: string): void {
    postCardAction(this, {
      'action': 'router',
      'abilityName': 'EntryAbility',
      'params': {
        'fromWidget': true,
        'openTab': 1,
        'widgetAction': action
      } as RouterParams
    } as RouterAction)
  }

  @Builder
  dueRow(index: number) {
    Row() {
      Text(this.rowName(index))
        .fontSize(TypeScale.captionSm)
        .fontColor(W_MUTED)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
        .margin({ right: 6 })
      Text(this.rowAmt(index))
        .fontSize(TypeScale.captionSm)
        .fontFamily(TypeScale.FONT_MONO)
        .fontColor(W_TEXT)
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
        Text('本月待还')
          .fontSize(TypeScale.caption)
          .fontColor(W_MUTED)
          .width('100%')

        Text(this.amountText())
          .fontSize(TypeScale.display)
          .fontWeight(FontWeight.Bold)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor(W_TEXT)
          .letterSpacing(TypeScale.displaySpacing)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .margin({ top: 2 })

        // 金额与列表间距拉开
        Column()
          .width('100%')
          .height(12)

        if (this.segCount() > 0) {
          Column({ space: 3 }) {
            this.dueRow(0)
            if (this.segCount() > 1) {
              this.dueRow(1)
            }
            // 2×2 空间有限：最多 2 行 + 另有 N 笔，给底钮留位
            if (this.moreCount + Math.max(0, this.segCount() - 2) > 0) {
              Text('另有 ' + (this.moreCount + Math.max(0, this.segCount() - 2)) + ' 笔')
                .fontSize(TypeScale.captionSm)
                .fontColor(W_DIM)
                .width('100%')
            }
          }
          .width('100%')
          .alignItems(HorizontalAlign.Start)
        } else {
          Text(this.hasData ? '本月无分项待还' : '本月暂无待还')
            .fontSize(TypeScale.captionSm)
            .fontColor(W_DIM)
            .width('100%')
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .onClick(() => {
        this.openDebts('open')
      })

      // 底：全宽铺开「还款」
      Text('还款')
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
          this.openDebts('repay')
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
