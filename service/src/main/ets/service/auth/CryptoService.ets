import { cryptoFramework } from '@kit.CryptoArchitectureKit'
import { buffer, util } from '@kit.ArkTS'

export class CryptoService {
  /** PBKDF2 迭代次数：抬高穷举成本，真机单次派生仍在百毫秒内 */
  private static readonly PBKDF2_ITERATIONS: number = 100000
  private static readonly PBKDF2_KEY_SIZE: number = 32
  private static readonly PBKDF2_PREFIX: string = 'pbkdf2'

  // ───── 字段级加密（与 go-forward-desktop lib/crypto.ts 逐字节互通）─────
  /** 密文前缀，与 go-forward-desktop ENC_PREFIX 一致 */
  static readonly ENC_PREFIX: string = 'enc:v1:'
  /** KEK 派生迭代数，与 go-forward-desktop PBKDF2_ITERATIONS 一致（勿改，改则两端不互通） */
  private static readonly KEK_ITERATIONS: number = 600000
  /** AES-GCM IV 长度：WebCrypto 默认 96bit */
  private static readonly GCM_IV_LEN: number = 12
  /** AES-GCM 认证标签长度：WebCrypto 默认 128bit */
  private static readonly GCM_TAG_LEN: number = 16
  /** DEK/AES-256 密钥字节数 */
  private static readonly AES_KEY_SIZE: number = 32

  static randomBytes(length: number): Uint8Array {
    try {
      const rand = cryptoFramework.createRandom()
      const blob = rand.generateRandomSync(length)
      return blob.data
    } catch (_e) {
      return new Uint8Array(0)
    }
  }

  static async sha256(data: Uint8Array): Promise<Uint8Array> {
    try {
      const md = cryptoFramework.createMd('SHA256')
      await md.update({ data: data })
      const result = await md.digest()
      return result.data
    } catch (_e) {
      return new Uint8Array(0)
    }
  }

  /** 新格式：pbkdf2:<iterations>:<saltB64>:<hashB64>，取代单轮 SHA256 */
  static async hashPin(pin: string, salt: Uint8Array): Promise<string> {
    const derived = await CryptoService.pbkdf2(pin, salt, CryptoService.PBKDF2_ITERATIONS)
    return CryptoService.PBKDF2_PREFIX + ':' + CryptoService.PBKDF2_ITERATIONS + ':' +
      CryptoService.encodeBase64(salt) + ':' + CryptoService.encodeBase64(derived)
  }

  /** 旧格式（<saltB64>:<hashB64>，单轮 SHA256），仅用于存量数据校验 */
  private static async hashPinLegacy(pin: string, salt: Uint8Array): Promise<string> {
    const pinBytes = CryptoService.stringToBytes(pin)
    const combined = new Uint8Array(pinBytes.length + salt.length)
    combined.set(pinBytes)
    combined.set(salt, pinBytes.length)
    const hash = await CryptoService.sha256(combined)
    return CryptoService.encodeBase64(salt) + ':' + CryptoService.encodeBase64(hash)
  }

  /** 存量哈希是否为旧式单轮 SHA256，调用方可据此在校验成功后重新落库升级 */
  static isLegacyHash(stored: string): boolean {
    return !stored.startsWith(CryptoService.PBKDF2_PREFIX + ':')
  }

  static async verifyPin(pin: string, stored: string): Promise<boolean> {
    const parts = stored.split(':')
    if (parts[0] === CryptoService.PBKDF2_PREFIX && parts.length === 4) {
      const iterations = Number.parseInt(parts[1], 10)
      if (!Number.isFinite(iterations) || iterations <= 0) {
        return false
      }
      const salt = CryptoService.decodeBase64(parts[2])
      const derived = await CryptoService.pbkdf2(pin, salt, iterations)
      return CryptoService.encodeBase64(derived) === parts[3]
    }
    if (parts.length !== 2) {
      return false
    }
    const salt = CryptoService.decodeBase64(parts[0])
    const legacy = await CryptoService.hashPinLegacy(pin, salt)
    return legacy === stored
  }

  private static async pbkdf2(pin: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
    try {
      const spec: cryptoFramework.PBKDF2Spec = {
        algName: 'PBKDF2',
        password: pin,
        salt: salt,
        iterations: iterations,
        keySize: CryptoService.PBKDF2_KEY_SIZE
      }
      const kdf = cryptoFramework.createKdf('PBKDF2|SHA256')
      const result = await kdf.generateSecret(spec)
      return result.data
    } catch (_e) {
      return new Uint8Array(0)
    }
  }

  static encodeBase64(data: Uint8Array): string {
    try {
      return buffer.from(data.buffer).toString('base64')
    } catch (_e) {
      return ''
    }
  }

  static decodeBase64(str: string): Uint8Array {
    const buf = buffer.from(str, 'base64')
    const arr = new Uint8Array(buf.length)
    for (let i = 0; i < buf.length; i++) {
      arr[i] = buf[i]
    }
    return arr
  }

  static stringToBytes(str: string): Uint8Array {
    const encoder = new util.TextEncoder()
    return encoder.encodeInto(str)
  }

  static bytesToString(data: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(data)
  }

  /** 值是否为本模块产出的密文（enc:v1: 前缀） */
  static isEncryptedValue(value: string): boolean {
    return value.length > 0 && value.startsWith(CryptoService.ENC_PREFIX)
  }

