# 第三方素材与声明

本文件说明「向前」仓库内**随代码分发的第三方素材**（如有），以及 App **运行时向第三方拉取的图源/数据源**。

一句话立场：本项目是个人记账工具，不隶属于、不受赞助于、不背书于任何金融机构；所有机构名称与图标仅用于帮助用户识别自己的账户。

---

## 一、内置图标（随仓库分发）

**当前状态：本节对应内容已从仓库整体移除。**

2026-09 之前，本仓库曾在 `entry/src/main/resources/rawfile/credit_logos/` 下打包 23 个金融机构 PNG 图标，用于在离线场景下「先出本地图、慢网也能识别」。基于以下考量，该目录与配套的 `PlatformService.CREDIT_LOGO_FILES` / `getLocalCreditLogoUrl()` / `IconPickerService.resolveRawfileIcon()` 已整体清理：

- 权利瑕疵只能在仓库层消除，不能用一段声明抵消——一旦收录就已经构成了可被主张的「未经授权的复制/分发」。
- 离线命中只解决弱网识别问题，运行时已有 favicon 兜底（见第二节），删除后体验损失很小。
- 权利人若发现新的误收录，按本文件「五、联系方式」告知会在无不正当拖延内处理。

**删除后的降级行为**（因此下架成本很低，不必担心「删了 App 就跑不起来」）：

- 名称命中的预设（花呗、京东白条、Netflix …）走 `PlatformService.getLogoUrlForName()` 拼接 `https://statics.dnspod.cn/proxy_favicon/_/favicon?domain=<preset.domain>`，由运行时按域名拉取站点 favicon。
- 任何名称都不再指向 `$rawfile:credit_logos/*.png`；旧数据库行重新解析时，Image 加载会失败并触发 `onError`，UI 退到 `getBrandVisual()` 的**品牌色 + 文字字标**，不会崩、不会留白框。
- 用户已存下的相册图 / 已上云的卡面图与本次清理无关，渲染链路未变。

---

## 二、运行时第三方数据源（不随仓库分发）

App 运行时按需向下列服务发起网络请求，图片/数据**不打包进仓库**，只缓存在用户设备本地。

| 来源 | 用途 | 代码位置 | 授权状态 |
|------|------|----------|----------|
| iTunes Search API<br>`itunes.apple.com` | 按名称检索 App 图标 | `IconPickerService.ets` | Apple 公开检索接口，图标版权归各开发者 |
| Simple Icons CDN<br>`cdn.simpleicons.org` | 品牌图标兜底 | `IconPickerService.ets` | 图标数据 CC0-1.0；但 depicted 商标仍属各权利人 |
| DuckDuckGo Icons<br>`icons.duckduckgo.com` | 域名图标兜底 | `IconPickerService.ets` | 第三方公开图标服务 |
| `favicon.im` | 域名 favicon 兜底 | `IconPickerService.ets` | 第三方公开服务 |
| Google Favicon<br>`www.google.com/s2/favicons` | 域名 favicon 兜底 | `IconPickerService.ets` | Google 公开服务 |
| DNSPod HTTPDNS<br>`statics.dnspod.cn` | 域名 favicon + HTTP DNS 解析（改善弱网连通性） | `IconPickerService.ets`、`PlatformService.ets` | 腾讯公开服务 |
| `open.er-api.com` | 汇率换算 | `ExchangeRateService.ets` | 第三方公开接口 |

**声明**：本项目与上述服务的运营方**均无关联、无合作、无背书**。App 内图标选择面板底部常驻同一提示。这些数据源拉到的图标若属金融机构，则只用于用户识别自己的账户，不构成与该机构的合作或推荐。运行时也允许用户从相册自选图覆盖。

### 已移除的数据源：银行卡卡面图（HarukaKinen/Cardentify）

本项目**曾经**通过 `CardLogoService.ets` 在运行时从 `HarukaKinen/Cardentify` 检索并下载银行卡卡面图。该数据源已于开源前整体删除，`CardLogoService.ets` 不再存在于仓库中。此处保留记录，是为了说明删除的依据，并防止后来者把它接回来。

