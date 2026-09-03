import { UserSettings, AiApiFormat } from 'common'
import { PreferencesService } from './PreferencesService'
import { SecureStore } from './auth/SecureStore'

/** AI 配置旁路快照（Key 走 SecureStore，其余走 Preferences） */
export class AiBackupSnapshot {
  textEnabled: boolean = false
  textKey: string = ''
  textUrl: string = ''
  textModel: string = ''
  textFormat: string = 'auto'
  textFp: string = ''
  visionEnabled: boolean = false
  visionKey: string = ''
  visionUrl: string = ''
  visionModel: string = ''
  visionFormat: string = 'auto'
  visionFp: string = ''
}

/**
 * RDB 整行更新失败时（缺列等），进程内缓存仍显示已接通，重启后变「未配置」。
 * 旁路快照保证杀进程后仍能恢复文字/图片渠道。
 */
export class SettingsAiBackup {
  static prefKey(userId: string): string {
    return 'ai_bak_' + userId
  }

  static textKeyAlias(userId: string): string {
    return 'ai_bak_tk_' + userId
  }

  static visionKeyAlias(userId: string): string {
    return 'ai_bak_vk_' + userId
  }

  static fromSettings(s: UserSettings): AiBackupSnapshot {
    const snap = new AiBackupSnapshot()
    snap.textEnabled = s.ai_text_enabled
    snap.textKey = s.ai_text_key
    snap.textUrl = s.ai_text_base_url
    snap.textModel = s.ai_text_model
    snap.textFormat = s.ai_text_api_format
    snap.textFp = s.ai_text_test_fp
    snap.visionEnabled = s.ai_vision_enabled
    snap.visionKey = s.ai_vision_key
    snap.visionUrl = s.ai_vision_base_url
    snap.visionModel = s.ai_vision_model
    snap.visionFormat = s.ai_vision_api_format
    snap.visionFp = s.ai_vision_test_fp
    return snap
  }

  static snapshotHasData(snap: AiBackupSnapshot): boolean {
    return snap.textKey.length > 0 || snap.textUrl.length > 0 ||
      snap.visionKey.length > 0 || snap.visionUrl.length > 0
  }

  /**
   * 库里缺的字段用快照补；已有非空值不覆盖。
   * 返回是否改写了 settings。
   */
  static hydrate(s: UserSettings, snap: AiBackupSnapshot): boolean {
    if (!SettingsAiBackup.snapshotHasData(snap)) {
      return false
    }
    let changed = false
    if (s.ai_text_key.length === 0 && snap.textKey.length > 0) {
      s.ai_text_key = snap.textKey
      changed = true
    }
    if (s.ai_text_base_url.length === 0 && snap.textUrl.length > 0) {
      s.ai_text_base_url = snap.textUrl
      changed = true
    }
    if (s.ai_text_model.length === 0 && snap.textModel.length > 0) {
      s.ai_text_model = snap.textModel
      changed = true
    }
    if (s.ai_text_test_fp.length === 0 && snap.textFp.length > 0) {
      s.ai_text_test_fp = snap.textFp
      changed = true
    }
    if (s.ai_text_api_format === 'auto' && snap.textFormat.length > 0 && snap.textFormat !== 'auto') {
      s.ai_text_api_format = SettingsAiBackup.toFormat(snap.textFormat)
      changed = true
    }
    if (s.ai_vision_key.length === 0 && snap.visionKey.length > 0) {
      s.ai_vision_key = snap.visionKey
      changed = true
    }
    if (s.ai_vision_base_url.length === 0 && snap.visionUrl.length > 0) {
      s.ai_vision_base_url = snap.visionUrl
      changed = true
    }
    if (s.ai_vision_model.length === 0 && snap.visionModel.length > 0) {
      s.ai_vision_model = snap.visionModel
      changed = true
    }
    if (s.ai_vision_test_fp.length === 0 && snap.visionFp.length > 0) {
      s.ai_vision_test_fp = snap.visionFp
      changed = true
    }
    if (s.ai_vision_api_format === 'auto' && snap.visionFormat.length > 0 &&
      snap.visionFormat !== 'auto') {
      s.ai_vision_api_format = SettingsAiBackup.toFormat(snap.visionFormat)
      changed = true
    }
    SettingsAiBackup.repairEnabled(s)
    return changed
  }

