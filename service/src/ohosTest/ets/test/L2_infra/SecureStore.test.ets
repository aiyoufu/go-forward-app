import { describe, it, expect, beforeAll } from '@ohos/hypium'
import { SecureStore as MockSecureStore } from '../../mock/SecureStore.mock'

export default function secureStoreTest() {
  beforeAll(() => {
    MockSecureStore._reset()
  })

  // ── putString ──────────────────────────────────────────

  describe('SecureStore_putString', () => {
    it('写入非空字符串_存储成功', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('token', 'abc123')
      const value = await MockSecureStore.getString('token')
      expect(value).assertEqual('abc123')
    })
    it('写入空字符串_等价于删除', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('key1', 'value1')
      await MockSecureStore.putString('key1', '')
      const value = await MockSecureStore.getString('key1')
      expect(value).assertEqual('')
    })
    it('覆盖已有值_取最新值', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('key', 'old')
      await MockSecureStore.putString('key', 'new')
      const value = await MockSecureStore.getString('key')
      expect(value).assertEqual('new')
    })
    it('不同alias_独立存储', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('a', 'val_a')
      await MockSecureStore.putString('b', 'val_b')
      expect(await MockSecureStore.getString('a')).assertEqual('val_a')
      expect(await MockSecureStore.getString('b')).assertEqual('val_b')
    })
  })

  // ── getString ──────────────────────────────────────────

  describe('SecureStore_getString', () => {
    it('不存在的键_返回空字符串', 0, async () => {
      MockSecureStore._reset()
      const value = await MockSecureStore.getString('nonexistent')
      expect(value).assertEqual('')
    })
    it('已存储的键_返回正确值', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('mykey', 'myvalue')
      const value = await MockSecureStore.getString('mykey')
      expect(value).assertEqual('myvalue')
    })
    it('删除后再读取_返回空字符串', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('temp', 'data')
      await MockSecureStore.remove('temp')
      const value = await MockSecureStore.getString('temp')
      expect(value).assertEqual('')
    })
  })

  // ── remove ─────────────────────────────────────────────

  describe('SecureStore_remove', () => {
    it('删除已存在的键_成功', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('k', 'v')
      await MockSecureStore.remove('k')
      expect(await MockSecureStore.getString('k')).assertEqual('')
    })
    it('删除不存在的键_不抛异常', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.remove('no_such_key')
      // 不应抛异常
      expect(true).assertTrue()
    })
  })

  // ── 存储键名验证 ────────────────────────────────────────

  describe('SecureStore_键名验证', () => {
    it('特殊字符键名_可正常存取', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('key-with-dashes', 'v1')
      expect(await MockSecureStore.getString('key-with-dashes')).assertEqual('v1')
    })
    it('长键名_可正常存取', 0, async () => {
      MockSecureStore._reset()
      const longKey = 'a'.repeat(100)
      await MockSecureStore.putString(longKey, 'long_key_value')
      expect(await MockSecureStore.getString(longKey)).assertEqual('long_key_value')
    })
    it('空字符串键名_可正常存取', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('', 'empty_key_value')
      expect(await MockSecureStore.getString('')).assertEqual('empty_key_value')
    })
  })

  // ── 内部存储验证 ────────────────────────────────────────

  describe('SecureStore_内部状态', () => {
    it('_getStore_反映当前存储', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('x', '1')
      await MockSecureStore.putString('y', '2')
      const store = MockSecureStore._getStore()
      expect(store.size).assertEqual(2)
      expect(store.get('x')).assertEqual('1')
      expect(store.get('y')).assertEqual('2')
    })
    it('_reset_清空所有数据', 0, async () => {
      MockSecureStore._reset()
      await MockSecureStore.putString('a', 'b')
      MockSecureStore._reset()
      expect(MockSecureStore._getStore().size).assertEqual(0)
    })
  })
}
