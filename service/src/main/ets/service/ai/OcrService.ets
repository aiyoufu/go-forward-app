import { Logger } from 'common'
import { image } from '@kit.ImageKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo } from '@kit.CoreFileKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { camera, cameraPicker } from '@kit.CameraKit'
import { CryptoService } from '../auth/CryptoService'

/**
 * 图片选取/拍照与压缩编码服务。
 * 统一内容处理架构：图片直发多模态大模型解析，不做本地 OCR 预处理；
 * 本服务负责选图、拍照、解码缩放与 JPEG base64 编码。
 */
export interface ImagePickResult {
  pixelMap: image.PixelMap | null
  fileName: string
  /** 非空表示业务拒绝（如超大图）；取消选图时为空 */
  error: string
}

export class OcrService {
  /** 选图/拍照原始文件上限，避免整文件读入 OOM */
  static readonly MAX_FILE_BYTES: number = 20 * 1024 * 1024
  /** 解码最长边：OCR 读单据字足够，且远低于原图内存 */
  static readonly OCR_MAX_EDGE: number = 1920
  /**
   * 视觉请求最长边与 JPEG 质量。
   * 单据图以文字为主，960px + q55 足够读数。
   */
  static readonly VISION_MAX_EDGE: number = 960
  static readonly VISION_JPEG_QUALITY: number = 55
  /** 视觉兜底二次压缩参数（base64 仍过大时） */
  static readonly VISION_FALLBACK_MAX_EDGE: number = 720
  static readonly VISION_FALLBACK_JPEG_QUALITY: number = 40
  /** base64 字符上限（约 1.1MB 二进制），控制请求体与 token */
  static readonly VISION_MAX_BASE64_CHARS: number = 1500000
  static readonly MSG_IMAGE_TOO_LARGE: string =
    '图片过大（超过 20MB），请压缩或更换后重试'

  static isAvailable(): boolean {
    try {
      return canIUse('SystemCapability.AI.TextRecognizer')
    } catch (_e) {
      return false
    }
  }

  private static emptyPick(error: string = ''): ImagePickResult {
    return { pixelMap: null, fileName: '', error: error }
  }

  /** URI → PixelMap（调用方负责 release）；超大文件拒绝解码 */
  private static async uriToPixelMap(uri: string): Promise<ImagePickResult> {
    const fileName = OcrService.extractFileNameFromUri(uri)
    let fd: number = -1
    try {
      const file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      fd = file.fd
      const stat = fileIo.statSync(file.fd)
      if (stat.size <= 0) {
        return { pixelMap: null, fileName: fileName, error: '' }
      }
      if (stat.size > OcrService.MAX_FILE_BYTES) {
        Logger.warn('OcrService', 'image rejected: size=' + stat.size)
        return {
          pixelMap: null,
          fileName: fileName,
          error: OcrService.MSG_IMAGE_TOO_LARGE
        }
      }
      const buf = new ArrayBuffer(stat.size)
      fileIo.readSync(file.fd, buf)
      fileIo.closeSync(file)
      fd = -1
      const imageSource = image.createImageSource(buf)
      const pixelMap = await OcrService.createPixelMapForOcr(imageSource)
      return { pixelMap: pixelMap, fileName: fileName, error: '' }
    } catch (err) {
      const error = err as BusinessError
      Logger.error('OcrService', 'uriToPixelMap failed: ' + error.message)
      return { pixelMap: null, fileName: fileName, error: '' }
    } finally {
      if (fd >= 0) {
        try {
          fileIo.closeSync(fd)
        } catch (_e) {
        }
      }
    }
  }

  /**
   * 解码时把最长边压到 OCR_MAX_EDGE，避免 4K/长截图全尺寸解码。
   * 失败则退回默认 createPixelMap。
   */
  private static async createPixelMapForOcr(
    imageSource: image.ImageSource
  ): Promise<image.PixelMap | null> {
    try {
      const srcInfo = await imageSource.getImageInfo()
      if (srcInfo !== undefined && srcInfo !== null && srcInfo.size !== undefined) {
        const w = srcInfo.size.width
        const h = srcInfo.size.height
        if (w > 0 && h > 0) {
          const maxEdge = w > h ? w : h
          if (maxEdge > OcrService.OCR_MAX_EDGE) {
            const scale = OcrService.OCR_MAX_EDGE / maxEdge
            const dw = Math.max(1, Math.floor(w * scale))
            const dh = Math.max(1, Math.floor(h * scale))
            const opts: image.DecodingOptions = {
              desiredSize: { width: dw, height: dh }
            }
            return await imageSource.createPixelMap(opts)
          }
        }
      }
      return await imageSource.createPixelMap()
    } catch (err) {
      Logger.warn('OcrService', 'createPixelMapForOcr fallback: ' + JSON.stringify(err))
      try {
        return await imageSource.createPixelMap()
      } catch (_e2) {
        return null
      }
    }
  }

