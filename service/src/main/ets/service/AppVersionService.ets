import { Constants } from 'common'
import { PreferencesService } from './PreferencesService'
import { SupabaseRestService, SupabaseRestOptions } from './SupabaseRestService'
import { SupabaseConfig } from 'common'
import { Logger } from 'common'

/**
 * 单条版本更新点项（动态模型）
 */
export class VersionLogItem {
  title: string = ''
  desc: string = ''
  tag: string = ''

  constructor(title: string = '', desc: string = '', tag: string = '') {
    this.title = title
    this.desc = desc
    this.tag = tag
  }
}

/**
 * 单条应用特色功能项（动态模型）
 */
export class FeatureItem {
  title: string = ''
  desc: string = ''
  icon: string = ''

  constructor(title: string = '', desc: string = '', icon: string = '') {
    this.title = title
    this.desc = desc
    this.icon = icon
  }
}

/**
 * 版本发布与功能信息汇总模型
 */
export class VersionReleaseInfo {
  versionName: string = '1.0.0'
  versionCode: number = 1000000
  releaseDate: string = ''
  isFirstInstall: boolean = false
  isVersionUpdated: boolean = false
  features: FeatureItem[] = []
  releaseNotes: VersionLogItem[] = []
}

/**
 * 版本与安装状态检测结果
 */
export class VersionStateResult {
  isFirstInstall: boolean = false
  isVersionUpdated: boolean = false
  lastRunVersion: string = ''
  currentVersion: string = ''

  constructor(isFirstInstall: boolean = false, isVersionUpdated: boolean = false, lastRunVersion: string = '', currentVersion: string = '') {
    this.isFirstInstall = isFirstInstall
    this.isVersionUpdated = isVersionUpdated
    this.lastRunVersion = lastRunVersion
    this.currentVersion = currentVersion
  }
}

/**
 * 动态版本与更新服务
 * 
 * 职责：
 * 1. 动态判断应用安装态（首次安装 vs 跨版本更新升级）
 * 2. 动态拉取与缓存云端最新 Release Notes 与特色功能
 * 3. 动态多版本映射，避免更新内容写死
 * 4. 版本已读标记管理
 */
export class AppVersionService {
  private static readonly TAG: string = 'AppVersionService'

  /** 运行时动态注册的多版本更新日志注册表（支持热扩展与多版本维护） */
  private static dynamicVersionMap: Map<string, VersionLogItem[]> = new Map<string, VersionLogItem[]>()

  /**
   * 注册指定版本的动态更新点（可在插件或模块初始化时动态注入）
   */
  static registerDynamicReleaseNotes(version: string, notes: VersionLogItem[]): void {
    AppVersionService.dynamicVersionMap.set(version, notes)
  }

  /**
   * 检测当前版本的安装/升级状态
   */
  static async checkVersionState(currentVersion: string): Promise<VersionStateResult> {
    try {
      const lastRun = await PreferencesService.getString(Constants.PREF_LAST_RUN_VERSION, '')
      if (!lastRun || lastRun.trim().length === 0) {
        return new VersionStateResult(true, false, '', currentVersion)
      }
      const isUpdated = lastRun !== currentVersion
      return new VersionStateResult(false, isUpdated, lastRun, currentVersion)
    } catch (e) {
      Logger.warn(AppVersionService.TAG, 'checkVersionState error: ' + JSON.stringify(e))
      return new VersionStateResult(false, false, '', currentVersion)
    }
  }

  /**
   * 检查是否存在未阅读的新版本更新内容
   */
  static async hasUnreadVersionUpdate(currentVersion: string): Promise<boolean> {
    try {
      const lastRun = await PreferencesService.getString(Constants.PREF_LAST_RUN_VERSION, '')
      const lastViewed = await PreferencesService.getString(Constants.PREF_LAST_VIEWED_VERSION, '')
      
      // 若从未记录过已读版本，但有老版本运行记录且不同于当前版本，说明刚升级未读
      if (lastRun.length > 0 && lastRun !== currentVersion && lastViewed !== currentVersion) {
        return true
      }
      return false
    } catch {
      return false
    }
  }

  /**
   * 标记当前版本已启动运行
   */
  static async markVersionRun(currentVersion: string): Promise<void> {
    try {
      await PreferencesService.putString(Constants.PREF_LAST_RUN_VERSION, currentVersion)
    } catch (e) {
      Logger.warn(AppVersionService.TAG, 'markVersionRun error: ' + JSON.stringify(e))
    }
  }

  /**
   * 标记当前版本更新内容已被用户查看
   */
  static async markVersionViewed(currentVersion: string): Promise<void> {
    try {
      await PreferencesService.putString(Constants.PREF_LAST_VIEWED_VERSION, currentVersion)
      await PreferencesService.putString(Constants.PREF_LAST_RUN_VERSION, currentVersion)
    } catch (e) {
      Logger.warn(AppVersionService.TAG, 'markVersionViewed error: ' + JSON.stringify(e))
    }
  }

  /**
   * 获取核心应用特色功能列表（动态模型）
   */
  static getDynamicFeatures(): FeatureItem[] {
    return [
      new FeatureItem('🎯 三维全景聚合', '负债、订阅、信用账户同屏可见，一张面板理清所有财务节奏', 'overview'),
      new FeatureItem('🤖 AI 智能单据', '支持文字、截屏、系统听写与拍照秒级解析，告别繁琐手动录入', 'ai'),
      new FeatureItem('🔒 端到端加密云备份', '本地优先离线可用，支持 Supabase 加密备份与多端双向同步', 'security'),
      new FeatureItem('📅 履约排期与宽限期', '还款日与扣费日时间线摊开，支持宽限期推算与提前结清计算', 'schedule'),
      new FeatureItem('🎨 极简沉浸交互体验', '全量优雅半模态交互、自适应深浅沉浸光感与流畅微动效', 'ui')
    ]
  }

