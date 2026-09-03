/**
 * 端侧分期计划表解析（从 LocalBillExtractService 拆出）
 * 覆盖：支付宝/花呗/美团「n/m 期 + 还款日 + 金额」截图，
 * 以及电商/白条「分期详情」序号列表（「1 1766.34 2026年07月12日」+ 千分位金额）
 */
import { ParseResult, ParseResultItem } from './AIService'
import { PeriodScanResult, allZero, creditAccountHint, fillConfidence, guessPlatform,
  matchMoney, pad2, parseDec, round2 } from './BillParseShared'

/**
 * 分期计划表 OCR 主入口；无法可靠识别时返回 null（交给 LLM）
 */
export function tryInstallmentPlanTable(text: string): ParseResult | null {
  if (!looksLikeBillOcr(text) && text.indexOf('期') < 0) {
    return null
  }
  const hasInstallmentHint =
    text.indexOf('分期') >= 0 ||
    text.indexOf('还款日') >= 0 ||
    text.indexOf('最后还款日') >= 0 ||
    text.indexOf('还款') >= 0 ||
    text.indexOf('账单分期') >= 0 ||
    text.indexOf('账单') >= 0 ||
    text.indexOf('分期详情') >= 0 ||
    text.indexOf('分期应还') >= 0 ||
    text.indexOf('分期本金') >= 0 ||
    /\d+\s*\/\s*\d+/.test(text)
  if (!hasInstallmentHint) {
    return null
  }

  let totalPeriods = 0
  // 1/3期、1/3 期、1／3期（全角斜杠）
  const normSlash = text.replace(/／/g, '/')
  const slashPeriod = normSlash.match(/(\d+)\s*\/\s*(\d+)\s*期?/)
  if (slashPeriod !== null && slashPeriod.length >= 3) {
    totalPeriods = parseInt(slashPeriod[2], 10)
  }
  if (!(totalPeriods > 0 && totalPeriods <= 120)) {
    const fenqi = text.match(/分\s*(\d+)\s*期/)
    if (fenqi !== null && fenqi.length >= 2) {
      totalPeriods = parseInt(fenqi[1], 10)
    }
  }
  // 电商/白条「分期详情」：无 n/m 期，靠序号行或还款日个数兜底
  if (!(totalPeriods > 0 && totalPeriods <= 120)) {
    totalPeriods = inferTotalPeriodsFromPlan(normSlash)
  }
  if (!(totalPeriods > 0 && totalPeriods <= 120)) {
    return null
  }

  // 分期金额 / 分期本金（优先「金额+标签」，避免标签后跨行吃到服务费 0.00）
  let principal: number | null = extractPrincipalAmount(text)

  // 逐期：OCR 常把金额/已还/服务费拆到下一行，按行窗口扫描
  const periodScan = scanInstallmentRows(normSlash, totalPeriods, principal)
  const periodAmounts = periodScan.amounts
  const periodFees = periodScan.fees
  const paidFlags = periodScan.paid
  const payDates = periodScan.dates

  let paidCount = 0
  for (let i = 0; i < paidFlags.length; i++) {
    if (paidFlags[i]) {
      paidCount++
    }
  }
  let remaining = totalPeriods - paidCount
  if (remaining < 0) {
    remaining = 0
  }
  if (paidCount === 0 && periodAmounts.length === totalPeriods) {
    remaining = totalPeriods
  }

  let monthly: number | null = null
  for (let i = 0; i < periodAmounts.length; i++) {
    if (!paidFlags[i] && periodAmounts[i] > 0) {
      monthly = periodAmounts[i]
      break
    }
  }
  if (monthly === null && periodAmounts.length > 0 && periodAmounts[0] > 0) {
    monthly = periodAmounts[0]
  }
  // 仍无月供：从全文取「像期供」的金额（排除本金、小额服务费）
  if (monthly === null) {
    monthly = guessInstallmentMonthly(normSlash, principal)
  }

  if (principal === null && monthly !== null && totalPeriods > 0) {
    principal = round2(monthly * totalPeriods)
  }
  if (principal === null && monthly === null) {
    return null
  }

  const platform = guessPlatform(text)
  let nextPay: string | null = null
  for (let i = 0; i < payDates.length; i++) {
    if (i >= paidFlags.length || !paidFlags[i]) {
      nextPay = payDates[i]
      break
    }
  }
  if (nextPay === null && payDates.length > 0) {
    nextPay = payDates[0]
  }
  // 全文再扫还款日（行窗口未抓到时）
  if (payDates.length === 0) {
    const allDates = scanAllPayDates(normSlash)
    for (let i = 0; i < allDates.length; i++) {
      payDates.push(allDates[i])
    }
    if (payDates.length > paidCount) {
      nextPay = payDates[paidCount]
    } else if (payDates.length > 0) {
      nextPay = payDates[0]
    }
  }

  let paymentDay: number | null = null
  if (nextPay !== null && nextPay.length >= 10) {
    paymentDay = parseInt(nextPay.substring(8, 10), 10)
    if (!(paymentDay >= 1 && paymentDay <= 31)) {
      paymentDay = null
    }
  }

  // 未还本金：优先用未还期金额之和，避免把已还期算进余额
  let unpaidBalance: number | null = null
  if (periodAmounts.length > 0) {
    let sumUnpaid = 0
    let hasUnpaid = false
    for (let i = 0; i < periodAmounts.length; i++) {
      if (!paidFlags[i] && periodAmounts[i] > 0) {
        sumUnpaid += periodAmounts[i]
        hasUnpaid = true
      }
    }
    if (hasUnpaid) {
      unpaidBalance = round2(sumUnpaid)
    }
  }
  if (unpaidBalance === null && monthly !== null && remaining > 0) {
    unpaidBalance = round2(monthly * remaining)
  }
  if (unpaidBalance === null) {
    unpaidBalance = principal
  }

  const item = new ParseResultItem()
  item.tempId = '1'
  item.recordType = 'debt'
  // 分期表识别到即视为分期（哪怕只剩 1 期未还）
  item.isComplete = principal !== null && monthly !== null && totalPeriods > 0
  item.parsedFields.set('platform', platform)
  item.parsedFields.set('debt_type', 'installment')
  if (principal !== null) {
    item.parsedFields.set('principal', principal)
  }
  if (unpaidBalance !== null) {
    item.parsedFields.set('current_balance', unpaidBalance)
  }
  if (monthly !== null) {
    item.parsedFields.set('monthly_payment', monthly)
  }
  item.parsedFields.set('total_periods', totalPeriods)
  item.parsedFields.set('remaining_periods', remaining)
  if (paymentDay !== null) {
    item.parsedFields.set('payment_day', paymentDay)
  }
  if (nextPay !== null) {
    item.parsedFields.set('next_payment_date', nextPay)
  }
  if (payDates.length > 0) {
    item.parsedFields.set('start_date', payDates[0])
  }
  // 供表单关联账户：单据分期常见于花呗/美团月付
  item.parsedFields.set('credit_account_hint', creditAccountHint(text, platform))
  // 完整还款计划（含已还期 + 图中本期金额/服务费）；text 留空，备注留给用户
  const scheduleNote = buildScheduleNote(
    totalPeriods, periodAmounts, periodFees, paidFlags, payDates, monthly, principal)
  item.parsedFields.set('note', scheduleNote)
  item.parsedFields.set('repayment_method', 'custom')

  fillConfidence(item, true)

  const result = new ParseResult()
  result.items.push(item)
  result.isComplete = item.isComplete
  result.clarifyQuestion = item.isComplete ? '' :
    '已识别分期金额与期数，请确认月供与还款日。'
  result.rawContent = 'LOCAL_RULE_INSTALLMENT_PLAN'
  return result
}