  /** 相册选图，供 UI 在识别前展示扫描动画 */
  static async pickImageToPixelMap(context: common.UIAbilityContext): Promise<ImagePickResult> {
    try {
      const options = new photoAccessHelper.PhotoSelectOptions()
      options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
      options.maxSelectNumber = 1
      const photoPicker = new photoAccessHelper.PhotoViewPicker()
      const result = await photoPicker.select(options)
      if (!result || !result.photoUris || result.photoUris.length === 0) {
        return OcrService.emptyPick()
      }
      return await OcrService.uriToPixelMap(result.photoUris[0])
    } catch (err) {
      const error = err as BusinessError
      Logger.error('OcrService', 'Pick image failed: ' + error.message)
      return OcrService.emptyPick()
    }
  }

  /**
   * 拍照取图。优先 CameraPicker；失败回退相册。
   */
  static async captureImageToPixelMap(context: common.UIAbilityContext): Promise<ImagePickResult> {
    try {
      const profile: cameraPicker.PickerProfile = {
        cameraPosition: camera.CameraPosition.CAMERA_POSITION_BACK
      }
      const pickerResult: cameraPicker.PickerResult =
        await cameraPicker.pick(context, [cameraPicker.PickerMediaType.PHOTO], profile)
      if (pickerResult && pickerResult.resultUri && pickerResult.resultUri.length > 0) {
        return await OcrService.uriToPixelMap(pickerResult.resultUri)
      }
      return OcrService.emptyPick()
    } catch (err) {
      Logger.error('OcrService', 'Capture image failed, fallback to album: ' + JSON.stringify(err))
      return await OcrService.pickImageToPixelMap(context)
    }
  }

  private static extractFileNameFromUri(uri: string): string {
    try {
      const q = uri.indexOf('?')
      const path = q >= 0 ? uri.substring(0, q) : uri
      const seg = path.substring(path.lastIndexOf('/') + 1)
      return decodeURIComponent(seg)
    } catch (_e) {
      return ''
    }
  }

  /**
   * PixelMap → JPEG base64（不含 data: 前缀），供视觉模型。
   * 先缩到 VISION_MAX_EDGE 再压 JPEG；base64 仍超上限则二次压缩。
   * 统一内容处理架构：图片直发多模态大模型，不做本地 OCR 预处理。
   */
  static async pixelMapToJpegBase64(pixelMap: image.PixelMap): Promise<string> {
    try {
      await OcrService.shrinkPixelMapToMaxEdge(pixelMap, OcrService.VISION_MAX_EDGE)
      let b64 = await OcrService.packPixelMapJpegBase64(pixelMap, OcrService.VISION_JPEG_QUALITY)
      if (b64.length > OcrService.VISION_MAX_BASE64_CHARS) {
        await OcrService.shrinkPixelMapToMaxEdge(pixelMap, OcrService.VISION_FALLBACK_MAX_EDGE)
        b64 = await OcrService.packPixelMapJpegBase64(
          pixelMap, OcrService.VISION_FALLBACK_JPEG_QUALITY)
      }
      return b64
    } catch (err) {
      Logger.error('OcrService', 'pixelMapToJpegBase64 failed: ' + JSON.stringify(err))
      return ''
    }
  }

  private static async packPixelMapJpegBase64(
    pixelMap: image.PixelMap,
    quality: number
  ): Promise<string> {
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

  /** 将 PixelMap 最长边缩到 maxEdge 以内（失败则保持原图） */
  private static async shrinkPixelMapToMaxEdge(
    pixelMap: image.PixelMap,
    maxEdge: number
  ): Promise<void> {
    try {
      const info = await pixelMap.getImageInfo()
      if (info === undefined || info === null || info.size === undefined) {
        return
      }
      const w = info.size.width
      const h = info.size.height
      if (w <= 0 || h <= 0) {
        return
      }
      const edge = w > h ? w : h
      if (edge <= maxEdge) {
        return
      }
      const scale = maxEdge / edge
      await pixelMap.scale(scale, scale)
    } catch (err) {
      Logger.warn('OcrService', 'shrinkPixelMapToMaxEdge skipped: ' + JSON.stringify(err))
    }
  }
}

