import type { Address } from 'viem'
import type { PenaltyView, SubsidyView, TokenView } from '../../types'

export type AdminContainerProps = {
  poolAddress: Address
  operatorRole: `0x${string}`
  rewardToken: TokenView
  subsidy: SubsidyView
  penalty: PenaltyView
  baseRewardReserve: bigint
  maxSweepableSubsidy: bigint
  isPaused: boolean
  isConnected: boolean
}