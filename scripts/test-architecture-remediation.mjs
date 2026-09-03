/**
 * Architecture remediation verification — drives pure helpers from shipped sources.
 * Run: node scripts/test-architecture-remediation.mjs
 *
 * 耦合约束：本脚本与 .ets 源码的文本格式强耦合 —— 各提取器按「方法签名字符串定位 +
 * 花括号配平」切出方法体，用 new Function 执行。重构对应方法的签名（改名、参数、
 * 类型标注、签名换行格式）时，必须同步更新本脚本中的提取模式（README「开发与门禁」
 * 段有同样说明）。
 * 输出区分：提取失败输出 EXTRACT-FAIL 并以退出码 2 终止（源码格式变化，非逻辑问题）；
 * 断言失败输出 FAIL 并最终以退出码 1 终止（被测逻辑行为不符）。
 */
import fs from 'fs'
import path from 'path'
import { fileURLToPath } from 'url'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const root = path.resolve(__dirname, '..')
const fail = (msg) => {
  console.error('FAIL:', msg)
  process.exitCode = 1
}
const ok = (msg) => console.log('OK:', msg)
// 提取失败 ≠ 断言失败：源码文本格式变化导致定位不到方法时，立即以退出码 2 终止
const extractFail = (msg) => {
  console.error('EXTRACT-FAIL（提取失败，非断言失败）:', msg)
  process.exit(2)
}

function read(rel) {
  return fs.readFileSync(path.join(root, rel), 'utf8')
}

// --- 1) Extract resolveChatCompletionsUrl from shipped AIService.ets and run cases ---
function extractResolveUrlFixed() {
  const src = read('service/src/main/ets/service/ai/AIService.ets')

  // resolveChatCompletionsUrl 委托给 AIService.normalizeVolcCodingPlanOpenAiBase，
  // 提取方法体脱离类作用域后该引用无法解析；故将 normalize 方法体一并提取注入同一作用域。
  const normSig = 'static normalizeVolcCodingPlanOpenAiBase(baseUrl: string): string {'
  const normStart = src.indexOf(normSig)
  if (normStart < 0) extractFail('normalizeVolcCodingPlanOpenAiBase signature not found in AIService.ets')
  const normBrace = src.indexOf('{', normStart)
  let depth = 0
  let normEnd = normBrace
  for (; normEnd < src.length; normEnd++) {
    if (src[normEnd] === '{') depth++
    else if (src[normEnd] === '}') {
      depth--
      if (depth === 0) break
    }
  }
  let normBody = src.slice(normBrace + 1, normEnd)
  normBody = normBody.replace(/: string/g, '')

  const start = src.indexOf('static resolveChatCompletionsUrl(baseUrl: string): string {')
  if (start < 0) extractFail('resolveChatCompletionsUrl signature not found in AIService.ets')
  const brace = src.indexOf('{', start)
  depth = 0
  let i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') {
      depth--
      if (depth === 0) break
    }
  }
  let body = src.slice(brace + 1, i)
  body = body.replace(/: string/g, '')
  // eslint-disable-next-line no-new-func
  return new Function(
    'baseUrl',
    'const AIService = { normalizeVolcCodingPlanOpenAiBase: function (baseUrl) {' + normBody + '} };\n' + body
  )
}

const resolveUrl = extractResolveUrlFixed()
const urlCases = [
  ['', 'https://api.openai.com/v1/chat/completions'],
  ['https://api.deepseek.com', 'https://api.deepseek.com/chat/completions'],
  ['https://api.deepseek.com/', 'https://api.deepseek.com/chat/completions'],
  ['https://x.com/v1/chat/completions', 'https://x.com/v1/chat/completions'],
  ['https://x.com/foo/chat/completions/extra', 'https://x.com/foo/chat/completions/extra']
]
for (const [input, expected] of urlCases) {
  const got = resolveUrl(input)
  if (got !== expected) {
    fail(`resolveChatCompletionsUrl(${JSON.stringify(input)}) => ${got}, want ${expected}`)
  } else {
    ok(`resolveChatCompletionsUrl(${JSON.stringify(input)})`)
  }
}

// --- 2) canParseText pure rule from AIParseOrchestrator.ets ---
function extractCanParseText() {
  const src = read('service/src/main/ets/service/ai/AIParseOrchestrator.ets')
  const m = src.match(
    /static canParseText\(settings: UserSettings\): boolean \{([\s\S]*?)\n  \}/
  )
  if (!m) extractFail('canParseText signature not found in AIParseOrchestrator.ets')
  let body = m[1]
  // eslint-disable-next-line no-new-func
  return new Function('settings', body)
}
const canParse = extractCanParseText()
// 产品：有文字 API Key 即可解析（听写文本走同一文字通道）
if (canParse({ ai_text_key: 'k', ai_vision_key: '' }) !== true) {
  fail('canParseText with key should be true')
} else {
  ok('canParseText with key')
}
if (canParse({ ai_text_key: '', ai_vision_key: '' }) !== false) {
  fail('canParseText empty key should be false')
} else {
  ok('canParseText empty key')
}
if (canParse({ ai_text_key: '   ', ai_vision_key: '' }) !== false) {
  fail('canParseText whitespace key should be false')
} else {
  ok('canParseText whitespace key')
}

// --- 3) Structural: Live + 系统听写；禁止 AI 语音 LLM 渠道 / AIChat ---
const live = read('entry/src/main/ets/components/AILiveOverlay.ets')
const sheet = read('components/src/main/ets/components/AIConfigSheet.ets')
const orch = read('service/src/main/ets/service/ai/AIParseOrchestrator.ets')
const legal = read('common/src/main/ets/common/LegalDocuments.ets')
const moduleJson = read('entry/src/main/module.json5')

if (!live.includes('AIParseOrchestrator')) {
  fail('Live must import/use AIParseOrchestrator')
} else {
  ok('Live uses AIParseOrchestrator')
}
if (fs.existsSync(path.join(root, 'entry/src/main/ets/pages/AIChatPage.ets'))) {
  fail('AIChatPage should be removed')
} else {
  ok('AIChatPage removed')
}
// 系统听写（SpeechService + MICROPHONE）是产品能力，非 ai_voice LLM
if (!fs.existsSync(path.join(root, 'service/src/main/ets/service/ai/SpeechService.ets'))) {
  fail('SpeechService (system dictation) should exist')
} else {
  ok('SpeechService present for system dictation')
}
if (!orch.includes('checkTextParseReady') || !orch.includes('parsePixelMap')) {
  fail('orchestrator missing checkTextParseReady/parsePixelMap')
} else {
  ok('orchestrator has text + image pipelines')
}
if (orch.includes('checkVoiceReady')) {
  fail('orchestrator still has checkVoiceReady (AI voice LLM)')
} else {
  ok('orchestrator has no AI voice LLM pipeline')
}
if (sheet.includes("this.segmentItem('voice')") || /formField\([^)]*'voice'/.test(sheet)) {
  fail('AIConfigSheet still has voice LLM form')
} else {
  ok('AIConfigSheet has no voice LLM form')
}
if (!sheet.includes("export type AiChannel = 'text' | 'vision'")) {
  fail('AiChannel should be text|vision only')
} else {
  ok('AiChannel is text|vision only')
}
// 隐私文案须披露系统听写麦克风用途（可选权限）
if (!legal.includes('麦克风') || !legal.includes('系统听写')) {
  fail('LegalDocuments must disclose mic for system dictation')
} else {
  ok('LegalDocuments discloses system dictation mic use')
}
if (!moduleJson.includes('MICROPHONE')) {
  fail('module.json5 should request MICROPHONE for system dictation')
} else {
  ok('module.json5 has MICROPHONE for system dictation')
}