/** 宽松分期表检测：OCR 常把「期」识别成「其」或漏字 */
export function looksLikeBillOcr(text: string): boolean {
  const t = text.replace(/\s+/g, '')
  if (t.length < 8) {
    return false
  }
  if (t.indexOf('分期') >= 0 || t.indexOf('还款') >= 0 || t.indexOf('账单') >= 0) {
    return true
  }
  if (/\d+\/\d+/.test(t) && (t.indexOf('期') >= 0 || t.indexOf('元') >= 0)) {
    return true
  }
  // 多个金额 + 日期
  const moneyHits = t.match(/[0-9]+\.[0-9]{2}/g)
  if (moneyHits !== null && moneyHits.length >= 2 &&
    (t.indexOf('202') >= 0 || t.indexOf('还款') >= 0)) {
    return true
  }
  return false
}

/**
 * 生成与 CalculationService.parseCustomSchedule 兼容的 note。
 * 图中：本期应付 total = 本金 + 服务费；如 114.21 = 110.88 + 3.33。
 * 单位：分。text 空串。
 */
function buildScheduleNote(
  totalPeriods: number,
  amounts: number[],
  fees: number[],
  paid: boolean[],
  dates: string[],
  monthly: number | null,
  principal: number | null
): string {
  const rows: string[] = []
  for (let p = 1; p <= totalPeriods; p++) {
    const i = p - 1
    let totalYuan = 0
    if (i < amounts.length && amounts[i] > 0) {
      totalYuan = amounts[i]
    } else if (monthly !== null) {
      totalYuan = monthly
    } else if (principal !== null && totalPeriods > 0) {
      totalYuan = round2(principal / totalPeriods)
    }
    let feeYuan = 0
    if (i < fees.length && fees[i] >= 0) {
      feeYuan = fees[i]
    }
    // 兜底：末几期若总额明显大于常见月供，差额当服务费（114.21 - 110.87 ≈ 3.34）
    if (feeYuan <= 0 && monthly !== null && totalYuan > monthly + 0.5) {
      feeYuan = round2(totalYuan - monthly)
    }
    if (feeYuan > totalYuan) {
      feeYuan = 0
    }
    // 本金 = 本期应付 − 服务费（图中第 3 期 114.21 − 3.33 = 110.88）
    let principalYuan = round2(totalYuan - feeYuan)
    if (principalYuan < 0) {
      principalYuan = 0
    }
    const totalFen = Math.round(totalYuan * 100)
    const interestFen = Math.round(feeYuan * 100)
    // 用分差保证 本金+利息 = 总额，避免浮点误差（110.88+3.33=114.21）
    const principalFen = totalFen - interestFen
    const isPaid = i < paid.length ? paid[i] : false
    const dateStr = i < dates.length ? dates[i] : ''
    rows.push(
      '{"period_number":' + p +
      ',"principal":' + principalFen +
      ',"interest":' + interestFen +
      ',"total":' + totalFen +
      ',"paid":' + (isPaid ? 'true' : 'false') +
      ',"date":' + JSON.stringify(dateStr) +
      '}'
    )
  }
  return '{"custom_schedule":[' + rows.join(',') + '],"text":""}'
}

