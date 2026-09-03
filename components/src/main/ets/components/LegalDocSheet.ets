import { ThemeColors, TypeScale } from 'common'
import { LegalDocuments, LegalDocKind } from 'common'
import { SheetHeader, sheetBottomInset } from './SheetDialog'

/**
 * 隐私政策 / 用户协议 · 底部半模态内容
 * 替代独立 LegalPage 跳转，登录/注册/设置共用
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct LegalDocSheet {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop kind: string = 'privacy'
  onClose: () => void = () => {}

  private resolveKind(): LegalDocKind {
    return this.kind === 'terms' ? 'terms' : 'privacy'
  }

  private titleText(): string {
    return LegalDocuments.title(this.resolveKind())
  }

  private bodyText(): string {
    return LegalDocuments.body(this.resolveKind())
  }

  build() {
    Column() {
      SheetHeader({
        theme: this.theme,
        title: this.titleText(),
        onClose: () => {
          this.onClose()
        }
      })

      Scroll() {
        Text(this.bodyText())
          .fontSize(TypeScale.body)
          .fontColor(this.theme.text2)
          .lineHeight(22)
          .width('100%')
          .padding({ left: 24, right: 24, bottom: sheetBottomInset(28) })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Auto)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
  }
}
