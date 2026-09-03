import { asset } from '@kit.AssetStoreKit'
import { util } from '@kit.ArkTS'
import { BusinessError } from '@kit.BasicServicesKit'

/**
 * 基于 Asset Store Kit（关键资产）的敏感凭据存储。
 * 数据由系统加密落盘，用于替代 Preferences 明文存储 token 等机密信息。
 * 关键资产 SECRET 上限 1024 字节，超长值（如 Supabase JWT）按分片存储：
 * 首片存于 alias，后续片存于 alias#1、alias#2…读取时自动拼接。
 */
export class SecureStore {
  /** 单片最大字节数，留余量低于系统上限 1024 */
  private static readonly CHUNK_SIZE: number = 1000

  /** 写入字符串密文；空字符串等价于删除该项 */
  static async putString(alias: string, value: string): Promise<void> {
    // 先清掉旧值（含旧分片），避免新值片数变少时残留脏分片
    await SecureStore.remove(alias)
    if (value.length === 0) {
      return
    }
    const data = SecureStore.encode(value)
    if (data.length <= SecureStore.CHUNK_SIZE) {
      await SecureStore.addChunk(alias, data)
      return
    }
    let index = 0
    for (let offset = 0; offset < data.length; offset += SecureStore.CHUNK_SIZE) {
      const chunk = data.slice(offset, offset + SecureStore.CHUNK_SIZE)
      await SecureStore.addChunk(SecureStore.chunkAlias(alias, index), chunk)
      index++
    }
  }

  /** 读取字符串；不存在时返回空字符串 */
  static async getString(alias: string): Promise<string> {
    const first = await SecureStore.queryChunk(alias)
    if (first === null) {
      return ''
    }
    const parts: Array<Uint8Array> = [first]
    for (let i = 1; ; i++) {
      const chunk = await SecureStore.queryChunk(SecureStore.chunkAlias(alias, i))
      if (chunk === null) {
        break
      }
      parts.push(chunk)
    }
    if (parts.length === 1) {
      return SecureStore.decode(first)
    }
    let total = 0
    parts.forEach(p => total += p.length)
    const merged = new Uint8Array(total)
    let offset = 0
    parts.forEach(p => {
      merged.set(p, offset)
      offset += p.length
    })
    return SecureStore.decode(merged)
  }

  /** 删除资产（含所有分片）；不存在视为成功 */
  static async remove(alias: string): Promise<void> {
    await SecureStore.removeOne(alias)
    for (let i = 1; ; i++) {
      const existed = await SecureStore.removeOne(SecureStore.chunkAlias(alias, i))
      if (!existed) {
        break
      }
    }
  }

  private static chunkAlias(alias: string, index: number): string {
    return index === 0 ? alias : `${alias}#${index}`
  }

  private static async addChunk(alias: string, data: Uint8Array): Promise<void> {
    const attrs: asset.AssetMap = new Map()
    attrs.set(asset.Tag.ALIAS, SecureStore.encode(alias))
    attrs.set(asset.Tag.SECRET, data)
    attrs.set(asset.Tag.ACCESSIBILITY, asset.Accessibility.DEVICE_FIRST_UNLOCKED)
    try {
      await asset.add(attrs)
    } catch (err) {
      const e = err as BusinessError
      if (e.code === asset.ErrorCode.DUPLICATED) {
        const query: asset.AssetMap = new Map()
        query.set(asset.Tag.ALIAS, SecureStore.encode(alias))
        const toUpdate: asset.AssetMap = new Map()
        toUpdate.set(asset.Tag.SECRET, data)
        try {
          await asset.update(query, toUpdate)
        } catch (_e2) {
        }
      } else {
        throw err as Error
      }
    }
  }

  /** 查询单片原始字节；不存在返回 null */
  private static async queryChunk(alias: string): Promise<Uint8Array | null> {
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, SecureStore.encode(alias))
    query.set(asset.Tag.RETURN_TYPE, asset.ReturnType.ALL)
    try {
      const result: Array<asset.AssetMap> = await asset.query(query)
      if (result.length === 0) {
        return null
      }
      return result[0].get(asset.Tag.SECRET) as Uint8Array
    } catch (err) {
      const e = err as BusinessError
      if (e.code === asset.ErrorCode.NOT_FOUND) {
        return null
      }
      throw err as Error
    }
  }

  /** 删除单片；返回删除前是否存在 */
  private static async removeOne(alias: string): Promise<boolean> {
    const query: asset.AssetMap = new Map()
    query.set(asset.Tag.ALIAS, SecureStore.encode(alias))
    try {
      await asset.remove(query)
      return true
    } catch (err) {
      const e = err as BusinessError
      if (e.code !== asset.ErrorCode.NOT_FOUND) {
        throw err as Error
      }
      return false
    }
  }

  private static encode(text: string): Uint8Array {
    return new util.TextEncoder().encodeInto(text)
  }

  private static decode(data: Uint8Array): string {
    return util.TextDecoder.create('utf-8').decodeToString(data)
  }
}
