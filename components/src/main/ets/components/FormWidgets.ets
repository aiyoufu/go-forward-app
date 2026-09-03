import { MotionTokens, ThemeColors, TypeScale } from 'common'

/**
 * 三表单页（负债/订阅/信用账户）公共小控件。
 * 从各表单页内重复定义的 FormInput2 / FormInput3 / FormLabel / DateField 归一而来；
 * 保留自定义组件以支持 @Link 响应式与焦点动效。
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct FormFieldLabel {
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop label: string = ''

  build() {
    Text(this.label)
      .fontSize(TypeScale.bodySm)
      .fontColor(this.theme.text2)
      .alignSelf(ItemAlign.Start)
      .margin({ top: 4 })
  }
}

@Component
export struct FormFieldInput {
  @Prop label: string = ''
  @Prop placeholder: string = ''
  @Prop inputType: InputType = InputType.Normal
  @Prop theme: ThemeColors = new ThemeColors()
  @Link value: string
  onChange?: (v: string) => void
  @State private focusBorderColor: ResourceColor = ''

  aboutToAppear(): void {
    this.focusBorderColor = this.theme.fieldBorder()
  }

  build() {
    Column({ space: 6 }) {
      Text(this.label)
        .fontSize(TypeScale.bodySm)
        .fontColor(this.theme.text2)
        .alignSelf(ItemAlign.Start)

      TextInput({ text: this.value, placeholder: this.placeholder })
        .type(this.inputType)
        .fontColor(this.theme.text)
        .placeholderColor(this.theme.text3)
        .backgroundColor(this.theme.fieldBackground())
        .borderRadius(this.theme.radiusLg)
        .border({ width: this.theme.fieldBorderWidth(), color: this.focusBorderColor })
        .height(44)
        .onChange((v: string) => {
          this.value = v
          if (this.onChange !== undefined) {
            this.onChange(v)
          }
        })
        .onFocus(() => {
          this.getUIContext().animateTo({
            duration: MotionTokens.feedbackDuration,
            curve: Curve.EaseOut
          }, () => { this.focusBorderColor = this.theme.primary })
        })
        .onBlur(() => {
          this.getUIContext().animateTo({
            duration: MotionTokens.feedbackDuration,
            curve: Curve.EaseOut
          }, () => { this.focusBorderColor = this.theme.fieldBorder() })
        })
    }
    .width('100%')
  }
}

@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct FormFieldDateField {
  @Prop value: string = ''
  @Prop theme: ThemeColors = new ThemeColors()
  @Prop placeholder: string = '选择日期'
  onPick?: () => void

  build() {
    Row() {
      Text(this.value.length > 0 ? this.value : this.placeholder)
        .fontSize(TypeScale.body)
        .fontColor(this.value.length > 0 ? this.theme.text : this.theme.text3)
        .layoutWeight(1)
      Text('📅')
        .fontSize(TypeScale.control)
    }
    .width('100%')
    .height(44)
    .padding({ left: 14, right: 14 })
    .backgroundColor(this.theme.fieldBackground())
    .borderRadius(this.theme.radiusLg)
    .border({ width: this.theme.fieldBorderWidth(), color: this.theme.fieldBorder() })
    .onClick(() => {
      if (this.onPick !== undefined) {
        this.onPick()
      }
    })
  }
}
