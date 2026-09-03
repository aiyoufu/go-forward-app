/**
 * 首页积极向上励志副文库（诗词名句 / 名家名言 / 影视经典台词 / 哲理）
 * 100% 严选正能量与前行动力，杜绝任何消极、批判或反讽文案
 * 支持 Fisher-Yates 洗牌不重复轮换机制
 */
export class InspirationalQuotes {
  static readonly QUOTES: string[] = [
    // ─── 经典诗词（豪迈、豁达、拼搏、希望） ───
    '长风破浪会有时，直挂云帆济沧海',
    '沉舟侧畔千帆过，病树前头万木春',
    '千磨万击还坚劲，任尔东西南北风',
    '雄关漫道真如铁，而今迈步从头越',
    '追风赶月莫停留，平芜尽处是春山',
    '流水不争先，争的是滔滔不绝',
    '山重水复疑无路，柳暗花明又一村',
    '竹杖芒鞋轻胜马，谁怕？一蓑烟雨任平生',
    '星光不问赶路人，时光不负有心人',
    '博观而约取，厚积而薄发',
    '莫愁前路无知己，天下谁人不识君',
    '欲穷千里目，更上一层楼',
    '会当凌绝顶，一览众山小',
    '大鹏一日同风起，扶摇直上九万里',
    '潮平两岸阔，风正一帆悬',
    '不畏浮云遮望眼，自缘身在最高层',
    '春风得意马蹄疾，一日看尽长安花',
    '纸上得来终觉浅，绝知此事要躬行',
    '读书破万卷，下笔如有神',
    '仰天大笑出门去，我辈岂是蓬蒿人',
    '愿君乘风破浪，踏遍青山不觉老',
    '少年何妨梦摘星，敢挽桑弓射玉衡',
    '鲜衣怒马少年时，不负韶华行且知',
    '莫道桑榆晚，为霞尚满天',
    '日日行不怕万里，常常做不怕万事',
    '九层之台起于累土，千里之行始于足下',
    '路虽远行则将至，事虽难做则必成',
    '不积跬步无以至千里，不积小流无以成江海',

    // ─── 中外文学与名家名言（治愈、热爱、笃定、坚韧） ───
    '万物皆有裂痕，那是光照进来的地方',
    '认清生活的真相后，依然热爱生活',
    '每一个不曾起舞的日子，都是对生命的辜负',
    '前路漫漫亦灿灿，笃行步步亦生花',
    '心之所向，素履以往，生如逆旅，一苇以航',
    '只要在路上，就没有到不了的远方',
    '保持热爱，奔赴下一场山海',
    '所有的伟大，都源于一个勇敢的开始',
    '在最黑暗的夜，也能看见最亮的星',
    '生活原本沉闷，但跑起来就有风',
    '向光而行，必有回响',
    '心中有光，何惧路长',
    '每一个走过的当下，都是未来的铺路石',
    '人生没有白走的路，每一步都算数',
    '慢一点没关系，只要是在往前走',
    '愿你历尽千帆，归来仍是少年',
    '做自己的光，不需要太亮，足以照亮前行',
    '凡是过往皆为序章，凡是未来皆有可期',
    '那些看似波澜不惊的日复一日，终见坚持的意义',
    '世界会给那些有目标和远见的人让路',
    '勇敢的人先享受世界',
    '在自己热爱的世界里，闪闪发光',
    '无论身处何地，心中总有春暖花开',
    '步履不停，生活自会给你答案',
    '保持内心的光，总有人借此走出黑暗',
    '满怀希望，就会所向披靡',
    '把普通的生活过得浪漫而有力量',
    '热爱可抵岁月漫长，温柔可挡艰难时光',
    '心怀希望，向光而行，所行皆坦途',

    // ─── 影视经典与励志台词（希望、拼搏、信念、力量） ───
    '希望是个好东西，也许是最好的东西',
    '永远不要让别人告诉你，你不能做什么',
    '生活就像一盒巧克力，结果往往充满惊喜',
    '风雨过后，眼前总会出现彩虹',
    '走好选择的路，别只选好走的路',
    '把每一个平凡的日子，过得热气腾腾',
    '向前走，答案就在前面的路上',
    '不负光阴，不负自己，笃定前行',
    '要坚信，所有美好都正在奔向你的路上',
    '生命必须有裂缝，阳光才能照得进来',
    '只要明天还在，我们就还有无限可能',
    '你必须非常努力，才能看起来毫不费力',
    '今天的坚持，是为了明天的从容',
    '任何时候开始，都不算晚',
    '沿着星光走，终会迎来黎明',
    '勇敢走出去，你会发现世界比想象的大得多',
    '沉住气，悄悄拔尖，然后惊艳所有人',
    '愿你的努力配得上你的梦想',
    '生活总会给你答案，只要你足够耐心',
    '每一个微小的进步，都是向前的力量',
    '行你所行，爱你所爱，听从你心，无问西东',
    '哪怕只有微弱的光，也要全力照亮前方',
    '追光的人，终会身披万丈光芒',
    '脚踏实地，仰望星空',
    '最好的时光，永远是当下与前方',
    '不慌不忙，心之所向，步步皆是风景',
    '只要心怀暖阳，何惧岁月沧桑',
    '往前看，往前走，风景一直在变好',
    '把脚步放稳，每一天都充满希望',

    // ─── 经典哲理与生活态度 ───
    '种一棵树最好的时间是十年前，其次是现在',
    '每一个晨曦，都是新希望的起点',
    '保持纯粹，保持热爱，稳步向前',
    '认准方向，所有的路都会通向远方',
    '即使身处沟壑，也要仰望星空',
    '越努力越幸运，越前行越开阔',
    '专注当下，静待花开',
    '往前走，每一步都在靠近更好的自己',
    '心有锦绣，何必远方；笃定前行，自成光芒',
    '今天也向前走一步',
    '一步一步，也能走很远',
    '先做好眼前这一件',
    '慢慢来，也比较快',
    '把小事做好，就是向前'
  ]

