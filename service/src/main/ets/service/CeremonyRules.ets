/** 累计结清笔数门槛：未达此数全清也不播仪式（保惊喜感） */
export const ALL_CLEARED_CEREMONY_MIN_SETTLED: number = 5

/**
 * 还款后是否将触发「全部结清仪式」（供 DebtsTab Toast 互斥）
 * activeCount：还款前 status!==completed 的笔数
 * mode：还款方式（payoff=一次性还清 / period=按期还）
 * remainingPeriods：该笔剩余期数（本期还后 remaining-1）
 * settledCountAfter：本笔若结清后的累计已结清笔数
 */
export function willClearAllAfterRepay(
  activeCount: number,
  mode: string,
  remainingPeriods: number,
  settledCountAfter: number = ALL_CLEARED_CEREMONY_MIN_SETTLED
): boolean {
  if (activeCount !== 1) {
    return false
  }
  const willClearLast: boolean = mode === 'payoff' || remainingPeriods <= 1
  if (!willClearLast) {
    return false
  }
  return settledCountAfter >= ALL_CLEARED_CEREMONY_MIN_SETTLED
}
