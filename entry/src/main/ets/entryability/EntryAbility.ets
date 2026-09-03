import {
  AbilityConstant,
  Configuration,
  ConfigurationConstant,
  EnvironmentCallback,
  UIAbility,
  Want
} from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { display } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { errorManager } from '@kit.AbilityKit';
import { IntentService } from 'service';
import { SettingsService } from 'service';
import { UserService } from 'service';
import { AnalyticsService } from 'service';
import { ReminderService } from 'service';
import { PreferencesService } from 'service';
import { AntiPeekService } from 'service';
import { PerfTrace } from 'service';
import { AppStorageKeys } from 'common';
import { ThemeManager } from 'common';
import { ColorTokens } from 'common';
import { AppRouter, RouteNames } from 'common';
import { Constants } from 'common';
import { isAbilityConfigDark } from 'common';
import { LightSensorService } from 'service';
import { SyncScheduler } from 'service';
import { SyncRealtime } from 'service';
import { bundleManager } from '@kit.AbilityKit';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private mainWindow: window.Window | null = null;
  /** ApplicationContext.on('environment') 回调 id，销毁时 off */
  private envCallbackId: number = -1;
  /** 冷启动意图延后处理，避免 onCreate 抢主线程 */
  private pendingWant: Want | null = null;

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    PerfTrace.boot()
    // 先占位 APPLIED=未设置，再读系统深浅；applyColorMode 异步落定后可能改为强制浅/深
    AppStorage.setOrCreate(AppStorageKeys.APPLIED_COLOR_MODE,
      ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET)
    this.refreshSystemDarkFromConfig(this.context.config?.colorMode)
    this.registerSystemEnvironmentCallback()
    this.applySystemFollowColorMode()
    // 意图延后到首帧窗口就绪后，减少 onCreate 阻塞
    this.pendingWant = want
    this.installCrashHook()
    // 防窥订阅：走敏感文本脱敏态，不走全屏蒙层
    PreferencesService.init(this.context).then(() => {
      AntiPeekService.startListeningIfEnabled()
    })
    hilog.info(DOMAIN, 'GoForward', '%{public}s', 'Ability onCreate');
  }

  private installCrashHook(): void {
    try {
      errorManager.on('unhandledRejection', (reason: Object) => {
        const msg = reason instanceof Error ? reason.message : JSON.stringify(reason)
        AnalyticsService.trackCrash(msg)
      })
    } catch (_e) {
    }
  }

  onDestroy(): void {
    this.unregisterSystemEnvironmentCallback()
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    const cm = newConfig.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
    hilog.info(DOMAIN, 'testTag', 'onConfigurationUpdate colorMode=%{public}d', cm);
    // 应用配置回调：仅跟随系统时 config 才是系统真值（强制浅/深时是应用生效值）
    // 系统切换深浅的主通道见 EnvironmentCallback；此处作补充
    if (this.isFollowingSystemColor()) {
      this.refreshSystemDarkFromConfig(cm, true)
    }
    this.applySystemBarAppearance()
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    windowStage.getMainWindow((err: BusinessError, windowClass: window.Window) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to obtain the main window. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      this.mainWindow = windowClass;

      windowClass.setWindowLayoutFullScreen(true).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting full-screen layout.');
      }).catch((e: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set full-screen layout. Cause: %{public}s', JSON.stringify(e));
      });

      windowClass.setWindowPrivacyMode(true).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting window privacy mode (anti-peep).');
      }).catch((e: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set window privacy mode. Cause: %{public}s', JSON.stringify(e));
      });

      try {
        const updateAvoidArea = (): void => {
          try {
            const systemAvoid = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
            const navAvoid = windowClass.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
            const density = display.getDefaultDisplaySync().densityPixels || 1;
            const topSafe = systemAvoid.topRect.height / density;
            const bottomSafe = Math.max(systemAvoid.bottomRect.height, navAvoid.bottomRect.height) / density;
            AppStorage.setOrCreate(AppStorageKeys.TOP_SAFE_HEIGHT, topSafe);
            AppStorage.setOrCreate(AppStorageKeys.BOTTOM_SAFE_HEIGHT, bottomSafe);
          } catch (err) {
            hilog.error(DOMAIN, 'testTag', 'Failed to calculate avoid area. Cause: %{public}s', JSON.stringify(err));
          }
        };

        updateAvoidArea();

        windowClass.on('avoidAreaChange', (data) => {
          if (data.type === window.AvoidAreaType.TYPE_SYSTEM || data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
            updateAvoidArea();
          }
        });
      } catch (err) {
        hilog.error(DOMAIN, 'testTag', 'Failed to get avoid area. Cause: %{public}s', JSON.stringify(err));
      }

      this.applySystemBarAppearance()
    });

    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      // 内容就绪后再处理启动 Want，降低 onCreate 主线程占用
      const w = this.pendingWant
      this.pendingWant = null
      if (w !== null) {
        IntentService.handleWant(w)
      }
    });
  }

  /** 应用是否处于 setColorMode(NOT_SET)「跟随系统」 */
  private isFollowingSystemColor(): boolean {
    const applied = AppStorage.get<number>(AppStorageKeys.APPLIED_COLOR_MODE)
    return applied === undefined || applied === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
  }

  /**
   * 从 Configuration.colorMode 写入 SYSTEM_DARK（ConfigurationConstant：DARK=0）。
   * - 应用 config：仅 isFollowingSystemColor 时可信
   * - EnvironmentCallback 的 config：始终是系统真值，可信
   */
  private refreshSystemDarkFromConfig(colorMode: number | undefined, notify: boolean = false): void {
    try {
      const isDark = isAbilityConfigDark(colorMode)
      if (AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) !== isDark) {
        AppStorage.setOrCreate(AppStorageKeys.SYSTEM_DARK, isDark)
        hilog.info(DOMAIN, 'testTag', 'SYSTEM_DARK=%{public}s from config=%{public}d',
          isDark ? 'true' : 'false', colorMode ?? -999)
        if (notify) {
          Constants.notifyThemeChange()
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to refresh SYSTEM_DARK. Cause: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 系统环境回调：系统设置改深/浅时触发（比 UIAbility.onConfigurationUpdate 更可靠）。
   * 始终用其 colorMode 更新 SYSTEM_DARK；主题是否采用取决于 theme_mode===system。
   */
  private registerSystemEnvironmentCallback(): void {
    try {
      const appCtx = this.context.getApplicationContext()
      const callback: EnvironmentCallback = {
        onConfigurationUpdated: (config: Configuration): void => {
          const cm = config.colorMode ?? ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
          hilog.info(DOMAIN, 'testTag', 'EnvironmentCallback colorMode=%{public}d', cm)
          // 系统真值：始终写入 SYSTEM_DARK 并广播；
          // theme_mode 为 light/dark 时 ThemeManager 忽略 systemDark，isSame 可挡住无效重绘
          this.refreshSystemDarkFromConfig(cm, true)
          this.applySystemBarAppearance()
        },
        onMemoryLevel: (_level: AbilityConstant.MemoryLevel): void => {
        }
      }
      this.envCallbackId = appCtx.on('environment', callback)
      hilog.info(DOMAIN, 'testTag', 'EnvironmentCallback registered id=%{public}d', this.envCallbackId)
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to register EnvironmentCallback. Cause: %{public}s',
        JSON.stringify(err));
    }
  }

  private unregisterSystemEnvironmentCallback(): void {
    if (this.envCallbackId < 0) {
      return
    }
    try {
      this.context.getApplicationContext().off('environment', this.envCallbackId)
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to unregister EnvironmentCallback. Cause: %{public}s',
        JSON.stringify(err));
    }
    this.envCallbackId = -1
  }

  /** 冷启动只跟系统，账号主题由 Splash 一次 getSettings 落定，避免与 Splash 抢会话 I/O */
  private applySystemFollowColorMode(): void {
    try {
      const colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET
      this.context.getApplicationContext().setColorMode(colorMode)
      AppStorage.setOrCreate(AppStorageKeys.APPLIED_COLOR_MODE, colorMode)
      this.refreshSystemDarkFromConfig(this.context.config?.colorMode)
      this.applySystemBarAppearance()
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  private applySystemBarAppearance(): void {
    if (!this.mainWindow) {
      return
    }
    try {
      const systemDark = AppStorage.get<boolean>(AppStorageKeys.SYSTEM_DARK) ?? false
      let dark = systemDark
      const uid = UserService.getCurrentUserId()
      const cached = uid.length > 0 ? SettingsService.peekCache(uid) : null
      if (cached !== null) {
        dark = ThemeManager.isEffectivelyDark(cached, systemDark)
      }
      // 状态栏图标/文字与主题 ink 对齐（暗 #DFE4E0 / 亮 #0A0A0A）
      const contentColor = dark ? ColorTokens.STATUS_BAR_CONTENT_DARK : ColorTokens.STATUS_BAR_CONTENT_LIGHT
      const sysBarProps: window.SystemBarProperties = {
        statusBarColor: 'rgba(0,0,0,0)',
        navigationBarColor: 'rgba(0,0,0,0)',
        statusBarContentColor: contentColor,
        navigationBarContentColor: contentColor
      };
      this.mainWindow.setWindowSystemBarProperties(sysBarProps).then(() => {
        hilog.info(DOMAIN, 'testTag', 'Succeeded in setting system bar properties.');
      }).catch((e: BusinessError) => {
        hilog.error(DOMAIN, 'testTag', 'Failed to set system bar properties. Cause: %{public}s', JSON.stringify(e));
      });
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to apply system bar appearance. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onNewWant');
    IntentService.handleWant(want)
  }

  onForeground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
    AppStorage.setOrCreate(AppStorageKeys.APP_IN_BACKGROUND, false);
    // 防窥保护：幂等补订阅，覆盖监听丢失场景
    AntiPeekService.startListeningIfEnabled()
    LightSensorService.resume();
    // 用户可能在系统设置里改了深浅再回 App：跟随系统时补一次同步（防漏回调）
    if (this.isFollowingSystemColor()) {
      this.refreshSystemDarkFromConfig(this.context.config?.colorMode, true)
      this.applySystemBarAppearance()
    }
    // 网络监听轻量，冷启动也可注册；同步/Realtime/提醒等首页 hydrate（Main 侧 warmup）
    SyncScheduler.ensureNetWatch()
    if (SyncScheduler.isHomeHydrated()) {
      SyncScheduler.scheduleForeground()
      SyncScheduler.startForegroundPulse()
      SyncRealtime.start()
      ReminderService.checkAndGenerateDueReminders().catch(() => {
      })
    }
    this.checkAutoLock();
    this.trackAnalyticsForeground()
  }

  onBackground(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
    // 退到后台断开环境光传感器，避免持续采样耗电
    LightSensorService.suspend();
    SyncScheduler.stopForegroundPulse()
    SyncRealtime.stop()
    PreferencesService.flush().catch(() => {
    })
    AppStorage.setOrCreate(AppStorageKeys.APP_IN_BACKGROUND, true);
    AppStorage.setOrCreate(AppStorageKeys.LAST_BACKGROUND_TIME, Date.now());
    AnalyticsService.trackBackground()
  }

  private trackAnalyticsForeground(): void {
    // Preferences 可能尚未由 Splash 初始化；埋点前幂等 init，避免 getPref 抛错丢事件
    PreferencesService.init(this.context)
      .then(() => {
        return bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)
      })
      .then((info) => {
        AnalyticsService.setAppMeta(info.versionName, info.versionCode)
        AnalyticsService.trackForeground()
      })
      .catch(() => {
        AnalyticsService.trackForeground()
      })
  }

  private async checkAutoLock(): Promise<void> {
    try {
      const settings = await SettingsService.getSettings(UserService.getCurrentUserId());
      if (!settings.app_lock_enabled) {
        return;
      }
      const lastBg = AppStorage.get<number>(AppStorageKeys.LAST_BACKGROUND_TIME) ?? 0;
      if (lastBg === 0) {
        return;
      }
      const elapsed = (Date.now() - lastBg) / 1000 / 60;
      if (elapsed >= settings.app_lock_timeout_mins) {
        AppStorage.setOrCreate(AppStorageKeys.APP_LOCK_VERIFIED, false);
        AppStorage.setOrCreate(AppStorageKeys.LAST_BACKGROUND_TIME, 0);
        // 在现有栈顶盖上锁页（不重建窗口内容，解锁后回到离开时的页面）
        if (AppRouter.size() > 0 && AppRouter.topName() !== RouteNames.APP_LOCK) {
          AppRouter.push(RouteNames.APP_LOCK, undefined, false);
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Auto lock check failed: %{public}s', JSON.stringify(err));
    }
  }
}
