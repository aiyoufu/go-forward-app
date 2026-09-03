import { describe, it, expect } from '@ohos/hypium'
import { IconPickerService } from '../../../../main/ets/service/platform/IconPickerService'

export default function iconPickerServiceTest() {
  describe('IconPickerService_listHistoryIcons', () => {
    it('无context_抛错被catch返回空数组', 0, () => {
      // null context 会导致 filesDir 访问失败，catch 后返回 []
      const result = IconPickerService.listHistoryIcons(null as Object)
      expect(Array.isArray(result)).assertTrue()
      expect(result.length).assertEqual(0)
    })

    it('undefined context_返回空数组', 0, () => {
      const result = IconPickerService.listHistoryIcons(undefined as Object)
      expect(Array.isArray(result)).assertTrue()
      expect(result.length).assertEqual(0)
    })

    it('卡面前缀_无context_返回空数组', 0, () => {
      const result = IconPickerService.listHistoryIcons(undefined as Object, 'card_face_')
      expect(Array.isArray(result)).assertTrue()
      expect(result.length).assertEqual(0)
    })
  })

  describe('IconPickerService_recordPickedIcon', () => {
    it('无context_不抛错', 0, () => {
      IconPickerService.recordPickedIcon(null as Object, 'file://data/icon_net_1.png')
    })

    it('空路径_不抛错', 0, () => {
      IconPickerService.recordPickedIcon(undefined as Object, '')
    })
  })

  describe('IconPickerService_pickAndCopyFromAlbum', () => {
    it('无context_返回空串', 0, async () => {
      const result = await IconPickerService.pickAndCopyFromAlbum(null as Object)
      expect(typeof result === 'string').assertTrue()
      expect(result.length).assertEqual(0)
    })

    it('undefined context_返回空串', 0, async () => {
      const result = await IconPickerService.pickAndCopyFromAlbum(undefined as Object)
      expect(typeof result === 'string').assertTrue()
      expect(result.length).assertEqual(0)
    })

    it('卡面前缀_无context_返回空串', 0, async () => {
      const result = await IconPickerService.pickAndCopyFromAlbum(undefined as Object, 'card_face_')
      expect(typeof result === 'string').assertTrue()
      expect(result.length).assertEqual(0)
    })
  })

  describe('IconPickerService_searchIconsByName', () => {
    it('空词返回空', 0, async () => {
      const list = await IconPickerService.searchIconsByName('')
      expect(list.length).assertEqual(0)
    })
  })

  describe('IconPickerService_encodeHttpUrl', () => {
    it('空串原样', 0, () => {
      expect(IconPickerService.encodeHttpUrl('')).assertEqual('')
    })
    it('空格与中文编码且保留路径里的@', 0, () => {
      const u = 'https://cdn.example.com/icons@2x/China Merchants Bank/Young卡.png'
      const e = IconPickerService.encodeHttpUrl(u)
      expect(e.indexOf(' ') < 0).assertTrue()
      expect(e.indexOf('@2x') >= 0).assertTrue()
      expect(e.indexOf('China%20Merchants%20Bank') >= 0).assertTrue()
    })
    it('已编码的query不二次编码', 0, () => {
      const u = 'https://itunes.apple.com/search?term=' + encodeURIComponent('招商')
      expect(IconPickerService.encodeHttpUrl(u)).assertEqual(u)
    })
    it('ASCII路径不改', 0, () => {
      const u = 'https://is1-ssl.mzstatic.com/image/thumb/a.png'
      expect(IconPickerService.encodeHttpUrl(u)).assertEqual(u)
    })
  })

  describe('IconPickerService_isRemoteUrl', () => {
    it('https为远程', 0, () => {
      expect(IconPickerService.isRemoteUrl('https://example.com/a.png')).assertTrue()
    })
    it('http为远程', 0, () => {
      expect(IconPickerService.isRemoteUrl('http://example.com/a.png')).assertTrue()
    })
    it('file不是远程', 0, () => {
      expect(IconPickerService.isRemoteUrl('file://data/icon.png')).assertFalse()
    })
    it('空串不是远程', 0, () => {
      expect(IconPickerService.isRemoteUrl('')).assertFalse()
    })
  })

  describe('IconPickerService_isRawfilePath', () => {
    it('rawfile路径命中', 0, () => {
      expect(IconPickerService.isRawfilePath('$rawfile:credit_logos/alipay.png')).assertTrue()
    })
    it('http不是rawfile', 0, () => {
      expect(IconPickerService.isRawfilePath('https://example.com/a.png')).assertFalse()
    })
    it('file不是rawfile', 0, () => {
      expect(IconPickerService.isRawfilePath('file://data/icon.png')).assertFalse()
    })
    it('空串不是rawfile', 0, () => {
      expect(IconPickerService.isRawfilePath('')).assertFalse()
    })
  })

  describe('IconPickerService_isCardFaceUrl', () => {
    it('card_face缓存为卡面', 0, () => {
      expect(IconPickerService.isCardFaceUrl('file://data/card_face_abc.png')).assertTrue()
    })
    it('云同步账户桶为卡面', 0, () => {
      expect(IconPickerService.isCardFaceUrl(
        'https://x.supabase.co/storage/v1/object/public/credit-account-icons/a.png')).assertTrue()
    })
    it('账户桶里的信贷平台圆标不是卡面', 0, () => {
      expect(IconPickerService.isCardFaceUrl(
        'https://x.supabase.co/storage/v1/object/public/credit-account-icons/u/icon_net_1a2b.png')).assertFalse()
    })
    it('应用图标不是卡面', 0, () => {
      expect(IconPickerService.isCardFaceUrl('https://is1-ssl.mzstatic.com/image/thumb/a.png')).assertFalse()
      expect(IconPickerService.isCardFaceUrl('file://data/icon_123.png')).assertFalse()
      expect(IconPickerService.isCardFaceUrl('')).assertFalse()
    })
  })

  describe('IconPickerService_resolveRawfileIcon', () => {
    it('无context_返回空串', 0, async () => {
      const r = await IconPickerService.resolveRawfileIcon(null as Object, '$rawfile:credit_logos/alipay.png')
      expect(r).assertEqual('')
    })
    it('非rawfile路径_返回空串', 0, async () => {
      const r = await IconPickerService.resolveRawfileIcon(undefined as Object, 'https://example.com/a.png')
      expect(r).assertEqual('')
    })
    it('空rawfile路径_返回空串', 0, async () => {
      const r = await IconPickerService.resolveRawfileIcon(undefined as Object, '$rawfile:')
      expect(r).assertEqual('')
    })
  })

  describe('IconPickerService_urlKey', () => {
    it('相同URL键相同', 0, () => {
      const a = IconPickerService.urlKey('https://www.google.com/s2/favicons?domain=netflix.com&sz=128')
      const b = IconPickerService.urlKey('https://www.google.com/s2/favicons?domain=netflix.com&sz=128')
      expect(a).assertEqual(b)
      expect(a.length > 0).assertTrue()
    })
    it('不同URL键不同', 0, () => {
      const a = IconPickerService.urlKey('https://a.example/x.png')
      const b = IconPickerService.urlKey('https://b.example/x.png')
      expect(a === b).assertFalse()
    })
  })

  describe('IconPickerService_guessExt', () => {
    it('jpeg类型为jpg', 0, () => {
      expect(IconPickerService.guessExt('https://x', 'image/jpeg')).assertEqual('jpg')
    })
    it('png类型为png', 0, () => {
      expect(IconPickerService.guessExt('https://x', 'image/png')).assertEqual('png')
    })
    it('无类型按jpg后缀', 0, () => {
      expect(IconPickerService.guessExt('https://x/a.jpg', '')).assertEqual('jpg')
    })
    it('默认png', 0, () => {
      expect(IconPickerService.guessExt('https://x/favicon', '')).assertEqual('png')
    })
  })

  describe('IconPickerService_extractDomain', () => {
    it('google_s2取出domain', 0, () => {
      const d = IconPickerService.extractDomain('https://www.google.com/s2/favicons?domain=openai.com&sz=128')
      expect(d).assertEqual('openai.com')
    })
    it('普通https取host', 0, () => {
      expect(IconPickerService.extractDomain('https://www.netflix.com/path')).assertEqual('netflix.com')
    })
  })

  describe('IconPickerService_iconCandidates', () => {
    it('含国内源与域名', 0, () => {
      const list = IconPickerService.iconCandidates('https://www.google.com/s2/favicons?domain=openai.com&sz=128')
      expect(list.length >= 2).assertTrue()
      let hasDnspod = false
      for (let i = 0; i < list.length; i++) {
        if (list[i].indexOf('dnspod.cn') >= 0) {
          hasDnspod = true
        }
      }
      expect(hasDnspod).assertTrue()
    })
  })

  describe('IconPickerService_extractEmbeddedPng', () => {
    it('无png返回null', 0, () => {
      const buf = new ArrayBuffer(16)
      expect(IconPickerService.extractEmbeddedPng(buf) === null).assertTrue()
    })
    it('能抽出内嵌png', 0, () => {
      const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
      const iend = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0x00, 0x00, 0x00, 0x00]
      const raw = new ArrayBuffer(4 + sig.length + iend.length)
      const u = new Uint8Array(raw)
      u[0] = 0
      u[1] = 0
      u[2] = 1
      u[3] = 0
      for (let i = 0; i < sig.length; i++) {
        u[4 + i] = sig[i]
      }
      for (let i = 0; i < iend.length; i++) {
        u[4 + sig.length + i] = iend[i]
      }
      const png = IconPickerService.extractEmbeddedPng(raw)
      expect(png !== null).assertTrue()
      if (png !== null) {
        expect(png.byteLength).assertEqual(sig.length + iend.length)
      }
    })
    it('目录多尺寸_取最大那张png', 0, () => {
      const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
      const iend = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0x00, 0x00, 0x00, 0x00]
      const smallLen = sig.length + iend.length
      const filler = [0x01, 0x02, 0x03, 0x04]
      const largeLen = sig.length + filler.length + iend.length
      const count = 2
      const off0 = 6 + count * 16
      const off1 = off0 + smallLen
      const raw = new ArrayBuffer(off1 + largeLen)
      const u = new Uint8Array(raw)
      u[4] = count & 0xFF
      const writeEntry = (idx: number, size: number, off: number, len: number) => {
        const e = 6 + idx * 16
        u[e] = size & 0xFF
        u[e + 1] = size & 0xFF
        u[e + 8] = len & 0xFF
        u[e + 12] = off & 0xFF
      }
      // 目录小图在前（真实 ICO 常见顺序），大图在后
      writeEntry(0, 16, off0, smallLen)
      writeEntry(1, 48, off1, largeLen)
      for (let i = 0; i < sig.length; i++) {
        u[off0 + i] = sig[i]
        u[off1 + i] = sig[i]
      }
      for (let i = 0; i < iend.length; i++) {
        u[off0 + sig.length + i] = iend[i]
        u[off1 + sig.length + filler.length + i] = iend[i]
      }
      const png = IconPickerService.extractEmbeddedPng(raw)
      expect(png !== null).assertTrue()
      if (png !== null) {
        expect(png.byteLength).assertEqual(largeLen)
      }
    })
    it('目录字段越界_回退扫png', 0, () => {
      const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
      const iend = [0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0x00, 0x00, 0x00, 0x00]
      // 合法头但目录指向文件外：只能靠回退扫描抽到 png
      const raw = new ArrayBuffer(6 + 16 + sig.length + iend.length)
      const u = new Uint8Array(raw)
      u[2] = 1
      u[4] = 1
      const e = 6
      u[e] = 32
      u[e + 1] = 32
      u[e + 8] = 0xFF
      u[e + 12] = 0xFF
      u[e + 13] = 0xFF
      const dataOff = 6 + 16
      for (let i = 0; i < sig.length; i++) {
        u[dataOff + i] = sig[i]
      }
      for (let i = 0; i < iend.length; i++) {
        u[dataOff + sig.length + i] = iend[i]
      }
      const png = IconPickerService.extractEmbeddedPng(raw)
      expect(png !== null).assertTrue()
      if (png !== null) {
        expect(png.byteLength).assertEqual(sig.length + iend.length)
      }
    })
  })

  describe('IconPickerService_isPngOrJpeg', () => {
    it('png为真', 0, () => {
      const buf = new ArrayBuffer(16)
      const u = new Uint8Array(buf)
      u[0] = 0x89
      u[1] = 0x50
      u[2] = 0x4E
      u[3] = 0x47
      expect(IconPickerService.isPngOrJpeg(buf)).assertTrue()
    })
    it('jpeg为真', 0, () => {
      const buf = new ArrayBuffer(16)
      const u = new Uint8Array(buf)
      u[0] = 0xFF
      u[1] = 0xD8
      expect(IconPickerService.isJpegBytes(buf)).assertTrue()
      expect(IconPickerService.isPngOrJpeg(buf)).assertTrue()
    })
    it('空数据为假', 0, () => {
      expect(IconPickerService.isPngOrJpeg(new ArrayBuffer(16))).assertFalse()
    })
  })

  describe('IconPickerService_isImageBytes', () => {
    it('png头为真', 0, () => {
      const buf = new ArrayBuffer(16)
      const u = new Uint8Array(buf)
      u[0] = 0x89
      u[1] = 0x50
      u[2] = 0x4E
      u[3] = 0x47
      expect(IconPickerService.isImageBytes(buf)).assertTrue()
    })
    it('太短为假', 0, () => {
      expect(IconPickerService.isImageBytes(new ArrayBuffer(4))).assertFalse()
    })
    it('空数据为假', 0, () => {
      expect(IconPickerService.isImageBytes(new ArrayBuffer(16))).assertFalse()
    })
  })

  describe('IconPickerService_fetchAndCache', () => {
    it('无context_返回空串', 0, async () => {
      const result = await IconPickerService.fetchAndCache(null as Object, 'https://example.com/a.png')
      expect(result.length).assertEqual(0)
    })
    it('非远程URL_返回空串', 0, async () => {
      const result = await IconPickerService.fetchAndCache(undefined as Object, 'file://x.png')
      expect(result.length).assertEqual(0)
    })
  })

  describe('IconPickerService_resolveIconPath', () => {
    it('空串返回空', 0, async () => {
      const result = await IconPickerService.resolveIconPath(null as Object, '')
      expect(result).assertEqual('')
    })
    it('本地路径原样返回', 0, async () => {
      const result = await IconPickerService.resolveIconPath(null as Object, 'file://data/icon.png')
      expect(result).assertEqual('file://data/icon.png')
    })
  })
}
