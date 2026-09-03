import { UIContext } from '@kit.ArkUI'
import { AppToast, ErrorMessages } from 'common'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { common } from '@kit.AbilityKit'
import { systemShare } from '@kit.ShareKit'

/**
 * 小票导出/分享共用能力：订阅月结小票与负债小票共用。
 * 快照离屏票面 -> 缓存 PNG -> 存相册 / 系统分享。
 */
export class ReceiptShareKit {
  /** 离屏票面快照落缓存文件；失败返回 undefined 并已提示 */
  static async snapshotToFile(ui: UIContext, posterId: string, filePrefix: string): Promise<string | undefined> {
    const host = ui.getHostContext()
    if (host === undefined || host === null) {
      AppToast.show(ErrorMessages.CONTEXT_UNAVAILABLE, 1800)
      return undefined
    }
    const context = host as common.UIAbilityContext
    await new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve()
      }, 48)
    })
    let pixelMap: image.PixelMap | undefined = undefined
    try {
      pixelMap = await ui.getComponentSnapshot().get(posterId)
    } catch (_se) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      return undefined
    }
    if (pixelMap === undefined || pixelMap === null) {
      return undefined
    }
    const fileName = filePrefix + Date.now().toString() + '.png'
    const cachePath = context.cacheDir + '/' + fileName
    let cacheFile: fs.File
    try {
      cacheFile = fs.openSync(cachePath, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE)
    } catch (_oe) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      return undefined
    }
    let packed = false
    try {
      const packer = image.createImagePacker()
      const opts: image.PackingOption = { format: 'image/png', quality: 100 }
      let ab: ArrayBuffer | undefined = undefined
      try {
        ab = await packer.packToData(pixelMap, opts)
      } catch (_packErr) {
        AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      }
      if (ab !== undefined) {
        try {
          fs.writeSync(cacheFile.fd, ab)
          packed = true
        } catch (_we) {
        }
      }
      try {
        packer.release()
      } catch (_re) {
      }
    } finally {
      try {
        fs.closeSync(cacheFile)
      } catch (_ce) {
      }
    }
    try {
      pixelMap.release()
    } catch (_re) {
    }
    if (!packed) {
      return undefined
    }
    return cachePath
  }

  /** 缓存 PNG 存入相册；成功返回 true（失败已提示） */
  static async saveToAlbum(ui: UIContext, cachePath: string): Promise<boolean> {
    const host = ui.getHostContext()
    if (host === undefined || host === null) {
      AppToast.show(ErrorMessages.CONTEXT_UNAVAILABLE, 1800)
      return false
    }
    const context = host as common.UIAbilityContext
    let helper: photoAccessHelper.PhotoAccessHelper
    try {
      helper = photoAccessHelper.getPhotoAccessHelper(context)
    } catch (_he) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      return false
    }
    let srcUri = ''
    try {
      srcUri = fileUri.getUriFromPath(cachePath)
    } catch (_ue) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      return false
    }
    // SaveButton 首次点击弹系统授权，之后静默写入。
    // 勿声明 WRITE_IMAGEVIDEO（受控权限，安装会 9568289）；勿用 showAssetsCreationDialog（每次都确认）
    try {
      const changeRequest = photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(context, srcUri)
      await helper.applyChanges(changeRequest)
    } catch (_se) {
      AppToast.show(ErrorMessages.SAVE_FAILED, 2000)
      return false
    }
    return true
  }

  /** 拉起系统分享面板；结束返回 true（失败已提示） */
  static async shareSystem(ui: UIContext, cachePath: string, title: string, description: string): Promise<boolean> {
    const host = ui.getHostContext()
    if (host === undefined || host === null) {
      AppToast.show(ErrorMessages.CONTEXT_UNAVAILABLE, 1800)
      return false
    }
    try {
      const uri = fileUri.getUriFromPath(cachePath)
      const data = new systemShare.SharedData({
        utd: 'general.png',
        uri: uri,
        title: title,
        description: description
      })
      const controller = new systemShare.ShareController(data)
      await controller.show(host as common.UIAbilityContext, {
        previewMode: systemShare.SharePreviewMode.DEFAULT,
        selectionMode: systemShare.SelectionMode.SINGLE
      })
      return true
    } catch (_e) {
      AppToast.show('分享失败，请重试', 2000)
      return false
    }
  }
}
