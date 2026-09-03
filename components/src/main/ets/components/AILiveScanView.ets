import { ThemeColors, ThemeManager, TypeScale } from 'common'

/**
 * AI Live 识别舞台（对齐 Lex Tang 识别截图叠卡）
 * - 三卡几乎同位一摞：前卡主体，后两张只从右上露侧缘
 * - 前卡模拟「单据分期详情」负债截图（本金 / 剩余 / 分期计划）
 * - 星尘为背景细白针点
 */
@Component
// eslint-disable-next-line @performance/avoid-overusing-custom-component-check
export struct AILiveScanView {
  @Prop theme: ThemeColors = ThemeManager.DARK
  @Prop scanProgress: number = 0
  @Prop sparklePhase: number = 0
  @Prop bottomSafe: number = 0

  /** 文档卡尺寸（接近手机截图比例） */
  private static readonly CARD_H: number = 460
  private static readonly CARD_W: string = '78%'
  private static readonly STACK_H: number = 500

  private cardSurface(): ResourceColor {
    // 截图卡始终偏「纸白」：浅色白卡；深色用抬升亮面
    return this.theme.isDarkCanvas() ? this.theme.surface3 : this.theme.surface2
  }

  private stageTextPrimary(): string {
    // 暖白而非纯白（深色画布禁裸 #FFFFFF）
    return 'rgba(242, 241, 239, 0.94)'
  }

  private stageTextSecondary(): string {
    return 'rgba(242, 241, 239, 0.72)'
  }

  private starOpacity(seed: number): number {
    const period = 30 + (seed % 7) * 5
    const phase = (this.sparklePhase + seed * 17) % period
    const t = phase / period
    const wave = Math.pow(0.5 - 0.5 * Math.cos(t * Math.PI * 2), 1.6)
    const floor = 0.10 + (seed % 4) * 0.03
    const peak = 0.90 + (seed % 5) * 0.02
    return floor + wave * (peak - floor)
  }

  private starSize(seed: number): number {
    const sizes: number[] = [2, 2, 3, 3, 2, 4, 3, 2, 4, 3, 2, 3, 2, 5, 2, 3]
    return sizes[seed % sizes.length]
  }

  @Builder
  starDot(xPct: number, yPct: number, seed: number) {
    Column()
      .width(this.starSize(seed))
      .height(this.starSize(seed))
      .borderRadius(999)
      .backgroundColor('#FFFFFF')
      .opacity(this.starOpacity(seed))
      .position({ x: `${xPct}%`, y: `${yPct}%` })
  }

  @Builder
  starBloom(xPct: number, yPct: number, seed: number) {
    Column()
      .width(this.starSize(seed) + 1)
      .height(this.starSize(seed) + 1)
      .borderRadius(999)
      .backgroundColor('#FFFFFF')
      .opacity(this.starOpacity(seed))
      .position({ x: `${xPct}%`, y: `${yPct}%` })
  }

  @Builder
  starDust(xPct: number, yPct: number, seed: number) {
    Column()
      .width(2)
      .height(2)
      .borderRadius(999)
      .backgroundColor('#FFFFFF')
      .opacity(this.starOpacity(seed) * 0.85)
      .position({ x: `${xPct}%`, y: `${yPct}%` })
  }