/**
 * 抽取分期本金/总额。
 * - 优先「金额 + 标签」（列布局 OCR 常金额在上）
 * - 其次「标签 + 同行金额」（禁止跨行，防吃到下一列服务费 0.00）
 * - 拒绝明显为 0 的误匹配
 */
function extractPrincipalAmount(text: string): number | null {
  const candidates: number[] = []
  const push = (n: number | null): void => {
    if (n !== null && n >= 1) {
      candidates.push(n)
    }
  }
  // 金额在标签前
  push(matchMoney(text, /([0-9]+(?:\.[0-9]+)?)\s*分期金额/))
  push(matchMoney(text, /([0-9]+(?:\.[0-9]+)?)\s*分期本金/))
  push(matchMoney(text, /([0-9]+(?:\.[0-9]+)?)\s*合计应还/))
  // 标签后同行（仅空格/制表，不含换行）
  push(matchMoney(text, /分期金额[ \t]*([0-9]+(?:\.[0-9]+)?)/))
  push(matchMoney(text, /分期本金[ \t]*([0-9]+(?:\.[0-9]+)?)/))
  push(matchMoney(text, /合计应还[ \t]*([0-9]+(?:\.[0-9]+)?)/))
  // 兼容旧：标签后任意空白（含换行），但须 ≥20 防 0.00
  const loose = matchMoney(text, /分期(?:金额|本金)\s+([0-9]+(?:\.[0-9]+)?)/)
  if (loose !== null && loose >= 20) {
    candidates.push(loose)
  }
  if (candidates.length === 0) {
    return null
  }
  // 多个候选取最大（本金/合计应还通常最大；服务费最小）
  let best = candidates[0]
  for (let i = 1; i < candidates.length; i++) {
    if (candidates[i] > best) {
      best = candidates[i]
    }
  }
  return best
}

