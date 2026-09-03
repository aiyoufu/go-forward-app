import { motion } from '@kit.MultimodalAwarenessKit'
import { Logger } from 'common'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'

/**
 * 智感握姿：供 AI 录入条跟手布局。
 * 主路径：holdingHandChanged（握持手）
 * 兼容：operatingHandChanged（操作手）
 * 需动态申请 ohos.permission.DETECT_GESTURE。
 */
export type HandednessListener = (leftPrimary: boolean) => void

export class HandednessService {
  private static listeners: HandednessListener[] = []
  private static subscribed: boolean = false
  private static starting: boolean = false
  /** true = 主操作（听写/发送）放左侧 */
  private static leftPrimary: boolean = false
  private static pendingTimer: number = -1
  private static pendingLeft: boolean = false
  private static readonly STABLE_MS: number = 350

  private static readonly onOperatingHand = (status: motion.OperatingHandStatus): void => {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      if (status === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
        HandednessService.scheduleApply(true)
      } else if (status === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
        HandednessService.scheduleApply(false)
      }
    }
  }

  private static readonly onHoldingHand = (status: motion.HoldingHandStatus): void => {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      if (status === motion.HoldingHandStatus.LEFT_HAND_HELD) {
        HandednessService.scheduleApply(true)
      } else if (status === motion.HoldingHandStatus.RIGHT_HAND_HELD) {
        HandednessService.scheduleApply(false)
      }
      // BOTH / NOT_HELD / UNKNOWN：不改，避免抖动
    }
  }

  static isLeftPrimary(): boolean {
    return HandednessService.leftPrimary
  }

  /**
   * 开始监听。传入 UIAbilityContext 以便动态申请 DETECT_GESTURE。
   */
  static async start(listener: HandednessListener, context?: common.UIAbilityContext): Promise<void> {
    HandednessService.addListener(listener)
    // 先把当前缓存态推给新订阅者
    listener(HandednessService.leftPrimary)

    if (HandednessService.starting) {
      return
    }
    HandednessService.starting = true
    try {
      if (context !== undefined && context !== null) {
        const ok = await HandednessService.ensureGesturePermission(context)
        if (!ok) {
          Logger.info('HandednessService', 'DETECT_GESTURE not granted')
          return
        }
      }
      HandednessService.subscribeIfNeeded()
      HandednessService.readRecentOnce()
    } finally {
      HandednessService.starting = false
    }
  }

  static stop(listener: HandednessListener): void {
    HandednessService.removeListener(listener)
    if (HandednessService.listeners.length === 0) {
      HandednessService.clearPending()
      HandednessService.unsubscribeAll()
    }
  }

  private static async ensureGesturePermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const permission: Permissions = 'ohos.permission.DETECT_GESTURE'
      const status = await atManager.checkAccessToken(context.applicationInfo.accessTokenId, permission)
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true
      }
      const result = await atManager.requestPermissionsFromUser(context, [permission])
      if (result.authResults !== undefined && result.authResults.length > 0) {
        return result.authResults[0] === 0
      }
      return false
    } catch (e) {
      Logger.info('HandednessService', 'ensureGesturePermission: ' + JSON.stringify(e))
      // 部分机型可能不弹窗，仍尝试订阅
      return true
    }
  }

  private static subscribeIfNeeded(): void {
    if (HandednessService.subscribed) {
      return
    }
    let any = false
    // 握持手（智感握姿主信号，API 20+）
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        motion.on('holdingHandChanged', HandednessService.onHoldingHand)
        any = true
        Logger.info('HandednessService', 'subscribed holdingHandChanged')
      } catch (e) {
        Logger.info('HandednessService', 'holdingHand on fail: ' + JSON.stringify(e))
      }
    } else {
      Logger.info('HandednessService', 'holdingHandChanged unsupported on this device')
    }
    // 操作手（兼容）
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        motion.on('operatingHandChanged', HandednessService.onOperatingHand)
        any = true
        Logger.info('HandednessService', 'subscribed operatingHandChanged')
      } catch (e2) {
        Logger.info('HandednessService', 'operatingHand on fail: ' + JSON.stringify(e2))
      }
    } else {
      Logger.info('HandednessService', 'operatingHandChanged unsupported on this device')
    }
    HandednessService.subscribed = any
  }

  private static unsubscribeAll(): void {
    if (!HandednessService.subscribed) {
      return
    }
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        motion.off('holdingHandChanged', HandednessService.onHoldingHand)
      } catch (_e) {
      }
      try {
        motion.off('operatingHandChanged', HandednessService.onOperatingHand)
      } catch (_e2) {
      }
    }
    HandednessService.subscribed = false
  }

  private static readRecentOnce(): void {
    if (canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      try {
        const recent = motion.getRecentOperatingHandStatus()
        Logger.info('HandednessService', 'recent operating: ' + recent)
        if (recent === motion.OperatingHandStatus.LEFT_HAND_OPERATED) {
          HandednessService.applyImmediate(true)
        } else if (recent === motion.OperatingHandStatus.RIGHT_HAND_OPERATED) {
          HandednessService.applyImmediate(false)
        }
      } catch (e) {
        Logger.info('HandednessService', 'getRecent fail: ' + JSON.stringify(e))
      }
    } else {
      Logger.info('HandednessService', 'getRecentOperatingHandStatus unsupported on this device')
    }
  }

  private static addListener(listener: HandednessListener): void {
    const next: HandednessListener[] = []
    for (let i = 0; i < HandednessService.listeners.length; i++) {
      if (HandednessService.listeners[i] !== listener) {
        next.push(HandednessService.listeners[i])
      }
    }
    next.push(listener)
    HandednessService.listeners = next
  }

  private static removeListener(listener: HandednessListener): void {
    const next: HandednessListener[] = []
    for (let i = 0; i < HandednessService.listeners.length; i++) {
      if (HandednessService.listeners[i] !== listener) {
        next.push(HandednessService.listeners[i])
      }
    }
    HandednessService.listeners = next
  }

  private static scheduleApply(leftPrimary: boolean): void {
    HandednessService.pendingLeft = leftPrimary
    HandednessService.clearPending()
    HandednessService.pendingTimer = setTimeout(() => {
      HandednessService.pendingTimer = -1
      HandednessService.applyImmediate(HandednessService.pendingLeft)
    }, HandednessService.STABLE_MS)
  }

  private static applyImmediate(leftPrimary: boolean): void {
    if (HandednessService.leftPrimary === leftPrimary) {
      return
    }
    Logger.info('HandednessService', 'apply leftPrimary=' + leftPrimary)
    HandednessService.leftPrimary = leftPrimary
    const list = HandednessService.listeners
    for (let i = 0; i < list.length; i++) {
      try {
        list[i](leftPrimary)
      } catch (_e) {
      }
    }
  }

  private static clearPending(): void {
    if (HandednessService.pendingTimer !== -1) {
      clearTimeout(HandednessService.pendingTimer)
      HandednessService.pendingTimer = -1
    }
  }
}
