import { describe, it, expect } from '@ohos/hypium'
import { recommendThemeMode, isAbilityConfigDark } from '../../../main/ets/common/ThemeMode'

export default function themeModeTest() {
  describe('ThemeMode', () => {

    describe('isAbilityConfigDark', () => {
      it('ConfigurationConstant_DARK_0_为深色', 0, () => {
        // ConfigurationConstant.ColorMode.COLOR_MODE_DARK === 0
        expect(isAbilityConfigDark(0)).assertTrue()
      })
      it('ConfigurationConstant_LIGHT_1_为浅色', 0, () => {
        // ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT === 1
        // 注意：ArkUI ColorMode.DARK 也是 1，不可混用
        expect(isAbilityConfigDark(1)).assertFalse()
      })
      it('NOT_SET与undefined非深色', 0, () => {
        expect(isAbilityConfigDark(-1)).assertFalse()
        expect(isAbilityConfigDark(undefined)).assertFalse()
      })
    })

    describe('recommendThemeMode', () => {
      it('低lux返回dark', 0, () => {
        expect(recommendThemeMode(0)).assertEqual('dark')
        expect(recommendThemeMode(5)).assertEqual('dark')
        expect(recommendThemeMode(9)).assertEqual('dark')
      })
      it('lux=10返回system', 0, () => {
        expect(recommendThemeMode(10)).assertEqual('system')
      })
      it('中等lux返回system', 0, () => {
        expect(recommendThemeMode(100)).assertEqual('system')
        expect(recommendThemeMode(500)).assertEqual('system')
        expect(recommendThemeMode(999)).assertEqual('system')
      })
      it('lux=1000返回system', 0, () => {
        expect(recommendThemeMode(1000)).assertEqual('system')
      })
      it('高lux返回light', 0, () => {
        expect(recommendThemeMode(1001)).assertEqual('light')
        expect(recommendThemeMode(5000)).assertEqual('light')
        expect(recommendThemeMode(10000)).assertEqual('light')
      })
      it('负数lux返回dark', 0, () => {
        expect(recommendThemeMode(-1)).assertEqual('dark')
      })
    })
  })
}