  /** 有 Key 即视为开启，避免 INTEGER 列读不回导致摘要「未配置」 */
  static repairEnabled(s: UserSettings): void {
    if (s.ai_text_key.trim().length > 0 || s.ai_text_base_url.trim().length > 0) {
      s.ai_text_enabled = true
    }
    if (s.ai_vision_key.trim().length > 0 || s.ai_vision_base_url.trim().length > 0) {
      s.ai_vision_enabled = true
    }
  }

  static serializeMeta(snap: AiBackupSnapshot): string {
    return JSON.stringify({
      te: snap.textEnabled ? 1 : 0,
      tu: snap.textUrl,
      tm: snap.textModel,
      tf: snap.textFormat,
      tp: snap.textFp,
      ve: snap.visionEnabled ? 1 : 0,
      vu: snap.visionUrl,
      vm: snap.visionModel,
      vf: snap.visionFormat,
      vp: snap.visionFp
    })
  }

  static deserializeMeta(raw: string): AiBackupSnapshot {
    const snap = new AiBackupSnapshot()
    if (raw.length === 0) {
      return snap
    }
    try {
      const obj = JSON.parse(raw) as Record<string, Object>
      snap.textEnabled = Number(obj['te']) === 1
      snap.textUrl = SettingsAiBackup.asString(obj['tu'])
      snap.textModel = SettingsAiBackup.asString(obj['tm'])
      snap.textFormat = SettingsAiBackup.asString(obj['tf'])
      snap.textFp = SettingsAiBackup.asString(obj['tp'])
      snap.visionEnabled = Number(obj['ve']) === 1
      snap.visionUrl = SettingsAiBackup.asString(obj['vu'])
      snap.visionModel = SettingsAiBackup.asString(obj['vm'])
      snap.visionFormat = SettingsAiBackup.asString(obj['vf'])
      snap.visionFp = SettingsAiBackup.asString(obj['vp'])
    } catch (_e) {
    }
    return snap
  }

  static async write(s: UserSettings): Promise<void> {
    const userId = s.user_id
    if (userId.length === 0) {
      return
    }
    const snap = SettingsAiBackup.fromSettings(s)
    await PreferencesService.putString(SettingsAiBackup.prefKey(userId),
      SettingsAiBackup.serializeMeta(snap))
    await SecureStore.putString(SettingsAiBackup.textKeyAlias(userId), snap.textKey)
    await SecureStore.putString(SettingsAiBackup.visionKeyAlias(userId), snap.visionKey)
  }

  static async read(userId: string): Promise<AiBackupSnapshot> {
    const snap = SettingsAiBackup.deserializeMeta(
      await PreferencesService.getString(SettingsAiBackup.prefKey(userId), ''))
    if (userId.length > 0) {
      snap.textKey = await SecureStore.getString(SettingsAiBackup.textKeyAlias(userId))
      snap.visionKey = await SecureStore.getString(SettingsAiBackup.visionKeyAlias(userId))
    }
    return snap
  }

  static async clear(userId: string): Promise<void> {
    if (userId.length === 0) {
      return
    }
    await PreferencesService.delete(SettingsAiBackup.prefKey(userId))
    await SecureStore.remove(SettingsAiBackup.textKeyAlias(userId))
    await SecureStore.remove(SettingsAiBackup.visionKeyAlias(userId))
  }

  private static asString(v: Object | undefined): string {
    if (v === undefined || v === null) {
      return ''
    }
    return `${v}`
  }

  private static toFormat(v: string): AiApiFormat {
    if (v === 'openai' || v === 'anthropic') {
      return v
    }
    return 'auto'
  }
}
