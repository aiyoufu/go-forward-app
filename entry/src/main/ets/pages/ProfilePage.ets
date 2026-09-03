import {
  ThemeColors, ThemeManager, TypeScale,
  AppStorageKeys, AppRouter, ImmersiveTitleBar,
  AppToast, ErrorMessages, UserSettings, RouteNames
} from 'common'
import { MotionHelper } from 'common'
import { SettingsService, UserService, AuthManager, ProfileService } from 'service'
import { SheetHeader, sheetBottomInset } from 'components'
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  ScrollEffectType
} from '@kit.UIDesignKit'
import { LengthMetrics } from '@kit.ArkUI'
import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import { AvatarCropParams } from './AvatarCropPage'

/** 昵称上限 */
const NICKNAME_MAX: number = 20
/** 签名上限 */
const SIGNATURE_MAX: number = 50

/** profileRow 按引用传参：@Builder 按值传参不响应 @State 变化，必须用对象字面量传递 */
class ProfileRowParams {
  label: string = ''
  value: string = ''
  clickable: boolean = false
  onTap: () => void = () => {
  }
}

/**
 * 个人资料页：头像（相册选图 → 裁剪编辑）、昵称、签名编辑 + 修改账户密码入口
 * 资料以 auth user_metadata 为云端真源（与 Web 端同源），本机 user_settings / filesDir 作缓存
 */
@Component
export struct ProfilePage {
  @State theme: ThemeColors = ThemeManager.DARK
  @State settings: UserSettings = new UserSettings()
  @State sessionEmail: string = ''
  @State avatarPixelMap: image.PixelMap | null = null
  @State showEditSheet: boolean = false
  /** 'nickname' | 'signature' */
  @State editKind: string = 'nickname'
  @State editText: string = ''
  @State showPasswordSheet: boolean = false
  @State oldPwd: string = ''
  @State newPwd: string = ''
  @State confirmPwd: string = ''
  @State changing: boolean = false
  @State saving: boolean = false
  private pageScroller: Scroller = new Scroller()
  private resumedOnce: boolean = false

  aboutToAppear() {
    this.bootstrap()
  }

  private async bootstrap(): Promise<void> {
    const settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    const storedLux = AppStorage.get<number>(AppStorageKeys.AMBIENT_LUX) ?? -1
    this.theme = ThemeManager.currentTheme(settings,
      AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false, storedLux)
    this.settings = settings
    const session = await AuthManager.loadSession()
    this.sessionEmail = session !== null ? session.email : ''
    await this.loadAvatar()
    await this.pullCloudProfile()
  }

