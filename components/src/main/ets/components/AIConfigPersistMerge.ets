/**
 * AI 配置落盘合并：HarmonyOS TextInput 失焦/重建会一次 onChange('')，
 * 不能把已存的 Key / Base URL / 模型盖成空（表现为重启后配置丢失）。
 */
export class AIConfigPersistMerge {
  /**
   * 草稿空且用户未点「清除」→ 保留库里的值。
   */
  static pickField(draft: string, stored: string, cleared: boolean): string {
    if (draft.trim().length > 0) {
      return draft
    }
    if (cleared) {
      return ''
    }
    return stored
  }

  /**
   * 从完整值一次跳到空串视为控件伪事件，不是逐字删到空。
   */
  static shouldAcceptFieldChange(prev: string, next: string): boolean {
    if (prev === next) {
      return false
    }
    if (next.length === 0 && prev.length > 1) {
      return false
    }
    return true
  }

  /**
   * 草稿指纹被伪清空时，若合并后的三项仍匹配库里的指纹则保留，避免「已接通」丢了。
   */
  static pickFingerprint(draftFp: string, storedFp: string, key: string, url: string,
    model: string, cleared: boolean): string {
    if (cleared) {
      return ''
    }
    if (draftFp.length > 0) {
      return draftFp
    }
    const fp = key + '\n' + url + '\n' + model
    if (storedFp.length > 0 && storedFp === fp) {
      return storedFp
    }
    return ''
  }
}