  /** 由登录密码派生 KEK（PBKDF2-SHA256-600k → 32 字节） */
  static async deriveKek(password: string, salt: Uint8Array): Promise<Uint8Array> {
    return CryptoService.pbkdf2(password, salt, CryptoService.KEK_ITERATIONS)
  }

  /** 生成随机 256bit DEK */
  static generateDek(): Uint8Array {
    return CryptoService.randomBytes(CryptoService.AES_KEY_SIZE)
  }

  /** 用 KEK 包裹 DEK（产出 enc:v1 密文字符串） */
  static async wrapDek(dek: Uint8Array, kek: Uint8Array): Promise<string> {
    return CryptoService.aesGcmEncrypt(dek, kek)
  }

  /** 用 KEK 解包 DEK，失败（密码不匹配等）返回 null */
  static async unwrapDek(wrapped: string, kek: Uint8Array): Promise<Uint8Array | null> {
    return CryptoService.aesGcmDecrypt(wrapped, kek)
  }

  /**
   * AES-256-GCM 加密，产出 `enc:v1:<iv_b64>:<ct_b64>`。
   * 为与 WebCrypto 互通，ct = 密文 || 16 字节 authTag（tag 拼在末尾）。
   */
  static async aesGcmEncrypt(plain: Uint8Array, keyBytes: Uint8Array): Promise<string> {
    try {
      const key = await CryptoService.importAesKey(keyBytes)
      if (key === null) {
        return ''
      }
      const iv = CryptoService.randomBytes(CryptoService.GCM_IV_LEN)
      const gcmParams: cryptoFramework.GcmParamsSpec = {
        algName: 'GcmParamsSpec',
        iv: { data: iv },
        aad: { data: new Uint8Array() },
        authTag: { data: new Uint8Array(CryptoService.GCM_TAG_LEN) }
      }
      const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding')
      await cipher.init(cryptoFramework.CryptoMode.ENCRYPT_MODE, key, gcmParams)
      const cipherOut: cryptoFramework.DataBlob | null = await cipher.update({ data: plain })
      // GCM 加密：doFinal(null) 返回 16 字节 authTag
      const tagOut: cryptoFramework.DataBlob | null = await cipher.doFinal(null)
      const cipherBytes = cipherOut !== null ? cipherOut.data : new Uint8Array()
      const tagBytes = tagOut !== null ? tagOut.data : new Uint8Array()
      const ct = new Uint8Array(cipherBytes.length + tagBytes.length)
      ct.set(cipherBytes)
      ct.set(tagBytes, cipherBytes.length)
      return CryptoService.ENC_PREFIX + CryptoService.encodeBase64(iv) + ':' + CryptoService.encodeBase64(ct)
    } catch (_e) {
      return ''
    }
  }

  /** AES-256-GCM 解密；非密文/格式错误/认证失败均返回 null */
  static async aesGcmDecrypt(value: string, keyBytes: Uint8Array): Promise<Uint8Array | null> {
    if (!CryptoService.isEncryptedValue(value)) {
      return null
    }
    const rest = value.substring(CryptoService.ENC_PREFIX.length)
    const sep = rest.indexOf(':')
    if (sep < 0) {
      return null
    }
    const iv = CryptoService.decodeBase64(rest.substring(0, sep))
    const ct = CryptoService.decodeBase64(rest.substring(sep + 1))
    if (ct.length < CryptoService.GCM_TAG_LEN) {
      return null
    }
    const tag = ct.slice(ct.length - CryptoService.GCM_TAG_LEN)
    const cipherBytes = ct.slice(0, ct.length - CryptoService.GCM_TAG_LEN)
    try {
      const key = await CryptoService.importAesKey(keyBytes)
      if (key === null) {
        return null
      }
      const gcmParams: cryptoFramework.GcmParamsSpec = {
        algName: 'GcmParamsSpec',
        iv: { data: iv },
        aad: { data: new Uint8Array() },
        authTag: { data: tag }
      }
      const cipher = cryptoFramework.createCipher('AES256|GCM|NoPadding')
      await cipher.init(cryptoFramework.CryptoMode.DECRYPT_MODE, key, gcmParams)
      const plainOut: cryptoFramework.DataBlob | null = await cipher.update({ data: cipherBytes })
      // doFinal 验证 tag，失败抛异常（密钥不匹配或数据损坏）
      const finalOut: cryptoFramework.DataBlob | null = await cipher.doFinal(null)
      const p1 = plainOut !== null ? plainOut.data : new Uint8Array()
      const p2 = finalOut !== null ? finalOut.data : new Uint8Array()
      if (p2.length === 0) {
        return p1
      }
      const out = new Uint8Array(p1.length + p2.length)
      out.set(p1)
      out.set(p2, p1.length)
      return out
    } catch (e) {
      return null
    }
  }

  /** 导入失败（密钥长度非法等）返回 null，调用方按加密/解密失败处理 */
  private static async importAesKey(keyBytes: Uint8Array): Promise<cryptoFramework.SymKey | null> {
    try {
      const generator = cryptoFramework.createSymKeyGenerator('AES256')
      return await generator.convertKey({ data: keyBytes })
    } catch (_e) {
      return null
    }
  }
}
