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

  describe('OcrService_isOcrTextUseful', () => {
    it('空字符串_返回false', 0, () => {
      expect(OcrService.isOcrTextUseful('')).assertFalse()
    })

    it('纯空白_返回false', 0, () => {
      expect(OcrService.isOcrTextUseful('   \n\t  ')).assertFalse()
    })

    it('长度不足6_返回false', 0, () => {
      expect(OcrService.isOcrTextUseful('abc')).assertFalse()
    })

    it('长度等于5_返回false', 0, () => {
      expect(OcrService.isOcrTextUseful('abcde')).assertFalse()
    })

    it('长度等于6但无数字中文_返回false', 0, () => {
      expect(OcrService.isOcrTextUseful('abcdef')).assertFalse()
    })

    it('长度等于6含数字_返回true', 0, () => {
      expect(OcrService.isOcrTextUseful('abc123')).assertTrue()
    })

    it('长度等于6含中文_返回true', 0, () => {
      // 去空白后至少 6 字：花呗还款单据 = 6
      expect(OcrService.isOcrTextUseful('花呗还款单据')).assertTrue()
    })

    it('含数字的较长文本_返回true', 0, () => {
      expect(OcrService.isOcrTextUseful('京东白条单据 2024-12-15')).assertTrue()
    })

    it('纯数字_返回true', 0, () => {
      expect(OcrService.isOcrTextUseful('20241215')).assertTrue()
    })

    it('纯中文_返回true', 0, () => {
      expect(OcrService.isOcrTextUseful('花呗还款日为十二月')).assertTrue()
    })

    it('含空白和数字_去除空白后判', 0, () => {
      expect(OcrService.isOcrTextUseful('  \n 12 34 56 ')).assertTrue()
    })

    it('乱码符号_返回false', 0, () => {
      expect(OcrService.isOcrTextUseful('!@#$%^&*()')).assertFalse()
    })
  })
}