  private static shuffledIndices: number[] = []
  private static currentIndex: number = 0

  /**
   * 洗牌算法：重置并随机打乱所有金句索引
   */
  private static shuffleDeck(): void {
    const total = InspirationalQuotes.QUOTES.length
    const indices: number[] = []
    for (let i = 0; i < total; i++) {
      indices.push(i)
    }
    // Fisher-Yates shuffle
    for (let i = total - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1))
      const temp = indices[i]
      indices[i] = indices[j]
      indices[j] = temp
    }
    InspirationalQuotes.shuffledIndices = indices
    InspirationalQuotes.currentIndex = 0
  }

  /**
   * 获取下一条不重复的积极向上金句（整套播完后重新洗牌，100% 绝不连续重复）
   */
  static nextQuote(): string {
    const total = InspirationalQuotes.QUOTES.length
    if (total === 0) {
      return '保持节奏，稳步向前'
    }
    if (InspirationalQuotes.shuffledIndices.length !== total ||
        InspirationalQuotes.currentIndex >= total) {
      InspirationalQuotes.shuffleDeck()
    }
    const quoteIndex = InspirationalQuotes.shuffledIndices[InspirationalQuotes.currentIndex]
    InspirationalQuotes.currentIndex++
    return InspirationalQuotes.QUOTES[quoteIndex]
  }

  /**
   * 根据索引获取特定语句（用于测试或指定展示）
   */
  static getQuote(index: number): string {
    if (index < 0 || index >= InspirationalQuotes.QUOTES.length) {
      return InspirationalQuotes.QUOTES[0]
    }
    return InspirationalQuotes.QUOTES[index]
  }

  /** 是否为本库严选句（用于丢弃历史接口缓存） */
  static contains(text: string): boolean {
    if (text.length === 0) {
      return false
    }
    return InspirationalQuotes.QUOTES.indexOf(text) >= 0
  }

  /**
   * 重置（测试用）
   */
  static resetForTest(): void {
    InspirationalQuotes.shuffledIndices = []
    InspirationalQuotes.currentIndex = 0
  }
}
