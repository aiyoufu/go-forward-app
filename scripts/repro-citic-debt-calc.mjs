/**
 * 中信/京东 PLUS 联名卡分期金额回归（无设备可跑）。
 * 案例：本金 519.93、月供 58.31、9 期、年化 3.23%、服务费 0.54/期。
 * Run: node scripts/repro-citic-debt-calc.mjs
 * 退出码 0 通过 / 1 失败
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8')

let failed = 0
const fail = (msg) => {
  console.error('FAIL:', msg)
  failed++
}
const ok = (msg) => console.log('OK:', msg)

const PRINCIPAL_FEN = 51993
const MONTHLY_FEN = 5831
const PERIODS = 9
const FEE_FEN = 54
const RATE_BP = 323

function pmtFen(principal, annualRateBp, n) {
  const r = annualRateBp / 10000 / 12
  return Math.round((principal * r * Math.pow(1 + r, n)) / (Math.pow(1 + r, n) - 1))
}

function distributeFenFront(totalFen, periods) {
  if (periods <= 0) return []
  if (totalFen <= 0) return Array.from({ length: periods }, () => 0)
  const base = Math.floor(totalFen / periods)
  const rem = totalFen - base * periods
  return Array.from({ length: periods }, (_, i) => base + (i < rem ? 1 : 0))
}

function useEqualMonthly(principal, monthly, periods, totalInterest = 0) {
  const feeFen = totalInterest > 0 ? totalInterest : Math.max(0, monthly * periods - principal)
  const interestParts = distributeFenFront(feeFen, periods)
  const list = []
  let principalAssigned = 0
  for (let i = 0; i < periods; i++) {
    const interest = interestParts[i] ?? 0
    const principalPart = i === periods - 1
      ? Math.max(0, principal - principalAssigned)
      : Math.max(0, monthly - interest)
    if (i < periods - 1) principalAssigned += principalPart
    list.push({
      period: i + 1,
      principal: principalPart,
      interest,
      total: i === periods - 1 ? principalPart + interest : monthly,
    })
  }
  const sumP = list.reduce((s, x) => s + x.principal, 0)
  if (sumP !== principal && periods > 0) {
    const drift = principal - sumP
    list[periods - 1].principal = Math.max(0, list[periods - 1].principal + drift)
    list[periods - 1].total = list[periods - 1].principal + list[periods - 1].interest
  }
  return list
}

function remainingDue(remaining, monthly, balance, status, debtType) {
  if (status === 'completed') return 0
  if (debtType !== 'installment') return balance
  if (remaining <= 0 || monthly <= 0 || balance <= 0) {
    const pending = remaining <= 0 ? 1 : remaining
    return monthly > 0 && status === 'active' && balance > 0 ? monthly * pending : balance
  }
  const inclusive = monthly * remaining
  const exclusive = monthly * (remaining + 1)
  const isInclusive = Math.abs(balance - inclusive) < Math.abs(balance - exclusive)
  const pending = isInclusive
    ? Math.max(0, remaining)
    : Math.max(0, remaining + 1)
  return monthly * pending
}

// ── 1) 旧算法（等额本息重算 PMT）会算出 58.55，这就是线上预览偏差 ──
{
  const computed = pmtFen(PRINCIPAL_FEN, RATE_BP, PERIODS)
  if (computed === MONTHLY_FEN) {
    fail('旧 PMT 不应等于银行月供 58.31，案例数据可能已变')
  } else {
    ok(`旧 PMT=${computed} 分（${(computed / 100).toFixed(2)}）≠ 月供 ${MONTHLY_FEN}`)
  }
  if (computed < 5850 || computed > 5860) {
    fail(`旧 PMT 预期约 5855，实际 ${computed}`)
  }
}

// ── 2) 正确算法：月供×期数反推总服务费并均摊 ──
{
  const list = useEqualMonthly(PRINCIPAL_FEN, MONTHLY_FEN, PERIODS, 486)
  if (list.length !== 9) fail(`期数 ${list.length} ≠ 9`)
  for (let i = 0; i < 8; i++) {
    if (list[i].total !== MONTHLY_FEN) fail(`第 ${i + 1} 期 total ${list[i].total} ≠ 5831`)
    if (list[i].interest !== FEE_FEN) fail(`第 ${i + 1} 期 interest ${list[i].interest} ≠ 54`)
    if (list[i].principal !== 5777) fail(`第 ${i + 1} 期 principal ${list[i].principal} ≠ 5777`)
  }
  if (list[8].interest !== FEE_FEN) fail(`末期 interest ${list[8].interest} ≠ 54`)
  if (list[8].total !== MONTHLY_FEN) fail(`末期 total ${list[8].total} ≠ 5831`)
  const sumP = list.reduce((s, x) => s + x.principal, 0)
  if (sumP !== PRINCIPAL_FEN) fail(`本金合计 ${sumP} ≠ 51993`)
  ok('等额月供+服务费：9 期均为 58.31 / 息 0.54')
}

// ── 3) 剩余未还：PC remaining=0（末期）不能回退成仅本金 57.77 ──
{
  const dueLastExclusive = remainingDue(0, MONTHLY_FEN, 5777, 'active', 'installment')
  if (dueLastExclusive !== MONTHLY_FEN) {
    fail(`末期 remaining=0 剩余未还应为 58.31，实际 ${dueLastExclusive}`)
  } else {
    ok('末期 remaining=0 → 剩余未还 58.31（含服务费）')
  }
  const dueTwoPending = remainingDue(1, MONTHLY_FEN, 11662, 'active', 'installment')
  if (dueTwoPending !== MONTHLY_FEN * 2) {
    fail(`PC remaining=1 剩余未还应为 116.62，实际 ${dueTwoPending}`)
  } else {
    ok('PC remaining=1（当期之后 1 期）→ 剩余未还 116.62')
  }
  const dueHarmonyLast = remainingDue(1, MONTHLY_FEN, 5777, 'active', 'installment')
  if (dueHarmonyLast !== MONTHLY_FEN) {
    fail(`鸿蒙含当期 remaining=1 剩余未还应为 58.31，实际 ${dueHarmonyLast}`)
  } else {
    ok('鸿蒙含当期 remaining=1 + 余额≈月供 → 剩余未还 58.31')
  }
}

// ── 4) 源码契约：修复后必须落地这些路径 ──
{
  const preview = read('service/src/main/ets/service/DebtFormPreview.ets')
  const calc = read('service/src/main/ets/service/CalculationService.ets')
  const form = read('entry/src/main/ets/pages/DebtFormPage.ets')
  const tab = read('entry/src/main/ets/pages/DebtsTab.ets')

  if (!preview.includes('useEqualMonthly') && !preview.includes('impliedFeeFen')) {
    fail('DebtFormPreview 尚未接入「月供×期数反推服务费」路径')
  } else {
    ok('DebtFormPreview 含等额月供路径')
  }
  if (!calc.includes('getInstallmentRemainingDue')) {
    fail('CalculationService 缺少 getInstallmentRemainingDue')
  } else {
    ok('CalculationService 含剩余未还口径')
  }
  if (!tab.includes('getInstallmentRemainingDue')) {
    fail('DebtsTab.buildDebtDetail 未改用 getInstallmentRemainingDue')
  } else {
    ok('DebtsTab 详情剩余未还走统一口径')
  }
  if (!form.includes("this.repaymentMethod === 'fixed_interest'") ||
      !form.includes('必须保留用户/银行月供')) {
    fail('DebtFormPage 仍会在非等本等息时用本金/期数覆盖每月应还')
  } else {
    ok('DebtFormPage 不再用本金均摊覆盖等额本息月供')
  }
  if (!form.includes("含服务费 '") && !form.includes('含服务费 ')) {
    fail('预览 UI 未改为「含服务费」')
  } else {
    ok('预览 UI 展示含服务费')
  }
}

if (failed > 0) {
  console.error(`\n${failed} failed`)
  process.exit(1)
}
console.log('\nall passed')
process.exit(0)
