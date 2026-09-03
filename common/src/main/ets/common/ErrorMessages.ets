/**
 * 面向用户的 Toast / 提示文案（上架 M5）
 * 失败、成功、引导统一从此取；日志仍可用 stringify
 */
export class ErrorMessages {
  // ——— 通用失败 ———
  static readonly SAVE_FAILED: string = '保存失败，请稍后重试'
  static readonly IMPORT_FAILED: string = '导入失败，请确认备份为应用导出的 JSON 后重试'
  static readonly CLEAR_FAILED: string = '操作未完成，请稍后重试'
  static readonly CLEARING: string = '正在清空…'
  static readonly EXPORTING: string = '正在导出…'
  static readonly IMPORTING: string = '正在导入…'
  static readonly CLEAR_CLOUD_FAILED: string = '本机数据已清空，云端未清完，请联网后重试（否则重新登录时可能被同步回来）'
  static readonly INIT_FAILED: string = '启动失败，请关闭后重新打开应用'
  static readonly SYNC_FAILED: string = '同步失败，请检查网络与登录状态'
  static readonly SYNC_AUTH_EXPIRED: string = '云同步登录已过期，请重新登录'
  static readonly SESSION_REVOKED: string = '登录已失效（密码可能在其他设备修改），请重新登录'
  static readonly NETWORK_FAILED: string = '网络异常，请稍后重试'
  static readonly ICON_FETCH_FAILED: string = '图标获取失败，请检查链接或网络'
  static readonly UNKNOWN: string = '操作失败，请稍后重试'
  static readonly AI_CONNECT_FAILED: string = '连接失败，请检查 Key、地址与模型后重试'
  static readonly CONTEXT_UNAVAILABLE: string = '暂时无法打开，请稍后重试'
  static readonly PARSE_FAILED: string = '解析失败，请检查网络与 AI 配置后重试'
  static readonly REPAY_FAILED: string = '还款失败，请稍后重试'
  static readonly EXPORT_FAILED: string = '导出失败，请重试或检查存储权限'
  static readonly FILE_NOT_SELECTED: string = '未选择文件'
  static readonly EMPTY_CSV: string = 'CSV 中无可用数据'
  static readonly LOCK_FAILED: string = '操作未完成，请稍后重试'

  // ——— 认证 / 找回密码（GoTrue 英文错误转中文） ———
  static readonly AUTH_RATE_LIMITED: string = '操作太频繁，请稍后再试（邮件发送有频率限制）'
  static readonly AUTH_CODE_INVALID: string = '验证码无效或已过期，请重新获取'
  static readonly AUTH_WEAK_PASSWORD: string = '密码至少 6 位，请重新设置'
  static readonly AUTH_SAME_PASSWORD: string = '新密码不能与旧密码相同'

  // ——— 成功 ———
  static readonly SAVE_OK: string = '保存成功'
  static readonly SAVED: string = '已保存'
  /** 表单新增成功 */
  static readonly CREATE_OK: string = '添加成功'
  /** 表单编辑成功 */
  static readonly UPDATE_OK: string = '修改成功'
  /** 删除成功 */
  static readonly DELETE_OK: string = '删除成功'
  /** 删除失败 */
  static readonly DELETE_FAILED: string = '删除失败，请稍后重试'
  static readonly CANCELLED: string = '已取消'
  static readonly DATA_CLEARED: string = '数据已清空'
  static readonly EXPORT_JSON_OK: string = 'JSON 备份已保存'
  static readonly EXPORT_CSV_OK: string = 'CSV 已导出'
  static readonly IMPORT_OK: string = '导入完成'
  static readonly AI_CONNECT_OK: string = '连接成功，已保存'
  static readonly LOCK_SET: string = '应用锁已设置'
  static readonly LOCK_OFF: string = '应用锁已关闭'
  static readonly LOCK_VERIFIED: string = '验证通过'
  static readonly REPAY_PERIOD_OK: string = '本期还款成功'
  static readonly REPAY_PAYOFF_OK: string = '已一次性还清'

  // ——— 引导 / 状态 ———
  static readonly INPUT_REQUIRED: string = '请先输入内容'
  static readonly AI_NEED_KEY: string = '请先填写 API Key'
  static readonly AI_NEED_BASE_URL: string = '请先填写 Base URL 或选择服务商'
  static readonly AI_NEED_MODEL: string = '请先填写模型（如 deepseek-chat）'
  static readonly CONSENT_REQUIRED: string = '请先阅读并勾选同意隐私政策与用户协议'
  static readonly DEBT_ALREADY_SETTLED: string = '该负债已结清'
  static readonly DEBT_STATUS_CHANGED: string = '负债状态已变更'
  static readonly NO_BREAKDOWN: string = '暂无构成数据'
  static readonly NFC_UNSUPPORTED: string = '设备不支持 NFC'
  static readonly NFC_OFF: string = '请先开启 NFC 开关'
  static readonly NFC_TAP_TAG: string = '请将设备靠近空白 NFC 标签完成写入'
  static readonly LIGHT_DARK: string = '光线较暗，建议开启深色模式护眼'
  static readonly LIGHT_BRIGHT: string = '光线较强，请注意护眼'