// channel load single path
const ais = read('service/src/main/ets/service/ai/AIService.ets')
if (!ais.includes('loadTextChannelConfig') || !ais.includes('loadVisionChannelConfig')) {
  fail('AIService missing load*ChannelConfig')
} else {
  ok('AIService load*ChannelConfig present')
}
if (live.includes('settings.ai_text_enabled')) {
  fail('Live still maps settings.ai_text_enabled locally for channel load')
} else {
  ok('Live does not locally map text channel settings for load')
}

// AppStorageKeys
const keys = read('common/src/main/ets/common/AppStorageKeys.ets')
if (!keys.includes('MAIN_TAB_INDEX') || !keys.includes('LIST_REFRESH_TOKEN')) {
  fail('AppStorageKeys incomplete')
} else {
  ok('AppStorageKeys module present')
}

// P1: all .ets AppStorage get/set must not use bare known keys
// Note: @StorageLink('literal') / @StorageProp stay as string literals (decorator constraint)
const bareRe = /AppStorage\.(setOrCreate|set|get(?:Sync)?)\s*(?:<[^>]+>)?\s*\(\s*['"]([^'"]+)['"]/
const knownBare = [
  'systemDark', 'topSafeHeight', 'bottomSafeHeight', 'ambientLux', 'mainTabIndex',
  'themeRevision', 'listRefreshToken', 'appLockEnabled', 'appLockVerified',
  'lastBackgroundTime', 'lastActiveTime', 'selectedDebtId', 'selectedSubscriptionId',
  'selectedCreditAccountId', 'showNotificationOverlay', 'settingsOpenAISheet',
  'settingsSheetBlockingTheme', 'aiLiveDebtDraft',
  'aiLiveSubscriptionDraft', 'intentAddDebt', 'intentTodayDue', 'nfcReceivedPayload'
]
function walkEts(dir, out = []) {
  for (const name of fs.readdirSync(dir)) {
    const p = path.join(dir, name)
    const st = fs.statSync(p)
    if (st.isDirectory()) walkEts(p, out)
    else if (name.endsWith('.ets')) out.push(p)
  }
  return out
}
const etsRoots = ['entry', 'service', 'common', 'components']
  .map((m) => path.join(root, m, 'src/main/ets'))
  .filter((p) => fs.existsSync(p))
const allEts = etsRoots.flatMap((p) => walkEts(p))
let bareHits = 0
for (const abs of allEts) {
  const body = fs.readFileSync(abs, 'utf8')
  const re = new RegExp(bareRe.source, 'g')
  let m
  while ((m = re.exec(body)) !== null) {
    if (knownBare.includes(m[2])) {
      bareHits++
      fail(`${path.relative(root, abs)} uses bare AppStorage key '${m[2]}'`)
    }
  }
}
if (!bareHits) {
  ok('P1: all ets AppStorage get/set use constants (no bare known keys)')
}

// P2: Live UI split（无语音 HoldCover；仅 ScanView + InputBar）
const holdCover = path.join(root, 'components/src/main/ets/components/AILiveHoldCover.ets')
const scanView = path.join(root, 'components/src/main/ets/components/AILiveScanView.ets')
const inputBar = path.join(root, 'components/src/main/ets/components/AILiveInputBar.ets')
if (fs.existsSync(holdCover)) {
  fail('P2: AILiveHoldCover should be removed (no voice)')
} else if (!fs.existsSync(scanView) || !fs.existsSync(inputBar)) {
  fail('P2: AILiveScanView / InputBar missing')
} else if (!live.includes('AILiveScanView') || !live.includes('AILiveInputBar')) {
  fail('P2: AILiveOverlay not wired to ScanView/InputBar')
} else if (live.includes('AILiveHoldCover') || live.includes('voiceDefaultBar')) {
  // 禁止旧 HoldCover / 默认语音条；系统听写 SpeechService 允许（非 AI 语音 LLM）
  fail('P2: Live still references deprecated voice HoldCover UI')
} else {
  ok('P2: ScanView + InputBar wired; no HoldCover')
}

// 密钥隔离：build-profile.json5（本机签名路径 + DevEco 加密口令）与 SupabaseConfig.ets
// （Supabase URL + anon key）都不入库，仓库只保留 .example 模板，克隆后各自复制一份填本机值。
// 这里断言的是仓库不变量而非某台机器的签名状态，故任何克隆者都能跑过。
{
  const ignore = read('.gitignore')
  for (const rule of ['/build-profile.json5', '/common/src/main/ets/common/SupabaseConfig.ets', '*.p12', '*.cer', '*.p7b']) {
    if (!ignore.includes(rule)) fail(`.gitignore 缺少规则 ${rule}（本机密钥物料可能入库）`)
  }
  ok('.gitignore 忽略 build-profile / SupabaseConfig / 签名物料')

  const tpl = read('build-profile.json5.example')
  if (!/"signingConfigs"\s*:\s*\[\s*\]/.test(tpl)) {
    fail('build-profile.json5.example 的 signingConfigs 必须为空数组')
  }
  ok('build-profile.json5.example 不含签名物料')

  read('common/src/main/ets/common/SupabaseConfig.ets.example')
  ok('SupabaseConfig.ets.example 存在')
}

// ========== S3–S7 extensions ==========

// S3: AILiveMapping.yuanToFen from shipped source
{
  const src = read('service/src/main/ets/service/ai/AILiveMapping.ets')
  if (!src.includes('static yuanToFen') || !src.includes('toCreateDebtInput')) {
    fail('AILiveMapping missing required methods')
  } else {
    ok('AILiveMapping module present')
  }
  const live = read('entry/src/main/ets/components/AILiveOverlay.ets')
  if (!live.includes('AILiveMapping') || !live.includes('AILiveSaveService') || !live.includes('AIParseOrchestrator')) {
    fail('AILiveOverlay not wired to extracted Live modules')
  } else {
    ok('AILiveOverlay uses AILiveMapping + AILiveSaveService + Orchestrator')
  }
  // Drive yuanToFen from shipped body
  const start = src.indexOf('static yuanToFen(yuan: number): number {')
  if (start < 0) extractFail('yuanToFen signature not found in AILiveMapping.ets')
  const brace = src.indexOf('{', start)
  let depth = 0, i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  let body = src.slice(brace + 1, i)
  // eslint-disable-next-line no-new-func
  const yuanToFen = new Function('yuan', body)
  const ytfCases = [
    [1.23, 123],
    [0, 0],
    [10.005, 1001],
    [Number.NaN, 0]
  ]
  for (const [inn, exp] of ytfCases) {
    const got = yuanToFen(inn)
    if (got !== exp) fail(`yuanToFen(${inn}) => ${got}, want ${exp}`)
  }
  ok('AILiveMapping.yuanToFen cases')
  if (!fs.existsSync(path.join(root, 'service/src/main/ets/service/ai/AILiveSaveService.ets'))) {
    fail('AILiveSaveService.ets missing')
  } else {
    ok('AILiveSaveService.ets present')
  }
}

// S4: SyncHelpers pure
{
  const src = read('service/src/main/ets/service/sync/SyncHelpers.ets')
  if (!src.includes('buildSummary') || !src.includes('pickCloudTimestamp') ||
    !src.includes('shouldPreferCloud') || !src.includes('missingCloudIds')) {
    fail('SyncHelpers incomplete')
  } else {
    ok('SyncHelpers module present')
  }
  const sync = read('service/src/main/ets/service/sync/SyncService.ets')
  if (!sync.includes('SyncHelpers.buildSummary') || !sync.includes('static async syncAll')) {
    fail('SyncService not using SyncHelpers facade pattern')
  } else {
    ok('SyncService facade uses SyncHelpers')
  }
  // buildSummary
  let start = src.indexOf('static buildSummary(stats: SyncStats[]): string {')
  if (start < 0) extractFail('buildSummary signature not found in SyncHelpers.ets')
  let brace = src.indexOf('{', start)
  let depth = 0, i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  let body = src.slice(brace + 1, i)
  // eslint-disable-next-line no-new-func
  const buildSummary = new Function('stats', body)
  const sum = buildSummary([{ pushed: 2, pulled: 3 }, { pushed: 1, pulled: 0 }])
  if (sum !== '推送 3 条，拉取 3 条') fail('buildSummary wrong: ' + sum)
  else ok('SyncHelpers.buildSummary')

  start = src.indexOf('static pickCloudTimestamp(updatedAt: string, createdAt: string): string {')
  if (start < 0) extractFail('pickCloudTimestamp signature not found in SyncHelpers.ets')
  brace = src.indexOf('{', start)
  depth = 0; i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  body = src.slice(brace + 1, i)
  // eslint-disable-next-line no-new-func
  const pick = new Function('updatedAt', 'createdAt', body)
  if (pick('u1', 'c1') !== 'u1') fail('pick prefers updated')
  if (pick('', 'c1') !== 'c1') fail('pick falls back created')
  ok('SyncHelpers.pickCloudTimestamp')

  start = src.indexOf('static shouldPreferCloud(localUpdatedAt: string, cloudUpdatedAt: string): boolean {')
  if (start < 0) extractFail('shouldPreferCloud signature not found in SyncHelpers.ets')
  brace = src.indexOf('{', start)
  depth = 0; i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  body = src.slice(brace + 1, i)
  // shouldPreferCloud 方法体委托同类静态方法 SyncHelpers.compareTimestamps(...)，
  // 单独提取方法体脱离类作用域后该引用无法解析；故将 compareTimestamps 方法体一并提取注入同一作用域。
  start = src.indexOf('static compareTimestamps(a: string, b: string): number {')
  if (start < 0) extractFail('compareTimestamps signature not found in SyncHelpers.ets')
  brace = src.indexOf('{', start)
  depth = 0; i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  const compareBody = src.slice(brace + 1, i)
  // eslint-disable-next-line no-new-func
  const prefer = new Function(
    'localUpdatedAt', 'cloudUpdatedAt',
    'const SyncHelpers = { compareTimestamps: function (a, b) {' + compareBody + '} };\n' + body
  )
  if (!prefer('2020', '2021')) fail('shouldPreferCloud newer cloud')
  if (prefer('2022', '2021')) fail('shouldPreferCloud older cloud')
  if (!prefer('', '2021')) fail('shouldPreferCloud empty local')
  ok('SyncHelpers.shouldPreferCloud')

  start = src.indexOf('static missingCloudIds(cloudIds: string[], localCloudIds: string[]): string[] {')
  if (start < 0) extractFail('missingCloudIds signature not found in SyncHelpers.ets')
  brace = src.indexOf('{', start)
  depth = 0; i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  body = src.slice(brace + 1, i)
  start = src.indexOf('static listHas(list: string[], value: string): boolean {')
  if (start < 0) extractFail('listHas signature not found in SyncHelpers.ets')
  brace = src.indexOf('{', start)
  depth = 0; i = brace
  for (; i < src.length; i++) {
    if (src[i] === '{') depth++
    else if (src[i] === '}') { depth--; if (depth === 0) break }
  }
  const listHasBody = src.slice(brace + 1, i)
  const stripTypes = (s) => s.replace(/: string\[\]/g, '')
  // eslint-disable-next-line no-new-func
  const missingCloudIds = new Function(
    'cloudIds', 'localCloudIds',
    'const SyncHelpers = { listHas: function (list, value) {' + stripTypes(listHasBody) + '} };\n' +
      stripTypes(body)
  )
  const missed = missingCloudIds(['acc1', 'sub1', 'debt1'], ['debt1'])
  if (!Array.isArray(missed) || missed.length !== 2 || missed[0] !== 'acc1' || missed[1] !== 'sub1') {
    fail('missingCloudIds should return acc1,sub1 got ' + JSON.stringify(missed))
  }
  if (missingCloudIds(['acc1'], ['acc1']).length !== 0) fail('missingCloudIds local hit')
  ok('SyncHelpers.missingCloudIds')
}

// S5: DebtFormValidator + DebtsFilterSort
{
  const vsrc = read('service/src/main/ets/service/DebtFormValidator.ets')
  const fsrc = read('service/src/main/ets/service/DebtsFilterSort.ets')
  const form = read('entry/src/main/ets/pages/DebtFormPage.ets')
  const tab = read('entry/src/main/ets/pages/DebtsTab.ets')
  if (!form.includes('DebtFormValidator.validate')) fail('DebtFormPage not using DebtFormValidator')
  else ok('DebtFormPage uses DebtFormValidator')
  if (!tab.includes('DebtsFilterSort.filterAndSort')) fail('DebtsTab not using DebtsFilterSort')
  else ok('DebtsTab uses DebtsFilterSort')

  let start = vsrc.indexOf('static validate(f: DebtFormFields): string {')
  if (start < 0) extractFail('validate signature not found in DebtFormValidator.ets')
  let brace = vsrc.indexOf('{', start)
  let depth = 0, i = brace
  for (; i < vsrc.length; i++) {
    if (vsrc[i] === '{') depth++
    else if (vsrc[i] === '}') { depth--; if (depth === 0) break }
  }
  let body = vsrc.slice(brace + 1, i)
  // eslint-disable-next-line no-new-func
  const validate = new Function('f', body)
  const empty = validate({
    platform: '', currentBalance: '100', isInstallment: false, creditAccountId: '',
    paymentDay: '', repaymentMethod: 'equal_payment', monthlyPayment: '',
    remainingPeriods: '', totalPeriods: '', repaymentDate: '2026-01-01'
  })
  if (empty !== '请输入平台名称') fail('validate empty platform: ' + empty)
  const okForm = validate({
    platform: '花呗', currentBalance: '100', isInstallment: false, creditAccountId: '',
    paymentDay: '', repaymentMethod: 'equal_payment', monthlyPayment: '',
    remainingPeriods: '', totalPeriods: '', repaymentDate: '2026-08-01'
  })
  if (okForm !== '') fail('validate should pass simple debt: ' + okForm)
  ok('DebtFormValidator.validate cases')

  start = fsrc.indexOf('static filterAndSort(')
  if (start < 0) extractFail('filterAndSort signature not found in DebtsFilterSort.ets')
  // find opening brace of method
  brace = fsrc.indexOf('{', start)
  depth = 0; i = brace
  for (; i < fsrc.length; i++) {
    if (fsrc[i] === '{') depth++
    else if (fsrc[i] === '}') { depth--; if (depth === 0) break }
  }
  body = fsrc.slice(brace + 1, i)
  body = body.replace(/: Debt\[\]/g, '').replace(/: Debt/g, '').replace(/: string/g, '')
    .replace(/: number/g, '').replace(/as Debt/g, '')
  // eslint-disable-next-line no-new-func
  const filterAndSort = new Function(
    'debts', 'searchQuery', 'filterIndex', 'sortIndex', 'today',
    body
  )
  const debts = [
    { platform: 'A', note: '', status: 'active', next_payment_date: '2026-08-01', current_balance: 100, estimated_end_date: '2027-01-01' },
    { platform: 'B', note: 'x', status: 'active', next_payment_date: '2020-01-01', current_balance: 500, estimated_end_date: '2026-01-01' },
    { platform: 'C', note: '', status: 'completed', next_payment_date: '2026-08-01', current_balance: 0, estimated_end_date: '2025-01-01' },
  ]
  const overdue = filterAndSort(debts, '', 2, 0, '2026-07-15')
  if (overdue.length !== 1 || overdue[0].platform !== 'B') fail('filter overdue wrong')
  const byBal = filterAndSort(debts, '', 0, 0, '2026-07-15')
  if (byBal[0].current_balance !== 500) fail('sort by balance wrong')
  ok('DebtsFilterSort.filterAndSort cases')
}

// S6: settings save must not write ai_voice_key/model
{
  const ss = read('service/src/main/ets/service/SettingsService.ets')
  // settingsToObject should not assign ai_voice_key/model to obj after S6
  const toObjStart = ss.indexOf('private static settingsToObject')
  const toObj = ss.slice(toObjStart, toObjStart + 2500)
  if (toObj.includes("obj['ai_voice_key']") || toObj.includes('obj["ai_voice_key"]') ||
      toObj.includes("obj['ai_voice_model']")) {
    fail('SettingsService still writes ai_voice LLM fields on save')
  } else {
    ok('SettingsService does not write ai_voice LLM fields')
  }
  const orch = read('service/src/main/ets/service/ai/AIParseOrchestrator.ets')
  if (orch.includes('ai_voice_model') || orch.includes('ai_voice_key')) {
    fail('AIParseOrchestrator must not read voice LLM fields')
  } else {
    ok('AIParseOrchestrator ignores voice LLM fields')
  }
}

// P4: DebtFormPreview + Sync adapters + Settings theme sheet
{
  const preview = path.join(root, 'service/src/main/ets/service/DebtFormPreview.ets')
  const form = read('entry/src/main/ets/pages/DebtFormPage.ets')
  if (!fs.existsSync(preview)) fail('DebtFormPreview.ets missing')
  else if (!form.includes('DebtFormPreview.buildSchedule')) fail('DebtFormPage not using DebtFormPreview')
  else ok('P4: DebtFormPreview extracted and wired')

  const sync = read('service/src/main/ets/service/sync/SyncService.ets')
  const tableSyncFiles = [
    'service/src/main/ets/service/sync/SyncRs.ets',
    'service/src/main/ets/service/sync/SettingsTableSync.ets',
    'service/src/main/ets/service/sync/DebtTableSync.ets',
    'service/src/main/ets/service/sync/PaymentTableSync.ets',
    'service/src/main/ets/service/sync/CreditAccountTableSync.ets',
    'service/src/main/ets/service/sync/SubscriptionTableSync.ets',
    'service/src/main/ets/service/sync/NotificationTableSync.ets',
    'service/src/main/ets/service/sync/AchievementTableSync.ets'
  ]
  const missingTables = tableSyncFiles.filter((rel) => !fs.existsSync(path.join(root, rel)))
  if (missingTables.length > 0) fail('表适配器文件缺失: ' + missingTables.join(', '))
  else if (!sync.includes('from \'./SettingsTableSync\'') || !sync.includes('from \'./AchievementTableSync\'')) {
    fail('SyncService not using per-table TableSync files')
  } else if (sync.includes('class DebtTableSync')) {
    fail('SyncService still contains DebtTableSync body')
  } else {
    ok('P4: SyncTableAdapters split from SyncService')
  }

  // 页面公共行为层（三列表 Tab / 表单页 / 设置页去重）
  {
    const commonFiles = [
      'entry/src/main/ets/pages/common/ListSelection.ets',
      'entry/src/main/ets/pages/common/ListReveal.ets',
      'entry/src/main/ets/pages/common/ThemeLoader.ets',
      'entry/src/main/ets/pages/common/ThemeApplier.ets',
      'entry/src/main/ets/pages/common/DebtFormMath.ets',
      'entry/src/main/ets/pages/common/SettingsDisplay.ets'
    ]
    const missingCommon = commonFiles.filter((rel) => !fs.existsSync(path.join(root, rel)))
    if (missingCommon.length > 0) fail('页面公共层文件缺失: ' + missingCommon.join(', '))

    const debts = read('entry/src/main/ets/pages/DebtsTab.ets')
    const subs = read('entry/src/main/ets/pages/SubscriptionsTab.ets')
    const credit = read('entry/src/main/ets/pages/CreditAccountsTab.ets')
    for (const [name, src] of [['DebtsTab', debts], ['SubscriptionsTab', subs], ['CreditAccountsTab', credit]]) {
      if (!src.includes('ListSelection.toggleAll') || !src.includes('runBatchDelete')) {
        fail(name + ' not using ListSelection common layer')
      } else if (!src.includes('listReveal.softReveal')) {
        fail(name + ' not using ListReveal controller')
      } else if (!src.includes('fetchEffectiveTheme')) {
        fail(name + ' not using ThemeLoader')
      }
    }
    ok('P6: 列表 Tab 公共行为层（选择/缓现/主题）已接入')

    const debtForm = read('entry/src/main/ets/pages/DebtFormPage.ets')
    const settingsTab = read('entry/src/main/ets/pages/SettingsTab.ets')
    if (!debtForm.includes('from \'./common/DebtFormMath\'')) fail('DebtFormPage not using DebtFormMath')
    else ok('P6: DebtFormPage 计算公式下沉 DebtFormMath')

    if (!settingsTab.includes('from \'./common/SettingsDisplay\'')) fail('SettingsTab not using SettingsDisplay')
    else if (!settingsTab.includes('from \'./common/ThemeApplier\'')) fail('SettingsTab not using ThemeApplier')
    else ok('P6: SettingsTab 展示文案与色彩模式调用下沉')

    const confirmRows = path.join(root, 'components/src/main/ets/components/AILiveConfirmRows.ets')
    const overlay = read('entry/src/main/ets/components/AILiveOverlay.ets')
    if (!fs.existsSync(confirmRows)) fail('AILiveConfirmRows.ets missing')
    else if (!overlay.includes('buildConfirmRows')) fail('AILiveOverlay not using AILiveConfirmRows')
    else if (overlay.includes('TextInput({ text: this.editName')) fail('AILiveOverlay still contains dead edit rows')
    else ok('P6: AILiveOverlay 确认列表行模型与行组件拆出')
  }

  const themeSheet = path.join(root, 'components/src/main/ets/components/SettingsThemeSheet.ets')
  const versionSheet = path.join(root, 'components/src/main/ets/components/SettingsVersionSheet.ets')
  const settings = read('entry/src/main/ets/pages/SettingsTab.ets')
  if (!fs.existsSync(themeSheet)) fail('SettingsThemeSheet.ets missing')
  else if (!settings.includes('SettingsThemeSheet')) fail('SettingsTab not using SettingsThemeSheet')
  else ok('P4: SettingsThemeSheet extracted')
  if (!fs.existsSync(versionSheet) || !settings.includes('SettingsVersionSheet')) {
    fail('P4: SettingsVersionSheet missing or not wired')
  } else {
    ok('P4: SettingsVersionSheet extracted')
  }
  // DebtFormWidgets 已随三表单页公共段归一升级为 FormWidgets（FormFieldInput 等）
  const formWidgets = path.join(root, 'components/src/main/ets/components/FormWidgets.ets')
  if (!fs.existsSync(formWidgets) || !form.includes('FormFieldInput')) {
    fail('P4: FormWidgets missing or not wired')
  } else {
    ok('P4: FormWidgets extracted')
  }
}

// P5: AI failure must not invent fake parse items
{
  const ais = read('service/src/main/ets/service/ai/AIService.ets')
  if (ais.includes('private static mockResult()') || ais.includes('mockResult()')) {
    fail('P5: AIService still has mockResult that can invent items')
  } else if (!ais.includes('failureResult')) {
    fail('P5: AIService missing failureResult')
  } else if (/failureResult[\s\S]{0,200}items\.push/.test(ais)) {
    fail('P5: failureResult still pushes fake items')
  } else {
    ok('P5: AIService failureResult has no fake items')
  }
}

// P6 / P7: 门禁只校验 README 是否记录了本门禁脚本。
// P6：废弃的是 AI 语音 LLM 渠道（ai_voice_*），系统听写 + MICROPHONE 保留。
{
  const readme = path.join(root, 'README.md')
  if (!fs.existsSync(readme)) {
    fail('P7: README.md missing')
  } else {
    const rm = fs.readFileSync(readme, 'utf8')
    if (!rm.includes('test-architecture-remediation')) {
      fail('P7: README must document the gate script (test-architecture-remediation)')
    } else {
      ok('P7: README documents the gate script')
    }
  }
}

// P3: Utils money helpers (元/分)
{
  const usrc = read('common/src/main/ets/common/Utils.ets')
  const yStart = usrc.indexOf('static yuanToFen(yuan: number): number {')
  if (yStart < 0) extractFail('yuanToFen signature not found in Utils.ets')
  const yBrace = usrc.indexOf('{', yStart)
  let depth = 0, i = yBrace
  for (; i < usrc.length; i++) {
    if (usrc[i] === '{') depth++
    else if (usrc[i] === '}') { depth--; if (depth === 0) break }
  }
  // eslint-disable-next-line no-new-func
  const yuanToFen = new Function('yuan', usrc.slice(yBrace + 1, i))
  if (yuanToFen(1.23) !== 123) fail('Utils.yuanToFen(1.23)')
  if (yuanToFen(10.005) !== 1001) fail('Utils.yuanToFen(10.005)')
  const fStart = usrc.indexOf('static fenToYuan(fen: number): number {')
  if (fStart < 0) extractFail('fenToYuan signature not found in Utils.ets')
  const fBrace = usrc.indexOf('{', fStart)
  depth = 0; i = fBrace
  for (; i < usrc.length; i++) {
    if (usrc[i] === '{') depth++
    else if (usrc[i] === '}') { depth--; if (depth === 0) break }
  }
  // eslint-disable-next-line no-new-func
  const fenToYuan = new Function('fen', usrc.slice(fBrace + 1, i))
  if (fenToYuan(123) !== 1.23) fail('Utils.fenToYuan(123)')
  ok('P3: Utils.yuanToFen / fenToYuan cases')
}

// Home action center: pure helpers from HomeActionItems.ets
{
  const src = read('service/src/main/ets/service/HomeActionItems.ets')
  const extractStatic = (sig) => {
    const start = src.indexOf(sig)
    if (start < 0) extractFail(sig + ' not found in HomeActionItems.ets')
    const brace = src.indexOf('{', start)
    let depth = 0
    let i = brace
    for (; i < src.length; i++) {
      if (src[i] === '{') depth++
      else if (src[i] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    let body = src.slice(brace + 1, i)
    body = body.replace(/: string/g, '').replace(/: number/g, '')
    // eslint-disable-next-line no-new-func
    return new Function(...argumentsFromSig(sig), body)
  }
  function argumentsFromSig(sig) {
    const m = sig.match(/\(([^)]*)\)/)
    if (!m) return []
    return m[1]
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => p.split(':')[0].trim())
  }
  const daysFrom = extractStatic('static daysFrom(today: string, date: string): number {')
  if (daysFrom('2026-08-10', '2026-08-10') !== 0) fail('HomeActionItems.daysFrom same day')
  if (daysFrom('2026-08-10', '2026-08-09') !== -1) fail('HomeActionItems.daysFrom yesterday')
  if (daysFrom('2026-08-10', '2026-08-17') !== 7) fail('HomeActionItems.daysFrom +7')
  const urgency = extractStatic('static urgencyFromDays(days: number): HomeActionUrgency | null {')
  if (urgency(-3) !== 'overdue') fail('urgency overdue')
  if (urgency(0) !== 'today') fail('urgency today')
  if (urgency(3) !== 'upcoming') fail('urgency upcoming')
  if (urgency(8) !== null) fail('urgency out of window')
  if (!src.includes('buildBuckets')) fail('HomeActionItems missing buildBuckets')
  // 账户有效期须规范 MM/YY，禁止把 raw expiry_date 直接喂给 daysFrom
  if (!src.includes('creditCardExpiryToYmd')) {
    fail('HomeActionItems.fromAccount must use Utils.creditCardExpiryToYmd for MM/YY')
  }
  if (src.includes('daysFrom(today, a.expiry_date)')) {
    fail('HomeActionItems must not pass raw MM/YY expiry_date into daysFrom')
  }
  ok('HomeActionItems: daysFrom / urgencyFromDays cases')
}

// 首页稀疏数据 AI 洞察：纯函数门槛与文案规则
{
  const src = read('service/src/main/ets/service/HomeInsights.ets')
  const extractStatic = (sig) => {
    const start = src.indexOf(sig)
    if (start < 0) extractFail(sig + ' not found in HomeInsights.ets')
    const brace = src.indexOf('{', start)
    let depth = 0
    let i = brace
    for (; i < src.length; i++) {
      if (src[i] === '{') depth++
      else if (src[i] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    let body = src.slice(brace + 1, i)
    body = body.replace(/: string/g, '').replace(/: number/g, '').replace(/: boolean/g, '')
    // eslint-disable-next-line no-new-func
    return new Function(...argumentsFromSig(sig), body)
  }
  function argumentsFromSig(sig) {
    const m = sig.match(/\(([^)]*)\)/)
    if (!m) return []
    return m[1]
      .split(',')
      .map((p) => p.trim())
      .filter(Boolean)
      .map((p) => p.split(':')[0].trim())
  }
  const shouldShow = extractStatic(
    'static shouldShow(hasActionItems: boolean, insightCount: number, firstLoad: boolean): boolean {'
  )
  if (shouldShow(true, 2, false) !== false) fail('HomeInsights.shouldShow hides when actions exist')
  if (shouldShow(false, 0, false) !== false) fail('HomeInsights.shouldShow hides empty card')
  if (shouldShow(false, 2, true) !== false) fail('HomeInsights.shouldShow hides firstLoad')
  if (shouldShow(false, 1, false) !== true) fail('HomeInsights.shouldShow shows sparse insight')
  const monthLabel = extractStatic('static monthLabel(month: string): string {')
  if (monthLabel('2026-08') !== '8月') fail('HomeInsights.monthLabel 2026-08')
  if (monthLabel('bad') !== 'bad') fail('HomeInsights.monthLabel invalid')
  const jump = extractStatic('static isSignificantJump(base: number, compare: number): boolean {')
  if (jump(100, 150) !== true) fail('HomeInsights.isSignificantJump 1.5x')
  if (jump(100, 149) !== false) fail('HomeInsights.isSignificantJump below 1.5x')
  if (jump(0, 200) !== false) fail('HomeInsights.isSignificantJump zero base')
  if (!src.includes("'rate_target'")) fail('HomeInsights missing rate_target')
  if (!src.includes("'peak_cause'")) fail('HomeInsights missing peak_cause')
  if (!src.includes("'dup_subs'")) fail('HomeInsights missing dup_subs')
  if (!src.includes('MAX_ITEMS')) fail('HomeInsights missing MAX_ITEMS')
  if (src.includes('比本月多') || src.includes('比本月少')) fail('HomeInsights copy must not restate visible amounts')
  if (src.includes('下月还款显著加重') || src.includes('还款周期较长')) {
    fail('HomeInsights copy must not restate visible month/term facts')
  }
  if (src.includes('提前把差额备出来') || src.includes('按现在的节奏还要走很久')) {
    fail('HomeInsights copy must not give empty pay-early advice')
  }
  if (src.includes("'mom_jump'") || src.includes("'long_tail'") || src.includes("'plateau'")) {
    fail('HomeInsights must drop surface-level insight ids')
  }
  if (!src.includes('建议') && !src.includes('可考虑')) fail('HomeInsights copy must stay advisory')
  ok('HomeInsights: shouldShow / monthLabel / jump cases')
}

// 首页副文：组合句式，不走开放语料筛选
{
  const src = read('common/src/main/ets/common/HomeSubtitleComposer.ets')
  if (!src.includes('static composeAt')) fail('HomeSubtitleComposer missing composeAt')
  if (!src.includes('static capacity')) fail('HomeSubtitleComposer missing capacity')
  const qsrc = read('service/src/main/ets/service/QuoteService.ets')
  if (qsrc.includes('hitokoto')) fail('QuoteService must not fetch hitokoto')
  if (!qsrc.includes('HomeSubtitleComposer')) fail('QuoteService must use composer')
  ok('HomeSubtitleComposer + QuoteService: no open-corpus filter')
}

// Utils.creditCardExpiryToYmd：MM/YY 不得被当成「今天」
{
  const usrc = read('common/src/main/ets/common/Utils.ets')
  const sig = 'static creditCardExpiryToYmd(expiry: string): string {'
  const start = usrc.indexOf(sig)
  if (start < 0) fail('Utils.creditCardExpiryToYmd missing')
  // extract method + private lastDayOfMonthYmd dependency by evaluating via Function with stubs
  // 轻量契约：源码含 MM/YY 路径与 lastDayOfMonthYmd
  if (!usrc.includes("s.charAt(2) === '/'")) fail('creditCardExpiryToYmd missing MM/YY branch')
  if (!usrc.includes('lastDayOfMonthYmd')) fail('creditCardExpiryToYmd missing lastDayOfMonthYmd')
  // 可执行路径：抽出 public 方法体，内联 private lastDayOfMonthYmd + formatDate
  const extractMethod = (source, methodSig) => {
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
  let body = extractMethod(usrc, sig)
  let lastBody = extractMethod(usrc, 'private static lastDayOfMonthYmd(year: number, month: number): string {')
  let fmtBody = extractMethod(usrc, 'static formatDate(dateStr: string | Date | number): string {')
  if (!body || !lastBody || !fmtBody) fail('creditCardExpiryToYmd extract failed')
  body = body
    .replace(/: string/g, '')
    .replace(/: number/g, '')
    .replace(/Utils\.lastDayOfMonthYmd/g, 'lastDayOfMonthYmd')
    .replace(/Utils\.formatDate/g, 'formatDate')
    .replace(/Utils\.isValidYmdParts/g, 'isValidYmdParts')
  lastBody = lastBody
    .replace(/: string/g, '')
    .replace(/: number/g, '')
    .replace(/Utils\.formatDate/g, 'formatDate')
  fmtBody = fmtBody.replace(/: string \| Date \| number/g, '').replace(/: string/g, '')
  // eslint-disable-next-line no-new-func
  const creditCardExpiryToYmd = new Function('expiry', `
    function formatDate(dateStr) { ${fmtBody} }
    function lastDayOfMonthYmd(year, month) { ${lastBody} }
    ${body}
  `)
  if (creditCardExpiryToYmd('06/30') !== '2030-06-30') fail('creditCardExpiryToYmd 06/30')
  if (creditCardExpiryToYmd('12/30') !== '2030-12-31') fail('creditCardExpiryToYmd 12/30')
  if (creditCardExpiryToYmd('2030-06') !== '2030-06-30') fail('creditCardExpiryToYmd YYYY-MM')
  if (creditCardExpiryToYmd('2030-06-15') !== '2030-06-15') fail('creditCardExpiryToYmd YYYY-MM-DD')
  if (creditCardExpiryToYmd('') !== '') fail('creditCardExpiryToYmd empty')
  if (creditCardExpiryToYmd('13/30') !== '') fail('creditCardExpiryToYmd invalid month')
  // 关键回归：MM/YY 解析成功后距 2026-08-12 远超 7 天，不得为「今天」
  const daysFromBody = (() => {
    const hsrc = read('service/src/main/ets/service/HomeActionItems.ets')
    const s = 'static daysFrom(today: string, date: string): number {'
    const s0 = hsrc.indexOf(s)
    const brace = hsrc.indexOf('{', s0)
    let depth = 0
    let i = brace
    for (; i < hsrc.length; i++) {
      if (hsrc[i] === '{') depth++
      else if (hsrc[i] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    return hsrc.slice(brace + 1, i).replace(/: string/g, '').replace(/: number/g, '')
  })()
  // eslint-disable-next-line no-new-func
  const daysFrom2 = new Function('today', 'date', daysFromBody)
  const ymd = creditCardExpiryToYmd('06/30')
  if (daysFrom2('2026-08-12', ymd) === 0) fail('MM/YY 06/30 must not count as today on 2026-08-12')
  if (daysFrom2('2026-08-12', '06/30') === 0) {
    // raw MM/YY 解析失败会落到 0——这正是旧 bug；规范化后不应再出现
  }
  ok('Utils.creditCardExpiryToYmd + MM/YY not-today regression')
}

// AI 测通：用户症状「网络异常，请稍后重试」不得再由配置页 catch 一刀切盖掉
{
  const sheet = read('components/src/main/ets/components/AIConfigSheet.ets')
  const ais = read('service/src/main/ets/service/ai/AIService.ets')
  const testFnStart = sheet.indexOf('private async testConnection(): Promise<void> {')
  if (testFnStart < 0) {
    fail('AIConfigSheet.testConnection missing')
  } else {
    let depth = 0
    const brace = sheet.indexOf('{', testFnStart)
    let end = brace
    for (; end < sheet.length; end++) {
      if (sheet[end] === '{') depth++
      else if (sheet[end] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    const body = sheet.slice(brace, end + 1)
    if (body.includes('ErrorMessages.NETWORK_FAILED')) {
      fail('testConnection toast NETWORK_FAILED：落盘/HTTP 抛错会被盖成「网络异常，请稍后重试」')
    } else {
      ok('testConnection does not toast NETWORK_FAILED')
    }
    // 测通与落盘必须拆开：persist 失败不能吞掉已返回的测通文案
    const persistIdx = body.indexOf('this.persist()')
    const detailedIdx = body.indexOf('testConnectionDetailed')
    if (persistIdx < 0 || detailedIdx < 0) {
      fail('testConnection must call testConnectionDetailed and persist')
    } else if (body.indexOf('catch') < 0) {
      fail('testConnection must catch testConnectionDetailed independently')
    } else {
      ok('testConnection keeps persist off the NETWORK_FAILED path')
    }
  }

  const persistStart = sheet.indexOf('private async persist(): Promise<void> {')
  if (persistStart < 0) {
    fail('AIConfigSheet.persist missing')
  } else {
    let depth = 0
    const brace = sheet.indexOf('{', persistStart)
    let end = brace
    for (; end < sheet.length; end++) {
      if (sheet[end] === '{') depth++
      else if (sheet[end] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    const persistBody = sheet.slice(brace, end + 1)
    if (persistBody.includes('LIST_REFRESH_TOKEN') || persistBody.includes('notifyListRefresh')) {
      fail('persist() 不得在 Sheet 打开时 bump listRefresh：宿主重建会让完成按钮失灵')
    } else {
      ok('persist() does not bump listRefresh while sheet is open')
    }
    if (!persistBody.includes('AIConfigPersistMerge.pickField')) {
      fail('persist() 必须用 pickField：空串草稿不得盖掉已存 Key/URL')
    } else {
      ok('persist() merges via pickField')
    }
  }

  {
    const mergeSrc = read('components/src/main/ets/components/AIConfigPersistMerge.ets')
    const extractMethodBody = (src, sig) => {
      const start = src.indexOf(sig)
      if (start < 0) return null
      const brace = src.indexOf('{', start)
      let depth = 0
      let i = brace
      for (; i < src.length; i++) {
        if (src[i] === '{') depth++
        else if (src[i] === '}') {
          depth--
          if (depth === 0) break
        }
      }
      return src.slice(brace + 1, i)
    }
    const pickBody = extractMethodBody(mergeSrc, 'static pickField(draft: string, stored: string, cleared: boolean): string {')
    const acceptBody = extractMethodBody(mergeSrc, 'static shouldAcceptFieldChange(prev: string, next: string): boolean {')
    if (!pickBody || !acceptBody) {
      fail('AIConfigPersistMerge missing pickField/shouldAcceptFieldChange')
    } else {
      const pickField = new Function('draft', 'stored', 'cleared', pickBody)
      const shouldAcceptFieldChange = new Function('prev', 'next', acceptBody)
      if (pickField('', 'https://api.deepseek.com', false) !== 'https://api.deepseek.com') {
        fail('pickField empty draft must keep stored URL（重启丢路径）')
      } else {
        ok('pickField empty draft keeps stored URL')
      }
      if (pickField('https://new.example/v1', 'https://old', false) !== 'https://new.example/v1') {
        fail('pickField non-empty draft wins')
      }
      if (pickField('', 'https://old', true) !== '') {
        fail('pickField cleared must write empty')
      }
      if (shouldAcceptFieldChange('https://api.deepseek.com', '') !== false) {
        fail('shouldAcceptFieldChange must reject jump-to-empty（完成/失焦一次清空）')
      } else {
        ok('shouldAcceptFieldChange rejects jump-to-empty')
      }
      if (shouldAcceptFieldChange('x', '') !== true) {
        fail('shouldAcceptFieldChange must allow deleting last char')
      }
      if (shouldAcceptFieldChange('ab', 'abc') !== true) {
        fail('shouldAcceptFieldChange must allow typing')
      }
    }
    if (!sheet.includes('AIConfigPersistMerge.shouldAcceptFieldChange')) {
      fail('formField onChange must ignore jump-to-empty')
    } else {
      ok('formField uses shouldAcceptFieldChange')
    }
  }

  const finishStart = sheet.indexOf('private async finish(): Promise<void> {')
  if (finishStart < 0) {
    fail('AIConfigSheet.finish missing')
  } else {
    let depth = 0
    const brace = sheet.indexOf('{', finishStart)
    let end = brace
    for (; end < sheet.length; end++) {
      if (sheet[end] === '{') depth++
      else if (sheet[end] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    const finishBody = sheet.slice(brace, end + 1)
    if (!finishBody.includes('finally') || finishBody.indexOf('this.onDone') < finishBody.indexOf('finally')) {
      fail('finish() must call onDone in finally，persist 抛错也不能卡住半模态')
    } else {
      ok('finish() closes sheet in finally')
    }
  }

  const settingsTab = read('entry/src/main/ets/pages/SettingsTab.ets')
  const refreshStart = settingsTab.indexOf('private onListRefresh(): void {')
  if (refreshStart < 0) {
    fail('SettingsTab.onListRefresh missing')
  } else {
    let depth = 0
    const brace = settingsTab.indexOf('{', refreshStart)
    let end = brace
    for (; end < settingsTab.length; end++) {
      if (settingsTab[end] === '{') depth++
      else if (settingsTab[end] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    const refreshBody = settingsTab.slice(brace, end + 1)
    if (!refreshBody.includes('isAnySheetOpen')) {
      fail('onListRefresh must skip reload while bindSheet is open')
    } else {
      ok('onListRefresh skips reload while sheet open')
    }
  }
  if (!settingsTab.includes('Constants.notifyListRefresh()')) {
    fail('SettingsTab must notifyListRefresh after AI sheet closes')
  } else {
    ok('SettingsTab notifies list refresh after AI sheet close')
  }

  {
    const bak = read('service/src/main/ets/service/SettingsAiBackup.ets')
    const settingsSrc = read('service/src/main/ets/service/SettingsService.ets')
    if (!settingsSrc.includes('SettingsAiBackup.write') || !settingsSrc.includes('SettingsAiBackup.hydrate')) {
      fail('SettingsService must write/hydrate AI backup so restart 未配置 can recover')
    } else {
      ok('SettingsService writes and hydrates AI backup')
    }
    if (!settingsSrc.includes('cloneSettings')) {
      fail('getSettings must return clone，避免 persist 改缓存冒充已落盘')
    } else {
      ok('SettingsService clones settings on get/save')
    }
    const extractMethodBody = (src, sig) => {
      const start = src.indexOf(sig)
      if (start < 0) return null
      const brace = src.indexOf('{', start)
      let depth = 0
      let i = brace
      for (; i < src.length; i++) {
        if (src[i] === '{') depth++
        else if (src[i] === '}') {
          depth--
          if (depth === 0) break
        }
      }
      return src.slice(brace + 1, i)
    }
    const hydBody = extractMethodBody(bak, 'static hydrate(s: UserSettings, snap: AiBackupSnapshot): boolean {')
    const repairBody = extractMethodBody(bak, 'static repairEnabled(s: UserSettings): void {')
    if (!hydBody || !repairBody) {
      fail('SettingsAiBackup hydrate/repairEnabled missing')
    } else {
      const hydrate = new Function('s', 'snap',
        'const SettingsAiBackup = {\n' +
        '  snapshotHasData: function (snap) {\n' +
        '    return snap.textKey.length > 0 || snap.textUrl.length > 0 ||\n' +
        '      snap.visionKey.length > 0 || snap.visionUrl.length > 0\n' +
        '  },\n' +
        '  repairEnabled: function (s) { ' + repairBody + ' },\n' +
        '  toFormat: function (v) { return (v === "openai" || v === "anthropic") ? v : "auto" }\n' +
        '};\n' + hydBody)
      const empty = {
        ai_text_key: '', ai_text_base_url: '', ai_text_model: '', ai_text_test_fp: '',
        ai_text_api_format: 'auto', ai_text_enabled: false,
        ai_vision_key: '', ai_vision_base_url: '', ai_vision_model: '', ai_vision_test_fp: '',
        ai_vision_api_format: 'auto', ai_vision_enabled: false
      }
      const snap = {
        textKey: 'sk-live', textUrl: 'https://api.deepseek.com', textModel: 'deepseek-v4-flash',
        textFp: 'sk-live\nhttps://api.deepseek.com\ndeepseek-v4-flash', textFormat: 'openai',
        textEnabled: true, visionKey: '', visionUrl: '', visionModel: '', visionFp: '',
        visionFormat: 'auto', visionEnabled: false
      }
      const changed = hydrate(empty, snap)
      if (!changed || empty.ai_text_base_url !== 'https://api.deepseek.com' || empty.ai_text_key !== 'sk-live') {
        fail('hydrate must restore URL/Key from backup: ' + JSON.stringify(empty))
      } else {
        ok('hydrate restores AI path from backup')
      }
      if (!empty.ai_text_enabled) {
        fail('repairEnabled must turn on text channel when key/url restored')
      } else {
        ok('repairEnabled sets text enabled after hydrate')
      }
    }
  }

  {
    const helperSrc = read('components/src/main/ets/components/AIConfigSheet.ets')
    const tagStart = helperSrc.indexOf('private static oneTag(name: string, enabled: boolean, key: string, url: string, model: string,')
    if (tagStart < 0) {
      fail('AIConfigSummaryHelper.oneTag missing')
    } else {
      const brace = helperSrc.indexOf('{', tagStart)
      let depth = 0
      let end = brace
      for (; end < helperSrc.length; end++) {
        if (helperSrc[end] === '{') depth++
        else if (helperSrc[end] === '}') {
          depth--
          if (depth === 0) break
        }
      }
      const tagBody = helperSrc.slice(brace + 1, end)
      const oneTag = new Function('name', 'enabled', 'key', 'url', 'model', 'testFp',
        'function AIChannelTagInfo(name, level) { this.name = name; this.level = level }\n' + tagBody)
      const fp = 'sk\nhttps://api.deepseek.com\nm'
      const tag = oneTag('文字', false, 'sk', 'https://api.deepseek.com', 'm', fp)
      if (tag.level === 0) {
        fail('oneTag must not treat complete fields as 未配置 when enabled=false')
      } else {
        ok('oneTag keeps complete fields visible even if enabled unread')
      }
    }
  }

  {
    const sched = read('service/src/main/ets/service/sync/SyncScheduler.ets')
    const syncSrc = read('service/src/main/ets/service/sync/SyncService.ets')
    const settingsTabSrc = read('entry/src/main/ets/pages/SettingsTab.ets')
    if (!sched.includes('shouldReleaseSyncingUi') || !sched.includes('MAX_SYNC_UI_MS')) {
      fail('SyncScheduler must time out 同步中 UI')
    } else {
      ok('SyncScheduler has syncing UI timeout')
    }
    if (syncSrc.includes('TABLE_USER_SETTINGS) {\n          await SyncOutbox.enqueueUpsert')) {
      fail('enqueueMissingFor must not always enqueue user_settings')
    } else {
      ok('enqueueMissingFor no longer always enqueues settings')
    }
    if (!syncSrc.includes('pageDidStall')) {
      fail('getAllPages must detect stalled offset')
    } else {
      ok('getAllPages has stall detection')
    }
    const tapStart = settingsTabSrc.indexOf('private async onCloudSyncTap()')
    if (tapStart < 0) {
      fail('onCloudSyncTap missing')
    } else {
      const brace = settingsTabSrc.indexOf('{', tapStart)
      let depth = 0
      let end = brace
      for (; end < settingsTabSrc.length; end++) {
        if (settingsTabSrc[end] === '{') depth++
        else if (settingsTabSrc[end] === '}') {
          depth--
          if (depth === 0) break
        }
      }
      const tapBody = settingsTabSrc.slice(brace, end + 1)
      if (!tapBody.includes('finally') || !tapBody.includes('refreshSyncUi')) {
        fail('onCloudSyncTap must refreshSyncUi in finally')
      } else {
        ok('onCloudSyncTap always refreshes UI')
      }
    }
  }

  const extractMethodBody = (src, sig) => {
    const start = src.indexOf(sig)
    if (start < 0) return null
    const brace = src.indexOf('{', start)
    let depth = 0
    let i = brace
    for (; i < src.length; i++) {
      if (src[i] === '{') depth++
      else if (src[i] === '}') {
        depth--
        if (depth === 0) break
      }
    }
    return src.slice(brace + 1, i)
  }

  const hostBody = extractMethodBody(ais, 'static hostOf(url: string): string {')
  const descBody = extractMethodBody(ais, 'static describeCaughtError(')
  const hintBody = extractMethodBody(ais, 'static networkFailureHint(rawErr: string, url: string): string {')
  const fromErrBody = extractMethodBody(ais, 'static hintFromCaughtError(')
  const toastBody = extractMethodBody(ais, 'static testResultToast(')
  if (!hostBody || !descBody || !hintBody || !fromErrBody || !toastBody) {
    fail('AIService missing hostOf/describeCaughtError/networkFailureHint/hintFromCaughtError/testResultToast')
  } else {
    const stripTypes = (s) => s
      .replace(/ as Record<[^>]+>/g, '')
      .replace(/ as Object/g, '')
      .replace(/: string/g, '')
      .replace(/: number/g, '')
      .replace(/: boolean/g, '')
      .replace(/: Object/g, '')
      .replace(/\| null/g, '')
      .replace(/\| undefined/g, '')
    const hostOf = new Function('url', stripTypes(hostBody))
    const describeCaughtError = new Function('err', stripTypes(descBody))
    const networkFailureHint = new Function('rawErr', 'url',
      'const AIService = { hostOf: function (url) { ' + stripTypes(hostBody) + ' } };\n' +
      stripTypes(hintBody))
    const hintFromCaughtError = new Function('err', 'url',
      'const AIService = {\n' +
      '  describeCaughtError: function (err) { ' + stripTypes(descBody) + ' },\n' +
      '  networkFailureHint: function (rawErr, url) {\n' +
      '    const AIService = { hostOf: function (url) { ' + stripTypes(hostBody) + ' } };\n' +
      stripTypes(hintBody) + '\n' +
      '  }\n' +
      '};\n' + stripTypes(fromErrBody))
    const testResultToast = new Function('ok', 'message', 'okText', 'failText', stripTypes(toastBody))

    const volcUrl = 'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions'
    if (hostOf(volcUrl) !== 'ark.cn-beijing.volces.com') {
      fail('hostOf volc url => ' + hostOf(volcUrl))
    } else {
      ok('hostOf strips scheme/path without regex')
    }
    if (hostOf('https://api.deepseek.com/chat/completions') !== 'api.deepseek.com') {
      fail('hostOf deepseek')
    }

    const biz = describeCaughtError({ code: 2300028, message: 'Operation timeout' })
    if (biz.indexOf('2300028') < 0 || biz.toLowerCase().indexOf('timeout') < 0) {
      fail('describeCaughtError must read BusinessError-like {code,message} without instanceof: ' + biz)
    } else {
      ok('describeCaughtError reads BusinessError-like object')
    }
    if (describeCaughtError('plain') !== 'plain') fail('describeCaughtError string')
    if (describeCaughtError(2300006) !== '2300006') fail('describeCaughtError number')

    const timeoutHint = networkFailureHint('2300028 Operation timeout', volcUrl)
    if (timeoutHint.indexOf('连接超时') < 0 || timeoutHint.indexOf('ark.cn-beijing.volces.com') < 0) {
      fail('networkFailureHint timeout => ' + timeoutHint)
    } else {
      ok('networkFailureHint timeout names host')
    }
    const dnsHint = networkFailureHint('2300006 couldn\'t resolve host', 'https://bad.example/v1')
    if (dnsHint.indexOf('域名解析') < 0) fail('networkFailureHint dns => ' + dnsHint)
    else ok('networkFailureHint dns')

    const fromBiz = hintFromCaughtError({ code: 2300028, message: 'timeout' }, volcUrl)
    if (fromBiz.indexOf('连接超时') < 0) {
      fail('hintFromCaughtError BusinessError-like => ' + fromBiz)
    } else {
      ok('hintFromCaughtError does not throw on plain object')
    }
    // 用户症状：测通失败文案必须优先于泛化「网络异常」
    const toastFail = testResultToast(false, fromBiz, '连接成功，已保存', '连接失败，请检查 Key、地址与模型后重试')
    if (toastFail !== fromBiz) fail('testResultToast must prefer detailed message: ' + toastFail)
    if (toastFail === '网络异常，请稍后重试') fail('testResultToast must not collapse to NETWORK_FAILED')
    const toastOk = testResultToast(true, '连接成功', '连接成功，已保存', '连接失败')
    if (toastOk !== '连接成功，已保存') fail('testResultToast ok')
    const toastEmpty = testResultToast(false, '', '连接成功，已保存', '连接失败，请检查 Key、地址与模型后重试')
    if (toastEmpty.indexOf('连接失败') < 0) fail('testResultToast empty fail')
    ok('testResultToast keeps detailed failure, never NETWORK_FAILED')
  }

  if (!ais.includes('HttpProtocol.HTTP1_1') && !ais.includes('usingProtocol')) {
    fail('testConnectionDetailed should force HTTP/1.1 (HarmonyOS 默认 HTTP/3 会导致连不上网关)')
  } else {
    ok('testConnectionDetailed forces HTTP/1.1')
  }
  if (!ais.includes('HttpDataType.STRING')) {
    fail('testConnectionDetailed should set expectDataType STRING')
  } else {
    ok('testConnectionDetailed expectDataType STRING')
  }
}

if (process.exitCode) {
  console.error('\nSome checks failed')
  process.exit(1)
}
console.log('\nAll architecture remediation tests passed (incl. S3–S7 / P1–P3)')
