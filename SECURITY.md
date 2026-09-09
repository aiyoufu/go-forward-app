# 安全问题披露

本文件对应 GoForward 的 HarmonyOS 端（`aiyoufu/go-forward-app`）。

## 报告通道

**请通过 GitHub 的私密漏洞报告功能，不要开公开 Issue、不要在 PR 或讨论区描述漏洞细节。**

路径：本仓库页面 → `Security` 标签 → `Report a vulnerability`。

维护者需先在 Settings → Security → **Private vulnerability reporting** 打开该功能。如果你看不到 `Report a vulnerability` 按钮，说明通道尚未开启 —— 此时开一个公开 Issue，正文只写「请开启私密漏洞报告通道」，**不要附带任何漏洞细节**。

报告时请尽量带上：

- 复现步骤与影响面（能读到谁的数据、能否写入、是否需要登录态）
- 受影响的版本 / commit，以及运行环境（HarmonyOS NEXT 版本号、真机型号或模拟器）
- 你已知的实际利用情况（是否已在野被利用）

## 本项目的安全边界

说清哪些是设计取舍、哪些才是漏洞，避免把公开信息当漏洞报，也避免真问题被「这是设计如此」搪塞过去。

**不是漏洞：**

- `SupabaseConfig.ets` 里的 `ANON_KEY` —— anon key 按 Supabase 设计就是公开的，它会随 HAP 一起分发到设备上。真正的边界是 RLS。「拿到 anon key 后能越权读写他人数据」才是漏洞。
- 业务数据（负债、订阅、信用账户、还款流水）**明文存于云端**，靠 RLS 行级隔离 —— 这是明确的取舍，不是疏漏，应用内隐私政策与 `README.md` 均已直白写明「不是端到端加密」。
- 应用锁是客户端界面锁（会话级验证），**不构成数据加密**，绕过它不等于拿到额外数据。PIN 以 PBKDF2（100 000 轮）加盐哈希存本机，`app_lock_hash` 列显式不参与云同步（`sync/SettingsTableSync.ets` 的 `toCloud` 白名单不含它），旧式单轮 SHA256 哈希在校验成功后自动升级。
- **桌面服务卡片与锁屏实况窗不经过应用锁，也不脱敏金额** —— 卡片由系统 Form 宿主渲染，不是应用进程内的界面，应用锁拦不住。这是「锁屏上直接看到本月待还」这个功能本身的代价，属于取舍。介意的人应移除卡片，而不是把它当绕过应用锁的漏洞报。
- DEK 与 Supabase 会话 token 缓存在 Asset Store Kit（关键资产，`auth/SecureStore.ets`，`DEVICE_FIRST_UNLOCKED`）—— 本机已持有会话 token 即可直接读取云端全部数据，缓存 DEK 不引入额外的本地风险面。
- 用户自行配置的第三方 AI API Key 由设备直连用户指定的服务商，不经过开发者服务器；该 Key 的泄露风险归属用户与其服务商。
- 自建 Supabase 环境因迁移未跑全、Realtime publication 未配、RLS 策略缺失导致的问题 —— 属于部署配置，请在 Issue 里说明环境，不必走私密通道。
- 历史版本内置的金融机构图标（`entry/src/main/resources/rawfile/credit_logos/`）已于 2026-09 整体移除（参见 [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) 第一节）。如仍在旧安装上看到残留像素，请升级到包含本次清理的版本，无需单独提报。

**是漏洞：**

- 任何绕过 RLS 的越权读写：用 A 用户的会话读到 / 改到 B 用户的数据。
- `service_role` key 出现在客户端代码、构建产物、脚本或 CI 配置里。它绕过全部 RLS，本仓库任何位置都不应存在。
- **明文凭证出站**：`auth/DekManager.ets` 的 `encryptField` 在 DEK 不可用时会回退明文暂存本机（这是过渡期兜底），此时出站拦截是唯一防线 —— `sync/CreditAccountTableSync.ets` 拒绝把非 `enc:v1:` 的 CVV 推上云，`sync/SettingsTableSync.ets` 的 `toCloud` 白名单根本不含 `ai_text_key` / `ai_vision_key`。若能构造出「明文 CVV 或明文 AI Key 实际到达云端」的路径，请报告。
- 密文被当明文回显：`decryptField` 在 DEK 缺失或解密失败时返回空串（凭证按「未配置」处理），不应把 `enc:v1:` 密文或错误明文吐给 UI。
- 加密字段的密文可被降级写入云端，或 `enc:v1` 格式 / PBKDF2 轮数（KEK 600 000 轮）/ 盐与 IV 长度被改动后，旧设备 / 旧版本客户端解不开既有数据。
- 图标云存储（`platform/IconCloudService.ets`）的公开读 bucket 可被写入非本人路径，或上传路径可被构造为覆盖他人对象。
- 意图框架（Insight Intent）、服务卡片、实况窗、NFC 碰一碰等系统入口可被其他应用在无用户确认的情况下调用，读到财务数据或写入记录。
- 应用沙箱内的本地数据库（`relationalStore`，`SecurityLevel.S3`）可被同设备其他应用读取。

**不属于本项目范围：**

- Supabase 平台自身的漏洞（请报给 Supabase）
- 用户自建 Supabase 项目的配置错误
- 第三方 AI 服务商的 API 安全问题
- HarmonyOS 系统、DevEco Studio、华为签名服务自身的漏洞（请报给华为）

## 密钥泄露的处理原则

**轮换优先于删除。** 一旦密钥进入过 git 历史，就按「已泄露」处理：

1. 立即在源头轮换（Supabase → Project Settings → API 重置对应 key；签名物料在 DevEco 重新「自动签名」生成）。
2. 再从工作区与 `.gitignore` 确认它不会再被提交。
3. 最后才考虑清理历史。

仅从 HEAD 删除文件**不会**清除历史，任何克隆者都能从旧提交里取到原件。所以「删掉了」不等于「安全了」，轮换才是那一步。

本仓库的 `.gitignore` 已覆盖 `build-profile.json5`（含 DevEco 写入的加密口令）、`common/src/main/ets/common/SupabaseConfig.ets`、`signature/`、`signing/`、`*.p12`、`*.cer`、`*.p7b`。这些文件只提供 `.example` 模板入库。**如果你 fork 后要把仓库转为公开，请先自查历史里有没有这些 blob。**

## 时限

本项目由个人维护，没有 SLA。目标是**一周内给出首次回应**（确认收到、判断是否成立、给出处置计划）。如果一周没有回音，可以在原通道催一次；仍无回应再考虑其他披露方式。

修复公开前不会披露细节；修复后会在 release notes 里说明，并致谢报告者（除非你要求匿名）。
