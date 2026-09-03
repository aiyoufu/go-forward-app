import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { Logger } from 'common'
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTs'
import { common } from '@kit.AbilityKit'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { image } from '@kit.ImageKit'
import { LogoCatalogItem, PlatformService } from './PlatformService'

/**
 * 图标选择与网络缓存
 * - listHistoryIcons / recordPickedIcon：点选历史清单（icon_history.json），无清单时回退扫描 filesDir
 * - pickAndCopyFromAlbum：相册选图复制到 filesDir
 * - resolveIconPath / fetchAndCache：从 http(s) URL 下载并缓存为 file://，避免 Image 直连远程失败
 */
export class IconPickerService {
  private static readonly MAX_BYTES: number = 2 * 1024 * 1024
  private static readonly TIMEOUT_MS: number = 8000
  /**
   * 网络图标缓存限边（px）：最大消费方是选择面板网格 56vp，3x 密度 168px、
   * 3.25x 182px，256 再留 4x 余量。调大时旧缓存靠文件名里的 _e<maxEdge> 后缀自动失效。
   */
  private static readonly CACHE_MAX_EDGE: number = 256
  /** 相册选图限边（px）：用户可能选整张照片当图标，原图直存纹理内存差百倍 */
  private static readonly ALBUM_MAX_EDGE: number = 256
  /** 点选历史清单（filesDir 下 JSON 数组，元素为 file:// 路径，越靠前越近） */
  private static readonly HISTORY_FILE: string = 'icon_history.json'
  /** 历史清单保存上限；“最近使用”展示再截到 HISTORY_SHOW */
  private static readonly HISTORY_MAX: number = 50
  private static readonly HISTORY_SHOW: number = 20
  private static readonly pathCache: Map<string, string> = new Map()
  private static readonly inflight: Map<string, Promise<string>> = new Map()
  /**
   * 列出最近使用的图标（app 图标 prefix='icon_' / 卡面 prefix='card_face_'）。
   * 优先读点选历史清单；无清单（老用户）回退扫描 filesDir 按 mtime 降序。
   * 返回元素为 'file://' + 绝对路径。
   * extraPrefixes：同一数据源混存的补充前缀（信用账户 = 卡面 card_face_ + 应用图标 icon_net_）。
   */
  static listHistoryIcons(context: common.UIAbilityContext, prefix: string = 'icon_',
    extraPrefixes: string[] = []): string[] {
    try {
      const filesDir = context.filesDir
      // 点选历史清单优先：真实「最近使用」语义（扫描目录会把仅浏览过的搜索结果也算进来）
      const manifest = filesDir + '/' + IconPickerService.HISTORY_FILE
      if (fileIo.accessSync(manifest)) {
        const recorded = IconPickerService.readHistoryManifest(manifest)
        const picked: string[] = []
        for (let i = 0; i < recorded.length; i++) {
          const p = recorded[i]
          const name = p.substring(p.lastIndexOf('/') + 1)
          if (IconPickerService.nameMatchesPrefix(name, prefix, extraPrefixes) && IconPickerService.fileExists(p)) {
            picked.push(p)
          }
          if (picked.length >= IconPickerService.HISTORY_SHOW) {
            break
          }
        }
        return picked
      }
      const names = fileIo.listFileSync(filesDir)
      const entries: HistoryFile[] = []
      for (let i = 0; i < names.length; i++) {
        const n = names[i]
        if (IconPickerService.nameMatchesPrefix(n, prefix, extraPrefixes) &&
          (n.endsWith('.jpg') || n.endsWith('.png'))) {
          const abs = filesDir + '/' + n
          if (IconPickerService.fileLooksLikeImage(abs)) {
            entries.push(new HistoryFile('file://' + abs, IconPickerService.fileMtime(abs)))
          }
        }
      }
      entries.sort((a: HistoryFile, b: HistoryFile) => b.mtime - a.mtime)
      const icons: string[] = []
      for (let i = 0; i < entries.length && i < IconPickerService.HISTORY_SHOW; i++) {
        icons.push(entries[i].path)
      }
      return icons
    } catch (err) {
      Logger.error('IconPickerService', 'listHistoryIcons failed: ' + JSON.stringify(err))
      return []
    }
  }

