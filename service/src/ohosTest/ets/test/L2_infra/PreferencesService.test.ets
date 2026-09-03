import { describe, it, expect, beforeAll } from '@ohos/hypium'
import { PreferencesService as MockPrefService } from '../../mock/PreferencesService.mock'

export default function preferencesServiceTest() {
  beforeAll(() => {
    MockPrefService._reset()
  })

  // ── init ───────────────────────────────────────────────

  describe('PreferencesService_init', () => {
    it('init_调用不抛异常', 0, async () => {
      await MockPrefService.init({})
    })
    it('init_幂等_多次调用不抛异常', 0, async () => {
      await MockPrefService.init({})
      await MockPrefService.init({})
    })
  })

  // ── putString / getString ─────────────────────────────

  describe('PreferencesService_putString_getString', () => {
    it('写入并读取字符串', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('name', 'Alice')
      const v = await MockPrefService.getString('name')
      expect(v).assertEqual('Alice')
    })
    it('覆盖已有字符串', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('k', 'old')
      await MockPrefService.putString('k', 'new')
      expect(await MockPrefService.getString('k')).assertEqual('new')
    })
    it('不存在的键_返回默认值', 0, async () => {
      MockPrefService._reset()
      const v = await MockPrefService.getString('missing', 'default')
      expect(v).assertEqual('default')
    })
    it('不存在的键_无默认值_返回空字符串', 0, async () => {
      MockPrefService._reset()
      const v = await MockPrefService.getString('missing')
      expect(v).assertEqual('')
    })
    it('写入空字符串_可读取', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('empty', '')
      const v = await MockPrefService.getString('empty')
      expect(v).assertEqual('')
    })
  })

  // ── putNumber / getNumber ─────────────────────────────

  describe('PreferencesService_putNumber_getNumber', () => {
    it('写入并读取数字', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putNumber('count', 42)
      const v = await MockPrefService.getNumber('count')
      expect(v).assertEqual(42)
    })
    it('写入浮点数', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putNumber('pi', 3.14)
      const v = await MockPrefService.getNumber('pi')
      expect(v).assertEqual(3.14)
    })
    it('写入0', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putNumber('zero', 0)
      const v = await MockPrefService.getNumber('zero')
      expect(v).assertEqual(0)
    })
    it('不存在的键_返回默认值', 0, async () => {
      MockPrefService._reset()
      const v = await MockPrefService.getNumber('missing', 99)
      expect(v).assertEqual(99)
    })
    it('不存在的键_无默认值_返回0', 0, async () => {
      MockPrefService._reset()
      const v = await MockPrefService.getNumber('missing')
      expect(v).assertEqual(0)
    })
    it('类型不匹配_返回默认值', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('str_key', 'not_a_number')
      const v = await MockPrefService.getNumber('str_key', 77)
      expect(v).assertEqual(77)
    })
  })

  // ── putBool / getBool ─────────────────────────────────

  describe('PreferencesService_putBool_getBool', () => {
    it('写入true并读取', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putBool('flag', true)
      const v = await MockPrefService.getBool('flag')
      expect(v).assertTrue()
    })
    it('写入false并读取', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putBool('flag', false)
      const v = await MockPrefService.getBool('flag')
      expect(v).assertFalse()
    })
    it('不存在的键_返回默认值false', 0, async () => {
      MockPrefService._reset()
      const v = await MockPrefService.getBool('missing')
      expect(v).assertFalse()
    })
    it('不存在的键_返回指定默认值', 0, async () => {
      MockPrefService._reset()
      const v = await MockPrefService.getBool('missing', true)
      expect(v).assertTrue()
    })
    it('类型不匹配_返回默认值', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('str_key', 'not_a_bool')
      const v = await MockPrefService.getBool('str_key', true)
      expect(v).assertTrue()
    })
  })

  // ── delete ─────────────────────────────────────────────

  describe('PreferencesService_delete', () => {
    it('删除已存在的键_读取返回默认值', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('temp', 'data')
      await MockPrefService.delete('temp')
      const v = await MockPrefService.getString('temp', 'gone')
      expect(v).assertEqual('gone')
    })
    it('删除不存在的键_不抛异常', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.delete('no_such_key')
      expect(true).assertTrue()
    })
    it('删除一个键不影响其他键', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('a', '1')
      await MockPrefService.putString('b', '2')
      await MockPrefService.delete('a')
      expect(await MockPrefService.getString('b')).assertEqual('2')
    })
  })

  // ── 内部状态验证 ────────────────────────────────────────

  describe('PreferencesService_内部状态', () => {
    it('_getStore_反映当前存储', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('s', 'hello')
      await MockPrefService.putNumber('n', 10)
      await MockPrefService.putBool('b', true)
      const store = MockPrefService._getStore()
      expect(store.size).assertEqual(3)
      expect(store.get('s')).assertEqual('hello')
      expect(store.get('n')).assertEqual(10)
      expect(store.get('b')).assertTrue()
    })
    it('_reset_清空所有数据', 0, async () => {
      MockPrefService._reset()
      await MockPrefService.putString('k', 'v')
      MockPrefService._reset()
      expect(MockPrefService._getStore().size).assertEqual(0)
    })
  })
}
