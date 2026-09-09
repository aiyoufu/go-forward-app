import { describe, it, expect, beforeEach } from '@ohos/hypium'
import { AIParseOrchestrator, AIImageParseOutcome } from '../../../../main/ets/service/ai/AIParseOrchestrator'
import { UserSettings, AIChannelConfig } from 'common'
import { AIService, ParseResult, ParseResultItem } from '../../mock/AIService.mock'
import { SettingsService } from '../../mock/SettingsService.mock'
import { UserService } from '../../mock/UserService.mock'
import { CreditAccountService } from '../../mock/CreditAccountService.mock'

function makeSettings(overrides: Record<string, string | number | boolean> = {}): UserSettings {
  const s = new UserSettings()
  s.user_id = 'test-user-001'
  s.ai_text_enabled = true
  s.ai_text_key = 'sk-test-key'
  s.ai_text_base_url = 'https://api.example.com'
  s.ai_text_model = 'gpt-4'
  s.ai_text_api_format = 'openai'
  s.ai_vision_enabled = true
  s.ai_vision_key = 'sk-vision-key'
  s.ai_vision_base_url = 'https://api.example.com'
  s.ai_vision_model = 'gpt-4-vision'
  s.ai_vision_api_format = 'openai'
  const keys = Object.keys(overrides)
  for (const k of keys) {
    ;(s as Record<string, string | number | boolean>)[k] = overrides[k]
  }
  return s
}

