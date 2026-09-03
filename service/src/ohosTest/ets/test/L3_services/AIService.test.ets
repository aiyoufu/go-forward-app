import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { AIService } from '../../mock/AIService.mock'
import { SettingsService } from '../../mock/SettingsService.mock'

export default function aiServiceTest() {
  beforeEach(() => {
    SettingsService._reset()
  })

  // ── resolveChatCompletionsUrl（纯逻辑）────────────────
  describe('AIService_resolveChatCompletionsUrl', () => {
    it('空字符串_返回OpenAI默认地址', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('')
      expect(url).assertEqual('https://api.openai.com/v1/chat/completions')
    })

    it('已含chat/completions_原样返回', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('https://example.com/v1/chat/completions')
      expect(url).assertEqual('https://example.com/v1/chat/completions')
    })

    it('仅根地址_拼接chat/completions', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('https://example.com/v1')
      expect(url).assertEqual('https://example.com/v1/chat/completions')
    })

    it('尾部斜杠_去除后拼接', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('https://example.com/v1/')
      expect(url).assertEqual('https://example.com/v1/chat/completions')
    })

    it('多尾部斜杠_全部去除', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('https://example.com/v1///')
      expect(url).assertEqual('https://example.com/v1/chat/completions')
    })

    it('含空格_先trim', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('  https://example.com/v1  ')
      expect(url).assertEqual('https://example.com/v1/chat/completions')
    })

    it('仅斜杠_不继续去除', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl('/')
      // '/' → length=1, while loop stops → doesn't end with /chat/completions → append
      expect(url.indexOf('chat/completions') >= 0).assertTrue()
    })

    it('火山CodingPlan_Anthropic根_纠正为v3并拼chat', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl(
        'https://ark.cn-beijing.volces.com/api/coding')
      expect(url).assertEqual(
        'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions')
    })

    it('火山CodingPlan_已是v3_只拼chat', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl(
        'https://ark.cn-beijing.volces.com/api/coding/v3')
      expect(url).assertEqual(
        'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions')
    })

    it('火山CodingPlan_尾斜杠_同样纠正', 0, async () => {
      const url = AIService.resolveChatCompletionsUrl(
        'https://ark.cn-beijing.volces.com/api/coding/')
      expect(url).assertEqual(
        'https://ark.cn-beijing.volces.com/api/coding/v3/chat/completions')
    })
  })

  // ── normalizeVolcCodingPlanOpenAiBase ────────────────
  describe('AIService_normalizeVolcCodingPlanOpenAiBase', () => {
    it('非火山地址_原样返回', 0, async () => {
      const u = AIService.normalizeVolcCodingPlanOpenAiBase('https://api.deepseek.com')
      expect(u).assertEqual('https://api.deepseek.com')
    })

    it('Anthropic根_补v3', 0, async () => {
      const u = AIService.normalizeVolcCodingPlanOpenAiBase(
        'https://ark.cn-beijing.volces.com/api/coding')
      expect(u).assertEqual('https://ark.cn-beijing.volces.com/api/coding/v3')
    })

    it('已是v3_不变', 0, async () => {
      const u = AIService.normalizeVolcCodingPlanOpenAiBase(
        'https://ark.cn-beijing.volces.com/api/coding/v3')
      expect(u).assertEqual('https://ark.cn-beijing.volces.com/api/coding/v3')
    })
  })

  describe('AIService_normalizeApiKey', () => {
    it('去空白', 0, async () => {
      expect(AIService.normalizeApiKey('  sk-ab cd\n')).assertEqual('sk-abcd')
    })
  })

  describe('AIService_isOpenAiCompatibleConfig', () => {
    it('火山coding_v3_即使anthropic也按OpenAI', 0, async () => {
      expect(AIService.isOpenAiCompatibleConfig(
        'https://ark.cn-beijing.volces.com/api/coding/v3', 'anthropic')).assertTrue()
    })
    it('纯anthropic地址_anthropic格式_不兼容', 0, async () => {
      expect(AIService.isOpenAiCompatibleConfig(
        'https://api.anthropic.com', 'anthropic')).assertFalse()
    })
  })

  // ── loadTextChannelConfig ──────────────────────────────
  describe('AIService_loadTextChannelConfig', () => {
    it('返回配置对象', 0, async () => {
      const config = await AIService.loadTextChannelConfig('test-user')
      expect(config !== undefined).assertTrue()
      expect(config.enabled).assertTrue()
      expect(config.key).assertEqual('mock-api-key')
      expect(config.baseUrl).assertEqual('https://api.mock.com')
      expect(config.model).assertEqual('mock-model')
    })
  })

  // ── loadVisionChannelConfig ──────────────────────────────
  describe('AIService_loadVisionChannelConfig', () => {
    it('返回配置对象', 0, async () => {
      const config = await AIService.loadVisionChannelConfig('test-user')
      expect(config !== undefined).assertTrue()
      expect(config.enabled).assertTrue()
      expect(config.key).assertEqual('mock-api-key')
    })
  })

  // ── parseDebtText ──────────────────────────────
  describe('AIService_parseDebtText', () => {
    it('返回预设结果', 0, async () => {
      const config = { enabled: true, key: 'test-key' }
      const result = await AIService.parseDebtText('京东白条分期6期', config)
      expect(result !== undefined).assertTrue()
    })
  })

  // ── parseDebtFromImage ──────────────────────────────
  describe('AIService_parseDebtFromImage', () => {
    it('返回预设结果', 0, async () => {
      const config = { enabled: true, key: 'test-key' }
      const result = await AIService.parseDebtFromImage('base64data', config)
      expect(result !== undefined).assertTrue()
    })
  })

  // ── testConnection ──────────────────────────────
  describe('AIService_testConnection', () => {
    it('mock返回true', 0, async () => {
      const result = await AIService.testConnection('key', 'https://api.test.com', 'model')
      expect(result).assertTrue()
    })
  })

  // ── testConnectionDetailed ──────────────────────────────
  describe('AIService_testConnectionDetailed', () => {
    it('mock返回成功', 0, async () => {
      const result = await AIService.testConnectionDetailed('key', 'https://api.test.com', 'model')
      expect(result.ok).assertTrue()
      expect(result.message).assertEqual('连接成功')
    })
  })
}
