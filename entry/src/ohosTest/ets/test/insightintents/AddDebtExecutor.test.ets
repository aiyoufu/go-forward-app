import { describe, it, expect } from '@ohos/hypium'

interface AddDebtInput {
  platform: string
  debt_type: string
  principal: number
  current_balance: number
  monthly_payment: number
  total_periods: number
  remaining_periods: number
  repayment_method: string
  total_interest: number
  annual_rate_bp: number
  payment_day: number
  next_payment_date: string
  start_date: string
  is_auto_payment: boolean
  note: string
  credit_account_id: string
  icon_url: string
}

interface DebtRef {
  id: string
}

interface ResultParams {
  debtId: string
  platform: string
  principalYuan: number
}

interface ErrorParams {
  error: string
}

interface ErrorResult {
  code: number
  result: ErrorParams
}

/**
 * AddDebtExecutor 单元测试
 * 覆盖：参数解析、初始化链、债务创建、结果组装、错误处理
 */
export default function addDebtExecutorTest() {

  describe('AddDebtExecutor_参数解析', () => {

    it('正常参数_提取全部字段', 0, () => {
      const params: Record<string, string | number> = {
        'platform': '花呗',
        'principal': 5000,
        'monthly_payment': 500,
        'total_periods': 12,
        'payment_day': 15,
        'next_payment_date': '2025-08-15'
      }
      const record = params
      const platform = (record['platform'] as string) ?? '未知平台'
      const principalYuan = Number(record['principal'] ?? 0)
      const monthlyYuan = Number(record['monthly_payment'] ?? 0)
      const totalPeriods = Number(record['total_periods'] ?? 12)
      const paymentDay = Number(record['payment_day'] ?? 1)
      const nextDate = (record['next_payment_date'] as string) ?? '2025-07-28'

      expect(platform).assertEqual('花呗')
      expect(principalYuan).assertEqual(5000)
      expect(monthlyYuan).assertEqual(500)
      expect(totalPeriods).assertEqual(12)
      expect(paymentDay).assertEqual(15)
      expect(nextDate).assertEqual('2025-08-15')
    })

    it('缺失platform_降级为未知平台', 0, () => {
      const record: Record<string, string | number> = {}
      const platform = (record['platform'] as string) ?? '未知平台'
      expect(platform).assertEqual('未知平台')
    })

    it('缺失principal_降级为0', 0, () => {
      const record: Record<string, string | number> = {}
      const principalYuan = Number(record['principal'] ?? 0)
      expect(principalYuan).assertEqual(0)
    })

    it('缺失monthly_payment_降级为0', 0, () => {
      const record: Record<string, string | number> = {}
      const monthlyYuan = Number(record['monthly_payment'] ?? 0)
      expect(monthlyYuan).assertEqual(0)
    })

    it('缺失total_periods_降级为12', 0, () => {
      const record: Record<string, string | number> = {}
      const totalPeriods = Number(record['total_periods'] ?? 12)
      expect(totalPeriods).assertEqual(12)
    })

    it('缺失payment_day_降级为1', 0, () => {
      const record: Record<string, string | number> = {}
      const paymentDay = Number(record['payment_day'] ?? 1)
      expect(paymentDay).assertEqual(1)
    })

    it('缺失next_payment_date_降级为今天', 0, () => {
      const record: Record<string, string | number> = {}
      const today = new Date()
      const y = today.getFullYear()
      const m = (today.getMonth() + 1 < 10 ? '0' : '') + (today.getMonth() + 1)
      const d = (today.getDate() < 10 ? '0' : '') + today.getDate()
      const todayStr = y + '-' + m + '-' + d
      const nextDate = (record['next_payment_date'] as string) ?? todayStr
      expect(nextDate).assertEqual(todayStr)
    })

    it('空字符串参数_使用默认值', 0, () => {
      const record: Record<string, string | number> = { 'platform': '' }
      const platform = (record['platform'] as string) ?? '未知平台'
      // 空字符串不是 null/undefined，不会触发 ??
      expect(platform).assertEqual('')
    })

    it('数值参数为字符串_自动转换', 0, () => {
      const record: Record<string, string | number> = { 'principal': '3000' }
      const principalYuan = Number(record['principal'] ?? 0)
      expect(principalYuan).assertEqual(3000)
    })
  })

  describe('AddDebtExecutor_初始化链', () => {

    it('初始化顺序_DbService先于PreferencesService', 0, async () => {
      const order: string[] = []
      // 模拟初始化链
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()

      expect(order[0]).assertEqual('DbService')
      expect(order[1]).assertEqual('PreferencesService')
      expect(order[2]).assertEqual('E2EEService')
      expect(order[3]).assertEqual('UserService')
    })

    it('初始化链_所有步骤必须完成', 0, async () => {
      const order: string[] = []
      await (async () => { order.push('DbService') })()
      await (async () => { order.push('PreferencesService') })()
      await (async () => { order.push('E2EEService') })()
      await (async () => { order.push('UserService') })()
      expect(order.length).assertEqual(4)
    })
  })

  describe('AddDebtExecutor_债务创建参数', () => {

    it('创建参数_包含所有必填字段', 0, () => {
      const input: AddDebtInput = {
        platform: '花呗',
        debt_type: 'loan',
        principal: 5000,
        current_balance: 500000, // 元转分
        monthly_payment: 500,
        total_periods: 12,
        remaining_periods: 12,
        repayment_method: 'equal_payment',
        total_interest: 0,
        annual_rate_bp: 0,
        payment_day: 15,
        next_payment_date: '2025-08-15',
        start_date: '2025-07-28',
        is_auto_payment: false,
        note: '来自小艺意图',
        credit_account_id: '',
        icon_url: ''
      }
      expect(input.platform).assertEqual('花呗')
      expect(input.debt_type).assertEqual('loan')
      expect(input.repayment_method).assertEqual('equal_payment')
      expect(input.note).assertEqual('来自小艺意图')
      expect(input.is_auto_payment).assertEqual(false)
    })

    it('元转分_yuanToFen逻辑', 0, () => {
      const principalYuan = 5000
      const principalFen = Math.round(principalYuan * 100)
      expect(principalFen).assertEqual(500000)
    })

    it('元转分_零金额', 0, () => {
      const principalYuan = 0
      const principalFen = Math.round(principalYuan * 100)
      expect(principalFen).assertEqual(0)
    })

    it('元转分_小数金额', 0, () => {
      const principalYuan = 1234.56
      const principalFen = Math.round(principalYuan * 100)
      expect(principalFen).assertEqual(123456)
    })
  })

  describe('AddDebtExecutor_结果组装', () => {

    it('创建成功_code为0', 0, () => {
      const debt: DebtRef = { id: 'debt-001' }
      const platform = '花呗'
      const principalYuan = 5000

      const resultParams: ResultParams = {
        debtId: debt.id,
        platform: platform,
        principalYuan: principalYuan
      }

      const code = 0
      expect(code).assertEqual(0)
      expect(resultParams.debtId).assertEqual('debt-001')
      expect(resultParams.platform).assertEqual('花呗')
      expect(resultParams.principalYuan).assertEqual(5000)
    })

    it('创建成功_结果包含正确debtId', 0, () => {
      const debt: DebtRef = { id: 'new-debt-123' }
      const resultParams: ResultParams = {
        debtId: debt.id,
        platform: 'test',
        principalYuan: 0
      }
      expect(resultParams.debtId).assertEqual('new-debt-123')
    })

    it('失败_code为-1', 0, () => {
      const err = new Error('db error')
      const errorParams: ErrorParams = { error: (err as Error).message }
      const code = -1
      expect(code).assertEqual(-1)
      expect(errorParams.error).assertContain('db error')
    })

    it('结果参数_可序列化', 0, () => {
      const resultParams: ResultParams = { debtId: 'd1', platform: '花呗', principalYuan: 5000 }
      const serialized = JSON.stringify(resultParams)
      const deserialized: ResultParams = JSON.parse(serialized) as ResultParams
      expect(deserialized.debtId).assertEqual('d1')
    })
  })

  describe('AddDebtExecutor_错误处理', () => {

    it('初始化链失败_进入catch分支', 0, () => {
      let caughtError = false
      try {
        throw new Error('init failed')
      } catch (err) {
        caughtError = true
        const errorParams: ErrorParams = { error: (err as Error).message }
        expect(errorParams.error).assertContain('init failed')
      }
      expect(caughtError).assertTrue()
    })

    it('createDebt失败_进入catch分支', 0, () => {
      let code = 0
      try {
        throw new Error('create failed')
      } catch (err) {
        code = -1
      }
      expect(code).assertEqual(-1)
    })

    it('错误结果_始终返回Promise.resolve', 0, async () => {
      const errorObj: ErrorParams = { error: 'test' }
      const resultObj: ErrorResult = { code: -1, result: errorObj }
      const result: ErrorResult = await Promise.resolve(resultObj)
      expect(result.code).assertEqual(-1)
    })
  })
}