**删除依据**（2026-09-03 实测，GitHub API + 直接请求，非推测）：

- **上游未声明任何 LICENSE**（`"license": null`）——著作权默认保留全部权利，未授予复制、镜像或再分发的许可。
- **上游被 DMCA 处理过一次**。仓库存在 `DMCA` / `data` / `main` 三个分支，其中 `DMCA` 分支的内容已被清空、只剩一个 README，全文为「🚫 DMCA'd 🚫」，而 `default_branch` 至今仍指向该分支。仓库当前未被封禁、内容已恢复，最后一次 push 为 2026-07-04。
- **素材不是发卡行官方提供的**。索引 `data.json` 每条记录带一个 `source` 字段，标明该卡面图是从哪里抓取的：Apple Pay 177 条、云闪付 147 条、Mi Pay 72 条、PayPal 34 条、Samsung Pay 9 条，招商银行 / Mir Pay / 中国银行各 3 / 3 / 1 条。也就是说，这些是从各家手机钱包 App 的卡面渲染中获取的图片。由此叠了两层权利问题：卡面设计本身的著作权与商业外观属于发卡行，而从第三方 App 内抓取素材的行为可能另受这些 App 服务条款约束。上游那次 DMCA 大概率与此相关（**这一句是推断，不是查证结论**）。

**为什么是删除而不是加声明**：第一节的小型品牌标识属于指示性使用，「无关联、无背书」的声明是与该用途相称的处理方式。但本节指向的是**完整卡面美术作品**，且上游处于无授权 + 已被下架过一次的状态——权利瑕疵不在「是否造成混淆」，声明化解不了，因此选择移除功能而不是移除责任。

**删除后的行为**：

- 用户**已经存下的卡面照旧显示**：本地缓存（`card_face_` 前缀）、用户自己 Supabase 桶里的对象、相册自选图三条链路都与上游存活状态无关，`IconPickerService.isCardFaceUrl()` 仍负责按前缀区分横卡面与圆标。
- 卡面加载失败时 `LogoImage` 清空图源并回调 `onError`；列表卡片与详情面板传了该回调，会退到品牌色底 + 文字字标，不会崩、不会留白框。

**给后来贡献者**：不要把这个图源接回来。若要恢复「按银行名搜卡面」，前提是换一个**你已取得授权**的图源；直接复用上游仓库等于把上述三层权利问题重新引入本项目。本段不构成法律意见。

---

## 三、用户自行配置的服务（不由本项目分发）

以下端点仅在**用户自己填入 API Key 后**才会被调用，本项目不分发任何凭据，也不代为付费：

- AI 解析：DeepSeek、火山方舟、OpenAI、Anthropic、Moonshot、智谱、MiniMax 等
- 云同步与登录：用户自己的 Supabase 项目（URL 与 anon key 由用户填入 `SupabaseConfig.ets`，该文件不入库）

调用这些服务受各自服务条款约束，由用户自行承担。

---

## 四、开源依赖

第三方代码依赖清单见各模块 `oh-package.json5` 及项目 lock 文件，其许可证由各自包声明。本文件只覆盖**素材与数据源**，不重复列举代码依赖。

---

## 五、联系方式（权利人异议通道）

本仓库不内置第三方机构图标，运行时图源（第二节）的权利问题由各服务运营方与各权利人自行约定，本项目仅作为客户端调用方。但若你发现：

- 仓库里出现了应当不属于本项目自有的素材（包括但不限于图片、音频、字体、文本片段）；
- App 内出现与本项目无关却可能被误认为由本项目背书的内容。

请按下列方式告知具体位置与主张权利，我们会在无不正当拖延内处理，并在下一个版本中移除相应素材。删除不影响 App 可用性——降级路径见第一节「删除后的降级行为」。

- **首选**：在仓库开 Issue，说明具体文件名或数据源、你主张的权利、以及期望的处理方式。
- **不愿公开**：用 GitHub 的 Report a vulnerability（私密通道，见 [`SECURITY.md`](SECURITY.md)），或写信到 naiyoufu@gmail.com。
