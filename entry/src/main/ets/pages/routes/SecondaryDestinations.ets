/**
 * 次级路由（表单/导出/资料/法律）
 * Index 以 import lazy 拉入本文件：第一次进表单才加载，不进冷启动图。
 */
import { DebtFormPage } from '../DebtFormPage'
import { SubscriptionFormPage } from '../SubscriptionFormPage'
import { CreditAccountFormPage } from '../CreditAccountFormPage'
import { ExportImportPage } from '../ExportImportPage'
import { LegalPage } from '../LegalPage'
import { ProfilePage } from '../ProfilePage'
import { AvatarCropPage } from '../AvatarCropPage'
import { NotificationsPage } from '../NotificationsPage'
import { RouteNames } from 'common'

@Builder
export function secondaryDestination(name: string) {
  if (name === RouteNames.DEBT_FORM) {
    DebtFormPage()
  } else if (name === RouteNames.SUBSCRIPTION_FORM) {
    SubscriptionFormPage()
  } else if (name === RouteNames.CREDIT_ACCOUNT_FORM) {
    CreditAccountFormPage()
  } else if (name === RouteNames.EXPORT_IMPORT) {
    ExportImportPage()
  } else if (name === RouteNames.LEGAL) {
    LegalPage()
  } else if (name === RouteNames.PROFILE) {
    ProfilePage()
  } else if (name === RouteNames.AVATAR_CROP) {
    AvatarCropPage()
  } else if (name === RouteNames.NOTIFICATIONS) {
    NotificationsPage()
  }
}

export function isSecondaryRoute(name: string): boolean {
  return RouteNames.isSecondary(name)
}
