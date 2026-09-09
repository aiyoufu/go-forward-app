import { describe, it, expect } from '@ohos/hypium'
import { CryptoService } from '../../../../main/ets/service/auth/CryptoService'
import { CryptoService as MockCryptoService } from '../../mock/CryptoService.mock'

export default function cryptoServiceTest() {
  // ── 纯逻辑方法（实际源码） ──────────────────────────────

  describe('CryptoService_isLegacyHash', () => {
    it('pbkdf2前缀_非旧格式', 0, async () => {
      expect(CryptoService.isLegacyHash('pbkdf2:100000:c2FsdA==:aGFzaA==')).assertFalse()
    })
    it('无前缀_旧格式', 0, async () => {
      expect(CryptoService.isLegacyHash('c2FsdA==:aGFzaA==')).assertTrue()
    })
    it('空字符串_旧格式', 0, async () => {
      expect(CryptoService.isLegacyHash('')).assertTrue()
    })
    it('pbkdf2开头但无冒号_旧格式', 0, async () => {
      // 'pbkdf2xxx' 不以 'pbkdf2:' 开头
      expect(CryptoService.isLegacyHash('pbkdf2xxx')).assertTrue()
    })
    it('pbkdf2:完整四段_非旧格式', 0, async () => {
      expect(CryptoService.isLegacyHash('pbkdf2:100:abc:def')).assertFalse()
    })
  })

  describe('CryptoService_encodeBase64', () => {
    it('空数组_返回空字符串', 0, async () => {
      const result = CryptoService.encodeBase64(new Uint8Array(0))
      expect(result).assertEqual('')
    })
    it('单字节_正确编码', 0, async () => {
      const data = new Uint8Array([72]) // 'H'
      const result = CryptoService.encodeBase64(data)
      expect(result).assertEqual(btoa('H'))
    })
    it('多字节_正确编码', 0, async () => {
      const data = new Uint8Array([72, 101, 108, 108, 111]) // 'Hello'
      const result = CryptoService.encodeBase64(data)
      expect(result).assertEqual(btoa('Hello'))
    })
    it('含0xFF字节_正确编码', 0, async () => {
      const data = new Uint8Array([0, 128, 255])
      const result = CryptoService.encodeBase64(data)
      expect(result.length > 0).assertTrue()
    })
  })

  describe('CryptoService_decodeBase64', () => {
    it('空字符串_返回空数组', 0, async () => {
      const result = CryptoService.decodeBase64('')
      expect(result.length).assertEqual(0)
    })
    it('base64字符串_正确解码', 0, async () => {
      const encoded = btoa('Hello')
      const result = CryptoService.decodeBase64(encoded)
      expect(result.length).assertEqual(5)
      expect(result[0]).assertEqual(72) // 'H'
      expect(result[4]).assertEqual(111) // 'o'
    })
    it('编码解码互逆', 0, async () => {
      const original = new Uint8Array([1, 2, 3, 4, 5])
      const encoded = CryptoService.encodeBase64(original)
      const decoded = CryptoService.decodeBase64(encoded)
      expect(decoded.length).assertEqual(original.length)
      for (let i = 0; i < original.length; i++) {
        expect(decoded[i]).assertEqual(original[i])
      }
    })
  })

  describe('CryptoService_stringToBytes', () => {
    it('空字符串_返回空数组', 0, async () => {
      const result = CryptoService.stringToBytes('')
      expect(result.length).assertEqual(0)
    })
    it('ASCII字符串_正确转换', 0, async () => {
      const result = CryptoService.stringToBytes('ABC')
      expect(result.length).assertEqual(3)
      expect(result[0]).assertEqual(65)
      expect(result[1]).assertEqual(66)
      expect(result[2]).assertEqual(67)
    })
    it('单字符_正确转换', 0, async () => {
      const result = CryptoService.stringToBytes('a')
      expect(result.length).assertEqual(1)
      expect(result[0]).assertEqual(97)
    })
  })

  // ── Mock 方法（验证业务逻辑） ──────────────────────────

  describe('MockCryptoService_randomBytes', () => {
    it('指定长度_返回对应长度数组', 0, async () => {
      const result = MockCryptoService.randomBytes(16)
      expect(result.length).assertEqual(16)
    })
    it('长度为0_返回空数组', 0, async () => {
      const result = MockCryptoService.randomBytes(0)
      expect(result.length).assertEqual(0)
    })
    it('内容为确定性序列', 0, async () => {
      const result = MockCryptoService.randomBytes(4)
      expect(result[0]).assertEqual(0)
      expect(result[1]).assertEqual(1)
      expect(result[2]).assertEqual(2)
      expect(result[3]).assertEqual(3)
    })
  })

  describe('MockCryptoService_hashPin', () => {
    it('返回pbkdf2格式', 0, async () => {
      const salt = MockCryptoService.randomBytes(16)
      const hash = await MockCryptoService.hashPin('123456', salt)
      const parts = hash.split(':')
      expect(parts[0]).assertEqual('pbkdf2')
      expect(parts[1]).assertEqual('100000')
      expect(parts.length).assertEqual(4)
    })
    it('相同pin和salt_产生相同hash', 0, async () => {
      const salt = MockCryptoService.randomBytes(16)
      const h1 = await MockCryptoService.hashPin('pin', salt)
      const h2 = await MockCryptoService.hashPin('pin', salt)
      expect(h1).assertEqual(h2)
    })
    it('不同pin_产生不同hash', 0, async () => {
      const salt = MockCryptoService.randomBytes(16)
      const h1 = await MockCryptoService.hashPin('pin1', salt)
      const h2 = await MockCryptoService.hashPin('pin2', salt)
      expect(h1 !== h2).assertTrue()
    })
  })

  describe('MockCryptoService_verifyPin', () => {
    it('正确pin_验证通过', 0, async () => {
      const salt = MockCryptoService.randomBytes(16)
      const hash = await MockCryptoService.hashPin('123456', salt)
      const ok = await MockCryptoService.verifyPin('123456', hash)
      expect(ok).assertTrue()
    })
    it('错误pin_验证失败', 0, async () => {
      const salt = MockCryptoService.randomBytes(16)
      const hash = await MockCryptoService.hashPin('123456', salt)
      const ok = await MockCryptoService.verifyPin('wrong', hash)
      expect(ok).assertFalse()
    })
  })

  describe('MockCryptoService_isLegacyHash', () => {
    it('pbkdf2格式_非旧格式', 0, async () => {
      expect(MockCryptoService.isLegacyHash('pbkdf2:100000:abc:def')).assertFalse()
    })
    it('旧格式_识别为旧', 0, async () => {
      expect(MockCryptoService.isLegacyHash('abc:def')).assertTrue()
    })
  })

  // ── 字段级加密原语（真实 cryptoFramework，enc:v1 格式） ──

  describe('CryptoService_isEncryptedValue', () => {
    it('enc:v1前缀_识别为密文', 0, async () => {
      expect(CryptoService.isEncryptedValue('enc:v1:aXY=:Y3Q=')).assertTrue()
    })
    it('明文_非密文', 0, async () => {
      expect(CryptoService.isEncryptedValue('sk-plaintext')).assertFalse()
    })
    it('空串_非密文', 0, async () => {
      expect(CryptoService.isEncryptedValue('')).assertFalse()
    })
  })

  describe('CryptoService_generateDek', () => {
    it('返回32字节', 0, async () => {
      expect(CryptoService.generateDek().length).assertEqual(32)
    })
  })

  describe('CryptoService_aesGcm', () => {
    it('往返_密文可解回原文', 0, async () => {
      const key = CryptoService.randomBytes(32)
      const plain = CryptoService.stringToBytes('hello 加密 123')
      const enc = await CryptoService.aesGcmEncrypt(plain, key)
      expect(enc.startsWith('enc:v1:')).assertTrue()
      // enc:v1:<iv>:<ct> 冒号分隔为四段
      expect(enc.split(':').length).assertEqual(4)
      const dec = await CryptoService.aesGcmDecrypt(enc, key)
      expect(dec !== null).assertTrue()
      expect(CryptoService.bytesToString(dec as Uint8Array)).assertEqual('hello 加密 123')
    })
    it('错误密钥_解密返回null', 0, async () => {
      const key = CryptoService.randomBytes(32)
      const wrong = CryptoService.randomBytes(32)
      const enc = await CryptoService.aesGcmEncrypt(CryptoService.stringToBytes('secret'), key)
      const dec = await CryptoService.aesGcmDecrypt(enc, wrong)
      expect(dec === null).assertTrue()
    })
    it('非密文_解密返回null', 0, async () => {
      const key = CryptoService.randomBytes(32)
      const dec = await CryptoService.aesGcmDecrypt('not-encrypted', key)
      expect(dec === null).assertTrue()
    })
  })

  describe('CryptoService_wrapDek', () => {
    it('wrap后unwrap_还原DEK', 0, async () => {
      const dek = CryptoService.generateDek()
      const salt = CryptoService.randomBytes(16)
      const kek = await CryptoService.deriveKek('password123', salt)
      const wrapped = await CryptoService.wrapDek(dek, kek)
      expect(wrapped.startsWith('enc:v1:')).assertTrue()
      const unwrapped = await CryptoService.unwrapDek(wrapped, kek)
      expect(unwrapped !== null).assertTrue()
      const out = unwrapped as Uint8Array
      expect(out.length).assertEqual(32)
      for (let i = 0; i < 32; i++) {
        expect(out[i]).assertEqual(dek[i])
      }
    })
    it('错误密码派生的KEK_unwrap返回null', 0, async () => {
      const dek = CryptoService.generateDek()
      const salt = CryptoService.randomBytes(16)
      const kek = await CryptoService.deriveKek('right', salt)
      const wrongKek = await CryptoService.deriveKek('wrong', salt)
      const wrapped = await CryptoService.wrapDek(dek, kek)
      const unwrapped = await CryptoService.unwrapDek(wrapped, wrongKek)
      expect(unwrapped === null).assertTrue()
    })
  })
}