/**
 * 无「n/m 期」「分 N 期」时，从序号计划表或还款日个数推断总期数。
 * 覆盖京东/白条等「分期详情」：①/1 + 金额 + 最后还款日。
 */
function inferTotalPeriodsFromPlan(text: string): number {
  const numbered = scanNumberedPlanRows(text, 0, null)
  const nValid = countFilledPeriods(numbered)
  if (nValid >= 2 && nValid <= 120) {
    return nValid
  }
  // 强分期语境下，还款日条数可当总期数（≥2 防误伤）
  const strong =
    text.indexOf('分期') >= 0 ||
    text.indexOf('最后还款日') >= 0 ||
    text.indexOf('分期应还') >= 0 ||
    text.indexOf('分期本金') >= 0 ||
    text.indexOf('分期详情') >= 0
  if (strong) {
    const dates = scanAllPayDates(text)
    if (dates.length >= 2 && dates.length <= 120) {
      return dates.length
    }
  }
  // 仅扫到 1 行序号但语境明确：仍接受 1（末期）
  if (nValid === 1 && strong) {
    return 1
  }
  return 0
}

/** 有效期数：有金额或还款日的槽位数（忽略中间空槽导致的虚高 length） */
function countFilledPeriods(scan: PeriodScanResult): number {
  let n = 0
  for (let i = 0; i < scan.amounts.length; i++) {
    const hasAmt = scan.amounts[i] > 0
    const hasDate = i < scan.dates.length && scan.dates[i].length > 0
    if (hasAmt || hasDate) {
      n++
    }
  }
  return n
}

/**
 * 扫描「n/m 期」或「序号 + 金额 + 日期」行，抓金额 / 已还 / 还款日。
 */
