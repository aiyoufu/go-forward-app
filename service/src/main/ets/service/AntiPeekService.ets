import { dlpAntiPeep } from '@kit.DeviceSecurityKit'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { AppStorageKeys, Constants } from 'common'
import { PreferencesService } from './PreferencesService'

/** 防窥保护开启结果：驱动设置页开关回弹与提示文案 */
export enum AntiPeekSetupOutcome {
  /** 已开启并订阅 */
  OK = 0,
  /** 设备不支持防窥能力（错误码 801） */
  UNSUPPORTED = 1,
  /** 用户拒绝窥视状态权限 */
  PERMISSION_DENIED = 2,
  /** 系统级防窥开关未开且引导失败（含未录入人脸 1020600004） */
  GUIDE_FAILED = 3
}

/**
 * 防窥保护（Device Security Kit DlpAntiPeep）：
 * 系统通过人脸识别区分机主与他人，检测到「非机主与机主同时注视屏幕」时回调 HIDE，
 * 本服务置位脱敏态（ANTI_PEEK_MASKED），页面结构保留，金额/名称/日期/分期等敏感文本
 * 由各卡片与弹窗组件消费该状态打码；系统回到 PASS（仅机主注视）自动恢复明文。
 *
 * 前置条件（系统侧）：设备支持人脸识别、已录入人脸、系统「设置 > 隐私和安全 > 防窥保护」
 * 为本应用开启开关。应用侧需受限权限 ohos.permission.DLP_GET_HIDE_STATUS。
 */
export class AntiPeekService {
  private static listening: boolean = false

  /** 设备是否具备防窥能力；不支持的设备直接短路所有 dlpAntiPeep 调用 */
  static isSupported(): boolean {
    return canIUse('SystemCapability.Security.DlpAntiPeep')
  }

  static isEnabled(): boolean {
    return PreferencesService.getBoolSync(Constants.PREF_ANTI_PEEK_ENABLED, false)
  }

  /** 写偏好；关闭时同步解除订阅并清除脱敏态，避免残留打码 */
  static async setEnabled(enabled: boolean): Promise<void> {
    await PreferencesService.putBool(Constants.PREF_ANTI_PEEK_ENABLED, enabled)
    if (enabled) {
      AntiPeekService.startListening()
    } else {
      AntiPeekService.stopListening()
      AppStorage.setOrCreate(AppStorageKeys.ANTI_PEEK_MASKED, false)
    }
  }

  /**
   * 开启全流程：动态申请权限 → 查询/引导系统级防窥开关 → 订阅窥视状态。
   * 任一步失败返回对应结果，调用方据此回弹开关并提示。
   */
  static async enable(context: common.UIAbilityContext): Promise<AntiPeekSetupOutcome> {
    if (!AntiPeekService.isSupported()) {
      return AntiPeekSetupOutcome.UNSUPPORTED
    }
    const granted = await AntiPeekService.requestPermission(context)
    if (!granted) {
      return AntiPeekSetupOutcome.PERMISSION_DENIED
    }
    try {
      if (!await dlpAntiPeep.isDlpAntiPeepSwitchOn()) {
        // 拉起系统设置引导；未录入人脸会抛 1020600004 或返回 FAIL
        const result = await dlpAntiPeep.requestAntiPeepOptions(context)
        if (result !== dlpAntiPeep.AntiPeepOptionsResult.SUCCESS &&
          result !== dlpAntiPeep.AntiPeepOptionsResult.ALREADY_ON) {
          return AntiPeekSetupOutcome.GUIDE_FAILED
        }
      }
      AntiPeekService.startListening()
      return AntiPeekSetupOutcome.OK
    } catch (err) {
      const e = err as BusinessError
      // 兜底：极少数设备声明了 syscap 但运行时仍报不支持（801）
      if (e.code === 801) {
        return AntiPeekSetupOutcome.UNSUPPORTED
      }
      return AntiPeekSetupOutcome.GUIDE_FAILED
    }
  }

  /** 幂等订阅：回前台/冷启动时调用，覆盖监听丢失场景；未启用则跳过 */
  static startListeningIfEnabled(): void {
    if (!AntiPeekService.isEnabled()) {
      return
    }
    AntiPeekService.startListening()
  }

  static startListening(): void {
    if (AntiPeekService.listening || !AntiPeekService.isSupported()) {
      return
    }
    try {
      dlpAntiPeep.on('dlpAntiPeep', AntiPeekService.onStatusChange)
      AntiPeekService.listening = true
      // 订阅后立即对齐一次当前状态，避免错过已处于窥视态的窗口期
      const current = dlpAntiPeep.getDlpAntiPeepInfo()
      AntiPeekService.onStatusChange(current)
    } catch (_e) {
      AntiPeekService.listening = false
    }
  }

  static stopListening(): void {
    if (!AntiPeekService.listening) {
      return
    }
    try {
      dlpAntiPeep.off('dlpAntiPeep', AntiPeekService.onStatusChange)
    } catch (_e) {
    }
    AntiPeekService.listening = false
  }

  private static readonly onStatusChange = (status: dlpAntiPeep.DlpAntiPeepStatus): void => {
    // 被窥视（HIDE）：敏感文本脱敏，页面结构保留；机主独视（PASS 等）：自动恢复明文
    AppStorage.setOrCreate(AppStorageKeys.ANTI_PEEK_MASKED,
      status === dlpAntiPeep.DlpAntiPeepStatus.HIDE)
  }

  private static async requestPermission(context: common.UIAbilityContext): Promise<boolean> {
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const permissions: Array<Permissions> = ['ohos.permission.DLP_GET_HIDE_STATUS']
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      for (let i = 0; i < result.authResults.length; i++) {
        if (result.authResults[i] !== 0) {
          return false
        }
      }
      return true
    } catch (_e) {
      return false
    }
  }
}
