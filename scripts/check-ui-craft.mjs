/**
 * UI 精致门禁（craft v2 · redesign-v9）
 * - 主路径 + 表单/设置/锁/通知/主题：禁裸 fontSize(数字)
 * - 同范围：禁裸 borderRadius(整数魔法)（允许 0 / ≤2 / 999 / theme.radius* / MotionTokens）
 * 用法：node scripts/check-ui-craft.mjs
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.join(__dirname, '..')

const CRAFT_PATH = [
  'entry/src/main/ets/pages/DashboardTab.ets',
  'entry/src/main/ets/pages/DebtsTab.ets',
  'entry/src/main/ets/pages/SubscriptionsTab.ets',
  'entry/src/main/ets/pages/CreditAccountsTab.ets',
  'entry/src/main/ets/pages/SettingsTab.ets',
  'entry/src/main/ets/pages/ProfilePage.ets',
  'entry/src/main/ets/pages/AppLockPage.ets',
  'entry/src/main/ets/pages/DebtFormPage.ets',
  'entry/src/main/ets/pages/SubscriptionFormPage.ets',
  'entry/src/main/ets/pages/CreditAccountFormPage.ets',
  'entry/src/main/ets/pages/MainPage.ets',
  'entry/src/main/ets/pages/common/BatchShell.ets',
  'entry/src/main/ets/pages/LoginPage.ets',
  'entry/src/main/ets/pages/OnboardingPage.ets',
  'entry/src/main/ets/pages/SplashPage.ets',
  'entry/src/main/ets/pages/RegisterPage.ets',
  'entry/src/main/ets/pages/RecoverPage.ets',
  'entry/src/main/ets/pages/ExportImportPage.ets',
  'entry/src/main/ets/pages/LegalPage.ets',
  'entry/src/main/ets/pages/AvatarCropPage.ets',
  'entry/src/main/ets/widget/pages/SubscriptionCard.ets',
  'components/src/main/ets/components/DetailSheetView.ets',
  // 组件在 components HAR（非 entry 内路径）
  'components/src/main/ets/components/DebtCard.ets',
  'components/src/main/ets/components/SubscriptionCard.ets',
  'components/src/main/ets/components/CreditAccountCard.ets',
  'components/src/main/ets/components/AILiveInputBar.ets',
  'components/src/main/ets/components/AILiveScanView.ets',
  'components/src/main/ets/components/EmptyState.ets',
  'components/src/main/ets/components/SwipeEditDeleteActions.ets',
  'components/src/main/ets/components/PressureChart.ets',
  'components/src/main/ets/components/SheetDialog.ets',
  'components/src/main/ets/components/ReceiptSlipOverlay.ets',
  'components/src/main/ets/components/SettingsThemeSheet.ets',
  'components/src/main/ets/components/AIConfigSheet.ets',
  'entry/src/main/ets/components/AILiveOverlay.ets',
  'components/src/main/ets/components/AILiveVoiceFullscreen.ets',
  'components/src/main/ets/components/ExportImportPanel.ets',
  'components/src/main/ets/components/FormWidgets.ets',
  'components/src/main/ets/components/FormLogoHeader.ets',
  'entry/src/main/ets/widget/pages/MonthDueCard.ets',
  'entry/src/main/ets/widget/pages/PressureTrendCard.ets',
  'entry/src/main/ets/widget/pages/DebtOverviewCard.ets',
  'entry/src/main/ets/widget/pages/DebtPressureCard.ets',
  'components/src/main/ets/components/AllClearedCeremonyOverlay.ets',
]

const bareFont = /\.fontSize\(\s*\d+(?:\.\d+)?\s*\)/
// 单参数数字圆角：允许 0 / ≤2（波形点/停止方块）/ 999；禁止魔法数
const bareRadiusNum = /\.borderRadius\(\s*(\d+(?:\.\d+)?)\s*\)/
const bareDurationProp = /duration:\s*\d+/

let failed = 0
let skipped = 0

for (const rel of CRAFT_PATH) {
  const full = path.join(root, rel)
  if (!fs.existsSync(full)) {
    failed++
    console.log(`FAIL missing: ${rel}`)
    continue
  }
  const lines = fs.readFileSync(full, 'utf8').split('\n')
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    if (bareFont.test(line)) {
      failed++
      console.log(`FAIL font ${rel}:${i + 1}: ${line.trim()}`)
    }
    const rm = line.match(bareRadiusNum)
    if (
      rm &&
      !line.includes('theme.radius') &&
      !line.includes('MotionTokens') &&
      !line.includes('W_RADIUS')
    ) {
      const v = Number(rm[1])
      if (!(v === 0 || v === 999 || v <= 2)) {
        failed++
        console.log(`FAIL radius ${rel}:${i + 1}: ${line.trim()}`)
      }
    }
    // 动效时长必须走 MotionTokens（LongPressGesture 的 duration 是手势阈值，放过）
    if (
      bareDurationProp.test(line) &&
      !line.includes('MotionTokens') &&
      !line.includes('LongPressGesture') &&
      !line.includes('setTimeout') &&
      (line.includes('animateTo') ||
        line.includes('.animation') ||
        line.includes('PageTransition') ||
        (line.includes('duration:') && (line.includes('curve:') || line.includes('animation'))))
    ) {
      failed++
      console.log(`FAIL motion ${rel}:${i + 1}: ${line.trim()}`)
    }
  }
}

if (failed > 0) {
  console.log(`\nUI craft gate FAILED: ${failed} issue(s)`)
  process.exit(1)
}
console.log(`OK: craft path has no bare fontSize / borderRadius / motion duration magic numbers (skipped ${skipped})`)
process.exit(0)
