import { describe, it, expect } from '@ohos/hypium'
import { ArrayDataSource, toObjectList } from '../../../main/ets/common/ArrayDataSource'

class RowObj {
  id: string = ''
}

export default function arrayDataSourceTest() {
  describe('ArrayDataSource', () => {
    it('reload后totalCount正确', 0, () => {
      const ds = new ArrayDataSource()
      const a = new RowObj()
      a.id = '1'
      const b = new RowObj()
      b.id = '2'
      const list: Object[] = [a, b]
      ds.reload(list)
      expect(ds.totalCount()).assertEqual(2)
    })
    it('getData返回对应项', 0, () => {
      const ds = new ArrayDataSource()
      const a = new RowObj()
      a.id = 'x'
      ds.reload([a])
      const got = ds.getData(0) as RowObj
      expect(got.id).assertEqual('x')
    })
    it('clear清空', 0, () => {
      const ds = new ArrayDataSource()
      const a = new RowObj()
      ds.reload([a])
      ds.clear()
      expect(ds.totalCount()).assertEqual(0)
    })
    it('toObjectList拷贝长度一致', 0, () => {
      const a = new RowObj()
      const b = new RowObj()
      const list: Object[] = [a, b]
      const out = toObjectList(list)
      expect(out.length).assertEqual(2)
    })
  })
}