function scanInstallmentRows(text: string, totalPeriods: number,
  principal: number | null): PeriodScanResult {
  const out = new PeriodScanResult()
  const lines = text.split('\n')
  for (let i = 0; i < lines.length; i++) {
    const line = lines[i]
    const pm = line.match(/(\d+)\s*\/\s*(\d+)\s*期?/)
    if (pm === null) {
      continue
    }
    const idx = parseInt(pm[1], 10)
    const total = parseInt(pm[2], 10)
    if (total !== totalPeriods && totalPeriods > 0) {
      // 仍接受，以行内 total 为准
    }
    // 扩到后 4 行：金额、还款日、含服务费常拆行
    let window = line
    for (let k = 1; k <= 4; k++) {
      if (i + k < lines.length) {
        window = window + ' ' + lines[i + k]
      }
    }
    const paid = window.indexOf('已还') >= 0 || window.indexOf('已结清') >= 0 ||
      window.indexOf('已还清') >= 0
    // 本期应付总额（图右上大号金额 110.87 / 114.21）
    const amt = periodTotalInWindow(window, principal)
    // 含服务费 0.00 / 3.33（取当前有效值，非划线价）
    const fee = serviceFeeInWindow(window)
    out.amounts.push(amt !== null ? amt : 0)
    out.fees.push(fee)
    out.paid.push(paid)
    const dateInWin = scanAllPayDates(window)
    if (dateInWin.length > 0) {
      out.dates.push(dateInWin[0])
    } else {
      out.dates.push('')
    }
  }
  // n/m 未命中：试序号列表（1 1766.34 2026年07月12日）
  if (out.amounts.length === 0 || allZero(out.amounts)) {
    const numbered = scanNumberedPlanRows(text, totalPeriods, principal)
    if (numbered.amounts.length > 0 && !allZero(numbered.amounts)) {
      return numbered
    }
  }
  // 若行扫没抓到期供金额，用全文启发式补 amounts 长度
  if (out.amounts.length === 0 || allZero(out.amounts)) {
    const guessed = collectPeriodLikeAmounts(text, principal, totalPeriods)
    for (let g = 0; g < guessed.length; g++) {
      if (g < out.amounts.length) {
        if (out.amounts[g] <= 0) {
          out.amounts[g] = guessed[g]
        }
      } else {
        out.amounts.push(guessed[g])
        out.fees.push(0)
        out.paid.push(false)
        out.dates.push('')
      }
    }
    // 对齐 fees 长度
    while (out.fees.length < out.amounts.length) {
      out.fees.push(0)
    }
    // 日期仍空时补全文还款日
    if (out.dates.length > 0) {
      const allDates = scanAllPayDates(text)
      for (let d = 0; d < out.dates.length && d < allDates.length; d++) {
        if (out.dates[d].length === 0) {
          out.dates[d] = allDates[d]
        }
      }
    }
  }
  return out
}

/**
 * 序号计划行：行首 1/① 或「1 金额 日期」粘连，覆盖电商分期详情表。
 * totalPeriods=0 时只计数/采集，不截断。
 */
