import { describe, it, expect } from '@ohos/hypium'
import { LegalDocuments } from '../../../main/ets/common/LegalDocuments'

export default function legalDocumentsTest() {
  describe('LegalDocuments', () => {

    describe('LegalDocuments_Constants', () => {
      it('CONSENT_VERSION为数字', 0, () => {
        expect(typeof LegalDocuments.CONSENT_VERSION).assertEqual('number')
        expect(LegalDocuments.CONSENT_VERSION).assertEqual(1)
      })
      it('PREF_CONSENT_VERSION非空', 0, () => {
        expect(LegalDocuments.PREF_CONSENT_VERSION.length > 0).assertTrue()
      })
    })

    describe('title', () => {
      it('privacy返回隐私政策', 0, () => {
        expect(LegalDocuments.title('privacy')).assertEqual('隐私政策')
      })
      it('terms返回用户协议', 0, () => {
        expect(LegalDocuments.title('terms')).assertEqual('用户协议')
      })
    })

    describe('body', () => {
      it('privacy正文非空', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.length > 0).assertTrue()
      })
      it('privacy正文包含更新日期', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.indexOf('更新日期') >= 0).assertTrue()
      })
      it('privacy正文包含信息处理章节', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.indexOf('我们处理的信息') >= 0).assertTrue()
      })
      it('privacy正文包含商标与品牌声明', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.indexOf('所展示的商标和品牌均为其各自所有者的财产') >= 0).assertTrue()
      })
      it('terms正文非空', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.length > 0).assertTrue()
      })
      it('terms正文包含服务内容', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.indexOf('服务内容') >= 0).assertTrue()
      })
      it('terms正文包含适用法律', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.indexOf('适用法律') >= 0).assertTrue()
      })
      it('terms正文包含商标与品牌声明', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.indexOf('所展示的商标和品牌均为其各自所有者的财产') >= 0).assertTrue()
      })
      it('privacy和terms内容不同', 0, () => {
        const privacyBody = LegalDocuments.body('privacy')
        const termsBody = LegalDocuments.body('terms')
        expect(privacyBody !== termsBody).assertTrue()
      })
      it('privacy正文不包含账单字眼', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.indexOf('账单') < 0).assertTrue()
      })
      it('terms正文不包含账单字眼', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.indexOf('账单') < 0).assertTrue()
      })
      it('terms正文包含非金融声明与免责', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.indexOf('非金融') >= 0).assertTrue()
        expect(body.indexOf('免责声明') >= 0).assertTrue()
      })
      it('privacy正文包含账号注销与权利控制', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.indexOf('注销') >= 0).assertTrue()
        expect(body.indexOf('您的权利') >= 0).assertTrue()
      })
      it('privacy正文明确说明本地优先与云端存储', 0, () => {
        const body = LegalDocuments.body('privacy')
        expect(body.indexOf('本地优先') >= 0).assertTrue()
        expect(body.indexOf('云端存储') >= 0).assertTrue()
      })
      it('terms正文明确说明本地与云端存储机制', 0, () => {
        const body = LegalDocuments.body('terms')
        expect(body.indexOf('本地优先') >= 0 || body.indexOf('本地离线') >= 0).assertTrue()
        expect(body.indexOf('云端存储') >= 0).assertTrue()
      })
    })
  })
}
