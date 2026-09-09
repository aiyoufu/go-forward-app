import { describe, it, expect } from '@ohos/hypium'
import { OcrService } from '../../../../main/ets/service/ai/OcrService'

export default function ocrServiceTest() {
  describe('OcrService_limits', () => {
    it('MAX_FILE_BYTES_为20MB', 0, () => {
      expect(OcrService.MAX_FILE_BYTES).assertEqual(20 * 1024 * 1024)
    })

    it('OCR_MAX_EDGE_为1920', 0, () => {
      expect(OcrService.OCR_MAX_EDGE).assertEqual(1920)
    })

    it('VISION_MAX_EDGE_为960', 0, () => {
      expect(OcrService.VISION_MAX_EDGE).assertEqual(960)
    })

    it('VISION_JPEG_QUALITY_为55', 0, () => {
      expect(OcrService.VISION_JPEG_QUALITY).assertEqual(55)
    })

    it('VISION_FALLBACK_MAX_EDGE_小于主路径', 0, () => {
      expect(OcrService.VISION_FALLBACK_MAX_EDGE < OcrService.VISION_MAX_EDGE).assertTrue()
    })

    it('VISION_MAX_BASE64_CHARS_为正', 0, () => {
      expect(OcrService.VISION_MAX_BASE64_CHARS > 0).assertTrue()
    })

    it('MSG_IMAGE_TOO_LARGE非空', 0, () => {
      expect(OcrService.MSG_IMAGE_TOO_LARGE.length > 0).assertTrue()
    })
  })
}
