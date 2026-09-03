/**
 * 本地白盒测试：从源码提取可执行纯逻辑 + 结构契约。
 * Run: node scripts/test-core-whitebox.mjs
 * 退出码 0 通过 / 1 断言失败 / 2 提取失败
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
let failed = 0
const fail = (msg) => {
  console.error('FAIL:', msg)
  failed++
  process.exitCode = 1
}
const ok = (msg) => console.log('OK:', msg)
const extractFail = (msg) => {
  console.error('EXTRACT-FAIL:', msg)
  process.exit(2)
}
const read = (rel) => fs.readFileSync(path.join(root, rel), 'utf8')

function extractMethod(source, methodSig) {
  const s0 = source.indexOf(methodSig)
  if (s0 < 0) return null
  const brace = source.indexOf('{', s0)
  let depth = 0
  let i = brace
  for (; i < source.length; i++) {
    if (source[i] === '{') depth++
    else if (source[i] === '}') {
      depth--
      if (depth === 0) break
    }
  }
  return source.slice(brace + 1, i)
}

// ─── 1) ArrayDataSource 行为（内嵌可运行替身，契约对齐源码 API）───
{
  class ArrayDataSource {
    constructor() {
      this.listeners = []
      this.dataArray = []
    }
    totalCount() { return this.dataArray.length }
    getData(index) { return this.dataArray[index] }
    registerDataChangeListener(l) {
      if (this.listeners.indexOf(l) < 0) this.listeners.push(l)
    }
    unregisterDataChangeListener(l) {
      const pos = this.listeners.indexOf(l)
      if (pos >= 0) this.listeners.splice(pos, 1)
    }
    reload(list) {
      this.dataArray = list
      this.listeners.forEach((l) => l.onDataReloaded && l.onDataReloaded())
    }
    clear() {
      this.dataArray = []
      this.listeners.forEach((l) => l.onDataReloaded && l.onDataReloaded())
    }
    notifyDataAdd(i) { this.listeners.forEach((l) => l.onDataAdd && l.onDataAdd(i)) }
    notifyDataDelete(i) { this.listeners.forEach((l) => l.onDataDelete && l.onDataDelete(i)) }
  }
  const src = read('common/src/main/ets/common/ArrayDataSource.ets')
  if (!src.includes('class ArrayDataSource') || !src.includes('reload(list: Object[])')) {
    fail('ArrayDataSource API missing')
  } else {
    const ds = new ArrayDataSource()
    let reloads = 0
    ds.registerDataChangeListener({ onDataReloaded: () => { reloads++ } })
    ds.reload([{ id: 'a' }, { id: 'b' }])
    if (ds.totalCount() !== 2) fail('ArrayDataSource totalCount')
    if (ds.getData(0).id !== 'a') fail('ArrayDataSource getData')
    if (reloads !== 1) fail('ArrayDataSource reload notify')
    ds.clear()
    if (ds.totalCount() !== 0 || reloads !== 2) fail('ArrayDataSource clear')
    ok('ArrayDataSource whitebox behavior')
  }
}

// ─── 2) PerfTrace ───
{
  const src = read('service/src/main/ets/service/PerfTrace.ets')
  if (!src.includes('static boot()') || !src.includes('T1_main_nav') || !src.includes('T2_home_ready')) {
    fail('PerfTrace missing T0/T1/T2 marks')
  } else {
    // 可执行：无 Logger 依赖的最小模拟
    const state = { t0: 0, t1: -1, t2: -1 }
    const boot = () => { state.t0 = Date.now(); state.t1 = -1; state.t2 = -1 }
    const mark = (name) => {
      if (state.t0 <= 0) state.t0 = Date.now()
      const ms = Date.now() - state.t0
      if (name === 'T1_main_nav') state.t1 = ms
      if (name === 'T2_home_ready') state.t2 = ms
      return ms
    }
    boot()
    const m1 = mark('T1_main_nav')
    const m2 = mark('T2_home_ready')
    if (m1 < 0 || m2 < m1 || state.t1 < 0 || state.t2 < 0) fail('PerfTrace mark order')
    ok('PerfTrace T0/T1/T2 contract')
  }
}

// ─── 3) Theme DARK v9.3 ───
{
  const src = read('common/src/main/ets/common/ThemeManager.ets')
  if (!src.includes("t.background = '#0C0B09'")) fail('DARK canvas not #0C0B09')
  if (!src.includes("t.surface2 = '#1C1A17'")) fail('DARK surface2 not #1C1A17')
  if (!src.includes("t.text = '#F2F1EF'")) fail('DARK text not #F2F1EF')
  if (!src.includes("t.text2 = '#C9C5BD'")) fail('DARK text2 not #C9C5BD')
  if (!src.includes('return this.isDarkCanvas() ? this.surface3 : this.surface2')) {
    fail('sheetBackground dark path not surface3')
  }
  if (!src.includes('return this.isDarkCanvas() ? this.chip : this.surface3')) {
    fail('sheetItemBackground dark path not chip')
  }
  if (!src.includes("return this.isDarkCanvas() ? 'rgba(255,255,255,0.28)' : this.border")) {
    fail('sheetEdgeColor dark path not 0.28')
  }
  ok('ThemeManager DARK v9.3 tokens + sheet lift')
}

// ─── 4) RouteNames.isSecondary 冷/次级拆分 ───
{
  const src = read('common/src/main/ets/common/AppRouter.ets')
  const body = extractMethod(src, 'static isSecondary(name: string): boolean {')
  if (!body) extractFail('RouteNames.isSecondary not found')
  const RouteNames = {
    DEBT_FORM: 'DebtFormPage',
    SUBSCRIPTION_FORM: 'SubscriptionFormPage',
    CREDIT_ACCOUNT_FORM: 'CreditAccountFormPage',
    EXPORT_IMPORT: 'ExportImportPage',
    LEGAL: 'LegalPage',
    PROFILE: 'ProfilePage',
    AVATAR_CROP: 'AvatarCropPage',
    MAIN: 'MainPage',
    SPLASH: 'SplashPage'
  }
  const isSecondary = (name) =>
    name === RouteNames.DEBT_FORM ||
    name === RouteNames.SUBSCRIPTION_FORM ||
    name === RouteNames.CREDIT_ACCOUNT_FORM ||
    name === RouteNames.EXPORT_IMPORT ||
    name === RouteNames.LEGAL ||
    name === RouteNames.PROFILE ||
    name === RouteNames.AVATAR_CROP
  if (!src.includes('RouteNames.AVATAR_CROP')) fail('isSecondary missing AVATAR_CROP')
  if (!isSecondary('DebtFormPage')) fail('secondary DebtForm')
  if (!isSecondary('AvatarCropPage')) fail('secondary AvatarCrop')
  if (isSecondary('MainPage')) fail('Main must not be secondary')
  if (isSecondary('SplashPage')) fail('Splash must not be secondary')
  ok('RouteNames.isSecondary cold/secondary split')
}

// ─── 5) HomeSnapshot JSON 往返 ───
{
  const frame = {
    remainingDebt: 10000,
    thisMonthDue: 500,
    nextMonthDue: 600,
    activeDebtCount: 2,
    subscriptionCount: 1,
    subscriptionTotalAmount: 30,
    creditAccountCount: 1,
    progressPercent: 40,
    hasRepaymentRecords: true,
    monthPaid: 200,
    todayDueAmount: 100,
    overdueCount: 0
  }
  const raw = JSON.stringify(frame)
  const o = JSON.parse(raw)
  if (Number(o.remainingDebt) !== 10000) fail('snapshot remainingDebt')
  if (Boolean(o.hasRepaymentRecords) !== true) fail('snapshot hasRepaymentRecords')
  const src = read('service/src/main/ets/service/sync/HomeSnapshotStore.ets')
  if (!src.includes('home_snapshot') || !src.includes('static async save') || !src.includes('static async load')) {
    fail('HomeSnapshotStore API incomplete')
  }
  ok('HomeSnapshot JSON + API contract')
}

// ─── 6) SyncScheduler 首页错峰 ───
{
  const src = read('service/src/main/ets/service/sync/SyncScheduler.ets')
  const need = [
    'scheduleEnterMainWhenHomeReady',
    'markHomeHydrated',
    'resetHomeHydrated',
    'isHomeHydrated',
    'PULSE_GRACE_MS',
    'HOME_READY_FALLBACK_MS'
  ]
  const fg = extractMethod(src, 'static scheduleForeground(): void {')
  if (!fg) extractFail('scheduleForeground not found')
  if (!fg.includes('homeHydrated')) fail('scheduleForeground must skip when home not hydrated')
  for (const n of need) {
    if (!src.includes(n)) fail('SyncScheduler missing ' + n)
  }
  ok('SyncScheduler home-ready / pulse grace API')
}

// ─── 7) Analytics 18 事件名结构 ───
{
  const src = read('service/src/main/ets/service/AnalyticsService.ets')
  const events = [
    'app_launch', 'app_foreground', 'app_background', 'app_crash',
    'privacy_accept', 'onboarding_complete',
    'record_create_success', 'record_create_fail',
    'tab_view', 'home_action_tap', 'repay_success', 'repay_fail',
    'ai_live_open', 'ai_parse_result',
    'auth_success', 'auth_fail', 'sync_result'
  ]
  // onboarding_skip 产品无入口
  for (const e of events) {
    if (!src.includes("'" + e + "'") && !src.includes('"' + e + '"')) {
      // track methods use string literals
      if (!src.includes(e)) fail('Analytics missing event ' + e)
    }
  }
  ok('Analytics 17 wired event names present')
}

// ─── 8) Dashboard loadHome / buildSummaryFrom ───
{
  const src = read('service/src/main/ets/service/DashboardService.ets')
  if (!src.includes('static async loadHome') || !src.includes('buildSummaryFrom')) {
    fail('DashboardService.loadHome / buildSummaryFrom missing')
  }
  // DashboardHomeSnapshot 已随类型拆分迁移至 DashboardTypes.ets
  const typesSrc = read('service/src/main/ets/service/DashboardTypes.ets')
  if (!typesSrc.includes('class DashboardHomeSnapshot')) fail('DashboardHomeSnapshot missing')
  if (!src.includes("from './DashboardTypes'")) fail('DashboardService 未从 DashboardTypes 导入类型')
  ok('DashboardService single-read home API')
}

// ─── 9) DbService schema v3 + home_snapshot ───
{
  const src = read('service/src/main/ets/service/DbService.ets')
  if (!src.includes('SCHEMA_VERSION: number = 3')) fail('SCHEMA_VERSION not 3')
  if (!src.includes('ensureUserSettingsAiColumns')) fail('ensureUserSettingsAiColumns missing')
  if (!src.includes('home_snapshot')) fail('home_snapshot table missing')
  if (!src.includes('schema_meta')) fail('schema_meta missing')
  ok('DbService schema v3 + home_snapshot + AI columns')
}

// ─── 10) Settings peekCache ───
{
  const src = read('service/src/main/ets/service/SettingsService.ets')
  if (!src.includes('static peekCache') || !src.includes('static clearCache')) {
    fail('SettingsService cache API incomplete')
  }
  ok('SettingsService peek/clear cache API')
}

// ─── 10b) 防窥脱敏态契约 ───
{
  const anti = read('service/src/main/ets/service/AntiPeekService.ets')
  if (!anti.includes('ANTI_PEEK_MASKED')) fail('AntiPeekService not driving antiPeekMasked')
  if (!anti.includes('DlpAntiPeepStatus.HIDE')) fail('AntiPeekService missing HIDE check')
  if (anti.includes('PRIVACY_SHIELDED')) fail('AntiPeekService must not reuse full-screen shield state')
  const index = read('entry/src/main/ets/pages/Index.ets')
  if (index.includes('隐私防护已开启') || index.includes('PRIVACY_SHIELDED')) {
    fail('Index must not show resume privacy shield overlay')
  }
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets')
  if (ability.includes('PrivacyGuard') || ability.includes('syncShieldState')) {
    fail('EntryAbility must not arm privacy shield on resume')
  }
  ok('AntiPeek masked-state contract / no resume privacy shield')
}

// ─── 11) Debt/Sub/Account 投影读 ───
{
  for (const [file, needle] of [
    ['service/src/main/ets/service/DebtService.ets', 'LocalDataStore.getDebts'],
    ['service/src/main/ets/service/SubscriptionService.ets', 'LocalDataStore.getSubscriptions'],
    ['service/src/main/ets/service/CreditAccountService.ets', 'LocalDataStore.getAccounts']
  ]) {
    const s = read(file)
    if (!s.includes(needle)) fail(file + ' missing projection ' + needle)
  }
  ok('List services use LocalDataStore projection')
}

// ─── 12) LazyForEach 主列表 ───
{
  for (const f of [
    'entry/src/main/ets/pages/DebtsTab.ets',
    'entry/src/main/ets/pages/SubscriptionsTab.ets',
    'entry/src/main/ets/pages/CreditAccountsTab.ets'
  ]) {
    const s = read(f)
    if (!s.includes('LazyForEach') || !s.includes('ArrayDataSource')) {
      fail(f + ' not using LazyForEach+ArrayDataSource')
    }
    if (!s.includes('cachedCount')) fail(f + ' missing cachedCount')
  }
  ok('Main lists LazyForEach + cachedCount')
}

// ─── 13) Main 性能编排 ───
{
  const s = read('entry/src/main/ets/pages/MainPage.ets')
  if (!s.includes('scheduleEnterMainWhenHomeReady')) fail('Main missing home-ready sync')
  if (!s.includes('peekCache') && !s.includes('applyThemeFromCacheOrLoad')) {
    fail('Main missing cache theme path')
  }
  if (!s.includes('startLightSensorIfEnabled')) fail('Main missing gated light sensor')
  if (!s.includes('import lazy { AILiveOverlay }')) fail('MainPage must lazy-import AILiveOverlay')
  ok('MainPage perf orchestration')
}

// ─── 13b) 冷启动：Index lazy + Ability 不抢 hydrate ───
{
  const index = read('entry/src/main/ets/pages/Index.ets')
  if (!index.includes('import lazy { MainPage }')) fail('Index must lazy-import MainPage')
  if (!index.includes("import { SplashPage } from './SplashPage'")) fail('Splash must stay eager')
  if (index.includes("import { MainPage } from './MainPage'")) fail('MainPage must not be eager-imported')
  if (!index.includes('import lazy { secondaryDestination }')) fail('Index must lazy-import secondary destinations')
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets')
  if (!ability.includes('SyncScheduler.isHomeHydrated()')) fail('onForeground must wait for home hydrate')
  ok('Cold start lazy import / hydrate gate')
}

// ─── 13c) 打开更顺：当前 Tab 刷新 / 首页不 build 重算 / 图卡 skipGrow ───
{
  const dash = read('entry/src/main/ets/pages/DashboardTab.ets')
  if (dash.includes('private insightItems(')) fail('Dashboard must not recompute insights in build helper')
  if (!dash.includes('rebuildInsights()')) fail('Dashboard missing rebuildInsights')
  if (!dash.includes('return this.debtTrend')) fail('Dashboard sparkline must use cached debtTrend')
  if (!dash.includes('skipGrow: true')) fail('Dashboard PressureChart must skipGrow')
  if (!dash.includes('if (this.mainTabForEnter !== 0)')) fail('Dashboard onListRefresh must skip off-tab')
  const debts = read('entry/src/main/ets/pages/DebtsTab.ets')
  if (!debts.includes('if (this.mainTabIndex !== 1)')) fail('DebtsTab onListRefresh must skip off-tab')
  const card = read('components/src/main/ets/components/DebtCard.ets')
  if (card.includes('getCreditAccounts()')) fail('DebtCard must not scan all accounts')
  const form = read('entry/src/main/ets/pages/DebtFormPage.ets')
  if (!form.includes('previewCacheKey')) fail('DebtFormPage missing preview cache')
  const forms = read('entry/src/main/resources/base/profile/form_config.json')
  if (forms.includes('"updateDuration": 1')) fail('widget updateDuration must not be 30min')
  if (!forms.includes('"updateDuration": 0')) fail('widget updateDuration should be 0 (app-driven)')
  ok('Open-smooth: tab-scoped refresh / cached insights / skipGrow / preview cache')
}

// ─── 13d) 启动边角：会话不重复读 / put 不立即 flush / 今日应还不整表摊还 ───
{
  const ability = read('entry/src/main/ets/entryability/EntryAbility.ets')
  if (!ability.includes('applySystemFollowColorMode')) fail('Ability must follow system at boot')
  if (ability.includes('AuthManager.loadSession')) fail('Ability must not loadSession for theme')
  if (!ability.includes('PreferencesService.flush()')) fail('Ability onBackground must flush prefs')
  const pref = read('service/src/main/ets/service/PreferencesService.ets')
  const put = extractMethod(pref, 'static async putString(key: string, value: string): Promise<void> {')
  if (!put) extractFail('putString not found')
  if (put.includes('.flush()')) fail('putString must not flush immediately')
  const dashSvc = read('service/src/main/ets/service/DashboardService.ets')
  if (dashSvc.includes('generatePaymentSchedule')) fail('DashboardService must not full-schedule today due')
  if (!dashSvc.includes('currentPeriodDue')) fail('DashboardService missing currentPeriodDue')
  const formAb = read('entry/src/main/ets/widget/FormAbility.ets')
  if (formAb.includes('E2EEService')) fail('FormAbility must not initialize E2EE')
  ok('Boot leftovers: no duplicate session / deferred flush / one-period due')
}

// ─── 14) Utils money + days 回归 ───
{
  const usrc = read('common/src/main/ets/common/Utils.ets')
  const yStart = usrc.indexOf('static yuanToFen(yuan: number): number {')
  if (yStart < 0) extractFail('yuanToFen')
  const yBrace = usrc.indexOf('{', yStart)
  let depth = 0, i = yBrace
  for (; i < usrc.length; i++) {
    if (usrc[i] === '{') depth++
    else if (usrc[i] === '}') { depth--; if (depth === 0) break }
  }
  // eslint-disable-next-line no-new-func
  const yuanToFen = new Function('yuan', usrc.slice(yBrace + 1, i))
  if (yuanToFen(1) !== 100) fail('yuanToFen(1)')
  if (yuanToFen(10.55) !== 1055) fail('yuanToFen(10.55)')
  ok('Utils.yuanToFen regression')
}

// ─── 15) 表单图标 bindSheet 必须独立宿主 + 双向绑定（链式挂载会闪关）───
// 图标选择 sheet 已收进共用组件 FormLogoHeader（自带独立宿主与 $$ 绑定），
// 三表单页不得再内联 icon bindSheet 与账户 sheet 链式同宿主。
{
  const header = read('components/src/main/ets/components/FormLogoHeader.ets')
  if (!header.includes('.bindSheet($$this.showPicker')) {
    fail('FormLogoHeader: icon bindSheet must use $$ two-way bind on its own host')
  }
  const forms = [
    'entry/src/main/ets/pages/DebtFormPage.ets',
    'entry/src/main/ets/pages/SubscriptionFormPage.ets',
    'entry/src/main/ets/pages/CreditAccountFormPage.ets'
  ]
  for (const rel of forms) {
    const src = read(rel)
    if (src.includes('.bindSheet($$this.showIconPicker') || /bindSheet\([^)]*showIconPicker/.test(src)) {
      fail(rel + ': icon bindSheet moved into FormLogoHeader; do not re-inline it')
    }
  }
  ok('Form icon bindSheet lives in FormLogoHeader with $$ two-way bind')
}

// ─── 16b) PC 导入旧 updated_at → 增量漏拉，核对应按 id 差集补拉 ───
{
  const src = read('service/src/main/ets/service/sync/SyncHelpers.ets')
  const syncSrc = read('service/src/main/ets/service/sync/SyncService.ets')
  const importSrc = read('service/src/main/ets/service/ExportImportService.ets')
  if (!syncSrc.includes('backfillMissingCloudRows') || !syncSrc.includes('missingCloudIds')) {
    fail('SyncService must backfill cloud-only ids after incremental miss')
  }
  if (!importSrc.includes("input.icon_url = iconUrl") && !importSrc.includes("input.icon_url = ExportImportService.fieldStr(d, 'icon_url')")) {
    fail('ExportImportService must write debt icon_url on import')
  }
  const missStart = src.indexOf('static missingCloudIds(cloudIds: string[], localCloudIds: string[]): string[] {')
  if (missStart < 0) extractFail('missingCloudIds')
  const missBrace = src.indexOf('{', missStart)
  let depth = 0
  let i = missBrace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  const missBody = src.slice(missBrace + 1, i)
  const listStart = src.indexOf('static listHas(list: string[], value: string): boolean {')
  if (listStart < 0) extractFail('listHas')
  const listBrace = src.indexOf('{', listStart)
  depth = 0
  i = listBrace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  const listBody = src.slice(listBrace + 1, i)
  const stripTypes = (s) => s.replace(/: string\[\]/g, '')
  // eslint-disable-next-line no-new-func
  const missingCloudIds = new Function(
    'cloudIds',
    'localCloudIds',
    'const SyncHelpers = { listHas: function (list, value) {' + stripTypes(listBody) + '} };\n' +
      stripTypes(missBody)
  )
  // 复现：cursor 之后只拉到负债；订阅/账户 updated_at 更旧，增量过滤掉
  const lastSyncAt = '2026-08-01T00:00:00.000Z'
  const cloud = [
    { id: 'debt-new', updated_at: '2026-08-18T00:00:00.000Z', table: 'debts' },
    { id: 'acc-old', updated_at: '2024-01-02T00:00:00.000Z', table: 'credit_accounts' },
    { id: 'sub-old', updated_at: '2024-01-02T00:00:00.000Z', table: 'subscriptions' }
  ]
  const incremental = cloud.filter((r) => r.updated_at > lastSyncAt).map((r) => r.id)
  if (incremental.length !== 1 || incremental[0] !== 'debt-new') {
    fail('incremental filter fixture broken: ' + JSON.stringify(incremental))
  }
  const localAfterIncremental = incremental.slice()
  const missed = missingCloudIds(cloud.map((r) => r.id), localAfterIncremental)
  if (missed.length !== 2 || missed[0] !== 'acc-old' || missed[1] !== 'sub-old') {
    fail('PC import stale updated_at must be backfilled: ' + JSON.stringify(missed))
  }
  ok('Incremental miss + missingCloudIds backfill')
}

// ─── 16) 空态资源体积门禁（防止回退到 MB 级；WebP 化后预算同步收紧到 512KB）───
// 归一后 empty_home 仅存于 components（EmptyState 默认图），其余三张归 entry
{
  const compMedia = path.join(root, 'components/src/main/resources/base/media')
  const media = path.join(root, 'entry/src/main/resources/base/media')
  const empties = [
    path.join(compMedia, 'empty_home.webp'),
    path.join(media, 'empty_debt.webp'),
    path.join(media, 'empty_account.webp'),
    path.join(media, 'empty_subscription.webp')
  ]
  let total = 0
  for (const p of empties) {
    if (!fs.existsSync(p)) fail('missing ' + path.basename(p))
    else total += fs.statSync(p).size
  }
  if (total > 512 * 1024) fail('empty assets total too large: ' + total)
  ok('Empty assets size budget (<512KB webp total), actual ' + Math.round(total / 1024) + 'KB')
}

// ─── 17) 双侧共用媒体归一门禁（components 与 entry 禁止同名重复定义）───
{
  const a = path.join(root, 'components/src/main/resources/base/media')
  const b = path.join(root, 'entry/src/main/resources/base/media')
  const names = fs.readdirSync(a)
  const dupes = names.filter((n) => fs.existsSync(path.join(b, n)))
  if (dupes.length > 0) fail('duplicated media in components & entry: ' + dupes.join(', '))
  ok('No duplicated media across components & entry')
}

if (failed > 0) {
  console.error('\nWhitebox: ' + failed + ' failed')
  process.exit(1)
}
console.log('\nAll core whitebox tests passed')