  private async pullCloudProfile(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
      await ProfileService.pullFromCloud(ctx)
      this.settings = await SettingsService.getSettings(UserService.getCurrentUserId())
      await this.loadAvatar()
    } catch (_e) {
    }
  }

  private async loadAvatar(): Promise<void> {
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    this.avatarPixelMap = await ProfileService.loadAvatarPixelMap(ctx, this.settings.profile_avatar_path)
  }

  private avatarMark(): string {
    if (this.settings.profile_nickname.length > 0) {
      return this.settings.profile_nickname.substring(0, 1).toUpperCase()
    }
    if (this.sessionEmail.length > 0) {
      return this.sessionEmail.substring(0, 1).toUpperCase()
    }
    return 'G'
  }

  private async pickAvatar(): Promise<void> {
    try {
      const picked = await ProfileService.pickAvatarSource()
      if (picked.uri.length === 0) {
        if (picked.tooLarge) {
          AppToast.show(ProfileService.MSG_SOURCE_TOO_LARGE, 2000)
        }
        return
      }
      const params: AvatarCropParams = { uri: picked.uri }
      AppRouter.push(RouteNames.AVATAR_CROP, params)
    } catch {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    }
  }

  /** 从裁剪页返回时刷新（首次 onShown 与 bootstrap 重复，跳过） */
  private onDestShown(): void {
    if (!this.resumedOnce) {
      this.resumedOnce = true
      return
    }
    this.refreshAfterCrop()
  }

  private async refreshAfterCrop(): Promise<void> {
    this.settings = await SettingsService.getSettings(UserService.getCurrentUserId())
    await this.loadAvatar()
  }

  /** 通知设置页账户卡刷新（SettingsTab 是 Tab 内组件，无 onPageShow 生命周期） */
  private static notifyProfileChanged(): void {
    AppStorage.setOrCreate(AppStorageKeys.PROFILE_REVISION, Date.now())
  }

  private openEdit(kind: string): void {
    this.editKind = kind
    this.editText = kind === 'nickname' ? this.settings.profile_nickname : this.settings.profile_signature
    this.showEditSheet = true
  }

  private async saveEdit(): Promise<void> {
    if (this.saving) {
      return
    }
    this.saving = true
    try {
      const trimmed = this.editText.trim()
      if (this.editKind === 'nickname') {
        this.settings.profile_nickname = trimmed
      } else {
        this.settings.profile_signature = trimmed
      }
      await SettingsService.saveSettings(this.settings)
      if (this.editKind === 'nickname') {
        await ProfileService.pushNickname(trimmed)
      }
      this.showEditSheet = false
      ProfilePage.notifyProfileChanged()
      AppToast.show(ErrorMessages.UPDATE_OK, 1500)
    } catch {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
    }
    this.saving = false
  }

  private async doChangePassword(): Promise<void> {
    if (this.changing) {
      return
    }
    if (this.oldPwd.length === 0 || this.newPwd.length === 0) {
      AppToast.show('请输入旧密码和新密码', 2000)
      return
    }
    if (this.newPwd.length < 6) {
      AppToast.show('密码长度至少 6 位', 2000)
      return
    }
    if (this.newPwd !== this.confirmPwd) {
      AppToast.show('两次输入的密码不一致', 2000)
      return
    }
    if (this.newPwd === this.oldPwd) {
      AppToast.show('新密码不能与旧密码相同', 2000)
      return
    }
    this.changing = true
    const result = await AuthManager.changePassword(this.oldPwd, this.newPwd)
    this.changing = false
    if (result.success) {
      AppToast.show('密码已修改', 2000)
      this.showPasswordSheet = false
      this.oldPwd = ''
      this.newPwd = ''
      this.confirmPwd = ''
    } else {
      AppToast.show(result.error.length > 0 ? result.error : '修改失败', 2500)
    }
  }

  @Builder
  profileRow(params: ProfileRowParams) {
    Row() {
      Text(params.label)
        .fontSize(TypeScale.listPrimary)
        .fontColor(this.theme.text)
      Row({ space: 6 }) {
        Text(params.value)
          .fontSize(TypeScale.body)
          .fontColor(this.theme.text3)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: 180 })
        if (params.clickable) {
          Text('›')
            .fontSize(TypeScale.metric)
            .fontColor(this.theme.text3)
        }
      }
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      if (params.clickable) {
        params.onTap()
      }
    })
  }

  @Builder
  avatarRow() {
    Row() {
      Text('头像')
        .fontSize(TypeScale.listPrimary)
        .fontColor(this.theme.text)
      Row({ space: 6 }) {
        if (this.avatarPixelMap !== null) {
          Image(this.avatarPixelMap)
            .width(44)
            .height(44)
            .borderRadius(this.theme.radiusPill)
            .objectFit(ImageFit.Cover)
        } else {
          Column() {
            Text(this.avatarMark())
              .fontSize(TypeScale.listPrimary)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.onColorBlock())
          }
          .width(44)
          .height(44)
          .borderRadius(this.theme.radiusPill)
          .backgroundColor(this.theme.accent)
          .justifyContent(FlexAlign.Center)
        }
        Text('›')
          .fontSize(TypeScale.metric)
          .fontColor(this.theme.text3)
      }
    }
    .width('100%')
    .height(68)
    .padding({ left: 16, right: 16 })
    .justifyContent(FlexAlign.SpaceBetween)
    .onClick(() => {
      this.pickAvatar()
    })
  }

  @Builder
  editSheetBuilder() {
    Column() {
      SheetHeader({
        theme: this.theme,
        title: this.editKind === 'nickname' ? '昵称' : '个性签名',
        onClose: () => {
          this.showEditSheet = false
        }
      })
      TextInput({
        placeholder: this.editKind === 'nickname' ? '输入昵称（20 字以内）' : '输入个性签名（50 字以内）',
        text: this.editText
      })
        .maxLength(this.editKind === 'nickname' ? NICKNAME_MAX : SIGNATURE_MAX)
        .fontSize(TypeScale.listPrimarySm)
        .fontColor(this.theme.text)
        .placeholderColor(this.theme.text3)
        .backgroundColor(this.theme.fieldBackground())
        .borderRadius(this.theme.radiusLg)
        .height(50)
        .onChange((v: string) => {
          this.editText = v
        })
      Text('保存')
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.ctaForeground())
        .width('100%')
        .textAlign(TextAlign.Center)
        .height(48)
        .borderRadius(this.theme.radiusSm)
        .backgroundColor(this.theme.ctaBackground())
        .margin({ top: 16 })
        .onClick(() => {
          this.saveEdit()
        })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ left: 16, right: 16, bottom: sheetBottomInset(24) })
  }

  @Builder
  passwordInput(placeholder: string, value: string, onValueChange: (v: string) => void) {
    TextInput({ placeholder: placeholder, text: value })
      .type(InputType.Password)
      .showPasswordIcon(false)
      .fontSize(TypeScale.listPrimarySm)
      .fontColor(this.theme.text)
      .placeholderColor(this.theme.text3)
      .backgroundColor(this.theme.fieldBackground())
      .borderRadius(this.theme.radiusLg)
      .height(50)
      .onChange(onValueChange)
  }

  @Builder
  passwordSheetBuilder() {
    Column({ space: 12 }) {
      SheetHeader({
        theme: this.theme,
        title: '修改密码',
        subtitle: '验证旧密码后设置新密码，新密码至少 6 位',
        onClose: () => {
          this.showPasswordSheet = false
        }
      })
      this.passwordInput('旧密码', this.oldPwd, (v: string) => {
        this.oldPwd = v
      })
      this.passwordInput('新密码（6 位以上）', this.newPwd, (v: string) => {
        this.newPwd = v
      })
      this.passwordInput('确认新密码', this.confirmPwd, (v: string) => {
        this.confirmPwd = v
      })
      Text(this.changing ? '提交中…' : '确认修改')
        .fontSize(TypeScale.body)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.ctaForeground())
        .width('100%')
        .textAlign(TextAlign.Center)
        .height(48)
        .borderRadius(this.theme.radiusSm)
        .backgroundColor(this.theme.ctaBackground())
        .opacity(this.changing ? 0.6 : 1)
        .margin({ top: 8 })
        .onClick(() => {
          this.doChangePassword()
        })
    }
    .width('100%')
    .backgroundColor(this.theme.sheetBackground())
    .border({ width: { top: 0.5, left: 0, right: 0, bottom: 0 }, color: this.theme.sheetEdgeColor() })
    .padding({ left: 16, right: 16, bottom: sheetBottomInset(24) })
  }

  /** 页转场位移/透明度（MotionHelper.navPageTransition 驱动） */
  @State private navTransX: number = 0
  @State private navAlpha: number = 1

  build() {
    NavDestination() {
      HdsNavigation() {
        Scroll(this.pageScroller) {
          Column() {
            // 单分组列表：头像 / 昵称 / 签名 / 邮箱 / 修改密码
            Column() {
              // 资料段：单独宿主挂编辑 Sheet
              Column() {
                this.avatarRow()
                Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 16 })
                this.profileRow({
                  label: '昵称',
                  value: this.settings.profile_nickname.length > 0 ? this.settings.profile_nickname : '未设置',
                  clickable: true,
                  onTap: (): void => {
                    this.openEdit('nickname')
                  }
                })
                Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 16 })
                this.profileRow({
                  label: '个性签名',
                  value: this.settings.profile_signature.length > 0 ? this.settings.profile_signature : '未设置',
                  clickable: true,
                  onTap: (): void => {
                    this.openEdit('signature')
                  }
                })
              }
              .width('100%')
              .bindSheet($$this.showEditSheet, this.editSheetBuilder, {
                height: SheetSize.FIT_CONTENT,
                dragBar: true,
                radius: LengthMetrics.vp(this.theme.sheetRadius),
                showClose: false,
                backgroundColor: this.theme.sheetBackground() as string,
                blurStyle: BlurStyle.NONE,
                maskColor: this.theme.sheetMaskColor(),
                shadow: this.theme.sheetShadowOptions(),
                onDisappear: () => {
                  this.showEditSheet = false
                }
              })

              Divider().color(this.theme.border).strokeWidth(0.5).margin({ left: 16 })

              // 安全段：单独宿主挂改密 Sheet
              Column() {
                this.profileRow({
                  label: '修改密码',
                  value: '',
                  clickable: true,
                  onTap: (): void => {
                    this.showPasswordSheet = true
                  }
                })
              }
              .width('100%')
              .bindSheet($$this.showPasswordSheet, this.passwordSheetBuilder, {
                height: SheetSize.FIT_CONTENT,
                dragBar: true,
                radius: LengthMetrics.vp(this.theme.sheetRadius),
                showClose: false,
                backgroundColor: this.theme.sheetBackground() as string,
                blurStyle: BlurStyle.NONE,
                maskColor: this.theme.sheetMaskColor(),
                shadow: this.theme.sheetShadowOptions(),
                onDisappear: () => {
                  this.showPasswordSheet = false
                }
              })
            }
            .width('100%')
            .backgroundColor(this.theme.surface)
            .borderRadius(this.theme.radiusSm)
            .border({ width: 1, color: this.theme.border })
            .shadow(this.theme.floatShadowOptions())
            .clip(true)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 40 })
        }
        .scrollBar(BarState.Off)
        .align(Alignment.Top)
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .width('100%')
        .height('100%')
      }
      .titleBar({
        avoidLayoutSafeArea: true,
        enableComponentSafeArea: true,
        style: {
          scrollEffectOpts: {
            enableScrollEffect: true,
            scrollEffectType: ScrollEffectType.GRADIENT_BLUR
          },
          systemMaterialEffect: ImmersiveTitleBar.material()
        },
        content: {
          title: { mainTitle: '个人资料' },
          backIcon: { label: '返回', action: () => AppRouter.pop() }
        }
      })
      .mode(NavigationMode.Stack)
      .titleMode(HdsNavigationTitleMode.MINI)
      .hideBackButton(false)
      .bindToScrollable([this.pageScroller])
      .width('100%')
      .height('100%')
      .backgroundColor(this.theme.background)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .backgroundColor(this.theme.background)
    .onShown(() => {
      this.onDestShown()
    })
    .translate({ x: this.navTransX })
    .opacity(this.navAlpha)
    .customTransition((op: NavigationOperation, isEnter: boolean) => MotionHelper.navPageTransition(op, isEnter,
      (x: number, alpha: number) => {
        this.navTransX = x
        this.navAlpha = alpha
      }))
  }
}
