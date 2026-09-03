import {
  ThemeColors, ThemeManager, TypeScale,
  AppStorageKeys, AppRouter, RouteNames,
  AppToast, ErrorMessages, MotionHelper, ImmersiveTitleBar,
  MotionTokens
} from 'common'
import { ProfileService, UserService } from 'service'
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit'
import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'

/** 路由参数：相册选图的临时 uri */
export interface AvatarCropParams {
  uri?: string
}

/** 双指缩放上限（相对铺满取景框的倍数） */
const ZOOM_MAX: number = 4
/** 双击切换的目标倍率（1x ↔ 2x），鼠标/模拟器无多指时的缩放途径 */
const ZOOM_DOUBLE: number = 2
/** 三分参考线：白色半透明叠在图片上，配暗色投影保证亮图下仍可辨 */
const GRID_LINE_COLOR: string = '#80FFFFFF'
const GRID_LINE_SHADOW: ShadowOptions = { radius: 1.5, color: '#66000000', offsetX: 0, offsetY: 0 }
/** 取景外框 */
const FRAME_COLOR: string = '#66FFFFFF'
/** 圆形头像参考环 */
const RING_COLOR: string = '#99FFFFFF'

/**
 * 头像裁剪编辑页：拖动平移 + 双指缩放，方形取景输出。
 * 确认后经 ProfileService.saveCroppedAvatar 缩放到固定边长落盘并同步云端。
 */
@Component
export struct AvatarCropPage {
  @State theme: ThemeColors = ThemeManager.DARK
  @State srcPixelMap: image.PixelMap | null = null
  @State srcW: number = 0
  @State srcH: number = 0
  /** 取景框实际边长（vp），onAreaChange 测得后再渲染图片 */
  @State boxSize: number = 0
  @State zoom: number = 1
  @State offX: number = 0
  @State offY: number = 0
  @State processing: boolean = false
  @State loadFailed: boolean = false
  private panBaseX: number = 0
  private panBaseY: number = 0
  private pinchBase: number = 1
  /** 双指捏合进行中：期间抑制单指拖动，避免两套手势互抢抖动 */
  private pinchActive: boolean = false

  /** 页转场位移/透明度（MotionHelper.navPageTransition 驱动） */
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  aboutToAppear(): void {
    const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? true
    this.theme = systemDark ? ThemeManager.DARK : ThemeManager.LIGHT
    this.loadSource()
  }

  private async loadSource(): Promise<void> {
    const params = AppRouter.peekParam(RouteNames.AVATAR_CROP) as AvatarCropParams
    const uri = params?.uri ?? ''
    if (uri.length === 0) {
      this.loadFailed = true
      return
    }
    const pm = await ProfileService.loadEditableAvatarPixelMap(uri)
    if (pm === null) {
      this.loadFailed = true
      return
    }
    const info = await pm.getImageInfo()
    if (info === undefined || info === null || info.size === undefined) {
      this.loadFailed = true
      return
    }
    this.srcW = info.size.width
    this.srcH = info.size.height
    this.srcPixelMap = pm
  }

  // —— 取景几何：图片按 cover 铺满取景框，再乘缩放倍数 ——

  private dispScale(): number {
    if (this.boxSize <= 0 || this.srcW <= 0 || this.srcH <= 0) {
      return 0
    }
    const cover = Math.max(this.boxSize / this.srcW, this.boxSize / this.srcH)
    return cover * this.zoom
  }

  private dispW(): number {
    return this.srcW * this.dispScale()
  }

  private dispH(): number {
    return this.srcH * this.dispScale()
  }

  private clampOffsets(): void {
    const mx = Math.max(0, (this.dispW() - this.boxSize) / 2)
    const my = Math.max(0, (this.dispH() - this.boxSize) / 2)
    let x = this.offX
    let y = this.offY
    if (x < -mx) {
      x = -mx
    }
    if (x > mx) {
      x = mx
    }
    if (y < -my) {
      y = -my
    }
    if (y > my) {
      y = my
    }
    this.offX = x
    this.offY = y
  }

  private setOffset(x: number, y: number): void {
    this.offX = x
    this.offY = y
    this.clampOffsets()
  }

  private setZoom(z: number): void {
    let nz = z
    if (nz < 1) {
      nz = 1
    }
    if (nz > ZOOM_MAX) {
      nz = ZOOM_MAX
    }
    this.zoom = nz
    this.clampOffsets()
  }

