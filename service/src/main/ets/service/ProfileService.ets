import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import { Logger } from 'common'
import { AuthManager } from './auth/AuthManager'
import { AuthUserProfile, SupabaseAuthService } from './auth/SupabaseAuthService'
import { CryptoService } from './auth/CryptoService'
import { SettingsService } from './SettingsService'
import { UserService } from './UserService'

/** 相册选图结果：uri 为空串表示取消或不可用 */
export class AvatarPickResult {
  uri: string = ''
  tooLarge: boolean = false
}

/**
 * 个人资料：本机 filesDir 缓存 + 云端 auth user_metadata（与 Web 端 nickname / avatar_data_url 同源）。
 * 头像文件不参与导出导入；读取失败由调用方回退首字母色块。
 */
export class ProfileService {
  static readonly DATA_URL_PREFIX: string = 'data:image/jpeg;base64,'
  private static readonly MAX_DATA_URL_CHARS: number = 4 * 1024
  /** 头像源图大小上限（原图直解码内存差百倍，超限直接拒绝） */
  static readonly MAX_SOURCE_BYTES: number = 10 * 1024 * 1024
  static readonly MSG_SOURCE_TOO_LARGE: string = '图片过大（超过 10MB），请压缩或更换后重试'
  /** 编辑态解码限边（px）：覆盖裁剪取景足够，避免长截图全尺寸解码 */
  private static readonly DECODE_MAX_EDGE: number = 4096
  /** 裁剪输出边长（px）：44~60vp 显示的 2x 余量 */
  private static readonly OUTPUT_EDGE: number = 256

  /**
   * 拉起相册选一张图，仅校验大小并返回临时 uri，不落盘。
   * 裁剪编辑在 AvatarCropPage 完成后经 saveCroppedAvatar 写入。
   */
  static async pickAvatarSource(): Promise<AvatarPickResult> {
    const result = new AvatarPickResult()
    try {
      const picker = new photoAccessHelper.PhotoViewPicker()
      const picked = await picker.select({
        MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
        maxSelectNumber: 1
      })
      if (picked.photoUris.length === 0) {
        return result
      }
      result.uri = picked.photoUris[0]
      const src = fs.openSync(result.uri, fs.OpenMode.READ_ONLY)
      try {
        const stat = fs.statSync(src.fd)
        if (stat.size > ProfileService.MAX_SOURCE_BYTES) {
          result.tooLarge = true
          result.uri = ''
        }
      } finally {
        try {
          fs.closeSync(src)
        } catch (_e2) {
        }
      }
    } catch (_e) {
      result.uri = ''
    }
    return result
  }

  /**
   * 把相册临时 uri 解码为可编辑 PixelMap；超限边等比压缩解码。
   * @returns 解码失败返回 null（过大已在选择时拦截，此处多为冷门格式）
   */
  static async loadEditableAvatarPixelMap(uri: string): Promise<image.PixelMap | null> {
    let fd: number = -1
    try {
      const file = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      fd = file.fd
      const stat = fs.statSync(fd)
      if (stat.size <= 0) {
        return null
      }
      const buf = new ArrayBuffer(stat.size)
      fs.readSync(fd, buf)
      fs.closeSync(fd)
      fd = -1
      const source = image.createImageSource(buf)
      let pixelMap: image.PixelMap | null = null
      try {
        const info = await source.getImageInfo()
        if (info !== undefined && info !== null && info.size !== undefined) {
          const w = info.size.width
          const h = info.size.height
          const maxEdge = w > h ? w : h
          if (w > 0 && h > 0 && maxEdge > ProfileService.DECODE_MAX_EDGE) {
            const scale = ProfileService.DECODE_MAX_EDGE / maxEdge
            const opts: image.DecodingOptions = {
              desiredSize: { width: Math.max(1, Math.floor(w * scale)), height: Math.max(1, Math.floor(h * scale)) }
            }
            pixelMap = await source.createPixelMap(opts)
          }
        }
        if (pixelMap === null) {
          pixelMap = await source.createPixelMap()
        }
      } finally {
        try {
          source.release()
        } catch (_se) {
        }
      }
      return pixelMap
    } catch (_e) {
      return null
    } finally {
      if (fd >= 0) {
        try {
          fs.closeSync(fd)
        } catch (_ce) {
        }
      }
    }
  }

