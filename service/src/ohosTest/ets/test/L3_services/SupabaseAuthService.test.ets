import { describe, it, expect, beforeEach } from '@ohos/hypium'
import {
  SupabaseAuthService,
  AuthSession,
  AuthResult,
  SignInRequest,
  SignUpRequest,
  RecoverRequest,
  RefreshTokenRequest,
  SupabaseAuthResponse
} from '../../../../main/ets/service/auth/SupabaseAuthService'

export default function supabaseAuthServiceTest() {
  // ── 数据类构造 ──────────────────────────────────────
  describe('AuthSession_constructor', () => {
    it('默认构造', 0, async () => {
      const s = new AuthSession()
      expect(s.accessToken).assertEqual('')
      expect(s.refreshToken).assertEqual('')
      expect(s.userId).assertEqual('')
      expect(s.email).assertEqual('')
    })

    it('带参构造', 0, async () => {
      const s = new AuthSession('at', 'rt', 'uid', 'em')
      expect(s.accessToken).assertEqual('at')
      expect(s.refreshToken).assertEqual('rt')
      expect(s.userId).assertEqual('uid')
      expect(s.email).assertEqual('em')
    })
  })

  describe('AuthResult_constructor', () => {
    it('默认构造_失败', 0, async () => {
      const r = new AuthResult()
      expect(r.success).assertFalse()
      expect(r.error).assertEqual('')
    })

    it('带参构造_成功', 0, async () => {
      const s = new AuthSession('at', 'rt', 'uid', 'em')
      const r = new AuthResult(true, s, '')
      expect(r.success).assertTrue()
      expect(r.session.accessToken).assertEqual('at')
    })
  })

  describe('SignInRequest_constructor', () => {
    it('带参构造', 0, async () => {
      const r = new SignInRequest('test@test.com', 'pass123')
      expect(r.email).assertEqual('test@test.com')
      expect(r.password).assertEqual('pass123')
    })
  })

  describe('SignUpRequest_constructor', () => {
    it('带参构造', 0, async () => {
      const r = new SignUpRequest('test@test.com', 'pass123')
      expect(r.email).assertEqual('test@test.com')
      expect(r.password).assertEqual('pass123')
    })
  })

  describe('RecoverRequest_constructor', () => {
    it('带参构造', 0, async () => {
      const r = new RecoverRequest('test@test.com')
      expect(r.email).assertEqual('test@test.com')
    })
  })

  describe('RefreshTokenRequest_constructor', () => {
    it('带参构造', 0, async () => {
      const r = new RefreshTokenRequest('token123')
      expect(r.refresh_token).assertEqual('token123')
    })
  })

  // ── pickError（私有纯逻辑）──────────────────────────
  describe('SupabaseAuthService_pickError_纯逻辑', () => {
    it('error_description优先', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['pickError']
      const resp = new SupabaseAuthResponse()
      resp.error_description = '描述错误'
      resp.message = '消息'
      resp.error = '错误码'
      const result = fn(resp) as string
      expect(result).assertEqual('描述错误')
    })

    it('message次之', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['pickError']
      const resp = new SupabaseAuthResponse()
      resp.message = '消息'
      resp.error = '错误码'
      const result = fn(resp) as string
      expect(result).assertEqual('消息')
    })

    it('msg再次', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['pickError']
      const resp = new SupabaseAuthResponse()
      resp.msg = 'msg信息'
      resp.error = '错误码'
      const result = fn(resp) as string
      expect(result).assertEqual('msg信息')
    })

    it('error兜底', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['pickError']
      const resp = new SupabaseAuthResponse()
      resp.error = '错误码'
      const result = fn(resp) as string
      expect(result).assertEqual('错误码')
    })

    it('全部为空_返回默认', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['pickError']
      const resp = new SupabaseAuthResponse()
      const result = fn(resp) as string
      expect(result).assertEqual('请求失败')
    })
  })

  // ── parseJson（私有纯逻辑）──────────────────────────
  describe('SupabaseAuthService_parseJson_纯逻辑', () => {
    it('空字符串_返回空响应', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['parseJson']
      const result = fn('') as SupabaseAuthResponse
      expect(result.access_token).assertEqual('')
    })

    it('有效JSON_解析字段', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['parseJson']
      const json = JSON.stringify({
        access_token: 'at123',
        refresh_token: 'rt456',
        user: { id: 'uid', email: 'test@test.com' }
      })
      const result = fn(json) as SupabaseAuthResponse
      expect(result.access_token).assertEqual('at123')
      expect(result.refresh_token).assertEqual('rt456')
      expect(result.user.id).assertEqual('uid')
    })

    it('非法JSON_返回空响应', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['parseJson']
      const result = fn('not json') as SupabaseAuthResponse
      expect(result.access_token).assertEqual('')
    })

    it('null JSON_返回空响应', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['parseJson']
      const result = fn('null') as SupabaseAuthResponse
      expect(result.access_token).assertEqual('')
    })

    it('含error字段_正确解析', 0, async () => {
      const fn = (SupabaseAuthService as Object as Record<string, Function>)['parseJson']
      const json = JSON.stringify({ error: 'invalid_grant', error_description: '密码错误' })
      const result = fn(json) as SupabaseAuthResponse
      expect(result.error).assertEqual('invalid_grant')
      expect(result.error_description).assertEqual('密码错误')
    })
  })

  // ── refresh 空token快速路径 ──────────────────────────
  describe('SupabaseAuthService_refresh_空token', () => {
    it('空refreshToken_返回错误', 0, async () => {
      const result = await SupabaseAuthService.refresh('')
      expect(result.success).assertFalse()
      expect(result.error).assertEqual('无刷新令牌')
    })
  })

  describe('SupabaseAuthService_parseUserMetadata', () => {
    it('GET /user 顶层 user_metadata', 0, () => {
      const json = JSON.stringify({
        id: 'uid',
        email: 'a@b.com',
        user_metadata: { nickname: '爱国者', avatar_data_url: 'data:image/jpeg;base64,abc' }
      })
      const p = SupabaseAuthService.parseUserMetadata(json)
      expect(p.nickname).assertEqual('爱国者')
      expect(p.avatar_data_url).assertEqual('data:image/jpeg;base64,abc')
    })

    it('token 响应嵌套 user.user_metadata', 0, () => {
      const json = JSON.stringify({
        access_token: 'at',
        user: { id: 'uid', user_metadata: { nickname: '阿豪' } }
      })
      const p = SupabaseAuthService.parseUserMetadata(json)
      expect(p.nickname).assertEqual('阿豪')
    })

    it('空串返回空资料', 0, () => {
      const p = SupabaseAuthService.parseUserMetadata('')
      expect(p.nickname).assertEqual('')
      expect(p.avatar_data_url).assertEqual('')
    })
  })
}
