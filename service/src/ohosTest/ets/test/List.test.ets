import calculationServiceTest from './L0_pure/CalculationService.test'
import platformServiceTest from './L0_pure/PlatformService.test'
import debtFormValidatorTest from './L0_pure/DebtFormValidator.test'
import debtsFilterSortTest from './L0_pure/DebtsFilterSort.test'
import subscriptionReceiptTest from './L0_pure/SubscriptionReceipt.test'
import syncHelpersTest from './L0_pure/SyncHelpers.test'
import syncOutboxTest from './L0_pure/SyncOutbox.test'
import syncFkTest from './L0_pure/SyncFk.test'
import retryHelperTest from './L0_pure/RetryHelper.test'
import liveLockPayloadTest from './L0_pure/LiveLockPayload.test'
import perfTraceTest from './L0_pure/PerfTrace.test'
import homeSnapshotStoreTest from './L0_pure/HomeSnapshotStore.test'
import homeInsightsTest from './L0_pure/HomeInsights.test'
import quoteServiceTest from './L0_pure/QuoteService.test'
import aiServiceConnectionTest from './L0_pure/AIService.connection.test'
import settingsAiBackupTest from './L0_pure/SettingsAiBackup.test'
import syncSchedulerGuardTest from './L0_pure/SyncScheduler.guard.test'
import analyticsServiceContractTest from './L0_pure/AnalyticsService.contract.test'
import debtServiceTest from './L3_services/DebtService.test'
import syncedWriteTest from './L3_services/SyncedWrite.test'
import localDataStoreTest from './L3_services/LocalDataStore.test'
import profileServiceContractTest from './L3_services/ProfileService.contract.test'
import exchangeRateServiceContractTest from './L3_services/ExchangeRateService.contract.test'
import syncRealtimeContractTest from './L3_services/SyncRealtime.contract.test'
import appVersionServiceTest from './L3_services/AppVersionService.test'
import lightSensorServiceTest from './L4_aggregators/LightSensorService.test'
import handednessServiceTest from './L4_aggregators/HandednessService.test'
import ocrServiceTest from './L4_aggregators/OcrService.test'
import speechServiceTest from './L4_aggregators/SpeechService.test'
import iconPickerServiceTest from './L4_aggregators/IconPickerService.test'
import iconCloudServiceTest from './L0_pure/IconCloudService.test'
import debtReceiptTest from './L0_pure/DebtReceipt.test'
import billParsersTest from './L0_pure/BillParsers.test'
import parsePromptsTest from './L0_pure/ParsePrompts.test'
import ceremonyRulesTest from './L0_pure/CeremonyRules.test'
import pressureEvaluatorTest from './L0_pure/PressureEvaluator.test'
import aILiveDraftTest from './L0_pure/AILiveDraft.test'
import aILiveMappingTest from './L0_pure/AILiveMapping.test'
import debtFormPreviewTest from './L0_pure/DebtFormPreview.test'
import localBillExtractServiceTest from './L0_pure/LocalBillExtractService.test'
import nFCShareServiceTest from './L0_pure/NFCShareService.test'
import cryptoServiceTest from './L2_infra/CryptoService.test'
import dbServiceTest from './L2_infra/DbService.test'
import preferencesServiceTest from './L2_infra/PreferencesService.test'
import secureStoreTest from './L2_infra/SecureStore.test'
import userServiceTest from './L2_infra/UserService.test'
import aIServiceTest from './L3_services/AIService.test'
import cloudIdMapTest from './L3_services/CloudIdMap.test'
import creditAccountServiceTest from './L3_services/CreditAccountService.test'
import notificationServiceTest from './L3_services/NotificationService.test'
import paymentServiceTest from './L3_services/PaymentService.test'
import settingsServiceTest from './L3_services/SettingsService.test'
import subscriptionServiceTest from './L3_services/SubscriptionService.test'
import supabaseAuthServiceTest from './L3_services/SupabaseAuthService.test'
import supabaseRestServiceTest from './L3_services/SupabaseRestService.test'
import syncServiceTest from './L3_services/SyncService.test'
import syncTableAdaptersTest from './L3_services/SyncTableAdapters.test'
import aILiveSaveServiceTest from './L4_aggregators/AILiveSaveService.test'
import aIParseOrchestratorTest from './L4_aggregators/AIParseOrchestrator.test'
import dashboardServiceTest from './L4_aggregators/DashboardService.test'
import e2EEServiceTest from './L4_aggregators/E2EEService.test'
import exportImportServiceTest from './L4_aggregators/ExportImportService.test'
import intentServiceTest from './L4_aggregators/IntentService.test'
import liveViewServiceTest from './L4_aggregators/LiveViewService.test'
import pressureAlertServiceTest from './L4_aggregators/PressureAlertService.test'
import reminderServiceTest from './L4_aggregators/ReminderService.test'
import widgetDataBuilderTest from './L4_aggregators/WidgetDataBuilder.test'
import widgetUpdateServiceTest from './L4_aggregators/WidgetUpdateService.test'

export default function testsuite() {
  calculationServiceTest()
  platformServiceTest()
  debtFormValidatorTest()
  debtsFilterSortTest()
  subscriptionReceiptTest()
  debtReceiptTest()
  billParsersTest()
  parsePromptsTest()
  ceremonyRulesTest()
  pressureEvaluatorTest()
  syncHelpersTest()
  syncOutboxTest()
  syncFkTest()
  retryHelperTest()
  liveLockPayloadTest()
  perfTraceTest()
  homeSnapshotStoreTest()
  homeInsightsTest()
  quoteServiceTest()
  aiServiceConnectionTest()
  settingsAiBackupTest()
  syncSchedulerGuardTest()
  analyticsServiceContractTest()
  debtServiceTest()
  syncedWriteTest()
  localDataStoreTest()
  profileServiceContractTest()
  exchangeRateServiceContractTest()
  syncRealtimeContractTest()
  appVersionServiceTest()
  lightSensorServiceTest()
  handednessServiceTest()
  ocrServiceTest()
  speechServiceTest()
  iconPickerServiceTest()
  iconCloudServiceTest()
  aILiveDraftTest()
  aILiveMappingTest()
  debtFormPreviewTest()
  localBillExtractServiceTest()
  nFCShareServiceTest()
  cryptoServiceTest()
  dbServiceTest()
  preferencesServiceTest()
  secureStoreTest()
  userServiceTest()
  aIServiceTest()
  cloudIdMapTest()
  creditAccountServiceTest()
  notificationServiceTest()
  paymentServiceTest()
  settingsServiceTest()
  subscriptionServiceTest()
  supabaseAuthServiceTest()
  supabaseRestServiceTest()
  syncServiceTest()
  syncTableAdaptersTest()
  aILiveSaveServiceTest()
  aIParseOrchestratorTest()
  dashboardServiceTest()
  e2EEServiceTest()
  exportImportServiceTest()
  intentServiceTest()
  liveViewServiceTest()
  pressureAlertServiceTest()
  reminderServiceTest()
  widgetDataBuilderTest()
  widgetUpdateServiceTest()
}
