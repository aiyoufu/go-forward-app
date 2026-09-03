import { preferences } from '@kit.ArkData'
import { formBindingData, formProvider } from '@kit.FormKit'
import { WidgetDataBuilder } from './WidgetDataBuilder'

/**
 * 万能卡片主动更新：注册 formId→formName，App 数据变更后 updateAll 推送。
 * 三种：本月待还 / 资金压力 / 负债总览（长卡）
 */
export class WidgetUpdateService {
  private static readonly STORE = 'go_forward_widget_registry'
  private static readonly KEY = 'form_registry'
  /** 各卡片类型上次推送的内容签名：内容未变时跳过 formProvider.updateForm */
  private static readonly lastPushedSig: Map<string, string> = new Map()

  static readonly MONTH_DUE = 'MonthDueWidget'
  static readonly PRESSURE = 'PressureTrendWidget'
  static readonly DEBT_OVERVIEW = 'DebtOverviewWidget'
  static readonly SUBSCRIPTION = 'SubscriptionWidget'
  static readonly DEBT_PRESSURE = 'DebtPressureWidget'
  /** @deprecated 已移除，兼容旧注册表 */
  static readonly REMAINING = 'RemainingDebtWidget'

  static async registerForm(context: Context, formId: string, formName: string): Promise<void> {
    if (formId.length === 0) {
      return
    }
    // 旧「剩余负债」迁移为负债总览数据源（用户需手动换成长卡）
    let name = formName
    if (name === WidgetUpdateService.REMAINING) {
      name = WidgetUpdateService.DEBT_OVERVIEW
    }
    const map = await WidgetUpdateService.loadMap(context)
    if (map.get(formId) === name) {
      return
    }
    // 新注册的卡片尚未收到过当前数据：作废签名，强制下次 updateAll 推送
    WidgetUpdateService.lastPushedSig.delete(name)
    map.set(formId, name)
    await WidgetUpdateService.saveMap(context, map)
  }

  static async unregisterForm(context: Context, formId: string): Promise<void> {
    const map = await WidgetUpdateService.loadMap(context)
    if (map.delete(formId)) {
      await WidgetUpdateService.saveMap(context, map)
    }
  }

  static async resolveName(context: Context, formId: string, fallback: string): Promise<string> {
    const map = await WidgetUpdateService.loadMap(context)
    let name = map.get(formId)
    if (name === WidgetUpdateService.REMAINING) {
      name = WidgetUpdateService.DEBT_OVERVIEW
    }
    return name !== undefined && name.length > 0 ? name : fallback
  }

  static async buildData(formName: string): Promise<Record<string, string | number | boolean>> {
    if (formName === WidgetUpdateService.PRESSURE) {
      return await WidgetDataBuilder.buildPressure()
    }
    if (formName === WidgetUpdateService.DEBT_OVERVIEW || formName === WidgetUpdateService.REMAINING) {
      return await WidgetDataBuilder.buildDebtOverview()
    }
    if (formName === WidgetUpdateService.SUBSCRIPTION) {
      return await WidgetDataBuilder.buildSubscription()
    }
    if (formName === WidgetUpdateService.DEBT_PRESSURE) {
      return await WidgetDataBuilder.buildDebtPressure()
    }
    return await WidgetDataBuilder.buildMonthDue()
  }

  static async updateAll(context: Context): Promise<void> {
    const map = await WidgetUpdateService.loadMap(context)
    if (map.size === 0) {
      return
    }
    const cache = new Map<string, formBindingData.FormBindingData>()
    const entries = Array.from(map.entries())
    for (const entry of entries) {
      const formId = entry[0]
      let formName = entry[1]
      if (formName === WidgetUpdateService.REMAINING) {
        formName = WidgetUpdateService.DEBT_OVERVIEW
      }
      try {
        let binding = cache.get(formName)
        if (binding === undefined) {
          const data = await WidgetUpdateService.buildData(formName)
          // 内容签名去重：数据未变时跳过推送（重复进主页/无变化写路径不再打扰卡片）
          const sig = JSON.stringify(data)
          if (WidgetUpdateService.lastPushedSig.get(formName) === sig) {
            continue
          }
          WidgetUpdateService.lastPushedSig.set(formName, sig)
          binding = formBindingData.createFormBindingData(data)
          cache.set(formName, binding)
        }
        await formProvider.updateForm(formId, binding)
      } catch (_err) {
        // 卡片可能已移除
      }
    }
  }

  private static async openFresh(context: Context): Promise<preferences.Preferences> {
    try {
      await preferences.removePreferencesFromCache(context, WidgetUpdateService.STORE)
    } catch (_err) {
      // 首次无缓存
    }
    try {
      return await preferences.getPreferences(context, WidgetUpdateService.STORE)
    } catch (e) {
      // 读取失败原样上抛，由调用方决定降级
      throw e as Error
    }
  }

  private static async loadMap(context: Context): Promise<Map<string, string>> {
    const pref = await WidgetUpdateService.openFresh(context)
    let raw = ''
    try {
      const v = pref.getSync(WidgetUpdateService.KEY, '')
      raw = typeof v === 'string' ? v : ''
    } catch (_e) {
    }
    const map = new Map<string, string>()
    if (raw.length === 0) {
      return map
    }
    const parts = raw.split(';')
    for (const part of parts) {
      if (part.length === 0) {
        continue
      }
      const kv = part.split('|')
      if (kv.length === 2 && kv[0].length > 0) {
        map.set(kv[0], kv[1])
      }
    }
    return map
  }

  private static async saveMap(context: Context, map: Map<string, string>): Promise<void> {
    const pref = await WidgetUpdateService.openFresh(context)
    const arr: string[] = []
    const entries = Array.from(map.entries())
    for (const entry of entries) {
      arr.push(entry[0] + '|' + entry[1])
    }
    try {
      await pref.put(WidgetUpdateService.KEY, arr.join(';'))
      await pref.flush()
    } catch (_e) {
    }
  }
}
