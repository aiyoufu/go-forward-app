import { fileIo } from '@kit.CoreFileKit'
import { http } from '@kit.NetworkKit'
import { BusinessError } from '@kit.BasicServicesKit'
import { Constants, Logger, SupabaseConfig } from 'common'
import { AuthState } from '../auth/AuthManager'
import { DbService } from '../DbService'
import { IconPickerService } from './IconPickerService'
import { SupabaseRestOptions, SupabaseRestService } from '../SupabaseRestService'

class IconUrlHolder {
  icon_url: string = ''
}

class LocalIconRow {
  id: string = ''
  cloud_id: string = ''
  icon_url: string = ''
}

/**
 * 把鸿蒙本地 file:// 图标上传到 Supabase Storage，云端写入可被 Web/PC 回显的 https。
 */
export class IconCloudService {
  static needsUpload(url: string): boolean {
    if (!url || url.length === 0) {
      return false
    }
    const t = url.trim().toLowerCase()
    return t.startsWith('file://') || t.startsWith('internal://')
  }

  static bucketForTable(table: string): string {
    if (table === Constants.TABLE_CREDIT_ACCOUNTS) {
      return 'credit-account-icons'
    }
    if (table === Constants.TABLE_SUBSCRIPTIONS) {
      return 'subscription-icons'
    }
    return 'debt-icons'
  }

  static publicUrl(bucket: string, objectPath: string): string {
    return SupabaseConfig.URL + '/storage/v1/object/public/' + bucket + '/' + objectPath
  }

  static localAbsPath(url: string): string {
    const t = url.trim()
    if (t.startsWith('file://')) {
      return t.substring(7)
    }
    return t
  }

  static async rewriteOutboundIcon(tableName: string, body: object, session: AuthState): Promise<object> {
    if (tableName !== Constants.TABLE_DEBTS &&
      tableName !== Constants.TABLE_CREDIT_ACCOUNTS &&
      tableName !== Constants.TABLE_SUBSCRIPTIONS) {
      return body
    }
    const rec = body as IconUrlHolder
    if (!IconCloudService.needsUpload(rec.icon_url)) {
      return body
    }
    const remote = await IconCloudService.ensureRemoteUrl(
      rec.icon_url,
      IconCloudService.bucketForTable(tableName),
      session.userId,
      session.accessToken
    )
    if (remote.length > 0 && remote !== rec.icon_url) {
      rec.icon_url = remote
    }
    return body
  }

  /** 已上云但仍是 file:// 的行：上传后 PATCH 云端，Web 端即可显示 */
  static async repairCloudIcons(session: AuthState): Promise<void> {
    if (session.accessToken.length === 0) {
      return
    }
    await IconCloudService.repairTable(Constants.TABLE_CREDIT_ACCOUNTS, session)
    await IconCloudService.repairTable(Constants.TABLE_DEBTS, session)
    await IconCloudService.repairTable(Constants.TABLE_SUBSCRIPTIONS, session)
  }

  static async ensureRemoteUrl(url: string, bucket: string, userId: string, token: string): Promise<string> {
    if (!IconCloudService.needsUpload(url)) {
      return url
    }
    if (userId.length === 0 || token.length === 0 || !SupabaseConfig.isConfigured()) {
      return url
    }
    const abs = IconCloudService.localAbsPath(url)
    let bytes: ArrayBuffer
    try {
      const src = fileIo.openSync(abs, fileIo.OpenMode.READ_ONLY)
      try {
        const stat = fileIo.statSync(src.fd)
        if (stat.size < 32 || stat.size > 2 * 1024 * 1024) {
          return url
        }
        bytes = new ArrayBuffer(stat.size)
        fileIo.readSync(src.fd, bytes)
      } finally {
        fileIo.closeSync(src)
      }
    } catch (err) {
      Logger.warn('IconCloudService', 'read local icon failed: ' + JSON.stringify(err))
      return url
    }
    if (!IconPickerService.isImageBytes(bytes)) {
      return url
    }
    const ext = IconCloudService.guessExt(bytes)
    // 对象名保留本地缓存前缀（card_face_ / icon_net_ / icon_）：
    // 上云后 URL 靠它区分横卡与圆标（IconPickerService.isCardFaceUrl）
    const objectPath = userId + '/' + IconCloudService.cachePrefix(url) +
      IconPickerService.urlKey(url) + '.' + ext
    const ok = await IconCloudService.uploadBytes(bucket, objectPath, bytes, ext === 'jpg' ? 'image/jpeg' : 'image/png', token)
    if (!ok) {
      return url
    }
    return IconCloudService.publicUrl(bucket, objectPath)
  }

