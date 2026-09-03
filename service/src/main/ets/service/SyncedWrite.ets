import { CloudIdMap } from './sync/CloudIdMap'
import { SyncOutbox } from './sync/SyncOutbox'
import { SyncScheduler } from './sync/SyncScheduler'

/**
 * 业务写后的同步管道收口：outbox 登记 → 缓存失效 → 调度触发。
 * 负债/订阅/信用账户/还款四个写入口共用，消除重复样板；
 * 多表事务路径（如还清结转）仍可直调 sync 底层件。
 */
export class SyncedWrite {
  /** 新建行：尚无云端 id，登记空映射 upsert */
  static async afterCreate(table: string, localId: string, invalidate: () => void): Promise<void> {
    await SyncOutbox.enqueueUpsert(table, localId, '')
    invalidate()
    SyncScheduler.scheduleAfterWrite()
  }

  /** 更新行：解析云端 id 后登记 upsert */
  static async afterUpsert(table: string, localId: string, invalidate: () => void): Promise<void> {
    const cloudId = await CloudIdMap.resolveCloudId(table, localId)
    await SyncOutbox.enqueueUpsert(table, localId, cloudId)
    invalidate()
    SyncScheduler.scheduleAfterWrite()
  }

  /** 删行前调用：业务行删除后 cloud_id 无法回读 */
  static async beforeDelete(table: string, localId: string): Promise<string> {
    return CloudIdMap.resolveCloudId(table, localId)
  }

  /** 删行后调用：清映射 + 登记删除 + 失效 + 调度 */
  static async afterDelete(table: string, localId: string, cloudId: string, invalidate: () => void): Promise<void> {
    await CloudIdMap.removeMapping(table, localId)
    await SyncOutbox.enqueueDelete(table, localId, cloudId)
    invalidate()
    SyncScheduler.scheduleAfterWrite()
  }
}