  /**
   * 裁剪结果落盘 + 更新本机设置 + 云端同步（dataURL 超限静默跳过，与既有行为一致）。
   * @param cropped 已按取景框裁好的方形 PixelMap（会被缩放到 OUTPUT_EDGE）
   * @returns 全流程是否成功
   */
  static async saveCroppedAvatar(
    context: common.UIAbilityContext,
    userId: string,
    cropped: image.PixelMap
  ): Promise<boolean> {
    try {
      const finalPx = await ProfileService.scaleSquareTo(cropped, ProfileService.OUTPUT_EDGE)
      const target = finalPx !== null ? finalPx : cropped
      const packed = await ProfileService.packJpeg(target, 85)
      if (finalPx !== null) {
        try {
          finalPx.release()
        } catch (_re) {
        }
      }
      if (packed === null || packed.byteLength < 32) {
        return false
      }
      const fileName = 'avatar_' + userId + '.jpg'
      const destPath = context.filesDir + '/' + fileName
      const dest = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      try {
        fs.writeSync(dest.fd, packed)
      } finally {
        fs.closeSync(dest)
      }
      const settings = await SettingsService.getSettings(userId)
      settings.profile_avatar_path = fileName
      await SettingsService.saveSettings(settings)
      const dataUrl = await ProfileService.fileToAvatarDataUrl(context, fileName)
      if (dataUrl.length > 0) {
        await ProfileService.pushAvatarDataUrl(dataUrl)
      }
      return true
    } catch (err) {
      Logger.warn('ProfileService', 'saveCroppedAvatar failed: ' + JSON.stringify(err))
      return false
    }
  }

  /** 方形图缩到目标边长（pack→重解码 desiredSize），无需缩放返回 null 由调用方沿用原图 */
  private static async scaleSquareTo(src: image.PixelMap, edge: number): Promise<image.PixelMap | null> {
    try {
      const info = await src.getImageInfo()
      if (info === undefined || info === null || info.size === undefined) {
        return null
      }
      const side = info.size.width < info.size.height ? info.size.width : info.size.height
      if (side <= 0 || side <= edge) {
        return null
      }
      const packed = await ProfileService.packJpegBase64(src, 90)
      if (packed.length === 0) {
        return null
      }
      const bytes = CryptoService.decodeBase64(packed)
      const source = image.createImageSource(bytes.buffer)
      const opts: image.DecodingOptions = {
        desiredSize: { width: edge, height: edge }
      }
      const copy = await source.createPixelMap(opts)
      try {
        source.release()
      } catch (_se) {
      }
      return copy
    } catch (_e) {
      return null
    }
  }

