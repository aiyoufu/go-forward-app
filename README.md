# 向前（GoForward）

个人财富与秩序规划平台 —— 管好负债、理清订阅、规划还款，笃定向前。

HarmonyOS NEXT 原生客户端（ArkTS，1 HAP + 3 HAR）。必须注册登录后使用，业务数据按账号同步至 Supabase 云端，与桌面端共用同一份数据。

## 同一个项目的两个端

「向前」是一套产品的两个客户端，共用同一个 Supabase 后端：

| 端 | 仓库 | 技术栈 |
|----|------|--------|
| HarmonyOS（本仓库） | `aiyoufu/go-forward-app` | ArkTS / HarmonyOS NEXT |
| 桌面端 | [`aiyoufu/go-forward-desktop`](https://github.com/aiyoufu/go-forward-desktop.git) | Next.js 15 / Tauri 2.x |

两端各自独立构建发布，账号与数据通过 Supabase 打通。

**建库脚本只在桌面端仓库**：[`go-forward-desktop/supabase/migrations/`](https://github.com/aiyoufu/go-forward-desktop/tree/main/supabase/migrations) 是两端共用的唯一真相，本仓库不含任何 SQL。

两处加密字段（AI API Key、卡片 CVV）由两端**逐字节互通**地加解密，改任一端都会让另一端解不开既有数据，详见[字段级加密](#字段级加密与桌面端逐字节互通)。

## 功能

- **负债管理**：分期 / 信用卡 / 贷款，三种还款方式 —— 等额本息、等本等息、自定义还款表（`RepaymentMethod`）
- **还款计划**：自动生成还款时间表，一键标记本期已还、提前一次性结清
- **信用账户**：账单日 / 还款日 / 额度 / 年费刷卡次数 / 免息期管理
- **订阅管理**：六种计费周期（周 / 双周 / 月 / 季 / 半年 / 年），月度支出测算与续费提醒
- **首页看板**：本月待还主舞台、未来资金压力趋势、需要关注事项
- **AI 录入**：自然语言、系统听写、拍照 / 相册 OCR 解析成负债字段；未配 Key 时可纯手动录入
- **外币折算**：录入时按汇率折算成 CNY（`ExchangeRateService`）
- **到期提醒**：本地通知 + `workScheduler` 后台补发
- **服务卡片**：5 张桌面卡片（本月待还 / 还款节奏 / 待还概览 / 订阅 / 待还·还款节奏）
- **实况窗**：锁屏实况窗展示待还信息
- **意图框架**：8 个 Insight Intent，可从系统入口直达查负债、记一笔、标记已还、查压力等
- **应用锁**：PIN 码 + 超时自动锁屏
- **防窥**：检测到旁人注视时自动脱敏金额
- **碰一碰**：NFC 面对面传输记录摘要
- **数据备份**：CSV / JSON 导入导出；接入系统备份恢复（`EntryBackupAbility`）

### AI 录入的三层心智

- **文字解析**：必选底座 —— 键盘输入、系统听写转写文本、OCR 识别文本最终都汇到这一层
- **图片视觉**：可选增强 —— 拍照 / 相册，本地未识别到文字时回退到图片理解
- **入口**：MiniBar 智能入口 + 胶囊条（拍照 · 相册 · 文字 · 系统听写）

## 数据存储

- **账号与同步**：必须登录使用。业务数据按 `user_id` 存于 Supabase，设备沙箱的关系型数据库（`relationalStore`，`SecurityLevel.S3`）仅作本地缓存。`local_users` / `sync_queue` / `sync_state` 是纯本地表，不上云。
- **云端同步**：注册登录后，负债、订阅、账户、还款流水等按 `user_id` 同步至 Supabase，支持跨设备访问。
- **不是端到端加密**：业务字段（金额、名称、日期）在云端为**明文存储**，保密性依赖 HTTPS/TLS 传输加密与行级安全策略（RLS）的账号隔离。应用锁是客户端界面锁，不构成数据加密；它只锁应用内界面，**桌面服务卡片与锁屏实况窗由系统渲染，不经应用锁、也不脱敏金额**，介意的人应移除卡片。只有凭证类字段另有客户端加密，见下。完整表述见应用内隐私政策与用户协议（`common/src/main/ets/common/LegalDocuments.ets`）与 [`SECURITY.md`](SECURITY.md)。

### 字段级加密（与桌面端逐字节互通）

`service/src/main/ets/service/auth/E2EEService.ets` 只加密「可重新录入」的凭证列，AES-256-GCM，密文前缀 `enc:v1:`：

| 表 | 列 | 去向 |
|----|----|------|
| `user_settings` | `ai_text_key`、`ai_vision_key` | **只在本机**：加密后写本地库，`SettingsTableSync.toCloud` 的白名单不含这两列，永不出站 |
| `credit_accounts` | `cvv` | 加密后随账户同步上云；明文 CVV 被 `CreditAccountTableSync` 拦在出站前 |

密钥模型：随机 DEK 加密字段值，DEK 由登录密码经 PBKDF2（600 000 轮、SHA-256）派生的 KEK 包裹后存 `user_settings.enc_dek_wrapped` / `enc_dek_salt`，本机把 DEK 缓存在 Asset Store Kit 关键资产里（`auth/DekManager.ets`、`auth/SecureStore.ets`）。密钥丢失（邮件重置密码且本机无缓存）时只需重新录入凭证，没有恢复码流程。

DEK 不可用时 `encryptField` 会回退明文**暂存本机**以便继续录入，此时出站拦截是唯一防线 —— 上表「去向」列就是这道防线的落点。这条不变量的完整表述见 [`SECURITY.md`](SECURITY.md)。

> ⚠️ 桌面端用**完全相同的参数**加解密同一份数据（`lib/crypto.ts`）。迭代轮数、盐 / IV 长度、`enc:v1` 格式、加密列清单，改任一端都会让另一端解不开既有数据，**两端必须同步改**。注意桌面端会把 AI Key 同步上云、本端不会，所以云端 `user_settings` 的这两列只有桌面端写入。

## 克隆后必做：复制两个本机配置

本机签名物料与 Supabase 凭据**都不入库**（见 `.gitignore`），仓库只提供模板。克隆后先复制两份，否则无法构建 / 登录：

```bash
cp build-profile.json5.example build-profile.json5
cp common/src/main/ets/common/SupabaseConfig.ets.example \
   common/src/main/ets/common/SupabaseConfig.ets
```

- `build-profile.json5` → 见[本机签名](#本机签名deveco)，签名段留空由 DevEco 自动写入。
- `SupabaseConfig.ets` → 见[自备后端](#自备后端supabase)，填自己 Supabase 项目的 URL 与 anon key。

## 开发

### 环境要求

- DevEco Studio（HarmonyOS NEXT）
- HarmonyOS SDK `6.1.1(24)`（`targetSdkVersion` 与 `compatibleSdkVersion` 同值，见 `build-profile.json5.example`）
- Node.js 20+（仅本地门禁脚本需要，不参与应用构建）
- 真机或模拟器（Hypium 仪器测试与构建均需设备）

包管理用 **oh-package**（清单 `oh-package.json5`），不是 npm。请勿切换包管理器或重新生成 `oh-package-lock.json5`。

### 构建与运行

用 DevEco Studio 打开仓库根目录，等 oh-package 依赖装完，先按上面复制两份本机配置，再：

1. **File → Project Structure → Signing Configs** 勾选 *Automatically generate signature*
2. 选设备，Run `entry`

命令行构建走 hvigor（`hvigorw assembleHap`），同样依赖本机签名配置。

### 本机签名（DevEco）

`build-profile.json5` **不入库**（已 gitignore），仓库只有 `build-profile.json5.example`。复制一份后：

DevEco → **File → Project Structure → Signing Configs** → 勾选 **Automatically generate signature**。
DevEco 会把本机的证书路径与加密口令写进你本地的 `build-profile.json5`，物料在 `~/.ohos/config/`。模板里的 `"signingConfigs": []` 留空即可，不要手填。

- 出现 SignHap **00303242**（`Signature material verification failed` / 口令与材料不匹配）：
  1. 按上面路径重新「自动签名」生成物料；或
  2. 确认 `build-profile` 的 `certpath` / `storeFile` / `profile` 指向**当前** `~/.ohos/config/default_go-forward_*.{cer,p12,p7b}`，且口令为 DevEco 写入的加密串（勿手改）。
- 真机分发再按华为开发者后台流程替换为发布签名；`*.p12` / `*.cer` / `*.p7b` 与 `signature/`、`signing/` 目录均已 gitignore，**任何情况下都不要提交签名私钥**。
- **不要用 `git update-index --skip-worktree build-profile.json5`**。该位会隐藏工作区与索引的漂移（DevEco 重新生成口令后你看不见），并让后续的 `git rm --cached` 以 "outside of your sparse-checkout definition" 报错失败。现在文件根本不入库，不需要这个技巧。

### 门禁与测试

```bash
# 推荐：本地冒烟一键（白盒 + 架构 + UI 门禁 + 模块覆盖率≥99%）
node scripts/run-all-smoke.mjs

# 分项
node scripts/test-core-whitebox.mjs
node scripts/test-architecture-remediation.mjs
node scripts/check-typescale-mainpath.mjs
node scripts/check-ui-craft.mjs
node scripts/test-module-coverage.mjs
```

要求：**冒烟全绿**后再合入涉及 AI / 同步 / AppStorage / 性能路径的改动。改页面、组件、卡片的 `.ets` 必跑 `check-ui-craft.mjs`；动到主路径 Tab 或核心卡片另跑 `check-typescale-mainpath.mjs`。

**Hypium 单元 / E2E（`*/src/ohosTest`）需真机**，本机 smoke 不执行仪器测试：

```bash
# 真机四模块（entry / common / service / components）
# macOS / Git Bash
scripts/run-device-ohos-test.sh
# Windows
pwsh -File scripts/run-device-ohos-test.ps1
```

> 耦合约束：`test-architecture-remediation.mjs` 与 `.ets` 源码文本格式强耦合（按方法签名字符串定位 + 花括号配平提取方法体执行）。重构其覆盖方法的签名（改名、参数、类型标注、签名换行格式）时，须同步更新脚本内的提取模式。脚本以 `EXTRACT-FAIL`（退出码 2，提取失败）区分于 `FAIL`（退出码 1，断言失败）。

仓库内置 `.githooks/pre-push` 钩子，推送前按序执行门禁，任一失败即阻断推送。克隆后执行一次以启用：

```bash
git config core.hooksPath .githooks
# Unix / macOS / Git Bash：确保可执行
chmod +x .githooks/pre-push
```

## 自备后端（Supabase）

`common/src/main/ets/common/SupabaseConfig.ets` 只有两个字段（取值位置：控制台 → Project Settings → API）：

- `URL` — 项目 API 根，形如 `https://<project-ref>.supabase.co`
- `ANON_KEY` — `anon` / `public` 密钥。它按 Supabase 设计就是公开的，安全性靠 RLS 兜底。

**不要用 `service_role` 密钥**。那是绕过 RLS 的服务端凭据，写进客户端等于把整个库敞开。

留空也能构建运行，登录页会提示「请先配置 Supabase URL 和 ANON_KEY」。登录方式为 Supabase GoTrue 的**邮箱 + 密码**（注册 / 登录 / 刷新 / 找回密码 / 改资料），需在后台开启 Email provider；本端不含任何第三方 OAuth 登录。

### 建库：跑桌面端仓库的迁移

本仓库不含 SQL，建库脚本在桌面端仓库：[`go-forward-desktop/supabase/migrations/`](https://github.com/aiyoufu/go-forward-desktop/tree/main/supabase/migrations)（48 个迁移，`001_initial_schema.sql` → `048_credit_accounts_interest_free.sql`）。按序在自己项目里跑完，GoForward 需要的 7 张同步表、3 个图标 bucket 与 RLS 策略就都有了。

迁移**没有**覆盖两处，需手动补：

1. **`app_releases`** —— GoForward 的「新版本」页读这张表，但桌面端只有 `app_versions`（`022_app_versions.sql`），那是给桌面端更新器用的，列为 `version` / `notes` / `pub_date` / `download_url`，与本端要的结构化字段完全不同。缺表不会崩，`AppVersionService` 拿不到 200 就返回 `null`，只是版本检查静默失效。
2. **Realtime publication** —— 迁移里没有任何 `alter publication` 语句，7 张同步表要在控制台 Database → Replication 手动加进 `supabase_realtime`。不加也能用，`SyncRealtime` 连不上会静默降级为轮询。

另外，桌面端仓库的 `006` / `030` 里的 pg_cron 每日提醒任务带占位符（`YOUR_PROJECT_REF`、`YOUR_SERVICE_ROLE_KEY`），跑完迁移不会自动生效；`031` / `039` 含 `TRUNCATE`，全新库按序跑无碍，**绝不可对已有数据的库重跑**。细节见桌面端仓库 README 的「公测运维注意」。

下面这张接口面清单按本仓库 `service/` 的实际调用整理（不是设计文档），用来核对迁移跑完后是否对得上：

**PostgREST — `<URL>/rest/v1/<table>`**（`SupabaseRestService.ets`）

请求头 `apikey: <ANON_KEY>` + `Authorization: Bearer <access_token>`；upsert 带 `Prefer: resolution=merge-duplicates,return=representation`。

| 表 | 用途 | 客户端 |
|----|------|--------|
| `debts` | 负债 | `sync/DebtTableSync.ets` |
| `credit_accounts` | 信用账户 | `sync/CreditAccountTableSync.ets` |
| `subscriptions` | 订阅 | `sync/SubscriptionTableSync.ets` |
| `payment_records` | 还款记录 | `sync/PaymentTableSync.ets` |
| `notifications` | 提醒 | `sync/NotificationTableSync.ets` |
| `achievement_cards` | 成就卡 | `sync/AchievementTableSync.ets` |
| `user_settings` | 设置 + 包裹后的 DEK | `sync/SettingsTableSync.ets`、`auth/DekManager.ets` |
| `app_releases` | 版本更新检查 | `AppVersionService.ets` |

前 7 张表**必须有 `user_id` 列**：同步按 `user_id=eq.<uid>` 拉取与推送（`SyncService.syncTable`），Realtime 也用同一 filter 订阅。`app_releases` 例外，它用空 token 查询（`SupabaseRestService.get('', …)`），所以要给 anon 角色开 select 策略，列见 `AppVersionService.fetchRemoteReleaseInfo`（`version_name` / `version_code` / `release_date` / `features` / `release_notes`）。

`local_users` / `sync_queue` / `sync_state` 虽然也在 `Constants.TABLE_*` 里，但它们是**本地 SQLite**，不上云，不要建到 Supabase。

**Auth（GoTrue）**（`auth/SupabaseAuthService.ets`）

邮箱口令注册登录：`POST /auth/v1/signup`、`POST /auth/v1/token?grant_type=password`、`POST /auth/v1/token?grant_type=refresh_token`、`POST /auth/v1/recover`、`POST /auth/v1/verify`、`GET|PUT /auth/v1/user`。

**Storage**（`platform/IconCloudService.ets`）

三个 bucket，公开读、登录写。读走 `/storage/v1/object/public/<bucket>/<path>`，写走 `/storage/v1/object/<bucket>/<path>`：

| bucket | 对应表 |
|--------|--------|
| `debt-icons` | `debts` |
| `credit-account-icons` | `credit_accounts` |
| `subscription-icons` | `subscriptions` |

**Realtime**（`sync/SyncRealtime.ets`）

`wss://<URL>/realtime/v1/websocket?apikey=<ANON_KEY>&vsn=1.0.0`，Phoenix 协议手写实现（ArkTS 无官方 SDK）。对上述 7 张表发 `postgres_changes`（`event: '*'`、`schema: 'public'`、`filter: 'user_id=eq.<uid>'`），所以这 7 张表要加进 Realtime publication。连不上会静默降级为轮询，不影响正确性。

## 技术栈

- **语言 / UI**：ArkTS + ArkUI 声明式（`@Component struct`），HarmonyOS NEXT
- **工程结构**：1 HAP（`entry`）+ 3 HAR（`common` / `service` / `components`），oh-package 管理依赖
- **本地存储**：`@kit.ArkData` relationalStore（RDB，`SecurityLevel.S3`）+ Preferences
- **云端后端**：Supabase（PostgreSQL + GoTrue Auth + Storage + Realtime），PostgREST / WebSocket 均为手写调用，无第三方 SDK
- **设备能力**：服务卡片（Form）、实况窗（liveViewLockScreen）、意图框架（Insight Intent）、后台任务（workScheduler）、NFC、系统听写、OCR、防窥（DLP）
- **加密**：`@kit.CryptoArchitectureKit` AES-256-GCM + PBKDF2；令牌存安全存储

## 项目结构

```
common/           # HAR：主题与设计令牌、常量、工具、数据模型（common + model）
service/          # HAR：业务服务、同步 facade + adapters、AI Orchestrator（依赖 common）
  src/main/ets/service/
    ai/           # AIParseOrchestrator / OcrService / SpeechService / Bill*Parser
    auth/         # AuthManager / SupabaseAuthService / E2EEService / DekManager / SecureStore
    platform/     # IconCloudService / IconPickerService / NFCShareService / PlatformService
    sync/         # SyncService / SyncRealtime / SyncScheduler / *TableSync
components/       # HAR：AI Live 拆分组件、设置 Sheet、表单控件、卡片等 40 个组件
entry/src/main/ets/
  pages/          # 5 个 Tab 与表单页、登录注册、应用锁、导入导出、法务文本
  widget/         # 5 张服务卡片（卡片容器不支持跨 HAR 导入，字号令牌见 widget/pages/WidgetTypeScale.ets 本地副本）
  liveview/       # 锁屏实况窗
  insightintents/ # 8 个意图执行器
  reminder/       # workScheduler 后台提醒
scripts/          # 本地门禁：run-all-smoke + whitebox / architecture / craft / typescale / module-coverage
```

依赖方向：`common ← service ← components ← entry`。跨模块导入一律用包名（`import { X } from 'common'`），新增导出需同步各模块的 `Index.ets` 门面 —— 门面导出了未声明的符号、或引用方导入门面没导出的名字，都会直接编译失败。

## 设计语言

「向前」采用 Cursor 化 v9 视觉语言：表面抬升、小圆角面板（上限 12vp）、弱边框、中文主叙述、mono 仅用于金额 / 日期 / 编号。

设计令牌实现在 `common/src/main/ets/common/` 下的 `ThemeManager.ets`（色板 / 圆角 / 间距 / 阴影）、`TypeScale.ets`（字阶）、`MotionTokens.ets`（动效时长与位移），这三个文件就是视觉语言的唯一真相。改完跑 `node scripts/check-ui-craft.mjs` 与 `node scripts/check-typescale-mainpath.mjs` 校验。

## 第三方素材与免责声明

应用内置了一批金融机构图标（`entry/src/main/resources/rawfile/credit_logos/`，23 个），用于在列表里快速认出账户。这些图标**只用于识别，本应用与任何机构均无关联、无背书**；图标选择面板底部也有同样的常驻提示。

完整清单、许可状态与运行时第三方数据源见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。权利人若认为收录不当，按该文件「五、联系方式」说明即会删除。仓库的开源许可证只覆盖自有代码，**不对这些图标再授权**。

信用账户的图标只能从内置图标或相册选取；早前版本从第三方仓库检索银行卡卡面图的链路已整体移除，理由记录在 `THIRD_PARTY_NOTICES.md` 第二节。

本仓库不打包字体等其它第三方素材。

## 设备手测（摘要）

自动化门禁覆盖不到真机行为，上架前最少手工过一遍：

1. 全新安装 → 引导勾选协议 → 注册登录 → 主页（MiniBar 说明后打开录入）；设置可再读隐私 / 协议
2. 空态标题「暂无记录 / 暂无负债 / 暂无订阅 / 暂无账户」，hint 为空（禁止说明书式「右下角 +…」）；不配 AI 仍可手动录入
3. AI Live：文字 / 系统听写 / 拍照 / 相册；听写依赖同一「文字解析」；未配 Key 无假入库
4. 导入 JSON 补充不重复；Toast 在顶部
5. 设置：主题、应用锁、云端同步状态（点击手动同步）、意见反馈（不展示邮箱）
6. 服务卡片与实况窗在锁屏 / 桌面的数据刷新；防窥在旁人注视时脱敏生效

## 文档

| 文档 | 说明 |
|------|------|
| [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) | 内置图标清单、运行时第三方数据源与许可状态、权利人异议通道 |
| [`SECURITY.md`](SECURITY.md) | 安全问题私下披露通道与本项目的安全边界 |
| [`LICENSE`](LICENSE) | 自有代码的开源许可证（不含第三方图标） |

## 许可证

自有代码见 [`LICENSE`](LICENSE)（MIT）。

例外：`entry/src/main/resources/rawfile/credit_logos/` 下的第三方金融机构图标**不受 MIT 覆盖**，仅作识别用途、不再授权，详见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md)。
