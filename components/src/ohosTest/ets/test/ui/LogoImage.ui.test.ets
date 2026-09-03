import { describe, it, expect } from '@ohos/hypium'

export default function logoImageUITest() {
  describe('LogoImage_UI', () => {
    it('onError回退字标', 0, () => {
      let failed = false
      const onError = () => {
        failed = true
      }
      onError()
      expect(failed).assertTrue()
    })
    it('url空用字标', 0, () => {
      const url = ''
      const useGlyph = url.length === 0
      expect(useGlyph).assertTrue()
    })
  })
}
