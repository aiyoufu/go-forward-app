import { ParseResultItem } from './AIService'
import { AILiveMapping } from './AILiveMapping'
import { DebtService } from '../DebtService'
import { CreditAccountService } from '../CreditAccountService'
import { SubscriptionService } from '../SubscriptionService'
import { AnalyticsService } from '../AnalyticsService'

/**
 * AI Live 确认入库（S3）— 无 UI
 */
export class AILiveSaveService {
  static async saveParseItem(item: ParseResultItem): Promise<void> {
    AnalyticsService.setNextRecordSource('ai_live')
    if (item.recordType === 'subscription') {
      await SubscriptionService.createSubscription(AILiveMapping.toCreateSubscriptionInput(item))
    } else if (item.recordType === 'credit_account') {
      await CreditAccountService.createCreditAccount(AILiveMapping.toCreateCreditAccountInput(item))
    } else {
      await DebtService.createDebt(AILiveMapping.toCreateDebtInput(item))
    }
  }
}
