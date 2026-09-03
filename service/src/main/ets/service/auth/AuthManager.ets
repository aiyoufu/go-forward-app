import { PreferencesService } from '../PreferencesService'
import { SecureStore } from './SecureStore'
import { Logger } from 'common'
import { AppStorageKeys } from 'common'
import { UserService } from '../UserService'
import { SupabaseAuthService, AuthSession, AuthResult } from './SupabaseAuthService'
import { DbService } from '../DbService'
import { DekManager } from './DekManager'
import { AnalyticsService } from '../AnalyticsService'
import { SettingsService } from '../SettingsService'
import { SettingsAiBackup } from '../SettingsAiBackup'
import { LocalDataStore } from '../sync/LocalDataStore'
import { HomeSnapshotStore } from '../sync/HomeSnapshotStore'

export type AuthMode = 'local' | 'cloud'

export class AuthState {
  mode: AuthMode = 'local'
  userId: string = ''
  email: string = ''
  accessToken: string = ''
  refreshToken: string = ''

  constructor(mode: AuthMode = 'local', userId: string = '', email: string = '',
    accessToken: string = '', refreshToken: string = '') {
    this.mode = mode
    this.userId = userId
    this.email = email
    this.accessToken = accessToken
    this.refreshToken = refreshToken
  }
}

export class AuthOperationResult {
  success: boolean = false
  error: string = ''

  constructor(success: boolean = false, error: string = '') {
    this.success = success
    this.error = error
  }
}

export class AuthManager {
  static readonly KEY_MODE: string = 'auth_mode'
  static readonly KEY_USER_ID: string = 'auth_user_id'
  static readonly KEY_EMAIL: string = 'auth_email'
  static readonly KEY_ACCESS_TOKEN: string = 'auth_access_token'
  static readonly KEY_REFRESH_TOKEN: string = 'auth_refresh_token'

  static async saveCloudSession(session: AuthSession): Promise<void> {
    const oldUserId = UserService.getCurrentUserId()
    const newUserId = session.userId

    await UserService.ensureCloudUser(session.userId, session.email)

    if (oldUserId.length > 0 && oldUserId !== newUserId) {
      await AuthManager.migrateUserData(oldUserId, newUserId)
    }

    await PreferencesService.putString(AuthManager.KEY_MODE, 'cloud')
    await PreferencesService.putString(AuthManager.KEY_USER_ID, session.userId)
    await PreferencesService.putString(AuthManager.KEY_EMAIL, session.email)
    // token 属敏感凭据，写入关键资产（系统加密）而非明文 Preferences
    await SecureStore.putString(AuthManager.KEY_ACCESS_TOKEN, session.accessToken)
    await SecureStore.putString(AuthManager.KEY_REFRESH_TOKEN, session.refreshToken)
    // 内存态必须与云会话一致，否则后续 getSettings/sync 会落到错误 userId
    UserService.setCurrentUserId(session.userId)
    // 换号或登录后清空进程内缓存，避免读到上一用户投影/设置
    if (oldUserId !== newUserId) {
      SettingsService.clearCache()
      LocalDataStore.invalidateAll()
    }
    await PreferencesService.flush()
  }

  static async migrateUserData(oldUserId: string, newUserId: string): Promise<void> {
    const tables = [
      'user_settings',
      'credit_accounts',
      'debts',
      'payment_records',
      'subscriptions',
      'notifications',
      'achievement_cards',
      'sync_queue',
      'sync_state'
    ]
    for (const table of tables) {
      try {
        if (table === 'user_settings') {
          const rs = await DbService.query('SELECT user_id FROM user_settings WHERE user_id = ?', [newUserId])
          const exists = rs.goToFirstRow()
          rs.close()
          if (!exists) {
            await DbService.executeSql('UPDATE user_settings SET user_id = ? WHERE user_id = ?', [newUserId, oldUserId])
          } else {
            await DbService.executeSql('DELETE FROM user_settings WHERE user_id = ?', [oldUserId])
          }
        } else if (table === 'sync_state') {
          await DbService.executeSql('UPDATE sync_state SET user_id = ? WHERE user_id = ?', [newUserId, oldUserId])
        } else {
          await DbService.executeSql(`UPDATE ${table} SET user_id = ? WHERE user_id = ?`, [newUserId, oldUserId])
        }
      } catch (err) {
        Logger.error('AuthManager', `Failed to migrate table ${table}: ${JSON.stringify(err)}`)
      }
    }
  }

  static async saveLocalSession(userId: string): Promise<void> {
    await PreferencesService.putString(AuthManager.KEY_MODE, 'local')
    await PreferencesService.putString(AuthManager.KEY_USER_ID, userId)
    await PreferencesService.putString(AuthManager.KEY_EMAIL, '')
    await SecureStore.remove(AuthManager.KEY_ACCESS_TOKEN)
    await SecureStore.remove(AuthManager.KEY_REFRESH_TOKEN)
    UserService.setCurrentUserId(userId)
    SettingsService.clearCache()
    LocalDataStore.invalidateAll()
    await PreferencesService.flush()
  }

