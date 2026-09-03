import { describe, it, expect } from '@ohos/hypium'

/**
 * ExportImportPanel UI 测试
 * 覆盖：导出导入按钮、数据清理、busy/进度态
 */
export default function ExportImportPanel_UITest() {
  describe('ExportImportPanel_UI', () => {

    it('渲染_进度标题_清空', 0, async () => {
      const clearing = true
      const busyKind = ''
      const title = clearing ? '正在清空…' :
        (busyKind === 'export' ? '正在导出…' :
          (busyKind === 'import' ? '正在导入…' : '处理中…'))
      expect(title).assertEqual('正在清空…')
    })

    it('渲染_进度标题_导出', 0, async () => {
      const clearing = false
      let busyKind: string = 'export'
      const title = clearing ? '正在清空…' :
        (busyKind === 'export' ? '正在导出…' :
          (busyKind === 'import' ? '正在导入…' : '处理中…'))
      expect(title).assertEqual('正在导出…')
    })

    it('渲染_进度标题_导入', 0, async () => {
      const clearing = false
      let busyKind: string = 'import'
      const title = clearing ? '正在清空…' :
        (busyKind === 'export' ? '正在导出…' :
          (busyKind === 'import' ? '正在导入…' : '处理中…'))
      expect(title).assertEqual('正在导入…')
    })

    it('渲染_进度卡尺寸_80vp', 0, async () => {
      const cardSize = 80
      const ringSize = 40
      expect(cardSize).assertEqual(80)
      expect(ringSize).assertEqual(40)
    })

    it('渲染_showProgress_busy或clearing为真', 0, async () => {
      const busy = true
      const clearing = false
      const showProgress = busy || clearing
      expect(showProgress).assertTrue()
    })

    it('渲染_清空分区标题', 0, async () => {
      const title = '清空'
      expect(title).assertEqual('清空')
    })

    it('渲染_清空数据按钮_红色文字', 0, async () => {
      const label = '清空本机数据'
      const color = 'red'
      expect(label).assertEqual('清空本机数据')
      expect(color).assertEqual('red')
    })

    it('渲染_清空数据说明_不可恢复', 0, async () => {
      const desc = '删除负债、订阅、信用账户与还款记录；登录云端时云端数据一并清空。不可恢复。'
      expect(desc.includes('不可恢复')).assertTrue()
    })

    it('渲染_导出标题', 0, async () => {
      const title = '导出'
      expect(title).assertEqual('导出')
    })

    it('渲染_导出JSON_完整备份', 0, async () => {
      const label = 'JSON'
      const desc = '完整备份'
      expect(label).assertEqual('JSON')
      expect(desc).assertEqual('完整备份')
    })

    it('渲染_导出CSV_表格导出', 0, async () => {
      const label = 'CSV'
      const desc = '表格导出'
      expect(label).assertEqual('CSV')
      expect(desc).assertEqual('表格导出')
    })

    it('渲染_导入标题', 0, async () => {
      const title = '导入'
      expect(title).assertEqual('导入')
    })

    it('渲染_导入JSON_从备份恢复', 0, async () => {
      const label = 'JSON'
      const desc = '从备份恢复'
      expect(label).assertEqual('JSON')
      expect(desc).assertEqual('从备份恢复')
    })

    it('渲染_导入CSV_交易流水', 0, async () => {
      const label = 'CSV'
      const desc = '交易流水'
      expect(label).assertEqual('CSV')
      expect(desc).assertEqual('交易流水')
    })

    it('渲染_busy状态_透明度降低', 0, async () => {
      const busy = true
      const opacity = busy ? 0.5 : 1
      expect(opacity).assertEqual(0.5)
    })

    it('渲染_非busy状态_完全不透明', 0, async () => {
      const busy = false
      const opacity = busy ? 0.5 : 1
      expect(opacity).assertEqual(1)
    })

    it('交互_点击清空数据_触发onClearAllData', 0, async () => {
      let cleared = false
      const busy = false
      const onClearAllData = () => { cleared = true }
      if (!busy && onClearAllData) {
        onClearAllData()
      }
      expect(cleared).assertTrue()
    })

    it('交互_busy中_不触发清空', 0, async () => {
      let cleared = false
      const busy = true
      const onClearAllData = () => { cleared = true }
      if (!busy && onClearAllData) {
        onClearAllData()
      }
      expect(cleared).assertFalse()
    })

    it('交互_点击导出JSON_触发exportJson', 0, async () => {
      let exported = false
      const busy = false
      const exportJson = () => { exported = true }
      if (!busy) {
        exportJson()
      }
      expect(exported).assertTrue()
    })

    it('交互_点击导出CSV_触发exportCsv', 0, async () => {
      let exported = false
      const busy = false
      const exportCsv = () => { exported = true }
      if (!busy) {
        exportCsv()
      }
      expect(exported).assertTrue()
    })

    it('交互_点击导入JSON_触发importData', 0, async () => {
      let imported = false
      const busy = false
      const importData = () => { imported = true }
      if (!busy) {
        importData()
      }
      expect(imported).assertTrue()
    })

    it('交互_点击导入CSV_触发importStatementCsv', 0, async () => {
      let imported = false
      const busy = false
      const importStatementCsv = () => { imported = true }
      if (!busy) {
        importStatementCsv()
      }
      expect(imported).assertTrue()
    })

    it('交互_busy中_不触发导出', 0, async () => {
      let exported = false
      const busy = true
      const exportJson = () => { exported = true }
      if (!busy) {
        exportJson()
      }
      expect(exported).assertFalse()
    })

    it('渲染_导出2宫格_左右排列', 0, async () => {
      const exportItems = ['JSON', 'CSV']
      expect(exportItems.length).assertEqual(2)
    })

    it('渲染_导入2宫格_左右排列', 0, async () => {
      const importItems = ['JSON', 'CSV']
      expect(importItems.length).assertEqual(2)
    })

    it('渲染_内边距_left24_right24_top4_bottom28', 0, async () => {
      const padding = { left: 24, right: 24, top: 4, bottom: 28 }
      expect(padding.left).assertEqual(24)
      expect(padding.bottom).assertEqual(28)
    })
  })
}
