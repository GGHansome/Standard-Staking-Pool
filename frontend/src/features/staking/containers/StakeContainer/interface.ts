import type { Address } from 'viem'
import type { TokenView } from '../../types'

export type StakeContainerProps = {
  poolAddress: Address
  stakingToken: TokenView
  isConnected: boolean
  isPoolPaused: boolean
  isRewardPeriodActive: boolean
}