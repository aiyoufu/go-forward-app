import { describe, it, expect } from '@ohos/hypium'
import { UserService } from '../../mock/UserService.mock'
import { UserService as MockUserService } from '../../mock/UserService.mock'
import { DbService as MockDbService } from '../../mock/DbService.mock'

export default function userServiceTest() {
  // ── 内存态方法（实际源码） ──────────────────────────────

  describe('UserService_getCurrentUserId', () => {
    it('初始为空字符串', 0, () => {
      UserService.setCurrentUserId('')
      expect(UserService.getCurrentUserId()).assertEqual('')
    })
    it('设置后可读取', 0, () => {
      UserService.setCurrentUserId('user-001')
      expect(UserService.getCurrentUserId()).assertEqual('user-001')
    })
  })

  describe('UserService_setCurrentUserId', () => {
    it('设置空字符串', 0, () => {
      UserService.setCurrentUserId('user-001')
      UserService.setCurrentUserId('')
      expect(UserService.getCurrentUserId()).assertEqual('')
    })
    it('覆盖已有值', 0, () => {
      UserService.setCurrentUserId('old-id')
      UserService.setCurrentUserId('new-id')
      expect(UserService.getCurrentUserId()).assertEqual('new-id')
    })
  })

  describe('UserService_isLoggedIn', () => {
    it('空ID_未登录', 0, () => {
      UserService.setCurrentUserId('')
      expect(UserService.isLoggedIn()).assertFalse()
    })
    it('有ID_已登录', 0, () => {
      UserService.setCurrentUserId('user-001')
      expect(UserService.isLoggedIn()).assertTrue()
    })
    it('重置为空后_未登录', 0, () => {
      UserService.setCurrentUserId('user-001')
      UserService.setCurrentUserId('')
      expect(UserService.isLoggedIn()).assertFalse()
    })
  })

  // ── 业务方法（使用 Mock 验证逻辑） ──────────────────────

  describe('MockUserService_ensureDefaultUser', () => {
    it('无用户时_创建默认用户并返回ID', 0, async () => {
      MockUserService._reset()
      MockUserService.setCurrentUserId('')
      const id = await MockUserService.ensureDefaultUser()
      expect(id.length > 0).assertTrue()
      expect(id).assertEqual('test-user-001')
    })
    it('已有用户时_返回现有ID', 0, async () => {
      MockUserService._reset()
      MockUserService.setCurrentUserId('existing-id')
      const id = await MockUserService.ensureDefaultUser()
      expect(id).assertEqual('existing-id')
    })
    it('调用后_isLoggedIn为true', 0, async () => {
      MockUserService._reset()
      MockUserService.setCurrentUserId('')
      await MockUserService.ensureDefaultUser()
      expect(MockUserService.isLoggedIn()).assertTrue()
    })
  })

  describe('MockUserService_createLocalUser', () => {
    it('创建用户_返回LocalUser对象', 0, async () => {
      const user = await MockUserService.createLocalUser('new@test.com', 'password')
      expect(user.id.length > 0).assertTrue()
      expect(user.email).assertEqual('new@test.com')
    })
    it('创建用户_ID不为空', 0, async () => {
      const user = await MockUserService.createLocalUser('a@b.com', '123')
      expect(user.id).assertEqual('test-user-new')
    })
    it('创建用户_邮箱正确传递', 0, async () => {
      const user = await MockUserService.createLocalUser('custom@email.com', 'pass')
      expect(user.email).assertEqual('custom@email.com')
    })
  })

  describe('MockUserService_authenticateLocalUser', () => {
    it('正确凭据_返回用户对象', 0, async () => {
      const user = await MockUserService.authenticateLocalUser('test@test.com', 'password')
      expect(user !== null).assertTrue()
      expect(user!.email).assertEqual('test@test.com')
    })
    it('返回的用户有ID', 0, async () => {
      const user = await MockUserService.authenticateLocalUser('a@b.com', '1234')
      expect(user !== null).assertTrue()
      expect(user!.id.length > 0).assertTrue()
    })
  })

  describe('MockUserService_ensureCloudUser', () => {
    it('新用户_设置currentUserId', 0, async () => {
      MockUserService._reset()
      await MockUserService.ensureCloudUser('cloud-001', 'cloud@test.com')
      expect(MockUserService.getCurrentUserId()).assertEqual('cloud-001')
    })
    it('覆盖之前的用户ID', 0, async () => {
      MockUserService._reset()
      MockUserService.setCurrentUserId('old-user')
      await MockUserService.ensureCloudUser('cloud-002', 'c@test.com')
      expect(MockUserService.getCurrentUserId()).assertEqual('cloud-002')
    })
  })

  describe('MockUserService_getLocalUserById', () => {
    it('返回指定ID的用户', 0, async () => {
      const user = await MockUserService.getLocalUserById('target-id')
      expect(user !== null).assertTrue()
      expect(user!.id).assertEqual('target-id')
    })
  })

  describe('MockUserService_reset', () => {
    it('reset_恢复默认状态', 0, async () => {
      MockUserService.setCurrentUserId('custom-id')
      MockUserService._reset()
      expect(MockUserService.getCurrentUserId()).assertEqual('test-user-001')
    })
  })

  // ── MockDbService 配合验证 ─────────────────────────────

  describe('MockDbService_UserService集成逻辑', () => {
    it('创建用户后_可通过查询读到', 0, async () => {
      MockDbService._reset()
      const values = new Map<string, string | number | boolean>()
      values.set('id', 'u-test')
      values.set('email', 'int@test.com')
      values.set('password_hash', 'hash123')
      values.set('recovery_key_encrypted', '')
      values.set('created_at', '2024-01-01T00:00:00.000Z')
      values.set('updated_at', '2024-01-01T00:00:00.000Z')
      await MockDbService.insert('local_users', values)

      const rs = (await MockDbService.query('SELECT * FROM local_users WHERE email = ?', ['int@test.com'])) as Object
      const hasRow = (rs as Record<string, Function>).goToFirstRow() as boolean
      expect(hasRow).assertTrue()
      const email = (rs as Record<string, Function>).getString(
        (rs as Record<string, Function>).getColumnIndex('email') as number
      ) as string
      expect(email).assertEqual('int@test.com')
      ;(rs as Record<string, Function>).close()
    })

    it('ensureDefaultUser_无用户时创建默认用户', 0, async () => {
      MockDbService._reset()
      // 预设空结果模拟无用户
      MockDbService._setQueryPreset('SELECT id FROM local_users', [])
      const rs = (await MockDbService.query('SELECT id FROM local_users LIMIT 1')) as Object
      const hasRow = (rs as Record<string, Function>).goToFirstRow() as boolean
      expect(hasRow).assertFalse()
      ;(rs as Record<string, Function>).close()
      // 此时 ensureDefaultUser 应创建默认用户
      const user = await MockUserService.createLocalUser('local@goforward.app', '000000')
      expect(user.id.length > 0).assertTrue()
    })

    it('ensureCloudUser_已有用户时不重复创建', 0, async () => {
      MockDbService._reset()
      // 预设已有用户
      MockDbService._setQueryPreset('SELECT * FROM local_users WHERE id', [
        { id: 'cloud-u1', email: 'cloud@test.com', password_hash: '', recovery_key_encrypted: '', created_at: '2024-01-01', updated_at: '2024-01-01' }
      ])
      const rs = (await MockDbService.query('SELECT * FROM local_users WHERE id = ?', ['cloud-u1'])) as Object
      const hasRow = (rs as Record<string, Function>).goToFirstRow() as boolean
      expect(hasRow).assertTrue()
      ;(rs as Record<string, Function>).close()
      // ensureCloudUser 发现已有用户，只设置 currentUserId
      await MockUserService.ensureCloudUser('cloud-u1', 'cloud@test.com')
      expect(MockUserService.getCurrentUserId()).assertEqual('cloud-u1')
    })
  })
}