function scanNumberedPlanRows(text: string, totalPeriods: number,
  principal: number | null): PeriodScanResult {
  const out = new PeriodScanResult()
  const lines = text.split('\n')
  const circle = '①②③④⑤⑥⑦⑧⑨⑩⑪⑫'
  // 行扫描：序号 + 邻窗金额/日期
  for (let i = 0; i < lines.length; i++) {
    const rawLine = lines[i]
    const line = rawLine.trim()
    if (line.length === 0) {
      continue
    }
    let idx = 0
    const c0 = line.charAt(0)
    const ci = circle.indexOf(c0)
    if (ci >= 0) {
      idx = ci + 1
    } else {
      // 行首 1 / 1. / 1、 / 1) ，且后续像金额或日期（防误吃商品名里的数字）
      const hm = line.match(/^(\d{1,2})(?:[.、．)）]\s*|\s+)(.*)$/)
      if (hm === null || hm.length < 3) {
        continue
      }
      idx = parseInt(hm[1], 10)
      const rest = hm[2]
      const restHasMoney = /[0-9]+\.[0-9]{2}/.test(rest)
      const restHasDate = /[0-9]{4}[-/.年]/.test(rest)
      // 纯「1」且后续无金额/日期：扩后 3 行再判
      if (!restHasMoney && !restHasDate) {
        let look = rest
        for (let k = 1; k <= 3; k++) {
          if (i + k < lines.length) {
            look = look + ' ' + lines[i + k]
          }
        }
        if (!/[0-9]+\.[0-9]{2}/.test(look) && !/[0-9]{4}[-/.年]/.test(look)) {
          continue
        }
      }
    }
    if (idx < 1 || idx > 120) {
      continue
    }
    if (totalPeriods > 0 && idx > totalPeriods) {
      continue
    }
    // 已按期序写入过则跳过（防重复）
    if (out.amounts.length >= idx && out.amounts[idx - 1] > 0) {
      continue
    }
    let window = line
    for (let k = 1; k <= 3; k++) {
      if (i + k < lines.length) {
        window = window + ' ' + lines[i + k]
      }
    }
    const paid = window.indexOf('已还') >= 0 || window.indexOf('已结清') >= 0 ||
      window.indexOf('已还清') >= 0
    // 优先「序号后首个金额」，避免窗口扫到上方本金 5299
    let amt = firstPeriodAmountAfterIndex(line, principal)
    if (amt === null) {
      amt = periodTotalInWindow(window, principal)
    }
    // 若命中本金级大额（≈总额），丢弃改用窗口内更小的期供
    if (amt !== null && principal !== null && Math.abs(amt - principal) < 0.02) {
      amt = periodTotalInWindow(window, principal)
    }
    const fee = serviceFeeInWindow(window)
    const dateInWin = scanAllPayDates(window)
    // 必须有金额或日期才算一期，避免把状态栏「1」当期号
    if ((amt === null || amt <= 0) && dateInWin.length === 0) {
      continue
    }
    // 按 idx 对齐稀疏数组
    while (out.amounts.length < idx) {
      out.amounts.push(0)
      out.fees.push(0)
      out.paid.push(false)
      out.dates.push('')
    }
    out.amounts[idx - 1] = amt !== null ? amt : 0
    out.fees[idx - 1] = fee
    out.paid[idx - 1] = paid
    out.dates[idx - 1] = dateInWin.length > 0 ? dateInWin[0] : ''
  }

  // 单行粘连：1 1766.34 2026年07月12日 2 1766.33 ...
  if (out.amounts.length === 0 || allZero(out.amounts)) {
    const flat = text.replace(/\n/g, ' ')
    const re = /(?:^|[^\d])(\d{1,2})\s+([0-9]+\.[0-9]{2})\s+([0-9]{4})[-/.年]([0-9]{1,2})[-/.月]([0-9]{1,2})/g
    let m: RegExpExecArray | null = re.exec(flat)
    const tmpAmt: number[] = []
    const tmpDate: string[] = []
    while (m !== null) {
      const idx = parseInt(m[1], 10)
      const n = round2(parseFloat(m[2]))
      if (idx >= 1 && idx <= 120 && n >= 5) {
        if (principal === null || Math.abs(n - principal) > 0.001) {
          while (tmpAmt.length < idx) {
            tmpAmt.push(0)
            tmpDate.push('')
          }
          tmpAmt[idx - 1] = n
          const mo = pad2(parseInt(m[4], 10))
          const d = pad2(parseInt(m[5], 10))
          tmpDate[idx - 1] = `${m[3]}-${mo}-${d}`
        }
      }
      m = re.exec(flat)
    }
    for (let t = 0; t < tmpAmt.length; t++) {
      if (tmpAmt[t] > 0) {
        out.amounts.push(tmpAmt[t])
        out.fees.push(0)
        out.paid.push(false)
        out.dates.push(tmpDate[t])
      }
    }
  }

  // 截断到 totalPeriods
  if (totalPeriods > 0 && out.amounts.length > totalPeriods) {
    out.amounts = out.amounts.slice(0, totalPeriods)
    out.fees = out.fees.slice(0, totalPeriods)
    out.paid = out.paid.slice(0, totalPeriods)
    out.dates = out.dates.slice(0, totalPeriods)
  }
  return out
}

/** 行内序号后的第一个 xx.xx（期供），排除本金 */
function firstPeriodAmountAfterIndex(line: string, principal: number | null): number | null {
  const m = line.match(/(?:^[①②③④⑤⑥⑦⑧⑨⑩⑪⑫]|^(\d{1,2})(?:[.、．)）]|\s))\s*([0-9]+\.[0-9]{2})/)
  if (m !== null) {
    // 分组：有捕获期号时金额在最后一组
    const raw = m[m.length - 1]
    const n = round2(parseFloat(raw))
    if (n >= 5 && (principal === null || Math.abs(n - principal) > 0.001)) {
      return n
    }
  }
  // 宽松：行内第一个非本金金额
  const re = /([0-9]+\.[0-9]{2})/g
  let mm: RegExpExecArray | null = re.exec(line)
  while (mm !== null) {
    const n = round2(parseFloat(mm[1]))
    if (n >= 5 && (principal === null || Math.abs(n - principal) > 0.001)) {
      return n
    }
    mm = re.exec(line)
  }
  return null
}