  /** 记录一次真实点选（搜索结果 / 相册 / 最近使用再次点选），置顶去重后落盘 */
  static recordPickedIcon(context: common.UIAbilityContext, path: string): void {
    if (!path || path.length === 0) {
      return
    }
    try {
      const filesDir = context.filesDir
      const manifest = filesDir + '/' + IconPickerService.HISTORY_FILE
      const existing = fileIo.accessSync(manifest) ? IconPickerService.readHistoryManifest(manifest) : []
      const next: string[] = [path]
      for (let i = 0; i < existing.length; i++) {
        if (existing[i] !== path) {
          next.push(existing[i])
        }
      }
      while (next.length > IconPickerService.HISTORY_MAX) {
        next.pop()
      }
      const f = fileIo.openSync(manifest,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      try {
        fileIo.writeSync(f.fd, new util.TextEncoder().encodeInto(JSON.stringify(next)))
      } finally {
        fileIo.closeSync(f)
      }
    } catch (err) {
      Logger.error('IconPickerService', 'recordPickedIcon failed: ' + JSON.stringify(err))
    }
  }

  /** 文件名命中主前缀或任一补充前缀 */
  private static nameMatchesPrefix(name: string, prefix: string, extraPrefixes: string[]): boolean {
    if (name.startsWith(prefix)) {
      return true
    }
    for (let i = 0; i < extraPrefixes.length; i++) {
      if (name.startsWith(extraPrefixes[i])) {
        return true
      }
    }
    return false
  }

  private static readHistoryManifest(manifest: string): string[] {
    try {
      const f = fileIo.openSync(manifest, fileIo.OpenMode.READ_ONLY)
      try {
        const st = fileIo.statSync(f.fd)
        const buf = new ArrayBuffer(st.size)
        fileIo.readSync(f.fd, buf)
        const text = util.TextDecoder.create('utf-8').decodeToString(new Uint8Array(buf))
        if (text.trim().length === 0) {
          return []
        }
        const parsed: Object = JSON.parse(text) as Object
        if (!(parsed instanceof Array)) {
          return []
        }
        const arr = parsed as Object[]
        const out: string[] = []
        for (let i = 0; i < arr.length; i++) {
          if (typeof arr[i] === 'string') {
            out.push(arr[i] as string)
          }
        }
        return out
      } finally {
        fileIo.closeSync(f)
      }
    } catch (_e) {
      return []
    }
  }

  private static fileMtime(absPath: string): number {
    try {
      return fileIo.statSync(absPath).mtime
    } catch (_e) {
      return 0
    }
  }

  /**
   * 从系统相册选一张图，复制到 filesDir 下，返回 file:// 路径
   * 用户取消或异常返回空串 ''
   * prefix：随数据源落盘（app 图标 icon_ / 卡面 card_face_），保证「最近使用」按数据源隔离
   */
  static async pickAndCopyFromAlbum(context: common.UIAbilityContext,
    prefix: string = 'icon_'): Promise<string> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const photoPicker = new photoAccessHelper.PhotoViewPicker()
      const result = await photoPicker.select(options)
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        return ''
      }
      const uri = result.photoUris[0]
      const filesDir = context.filesDir
      const fileName = prefix + Date.now() + '_' + (uri.split('/').pop()?.split('.').shift() || 'temp') + '.jpg'
      const destPath = filesDir + '/' + fileName

      const srcFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const stat = fileIo.statSync(srcFile.fd)
      const buf = new ArrayBuffer(stat.size)
      fileIo.readSync(srcFile.fd, buf)
      fileIo.closeSync(srcFile)

      // 相册图常为整张照片：先等比缩到限边再落盘；解码失败（冷门格式）回退原样复制
      const scaled = await IconPickerService.downscaleToFormat(
        buf, IconPickerService.ALBUM_MAX_EDGE, 'image/jpeg', 90)
      const payload = scaled !== null ? scaled : buf

      const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      fileIo.writeSync(destFile.fd, payload)
      fileIo.closeSync(destFile)

