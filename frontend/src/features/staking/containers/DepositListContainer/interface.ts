import type { Address } from 'viem'
import type { TokenView } from '../../types'

export type DepositListContainerProps = {
  poolAddress: Address
  chainTimestamp?: bigint
  stakingToken: TokenView
  rewardToken: TokenView
  penaltyRate: bigint
  isConnected: boolean
}