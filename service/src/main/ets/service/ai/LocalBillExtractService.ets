/**
 * 端侧单据规则抽取（无网络）— 编排入口。
 * 与 Core Vision OCR 配合：OCR 出字后优先本服务秒级结构化，
 * 再不足时才调文字 LLM / 视觉模型。
 *
 * 解析实现已拆分：
 * - 分期计划表截图 OCR → BillPlanParser
 * - 自然语言描述 → BillNaturalParser
 * - 共享工具 → BillParseShared
 */
import { ParseResult } from './AIService'
import { normalizeText } from './BillParseShared'
import { looksLikeBillOcr, tryInstallmentPlanTable } from './BillPlanParser'
import { tryNaturalLanguageDebt } from './BillNaturalParser'

export class LocalBillExtractService {
  /**
   * 尝试从纯文本抽取负债等；无法可靠识别时返回 null（交给 LLM）。
   */
  static tryExtract(raw: string): ParseResult | null {
    const text = normalizeText(raw)
    if (text.length < 6) {
      return null
    }
    const fromPlan = tryInstallmentPlanTable(text)
    if (fromPlan !== null) {
      return fromPlan
    }
    const fromNl = tryNaturalLanguageDebt(text)
    if (fromNl !== null) {
      return fromNl
    }
    return null
  }

  /**
   * 可跳过云端的结果：有金额类字段即可（平台可默认「未知」）。
   * 宁可本地秒出再让用户改字段，也不要卡在云端几十秒。
   */
  static isResultUsable(result: ParseResult): boolean {
    if (result.items.length === 0) {
      return false
    }
    for (let i = 0; i < result.items.length; i++) {
      const it = result.items[i]
      const bal = it.parsedFields.get('current_balance')
      const monthly = it.parsedFields.get('monthly_payment')
      const periods = it.parsedFields.get('total_periods')
      if (bal !== undefined && bal !== null) {
        return true
      }
      if (monthly !== undefined && monthly !== null) {
        return true
      }
      if (periods !== undefined && periods !== null) {
        return true
      }
    }
    return false
  }

  /** 宽松分期表检测：OCR 常把「期」识别成「其」或漏字 */
  static looksLikeBillOcr(text: string): boolean {
    return looksLikeBillOcr(text)
  }
}
