import { ThemeColors } from 'common'
import { IconPickerService } from 'service'
import { common } from '@kit.AbilityKit'

/**
 * 列表 / 表单 logo 图。
 *
 * 渲染要点（避坑）：clip 和 shadow 必须分处两个元素，不能挂同一个：
 *  - Image 挂 borderRadius + clip(true)：把 favicon 位图裁成圆角（光 borderRadius
 *    不保证裁掉位图，方形图标会露出方角）。
 *  - 外层 Stack 挂 borderRadius + 背景色 + shadow、且不 clip：shadow 按圆角投射。
 *    若同一元素同时 clip(true) + shadow，clip 会把阴影按矩形裁切，四角漏黑。
 *
 * `inset`：favicon 是正方形图源会铺满整框贴到边缘，大尺寸（如表单 54vp）下
 * 尤其明显，加内边距让图标内缩成「图标卡」留白观感。列表小图（36vp）默认 0。
 *
 * http(s) 地址先经 IconPickerService 下载缓存为 file:// 再显示，避免直连远程失败。
 */
@Component
// 设计系统原子：跨模块复用 + onError 回调隔离，不宜降为 @Builder
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct LogoImage {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop @Watch('onUrlChange') url: string = ''
  @Prop logoSize: number = 36
  @Prop radius: number = 8
  /** 白框内图标内边距，默认 0（列表小图保持铺满） */
  @Prop inset: number = 0
  /** 裁切方式：方形 favicon 用 Cover；横向卡面图用 Contain / Fill 完整展示 */
  @Prop fit: ImageFit = ImageFit.Cover
  /**
   * 宽/高。默认 1 为正方形。
   * 卡面用 MotionTokens.cardFaceRatio（ID-1）；圆角用 cardFaceRadius，像实体卡而不是图标方块。
   * 命名注意：不能叫 aspectRatio，会与 CustomComponent 基类通用属性方法同名冲突（编译报 10505001）。
   */
  @Prop ratio: number = 1
  /** true：宽度铺满父级，高度由 ratio 决定（搜索结果网格） */
  @Prop fillWidth: boolean = false
  /** false：不加白底/描边；卡面圆角走 radius（实体卡），不是图标方块 */
  @Prop framed: boolean = true
  /** 远程 URL 为直连图资源时置 true：不做域名 favicon 多源兜底（避免取到站点 favicon 错图） */
  @Prop remoteExact: boolean = false
  /** 远程缓存文件前缀：卡面 card_face_ 与 app 图标 icon_net_ 隔离 */
  @Prop remotePrefix: string = 'icon_net_'
  /** 远程下载读取超时（ms）：卡面 PNG 较大需放宽 */
  @Prop remoteReadMs: number = 8000
  /** 加载失败回调，父组件置空 url 后会回退到文字头像 */
  onError?: () => void
  @State private displayUrl: string = ''
  private resolveSeq: number = 0

  aboutToAppear() {
    this.onUrlChange()
  }

  private onUrlChange(): void {
    this.resolveSeq++
    const seq = this.resolveSeq
    const src = this.url
    if (!src || src.length === 0) {
      this.displayUrl = ''
      return
    }
    if (!IconPickerService.isRemoteUrl(src)) {
      this.displayUrl = src
      return
    }
    this.resolveRemote(src, seq)
  }

  private async resolveRemote(src: string, seq: number): Promise<void> {
    try {
      const host = this.getUIContext().getHostContext()
      if (host === undefined || host === null) {
        if (seq === this.resolveSeq) {
          this.displayUrl = ''
          if (this.onError) {
            this.onError()
          }
        }
        return
      }
      const ctx = host as common.UIAbilityContext
      // 卡面原图直存（maxEdge=0）：缓存文件名不带 _e256 后缀，已落盘的卡面继续命中
      const local = this.remotePrefix === 'card_face_'
        ? await IconPickerService.resolveIconPath(
          ctx, src, this.remoteExact, this.remotePrefix, this.remoteReadMs, 0)
        : await IconPickerService.resolveIconPath(
          ctx, src, this.remoteExact, this.remotePrefix, this.remoteReadMs)
      if (seq !== this.resolveSeq) {
        return
      }
      if (local.length > 0) {
        this.displayUrl = local
      } else {
        this.displayUrl = ''
        if (this.onError) {
          this.onError()
        }
      }
    } catch (_e) {
      if (seq === this.resolveSeq) {
        this.displayUrl = ''
        if (this.onError) {
          this.onError()
        }
      }
    }
  }

  private boxWidth(): number {
    return this.logoSize * (this.ratio > 0 ? this.ratio : 1)
  }

  private decodeWidth(): number {
    return 512
  }

  private decodeHeight(): number {
    const ratio = this.ratio > 0 ? this.ratio : 1
    return Math.round(this.decodeWidth() / ratio)
  }

  build() {
    if (this.fillWidth) {
      this.faceFill()
    } else {
      this.iconBox()
    }
  }

  @Builder
  faceFill() {
    Stack() {
      if (this.displayUrl.length > 0) {
        Image(this.displayUrl)
          .width('100%')
          .height('100%')
          .borderRadius(this.radius)
          .clip(true)
          .objectFit(this.fit)
          .sourceSize({ width: this.decodeWidth(), height: this.decodeHeight() })
          .onError(() => {
            if (this.onError) {
              this.onError()
            }
          })
      }
    }
    .width('100%')
    .aspectRatio(this.ratio > 0 ? this.ratio : 1)
    .borderRadius(this.radius)
    .clip(false)
    .shadow(this.displayUrl.length > 0 ? this.theme.listLogoShadowOptions() : this.theme.noneShadowOptions())
  }

  @Builder
  iconBox() {
    Stack() {
      if (this.displayUrl.length > 0) {
        Image(this.displayUrl)
          .width(this.boxWidth() - 2 * this.inset)
          .height(this.logoSize - 2 * this.inset)
          .objectFit(this.fit)
          .onError(() => {
            if (this.onError) {
              this.onError()
            }
          })
      }
    }
    .width(this.boxWidth())
    .height(this.logoSize)
  }
}
