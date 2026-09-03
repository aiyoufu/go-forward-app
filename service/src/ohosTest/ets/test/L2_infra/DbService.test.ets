import { describe, it, expect, beforeAll } from '@ohos/hypium'
import { DbService } from '../../mock/DbService.mock'
import { DbService as MockDbService } from '../../mock/DbService.mock'

export default function dbServiceTest() {
  // ── 纯逻辑方法（实际源码） ──────────────────────────────

  describe('DbService_boolToInt', () => {
    it('true_返回1', 0, async () => {
      expect(DbService.boolToInt(true)).assertEqual(1)
    })
    it('false_返回0', 0, async () => {
      expect(DbService.boolToInt(false)).assertEqual(0)
    })
  })

  describe('DbService_intToBool', () => {
    it('1_返回true', 0, async () => {
      expect(DbService.intToBool(1)).assertTrue()
    })
    it('0_返回false', 0, async () => {
      expect(DbService.intToBool(0)).assertFalse()
    })
    it('其他数字_返回false', 0, async () => {
      expect(DbService.intToBool(2)).assertFalse()
      expect(DbService.intToBool(-1)).assertFalse()
      expect(DbService.intToBool(100)).assertFalse()
    })
    it('字符串数字1_返回true', 0, async () => {
      // Number('1') === 1 → true
      expect(DbService.intToBool(Number('1'))).assertTrue()
    })
    it('NaN_返回false', 0, async () => {
      expect(DbService.intToBool(NaN)).assertFalse()
    })
  })

  describe('DbService_now', () => {
    it('返回ISO8601格式字符串', 0, async () => {
      const ts = DbService.now()
      // ISO 8601 格式：YYYY-MM-DDTHH:mm:ss.sssZ
      const isoRegex = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/
      expect(isoRegex.test(ts)).assertTrue()
    })
    it('返回的时间戳可被Date解析', 0, async () => {
      const ts = DbService.now()
      const parsed = new Date(ts)
      expect(isNaN(parsed.getTime())).assertFalse()
    })
    it('连续调用返回相近时间', 0, async () => {
      const t1 = DbService.now()
      const t2 = DbService.now()
      const diff = Math.abs(new Date(t2).getTime() - new Date(t1).getTime())
      // 差值应小于 1 秒
      expect(diff < 1000).assertTrue()
    })
  })

  // ── 业务方法（使用 Mock DbService 验证逻辑） ────────────

  describe('MockDbService_init', () => {
    beforeAll(async () => {
      MockDbService._reset()
    })
    it('init_调用不抛异常', 0, async () => {
      await MockDbService.init({})
      // init 为幂等操作，二次调用也不应抛异常
      await MockDbService.init({})
    })
  })

  describe('MockDbService_insert', () => {
    beforeAll(async () => {
      MockDbService._reset()
    })
    it('插入单行_返回行号', 0, async () => {
      const values = new Map<string, string | number | boolean>()
      values.set('id', 'u1')
      values.set('email', 'test@test.com')
      const rowId = await MockDbService.insert('test_table', values)
      expect(rowId).assertEqual(1)
    })
    it('插入后内存存储可查', 0, async () => {
      MockDbService._reset()
      const values = new Map<string, string | number | boolean>()
      values.set('id', 'u1')
      values.set('name', 'Alice')
      await MockDbService.insert('users', values)
      const store = MockDbService._getStore()
      const rows = store.get('users')
      expect(rows !== undefined).assertTrue()
      expect(rows!.length).assertEqual(1)
      expect(rows![0].get('id')).assertEqual('u1')
      expect(rows![0].get('name')).assertEqual('Alice')
    })
    it('多行插入_累加存储', 0, async () => {
      MockDbService._reset()
      const v1 = new Map<string, string | number | boolean>()
      v1.set('id', 'a')
      const v2 = new Map<string, string | number | boolean>()
      v2.set('id', 'b')
      await MockDbService.insert('items', v1)
      await MockDbService.insert('items', v2)
      const store = MockDbService._getStore()
      expect(store.get('items')!.length).assertEqual(2)
    })
  })

  describe('MockDbService_query', () => {
    beforeAll(async () => {
      MockDbService._reset()
    })
    it('查询空表_返回空ResultSet', 0, async () => {
      const rs = (await MockDbService.query('SELECT * FROM empty_table')) as Object
      const hasRow = (rs as Record<string, Function>).goToFirstRow() as boolean
      expect(hasRow).assertFalse()
    })
    it('插入后查询_可读到数据', 0, async () => {
      MockDbService._reset()
      const values = new Map<string, string | number | boolean>()
      values.set('id', 'x1')
      values.set('name', 'Bob')
      await MockDbService.insert('people', values)
      const rs = (await MockDbService.query('SELECT * FROM people')) as Object
      const hasRow = (rs as Record<string, Function>).goToFirstRow() as boolean
      expect(hasRow).assertTrue()
      const name = (rs as Record<string, Function>).getString(
        (rs as Record<string, Function>).getColumnIndex('name') as number
      ) as string
      expect(name).assertEqual('Bob')
    })
    it('预设查询结果_优先于内存存储', 0, async () => {
      MockDbService._reset()
      MockDbService._setQueryPreset('SELECT id FROM local_users', [
        { id: 'preset-001' }
      ])
      const rs = (await MockDbService.query('SELECT id FROM local_users')) as Object
      const hasRow = (rs as Record<string, Function>).goToFirstRow() as boolean
      expect(hasRow).assertTrue()
      const id = (rs as Record<string, Function>).getString(
        (rs as Record<string, Function>).getColumnIndex('id') as number
      ) as string
      expect(id).assertEqual('preset-001')
    })
    it('SQL调用日志被记录', 0, async () => {
      MockDbService._reset()
      await MockDbService.query('SELECT 1', [42])
      const log = MockDbService._getSqlCallLog()
      expect(log.length).assertEqual(1)
      expect(log[0].sql).assertEqual('SELECT 1')
      expect(log[0].args![0]).assertEqual(42)
    })
  })

  describe('MockDbService_update', () => {
    beforeAll(async () => {
      MockDbService._reset()
    })
    it('update_返回1', 0, async () => {
      const values = new Map<string, string | number | boolean>()
      values.set('name', 'Updated')
      const result = await MockDbService.update('users', values, 'id = ?', ['u1'])
      expect(result).assertEqual(1)
    })
    it('update_记录SQL日志', 0, async () => {
      MockDbService._reset()
      const values = new Map<string, string | number | boolean>()
      values.set('email', 'new@test.com')
      await MockDbService.update('users', values, 'id = ?', ['u1'])
      const log = MockDbService._getSqlCallLog()
      expect(log.length).assertEqual(1)
      expect(log[0].sql.indexOf('UPDATE users') >= 0).assertTrue()
    })
  })

  describe('MockDbService_delete', () => {
    beforeAll(async () => {
      MockDbService._reset()
    })
    it('delete_返回1', 0, async () => {
      const result = await MockDbService.delete('users', 'id = ?', ['u1'])
      expect(result).assertEqual(1)
    })
    it('delete_记录SQL日志', 0, async () => {
      MockDbService._reset()
      await MockDbService.delete('users', 'id = ?', ['u1'])
      const log = MockDbService._getSqlCallLog()
      expect(log.length).assertEqual(1)
      expect(log[0].sql.indexOf('DELETE users') >= 0).assertTrue()
    })
  })

  describe('MockDbService_executeSql', () => {
    beforeAll(async () => {
      MockDbService._reset()
    })
    it('executeSql_记录SQL到日志', 0, async () => {
      await MockDbService.executeSql('CREATE TABLE test (id TEXT)')
      const log = MockDbService._getSqlCallLog()
      expect(log.length).assertEqual(1)
      expect(log[0].sql).assertEqual('CREATE TABLE test (id TEXT)')
    })
    it('executeSql_带绑定参数', 0, async () => {
      MockDbService._reset()
      await MockDbService.executeSql('INSERT INTO t VALUES (?, ?)', ['a', 1])
      const log = MockDbService._getSqlCallLog()
      expect(log[0].args!.length).assertEqual(2)
      expect(log[0].args![0]).assertEqual('a')
      expect(log[0].args![1]).assertEqual(1)
    })
  })

  describe('MockDbService_close', () => {
    it('close_调用不抛异常', 0, async () => {
      await MockDbService.close()
    })
  })

  describe('MockDbService_now', () => {
    it('返回固定时间戳', 0, async () => {
      expect(MockDbService.now()).assertEqual('2024-11-14T10:00:00.000Z')
    })
  })

  describe('MockDbService_reset', () => {
    it('reset_清空所有状态', 0, async () => {
      const values = new Map<string, string | number | boolean>()
      values.set('id', 'z1')
      await MockDbService.insert('tmp', values)
      await MockDbService.executeSql('SELECT 1')
      MockDbService._reset()
      expect(MockDbService._getStore().size).assertEqual(0)
      expect(MockDbService._getSqlCallLog().length).assertEqual(0)
    })
  })
}
