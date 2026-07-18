import type { DepositItem } from '../../types'

export type DepositTableProps = {
  deposits: DepositItem[]
  chainTimestamp?: bigint
  loading?: boolean
  disabled?: boolean
  penaltyRate: bigint
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  stakingTokenSymbol: string
  stakingTokenDecimals: number
  onWithdraw: (depositId: bigint) => Promise<void>
  onWithdrawMultiple: (depositIds: bigint[]) => Promise<void>
  onExit: () => Promise<void>
}