import type { Address } from 'viem'
import type { SubsidyView, TokenView } from '../../types'

export type OperatorRewardContainerProps = {
  poolAddress: Address
  rewardToken: TokenView
  subsidy: SubsidyView
  maxSweepableSubsidy: bigint
  injectedBaseCumulative: bigint
  isConnected: boolean
  isPaused: boolean
}