  /** 键值行：无分割线，靠留白分层（对齐真实单据 App） */
  @Builder
  debtKvRow(label: string, value: string, valueAccent: boolean) {
    Row() {
      Text(label)
        .fontSize(TypeScale.caption)
        .fontColor(this.theme.text3)
        .layoutWeight(1)
      Text(value)
        .fontSize(TypeScale.caption)
        .fontFamily(TypeScale.FONT_MONO)
        .fontColor(valueAccent ? this.theme.amber : this.theme.text)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 9, bottom: 9 })
  }

  /**
   * 分期计划行：期数 + 已还清 chip + 金额；副行还款日
   * 期与期之间只留白，不画横线
   */
  @Builder
  debtPeriodRow(period: string, status: string, date: string, amount: string, paid: boolean) {
    Column({ space: 4 }) {
      Row() {
        Text(period)
          .fontSize(TypeScale.bodySm)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
        if (status.length > 0) {
          Text(status)
            .fontSize(TypeScale.kicker)
            .fontColor(paid ? this.theme.positiveGreen : this.theme.text3)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .margin({ left: 8 })
            .backgroundColor(paid
              ? (this.theme.isDarkCanvas() ? 'rgba(52,211,153,0.14)' : 'rgba(31,138,101,0.10)')
              : Color.Transparent)
            .borderRadius(this.theme.radiusPill)
        }
        Blank()
        Text(amount)
          .fontSize(TypeScale.bodySm)
          .fontWeight(FontWeight.Medium)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor(this.theme.text)
      }
      .width('100%')
      Text('还款日 ' + date)
        .fontSize(TypeScale.kicker)
        .fontColor(this.theme.text3)
        .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
  }

  /**
   * 后排空白文档卡：几乎被盖住，只露侧缘（参考图右上/左下弧边）
   */
  @Builder
  blankDocCard(top: number, leftPct: string, rotateDeg: number) {
    Column()
      .width(AILiveScanView.CARD_W)
      .height(AILiveScanView.CARD_H)
      .borderRadius(this.theme.radiusXl)
      .backgroundColor(this.cardSurface())
      .border({ width: 1, color: this.theme.borderSoft })
      .shadow({
        radius: 18,
        color: this.theme.isDarkCanvas() ? 'rgba(0,0,0,0.32)' : 'rgba(0,0,0,0.10)',
        offsetX: 0,
        offsetY: 6
      })
      .rotate({ angle: rotateDeg, centerX: '50%', centerY: '50%' })
      .margin({ top: top, left: leftPct })
  }

  /**
   * 前卡：模拟真实单据分期详情页
   * 无横线/虚线分隔，块面靠留白与字阶分层（对齐支付宝类单据 UI）
   */
  @Builder
  screenshotCard(top: number, leftPct: string, rotateDeg: number) {
    Column({ space: 0 }) {
      // 导航（真实页常无额外状态栏字，只留标题区）
      Row() {
        Text('‹')
          .fontSize(TypeScale.sectionTitle)
          .fontColor(this.theme.text2)
          .width(28)
        Text('单据分期详情')
          .fontSize(TypeScale.body)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.text)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Row().width(28)
      }
      .width('100%')
      .padding({ left: 10, right: 10, top: 14, bottom: 8 })

      // 剩余待还
      Column({ space: 6 }) {
        Text('剩余待还(元)')
          .fontSize(TypeScale.kicker)
          .fontColor(this.theme.text3)
        Text('225.08')
          .fontSize(TypeScale.heroNumber)
          .fontWeight(FontWeight.Bold)
          .fontFamily(TypeScale.FONT_MONO)
          .fontColor(this.theme.text)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .padding({ top: 12, bottom: 16 })

      this.debtKvRow('分期本金', '332.62', false)
      this.debtKvRow('分期服务费', '3.33', true)
      this.debtKvRow('支付方式', '单据分期', false)
      this.debtKvRow('分期时间', '2026-06-22 20:52', false)

      // 分区标题：仅字阶 + 上留白，无横线
      Text('分期计划')
        .fontSize(TypeScale.bodySm)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.theme.text)
        .width('100%')
        .padding({ left: 16, right: 16, top: 18, bottom: 4 })

      this.debtPeriodRow('1/3 期', '已还清', '2026-07-08', '110.87', true)
      this.debtPeriodRow('2/3 期', '', '2026-09-03', '110.87', false)
      this.debtPeriodRow('3/3 期', '', '2026-10-03', '114.21', false)
    }
    .width(AILiveScanView.CARD_W)
    .height(AILiveScanView.CARD_H)
    .borderRadius(this.theme.radiusXl)
    .backgroundColor(this.cardSurface())
    .border({ width: 1, color: this.theme.borderSoft })
    .shadow({
      radius: 28,
      color: this.theme.isDarkCanvas() ? 'rgba(0,0,0,0.42)' : 'rgba(0,0,0,0.16)',
      offsetX: 0,
      offsetY: 12
    })
    .clip(true)
    .rotate({ angle: rotateDeg, centerX: '50%', centerY: '55%' })
    .margin({ top: top, left: leftPct })
  }

  @Builder
  starField() {
    Stack() {
      this.starDust(6, 4, 0)
      this.starDot(18, 8, 1)
      this.starBloom(32, 5, 2)
      this.starDust(48, 10, 3)
      this.starDot(62, 6, 4)
      this.starBloom(76, 9, 5)
      this.starDust(90, 4, 6)
      this.starDot(40, 14, 7)
      this.starBloom(12, 16, 8)
      this.starDust(84, 15, 9)
      this.starDot(8, 22, 10)
      this.starBloom(24, 26, 11)
      this.starDust(38, 20, 12)
      this.starDot(54, 28, 13)
      this.starBloom(70, 23, 14)
      this.starDust(86, 30, 15)
      this.starDot(16, 34, 16)
      this.starBloom(48, 32, 17)
      this.starDust(78, 35, 18)
      this.starDot(5, 40, 19)
      this.starBloom(22, 44, 20)
      this.starDust(36, 38, 21)
      this.starDot(52, 46, 22)
      this.starBloom(68, 41, 23)
      this.starDust(84, 48, 24)
      this.starDot(14, 52, 25)
      this.starBloom(44, 50, 26)
      this.starDust(74, 54, 27)
      this.starDot(92, 42, 28)
      this.starDust(7, 58, 29)
      this.starDot(28, 62, 30)
      this.starBloom(46, 56, 31)
      this.starDust(64, 64, 32)
      this.starDot(82, 60, 33)
      this.starBloom(12, 68, 34)
      this.starDust(38, 70, 35)
      this.starDot(58, 66, 36)
      this.starBloom(88, 72, 37)
      this.starDust(10, 76, 38)
      this.starDot(26, 82, 39)
      this.starBloom(42, 78, 40)
      this.starDust(58, 86, 41)
      this.starDot(74, 80, 42)
      this.starBloom(90, 84, 43)
      this.starDust(18, 90, 44)
      this.starDot(50, 92, 45)
      this.starBloom(66, 88, 46)
      this.starDust(82, 94, 47)
      this.starDot(34, 96, 48)
    }
    .width('100%')
    .height('100%')
    .hitTestBehavior(HitTestMode.None)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(this.theme.isDarkCanvas()
          ? 'rgba(0, 0, 0, 0.52)'
          : 'rgba(0, 0, 0, 0.32)')

      this.starField()

      Column({ space: 16 }) {
        /**
         * 参考图一摞截图卡（绘制：后 → 中 → 前）：
         * - 三卡几乎同位，非整排左中右散开
         * - 后两张略右移/右倾，只从右上露弧边；前卡略左倾盖住主体
         * - 左下亦有后卡缘露出
         */
        Stack({ alignContent: Alignment.TopStart }) {
          // 最底：再往右一点
          this.blankDocCard(10, '16%', 4.0)
          // 中层：略右
          this.blankDocCard(6, '13%', 2.0)
          // 前卡：截图主体（left≈(100-78)/2=11%）
          this.screenshotCard(0, '11%', -2.0)
        }
        .width('100%')
        .height(AILiveScanView.STACK_H)

        Column({ space: 6 }) {
          Text('AI 正在理解截图…')
            .fontSize(TypeScale.sectionTitle)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.stageTextPrimary())
          Text('识别负债 · 分期计划 · 账户信息')
            .fontSize(TypeScale.caption)
            .fontColor(this.stageTextSecondary())
          Text('点击空白处取消')
            .fontSize(TypeScale.kicker)
            .fontColor('rgba(242, 241, 239, 0.48)')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .padding({ left: 16, right: 16, top: 8, bottom: this.bottomSafe + 8 })
    }
    .width('100%')
    .height('100%')
  }
}
