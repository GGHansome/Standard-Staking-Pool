import type { Address } from 'viem'
import type { LockTier, PenaltyView, SubsidyView } from '../../types'

export type PoolOverviewCardProps = {
  isPaused: boolean
  isRewardPeriodActive: boolean
  totalSupply: bigint
  rewardsDuration: bigint
  periodFinish: bigint
  chainTimestamp?: bigint
  apr?: number
  rewardPerSecond?: number
  lockTiers: LockTier[]
  subsidy: SubsidyView
  penalty: PenaltyView
  stakingTokenAddress?: Address
  stakingTokenSymbol: string
  stakingTokenDecimals: number
  stakingTokenUsdPrice?: number
  rewardTokenAddress?: Address
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  rewardTokenUsdPrice?: number
}