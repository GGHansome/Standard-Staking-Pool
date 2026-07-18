import { BaseError } from 'wagmi'

type ReadResult = {
  status?: string
  result?: unknown
}

type RewardAllowanceInput = {
  baseRewardAmount: bigint
  injectedBaseCumulative: bigint
  maxSubsidyRate: bigint
  maxSweepableSubsidy: bigint
}

export type RewardAllowance = {
  baseRewardAmount: bigint
  subsidyTopUp: bigint
  total: bigint
}

const BPS_BASE = 10_000n

export function calculateRequiredRewardAllowance({
  baseRewardAmount,
  injectedBaseCumulative,
  maxSubsidyRate,
  maxSweepableSubsidy,
}: RewardAllowanceInput): RewardAllowance {
  const previousSubsidyBudget = (injectedBaseCumulative * maxSubsidyRate) / BPS_BASE
  const nextSubsidyBudget =
    ((injectedBaseCumulative + baseRewardAmount) * maxSubsidyRate) / BPS_BASE
  const requiredSubsidy = nextSubsidyBudget - previousSubsidyBudget
  const subsidyTopUp =
    requiredSubsidy > maxSweepableSubsidy ? requiredSubsidy - maxSweepableSubsidy : 0n

  return {
    baseRewardAmount,
    subsidyTopUp,
    total: baseRewardAmount + subsidyTopUp,
  }
}

export function readAt<T>(data: readonly unknown[] | undefined, index: number, fallback: T): T {
  const item = data?.[index] as ReadResult | undefined
  return item?.status === 'success' && item.result !== undefined ? (item.result as T) : fallback
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof BaseError) {
    return error.shortMessage || error.message
  }

  if (error instanceof Error) {
    return error.message
  }

  return '交易执行失败'
}
