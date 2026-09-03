import { describe, it, expect } from '@ohos/hypium'
import { SyncOutbox, SyncOutboxItem } from '../../../../main/ets/service/sync/SyncOutbox'
import { Constants } from 'common'

export default function syncOutboxTest() {
  describe('SyncOutbox_encodePayload', () => {
    it('仅cloudId', 0, async () => {
      expect(SyncOutbox.encodePayload('cid-1', '')).assertEqual('cid-1')
    })
    it('cloudId加JSON', 0, async () => {
      expect(SyncOutbox.encodePayload('cid-1', '{"a":1}')).assertEqual('cid-1\n{"a":1}')
    })
  })

  describe('SyncOutbox_decode', () => {
    it('解码cloudId', 0, async () => {
      expect(SyncOutbox.decodeCloudId('cid-1\n{"a":1}')).assertEqual('cid-1')
      expect(SyncOutbox.decodeCloudId('cid-only')).assertEqual('cid-only')
    })
    it('解码JSON body', 0, async () => {
      expect(SyncOutbox.decodeJsonBody('cid-1\n{"a":1}')).assertEqual('{"a":1}')
      expect(SyncOutbox.decodeJsonBody('cid-only')).assertEqual('')
    })
  })

  describe('SyncOutbox_sortForFlush', () => {
    it('delete优先于同表upsert', 0, async () => {
      const a = new SyncOutboxItem()
      a.table_name = Constants.TABLE_DEBTS
      a.operation = SyncOutbox.OP_UPSERT
      a.created_at = 1
      const b = new SyncOutboxItem()
      b.table_name = Constants.TABLE_DEBTS
      b.operation = SyncOutbox.OP_DELETE
      b.created_at = 2
      const sorted = SyncOutbox.sortForFlush([a, b])
      expect(sorted[0].operation).assertEqual(SyncOutbox.OP_DELETE)
      expect(sorted[1].operation).assertEqual(SyncOutbox.OP_UPSERT)
    })
    it('payment在debt之后', 0, async () => {
      const pay = new SyncOutboxItem()
      pay.table_name = Constants.TABLE_PAYMENT_RECORDS
      pay.operation = SyncOutbox.OP_UPSERT
      pay.created_at = 1
      const debt = new SyncOutboxItem()
      debt.table_name = Constants.TABLE_DEBTS
      debt.operation = SyncOutbox.OP_UPSERT
      debt.created_at = 2
      const sorted = SyncOutbox.sortForFlush([pay, debt])
      expect(sorted[0].table_name).assertEqual(Constants.TABLE_DEBTS)
      expect(sorted[1].table_name).assertEqual(Constants.TABLE_PAYMENT_RECORDS)
    })
  })
}