  static async loadSession(): Promise<AuthState | null> {
    const modeValue = await PreferencesService.getString(AuthManager.KEY_MODE, '')
    const mode = modeValue === 'cloud' ? 'cloud' : (modeValue === 'local' ? 'local' : '')
    if (mode.length === 0) {
      return null
    }

    const userId = await PreferencesService.getString(AuthManager.KEY_USER_ID, '')
    const email = await PreferencesService.getString(AuthManager.KEY_EMAIL, '')
    await AuthManager.migrateLegacyTokens()
    const accessToken = await SecureStore.getString(AuthManager.KEY_ACCESS_TOKEN)
    const refreshToken = await SecureStore.getString(AuthManager.KEY_REFRESH_TOKEN)

    if (userId.length === 0) {
      return null
    }

    UserService.setCurrentUserId(userId)
    return new AuthState(mode as AuthMode, userId, email, accessToken, refreshToken)
  }

  /** 历史版本把 token 明文存在 Preferences，首次加载时迁入关键资产并抹除明文 */
  private static async migrateLegacyTokens(): Promise<void> {
    const legacyAccess = await PreferencesService.getString(AuthManager.KEY_ACCESS_TOKEN, '')
    const legacyRefresh = await PreferencesService.getString(AuthManager.KEY_REFRESH_TOKEN, '')
    if (legacyAccess.length === 0 && legacyRefresh.length === 0) {
      return
    }
    if (legacyAccess.length > 0) {
      await SecureStore.putString(AuthManager.KEY_ACCESS_TOKEN, legacyAccess)
    }
    if (legacyRefresh.length > 0) {
      await SecureStore.putString(AuthManager.KEY_REFRESH_TOKEN, legacyRefresh)
    }
    await PreferencesService.delete(AuthManager.KEY_ACCESS_TOKEN)
    await PreferencesService.delete(AuthManager.KEY_REFRESH_TOKEN)
    await PreferencesService.flush()
  }

  static async clearSession(): Promise<void> {
    await PreferencesService.delete(AuthManager.KEY_MODE)
    await PreferencesService.delete(AuthManager.KEY_USER_ID)
    await PreferencesService.delete(AuthManager.KEY_EMAIL)
    await PreferencesService.delete(AuthManager.KEY_ACCESS_TOKEN)
    await PreferencesService.delete(AuthManager.KEY_REFRESH_TOKEN)
    await PreferencesService.flush()
    await SecureStore.remove(AuthManager.KEY_ACCESS_TOKEN)
    await SecureStore.remove(AuthManager.KEY_REFRESH_TOKEN)
    // 清除本机 DEK 缓存，防止登出后残留可解密凭证的密钥
    await DekManager.clearActiveDek()
    const uid = UserService.getCurrentUserId()
    UserService.setCurrentUserId('')
    SettingsService.clearCache()
    try {
      await SettingsAiBackup.clear(uid)
    } catch (_e) {
    }
    LocalDataStore.invalidateAll()
    await LocalDataStore.clearDashboardFrame(uid)
    await HomeSnapshotStore.clear(uid)
    AppStorage.setOrCreate(AppStorageKeys.MAIN_TAB_INDEX, 0)
  }

  static async signInCloud(email: string, password: string): Promise<AuthOperationResult> {
    const result: AuthResult = await SupabaseAuthService.signIn(email, password)
    if (result.success) {
      await AuthManager.saveCloudSession(result.session)
      await AuthManager.unlockDek(result.session.userId, result.session.accessToken, password)
      AnalyticsService.trackAuthSuccess('login')
      return new AuthOperationResult(true, '')
    }
    AnalyticsService.trackAuthFail('login', result.error)
    return new AuthOperationResult(false, result.error)
  }

  static async signUpCloud(email: string, password: string): Promise<AuthOperationResult> {
    const result: AuthResult = await SupabaseAuthService.signUp(email, password)
    if (result.success) {
      await AuthManager.saveCloudSession(result.session)
      await AuthManager.unlockDek(result.session.userId, result.session.accessToken, password)
      AnalyticsService.trackAuthSuccess('register')
      return new AuthOperationResult(true, '')
    }
    AnalyticsService.trackAuthFail('register', result.error)
    return new AuthOperationResult(false, result.error)
  }

  /** 解锁 DEK：失败仅告警，不阻断登录/注册主流程 */
  private static async unlockDek(userId: string, token: string, password: string): Promise<void> {
    try {
      await DekManager.unlockDekOnLogin(userId, token, password)
    } catch (err) {
      Logger.warn('AuthManager', 'DEK 解锁失败: ' + JSON.stringify(err))
    }
  }

