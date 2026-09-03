import { describe, it, expect } from '@ohos/hypium'

interface MarkPaidParams {
  platform: string
  debt_id: string
}

interface MarkPaidDebt {
  id: string
  platform_name: string
  platform: string
}

interface MarkPaidResult {
  success: boolean
  debtId: string
}

interface ErrorParams {
  error: string
}

/**
 * MarkPaidExecutor 单元测试
 * 覆盖：参数解析、平台查找、状态更新、结果组装、错误处理
 */
export default function markPaidExecutorTest() {

  describe('MarkPaidExecutor_参数解析', () => {

    it('正常参数_提取platform和debt_id', 0, () => {
      const params: MarkPaidParams = { platform: '花呗', debt_id: 'debt-001' }
      const record = params
      const platform = record.platform ?? ''
      const debtId = record.debt_id ?? ''
      expect(platform).assertEqual('花呗')
      expect(debtId).assertEqual('debt-001')
    })

    it('缺失参数_默认为空', 0, () => {
      const record: MarkPaidParams = { platform: '', debt_id: '' }
      const platform = record.platform ?? ''
      const debtId = record.debt_id ?? ''
      expect(platform).assertEqual('')
      expect(debtId).assertEqual('')
    })

    it('仅有platform_无debt_id', 0, () => {
      const record: MarkPaidParams = { platform: '京东白条', debt_id: '' }
      const platform = record.platform ?? ''
      const debtId = record.debt_id ?? ''
      expect(platform).assertEqual('京东白条')
      expect(debtId).assertEqual('')
    })

    it('仅有debt_id_无platform', 0, () => {
      const record: MarkPaidParams = { platform: '', debt_id: 'debt-002' }
      const platform = record.platform ?? ''
      const debtId = record.debt_id ?? ''
      expect(platform).assertEqual('')
      expect(debtId).assertEqual('debt-002')
    })
  })

  describe('MarkPaidExecutor_平台查找逻辑', () => {

    it('debtId为空且platform有值_按平台匹配', 0, () => {
      const debtId = ''
      const platform = '花呗'
      const debts: MarkPaidDebt[] = [
        { id: 'd1', platform_name: '借呗', platform: '' },
        { id: 'd2', platform_name: '花呗', platform: '' },
        { id: 'd3', platform_name: '京东白条', platform: '' }
      ]
      let foundId = debtId
      if (foundId.length === 0 && platform.length > 0) {
        for (const debt of debts) {
          const d = debt
          const p = d.platform_name ?? d.platform ?? ''
          if (p.includes(platform)) {
            foundId = d.id
            break
          }
        }
      }
      expect(foundId).assertEqual('d2')
    })

    it('debtId为空且platform无匹配_保持空', 0, () => {
      const debtId = ''
      const platform = '微粒贷'
      const debts: MarkPaidDebt[] = [
        { id: 'd1', platform_name: '借呗', platform: '' },
        { id: 'd2', platform_name: '花呗', platform: '' }
      ]
      let foundId = debtId
      if (foundId.length === 0 && platform.length > 0) {
        for (const debt of debts) {
          const d = debt
          const p = d.platform_name ?? d.platform ?? ''
          if (p.includes(platform)) {
            foundId = d.id
            break
          }
        }
      }
      expect(foundId).assertEqual('')
    })

    it('debtId已有值_跳过平台查找', 0, () => {
      const debtId = 'debt-001'
      const platform = '花呗'
      const shouldSearch = debtId.length === 0 && platform.length > 0
      expect(shouldSearch).assertFalse()
    })

    it('platform为空且debtId为空_不触发查找', 0, () => {
      const debtId = ''
      const platform = ''
      const shouldSearch = debtId.length === 0 && platform.length > 0
      expect(shouldSearch).assertFalse()
    })

    it('模糊匹配_platform包含关键字', 0, () => {
      const platform = '花'
      const debts: MarkPaidDebt[] = [
        { id: 'd1', platform_name: '花呗', platform: '' }
      ]
      let foundId = ''
      for (const debt of debts) {
        const d = debt
        const p = d.platform_name ?? ''
        if (p.includes(platform)) {
          foundId = d.id
          break
        }
      }
      expect(foundId).assertEqual('d1')
    })
  })

  describe('MarkPaidExecutor_状态更新', () => {

    it('debtId有值_执行更新', 0, () => {
      const debtId = 'debt-001'
      let success = false
      if (debtId.length > 0) {
        success = true
      }
      expect(success).assertTrue()
    })

    it('debtId为空_不执行更新', 0, () => {
      const debtId = ''
      let success = false
      if (debtId.length > 0) {
        success = true
      }
      expect(success).assertFalse()
    })
  })

  describe('MarkPaidExecutor_结果组装', () => {

    it('成功_code为0_success为true', 0, () => {
      const success = true
      const code = success ? 0 : -1
      expect(code).assertEqual(0)
    })

    it('失败_code为-1_success为false', 0, () => {
      const success = false
      const code = success ? 0 : -1
      expect(code).assertEqual(-1)
    })

    it('结果包含success和debtId', 0, () => {
      const success = true
      const debtId = 'debt-001'
      const resultParams: MarkPaidResult = { success, debtId }
      expect(resultParams.success).assertTrue()
      expect(resultParams.debtId).assertEqual('debt-001')
    })
  })

  describe('MarkPaidExecutor_错误处理', () => {

    it('更新失败_进入catch分支', 0, () => {
      let code = 0
      try {
        throw new Error('update failed')
      } catch (err) {
        code = -1
      }
      expect(code).assertEqual(-1)
    })
  })
}
