/**
 * 首页副文组合器：用审过的短词按固定句式拼接。
 * 不拉外网、不靠关键词筛语义；组合空间大，不会像固定句库那样很快轮完。
 */
export class HomeSubtitleComposer {
  static readonly WHEN: string[] = [
    '今天', '此刻', '眼下', '现在', '接下来', '这一步'
  ]

  static readonly ACT: string[] = [
    '向前走一步', '慢慢来', '把眼前做好', '再走近一点', '把脚步放稳',
    '把小事做好', '把节奏放稳', '再往前一点', '走稳脚下', '先做好手头',
    '把心放稳', '把今天过好', '把这一步走完', '抬头往前看', '把小事做完'
  ]

  static readonly CLOSE: string[] = [
    '也算数', '就是向前', '风景会变好', '每一步都算数', '答案在路上',
    '已经在路上', '就很好', '总会有回响', '路就在脚下', '已经很好',
    '还在向前'
  ]

  static whenCount(): number {
    return HomeSubtitleComposer.WHEN.length
  }

  static actCount(): number {
    return HomeSubtitleComposer.ACT.length
  }

  static closeCount(): number {
    return HomeSubtitleComposer.CLOSE.length
  }

  /** 三套句式互不重叠计数 */
  static capacity(): number {
    const w = HomeSubtitleComposer.whenCount()
    const a = HomeSubtitleComposer.actCount()
    const c = HomeSubtitleComposer.closeCount()
    return w * a * c + w * a + a * c
  }

  static composeAt(index: number): string {
    const w = HomeSubtitleComposer.whenCount()
    const a = HomeSubtitleComposer.actCount()
    const c = HomeSubtitleComposer.closeCount()
    const n3 = w * a * c
    const n2a = w * a
    const n2b = a * c
    const total = n3 + n2a + n2b
    let i = index % total
    if (i < 0) {
      i = i + total
    }
    if (i < n3) {
      const closeI = i % c
      const rest = Math.floor(i / c)
      const actI = rest % a
      const whenI = Math.floor(rest / a)
      return HomeSubtitleComposer.WHEN[whenI] + '，' +
        HomeSubtitleComposer.ACT[actI] + '，' +
        HomeSubtitleComposer.CLOSE[closeI]
    }
    i = i - n3
    if (i < n2a) {
      const actI = i % a
      const whenI = Math.floor(i / a)
      return HomeSubtitleComposer.WHEN[whenI] + '也' + HomeSubtitleComposer.ACT[actI]
    }
    i = i - n2a
    const closeI = i % c
    const actI = Math.floor(i / c)
    return HomeSubtitleComposer.ACT[actI] + '，' + HomeSubtitleComposer.CLOSE[closeI]
  }

  static isComposed(text: string): boolean {
    if (text.length === 0) {
      return false
    }
    const total = HomeSubtitleComposer.capacity()
    for (let i = 0; i < total; i++) {
      if (HomeSubtitleComposer.composeAt(i) === text) {
        return true
      }
    }
    return false
  }
}
