import { describe, it, expect } from '@ohos/hypium'
import { AIService } from '../../../../main/ets/service/ai/AIService'

export default function aiServiceConnectionTest() {
  describe('AIService_connectionHints', () => {
    it('hostOf去掉协议和路径', 0, () => {
      const host = AIService.hostOf(
        'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions')
      expect(host).assertEqual('ark.cn-beijing.volces.com')
    })

    it('describeCaughtError读取BusinessError形态对象', 0, () => {
      const rec: Record<string, number | string> = {
        'code': 2300028,
        'message': 'Operation timeout'
      }
      const raw = AIService.describeCaughtError(rec)
      expect(raw.indexOf('2300028') >= 0).assertTrue()
      expect(raw.toLowerCase().indexOf('timeout') >= 0).assertTrue()
    })

    it('hintFromCaughtError超时带出主机名', 0, () => {
      const rec: Record<string, number | string> = {
        'code': 2300028,
        'message': 'timeout'
      }
      const hint = AIService.hintFromCaughtError(rec,
        'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions')
      expect(hint.indexOf('连接超时') >= 0).assertTrue()
      expect(hint.indexOf('ark.cn-beijing.volces.com') >= 0).assertTrue()
    })

    it('testResultToast优先详细失败文案', 0, () => {
      const toast = AIService.testResultToast(false, '连接超时：请检查 Base URL',
        '连接成功，已保存', '连接失败，请检查 Key、地址与模型后重试')
      expect(toast).assertEqual('连接超时：请检查 Base URL')
    })

    it('testResultToast成功用成功文案', 0, () => {
      const toast = AIService.testResultToast(true, '连接成功',
        '连接成功，已保存', '连接失败')
      expect(toast).assertEqual('连接成功，已保存')
    })
  })
}