  private static async packJpeg(pixelMap: image.PixelMap, quality: number): Promise<ArrayBuffer | null> {
    const packer = image.createImagePacker()
    try {
      const opts: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
      }
      return await packer.packToData(pixelMap, opts)
    } catch (_e) {
      return null
    } finally {
      try {
        packer.release()
      } catch (_e2) {
      }
    }
  }

  /**
   * 按文件名解码头像 PixelMap（覆盖写后同路径也能刷新，避免 Image 组件 uri 缓存）。
   * @returns 文件缺失或解码失败返回 null，调用方回退首字母色块
   */
  static async loadAvatarPixelMap(context: common.Context, fileName: string): Promise<image.PixelMap | null> {
    if (fileName.length === 0) {
      return null
    }
    const path = context.filesDir + '/' + fileName
    try {
      if (!fs.accessSync(path)) {
        return null
      }
      const source = image.createImageSource(path)
      const pixelMap = await source.createPixelMap()
      await source.release()
      return pixelMap
    } catch {
      return null
    }
  }

  static stripDataUrlPrefix(dataUrl: string): string {
    const marker = 'base64,'
    const idx = dataUrl.indexOf(marker)
    if (idx < 0) {
      return dataUrl
    }
    return dataUrl.substring(idx + marker.length)
  }

  /** 从云端拉取昵称/头像并写入本机缓存，供「我的」页展示 */
  static async pullFromCloud(context: common.UIAbilityContext): Promise<AuthUserProfile> {
    const empty = new AuthUserProfile()
    const session = await AuthManager.loadSession()
    if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return empty
    }
    const result = await SupabaseAuthService.getUser(session.accessToken)
    if (!result.success) {
      return empty
    }
    await ProfileService.applyCloudProfile(context, session.userId, result.profile)
    return result.profile
  }

  static async applyCloudProfile(
    context: common.UIAbilityContext,
    userId: string,
    profile: AuthUserProfile
  ): Promise<void> {
    const settings = await SettingsService.getSettings(userId)
    let changed = false
    if (profile.nickname.length > 0 && profile.nickname !== settings.profile_nickname) {
      settings.profile_nickname = profile.nickname
      changed = true
    }
    if (profile.avatar_data_url.length > 0) {
      const fileName = await ProfileService.writeAvatarDataUrl(context, userId, profile.avatar_data_url)
      if (fileName.length > 0 && fileName !== settings.profile_avatar_path) {
        settings.profile_avatar_path = fileName
        changed = true
      } else if (fileName.length > 0 && settings.profile_avatar_path.length === 0) {
        settings.profile_avatar_path = fileName
        changed = true
      }
    }
    if (changed) {
      await SettingsService.saveSettings(settings)
    }
  }

  static async pushNickname(nickname: string): Promise<boolean> {
    const session = await AuthManager.loadSession()
    if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return false
    }
    const result = await SupabaseAuthService.updateUserNickname(session.accessToken, nickname)
    return result.success
  }

  static async pushAvatarDataUrl(dataUrl: string): Promise<boolean> {
    const session = await AuthManager.loadSession()
    if (session === null || session.mode !== 'cloud' || session.accessToken.length === 0) {
      return false
    }
    const result = await SupabaseAuthService.updateUserAvatar(session.accessToken, dataUrl)
    return result.success
  }

  static async writeAvatarDataUrl(
    context: common.UIAbilityContext,
    userId: string,
    dataUrl: string
  ): Promise<string> {
    const b64 = ProfileService.stripDataUrlPrefix(dataUrl)
    if (b64.length === 0) {
      return ''
    }
    const bytes = CryptoService.decodeBase64(b64)
    if (bytes.length < 32) {
      return ''
    }
    const fileName = 'avatar_' + userId + '.jpg'
    const destPath = context.filesDir + '/' + fileName
    try {
      const dest = fs.openSync(destPath, fs.OpenMode.CREATE | fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC)
      try {
        fs.writeSync(dest.fd, bytes.buffer)
      } finally {
        fs.closeSync(dest)
      }
      return fileName
    } catch (err) {
      Logger.warn('ProfileService', 'writeAvatarDataUrl failed: ' + JSON.stringify(err))
      return ''
    }
  }

  /** 本机头像压成 Web 同源的 JPEG dataURL（控制在 ~4KB，避免 JWT 膨胀） */
  static async fileToAvatarDataUrl(context: common.UIAbilityContext, fileName: string): Promise<string> {
    if (fileName.length === 0) {
      return ''
    }
    const path = context.filesDir + '/' + fileName
    try {
      if (!fs.accessSync(path)) {
        return ''
      }
      const source = image.createImageSource(path)
      const pixelMap = await source.createPixelMap()
      try {
        source.release()
      } catch (_se) {
      }
      const sizes: number[] = [96, 64, 48]
      const qualities: number[] = [75, 70, 60]
      for (let i = 0; i < sizes.length; i++) {
        const copy = await ProfileService.cloneScaledSquare(pixelMap, sizes[i])
        if (copy === null) {
          continue
        }
        try {
          const b64 = await ProfileService.packJpegBase64(copy, qualities[i])
          const dataUrl = ProfileService.DATA_URL_PREFIX + b64
          if (b64.length > 0 && dataUrl.length <= ProfileService.MAX_DATA_URL_CHARS) {
            return dataUrl
          }
        } finally {
          try {
            copy.release()
          } catch (_re) {
          }
        }
      }
      try {
        pixelMap.release()
      } catch (_pe) {
      }
      return ''
    } catch (err) {
      Logger.warn('ProfileService', 'fileToAvatarDataUrl failed: ' + JSON.stringify(err))
      return ''
    }
  }

  private static async cloneScaledSquare(src: image.PixelMap, size: number): Promise<image.PixelMap | null> {
    try {
      const info = await src.getImageInfo()
      if (info === undefined || info === null || info.size === undefined) {
        return null
      }
      const w = info.size.width
      const h = info.size.height
      if (w <= 0 || h <= 0) {
        return null
      }
      const packed = await ProfileService.packJpegBase64(src, 90)
      if (packed.length === 0) {
        return null
      }
      const bytes = CryptoService.decodeBase64(packed)
      const source = image.createImageSource(bytes.buffer)
      const copy = await source.createPixelMap()
      try {
        source.release()
      } catch (_se) {
      }
      const side = w < h ? w : h
      const scale = size / side
      if (scale > 0 && scale < 1) {
        await copy.scale(scale, scale)
      }
      return copy
    } catch (_e) {
      return null
    }
  }

  private static async packJpegBase64(pixelMap: image.PixelMap, quality: number): Promise<string> {
    const packer = image.createImagePacker()
    try {
      const opts: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
      }
      const ab: ArrayBuffer = await packer.packToData(pixelMap, opts)
      return CryptoService.encodeBase64(new Uint8Array(ab))
    } catch (_e) {
      return ''
    } finally {
      try {
        packer.release()
      } catch (_e2) {
      }
    }
  }
}
