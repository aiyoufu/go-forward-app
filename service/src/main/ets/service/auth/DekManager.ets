import { Logger } from 'common'
import { Constants } from 'common'
import { CryptoService } from './CryptoService'
import { SecureStore } from './SecureStore'
import { DbService } from '../DbService'
import { SupabaseRestService, SupabaseRestOptions } from '../SupabaseRestService'

/**
 * DEK 生命周期编排：登录解锁 / 注册开通 / 改密重包裹 / 重置自愈。
 * 复刻 go-forward-desktop lib/crypto-keys.ts，云端仅存包裹后的 DEK
 * （user_settings.enc_dek_wrapped / enc_dek_salt）。
 *
 * 云端读写方法显式接收 userId + token（不 import AuthManager），
 * 避免与 AuthManager 的循环依赖；字段门面仅依赖活跃 DEK，与云端无关。
 */
export type DekUnlockResult = 'unlocked' | 'provisioned' | 'reset'

/** DEK 列 PATCH 请求体（局部更新，不含 user_id） */
class DekPatchBody {
  enc_dek_wrapped: string = ''
  enc_dek_salt: string = ''

  constructor(wrapped: string, salt: string) {
    this.enc_dek_wrapped = wrapped
    this.enc_dek_salt = salt
  }
}

/** DEK 列 upsert 请求体（云端行缺失时兜底建行，含 user_id） */
class DekUpsertBody {
  user_id: string = ''
  enc_dek_wrapped: string = ''
  enc_dek_salt: string = ''

  constructor(userId: string, wrapped: string, salt: string) {
    this.user_id = userId
    this.enc_dek_wrapped = wrapped
    this.enc_dek_salt = salt
  }
}

/** 云端 DEK 列读取结果 */
class DekCloudRow {
  wrapped: string = ''
  salt: string = ''
}

export class DekManager {
  private static readonly TAG: string = 'DekManager'
  /** DEK 本机缓存别名（关键资产），存 base64(dek 32B) */
  private static readonly DEK_ALIAS: string = 'enc_dek_cache'
  /** PBKDF2 盐字节数，与 go-forward-desktop generateSaltB64 一致 */
  private static readonly SALT_LEN: number = 16

  /** 活跃 DEK 内存缓存；进程内命中免读关键资产 */
  private static memoryDek: Uint8Array | null = null

  // ───── DEK 持有（内存 + SecureStore）─────

  /** 取当前 DEK：内存 → SecureStore → null */
  static async getActiveDek(): Promise<Uint8Array | null> {
    if (DekManager.memoryDek !== null) {
      return DekManager.memoryDek
    }
    try {
      const cached = await SecureStore.getString(DekManager.DEK_ALIAS)
      if (cached.length === 0) {
        return null
      }
      const dek = CryptoService.decodeBase64(cached)
      DekManager.memoryDek = dek
      return dek
    } catch (e) {
      Logger.warn(DekManager.TAG, '读取缓存 DEK 失败: ' + JSON.stringify(e))
      return null
    }
  }

  /** 设置当前 DEK 并缓存到本机关键资产 */
  static async setActiveDek(dek: Uint8Array): Promise<void> {
    DekManager.memoryDek = dek
    try {
      await SecureStore.putString(DekManager.DEK_ALIAS, CryptoService.encodeBase64(dek))
    } catch (e) {
      Logger.warn(DekManager.TAG, '缓存 DEK 失败: ' + JSON.stringify(e))
    }
  }

  /** 清除 DEK（登出时调用） */
  static async clearActiveDek(): Promise<void> {
    DekManager.memoryDek = null
    try {
      await SecureStore.remove(DekManager.DEK_ALIAS)
    } catch (e) {
      Logger.warn(DekManager.TAG, '清除 DEK 失败: ' + JSON.stringify(e))
    }
  }

  // ───── 字段加解密门面（E2EEService 调用）─────

