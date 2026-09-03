// CryptoService.mock.ets
// Mock preset: 简单变换或透传

export class CryptoService {
  static randomBytes(length: number): Uint8Array {
    const arr = new Uint8Array(length)
    for (let i = 0; i < length; i++) {
      arr[i] = i % 256
    }
    return arr
  }

  static async sha256(data: Uint8Array): Promise<Uint8Array> {
    // 简单变换：取反
    const result = new Uint8Array(data.length)
    for (let i = 0; i < data.length; i++) {
      result[i] = ~data[i] & 0xFF
    }
    return result
  }

  static async hashPin(pin: string, salt: Uint8Array): Promise<string> {
    // 简单格式：pbkdf2:100000:<saltB64>:<hashB64>
    const saltB64 = CryptoService.encodeBase64(salt)
    const hashB64 = CryptoService.encodeBase64(CryptoService.stringToBytes(pin + '-mock-hash'))
    return 'pbkdf2:100000:' + saltB64 + ':' + hashB64
  }

  static isLegacyHash(stored: string): boolean {
    return !stored.startsWith('pbkdf2:')
  }

  static async verifyPin(pin: string, stored: string): Promise<boolean> {
    // 简单比较：stored 是否包含 pin 的 mock hash
    const expected = CryptoService.encodeBase64(CryptoService.stringToBytes(pin + '-mock-hash'))
    return stored.indexOf(expected) >= 0
  }

  static encodeBase64(data: Uint8Array): string {
    let str = ''
    for (let i = 0; i < data.length; i++) {
      str += String.fromCharCode(data[i])
    }
    // 简单 base64 编码
    return btoa(str)
  }

  static decodeBase64(str: string): Uint8Array {
    const decoded = atob(str)
    const arr = new Uint8Array(decoded.length)
    for (let i = 0; i < decoded.length; i++) {
      arr[i] = decoded.charCodeAt(i)
    }
    return arr
  }

  static stringToBytes(str: string): Uint8Array {
    const arr = new Uint8Array(str.length)
    for (let i = 0; i < str.length; i++) {
      arr[i] = str.charCodeAt(i) & 0xFF
    }
    return arr
  }
}
