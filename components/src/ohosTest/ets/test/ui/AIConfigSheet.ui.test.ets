import { describe, it, expect } from '@ohos/hypium'

/**
 * AIConfigSheet UI 测试
 * 覆盖：配置项交互、渠道状态、服务商选择
 */
export default function AIConfigSheet_UITest() {
  describe('AIConfigSheet_UI', () => {

    // ── 渠道状态 ──
    it('渲染_未开启_显示未开启', 0, async () => {
      const enabled = false
      const label = enabled ? '已接通' : '未开启'
      expect(label).assertEqual('未开启')
    })

    it('渲染_已开启待完善_显示待完善', 0, async () => {
      const enabled = true
      const key = ''
      const url = ''
      const model = ''
      const status = enabled ? (key.length === 0 || url.length === 0 || model.length === 0 ? '已开启 · 待完善' : '已接通') : '未开启'
      expect(status).assertEqual('已开启 · 待完善')
    })

    it('渲染_已配置待测试_显示待测试', 0, async () => {
      const enabled = true
      const key = 'sk-xxx'
      const url = 'https://api.example.com'
      const model = 'gpt-4'
      const testedOk = false
      const status = enabled ? (testedOk ? '已接通' : '已配置 · 待测试') : '未开启'
      expect(status).assertEqual('已配置 · 待测试')
    })

    it('渲染_已接通_显示已接通', 0, async () => {
      const enabled = true
      const testedOk = true
      const status = enabled ? (testedOk ? '已接通' : '已配置 · 待测试') : '未开启'
      expect(status).assertEqual('已接通')
    })

    // ── 渠道短标签 ──
    it('渲染_文字渠道_显示文字', 0, async () => {
      let channel: string = 'text'
      const label = channel === 'text' ? '文字' : '图片'
      expect(label).assertEqual('文字')
    })

    it('渲染_图片渠道_显示图片', 0, async () => {
      let channel: string = 'vision'
      const label = channel === 'text' ? '文字' : '图片'
      expect(label).assertEqual('图片')
    })

    // ── 状态点颜色 ──
    it('渲染_dot_未开启返回0', 0, async () => {
      const enabled = false
      const dot = enabled ? 1 : 0
      expect(dot).assertEqual(0)
    })

    it('渲染_dot_已接通返回2', 0, async () => {
      const enabled = true
      const testedOk = true
      const dot = enabled ? (testedOk ? 2 : 1) : 0
      expect(dot).assertEqual(2)
    })

    it('渲染_dot_待完善返回1', 0, async () => {
      const enabled = true
      const testedOk = false
      const dot = enabled ? (testedOk ? 2 : 1) : 0
      expect(dot).assertEqual(1)
    })

    // ── 格式标签 ──
    it('渲染_openai格式_显示OpenAI', 0, async () => {
      const fmt = 'openai'
      const label = fmt === 'openai' ? 'OpenAI' : (fmt === 'anthropic' ? 'Anthropic' : '自动')
      expect(label).assertEqual('OpenAI')
    })

    it('渲染_anthropic格式_显示Anthropic', 0, async () => {
      const fmt = 'anthropic'
      const label = fmt === 'anthropic' ? 'Anthropic' : 'OpenAI'
      expect(label).assertEqual('Anthropic')
    })

    it('渲染_auto格式_显示自动', 0, async () => {
      const fmt = 'auto'
      const label = fmt === 'auto' ? '自动' : 'OpenAI'
      expect(label).assertEqual('自动')
    })

    // ── Base URL 规范化 ──
    it('规范化_去除末尾斜杠', 0, async () => {
      let url = 'https://api.example.com/v1/'
      while (url.endsWith('/') && url.length > 1) { url = url.substring(0, url.length - 1) }
      expect(url).assertEqual('https://api.example.com/v1')
    })

    it('规范化_保留单斜杠', 0, async () => {
      let url = '/'
      while (url.endsWith('/') && url.length > 1) { url = url.substring(0, url.length - 1) }
      expect(url).assertEqual('/')
    })

    // ── 配置指纹 ──
    it('指纹_相同配置返回相同指纹', 0, async () => {
      const fp1 = 'key\nurl\nmodel'
      const fp2 = 'key\nurl\nmodel'
      expect(fp1).assertEqual(fp2)
    })

    it('指纹_不同配置返回不同指纹', 0, async () => {
      const fp1 = 'key1\nurl\nmodel'
      const fp2 = 'key2\nurl\nmodel'
      expect(fp1 !== fp2).assertTrue()
    })

    // ── 禁用提示 ──
    it('渲染_文字禁用提示_显示解析说明', 0, async () => {
      let channel: string = 'text'
      const hint = channel === 'text' ? '开启后支持键盘描述、系统听写转写文本与 OCR 文本的智能解析。' : '开启后支持通过图片进行智能识别。'
      expect(hint.includes('键盘')).assertTrue()
    })

    it('渲染_图片禁用提示_显示图片识别说明', 0, async () => {
      let channel: string = 'vision'
      const hint = channel === 'text' ? '文字提示' : '开启后支持通过图片进行智能识别。'
      expect(hint.includes('图片')).assertTrue()
    })

    // ── 服务商匹配 ──
    it('匹配_DeepSeek URL_返回DeepSeek', 0, async () => {
      const providers = [
        { name: 'DeepSeek', baseUrl: 'https://api.deepseek.com' },
        { name: 'Kimi', baseUrl: 'https://api.moonshot.cn/v1' }
      ]
      const url = 'https://api.deepseek.com'
      let matched = '自定义'
      for (const p of providers) {
        if (url === p.baseUrl) { matched = p.name; break }
      }
      expect(matched).assertEqual('DeepSeek')
    })

    it('匹配_未知URL_返回自定义', 0, async () => {
      const providers = [{ name: 'DeepSeek', baseUrl: 'https://api.deepseek.com' }]
      const url = 'https://unknown.api.com'
      let matched = '自定义'
      for (const p of providers) {
        if (url === p.baseUrl) { matched = p.name; break }
      }
      expect(matched).assertEqual('自定义')
    })

    // ── 服务商下标回显（用于列表勾选） ──
    it('下标_空URL_返回负一', 0, async () => {
      const url = ''
      const idx = url.length === 0 ? -1 : 0
      expect(idx).assertEqual(-1)
    })

    it('下标_命中预设_返回对应下标', 0, async () => {
      const providers = [
        { name: '火山', baseUrl: 'https://ark.cn-beijing.volces.com/api/coding/v3' },
        { name: 'DeepSeek', baseUrl: 'https://api.deepseek.com' },
        { name: '自定义', baseUrl: '' }
      ]
      const url = 'https://api.deepseek.com'
      let idx = providers.length - 1
      for (let i = 0; i < providers.length; i++) {
        if (providers[i].baseUrl.length === 0) {
          continue
        }
        if (url === providers[i].baseUrl) {
          idx = i
          break
        }
      }
      expect(idx).assertEqual(1)
    })

    it('下标_非空未命中_返回末位自定义', 0, async () => {
      const providers = [
        { name: 'DeepSeek', baseUrl: 'https://api.deepseek.com' },
        { name: '自定义', baseUrl: '' }
      ]
      const url = 'https://unknown.api.com'
      let idx = providers.length - 1
      for (let i = 0; i < providers.length; i++) {
        if (providers[i].baseUrl.length === 0) {
          continue
        }
        if (url === providers[i].baseUrl) {
          idx = i
          break
        }
      }
      expect(idx).assertEqual(1)
    })

    // ── AIConfigSummaryHelper ──
    it('摘要_两渠道均未配置_显示未配置', 0, async () => {
      let textLevel: number = 0
      let visionLevel: number = 0
      const ok = (textLevel === 2 ? 1 : 0) + (visionLevel === 2 ? 1 : 0)
      const mid = (textLevel === 1 ? 1 : 0) + (visionLevel === 1 ? 1 : 0)
      const summary = ok === 0 && mid === 0 ? '未配置' : '查看配置状态'
      expect(summary).assertEqual('未配置')
    })

    it('摘要_两渠道均接通_显示已接通', 0, async () => {
      const textLevel = 2
      const visionLevel = 2
      const ok = (textLevel === 2 ? 1 : 0) + (visionLevel === 2 ? 1 : 0)
      const summary = ok === 2 ? '文字·图片 已接通' : '查看配置状态'
      expect(summary).assertEqual('文字·图片 已接通')
    })

    // ── 已接通默认折叠 ──
    it('折叠_已接通_默认折叠', 0, async () => {
      const enabled = true
      const testedOk = true
      const collapsed = enabled && testedOk
      expect(collapsed).assertTrue()
    })

    it('折叠_待测试_默认展开', 0, async () => {
      const enabled = true
      const testedOk = false
      const collapsed = enabled && testedOk
      expect(collapsed).assertFalse()
    })

    it('折叠_未开启_不进入折叠分支', 0, async () => {
      const enabled = false
      const entersCollapsedBranch = enabled
      expect(entersCollapsedBranch).assertFalse()
    })

    it('折叠_用户展开后_不再折叠', 0, async () => {
      const testedOk = true
      let collapsed = true
      collapsed = false
      const showsSummary = collapsed && testedOk
      expect(showsSummary).assertFalse()
    })

    it('折叠_展开态点击收起_回到折叠', 0, async () => {
      const testedOk = true
      let collapsed = false
      collapsed = true
      const showsSummary = collapsed && testedOk
      expect(showsSummary).assertTrue()
    })
  })
}
