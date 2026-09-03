import { describe, beforeAll, afterAll, it, expect } from '@ohos/hypium'
import { E2EEService } from '../../../../main/ets/service/auth/E2EEService'
import { DekManager } from '../../../../main/ets/service/auth/DekManager'
import { CryptoService } from '../../../../main/ets/service/auth/CryptoService'

export default function e2eeServiceTest() {
  describe('E2EEService_initialize', () => {
    it('initialize_不抛异常', 0, async () => {
      await E2EEService.initialize()
    })
  })

  describe('E2EEService_encryptRecord', () => {
    it('正常对象_透传字段', 0, async () => {
      const input = { a: '1', b: 2, c: true }
      const out = await E2EEService.encryptRecord('debts', input)
      expect(out.a).assertEqual('1')
      expect(out.b).assertEqual(2)
      expect(out.c).assertTrue()
    })

    it('null和undefined字段_被过滤', 0, async () => {
      const input: Record<string, string | number | boolean | null | undefined> = {
        a: 'x',
        b: null,
        c: undefined,
        d: 0
      }
      const out = await E2EEService.encryptRecord('debts', input)
      expect(out.a).assertEqual('x')
      expect(out.b === undefined).assertTrue()
      expect(out.c === undefined).assertTrue()
      expect(out.d).assertEqual(0)
    })

    it('空对象_返回空对象', 0, async () => {
      const out = await E2EEService.encryptRecord('debts', {})
      expect(Object.keys(out).length).assertEqual(0)
    })
  })

  describe('E2EEService_decryptRecord', () => {
    it('decrypt与encrypt对称', 0, async () => {
      const input = { a: '1', b: 2 }
      const enc = await E2EEService.encryptRecord('debts', input)
      const dec = await E2EEService.decryptRecord('debts', enc)
      expect(dec.a).assertEqual('1')
      expect(dec.b).assertEqual(2)
    })

    it('decrypt也过滤null', 0, async () => {
      const input: Record<string, string | number | null> = { a: 'x', b: null }
      const out = await E2EEService.decryptRecord('debts', input)
      expect(out.a).assertEqual('x')
      expect(out.b === undefined).assertTrue()
    })

    it('不同表名_都透传', 0, async () => {
      const input = { id: '1' }
      const out1 = await E2EEService.encryptRecord('debts', input)
      const out2 = await E2EEService.encryptRecord('subscriptions', input)
      expect(out1.id).assertEqual('1')
      expect(out2.id).assertEqual('1')
    })
  })

  // ── 字段级加解密（敏感列加密，其余透传） ──

  describe('E2EEService_fieldLevel_withDek', () => {
    beforeAll(async () => {
      await DekManager.setActiveDek(CryptoService.randomBytes(32))
    })
    afterAll(async () => {
      await DekManager.clearActiveDek()
    })

    it('credit_accounts_cvv加密_其余透传', 0, async () => {
      const enc = await E2EEService.encryptRecord('credit_accounts', { id: '1', name: 'card', cvv: '123' })
      expect(('' + enc.cvv).startsWith('enc:v1:')).assertTrue()
      expect(enc.id).assertEqual('1')
      expect(enc.name).assertEqual('card')
      const dec = await E2EEService.decryptRecord('credit_accounts', enc)
      expect(dec.cvv).assertEqual('123')
      expect(dec.name).assertEqual('card')
    })

    it('user_settings_ai_key加密往返', 0, async () => {
      const enc = await E2EEService.encryptRecord('user_settings',
        { user_id: 'u1', ai_text_key: 'sk-text', ai_vision_key: 'sk-vision' })
      expect(('' + enc.ai_text_key).startsWith('enc:v1:')).assertTrue()
      expect(('' + enc.ai_vision_key).startsWith('enc:v1:')).assertTrue()
      expect(enc.user_id).assertEqual('u1')
      const dec = await E2EEService.decryptRecord('user_settings', enc)
      expect(dec.ai_text_key).assertEqual('sk-text')
      expect(dec.ai_vision_key).assertEqual('sk-vision')
    })

    it('已加密值_不重复加密', 0, async () => {
      const enc1 = await E2EEService.encryptRecord('credit_accounts', { cvv: '456' })
      const enc2 = await E2EEService.encryptRecord('credit_accounts', { cvv: '' + enc1.cvv })
      expect(enc2.cvv).assertEqual(enc1.cvv)
    })
  })

  describe('E2EEService_fieldLevel_noDek', () => {
    beforeAll(async () => {
      await DekManager.clearActiveDek()
    })

    it('无DEK_cvv回退明文', 0, async () => {
      const enc = await E2EEService.encryptRecord('credit_accounts', { cvv: '789' })
      expect(enc.cvv).assertEqual('789')
    })

    it('无DEK_明文cvv读取原样返回', 0, async () => {
      const dec = await E2EEService.decryptRecord('credit_accounts', { cvv: '789' })
      expect(dec.cvv).assertEqual('789')
    })
  })
}
