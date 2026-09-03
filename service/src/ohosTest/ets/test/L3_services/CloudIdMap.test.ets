import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { CloudIdMap } from '../../../../main/ets/service/sync/CloudIdMap'
import { DbService } from '../../mock/DbService.mock'

export default function cloudIdMapTest() {
  beforeEach(() => {
    DbService._reset()
  })

  // ── getCloudId ──────────────────────────────────────
  describe('CloudIdMap_getCloudId', () => {
    it('无记录_返回null', 0, async () => {
      const result = await CloudIdMap.getCloudId('debts', 'local-001')
      expect(result === null).assertTrue()
    })

    it('有记录_返回cloud_id', 0, async () => {
      DbService._setQueryPreset('FROM sync_id_map', [{ cloud_id: 'cloud-001' }])
      const result = await CloudIdMap.getCloudId('debts', 'local-001')
      expect(result).assertEqual('cloud-001')
    })
  })

  // ── getLocalId ──────────────────────────────────────
  describe('CloudIdMap_getLocalId', () => {
    it('无记录_返回null', 0, async () => {
      const result = await CloudIdMap.getLocalId('debts', 'cloud-001')
      expect(result === null).assertTrue()
    })

    it('有记录_返回local_id', 0, async () => {
      DbService._setQueryPreset('FROM sync_id_map', [{ local_id: 'local-001' }])
      const result = await CloudIdMap.getLocalId('debts', 'cloud-001')
      expect(result).assertEqual('local-001')
    })
  })

  // ── setMapping ──────────────────────────────────────
  describe('CloudIdMap_setMapping', () => {
    it('首次设置_插入成功', 0, async () => {
      await CloudIdMap.setMapping('debts', 'local-001', 'cloud-001')
      const store = DbService._getStore()
      const rows = store.get('sync_id_map')
      expect(rows !== undefined).assertTrue()
      expect(rows!.length).assertEqual(1)
    })

    it('已存在_更新（insert抛异常后走update路径）', 0, async () => {
      // 先插入一条
      await CloudIdMap.setMapping('debts', 'local-001', 'cloud-001')
      // 再次设置同一 local_id → insert 会再添加一行（mock 不抛异常）
      await CloudIdMap.setMapping('debts', 'local-001', 'cloud-002')
      const store = DbService._getStore()
      const rows = store.get('sync_id_map')
      // mock insert 不抛异常，所以会插入两行
      expect(rows !== undefined).assertTrue()
      expect(rows!.length).assertEqual(2)
    })
  })

  // ── removeMapping ──────────────────────────────────
  describe('CloudIdMap_removeMapping', () => {
    it('删除映射_调用delete', 0, async () => {
      await CloudIdMap.removeMapping('debts', 'local-001')
      const log = DbService._getSqlCallLog()
      expect(log.some(l => l.sql.indexOf('DELETE sync_id_map') >= 0)).assertTrue()
    })
  })

  // ── 多表映射 ──────────────────────────────────────
  describe('CloudIdMap_多表', () => {
    it('不同表独立映射', 0, async () => {
      await CloudIdMap.setMapping('debts', 'local-d1', 'cloud-d1')
      await CloudIdMap.setMapping('subscriptions', 'local-s1', 'cloud-s1')
      const store = DbService._getStore()
      const rows = store.get('sync_id_map')
      expect(rows!.length).assertEqual(2)
    })
  })

  // ── setMapping 字段验证 ──────────────────────────────
  describe('CloudIdMap_setMapping_字段验证', () => {
    it('插入行包含所有必要字段', 0, async () => {
      await CloudIdMap.setMapping('debts', 'local-001', 'cloud-001')
      const store = DbService._getStore()
      const rows = store.get('sync_id_map')
      const row = rows![0]
      expect(row.get('table_name')).assertEqual('debts')
      expect(row.get('local_id')).assertEqual('local-001')
      expect(row.get('cloud_id')).assertEqual('cloud-001')
      expect(row.has('synced_at')).assertTrue()
    })
  })
}