  /** 本地图标文件的缓存前缀：卡面 card_face_ / 网络圆标 icon_net_ / 其余（相册等）icon_ */
  private static cachePrefix(url: string): string {
    const base = url.substring(url.lastIndexOf('/') + 1)
    if (base.startsWith('card_face_')) {
      return 'card_face_'
    }
    if (base.startsWith('icon_net_')) {
      return 'icon_net_'
    }
    return 'icon_'
  }

  private static guessExt(bytes: ArrayBuffer): string {
    if (bytes.byteLength < 3) {
      return 'png'
    }
    const u = new Uint8Array(bytes)
    if (u[0] === 0xFF && u[1] === 0xD8) {
      return 'jpg'
    }
    return 'png'
  }

  private static uploadBytes(
    bucket: string,
    objectPath: string,
    bytes: ArrayBuffer,
    contentType: string,
    token: string
  ): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      const req = http.createHttp()
      const url = SupabaseConfig.URL + '/storage/v1/object/' + bucket + '/' + objectPath
      req.request(url, {
        method: http.RequestMethod.POST,
        extraData: bytes,
        connectTimeout: 15000,
        readTimeout: 20000,
        header: {
          'apikey': SupabaseConfig.ANON_KEY,
          'Authorization': 'Bearer ' + token,
          'Content-Type': contentType,
          'x-upsert': 'true'
        }
      }, (err: BusinessError, data: http.HttpResponse) => {
        req.destroy()
        if (err || data === undefined) {
          Logger.warn('IconCloudService', 'upload failed: ' + JSON.stringify(err))
          resolve(false)
          return
        }
        if (data.responseCode >= 200 && data.responseCode < 300) {
          resolve(true)
          return
        }
        Logger.warn('IconCloudService', 'upload HTTP ' + data.responseCode)
        resolve(false)
      })
    })
  }

  private static async repairTable(table: string, session: AuthState): Promise<void> {
    const rows = await IconCloudService.listLocalFileIcons(table)
    const bucket = IconCloudService.bucketForTable(table)
    for (let i = 0; i < rows.length; i++) {
      const row = rows[i]
      if (row.cloud_id.length === 0) {
        continue
      }
      const remote = await IconCloudService.ensureRemoteUrl(
        row.icon_url, bucket, session.userId, session.accessToken
      )
      if (remote.length === 0 || remote === row.icon_url) {
        continue
      }
      const patched = await IconCloudService.patchCloudIcon(table, row.cloud_id, remote, session.accessToken)
      if (!patched) {
        continue
      }
      const values = new Map<string, string | number | boolean>()
      values.set('icon_url', remote)
      try {
        await DbService.update(table, values, 'id = ?', [row.id])
      } catch (e) {
        Logger.warn('IconCloudService', 'update local icon failed: ' + JSON.stringify(e))
      }
    }
  }

  private static async listLocalFileIcons(table: string): Promise<LocalIconRow[]> {
    const out: LocalIconRow[] = []
    try {
      const rs = await DbService.query(
        'SELECT id, cloud_id, icon_url FROM ' + table +
        " WHERE icon_url LIKE 'file://%' OR icon_url LIKE 'internal://%'"
      )
      try {
        while (rs.goToNextRow()) {
          const row = new LocalIconRow()
          row.id = '' + (rs.getString(rs.getColumnIndex('id')) ?? '')
          row.cloud_id = '' + (rs.getString(rs.getColumnIndex('cloud_id')) ?? '')
          row.icon_url = '' + (rs.getString(rs.getColumnIndex('icon_url')) ?? '')
          if (row.id.length > 0 && row.icon_url.length > 0) {
            out.push(row)
          }
        }
      } finally {
        rs.close()
      }
    } catch (e) {
      Logger.warn('IconCloudService', 'listLocalFileIcons ' + table + ' failed: ' + JSON.stringify(e))
    }
    return out
  }

  private static async patchCloudIcon(
    table: string,
    cloudId: string,
    iconUrl: string,
    token: string
  ): Promise<boolean> {
    const options = new SupabaseRestOptions(table)
    options.filters.set('id', 'eq.' + cloudId)
    const body = new IconUrlHolder()
    body.icon_url = iconUrl
    options.body = body
    options.preferReturn = 'minimal'
    const res = await SupabaseRestService.patch(token, options)
    if (res.error.length > 0) {
      Logger.warn('IconCloudService', 'PATCH ' + table + ' icon failed: ' + res.error)
      return false
    }
    return true
  }
}