  /**
   * 加密字段值。空值/已加密值原样返回；
   * DEK 不可用时回退明文（过渡期兜底，下次登录后由迁移补加密）。
   */
  static async encryptField(plain: string): Promise<string> {
    if (plain.length === 0) {
      return plain
    }
    if (CryptoService.isEncryptedValue(plain)) {
      return plain
    }
    const dek = await DekManager.getActiveDek()
    if (dek === null) {
      // 本机暂存明文以便继续录入；出站由各表 TableSync 适配器剥离明文敏感列
      Logger.warn(DekManager.TAG, 'DEK 不可用，敏感字段暂存本机明文，禁止出站')
      return plain
    }
    return CryptoService.aesGcmEncrypt(CryptoService.stringToBytes(plain), dek)
  }

  /**
   * 解密字段值。非密文原样返回（兼容存量明文）；
   * 密文但 DEK 不可用/解密失败返回空串（凭证按「未配置」处理，避免把密文当明文回显）。
   */
  static async decryptField(value: string): Promise<string> {
    if (value.length === 0) {
      return value
    }
    if (!CryptoService.isEncryptedValue(value)) {
      return value
    }
    const dek = await DekManager.getActiveDek()
    if (dek === null) {
      Logger.warn(DekManager.TAG, 'DEK 不可用，无法解密字段')
      return ''
    }
    const plain = await CryptoService.aesGcmDecrypt(value, dek)
    if (plain === null) {
      return ''
    }
    return CryptoService.bytesToString(plain)
  }

  // ───── DEK 生命周期 ─────

  /**
   * 登录后解锁 DEK：
   * - 云端无记录 → 首次开通并后台补加密存量明文；
   * - 解包成功 → 激活并后台补加密；
   * - 解包失败（邮件重置过密码等）→ 自愈：换新 DEK 并清空不可解密的凭证。
   */
  static async unlockDekOnLogin(userId: string, token: string, password: string): Promise<DekUnlockResult> {
    const row = await DekManager.readDekColumns(userId, token)
    if (row === null || row.wrapped.length === 0 || row.salt.length === 0) {
      await DekManager.provisionDek(userId, token, password)
      await DekManager.migratePlaintextSecrets(userId)
      return 'provisioned'
    }

    const saltBytes = CryptoService.decodeBase64(row.salt)
    const kek = await CryptoService.deriveKek(password, saltBytes)
    const dek = await CryptoService.unwrapDek(row.wrapped, kek)
    if (dek !== null) {
      await DekManager.setActiveDek(dek)
      await DekManager.migratePlaintextSecrets(userId)
      return 'unlocked'
    }

    await DekManager.resetDekAndClearSecrets(userId, token, password)
    return 'reset'
  }

  /** 生成新 DEK，用密码包裹后写云端，并激活到本机 */
  static async provisionDek(userId: string, token: string, password: string): Promise<void> {
    const dek = CryptoService.generateDek()
    const saltBytes = CryptoService.randomBytes(DekManager.SALT_LEN)
    const saltB64 = CryptoService.encodeBase64(saltBytes)
    const kek = await CryptoService.deriveKek(password, saltBytes)
    const wrapped = await CryptoService.wrapDek(dek, kek)
    await DekManager.writeDekColumns(userId, token, wrapped, saltB64)
    await DekManager.setActiveDek(dek)
  }

  /**
   * 用新密码重新包裹当前 DEK（修改密码 / 本机有缓存的邮件重置）。
   * 无可用 DEK 时返回 false，由下次登录的自愈流程兜底。
   */
  static async rewrapDekWithPassword(userId: string, token: string, newPassword: string): Promise<boolean> {
    if (userId.length === 0 || token.length === 0) {
      return false
    }
    const dek = await DekManager.getActiveDek()
    if (dek === null) {
      return false
    }
    const saltBytes = CryptoService.randomBytes(DekManager.SALT_LEN)
    const saltB64 = CryptoService.encodeBase64(saltBytes)
    const kek = await CryptoService.deriveKek(newPassword, saltBytes)
    const wrapped = await CryptoService.wrapDek(dek, kek)
    const ok = await DekManager.writeDekColumns(userId, token, wrapped, saltB64)
    if (!ok) {
      Logger.warn(DekManager.TAG, '重新包裹 DEK 失败，将由下次登录自愈')
    }
    return ok
  }