/**
 * 窗口内本期总额：取 ≥20 的最大 xx.xx，且非分期本金。
 * 图中 110.87 / 114.21 为本期应付；3.33 为服务费。
 */
function periodTotalInWindow(window: string, principal: number | null): number | null {
  const re = /([0-9]+\.[0-9]{2})/g
  let best: number | null = null
  let m: RegExpExecArray | null = re.exec(window)
  while (m !== null) {
    const n = round2(parseFloat(m[1]))
    if (n >= 20) {
      if (principal === null || Math.abs(n - principal) > 0.001) {
        if (best === null || n > best) {
          best = n
        }
      }
    }
    m = re.exec(window)
  }
  return best
}

/**
 * 图中：「含服务费0.00 3.33」→ 当前有效 0.00（划线 3.33 忽略）
 * 「含服务费3.33」→ 3.33
 * OCR 变体：无「含」、小数点变逗号、粘连 0.003.33
 */
function serviceFeeInWindow(window: string): number {
  // 含服务费0.00 3.33 / 服务费 0.00 3.33
  let m = window.match(/服务费\s*([0-9]+[.,][0-9]{2})\s*([0-9]+[.,][0-9]{2})?/)
  if (m !== null && m.length >= 2) {
    const first = parseDec(m[1])
    // 第一个是当前展示值（可能 0.00）
    if (first !== null && first >= 0) {
      return first
    }
  }
  // 服务费3.33（单值）
  m = window.match(/服务费\s*([0-9]+[.,][0-9]{1,2})/)
  if (m !== null && m.length >= 2) {
    const n = parseDec(m[1])
    if (n !== null && n >= 0) {
      return n
    }
  }
  return 0
}

export function scanAllPayDates(text: string): string[] {
  const payDates: string[] = []
  const dateRe = /(?:还款日)?\s*([0-9]{4})[-/.年]([0-9]{1,2})[-/.月]([0-9]{1,2})/g
  let dm: RegExpExecArray | null = dateRe.exec(text)
  while (dm !== null) {
    const y = parseInt(dm[1], 10)
    if (y >= 2020 && y <= 2100) {
      const mo = pad2(parseInt(dm[2], 10))
      const d = pad2(parseInt(dm[3], 10))
      payDates.push(`${dm[1]}-${mo}-${d}`)
    }
    dm = dateRe.exec(text)
  }
  return payDates
}

/** 收集像「期供」的 xx.xx（排除本金与小额服务费） */
function collectPeriodLikeAmounts(text: string, principal: number | null,
  totalPeriods: number): number[] {
  const found: number[] = []
  const re = /([0-9]+\.[0-9]{2})/g
  let m: RegExpExecArray | null = re.exec(text)
  while (m !== null) {
    const n = round2(parseFloat(m[1]))
    if (n < 5) {
      m = re.exec(text)
      continue
    }
    if (principal !== null && Math.abs(n - principal) < 0.001) {
      m = re.exec(text)
      continue
    }
    found.push(n)
    m = re.exec(text)
  }
  if (found.length > totalPeriods && totalPeriods > 0) {
    return found.slice(found.length - totalPeriods)
  }
  return found
}

function guessInstallmentMonthly(text: string, principal: number | null): number | null {
  const list = collectPeriodLikeAmounts(text, principal, 12)
  if (list.length === 0) {
    return null
  }
  // 取出现次数最多的金额（两期同额 110.87）
  let best = list[0]
  let bestCnt = 1
  for (let i = 0; i < list.length; i++) {
    let c = 0
    for (let j = 0; j < list.length; j++) {
      if (Math.abs(list[i] - list[j]) < 0.001) {
        c++
      }
    }
    if (c > bestCnt) {
      bestCnt = c
      best = list[i]
    }
  }
  return best
}