  /** 把取景框映射回源图像素区域，裁剪并落盘同步 */
  private async confirmCrop(): Promise<void> {
    const pm = this.srcPixelMap
    if (this.processing || pm === null || this.boxSize <= 0 || this.srcW <= 0 || this.srcH <= 0) {
      return
    }
    const k = this.dispScale()
    if (k <= 0) {
      return
    }
    this.processing = true
    try {
      const limitSide = Math.min(this.srcW, this.srcH)
      let side = Math.floor(this.boxSize / k)
      if (side < 8) {
        side = 8
      }
      if (side > limitSide) {
        side = limitSide
      }
      const ix = (this.boxSize - this.dispW()) / 2 + this.offX
      const iy = (this.boxSize - this.dispH()) / 2 + this.offY
      let sx = Math.round(-ix / k)
      let sy = Math.round(-iy / k)
      if (sx < 0) {
        sx = 0
      }
      if (sy < 0) {
        sy = 0
      }
      if (sx > this.srcW - side) {
        sx = this.srcW - side
      }
      if (sy > this.srcH - side) {
        sy = this.srcH - side
      }
      const region: image.Region = { x: sx, y: sy, size: { width: side, height: side } }
      await pm.crop(region)
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      const ok = await ProfileService.saveCroppedAvatar(ctx, UserService.getCurrentUserId(), pm)
      if (ok) {
        AppStorage.setOrCreate(AppStorageKeys.PROFILE_REVISION, Date.now())
        AppToast.show(ErrorMessages.UPDATE_OK, 1500)
        AppRouter.pop()
      } else {
        AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      }
    } catch (_e) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    } finally {
      this.processing = false
    }
  }

  build() {
    NavDestination() {
      HdsNavigation() {
        Column() {
          // 裁剪区：占满剩余空间居中，方形取景框
          Column() {
            if (this.loadFailed) {
              Text('图片读取失败，请更换图片后重试')
                .fontSize(TypeScale.body)
                .fontColor(this.theme.text3)
            } else {
              Stack() {
                if (this.boxSize > 0 && this.srcPixelMap !== null) {
                  Image(this.srcPixelMap)
                    .width(this.dispW())
                    .height(this.dispH())
                    .objectFit(ImageFit.Fill)
                    .translate({ x: this.offX, y: this.offY })
                  Column()
                    .width(1)
                    .height('100%')
                    .backgroundColor(GRID_LINE_COLOR)
                    .shadow(GRID_LINE_SHADOW)
                    .position({ x: this.boxSize / 3, y: 0 })
                  Column()
                    .width(1)
                    .height('100%')
                    .backgroundColor(GRID_LINE_COLOR)
                    .shadow(GRID_LINE_SHADOW)
                    .position({ x: this.boxSize * 2 / 3, y: 0 })
                  Row()
                    .height(1)
                    .width('100%')
                    .backgroundColor(GRID_LINE_COLOR)
                    .shadow(GRID_LINE_SHADOW)
                    .position({ x: 0, y: this.boxSize / 3 })
                  Row()
                    .height(1)
                    .width('100%')
                    .backgroundColor(GRID_LINE_COLOR)
                    .shadow(GRID_LINE_SHADOW)
                    .position({ x: 0, y: this.boxSize * 2 / 3 })
                  Column()
                    .width(this.boxSize - 16)
                    .height(this.boxSize - 16)
                    .borderRadius(999)
                    .border({ width: 1, color: RING_COLOR })
                  Column()
                    .width('100%')
                    .height('100%')
                    .border({ width: 1, color: FRAME_COLOR })
                }
              }
              .width('100%')
              .aspectRatio(1)
              .clip(true)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.theme.surface2)
              .onAreaChange((_oldVal: Area, newVal: Area) => {
                const w = Number(newVal.width)
                if (w > 0 && w !== this.boxSize) {
                  this.boxSize = w
                  this.clampOffsets()
                }
              })
              .gesture(GestureGroup(GestureMode.Parallel,
                PanGesture({ fingers: 1, distance: 1 })
                  .onActionStart((_e: GestureEvent) => {
                    if (this.pinchActive) {
                      return
                    }
                    this.panBaseX = this.offX
                    this.panBaseY = this.offY
                  })
                  .onActionUpdate((e: GestureEvent) => {
                    if (this.pinchActive) {
                      return
                    }
                    this.setOffset(this.panBaseX + e.offsetX, this.panBaseY + e.offsetY)
                  }),
                PinchGesture({ fingers: 2 })
                  .onActionStart((_e: GestureEvent) => {
                    this.pinchActive = true
                    this.pinchBase = this.zoom
                  })
                  .onActionUpdate((e: GestureEvent) => {
                    this.setZoom(this.pinchBase * e.scale)
                  })
                  .onActionEnd((_e: GestureEvent) => {
                    this.pinchActive = false
                  })
                  .onActionCancel(() => {
                    this.pinchActive = false
                  }),
                TapGesture({ count: 2 })
                  .onAction(() => {
                    const target = this.zoom > 1 ? 1 : ZOOM_DOUBLE
                    this.getUIContext().animateTo(
                      { duration: MotionTokens.sheetDuration, curve: Curve.EaseOut },
                      () => {
                        this.setZoom(target)
                      }
                    )
                  })
              ))
            }
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)

          Text('拖动调整位置，双击或双指缩放取景')
            .fontSize(TypeScale.caption)
            .fontColor(this.theme.text3)
            .margin({ bottom: 12 })

          Row({ space: 12 }) {
            Text('取消')
              .fontSize(TypeScale.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.text2)
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(48)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.theme.surface2)
              .opacity(this.processing ? 0.6 : 1)
              .onClick(() => {
                if (!this.processing) {
                  AppRouter.pop()
                }
              })
            Text(this.processing ? '处理中…' : '完成')
              .fontSize(TypeScale.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.ctaForeground())
              .textAlign(TextAlign.Center)
              .layoutWeight(1)
              .height(48)
              .borderRadius(this.theme.radiusSm)
              .backgroundColor(this.theme.ctaBackground())
              .opacity(this.processing || this.loadFailed ? 0.6 : 1)
              .onClick(() => {
                this.confirmCrop()
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 24 })
        }
        .width('100%')
        .height('100%')
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: true,
        style: {
          systemMaterialEffect: ImmersiveTitleBar.material()
        },
        content: {
          title: { mainTitle: '裁剪头像' },
          backIcon: { label: '返回', action: () => AppRouter.pop() }
        }
      })
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(false)
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme.background)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
}