  /** DEK 不可恢复时的自愈：清空本地不可解密（enc:v1）的凭证字段，换新 DEK */
  static async resetDekAndClearSecrets(userId: string, token: string, password: string): Promise<void> {
    await DekManager.clearEncryptedSecrets(userId)
    await DekManager.provisionDek(userId, token, password)
  }

  /**
   * 补加密本地存量明文凭证（后台静默执行，失败不影响主流程）。
   * 覆盖：本功能上线前录入的明文，以及 DEK 暂不可用时的明文兜底写入。
   */
  static async migratePlaintextSecrets(userId: string): Promise<void> {
    try {
      const dek = await DekManager.getActiveDek()
      if (dek === null) {
        return
      }
      await DekManager.migrateSettingsSecrets(userId)
      await DekManager.migrateCvvSecrets(userId)
    } catch (e) {
      Logger.warn(DekManager.TAG, '存量凭证补加密失败: ' + JSON.stringify(e))
    }
  }

  // ───── 内部：本地迁移 ─────

  private static async migrateSettingsSecrets(userId: string): Promise<void> {
    const rs = await DbService.query(
      'SELECT ai_text_key, ai_vision_key FROM user_settings WHERE user_id = ?', [userId])
    let textKey = ''
    let visionKey = ''
    try {
      if (rs.goToFirstRow()) {
        textKey = rs.getString(rs.getColumnIndex('ai_text_key'))
        visionKey = rs.getString(rs.getColumnIndex('ai_vision_key'))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }

    const updates = new Map<string, string | number | boolean>()
    if (textKey.length > 0 && !CryptoService.isEncryptedValue(textKey)) {
      updates.set('ai_text_key', await DekManager.encryptField(textKey))
    }
    if (visionKey.length > 0 && !CryptoService.isEncryptedValue(visionKey)) {
      updates.set('ai_vision_key', await DekManager.encryptField(visionKey))
    }
    if (updates.size > 0) {
      await DbService.update('user_settings', updates, 'user_id = ?', [userId])
    }
  }

  private static async migrateCvvSecrets(userId: string): Promise<void> {
    const rs = await DbService.query(
      'SELECT id, cvv FROM credit_accounts WHERE user_id = ?', [userId])
    const ids: string[] = []
    const cvvs: string[] = []
    try {
      while (rs.goToNextRow()) {
        ids.push(rs.getString(rs.getColumnIndex('id')))
        cvvs.push(rs.getString(rs.getColumnIndex('cvv')))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }

    for (let i = 0; i < ids.length; i++) {
      const cvv = cvvs[i]
      if (cvv.length > 0 && !CryptoService.isEncryptedValue(cvv)) {
        const updates = new Map<string, string | number | boolean>()
        updates.set('cvv', await DekManager.encryptField(cvv))
        await DbService.update('credit_accounts', updates, 'id = ?', [ids[i]])
      }
    }
  }

  /** 清空本地已加密（不可解密）的凭证字段；存量明文保留 */
  private static async clearEncryptedSecrets(userId: string): Promise<void> {
    const rs = await DbService.query(
      'SELECT ai_text_key, ai_vision_key FROM user_settings WHERE user_id = ?', [userId])
    let textKey = ''
    let visionKey = ''
    try {
      if (rs.goToFirstRow()) {
        textKey = rs.getString(rs.getColumnIndex('ai_text_key'))
        visionKey = rs.getString(rs.getColumnIndex('ai_vision_key'))
      }
    } catch (_e) {
    } finally {
      try {
        rs.close()
      } catch (_e2) {
      }
    }

    const updates = new Map<string, string | number | boolean>()
    if (CryptoService.isEncryptedValue(textKey)) {
      updates.set('ai_text_key', '')
    }
    if (CryptoService.isEncryptedValue(visionKey)) {
      updates.set('ai_vision_key', '')
    }
    if (updates.size > 0) {
      await DbService.update('user_settings', updates, 'user_id = ?', [userId])
    }

    const accRs = await DbService.query(
      'SELECT id, cvv FROM credit_accounts WHERE user_id = ?', [userId])
    const ids: string[] = []
    const cvvs: string[] = []
    try {
      while (accRs.goToNextRow()) {
        ids.push(accRs.getString(accRs.getColumnIndex('id')))
        cvvs.push(accRs.getString(accRs.getColumnIndex('cvv')))
      }
    } catch (_e3) {
    } finally {
      try {
        accRs.close()
      } catch (_e4) {
      }
    }

    for (let i = 0; i < ids.length; i++) {
      if (CryptoService.isEncryptedValue(cvvs[i])) {
        const cvvUpdates = new Map<string, string | number | boolean>()
        cvvUpdates.set('cvv', '')
        await DbService.update('credit_accounts', cvvUpdates, 'id = ?', [ids[i]])
      }
    }
  }

  // ───── 内部：云端 DEK 列读写 ─────

  /** 读云端 enc_dek_wrapped / enc_dek_salt；无行或失败返回 null */
  private static async readDekColumns(userId: string, token: string): Promise<DekCloudRow | null> {
    if (userId.length === 0 || token.length === 0) {
      return null
    }
    const options = new SupabaseRestOptions(Constants.TABLE_USER_SETTINGS)
    options.select = 'enc_dek_wrapped,enc_dek_salt'
    options.filters.set('user_id', 'eq.' + userId)
    const resp = await SupabaseRestService.get(token, options)
    if (resp.error.length > 0) {
      Logger.warn(DekManager.TAG, '读取云端 DEK 列失败: ' + resp.error)
      return null
    }
    if (resp.data.length === 0) {
      return null
    }
    const first = resp.data[0] as Record<string, string | null | undefined>
    const row = new DekCloudRow()
    row.wrapped = '' + (first['enc_dek_wrapped'] ?? '')
    row.salt = '' + (first['enc_dek_salt'] ?? '')
    return row
  }

  /**
   * 写云端 DEK 列：先 PATCH 局部更新；若 0 行命中（云端行缺失）则 upsert 兜底建行。
   * 独立于同步队列，仅动 enc_dek_* 两列，不影响 SettingsTableSync 管理的其他列。
   */
  private static async writeDekColumns(userId: string, token: string,
    wrapped: string, salt: string): Promise<boolean> {
    if (userId.length === 0 || token.length === 0) {
      return false
    }
    const options = new SupabaseRestOptions(Constants.TABLE_USER_SETTINGS)
    options.select = 'user_id'
    options.filters.set('user_id', 'eq.' + userId)
    options.body = new DekPatchBody(wrapped, salt)
    options.preferReturn = 'return=representation'
    const resp = await SupabaseRestService.patch(token, options)
    if (resp.error.length > 0) {
      Logger.warn(DekManager.TAG, '写云端 DEK 列失败: ' + resp.error)
      return false
    }
    if (resp.data.length > 0) {
      return true
    }
    // PATCH 0 行命中：云端 user_settings 行尚未建立，改用 upsert 建行
    const upsertBody: object[] = [new DekUpsertBody(userId, wrapped, salt)]
    const upsertOptions = SupabaseRestService.buildUpsertOptions(Constants.TABLE_USER_SETTINGS, upsertBody)
    const upsertResp = await SupabaseRestService.post(token, upsertOptions)
    if (upsertResp.error.length > 0) {
      Logger.warn(DekManager.TAG, 'upsert 云端 DEK 列失败: ' + upsertResp.error)
      return false
    }
    return true
  }
}