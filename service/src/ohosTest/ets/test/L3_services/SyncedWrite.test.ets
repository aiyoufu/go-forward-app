import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { SyncedWrite } from '../../../../main/ets/service/SyncedWrite'
import { SyncOutbox } from '../../../../main/ets/service/sync/SyncOutbox'
import { DbService } from '../../mock/DbService.mock'

async function countQueueRows(): Promise<number> {
  const rs = await DbService.query('SELECT * FROM sync_queue')
  let n = 0
  try {
    while (rs.goToNextRow()) {
      n++
    }
  } catch (_e) {
  }
  return n
}

async function lastQueueRow(): Promise<Record<string, string | number | boolean>> {
  const rs = await DbService.query('SELECT * FROM sync_queue ORDER BY created_at DESC')
  const row: Record<string, string | number | boolean> = {}
  try {
    if (rs.goToNextRow()) {
      row['table_name'] = rs.getString(rs.getColumnIndex('table_name'))
      row['record_id'] = rs.getString(rs.getColumnIndex('record_id'))
      row['operation'] = rs.getString(rs.getColumnIndex('operation'))
      row['cloud_id'] = rs.getString(rs.getColumnIndex('cloud_id'))
    }
  } catch (_e) {
  }
  return row
}

export default function syncedWriteTest() {
  beforeEach(() => {
    DbService._reset()
  })

  describe('SyncedWrite_afterCreate', () => {
    it('登记空cloudId的upsert并触发失效回调', 0, async () => {
      let invalidated = false
      await SyncedWrite.afterCreate('debts', 'd1', () => {
        invalidated = true
      })
      expect(invalidated).assertTrue()
      expect(await countQueueRows()).assertEqual(1)
      const row = await lastQueueRow()
      expect(row['table_name']).assertEqual('debts')
      expect(row['record_id']).assertEqual('d1')
      expect(row['operation']).assertEqual(SyncOutbox.OP_UPSERT)
      expect(row['cloud_id']).assertEqual('')
    })
  })

  describe('SyncedWrite_afterUpsert', () => {
    it('无云端映射时_解析为空串仍登记upsert', 0, async () => {
      let invalidated = false
      await SyncedWrite.afterUpsert('subscriptions', 's1', () => {
        invalidated = true
      })
      expect(invalidated).assertTrue()
      const row = await lastQueueRow()
      expect(row['record_id']).assertEqual('s1')
      expect(row['operation']).assertEqual(SyncOutbox.OP_UPSERT)
      expect(row['cloud_id']).assertEqual('')
    })
  })

  describe('SyncedWrite_delete两段式', () => {
    it('beforeDelete_无映射返回空串', 0, async () => {
      const cloudId = await SyncedWrite.beforeDelete('debts', 'd1')
      expect(cloudId).assertEqual('')
    })

    it('afterDelete_有cloudId登记delete', 0, async () => {
      let invalidated = false
      await SyncedWrite.afterDelete('debts', 'd1', 'cloud-9', () => {
        invalidated = true
      })
      expect(invalidated).assertTrue()
      const row = await lastQueueRow()
      expect(row['operation']).assertEqual(SyncOutbox.OP_DELETE)
      expect(row['cloud_id']).assertEqual('cloud-9')
    })

    it('afterDelete_无cloudId_无需云删除不入队', 0, async () => {
      await SyncedWrite.afterDelete('debts', 'd1', '', () => {
      })
      expect(await countQueueRows()).assertEqual(0)
    })
  })
}
