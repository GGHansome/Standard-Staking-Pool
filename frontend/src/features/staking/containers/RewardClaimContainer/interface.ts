import type { Address } from 'viem'
import type { TokenView } from '../../types'

export type RewardClaimContainerProps = {
  poolAddress: Address
  rewardToken: TokenView
  isConnected: boolean
  isPaused: boolean
}