import { promptAction, UIContext } from '@kit.ArkUI'
import { AppStorageKeys } from './AppStorageKeys'

/**
 * 全局 Toast：统一从屏幕顶部弹出（避开状态栏）
 *
 * 全局 promptAction.showToast 已废弃，替代品 UIContext.getPromptAction() 需要 UIContext。
 * 本类被近百处静态调用，不逐个透传，改由唯一 @Entry（Index）在挂载时注册一次。
 */
export class AppToast {
  private static uiContext: UIContext | null = null

  /** 由唯一 @Entry 页在 onAppear 中调用，注入 UIContext */
  static attach(context: UIContext): void {
    AppToast.uiContext = context
  }

  static show(message: string, duration: number = 2000): void {
    if (message.length === 0) {
      return
    }
    const ctx = AppToast.uiContext
    if (!ctx) {
      return
    }
    const topSafe = AppStorage.get<number>(AppStorageKeys.TOP_SAFE_HEIGHT) ?? 0
    const dy = topSafe > 0 ? (topSafe + 24) : 72
    const options: promptAction.ShowToastOptions = {
      message: message,
      duration: duration,
      alignment: Alignment.Top,
      offset: { dx: 0, dy: dy }
    }
    try {
      ctx.getPromptAction().showToast(options)
    } catch (_e) {
    }
  }
}