      return 'file://' + destPath
    } catch (err) {
      Logger.error('IconPickerService', 'pickAndCopyFromAlbum failed: ' + JSON.stringify(err))
      return ''
    }
  }

  /** 是否为可下载的网络图标地址 */
  static isRemoteUrl(url: string): boolean {
    if (!url || url.length === 0) {
      return false
    }
    const t = url.trim().toLowerCase()
    return t.startsWith('https://') || t.startsWith('http://')
  }

  /** 内置图 rawfile 路径：$rawfile:<path> 形式，搜索面板预览直接吃，落地时复制到 filesDir */
  static isRawfilePath(url: string): boolean {
    if (!url || url.length === 0) {
      return false
    }
    return url.trim().startsWith('$rawfile:')
  }

  /**
   * 是否按横卡面渲染（而非圆标），决定列表卡的宽高比与圆角。
   * 信用账户桶里两类并存：卡面上云为 icon_/card_face_ 前缀，信贷平台应用图标
   * （花呗等）上云保留 icon_net_ 前缀，按前缀区分。
   */
  static isCardFaceUrl(url: string): boolean {
    if (!url || url.length === 0) {
      return false
    }
    if (url.indexOf('card_face_') >= 0) {
      return true
    }
    if (url.indexOf('credit-account-icons') < 0) {
      return false
    }
    return url.indexOf('icon_net_') < 0
  }

  /**
   * 把 $rawfile: 内置 PNG 落地为 file://<filesDir>/<prefix><key>.png。
   * 与下载缓存同一目录、同前缀规则，云端上传、跨设备同步按既有 file:// 链路处理。
   */
  static async resolveRawfileIcon(context: common.UIAbilityContext, url: string,
    prefix: string = 'icon_net_'): Promise<string> {
    if (!url || !IconPickerService.isRawfilePath(url)) {
      return ''
    }
    if (!context || !context.filesDir) {
      return ''
    }
    const cacheKey = prefix + url
    const cached = IconPickerService.pathCache.get(cacheKey)
    if (cached !== undefined && cached.length > 0 && IconPickerService.fileExists(cached)) {
      return cached
    }
    const relPath = url.substring('$rawfile:'.length)
    if (relPath.length === 0) {
      return ''
    }
    let bytes: ArrayBuffer
    try {
      const rm = context.resourceManager
      if (rm === undefined || rm === null) {
        return ''
      }
      // getRawFileContent 返回 Uint8Array；.buffer 在 lib 里是 ArrayBufferLike（结构化类型），
      // ArkTS 严格模式拒绝隐式赋给 ArrayBuffer。显式 copy 一份新的 ArrayBuffer 满足下游签名。
      const u8: Uint8Array = await rm.getRawFileContent(relPath)
      const buf = new ArrayBuffer(u8.byteLength)
      new Uint8Array(buf).set(u8)
      bytes = buf
    } catch (err) {
      Logger.error('IconPickerService', 'resolveRawfileIcon read failed: ' + JSON.stringify(err))
      return ''
    }
    if (bytes.byteLength < 32) {
      return ''
    }
    if (!IconPickerService.isImageBytes(bytes)) {
      return ''
    }
    const ext = IconPickerService.guessExt(url, 'image/png')
    const destPath = context.filesDir + '/' +
      IconPickerService.cacheBaseName(prefix, url, 0) + '.' + ext
    try {
      const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
      try {
        fileIo.writeSync(destFile.fd, bytes)
      } finally {
        fileIo.closeSync(destFile)
      }
    } catch (err) {
      Logger.error('IconPickerService', 'resolveRawfileIcon write failed: ' + JSON.stringify(err))
      return ''
    }
    const local = 'file://' + destPath
    IconPickerService.pathCache.set(cacheKey, local)
    return local
  }

  /**
   * HarmonyOS http.request 不接受未编码的空格 / 非 ASCII。
   * 只编码 path（query 由调用方自行 encodeURIComponent，避免二次编码）。
   * encodeURI 会保留 jsdelivr 的 @ 与括号。
   */
  static encodeHttpUrl(url: string): string {
    if (url.length === 0) {
      return url
    }
    let cut = url.length
    const qMark = url.indexOf('?')
    if (qMark >= 0 && qMark < cut) {
      cut = qMark
    }
    const hash = url.indexOf('#')
    if (hash >= 0 && hash < cut) {
      cut = hash
    }
    try {
      return encodeURI(url.substring(0, cut)) + url.substring(cut)
    } catch (_e) {
      return url
    }
  }

  /** URL 稳定短键，用于缓存文件名（非加密） */
  static urlKey(url: string): string {
    let h = 5381
    for (let i = 0; i < url.length; i++) {
      h = ((h << 5) + h) + url.charCodeAt(i)
      h = h & 0x7fffffff
    }
    return h.toString(16)
  }

  /** 从 favicon URL 或站点地址取出域名 */
  static extractDomain(url: string): string {
    const t = url.trim()
    if (t.length === 0) {
      return ''
    }
    const domainEq = t.toLowerCase().indexOf('domain=')
    if (domainEq >= 0) {
      let rest = t.substring(domainEq + 7)
      const amp = rest.indexOf('&')
      if (amp >= 0) {
        rest = rest.substring(0, amp)
      }
      return IconPickerService.stripHost(rest)
    }
    return IconPickerService.stripHost(t)
  }

  private static stripHost(raw: string): string {
    let s = raw.trim()
    if (s.length === 0) {
      return ''
    }
    const low = s.toLowerCase()
    if (low.startsWith('https://')) {
      s = s.substring(8)
    } else if (low.startsWith('http://')) {
      s = s.substring(7)
    }
    const slash = s.indexOf('/')
    if (slash >= 0) {
      s = s.substring(0, slash)
    }
    const q = s.indexOf('?')
    if (q >= 0) {
      s = s.substring(0, q)
    }
    if (s.startsWith('www.')) {
      s = s.substring(4)
    }
    return s.toLowerCase()
  }

  private static domainLabel(domain: string): string {
    const parts = domain.split('.')
    if (parts.length === 0) {
      return ''
    }
    if ((parts[0] === 'www' || parts[0] === 'm') && parts.length > 1) {
      return parts[1]
    }
    return parts[0]
  }

  /** 同一域名多源：国内可访问的优先，Google 作兜底 */
  static iconCandidates(url: string): string[] {
    const out: string[] = []
    const push = (u: string) => {
      if (u.length === 0) {
        return
      }
      for (let i = 0; i < out.length; i++) {
        if (out[i] === u) {
          return
        }
      }
      out.push(u)
    }
    if (IconPickerService.isRemoteUrl(url)) {
      push(url.trim())
    }
    const domain = IconPickerService.extractDomain(url)
    if (domain.length > 0) {
      const host = IconPickerService.domainLabel(domain)
      if (host.length > 0 && domain.split('.').length === 2) {
        push('https://cdn.simpleicons.org/' + host)
      }
      push('https://' + domain + '/apple-touch-icon.png')
      push('https://' + domain + '/favicon.png')
      push('https://' + domain + '/favicon.ico')
      push('https://favicon.im/' + domain + '?larger=true')
      push('https://statics.dnspod.cn/proxy_favicon/_/favicon?domain=' + domain)
      push('https://icons.duckduckgo.com/ip3/' + domain + '.ico')
      push('https://www.google.com/s2/favicons?sz=256&domain=' + domain)
    }
    return out
  }

  /** 由 Content-Type 或 URL 后缀推断 jpg/png */
  static guessExt(url: string, contentType: string): string {
    const ct = contentType.toLowerCase()
    if (ct.indexOf('jpeg') >= 0 || ct.indexOf('jpg') >= 0) {
      return 'jpg'
    }
    if (ct.indexOf('png') >= 0) {
      return 'png'
    }
    if (ct.indexOf('webp') >= 0) {
      return 'png'
    }
    const u = url.toLowerCase()
    if (u.indexOf('.jpg') >= 0 || u.indexOf('.jpeg') >= 0) {
      return 'jpg'
    }
    return 'png'
  }

  /**
   * 把任意图标地址解析为本地可显示路径。
   * file:// 原样返回；http(s) 下载到 filesDir 后返回 file://；失败返回空串。
   * $rawfile: 内置图（信贷平台 logo）首次复制到 filesDir，返回 file://，
   * 保证下游 icon_url 走的是 file:// 标准链路（云上传、跨设备同步都按既有规则处理）。
   * exact=true：直连图资源（CDN 直链），只取 URL 本身，不做域名 favicon 兜底；
   * prefix：缓存文件前缀，区分不同数据源（卡面 card_face_ / app 图标 icon_net_）。
   */
  static async resolveIconPath(context: common.UIAbilityContext, url: string,
    exact: boolean = false, prefix: string = 'icon_net_',
    readMs: number = IconPickerService.TIMEOUT_MS,
    maxEdge: number = IconPickerService.CACHE_MAX_EDGE): Promise<string> {
    if (!url || url.length === 0) {
      return ''
    }
    const trimmed = url.trim()
    if (IconPickerService.isRawfilePath(trimmed)) {
      return await IconPickerService.resolveRawfileIcon(context, trimmed, prefix)
    }
    if (!IconPickerService.isRemoteUrl(trimmed)) {
      return trimmed
    }
    if (!context || !context.filesDir) {
      return ''
    }
    const cacheKey = prefix + trimmed
    const cached = IconPickerService.pathCache.get(cacheKey)
    if (cached !== undefined && cached.length > 0 && IconPickerService.fileExists(cached)) {
      return cached
    }
    const existing = IconPickerService.findCachedFile(context, trimmed, prefix, maxEdge)
    if (existing.length > 0) {
      IconPickerService.pathCache.set(cacheKey, existing)
      return existing
    }
    const pending = IconPickerService.inflight.get(cacheKey)
    if (pending !== undefined) {
      return pending
    }
    const work = IconPickerService.fetchAndCache(context, trimmed, exact, prefix, readMs, maxEdge)
    IconPickerService.inflight.set(cacheKey, work)
    try {
      return await work
    } finally {
      IconPickerService.inflight.delete(cacheKey)
    }
  }

  /**
   * 下载网络图标并写入 filesDir/<prefix><key>.png
   * 失败或非图片返回 ''；exact=true 时不做域名 favicon 多源兜底
   */
  static async fetchAndCache(context: common.UIAbilityContext, url: string,
    exact: boolean = false, prefix: string = 'icon_net_',
    readMs: number = IconPickerService.TIMEOUT_MS,
    maxEdge: number = IconPickerService.CACHE_MAX_EDGE): Promise<string> {
    if (!context || !context.filesDir) {
      return ''
    }
    const trimmed = url.trim()
    if (!IconPickerService.isRemoteUrl(trimmed)) {
      return ''
    }
    try {
      const candidates = exact ? [trimmed] : IconPickerService.iconCandidates(trimmed)
      for (let i = 0; i < candidates.length; i++) {
        const packed = await IconPickerService.httpGetBytes(candidates[i], IconPickerService.TIMEOUT_MS, readMs)
        if (packed === null || packed.bytes.byteLength < 64) {
          continue
        }
        if (packed.bytes.byteLength > IconPickerService.MAX_BYTES) {
          continue
        }
        const keepRaw = maxEdge <= 0 && IconPickerService.isPngOrJpeg(packed.bytes)
        let payload: ArrayBuffer | null = null
        let ext = 'png'
        if (keepRaw) {
          payload = packed.bytes
          ext = IconPickerService.isJpegBytes(packed.bytes) ? 'jpg' : 'png'
        } else {
          payload = await IconPickerService.bytesToPng(packed.bytes)
        }
        if (payload === null || payload.byteLength < 64) {
          continue
        }
        const destPath = context.filesDir + '/' +
          IconPickerService.cacheBaseName(prefix, trimmed, maxEdge) + '.' + ext
        const destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC)
        try {
          fileIo.writeSync(destFile.fd, payload)
        } finally {
          fileIo.closeSync(destFile)
        }
        const local = 'file://' + destPath
        IconPickerService.pathCache.set(prefix + trimmed, local)
        return local
      }
      return ''
    } catch (err) {
      Logger.error('IconPickerService', 'fetchAndCache failed: ' + JSON.stringify(err))
      return ''
    }
  }

  /**
   * 缓存文件基名。转码缓存（maxEdge>0）在文件名里带 _e<maxEdge> 版本后缀：
   * 调整 CACHE_MAX_EDGE 或调用方传参变化时，旧分辨率文件不再命中、自动过期；
   * 卡面原图直存（maxEdge=0）内容与常量无关，不加后缀、不重复下载。
   */
  private static cacheBaseName(prefix: string, url: string, maxEdge: number): string {
    return prefix + IconPickerService.urlKey(url) + (maxEdge > 0 ? '_e' + maxEdge : '')
  }

  private static findCachedFile(context: common.UIAbilityContext, url: string,
    prefix: string = 'icon_net_',
    maxEdge: number = IconPickerService.CACHE_MAX_EDGE): string {
    try {
      const base = IconPickerService.cacheBaseName(prefix, url, maxEdge)
      const filesDir = context.filesDir
      const png = filesDir + '/' + base + '.png'
      const jpg = filesDir + '/' + base + '.jpg'
      if (fileIo.accessSync(png) && IconPickerService.fileLooksLikeImage(png)) {
        return 'file://' + png
      }
      if (fileIo.accessSync(jpg) && IconPickerService.fileLooksLikeImage(jpg)) {
        return 'file://' + jpg
      }
    } catch (_e) {
    }
    return ''
  }

  /**
   * ICO 里常内嵌 PNG；解析目录取「最大尺寸」的那张。目录通常小图在前，
   * 顺序扫第一个签名会拿到 16/32px 小图，放大到 100px+ 显示时发糊。
   * 目录不合法（截断/字段越界）时回退全文件扫第一个 PNG（旧实现行为）。
   */
  static extractEmbeddedPng(buf: ArrayBuffer): ArrayBuffer | null {
    const u = new Uint8Array(buf)
    // ICO 头：reserved(2) + type(2) + count(2)；目录项 16 字节，width/height 为 0 表示 256
    if (u.length >= 6 && u[0] === 0 && u[1] === 0 && u[2] === 1 && u[3] === 0) {
      const count = (u[4] | (u[5] << 8)) >>> 0
      let bestOff = -1
      let bestLen = 0
      let bestArea = -1
      for (let i = 0; i < count; i++) {
        const e = 6 + i * 16
        if (e + 16 > u.length) {
          break
        }
        const w = u[e] === 0 ? 256 : u[e]
        const h = u[e + 1] === 0 ? 256 : u[e + 1]
        const len = (u[e + 8] | (u[e + 9] << 8) | (u[e + 10] << 16) | (u[e + 11] << 24)) >>> 0
        const off = (u[e + 12] | (u[e + 13] << 8) | (u[e + 14] << 16) | (u[e + 15] << 24)) >>> 0
        if (len === 0 || off + len > u.length || !IconPickerService.isPngAt(u, off)) {
          continue
        }
        const area = w * h
        if (area > bestArea) {
          bestArea = area
          bestOff = off
          bestLen = len
        }
      }
      if (bestOff >= 0) {
        return IconPickerService.sliceBytes(u, bestOff, bestLen)
      }
    }
    let start = -1
    for (let i = 0; i <= u.length - 8; i++) {
      if (IconPickerService.isPngAt(u, i)) {
        start = i
        break
      }
    }
    if (start < 0) {
      return null
    }
    for (let i = start + 8; i <= u.length - 8; i++) {
      if (u[i] === 0x49 && u[i + 1] === 0x45 && u[i + 2] === 0x4E && u[i + 3] === 0x44) {
        return IconPickerService.sliceBytes(u, start, i + 8 - start)
      }
    }
    return null
  }

  private static isPngAt(u: Uint8Array, off: number): boolean {
    return off >= 0 && off + 8 <= u.length &&
      u[off] === 0x89 && u[off + 1] === 0x50 && u[off + 2] === 0x4E && u[off + 3] === 0x47 &&
      u[off + 4] === 0x0D && u[off + 5] === 0x0A && u[off + 6] === 0x1A && u[off + 7] === 0x0A
  }

  private static sliceBytes(u: Uint8Array, start: number, len: number): ArrayBuffer {
    const out = new ArrayBuffer(len)
    const dest = new Uint8Array(out)
    for (let k = 0; k < len; k++) {
      dest[k] = u[start + k]
    }
    return out
  }

  /**
   * 解码位图并按最长边等比缩放后重编码。
   * 缓存即目标尺寸：列表小图免过采样解码，纹理内存与首滚解码开销大幅下降。
   * 解码失败返回 null（调用方决定兜底策略）。
   */
  private static async downscaleToFormat(buf: ArrayBuffer, maxEdge: number,
    format: string, quality: number): Promise<ArrayBuffer | null> {
    try {
      const source = image.createImageSource(buf)
      let pixelMap: image.PixelMap | undefined = undefined
      try {
        const info = await source.getImageInfo()
        const w = info.size.width
        const h = info.size.height
        if (w <= 0 || h <= 0) {
          return null
        }
        // 等比缩到限边内；字面量内联以获得 DecodingOptions/Size 上下文类型
        const scale = Math.min(1, maxEdge / Math.max(w, h))
        pixelMap = await source.createPixelMap({
          desiredSize: {
            width: Math.max(1, Math.round(w * scale)),
            height: Math.max(1, Math.round(h * scale))
          }
        })
      } finally {
        try {
          source.release()
        } catch (_se) {
        }
      }
      if (pixelMap === undefined) {
        return null
      }
      const packer = image.createImagePacker()
      try {
        const ab = await packer.packToData(pixelMap, { format: format, quality: quality })
        return ab.byteLength >= 64 ? ab : null
      } finally {
        try {
          packer.release()
        } catch (_pe) {
        }
        try {
          pixelMap.release()
        } catch (_re) {
        }
      }
    } catch (_e) {
      return null
    }
  }

  /** 网络图标统一落盘为「限边内 PNG」；ICO 先剥内嵌 PNG（ImageKit 不解码 ICO）再归一化尺寸 */
  private static async bytesToPng(buf: ArrayBuffer): Promise<ArrayBuffer | null> {
    const embedded = IconPickerService.extractEmbeddedPng(buf)
    const src = embedded !== null ? embedded : buf
    return IconPickerService.downscaleToFormat(src, IconPickerService.CACHE_MAX_EDGE, 'image/png', 100)
  }

  static isJpegBytes(buf: ArrayBuffer): boolean {
    if (buf.byteLength < 3) {
      return false
    }
    const u = new Uint8Array(buf)
    return u[0] === 0xFF && u[1] === 0xD8
  }

  static isPngOrJpeg(buf: ArrayBuffer): boolean {
    if (buf.byteLength < 8) {
      return false
    }
    const u = new Uint8Array(buf)
    if (u[0] === 0x89 && u[1] === 0x50 && u[2] === 0x4E && u[3] === 0x47) {
      return true
    }
    return IconPickerService.isJpegBytes(buf)
  }

  /** PNG / JPEG / GIF / ICO / WEBP 文件头 */
  static isImageBytes(buf: ArrayBuffer): boolean {
    if (buf.byteLength < 12) {
      return false
    }
    const u = new Uint8Array(buf)
    if (u[0] === 0x89 && u[1] === 0x50 && u[2] === 0x4E && u[3] === 0x47) {
      return true
    }
    if (IconPickerService.isJpegBytes(buf)) {
      return true
    }
    if (u[0] === 0x47 && u[1] === 0x49 && u[2] === 0x46) {
      return true
    }
    if (IconPickerService.isIcoBytes(buf)) {
      return true
    }
    if (u[0] === 0x52 && u[1] === 0x49 && u[2] === 0x46 && u[3] === 0x46 &&
      u[8] === 0x57 && u[9] === 0x45 && u[10] === 0x42 && u[11] === 0x50) {
      return true
    }
    return false
  }

  static isIcoBytes(buf: ArrayBuffer): boolean {
    if (buf.byteLength < 4) {
      return false
    }
    const u = new Uint8Array(buf)
    return u[0] === 0x00 && u[1] === 0x00 && u[2] === 0x01 && u[3] === 0x00
  }

  private static fileLooksLikeImage(absPath: string): boolean {
    try {
      const f = fileIo.openSync(absPath, fileIo.OpenMode.READ_ONLY)
      try {
        const st = fileIo.statSync(f.fd)
        if (st.size < 32) {
          return false
        }
        const head = new ArrayBuffer(16)
        fileIo.readSync(f.fd, head)
        return IconPickerService.isImageBytes(head)
      } finally {
        fileIo.closeSync(f)
      }
    } catch (_e) {
      return false
    }
  }

  /**
   * 按名称查应用图标：本地预设目录优先，iTunes 兜底。
   * - 本地预设（信贷平台 + 主流订阅）是离线正解，先入列；
   * - iTunes 搜索不支持翻页（offset 被服务端忽略），一次取 50 条再按名称过滤；
   * - 同名以本地为准，避免 iTunes 误中「同名应用」盖掉品牌正解。
   */
  static async searchIconsByName(query: string): Promise<LogoCatalogItem[]> {
    const q = query.trim()
    if (q.length === 0) {
      return []
    }
    const out: LogoCatalogItem[] = []
    const seen: Map<string, boolean> = new Map()
    const presets = PlatformService.searchLogoCatalog(q)
    for (let i = 0; i < presets.length; i++) {
      const key = presets[i].name.toLowerCase()
      if (seen.get(key) === true) {
        continue
      }
      seen.set(key, true)
      out.push(presets[i])
    }
    const api = 'https://itunes.apple.com/search?entity=software&country=cn&limit=50&term='
      + encodeURIComponent(q)
    const parsed = await IconPickerService.httpGetJson(api)
    if (parsed !== null) {
      const itunes = IconPickerService.parseItunes(parsed, q)
      for (let i = 0; i < itunes.length; i++) {
        const key = itunes[i].name.toLowerCase()
        if (seen.get(key) === true) {
          continue
        }
        seen.set(key, true)
        out.push(itunes[i])
      }
    }
    return out
  }

  private static parseItunes(parsed: object, q: string): LogoCatalogItem[] {
    const out: LogoCatalogItem[] = []
    const root: Record<string, object | object[]> = parsed as Record<string, object | object[]>
    const raw = root['results']
    if (raw === undefined || !Array.isArray(raw)) {
      return out
    }
    const arr: object[] = raw
    const seen: Map<string, boolean> = new Map()
    for (let i = 0; i < arr.length; i++) {
      const row: Record<string, string> = arr[i] as Record<string, string>
      const name = row['trackName']
      if (name === undefined || name.length === 0) {
        continue
      }
      if (!PlatformService.logoNameMatches(name, q)) {
        continue
      }
      const art = IconPickerService.itunesArtwork(row)
      if (art.length === 0) {
        continue
      }
      const key = name.toLowerCase()
      if (seen.get(key) === true) {
        continue
      }
      seen.set(key, true)
      out.push(new LogoCatalogItem(name, art))
    }
    return out
  }

  /**
   * 统一取 200x200 规格：最大消费方（选择面板网格 56vp）3x~3.25x 密度约 168~182px，
   * 200 已覆盖；512 原图纯浪费带宽，是搜索结果图显示慢的主因。
   */
  private static itunesArtwork(row: Record<string, string>): string {
    const a512 = row['artworkUrl512']
    if (a512 !== undefined && a512.length > 0) {
      return a512.indexOf('512x512') >= 0 ? a512.replace('512x512', '200x200') : a512
    }
    const a100 = row['artworkUrl100']
    if (a100 === undefined || a100.length === 0) {
      return ''
    }
    return a100.replace('100x100', '200x200')
  }

  /** GET 文本资源（JSON 索引等），失败返回空串 */
  static httpGetText(url: string): Promise<string> {
    return new Promise<string>((resolve) => {
      const req = http.createHttp()
      req.request(IconPickerService.encodeHttpUrl(url), {
        method: http.RequestMethod.GET,
        connectTimeout: IconPickerService.TIMEOUT_MS,
        readTimeout: IconPickerService.TIMEOUT_MS,
        header: {
          'Accept': 'application/json',
          'User-Agent': 'GoForwardApp/1.0 (icon-search)'
        }
      }, (err: BusinessError, data: http.HttpResponse) => {
        req.destroy()
        if (err || data === undefined || data.responseCode !== 200) {
          resolve('')
          return
        }
        resolve(typeof data.result === 'string' ? data.result as string : '')
      })
    })
  }

  private static httpGetJson(url: string): Promise<object | object[] | null> {
    return new Promise<object | object[] | null>((resolve) => {
      IconPickerService.httpGetText(url).then((text: string) => {
        if (text.length === 0) {
          resolve(null)
          return
        }
        try {
          const parsed: object | object[] = JSON.parse(text) as object
          resolve(parsed)
        } catch (_pe) {
          resolve(null)
        }
      })
    })
  }

  private static fileExists(fileUri: string): boolean {
    try {
      const path = fileUri.startsWith('file://') ? fileUri.substring(7) : fileUri
      return fileIo.accessSync(path)
    } catch (_e) {
      return false
    }
  }

  private static httpGetBytes(url: string,
    connectMs: number = IconPickerService.TIMEOUT_MS,
    readMs: number = IconPickerService.TIMEOUT_MS): Promise<IconDownload | null> {
    return new Promise<IconDownload | null>((resolve) => {
      const req = http.createHttp()
      req.request(IconPickerService.encodeHttpUrl(url), {
        method: http.RequestMethod.GET,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: connectMs,
        readTimeout: readMs,
        header: {
          'Accept': 'image/png,image/jpeg,image/webp,image/*;q=0.8',
          'User-Agent': 'Mozilla/5.0 (Linux; Android 13) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36'
        }
      }, (err: BusinessError, data: http.HttpResponse) => {
        req.destroy()
        if (err || data === undefined || data.responseCode !== 200) {
          resolve(null)
          return
        }
        const raw = data.result as ArrayBuffer
        if (raw === undefined || raw === null || raw.byteLength === undefined || raw.byteLength === 0) {
          resolve(null)
          return
        }
        let contentType = ''
        try {
          const headers = data.header as Record<string, string>
          if (headers !== undefined && headers !== null) {
            const ct = headers['content-type'] ?? headers['Content-Type']
            if (typeof ct === 'string') {
              contentType = ct
            }
          }
        } catch (_he) {
        }
        const packed = new IconDownload()
        packed.bytes = raw
        packed.contentType = contentType
        resolve(packed)
      })
    })
  }
}

class IconDownload {
  bytes: ArrayBuffer = new ArrayBuffer(0)
  contentType: string = ''
}

/** 目录扫描回退用的 mtime 排序载体 */
class HistoryFile {
  path: string = ''
  mtime: number = 0

  constructor(path: string, mtime: number) {
    this.path = path
    this.mtime = mtime
  }
}
