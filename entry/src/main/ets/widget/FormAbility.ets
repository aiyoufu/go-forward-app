import { Want } from '@kit.AbilityKit'
import { Logger } from 'common'
import { formBindingData, formProvider, FormExtensionAbility } from '@kit.FormKit'
import { DbService } from 'service'
import { PreferencesService } from 'service'
import { UserService } from 'service'
import { WidgetDataBuilder } from 'service'
import { WidgetUpdateService } from 'service'

/**
 * 桌面卡片 Form 生命周期
 * 五种：本月待还 / 资金压力 / 负债总览 / 订阅 / 负债·资金压力（长卡）
 */
export default class FormAbility extends FormExtensionAbility {
  private currentFormName: string = WidgetUpdateService.MONTH_DUE

  onAddForm(want: Want): formBindingData.FormBindingData {
    const p = want.parameters
    const rawName = p?.['ohos.extra.param.key.form_name'] ?? p?.['formName']
    const rawId = p?.['ohos.extra.param.key.form_identity'] ?? p?.['formId']
    let formName = (rawName as string) ?? WidgetUpdateService.MONTH_DUE
    if (formName === WidgetUpdateService.REMAINING) {
      formName = WidgetUpdateService.DEBT_OVERVIEW
    }
    const formId = (rawId as string) ?? ''
    this.currentFormName = formName
    this.initAndRefresh(formId, formName)
    return formBindingData.createFormBindingData(this.placeholderFor(formName))
  }

  onCastToNormalForm(_formId: string) {
  }

  onUpdateForm(formId: string): void {
    this.initAndRefresh(formId, '')
  }

  onFormEvent(formId: string, _message: string): void {
    this.initAndRefresh(formId, '')
  }

  onRemoveForm(formId: string) {
    WidgetUpdateService.unregisterForm(this.context, formId)
  }

  private placeholderFor(formName: string): Record<string, string | number | boolean> {
    if (formName === WidgetUpdateService.PRESSURE) {
      return WidgetDataBuilder.pressurePlaceholder()
    }
    if (formName === WidgetUpdateService.DEBT_OVERVIEW || formName === WidgetUpdateService.REMAINING) {
      return WidgetDataBuilder.debtOverviewPlaceholder()
    }
    if (formName === WidgetUpdateService.SUBSCRIPTION) {
      return WidgetDataBuilder.subscriptionPlaceholder()
    }
    if (formName === WidgetUpdateService.DEBT_PRESSURE) {
      return WidgetDataBuilder.debtPressurePlaceholder()
    }
    return WidgetDataBuilder.monthDuePlaceholder()
  }

  private async initAndRefresh(formId: string, formNameHint: string): Promise<void> {
    try {
      await this.initContext()
      let formName = formNameHint
      if (formName.length === 0) {
        formName = await WidgetUpdateService.resolveName(this.context, formId, this.currentFormName)
      }
      if (formName === WidgetUpdateService.REMAINING) {
        formName = WidgetUpdateService.DEBT_OVERVIEW
      }
      if (formName.length === 0) {
        formName = this.currentFormName
      }
      this.currentFormName = formName
      if (formId.length > 0) {
        await WidgetUpdateService.registerForm(this.context, formId, formName)
        await this.updateFormData(formId, formName)
      }
    } catch (err) {
      Logger.error('FormAbility', 'widget initAndRefresh failed: ' + JSON.stringify(err))
    }
  }

  private async initContext(): Promise<void> {
    const context = this.context
    await DbService.init(context)
    await PreferencesService.init(context)
    if (UserService.getCurrentUserId().length === 0) {
      await UserService.ensureDefaultUser()
    }
  }

  private async updateFormData(formId: string, formName: string): Promise<void> {
    try {
      const data = await WidgetUpdateService.buildData(formName)
      const binding = formBindingData.createFormBindingData(data)
      await formProvider.updateForm(formId, binding)
    } catch (err) {
      Logger.error('FormAbility', 'updateForm failed: ' + JSON.stringify(err))
    }
  }
}
