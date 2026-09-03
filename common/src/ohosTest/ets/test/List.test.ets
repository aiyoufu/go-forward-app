import appStorageKeysTest from './AppStorageKeys.test'
import constantsTest from './Constants.test'
import errorMessagesTest from './ErrorMessages.test'
import legalDocumentsTest from './LegalDocuments.test'
import motionHelperTest from './MotionHelper.test'
import supabaseConfigTest from './SupabaseConfig.test'
import themeManagerTest from './ThemeManager.test'
import themeModeTest from './ThemeMode.test'
import utilsTest from './Utils.test'
import currencyServiceTest from './CurrencyService.test'
import creditAccountModelTest from './model/CreditAccountModel.test'
import debtModelTest from './model/DebtModel.test'
import subscriptionModelTest from './model/SubscriptionModel.test'
import arrayDataSourceTest from './ArrayDataSource.test'
import immersiveTitleBarTest from './ImmersiveTitleBar.test'
import loggerTest from './Logger.test'
import appRouterTest from './AppRouter.test'
import currencyModelTest from './model/CurrencyModel.test'
import homeSubtitleComposerTest from './HomeSubtitleComposer.test'
import achievementCardModelTest from './model/AchievementCardModel.test'
import notificationModelTest from './model/NotificationModel.test'
import paymentRecordModelTest from './model/PaymentRecordModel.test'
import userSettingsModelTest from './model/UserSettingsModel.test'

export default function testsuite() {
  appStorageKeysTest()
  constantsTest()
  errorMessagesTest()
  legalDocumentsTest()
  motionHelperTest()
  supabaseConfigTest()
  themeManagerTest()
  themeModeTest()
  utilsTest()
  currencyServiceTest()
  creditAccountModelTest()
  debtModelTest()
  subscriptionModelTest()
  arrayDataSourceTest()
  immersiveTitleBarTest()
  loggerTest()
  appRouterTest()
  currencyModelTest()
  homeSubtitleComposerTest()
  achievementCardModelTest()
  notificationModelTest()
  paymentRecordModelTest()
  userSettingsModelTest()
}