  static async recoverPassword(email: string): Promise<AuthOperationResult> {
    const result: AuthResult = await SupabaseAuthService.recover(email)
    if (result.success) {
      return new AuthOperationResult(true, '')
    }
    return new AuthOperationResult(false, result.error)
  }

  static async resetPasswordWithCode(code: string, newPassword: string): Promise<AuthOperationResult> {
    const verify: AuthResult = await SupabaseAuthService.verifyRecovery(code)
    if (!verify.success) {
      return new AuthOperationResult(false, verify.error)
    }
    const update: AuthResult = await SupabaseAuthService.updateUser(
      verify.session.accessToken, newPassword)
    if (!update.success) {
      return new AuthOperationResult(false, update.error)
    }
    return new AuthOperationResult(true, '')
  }

  /**
   * 登录态修改账户密码：旧密码静默 signIn 验证身份，通过后调 updateUser。
   * 验证失败不触碰现有会话；成功后保存验证产生的新会话（改密响应不含新 token）。
   */
  static async changePassword(oldPassword: string, newPassword: string): Promise<AuthOperationResult> {
    const current = await AuthManager.loadSession()
    if (current === null || current.email.length === 0) {
      return new AuthOperationResult(false, '会话已失效，请重新登录')
    }
    const verify: AuthResult = await SupabaseAuthService.signIn(current.email, oldPassword)
    if (!verify.success) {
      const err = verify.error
      const badCred = err.indexOf('Invalid login credentials') >= 0 ||
        err.indexOf('invalid_credentials') >= 0 ||
        err.indexOf('邮箱或密码错误') >= 0
      const msg = badCred ? '旧密码错误' : err
      return new AuthOperationResult(false, msg)
    }
    const update: AuthResult = await SupabaseAuthService.updateUser(verify.session.accessToken, newPassword)
    if (!update.success) {
      return new AuthOperationResult(false, update.error)
    }
    await AuthManager.saveCloudSession(verify.session)
    // 用新密码重新包裹当前 DEK 回写云端；失败靠下次登录自愈，不阻断改密结果
    try {
      await DekManager.rewrapDekWithPassword(verify.session.userId, verify.session.accessToken, newPassword)
    } catch (err) {
      Logger.warn('AuthManager', 'DEK 重新包裹失败: ' + JSON.stringify(err))
    }
    return new AuthOperationResult(true, '')
  }

  static async signOut(): Promise<void> {
    await AuthManager.clearSession()
  }

  /**
   * 刷新云端 access_token；成功则写回关键资产并更新内存。
   * 若服务端明确拒绝刷新令牌（他端改密吊销等），清除本地会话并广播踢出信号。
   * @returns 新的 AuthState；失败返回 null
   */
  static async refreshCloudSession(): Promise<AuthState | null> {
    const current = await AuthManager.loadSession()
    if (current === null || current.mode !== 'cloud' || current.refreshToken.length === 0) {
      return null
    }
    const result = await SupabaseAuthService.refresh(current.refreshToken)
    if (!result.success || result.session.accessToken.length === 0) {
      if (result.sessionRevoked) {
        await AuthManager.onSessionRevoked()
      }
      return null
    }
    // 保留原 userId/email（refresh 响应里 user 可能为空）
    const session = result.session
    if (session.userId.length === 0) {
      session.userId = current.userId
    }
    if (session.email.length === 0) {
      session.email = current.email
    }
    await SecureStore.putString(AuthManager.KEY_ACCESS_TOKEN, session.accessToken)
    if (session.refreshToken.length > 0) {
      await SecureStore.putString(AuthManager.KEY_REFRESH_TOKEN, session.refreshToken)
    }
    return new AuthState('cloud', session.userId, session.email, session.accessToken,
      session.refreshToken.length > 0 ? session.refreshToken : current.refreshToken)
  }

  /**
   * 主动校验云会话是否仍有效（进首页/回前台调用）：
   * 他端改密后 GoTrue 会吊销本机 session，即使 JWT 未过期也能在此及时发现。
   * 网络错误不误踢；仅当 getUser 被拒且 refresh 也被明确拒绝时才踢出。
   */
  static async validateCloudSession(): Promise<void> {
    const current = await AuthManager.loadSession()
    if (current === null || current.mode !== 'cloud' || current.accessToken.length === 0) {
      return
    }
    const check = await SupabaseAuthService.getUser(current.accessToken)
    if (check.success || !check.sessionRevoked) {
      return
    }
    // token 被拒：可能只是 JWT 过期，交给 refresh 判定；若 refresh 也被拒内部会踢出
    await AuthManager.refreshCloudSession()
  }

  /** 会话被服务端吊销：清本地会话，广播令牌由 MainPage 踢回登录页 */
  private static async onSessionRevoked(): Promise<void> {
    Logger.warn('AuthManager', '云会话已被服务端吊销（他端改密等），清除本地会话')
    await AuthManager.clearSession()
    AppStorage.setOrCreate(AppStorageKeys.SESSION_REVOKED_TOKEN, Date.now())
  }
}
