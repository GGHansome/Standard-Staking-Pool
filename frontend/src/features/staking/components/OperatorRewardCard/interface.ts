import type { SubsidyView } from '../../types'

export type OperatorRewardCardProps = {
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  rewardTokenAllowance: bigint
  subsidy: SubsidyView
  maxSweepableSubsidy: bigint
  injectedBaseCumulative: bigint
  disabled: boolean
  approveDisabled: boolean
  notifyDisabled: boolean
  onApprove: (amount: string) => Promise<void>
  onNotify: (amount: string) => Promise<void>
}