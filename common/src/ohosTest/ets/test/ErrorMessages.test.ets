import { describe, it, expect } from '@ohos/hypium'
import { ErrorMessages } from '../../../main/ets/common/ErrorMessages'

export default function errorMessagesTest() {
  describe('ErrorMessages', () => {

    // ─── 静态常量 ──────────────────────────────────────────
    describe('ErrorMessages_StaticConstants', () => {
      it('失败消息非空', 0, () => {
        expect(ErrorMessages.SAVE_FAILED.length > 0).assertTrue()
        expect(ErrorMessages.IMPORT_FAILED.length > 0).assertTrue()
        expect(ErrorMessages.CLEAR_FAILED.length > 0).assertTrue()
        expect(ErrorMessages.CLEARING.length > 0).assertTrue()
        expect(ErrorMessages.EXPORTING.length > 0).assertTrue()
        expect(ErrorMessages.IMPORTING.length > 0).assertTrue()
        expect(ErrorMessages.INIT_FAILED.length > 0).assertTrue()
        expect(ErrorMessages.SYNC_FAILED.length > 0).assertTrue()
        expect(ErrorMessages.NETWORK_FAILED.length > 0).assertTrue()
        expect(ErrorMessages.UNKNOWN.length > 0).assertTrue()
      })
      it('成功消息非空', 0, () => {
        expect(ErrorMessages.SAVE_OK.length > 0).assertTrue()
        expect(ErrorMessages.SAVED.length > 0).assertTrue()
        expect(ErrorMessages.CANCELLED.length > 0).assertTrue()
        expect(ErrorMessages.DATA_CLEARED.length > 0).assertTrue()
        expect(ErrorMessages.EXPORT_JSON_OK.length > 0).assertTrue()
        expect(ErrorMessages.IMPORT_OK.length > 0).assertTrue()
      })
      it('引导消息非空', 0, () => {
        expect(ErrorMessages.INPUT_REQUIRED.length > 0).assertTrue()
        expect(ErrorMessages.AI_NEED_KEY.length > 0).assertTrue()
        expect(ErrorMessages.CONSENT_REQUIRED.length > 0).assertTrue()
      })
    })

    // ─── userFacing ─────────────────────────────────────────
    describe('userFacing', () => {

      it('undefined返回fallback', 0, () => {
        expect(ErrorMessages.userFacing(undefined, '默认错误')).assertEqual('默认错误')
      })
      it('null返回fallback', 0, () => {
        expect(ErrorMessages.userFacing(null, '默认错误')).assertEqual('默认错误')
      })
      it('空字符串返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('', '默认错误')).assertEqual('默认错误')
        expect(ErrorMessages.userFacing('   ', '默认错误')).assertEqual('默认错误')
      })
      it('JSON字符串返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('{"error":"bad"}', '默认错误')).assertEqual('默认错误')
      })
      it('Error:前缀返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('Error: something', '默认错误')).assertEqual('默认错误')
      })
      it('含at 堆栈返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('at Object.foo', '默认错误')).assertEqual('默认错误')
      })
      it('HTTP_前缀返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('HTTP_BAD_REQUEST', '默认错误')).assertEqual('默认错误')
      })
      it('PARSING_前缀返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('PARSING_ERROR', '默认错误')).assertEqual('默认错误')
      })
      it('VISION_前缀返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('VISION_FAIL', '默认错误')).assertEqual('默认错误')
      })
      it('HTTP 前缀返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('HTTP 500', '默认错误')).assertEqual('默认错误')
      })
      it('JWT过期返回SYNC_AUTH_EXPIRED', 0, () => {
        expect(ErrorMessages.userFacing('jwt expired token', '默认')).assertEqual(ErrorMessages.SYNC_AUTH_EXPIRED)
      })
      it('expired关键字返回SYNC_AUTH_EXPIRED', 0, () => {
        expect(ErrorMessages.userFacing('token has expired', '默认')).assertEqual(ErrorMessages.SYNC_AUTH_EXPIRED)
      })
      it('401返回SYNC_AUTH_EXPIRED', 0, () => {
        expect(ErrorMessages.userFacing('401 unauthorized', '默认')).assertEqual(ErrorMessages.SYNC_AUTH_EXPIRED)
      })
      it('403返回SYNC_AUTH_EXPIRED', 0, () => {
        expect(ErrorMessages.userFacing('403 forbidden', '默认')).assertEqual(ErrorMessages.SYNC_AUTH_EXPIRED)
      })
      it('拉取失败有fallback返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('拉取失败', '自定义提示')).assertEqual('自定义提示')
      })
      it('推送失败有fallback返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('推送失败', '自定义提示')).assertEqual('自定义提示')
      })
      it('拉取失败空fallback返回SYNC_FAILED', 0, () => {
        expect(ErrorMessages.userFacing('拉取失败', '')).assertEqual(ErrorMessages.SYNC_FAILED)
      })
      it('access_token有fallback返回fallback', 0, () => {
        expect(ErrorMessages.userFacing('access_token invalid', '自定义')).assertEqual('自定义')
      })
      it('refresh_token空fallback返回SYNC_FAILED', 0, () => {
        expect(ErrorMessages.userFacing('refresh_token bad', '')).assertEqual(ErrorMessages.SYNC_FAILED)
      })
      it('普通字符串直接返回', 0, () => {
        expect(ErrorMessages.userFacing('网络超时', '默认')).assertEqual('网络超时')
      })
      it('超长字符串截断加省略号', 0, () => {
        const longStr = 'a'.repeat(100)
        const result = ErrorMessages.userFacing(longStr, '默认')
        expect(result.length).assertEqual(81)
        expect(result.endsWith('…')).assertTrue()
      })
      it('80字符以内不截断', 0, () => {
        const str = 'a'.repeat(80)
        const result = ErrorMessages.userFacing(str, '默认')
        expect(result.length).assertEqual(80)
      })
      it('数字类型返回fallback', 0, () => {
        expect(ErrorMessages.userFacing(404 as Object, '默认')).assertEqual('默认')
      })
      it('布尔类型返回fallback', 0, () => {
        expect(ErrorMessages.userFacing(true as Object, '默认')).assertEqual('默认')
      })
      it('对象类型返回fallback', 0, () => {
        const obj: Record<string, string> = { 'k': 'v' }
        expect(ErrorMessages.userFacing(obj as Object, '默认')).assertEqual('默认')
      })
    })
  })
}
