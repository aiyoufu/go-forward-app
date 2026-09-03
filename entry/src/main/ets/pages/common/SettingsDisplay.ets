/**
 * 设置页展示文案（从 SettingsTab 拆出）
 * 纯函数：输入标量/快照，输出文案；不触碰组件状态
 */
import { SyncStatusSnapshot } from 'service'

/** 账户主标题：昵称 > 邮箱 > 已登录 > 未登录 */
export function accountLabel(profileNickname: string, sessionEmail: string,
  cloudSession: boolean): string {
  if (profileNickname.length > 0) {
    return profileNickname
  }
  if (sessionEmail.length > 0) {
    return sessionEmail
  }
  if (cloudSession) {
    return '已登录'
  }
  return '未登录'
}

/** 账户副标题：设置了昵称且有邮箱时展示邮箱 */
export function accountSubtitle(profileNickname: string, sessionEmail: string): string {
  if (profileNickname.length > 0 && sessionEmail.length > 0) {
    return sessionEmail
  }
  return ''
}

/** 头像占位字符：昵称/邮箱首字母，缺省 G */
export function accountMark(profileNickname: string, sessionEmail: string): string {
  if (profileNickname.length > 0) {
    return profileNickname.substring(0, 1).toUpperCase()
  }
  if (sessionEmail.length > 0) {
    return sessionEmail.substring(0, 1).toUpperCase()
  }
  return 'G'
}

/** 邮箱前缀：@ 之前的部分；无 @ 时原样返回 */
function emailPrefix(email: string): string {
  const at = email.indexOf('@')
  return at > 0 ? email.substring(0, at) : email
}

/** 首页问候名：昵称 > 邮箱前缀；都缺省返回空串（只留问候语） */
export function greetingName(profileNickname: string, sessionEmail: string): string {
  if (profileNickname.length > 0) {
    return profileNickname
  }
  if (sessionEmail.length > 0) {
    return emailPrefix(sessionEmail)
  }
  return ''
}

/** 编号补零至至少 4 位 */
function padMemberNo(no: number): string {
  let s = '' + Math.floor(no)
  while (s.length < 4) {
    s = '0' + s
  }
  return s
}

/** 创始版徽章文案：有创始编号时追加 No.xxxx，否则仅显示「创始版」 */
export function foundingBadgeText(memberNo: number): string {
  if (memberNo > 0) {
    return '创始版 · No.' + padMemberNo(memberNo)
  }
  return '创始版'
}

/** 同步行右侧状态文字 */
export function syncStatusText(cloudSession: boolean, snap: SyncStatusSnapshot, running: boolean): string {
  if (!cloudSession) {
    return '登录后可用'
  }
  if (snap.phase === 'syncing' || running) {
    return '同步中'
  }
  if (snap.phase === 'error') {
    return '同步失败'
  }
  if (snap.outboxPending > 0) {
    return '待上传 ' + snap.outboxPending
  }
  if (snap.phase === 'ok' && snap.lastSuccessAt.length > 0) {
    return '已同步'
  }
  return '点击同步'
}
