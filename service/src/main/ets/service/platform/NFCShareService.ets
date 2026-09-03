import { tag, nfcController } from '@kit.ConnectivityKit'
import { Debt } from 'common'
import { CreditAccount } from 'common'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppToast } from 'common'
import { ErrorMessages } from 'common'

export class NFCSharePayload {
  type: string = 'debt'
  version: string = '1.0'
  platform: string = ''
  currentBalanceFen: number = 0
  monthlyPaymentFen: number = 0
  nextPaymentDate: string = ''
  note: string = ''
  accountName: string = ''
  accountLastFour: string = ''
}

export class NFCShareService {
  static readonly MIME_TYPE: string = 'application/vnd.goforward.nfcshare'

  static buildDebtSummary(debt: Debt): NFCSharePayload {
    const payload = new NFCSharePayload()
    payload.type = 'debt'
    payload.platform = debt.platform
    payload.currentBalanceFen = debt.current_balance
    payload.monthlyPaymentFen = debt.monthly_payment
    payload.nextPaymentDate = debt.next_payment_date
    payload.note = debt.note
    return payload
  }

  static buildAccountSummary(account: CreditAccount): NFCSharePayload {
    const payload = new NFCSharePayload()
    payload.type = 'account'
    payload.platform = account.name
    payload.accountName = account.name
    payload.accountLastFour = account.last_four
    payload.note = '信用账户分享'
    return payload
  }

  static writeDebtToTag(payload: NFCSharePayload): void {
    if (!canIUse('SystemCapability.Communication.NFC.Tag')) {
      AppToast.show(ErrorMessages.NFC_UNSUPPORTED, 2000)
      return
    }

    if (!canIUse('SystemCapability.Communication.NFC.Core') || !nfcController.isNfcOpen()) {
      AppToast.show(ErrorMessages.NFC_OFF, 2000)
      return
    }

    const json = JSON.stringify(payload)
    const bytes = NFCShareService.stringToNumberArray(json)
    if (canIUse('SystemCapability.Communication.NFC.Tag')) {
      const record = tag.ndef.makeMimeRecord(NFCShareService.MIME_TYPE, bytes)
      const message = tag.ndef.createNdefMessage([record])
      // 预留：将来通过 tagSession.writeNdef(message) 实际写入
      void message
    }

    AppToast.show(ErrorMessages.NFC_TAP_TAG, 3000)
    // 仅记长度，禁止把 payload/message 打到日志（含余额等敏感字段）
    hilog.info(0x0000, 'NFCShare', 'NDEF message ready, length=%{public}d', bytes.length)
  }

  static parsePayload(jsonText: string): NFCSharePayload | null {
    try {
      return JSON.parse(jsonText) as NFCSharePayload
    } catch {
      return null
    }
  }

  static numberArrayToString(bytes: number[]): string {
    let str = ''
    let i = 0
    while (i < bytes.length) {
      const b = bytes[i]
      if (b < 0x80) {
        str += String.fromCharCode(b)
        i++
      } else if ((b & 0xE0) === 0xC0 && i + 1 < bytes.length) {
        const rune = ((b & 0x1F) << 6) | (bytes[i + 1] & 0x3F)
        str += String.fromCharCode(rune)
        i += 2
      } else if ((b & 0xF0) === 0xE0 && i + 2 < bytes.length) {
        const rune = ((b & 0x0F) << 12) | ((bytes[i + 1] & 0x3F) << 6) | (bytes[i + 2] & 0x3F)
        str += String.fromCharCode(rune)
        i += 3
      } else if ((b & 0xF8) === 0xF0 && i + 3 < bytes.length) {
        const rune = ((b & 0x07) << 18) | ((bytes[i + 1] & 0x3F) << 12) | ((bytes[i + 2] & 0x3F) << 6) | (bytes[i + 3] & 0x3F)
        str += String.fromCodePoint(rune)
        i += 4
      } else {
        str += String.fromCharCode(b)
        i++
      }
    }
    return str
  }

  private static stringToNumberArray(text: string): number[] {
    const arr: number[] = []
    for (let i = 0; i < text.length; i++) {
      const code = text.charCodeAt(i)
      if (code < 0x80) {
        arr.push(code)
      } else if (code < 0x800) {
        arr.push(0xC0 | (code >> 6))
        arr.push(0x80 | (code & 0x3F))
      } else if (code < 0xD800 || code >= 0xE000) {
        arr.push(0xE0 | (code >> 12))
        arr.push(0x80 | ((code >> 6) & 0x3F))
        arr.push(0x80 | (code & 0x3F))
      } else {
        const next = text.charCodeAt(i + 1)
        const rune = 0x10000 + ((code & 0x3FF) << 10) | (next & 0x3FF)
        arr.push(0xF0 | (rune >> 18))
        arr.push(0x80 | ((rune >> 12) & 0x3F))
        arr.push(0x80 | ((rune >> 6) & 0x3F))
        arr.push(0x80 | (rune & 0x3F))
        i++
      }
    }
    return arr
  }
}
