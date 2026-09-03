import { describe, it, expect } from '@ohos/hypium'
import { ThemeColors, ThemeManager } from '../../../main/ets/common/ThemeManager'
import { MotionTokens } from '../../../main/ets/common/MotionTokens'
import { TypeScale } from '../../../main/ets/common/TypeScale'

export default function themeManagerTest() {
  describe('ThemeManager', () => {

    // ─── ThemeColors 默认值 ──────────────────────────────
    describe('ThemeColors', () => {
      it('默认背景为黑色', 0, () => {
        const c = new ThemeColors()
        expect(c.background).assertEqual('#000000')
      })
      it('默认radius值', 0, () => {
        const c = new ThemeColors()
        expect(c.radiusSm).assertEqual(4)
        expect(c.radiusMd).assertEqual(4)
        expect(c.radiusLg).assertEqual(8)
        expect(c.radiusXl).assertEqual(12)
        expect(c.radiusPill).assertEqual(999)
      })
      it('默认sheet圆角', 0, () => {
        const c = new ThemeColors()
        expect(c.sheetRadius).assertEqual(12)
        expect(c.sheetCardRadius).assertEqual(8)
      })
      it('默认间距', 0, () => {
        const c = new ThemeColors()
        expect(c.spaceXxs).assertEqual(4)
        expect(c.spaceXs).assertEqual(8)
        expect(c.spaceSm).assertEqual(16)
        expect(c.spaceBase).assertEqual(24)
        // v9：页面水平内边距 10（4 网格）
        expect(c.pageHorizontalPadding).assertEqual(10)
      })
    })

    // ─── ThemeColors 方法 ────────────────────────────────
    describe('ThemeColors.actionLabelColor', () => {
      it('destructive返回red', 0, () => {
        const c = new ThemeColors()
        expect(c.actionLabelColor('destructive')).assertEqual(c.red)
      })
      it('cancel返回text2', 0, () => {
        const c = new ThemeColors()
        expect(c.actionLabelColor('cancel')).assertEqual(c.text2)
      })
      it('其他role返回text', 0, () => {
        const c = new ThemeColors()
        expect(c.actionLabelColor('default')).assertEqual(c.text)
      })
    })

    describe('ThemeColors.statusColors', () => {
      it('statusDanger返回red', 0, () => {
        const c = new ThemeColors()
        expect(c.statusDanger()).assertEqual(c.red)
      })
      it('statusWarning返回amber', 0, () => {
        const c = new ThemeColors()
        expect(c.statusWarning()).assertEqual(c.amber)
      })
      it('statusOk返回text', 0, () => {
        const c = new ThemeColors()
        expect(c.statusOk()).assertEqual(c.text)
      })
      it('statusMuted返回text2', 0, () => {
        const c = new ThemeColors()
        expect(c.statusMuted()).assertEqual(c.text2)
      })
      it('statusInactive返回text3', 0, () => {
        const c = new ThemeColors()
        expect(c.statusInactive()).assertEqual(c.text3)
      })
    })

    describe('ThemeColors.dueUrgencyColor', () => {
      it('负数天返回red', 0, () => {
        const c = new ThemeColors()
        expect(c.dueUrgencyColor(-1)).assertEqual(c.red)
      })
      it('0天返回amber', 0, () => {
        const c = new ThemeColors()
        expect(c.dueUrgencyColor(0)).assertEqual(c.amber)
      })
      it('3天返回amber', 0, () => {
        const c = new ThemeColors()
        expect(c.dueUrgencyColor(3)).assertEqual(c.amber)
      })
      it('4天返回text2', 0, () => {
        const c = new ThemeColors()
        expect(c.dueUrgencyColor(4)).assertEqual(c.text2)
      })
    })

    describe('ThemeColors.isDarkCanvas', () => {
      it('黑色背景为深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#000000'
        expect(c.isDarkCanvas()).assertTrue()
      })
      it('#0A0A0A为深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#0A0A0A'
        expect(c.isDarkCanvas()).assertTrue()
      })
      it('#0C0C0E为深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#0C0C0E'
        expect(c.isDarkCanvas()).assertTrue()
      })
      it('#0D0C08为深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#0D0C08'
        expect(c.isDarkCanvas()).assertTrue()
      })
      it('#0C0B09为深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#0C0B09'
        expect(c.isDarkCanvas()).assertTrue()
      })
      it('白色背景非深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#FFFFFF'
        expect(c.isDarkCanvas()).assertFalse()
      })
      it('微暖浅色画布非深色', 0, () => {
        const c = new ThemeColors()
        c.background = '#FAFAF9'
        expect(c.isDarkCanvas()).assertFalse()
      })
    })

    describe('ThemeColors.elevatedShadow', () => {
      it('深色浮层阴影更深', 0, () => {
        const c = ThemeManager.DARK
        expect(c.elevatedShadowColor()).assertEqual('rgba(0,0,0,0.20)')
        expect(c.elevatedShadowRadius()).assertEqual(20)
        expect(c.elevatedShadowOffsetY()).assertEqual(8)
      })
      it('浅色浮层阴影更轻', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.elevatedShadowColor()).assertEqual('rgba(0,0,0,0.04)')
      })
    })

    describe('ThemeColors.floatShadowOptions', () => {
      it('float 一次对象与原语一致', 0, () => {
        const c = ThemeManager.DARK
        const o = c.floatShadowOptions()
        expect(o.radius).assertEqual(c.floatShadowRadius())
        expect(o.color).assertEqual(c.floatShadowColor())
        expect(o.offsetX).assertEqual(0)
        expect(o.offsetY).assertEqual(c.floatShadowOffsetY())
      })
      it('none 为零半径透明', 0, () => {
        const o = ThemeManager.DARK.noneShadowOptions()
        expect(o.radius).assertEqual(0)
        expect(o.offsetY).assertEqual(0)
      })
      it('floatShadowOptionsWhen 开关', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.floatShadowOptionsWhen(true).radius).assertEqual(c.floatShadowRadius())
        expect(c.floatShadowOptionsWhen(false).radius).assertEqual(0)
      })
      it('elevated 一次对象与原语一致', 0, () => {
        const c = ThemeManager.DARK
        const o = c.elevatedShadowOptions()
        expect(o.radius).assertEqual(c.elevatedShadowRadius())
        expect(o.color).assertEqual(c.elevatedShadowColor())
        expect(o.offsetY).assertEqual(c.elevatedShadowOffsetY())
      })
      it('popup 一次对象与原语一致且强于 float', 0, () => {
        const c = ThemeManager.DARK
        const o = c.popupShadowOptions()
        expect(o.radius).assertEqual(c.popupShadowRadius())
        expect(o.color).assertEqual(c.popupShadowColor())
        expect(o.offsetY).assertEqual(c.popupShadowOffsetY())
        expect(c.popupShadowRadius() > c.floatShadowRadius()).assertTrue()
        expect(c.popupShadowOffsetY() > c.floatShadowOffsetY()).assertTrue()
      })
    })

    describe('ThemeColors.sheetMaskColor', () => {
      it('深色画布返回较深遮罩', 0, () => {
        const c = ThemeManager.DARK
        expect(c.sheetMaskColor()).assertEqual('rgba(0, 0, 0, 0.82)')
      })
      it('浅色画布返回较浅遮罩', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.sheetMaskColor()).assertEqual('rgba(0, 0, 0, 0.45)')
      })
    })

    describe('ThemeColors.fieldBackground', () => {
      it('深色画布返回surface2', 0, () => {
        const c = ThemeManager.DARK
        expect(c.fieldBackground()).assertEqual(c.surface2)
      })
      it('浅色画布返回chip', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.fieldBackground()).assertEqual(c.chip)
      })
    })

    describe('ThemeColors.fieldBorder', () => {
      it('深色画布返回白色半透明', 0, () => {
        const c = ThemeManager.DARK
        expect(c.fieldBorder()).assertEqual('rgba(255,255,255,0.24)')
      })
      it('浅色画布返回黑色半透明', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.fieldBorder()).assertEqual('rgba(0,0,0,0.18)')
      })
    })

    describe('ThemeColors.aiHighlightBorder', () => {
      it('金色aiAccent返回金色描边', 0, () => {
        const c = new ThemeColors()
        c.aiAccent = '#E5B83A'
        expect(c.aiHighlightBorder()).assertEqual('rgba(229,184,58,0.40)')
      })
      it('橙色aiAccent返回橙色描边', 0, () => {
        const c = new ThemeColors()
        c.aiAccent = '#F54E00'
        expect(c.aiHighlightBorder()).assertEqual('rgba(245,78,0,0.35)')
      })
      it('默认aiAccent返回默认描边', 0, () => {
        const c = new ThemeColors()
        expect(c.aiHighlightBorder()).assertEqual('rgba(255,122,23,0.35)')
      })
    })

    describe('ThemeColors.sheetEdgeColor', () => {
      it('深色画布返回更亮的顶边受光线', 0, () => {
        const c = ThemeManager.DARK
        expect(c.sheetEdgeColor()).assertEqual('rgba(255,255,255,0.28)')
      })
      it('浅色画布返回border', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.sheetEdgeColor()).assertEqual(c.border)
      })
    })

    describe('ThemeColors.sheetBackground', () => {
      it('深色画布返回surface3抬离页内卡', 0, () => {
        const c = ThemeManager.DARK
        expect(c.sheetBackground()).assertEqual(c.surface3)
      })
      it('浅色画布返回surface2白底', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.sheetBackground()).assertEqual(c.surface2)
      })
      it('护眼画布返回surface3', 0, () => {
        const c = ThemeManager.EYE_CARE
        expect(c.sheetBackground()).assertEqual(c.surface3)
      })
    })

    describe('ThemeColors.sheetItemBackground', () => {
      it('深色画布返回chip再抬一级', 0, () => {
        const c = ThemeManager.DARK
        expect(c.sheetItemBackground()).assertEqual(c.chip)
      })
      it('浅色画布返回surface3', 0, () => {
        const c = ThemeManager.LIGHT
        expect(c.sheetItemBackground()).assertEqual(c.surface3)
      })
    })

    describe('ThemeColors.sheetShadowOptions', () => {
      it('复用popup档阴影', 0, () => {
        const c = ThemeManager.DARK
        const o = c.sheetShadowOptions()
        const p = c.popupShadowOptions()
        expect(o.radius).assertEqual(p.radius)
        expect(o.color).assertEqual(p.color)
        expect(o.offsetY).assertEqual(p.offsetY)
      })
    })

    // ─── ThemeManager 静态方法 ──────────────────────────
    describe('ThemeManager.getTheme', () => {
      it('dark模式返回DARK主题', 0, () => {
        const theme = ThemeManager.getTheme('dark', false)
        expect(theme.background).assertEqual(ThemeManager.DARK.background)
      })
      it('light模式返回LIGHT主题', 0, () => {
        const theme = ThemeManager.getTheme('light', true)
        expect(theme.background).assertEqual(ThemeManager.LIGHT.background)
      })
      it('system模式+深色返回DARK', 0, () => {
        const theme = ThemeManager.getTheme('system', true)
        expect(theme.background).assertEqual(ThemeManager.DARK.background)
      })
      it('system模式+浅色返回LIGHT', 0, () => {
        const theme = ThemeManager.getTheme('system', false)
        expect(theme.background).assertEqual(ThemeManager.LIGHT.background)
      })
    })

    describe('ThemeManager.isSame', () => {
      it('相同主题返回true', 0, () => {
        const a = ThemeManager.getTheme('dark', false)
        const b = ThemeManager.getTheme('dark', false)
        expect(ThemeManager.isSame(a, b)).assertTrue()
      })
      it('不同主题返回false', 0, () => {
        const a = ThemeManager.getTheme('dark', false)
        const b = ThemeManager.getTheme('light', false)
        expect(ThemeManager.isSame(a, b)).assertFalse()
      })
    })

    describe('ThemeManager.eyeCareTheme', () => {
      it('返回护眼主题', 0, () => {
        const theme = ThemeManager.eyeCareTheme(false)
        expect(theme.background).assertEqual('#100F0B')
        expect(theme.primary).assertEqual('#E5B83A')
      })
    })

    describe('ThemeManager.autoTheme', () => {
      it('低lux返回暗色主题', 0, () => {
        const theme = ThemeManager.autoTheme(5, false)
        expect(theme.background).assertEqual('#030303')
      })
      it('高lux返回亮色主题', 0, () => {
        const theme = ThemeManager.autoTheme(2000, false)
        expect(theme.background).assertEqual('#F7F7F4')
      })
    })

    describe('ThemeManager.applyAmbientGlow', () => {
      it('glow恒为透明', 0, () => {
        const theme = ThemeManager.applyAmbientGlow(ThemeManager.getTheme('dark', false), 50)
        expect(theme.glow).assertEqual('rgba(0,0,0,0)')
        expect(theme.glowCenter).assertEqual('rgba(0,0,0,0)')
        expect(theme.glowEdge).assertEqual('rgba(0,0,0,0)')
      })
    })

    describe('ThemeManager.ambientLabel', () => {
      it('负数lux返回无数据', 0, () => {
        expect(ThemeManager.ambientLabel(-1)).assertEqual('无环境光数据')
      })
      it('低lux返回暗光', 0, () => {
        expect(ThemeManager.ambientLabel(5)).assertEqual('暗光环境 · 已开启氛围光')
      })
      it('弱光返回柔化', 0, () => {
        expect(ThemeManager.ambientLabel(50)).assertEqual('弱光环境 · 已柔化显示')
      })
      it('强光返回提亮', 0, () => {
        expect(ThemeManager.ambientLabel(2000)).assertEqual('强光环境 · 已提亮显示')
      })
      it('适中光线', 0, () => {
        expect(ThemeManager.ambientLabel(500)).assertEqual('光线适中')
      })
    })

    // ─── 预设主题验证 ──────────────────────────────────────
    describe('ThemeManager_PresetThemes', () => {
      it('DARK主题背景为微暖深灰', 0, () => {
        expect(ThemeManager.DARK.background).assertEqual('#0C0B09')
        expect(ThemeManager.DARK.surface2).assertEqual('#1C1A17')
      })
      it('LIGHT主题背景为Cursor奶油纸', 0, () => {
        expect(ThemeManager.LIGHT.background).assertEqual('#F7F7F4')
        expect(ThemeManager.LIGHT.surface2).assertEqual('#FFFFFF')
      })
      it('EYE_CARE主题背景为暖暗', 0, () => {
        expect(ThemeManager.EYE_CARE.background).assertEqual('#100F0B')
      })
      it('v9圆角阶梯与DARK一致', 0, () => {
        expect(ThemeManager.DARK.radiusSm).assertEqual(4)
        expect(ThemeManager.DARK.radiusMd).assertEqual(4)
        expect(ThemeManager.DARK.radiusLg).assertEqual(8)
        expect(ThemeManager.DARK.sheetRadius).assertEqual(12)
        expect(ThemeManager.DARK.pageHorizontalPadding).assertEqual(10)
      })
      it('DARK画布判定为深色', 0, () => {
        expect(ThemeManager.DARK.isDarkCanvas()).assertTrue()
      })
    })
  })

  // ─── MotionTokens ────────────────────────────────────────
  describe('MotionTokens', () => {
    it('pressScale值正确', 0, () => {
      expect(MotionTokens.pressScale).assertEqual(0.97)
    })
    it('pressScaleLight值正确', 0, () => {
      expect(MotionTokens.pressScaleLight).assertEqual(0.98)
    })
    it('pressDuration值正确', 0, () => {
      expect(MotionTokens.pressDuration).assertEqual(100)
    })
    it('feedbackDuration值正确', 0, () => {
      expect(MotionTokens.feedbackDuration).assertEqual(150)
    })
    it('listItemReveal逐项缓现令牌正确', 0, () => {
      expect(MotionTokens.listItemRevealDuration).assertEqual(300)
      expect(MotionTokens.listItemRevealStagger).assertEqual(26)
      expect(MotionTokens.listItemRevealStaggerCap).assertEqual(8)
      expect(MotionTokens.listItemRevealOffsetY).assertEqual(12)
      // 错峰封顶：第 cap 项之后 delay 不再增长
      expect(MotionTokens.listItemRevealDelay(3)).assertEqual(78)
      expect(MotionTokens.listItemRevealDelay(20)).assertEqual(MotionTokens.listItemRevealDelay(8))
      expect(MotionTokens.listItemRevealTotal()).assertEqual(8 * 26 + 300)
    })
    it('listLogoRadius为v9', 0, () => {
      expect(MotionTokens.listLogoRadius).assertEqual(8)
    })
    it('listCardHeight与圆标不同', 0, () => {
      expect(MotionTokens.listCardHeight).assertEqual(38)
      expect(MotionTokens.listCardHeight === MotionTokens.listLogoSize).assertFalse()
    })
    it('listCardRadius为列表卡面', 0, () => {
      expect(MotionTokens.listCardRadius).assertEqual(4)
    })
    it('formLogoRadius为v9', 0, () => {
      expect(MotionTokens.formLogoRadius).assertEqual(12)
    })
    it('cardFaceRatio为ID-1', 0, () => {
      expect(MotionTokens.cardFaceRatio).assertEqual(1.586)
    })
    it('cardFaceRadius为实体卡圆角', 0, () => {
      expect(MotionTokens.cardFaceRadius).assertEqual(6)
    })
    it('chartGrowDuration值正确', 0, () => {
      expect(MotionTokens.chartGrowDuration).assertEqual(480)
    })
    it('countDuration值正确', 0, () => {
      expect(MotionTokens.countDuration).assertEqual(420)
    })
    it('trendRevealDuration值正确', 0, () => {
      expect(MotionTokens.trendRevealDuration).assertEqual(1100)
    })
    it('themeCrossfadeDuration值正确', 0, () => {
      expect(MotionTokens.themeCrossfadeDuration).assertEqual(400)
    })
    it('sheetDuration值正确', 0, () => {
      expect(MotionTokens.sheetDuration).assertEqual(250)
    })
    it('pageTransitionDuration值正确', 0, () => {
      expect(MotionTokens.pageTransitionDuration).assertEqual(320)
    })
    it('ceremonyHold值正确', 0, () => {
      expect(MotionTokens.ceremonyHold).assertEqual(5600)
    })
    it('ceremonySceneDuration值正确', 0, () => {
      expect(MotionTokens.ceremonySceneDuration).assertEqual(1100)
    })
    it('ceremonyMaskIn值正确', 0, () => {
      expect(MotionTokens.ceremonyMaskIn).assertEqual(260)
    })

    describe('drawerItemDelay', () => {
      it('正常索引', 0, () => {
        expect(MotionTokens.drawerItemDelay(0)).assertEqual(0)
        expect(MotionTokens.drawerItemDelay(1)).assertEqual(26)
        expect(MotionTokens.drawerItemDelay(3)).assertEqual(78)
      })
      it('负数索引视为0', 0, () => {
        expect(MotionTokens.drawerItemDelay(-1)).assertEqual(0)
      })
      it('超过8封顶', 0, () => {
        expect(MotionTokens.drawerItemDelay(10)).assertEqual(8 * 26)
        expect(MotionTokens.drawerItemDelay(100)).assertEqual(8 * 26)
      })
    })

    describe('barStaggerProgress', () => {
      it('t=0时所有柱为0', 0, () => {
        expect(MotionTokens.barStaggerProgress(0, 0, 5)).assertEqual(0)
        expect(MotionTokens.barStaggerProgress(0, 2, 5)).assertEqual(0)
      })
      it('t=1时所有柱为1', 0, () => {
        expect(MotionTokens.barStaggerProgress(1, 0, 5)).assertEqual(1)
        expect(MotionTokens.barStaggerProgress(1, 4, 5)).assertEqual(1)
      })
      it('count=0不崩溃', 0, () => {
        const result = MotionTokens.barStaggerProgress(0.5, 0, 0)
        expect(result >= 0 && result <= 1).assertTrue()
      })
      it('进度单调递增', 0, () => {
        const p1 = MotionTokens.barStaggerProgress(0.3, 1, 5)
        const p2 = MotionTokens.barStaggerProgress(0.6, 1, 5)
        expect(p2 >= p1).assertTrue()
      })
    })
  })

  // ─── TypeScale ───────────────────────────────────────────
  describe('TypeScale', () => {
    it('FONT_MONO非空', 0, () => {
      expect(TypeScale.FONT_MONO.length > 0).assertTrue()
    })
    it('heroTitle大于body', 0, () => {
      expect(TypeScale.heroTitle > TypeScale.body).assertTrue()
    })
    it('字号递减排列', 0, () => {
      expect(TypeScale.heroTitle > TypeScale.display).assertTrue()
      expect(TypeScale.display > TypeScale.metric).assertTrue()
      expect(TypeScale.metric > TypeScale.listPrimary).assertTrue()
      expect(TypeScale.listPrimary > TypeScale.control).assertTrue()
      expect(TypeScale.control > TypeScale.body).assertTrue()
      expect(TypeScale.body > TypeScale.bodySm).assertTrue()
      expect(TypeScale.bodySm > TypeScale.caption).assertTrue()
      expect(TypeScale.caption > TypeScale.captionSm).assertTrue()
      expect(TypeScale.captionSm > TypeScale.kicker).assertTrue()
    })
    it('watermark为大尺寸', 0, () => {
      expect(TypeScale.watermark).assertEqual(56)
    })
    it('emptyPlus值正确', 0, () => {
      expect(TypeScale.emptyPlus).assertEqual(20)
    })
  })
}