export default function aiParseOrchestratorTest() {
  beforeEach(() => {
    AIService._reset()
    SettingsService._reset()
    UserService._reset()
    CreditAccountService._reset()
  })

  describe('AIParseOrchestrator_canParseText', () => {
    it('有Key_返回true', 0, () => {
      expect(AIParseOrchestrator.canParseText(makeSettings({ ai_text_key: 'sk-xxx' }))).assertTrue()
    })

    it('空Key_返回false', 0, () => {
      expect(AIParseOrchestrator.canParseText(makeSettings({ ai_text_key: '' }))).assertFalse()
    })

    it('纯空白Key_返回false', 0, () => {
      expect(AIParseOrchestrator.canParseText(makeSettings({ ai_text_key: '   ' }))).assertFalse()
    })

    it('带前后空格的Key_返回true', 0, () => {
      expect(AIParseOrchestrator.canParseText(makeSettings({ ai_text_key: '  sk-xxx  ' }))).assertTrue()
    })
  })

  describe('AIParseOrchestrator_checkTextParseReady', () => {
    it('有Key_返回ok=true', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({ ai_text_key: 'sk-xxx' }))
      const r = await AIParseOrchestrator.checkTextParseReady()
      expect(r.ok).assertTrue()
      expect(r.message.length).assertEqual(0)
    })

    it('无Key_返回ok=false并附消息', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({ ai_text_key: '' }))
      const r = await AIParseOrchestrator.checkTextParseReady()
      expect(r.ok).assertFalse()
      expect(r.message.length > 0).assertTrue()
    })

    it('指定userId_使用该userId', 0, async () => {
      SettingsService._setPresetSettings(makeSettings({ ai_text_key: 'sk-xxx' }))
      const r = await AIParseOrchestrator.checkTextParseReady('user-99')
      expect(r.ok).assertTrue()
    })

    it('未预设settings_Key为空_返回false', 0, async () => {
      // SettingsService.mock 默认返回 {} 空对象，ai_text_key 字段读取为 undefined
      const r = await AIParseOrchestrator.checkTextParseReady()
      expect(r.ok).assertFalse()
    })
  })

  describe('AIParseOrchestrator_loadTextConfig', () => {
    it('返回AIService.loadTextChannelConfig结果', 0, async () => {
      const out = await AIParseOrchestrator.loadTextConfig() as AIChannelConfig
      expect(out.enabled).assertTrue()
      expect(out.key.length > 0).assertTrue()
    })
  })

  describe('AIParseOrchestrator_loadVisionConfig', () => {
    it('返回AIService.loadVisionChannelConfig结果', 0, async () => {
      const out = await AIParseOrchestrator.loadVisionConfig() as AIChannelConfig
      expect(out.enabled).assertTrue()
      expect(out.key.length > 0).assertTrue()
    })
  })

  describe('AIParseOrchestrator_parseText', () => {
    it('渠道启用_返回AIService解析结果', 0, async () => {
      const preset = {
        items: [],
        clarifyQuestion: '',
        isComplete: true,
        rawContent: 'MOCK_OK'
      }
      AIService._setPresetParseResult(preset)
      const r = await AIParseOrchestrator.parseText('花呗还款')
      expect(r.rawContent).assertEqual('MOCK_OK')
    })

    it('空文本_仍走解析', 0, async () => {
      AIService._setPresetParseResult({ items: [], clarifyQuestion: '', isComplete: false, rawContent: 'EMPTY' })
      const r = await AIParseOrchestrator.parseText('')
      expect(r.rawContent).assertEqual('EMPTY')
    })
  })

  describe('AIParseOrchestrator_常量', () => {
    it('MSG_TEXT_KEY_REQUIRED非空', 0, () => {
      expect(AIParseOrchestrator.MSG_TEXT_KEY_REQUIRED.length > 0).assertTrue()
    })
    it('MSG_TEXT_PARSE_REQUIRED非空', 0, () => {
      expect(AIParseOrchestrator.MSG_TEXT_PARSE_REQUIRED.length > 0).assertTrue()
    })
    it('MSG_IMAGE_KEY_REQUIRED非空', 0, () => {
      expect(AIParseOrchestrator.MSG_IMAGE_KEY_REQUIRED.length > 0).assertTrue()
    })
    it('MSG_IMAGE_ENCODE_FAIL非空', 0, () => {
      expect(AIParseOrchestrator.MSG_IMAGE_ENCODE_FAIL.length > 0).assertTrue()
    })
    it('MSG_IMAGE_PARSE_FAIL非空', 0, () => {
      expect(AIParseOrchestrator.MSG_IMAGE_PARSE_FAIL.length > 0).assertTrue()
    })
    it('MSG_EMPTY_IMAGE非空', 0, () => {
      expect(AIParseOrchestrator.MSG_EMPTY_IMAGE.length > 0).assertTrue()
    })
    it('MSG_VISION_TIMEOUT非空', 0, () => {
      expect(AIParseOrchestrator.MSG_VISION_TIMEOUT.length > 0).assertTrue()
    })
  })

  describe('AIParseOrchestrator_isVisionTimeout', () => {
    it('VISION_TIMEOUT前缀_true', 0, () => {
      expect(AIParseOrchestrator.isVisionTimeout('VISION_TIMEOUT: read timeout')).assertTrue()
    })
    it('VISION_EXCEPTION含timeout_true', 0, () => {
      expect(AIParseOrchestrator.isVisionTimeout('VISION_EXCEPTION: TimeoutError')).assertTrue()
    })
    it('VISION_HTTP_504_true', 0, () => {
      expect(AIParseOrchestrator.isVisionTimeout('VISION_HTTP_504')).assertTrue()
    })
    it('普通VISION失败_false', 0, () => {
      expect(AIParseOrchestrator.isVisionTimeout('VISION_EMPTY_CONTENT')).assertFalse()
    })
    it('空串_false', 0, () => {
      expect(AIParseOrchestrator.isVisionTimeout('')).assertFalse()
    })
  })

  describe('AIParseOrchestrator_messageForVisionFailure', () => {
    it('401映射鉴权文案', 0, () => {
      const m = AIParseOrchestrator.messageForVisionFailure('VISION_HTTP_401: unauthorized')
      expect(m.indexOf('401') >= 0).assertTrue()
    })
    it('Anthropic格式映射协议文案', 0, () => {
      const m = AIParseOrchestrator.messageForVisionFailure('FORMAT_UNSUPPORTED_ANTHROPIC')
      expect(m.indexOf('OpenAI') >= 0).assertTrue()
    })
    it('超时映射超时文案', 0, () => {
      const m = AIParseOrchestrator.messageForVisionFailure('VISION_TIMEOUT')
      expect(m.indexOf('超时') >= 0).assertTrue()
    })
    it('空串返回空', 0, () => {
      expect(AIParseOrchestrator.messageForVisionFailure('')).assertEqual('')
    })
  })

  describe('AIParseOrchestrator_applyFileNameFallback', () => {
    function buildOutcome(platform: string): AIImageParseOutcome {
      const out = new AIImageParseOutcome()
      out.kind = 'vision'
      const item = new ParseResultItem()
      item.parsedFields.set('platform', platform)
      const result = new ParseResult()
      result.items.push(item)
      out.visionResult = result
      return out
    }

    it('未知平台_文件名命中_覆盖为账户名', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([
        { id: 'ca-001', name: '招商银行信用卡' } as Object
      ])
      const out = buildOutcome('未知平台')
      await AIParseOrchestrator.applyFileNameFallback(out, '招商银行信用卡单据.jpg')
      const p = out.visionResult!.items[0].parsedFields.get('platform') as string
      expect(p).assertEqual('招商银行信用卡')
    })

    it('未知平台_无账户匹配_保持未知平台', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([
        { id: 'ca-001', name: '花呗' } as Object
      ])
      const out = buildOutcome('未知平台')
      await AIParseOrchestrator.applyFileNameFallback(out, 'IMG_001.jpg')
      const p = out.visionResult!.items[0].parsedFields.get('platform') as string
      expect(p).assertEqual('未知平台')
    })

    it('已识别平台_不被文件名覆盖', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([
        { id: 'ca-001', name: '招商银行信用卡' } as Object
      ])
      const out = buildOutcome('花呗')
      await AIParseOrchestrator.applyFileNameFallback(out, '招商银行信用卡单据.jpg')
      const p = out.visionResult!.items[0].parsedFields.get('platform') as string
      expect(p).assertEqual('花呗')
    })

    it('空文件名_保持未知平台', 0, async () => {
      CreditAccountService._setPresetCreditAccounts([
        { id: 'ca-001', name: '招商银行信用卡' } as Object
      ])
      const out = buildOutcome('未知平台')
      await AIParseOrchestrator.applyFileNameFallback(out, '')
      const p = out.visionResult!.items[0].parsedFields.get('platform') as string
      expect(p).assertEqual('未知平台')
    })

    it('error类型结果_不抛异常', 0, async () => {
      const out = new AIImageParseOutcome()
      out.kind = 'error'
      out.visionResult = null
      await AIParseOrchestrator.applyFileNameFallback(out, '招商银行信用卡.jpg')
      expect(out.kind).assertEqual('error')
    })

    it('空账户列表_保持未知平台', 0, async () => {
      const out = buildOutcome('未知平台')
      await AIParseOrchestrator.applyFileNameFallback(out, '招商银行信用卡.jpg')
      const p = out.visionResult!.items[0].parsedFields.get('platform') as string
      expect(p).assertEqual('未知平台')
    })
  })
}
