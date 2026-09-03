import AbilityTest from '../test/Ability.test'

@Entry
@Component
struct Index {
  aboutToAppear() {
    AbilityTest()
  }

  build() {
    Column() {
      Text('Common Test Running')
        .fontSize(24)
        .margin({ top: 50 })
    }
    .width('100%')
    .height('100%')
  }
}