  /**
   * 将底层错误转为短文案；不向用户展示堆栈或 JSON
   */
  static userFacing(err: Object | string | number | boolean | null | undefined, fallback: string): string {
    if (err === undefined || err === null) {
      return fallback
    }
    if (typeof err === 'string') {
      const s = err.trim()
      if (s.length === 0) {
        return fallback
      }
      // 过滤明显的开发向内容
      if (s.indexOf('{') === 0 || s.indexOf('Error:') === 0 || s.indexOf('at ') >= 0) {
        return fallback
      }
      if (s.indexOf('HTTP_') === 0 || s.indexOf('PARSING_') === 0 ||
        s.indexOf('VISION_') === 0 || s.indexOf('HTTP ') === 0) {
        return fallback
      }
      // 鉴权/同步内部错误：不把 JWT、表名、HTTP 码抛给用户
      const lower = s.toLowerCase()
      if (lower.indexOf('jwt') >= 0 || lower.indexOf('expired') >= 0 ||
        s.indexOf('401') >= 0 || s.indexOf('403') >= 0 ||
        s.indexOf('拉取失败') >= 0 || s.indexOf('推送失败') >= 0 ||
        s.indexOf('access_token') >= 0 || s.indexOf('refresh_token') >= 0) {
        if (lower.indexOf('jwt') >= 0 || lower.indexOf('expired') >= 0 ||
          s.indexOf('401') >= 0 || s.indexOf('403') >= 0) {
          return ErrorMessages.SYNC_AUTH_EXPIRED
        }
        return fallback.length > 0 ? fallback : ErrorMessages.SYNC_FAILED
      }
      return s.length > 80 ? s.substring(0, 80) + '…' : s
    }
    return fallback
  }

  /**
   * 认证 / 找回密码场景：先把常见 GoTrue 英文错误映射为中文友好文案；
   * 未命中且不含中文的一律用中文兜底，避免把 GoTrue 英文原文透给用户
   */
  static auth(err: Object | string | number | boolean | null | undefined, fallback: string): string {
    if (typeof err === 'string') {
      const raw = err.trim()
      const lower = raw.toLowerCase()
      if (lower.length > 0) {
        // 网络/超时（鸿蒙网络层 BusinessError 可能中英混合）：优先转中文，避免英文透传
        if (lower.indexOf('timeout') >= 0 || lower.indexOf('timed out') >= 0 ||
          lower.indexOf('network') >= 0 || lower.indexOf('unreachable') >= 0 ||
          lower.indexOf('failed to connect') >= 0 || lower.indexOf('connection') >= 0) {
          return ErrorMessages.NETWORK_FAILED
        }
        if (lower.indexOf('rate limit') >= 0 || lower.indexOf('you can only request this after') >= 0 ||
          lower.indexOf('over_email_send_rate_limit') >= 0 || lower.indexOf('over_request_rate_limit') >= 0) {
          return ErrorMessages.AUTH_RATE_LIMITED
        }
        if (lower.indexOf('otp_expired') >= 0 ||
          (lower.indexOf('token') >= 0 && (lower.indexOf('expired') >= 0 || lower.indexOf('invalid') >= 0))) {
          return ErrorMessages.AUTH_CODE_INVALID
        }
        if (lower.indexOf('new password should be different') >= 0 || lower.indexOf('same_password') >= 0) {
          return ErrorMessages.AUTH_SAME_PASSWORD
        }
        if (lower.indexOf('weak_password') >= 0 || lower.indexOf('password should be at least') >= 0) {
          return ErrorMessages.AUTH_WEAK_PASSWORD
        }
        // 未命中具体映射且不含中文：视为 GoTrue 开发向英文错误，统一中文兜底，不透传
        if (!ErrorMessages.hasChinese(raw)) {
          return fallback
        }
      }
    }
    return ErrorMessages.userFacing(err, fallback)
  }

  /** 是否含 CJK 汉字（用于判断错误文案是否已本地化） */
  private static hasChinese(s: string): boolean {
    for (let i = 0; i < s.length; i++) {
      const c = s.charCodeAt(i)
      if (c >= 0x4e00 && c <= 0x9fff) {
        return true
      }
    }
    return false
  }
}
