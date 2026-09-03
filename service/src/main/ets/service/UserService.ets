import { relationalStore } from '@kit.ArkData'
import { DbService } from './DbService'
import { Utils } from 'common'
import { CryptoService } from './auth/CryptoService'

export class LocalUser {
  id: string = ''
  email: string = ''
  passwordHash: string = ''
  recoveryKeyEncrypted: string = ''
  createdAt: string = ''
  updatedAt: string = ''
}

export class UserService {
  private static currentUserId: string = ''

  static getCurrentUserId(): string {
    return UserService.currentUserId
  }

  static setCurrentUserId(id: string): void {
    UserService.currentUserId = id
  }

  static isLoggedIn(): boolean {
    return UserService.currentUserId.length > 0
  }

  static async createLocalUser(email: string, password: string): Promise<LocalUser> {
    const id = Utils.generateId()
    const salt = CryptoService.randomBytes(16)
    const passwordHash = await CryptoService.hashPin(password, salt)
    const now = DbService.now()

    const values = new Map<string, string | number | boolean>()
    values.set('id', id)
    values.set('email', email)
    values.set('password_hash', passwordHash)
    values.set('recovery_key_encrypted', '')
    values.set('created_at', now)
    values.set('updated_at', now)

    await DbService.insert('local_users', values)

    const user = new LocalUser()
    user.id = id
    user.email = email
    user.passwordHash = passwordHash
    user.createdAt = now
    user.updatedAt = now
    return user
  }

  static async authenticateLocalUser(email: string, password: string): Promise<LocalUser | null> {
    const rs = await DbService.query(
      'SELECT * FROM local_users WHERE email = ?',
      [email]
    )
    let hasRow = false
    try {
      hasRow = rs.goToFirstRow()
    } catch (_e) {
    }
    if (!hasRow) {
      try {
        rs.close()
      } catch (_e2) {
      }
      return null
    }
    let storedHash = ''
    try {
      storedHash = rs.getString(rs.getColumnIndex('password_hash'))
    } catch (_e3) {
    }
    const ok = await CryptoService.verifyPin(password, storedHash)
    if (!ok) {
      try {
        rs.close()
      } catch (_e4) {
      }
      return null
    }
    const user = UserService.rowToLocalUser(rs)
    try {
      rs.close()
    } catch (_e5) {
    }
    UserService.setCurrentUserId(user.id)
    return user
  }

  static async getLocalUserById(id: string): Promise<LocalUser | null> {
    const rs = await DbService.query(
      'SELECT * FROM local_users WHERE id = ?',
      [id]
    )
    let hasRow = false
    try {
      hasRow = rs.goToFirstRow()
    } catch (_e) {
    }
    if (!hasRow) {
      try {
        rs.close()
      } catch (_e2) {
      }
      return null
    }
    const user = UserService.rowToLocalUser(rs)
    try {
      rs.close()
    } catch (_e3) {
    }
    return user
  }

  static async ensureDefaultUser(): Promise<string> {
    const rs = await DbService.query('SELECT id FROM local_users LIMIT 1')
    let id = ''
    try {
      if (rs.goToFirstRow()) {
        id = rs.getString(rs.getColumnIndex('id'))
      }
    } catch (_e) {
    }
    try {
      rs.close()
    } catch (_e2) {
    }
    if (id.length === 0) {
      const user = await UserService.createLocalUser('local@goforward.app', '000000')
      id = user.id
    }
    UserService.setCurrentUserId(id)
    return id
  }

  static async ensureCloudUser(userId: string, email: string): Promise<void> {
    const existing = await UserService.getLocalUserById(userId)
    if (existing) {
      UserService.setCurrentUserId(userId)
      return
    }

    const now = DbService.now()
    const values = new Map<string, string | number | boolean>()
    values.set('id', userId)
    values.set('email', email)
    values.set('password_hash', '')
    values.set('recovery_key_encrypted', '')
    values.set('created_at', now)
    values.set('updated_at', now)

    await DbService.insert('local_users', values)
    UserService.setCurrentUserId(userId)
  }

  private static rowToLocalUser(rs: relationalStore.ResultSet): LocalUser {
    const user = new LocalUser()
    try {
      user.id = rs.getString(rs.getColumnIndex('id'))
    } catch (_e) {
    }
    try {
      user.email = rs.getString(rs.getColumnIndex('email'))
    } catch (_e2) {
    }
    try {
      user.passwordHash = rs.getString(rs.getColumnIndex('password_hash'))
    } catch (_e3) {
    }
    try {
      user.recoveryKeyEncrypted = rs.getString(rs.getColumnIndex('recovery_key_encrypted'))
    } catch (_e4) {
    }
    try {
      user.createdAt = rs.getString(rs.getColumnIndex('created_at'))
    } catch (_e5) {
    }
    try {
      user.updatedAt = rs.getString(rs.getColumnIndex('updated_at'))
    } catch (_e6) {
    }
    return user
  }
}