  /**
   * 根据版本号动态匹配该版本的专属更新点（支持多版本动态映射，不写死单版本）
   */
  static getDynamicReleaseNotes(versionName: string): VersionLogItem[] {
    // 1. 优先读取运行时动态注册表
    if (AppVersionService.dynamicVersionMap.has(versionName)) {
      const registered = AppVersionService.dynamicVersionMap.get(versionName)
      if (registered && registered.length > 0) {
        return registered
      }
    }

    // 2. 根据版本动态生成或解析结构化更新日志
    if (versionName.startsWith('1.1') || versionName.startsWith('2.')) {
      return [
        new VersionLogItem('✨ 多端实时协同', '全面优化多端双向同步冲突解决与离线队列性能', 'NEW'),
        new VersionLogItem('🤖 AI 语音与多票合并', '支持多张票据一次性批量识别与语义归类', 'AI'),
        new VersionLogItem('📈 资产与负债走势图', '新增月度收支趋势预测与履约健康度打分', 'FEATURE'),
        new VersionLogItem('🎨 动效与交互优化', '优化卡片交互手势与沉浸式底栏切换触感', 'OPTIMIZE')
      ]
    }

    // 默认/1.0.x 版本动态更新点
    return [
      new VersionLogItem('✨ 云端同步与多端互联', '支持 Supabase 备份恢复与多端双向同步，凭证字段端到端加密', 'NEW'),
      new VersionLogItem('🤖 AI 智能单据全面升级', '配置文字/图片解析，支持键盘、系统听写、拍照与相册录入', 'AI'),
      new VersionLogItem('💳 信用与宽限期计算', '新增单据宽限期提示、还款明细精细计算与一键提前结清', 'FEATURE'),
      new VersionLogItem('🎨 交互视觉全新重构', '全新设计安全应用锁，全量弹窗重构为优雅的底部半模态', 'UI'),
      new VersionLogItem('⚡ 细节体验与流畅优化', '页面切换自动收起滑动菜单，认证失败提示增加抖动特效', 'OPTIMIZE')
    ]
  }

  /**
   * 异步从远程云端（如 Supabase 或 API）拉取最新版本发布信息
   */
  static async fetchRemoteReleaseInfo(currentVersion: string): Promise<VersionReleaseInfo | null> {
    try {
      if (!SupabaseConfig.isConfigured()) {
        return null
      }
      const options = new SupabaseRestOptions('app_releases')
      options.filters.set('version_name', `eq.${currentVersion}`)
      const resp = await SupabaseRestService.get('', options)
      if (resp.status === 200 && resp.data && resp.data.length > 0) {
        const item = resp.data[0] as Record<string, Object>
        const info = new VersionReleaseInfo()
        info.versionName = (item.version_name as string) || currentVersion
        info.versionCode = (item.version_code as number) || 1000000
        info.releaseDate = (item.release_date as string) || ''
        
        // 动态解析 features
        if (Array.isArray(item.features)) {
          info.features = (item.features as Record<string, string>[]).map((f) => new FeatureItem(f.title, f.desc, f.icon))
        }
        // 动态解析 release_notes
        if (Array.isArray(item.release_notes)) {
          info.releaseNotes = (item.release_notes as Record<string, string>[]).map((n) => new VersionLogItem(n.title, n.desc, n.tag))
        }
        
        // 缓存到本地 Preferences 供离线和即时读取
        await PreferencesService.putString(Constants.PREF_CACHED_RELEASE_INFO, JSON.stringify(info))
        return info
      }
      return null
    } catch (e) {
      Logger.warn(AppVersionService.TAG, 'fetchRemoteReleaseInfo failed: ' + JSON.stringify(e))
      return null
    }
  }

  /**
   * 获取当前版本的完整发布信息（优先读取本地动态缓存/动态生成，并合并安装状态）
   */
  static async getReleaseInfo(currentVersion: string): Promise<VersionReleaseInfo> {
    const state = await AppVersionService.checkVersionState(currentVersion)
    const result = new VersionReleaseInfo()
    result.versionName = currentVersion
    result.isFirstInstall = state.isFirstInstall
    result.isVersionUpdated = state.isVersionUpdated

    // 1. 尝试从本地缓存读取动态拉取的数据
    try {
      const cachedJson = await PreferencesService.getString(Constants.PREF_CACHED_RELEASE_INFO, '')
      if (cachedJson && cachedJson.length > 0) {
        const parsed = JSON.parse(cachedJson) as VersionReleaseInfo
        if (parsed && (parsed.versionName === currentVersion || parsed.releaseNotes?.length > 0)) {
          result.versionCode = parsed.versionCode || 1000000
          result.releaseDate = parsed.releaseDate || ''
          result.features = parsed.features?.length > 0 ? parsed.features : AppVersionService.getDynamicFeatures()
          result.releaseNotes = parsed.releaseNotes?.length > 0 ? parsed.releaseNotes : AppVersionService.getDynamicReleaseNotes(currentVersion)
          return result
        }
      }
    } catch (_e) {
    }

    // 2. 动态生成并注入
    result.features = AppVersionService.getDynamicFeatures()
    result.releaseNotes = AppVersionService.getDynamicReleaseNotes(currentVersion)

    // 3. 后台异步静默尝试拉取一次云端最新更新（不阻塞当前返回）
    AppVersionService.fetchRemoteReleaseInfo(currentVersion).catch(() => {})

    return result
  }
}
