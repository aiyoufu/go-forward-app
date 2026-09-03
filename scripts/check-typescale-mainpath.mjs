/**
 * 主路径禁裸 fontSize(数字) 门禁
 * 范围：首页 / 三列表 / AI 条与扫描 / 空态 / 摘要与列表卡 / 主图表
 * 用法：node scripts/check-typescale-mainpath.mjs
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.join(__dirname, '..')

const MAIN_PATH = [
  'entry/src/main/ets/pages/DashboardTab.ets',
  'entry/src/main/ets/pages/DebtsTab.ets',
  'entry/src/main/ets/pages/SubscriptionsTab.ets',
  'entry/src/main/ets/pages/CreditAccountsTab.ets',
  'components/src/main/ets/components/DebtCard.ets',
  'components/src/main/ets/components/SubscriptionCard.ets',
  'components/src/main/ets/components/CreditAccountCard.ets',
  'components/src/main/ets/components/AILiveInputBar.ets',
  'components/src/main/ets/components/AILiveScanView.ets',
  'components/src/main/ets/components/EmptyState.ets',
  'components/src/main/ets/components/SwipeEditDeleteActions.ets',
  'components/src/main/ets/components/PressureChart.ets',
]

const bare = /\.fontSize\(\s*\d+(?:\.\d+)?\s*\)/g
let failed = 0

for (const rel of MAIN_PATH) {
  const full = path.join(root, rel)
  if (!fs.existsSync(full)) {
    failed++
    console.log(`FAIL missing: ${rel}`)
    continue
  }
  const text = fs.readFileSync(full, 'utf8')
  const lines = text.split('\n')
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(bare)
    if (m) {
      failed++
      console.log(`FAIL ${rel}:${i + 1}: ${lines[i].trim()}`)
    }
  }
}

if (failed > 0) {
  console.log(`\nTypeScale gate FAILED: ${failed} bare fontSize(number) on main path`)
  process.exit(1)
}
console.log('OK: main path has no bare fontSize(number)')
process.exit(0)
