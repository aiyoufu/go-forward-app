import debtPressureCardTest from './widget/DebtPressureCard.test'
import monthDueCardTest from './widget/MonthDueCard.test'
import pressureTrendCardTest from './widget/PressureTrendCard.test'
import subscriptionCardTest from './widget/SubscriptionCard.test'
import widgetTypeScaleTest from './widget/WidgetTypeScale.test'
import e2eCreateDebtTest from './e2e/E2E_CreateDebt.test'
import e2eRepaymentTest from './e2e/E2E_Repayment.test'
import e2eCreateSubscriptionTest from './e2e/E2E_CreateSubscription.test'
import e2eSettingsTest from './e2e/E2E_Settings.test'
import e2eExportImportTest from './e2e/E2E_ExportImport.test'
import e2eLoginTest from './e2e/E2E_Login.test'
import e2eColdStartTest from './e2e/E2E_ColdStart.test'
import lockScreenLivePageTest from './liveview/LockScreenLivePage.test'
import addDebtExecutorTest from './insightintents/AddDebtExecutor.test'
import checkDebtExecutorTest from './insightintents/CheckDebtExecutor.test'
import checkSubscriptionExecutorTest from './insightintents/CheckSubscriptionExecutor.test'
import countdownToPayoffExecutorTest from './insightintents/CountdownToPayoffExecutor.test'
import markPaidExecutorTest from './insightintents/MarkPaidExecutor.test'
import openAILiveExecutorTest from './insightintents/OpenAILiveExecutor.test'
import queryPressureExecutorTest from './insightintents/QueryPressureExecutor.test'
import querySummaryExecutorTest from './insightintents/QuerySummaryExecutor.test'
import liveViewLockScreenAbilityTest from './liveview/LiveViewLockScreenAbility.test'
import entryAbilityTest from './entryability/EntryAbility.test'
import listSelectionTest from './L0_pure/ListSelection.test'
import debtFormMathTest from './L0_pure/DebtFormMath.test'
import settingsDisplayTest from './L0_pure/SettingsDisplay.test'

// Entry 页面 UI 测试
import dashboardTabUITest from './pages/DashboardTab.ui.test'
import debtsTabUITest from './pages/DebtsTab.ui.test'
import subscriptionsTabUITest from './pages/SubscriptionsTab.ui.test'
import creditAccountsTabUITest from './pages/CreditAccountsTab.ui.test'
import settingsTabUITest from './pages/SettingsTab.ui.test'
import debtFormPageUITest from './pages/DebtFormPage.ui.test'
import subscriptionFormPageUITest from './pages/SubscriptionFormPage.ui.test'
import creditAccountFormPageUITest from './pages/CreditAccountFormPage.ui.test'
import loginPageUITest from './pages/LoginPage.ui.test'
import registerPageUITest from './pages/RegisterPage.ui.test'
import recoverPageUITest from './pages/RecoverPage.ui.test'
import appLockPageUITest from './pages/AppLockPage.ui.test'
import mainPageUITest from './pages/MainPage.ui.test'
import exportImportPageUITest from './pages/ExportImportPage.ui.test'
import splashPageUITest from './pages/SplashPage.ui.test'
import legalPageUITest from './pages/LegalPage.ui.test'
import indexUITest from './pages/Index.ui.test'
import onboardingPageUITest from './pages/OnboardingPage.ui.test'
import profilePageUITest from './pages/ProfilePage.ui.test'
import secondaryDestinationsUITest from './pages/SecondaryDestinations.ui.test'

export default function testsuite() {
  // Widget UI 测试
  debtPressureCardTest()
  monthDueCardTest()
  pressureTrendCardTest()
  subscriptionCardTest()
  widgetTypeScaleTest()

  // E2E 流程测试
  e2eCreateDebtTest()
  e2eRepaymentTest()
  e2eCreateSubscriptionTest()
  e2eSettingsTest()
  e2eExportImportTest()
  e2eLoginTest()
  e2eColdStartTest()

  // InsightIntent Executor 测试
  addDebtExecutorTest()
  checkDebtExecutorTest()
  checkSubscriptionExecutorTest()
  countdownToPayoffExecutorTest()
  markPaidExecutorTest()
  openAILiveExecutorTest()
  queryPressureExecutorTest()
  querySummaryExecutorTest()

  // LiveView UI 测试
  lockScreenLivePageTest()
  liveViewLockScreenAbilityTest()

  // EntryAbility 测试
  entryAbilityTest()

  // 页面纯逻辑（L0）
  listSelectionTest()
  debtFormMathTest()
  settingsDisplayTest()

  // Entry 页面 UI 测试
  dashboardTabUITest()
  debtsTabUITest()
  subscriptionsTabUITest()
  creditAccountsTabUITest()
  settingsTabUITest()
  debtFormPageUITest()
  subscriptionFormPageUITest()
  creditAccountFormPageUITest()
  loginPageUITest()
  registerPageUITest()
  recoverPageUITest()
  appLockPageUITest()
  mainPageUITest()
  exportImportPageUITest()
  splashPageUITest()
  legalPageUITest()
  indexUITest()
  onboardingPageUITest()
  profilePageUITest()
  secondaryDestinationsUITest()
}
