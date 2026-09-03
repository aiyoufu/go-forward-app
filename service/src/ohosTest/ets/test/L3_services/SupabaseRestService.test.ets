import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { SupabaseRestService, SupabaseRestOptions, SupabaseRestResponse } from '../../../../main/ets/service/SupabaseRestService'

export default function supabaseRestServiceTest() {
  // ── buildUpsertOptions ──────────────────────────────
  describe('SupabaseRestService_buildUpsertOptions', () => {
    it('构建upsert选项_包含body', 0, async () => {
      const records = [{ id: '1', name: 'test' }, { id: '2', name: 'test2' }]
      const options = SupabaseRestService.buildUpsertOptions('debts', records)
      expect(options.table).assertEqual('debts')
      expect(options.body !== null).assertTrue()
      expect(options.preferReturn.indexOf('merge-duplicates') >= 0).assertTrue()
      expect(options.preferReturn.indexOf('return=representation') >= 0).assertTrue()
    })

    it('空记录_也正常构建', 0, async () => {
      const options = SupabaseRestService.buildUpsertOptions('debts', [])
      expect(options.table).assertEqual('debts')
      expect(options.body !== null).assertTrue()
    })
  })

  // ── SupabaseRestOptions 构造 ──────────────────────────
  describe('SupabaseRestOptions_constructor', () => {
    it('默认构造_空table', 0, async () => {
      const opt = new SupabaseRestOptions()
      expect(opt.table).assertEqual('')
      expect(opt.select).assertEqual('*')
      expect(opt.preferReturn).assertEqual('representation')
    })

    it('带table构造', 0, async () => {
      const opt = new SupabaseRestOptions('debts')
      expect(opt.table).assertEqual('debts')
    })

    it('filters可设置', 0, async () => {
      const opt = new SupabaseRestOptions('debts')
      opt.filters.set('user_id', 'eq.u001')
      expect(opt.filters.get('user_id')).assertEqual('eq.u001')
    })
  })

  // ── SupabaseRestResponse 构造 ──────────────────────────
  describe('SupabaseRestResponse_constructor', () => {
    it('默认构造', 0, async () => {
      const resp = new SupabaseRestResponse()
      expect(resp.status).assertEqual(0)
      expect(resp.data.length).assertEqual(0)
      expect(resp.error).assertEqual('')
    })

    it('带参构造', 0, async () => {
      const resp = new SupabaseRestResponse(200, [{ id: 1 }], '')
      expect(resp.status).assertEqual(200)
      expect(resp.data.length).assertEqual(1)
    })

    it('错误响应', 0, async () => {
      const resp = new SupabaseRestResponse(400, [], 'Bad Request')
      expect(resp.status).assertEqual(400)
      expect(resp.error).assertEqual('Bad Request')
    })
  })

  // ── 私有方法通过 any 访问（测试纯逻辑）─────────────────
  describe('SupabaseRestService_buildQuery_纯逻辑', () => {
    it('默认select_生成select=*', 0, async () => {
      const opt = new SupabaseRestOptions('debts')
      const fn = (SupabaseRestService as Object as Record<string, Function>)['buildQuery']
      const query = fn(opt) as string
      expect(query.indexOf('select=') >= 0).assertTrue()
      expect(query.indexOf('*') >= 0).assertTrue()
    })

    it('含filters_生成多参数', 0, async () => {
      const opt = new SupabaseRestOptions('debts')
      opt.filters.set('user_id', 'eq.u001')
      const fn = (SupabaseRestService as Object as Record<string, Function>)['buildQuery']
      const query = fn(opt) as string
      expect(query.indexOf('user_id') >= 0).assertTrue()
      expect(query.indexOf('eq.u001') >= 0).assertTrue()
    })
  })

  describe('SupabaseRestService_parseArray_纯逻辑', () => {
    it('空字符串_返回空数组', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['parseArray']
      const result = fn('') as object[]
      expect(result.length).assertEqual(0)
    })

    it('JSON数组_返回数组', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['parseArray']
      const result = fn('[{"id":1},{"id":2}]') as object[]
      expect(result.length).assertEqual(2)
    })

    it('JSON对象_包装为数组', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['parseArray']
      const result = fn('{"id":1}') as object[]
      expect(result.length).assertEqual(1)
    })

    it('非法JSON_返回空数组', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['parseArray']
      const result = fn('not json') as object[]
      expect(result.length).assertEqual(0)
    })

    it('null JSON_返回空数组', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['parseArray']
      const result = fn('null') as object[]
      expect(result.length).assertEqual(0)
    })
  })

  describe('SupabaseRestService_pickError_纯逻辑', () => {
    it('空数组_返回默认', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['pickError']
      const result = fn([]) as string
      expect(result).assertEqual('请求失败')
    })

    it('含message字段_返回message', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['pickError']
      const result = fn([{ message: 'Not found' }]) as string
      expect(result).assertEqual('Not found')
    })

    it('含error字段_返回error', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['pickError']
      const result = fn([{ error: 'Bad request' }]) as string
      expect(result).assertEqual('Bad request')
    })

    it('无message/error_返回默认', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['pickError']
      const result = fn([{ id: 1 }]) as string
      expect(result).assertEqual('请求失败')
    })

    it('message优先于error', 0, async () => {
      const fn = (SupabaseRestService as Object as Record<string, Function>)['pickError']
      const result = fn([{ message: 'msg', error: 'err' }]) as string
      expect(result).assertEqual('msg')
    })
  })
}
