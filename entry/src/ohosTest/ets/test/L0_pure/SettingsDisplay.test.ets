import { describe, it, expect } from '@ohos/hypium'
import {
  accountLabel,
  accountSubtitle,
  accountMark,
  greetingName,
  foundingBadgeText,
  syncStatusText
} from '../../../../main/ets/pages/common/SettingsDisplay'
import { SyncStatusSnapshot } from 'service'

function snapshot(phase: string, outboxPending: number, lastSuccessAt: string): SyncStatusSnapshot {
  const s = new SyncStatusSnapshot()
  s.phase = phase
  s.outboxPending = outboxPending
  s.lastSuccessAt = lastSuccessAt
  return s
}

export default function settingsDisplayTest() {
  describe('SettingsDisplay', () => {
    it('accountLabel_优先昵称', 0, () => {
      expect(accountLabel('小明', 'a@b.c', true)).assertEqual('小明')
    })

    it('accountLabel_无昵称用邮箱', 0, () => {
      expect(accountLabel('', 'a@b.c', false)).assertEqual('a@b.c')
    })

    it('accountLabel_云会话无昵称无邮箱', 0, () => {
      expect(accountLabel('', '', true)).assertEqual('已登录')
    })

    it('accountLabel_未登录', 0, () => {
      expect(accountLabel('', '', false)).assertEqual('未登录')
    })

    it('accountSubtitle_有昵称有邮箱才显示', 0, () => {
      expect(accountSubtitle('小明', 'a@b.c')).assertEqual('a@b.c')
      expect(accountSubtitle('', 'a@b.c')).assertEqual('')
    })

    it('accountMark_取首字母大写', 0, () => {
      expect(accountMark('ming', '')).assertEqual('M')
      expect(accountMark('', 'abc@x.com')).assertEqual('A')
      expect(accountMark('', '')).assertEqual('G')
    })

    it('greetingName_优先昵称', 0, () => {
      expect(greetingName('小明', 'a@b.c')).assertEqual('小明')
    })

    it('greetingName_无昵称取邮箱前缀', 0, () => {
      expect(greetingName('', 'abc@x.com')).assertEqual('abc')
      expect(greetingName('', 'no-at-sign')).assertEqual('no-at-sign')
    })

    it('greetingName_全空返回空串', 0, () => {
      expect(greetingName('', '')).assertEqual('')
    })

    it('foundingBadgeText_带编号补零', 0, () => {
      expect(foundingBadgeText(7)).assertEqual('创始版 · No.0007')
      expect(foundingBadgeText(0)).assertEqual('创始版')
    })

    it('syncStatusText_未登录提示', 0, () => {
      expect(syncStatusText(false, snapshot('idle', 0, ''), false)).assertEqual('登录后可用')
    })

    it('syncStatusText_同步中与失败', 0, () => {
      expect(syncStatusText(true, snapshot('syncing', 0, ''), false)).assertEqual('同步中')
      expect(syncStatusText(true, snapshot('error', 0, ''), false)).assertEqual('同步失败')
    })

    it('syncStatusText_待上传与已同步', 0, () => {
      expect(syncStatusText(true, snapshot('ok', 3, ''), false)).assertEqual('待上传 3')
      expect(syncStatusText(true, snapshot('ok', 0, '2025-05-01'), false)).assertEqual('已同步')
      expect(syncStatusText(true, snapshot('idle', 0, ''), false)).assertEqual('点击同步')
    })
  })
}
