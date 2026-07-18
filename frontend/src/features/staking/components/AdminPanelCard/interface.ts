import type { PenaltyView, SubsidyView } from '../../types'

export type AdminPanelCardProps = {
  isPaused: boolean
  disabled: boolean
  subsidy: SubsidyView
  penalty: PenaltyView
  baseRewardReserve: bigint
  maxSweepableSubsidy: bigint
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  onPause: () => Promise<void>
  onUnpause: () => Promise<void>
  onSetTreasury: (treasury: string) => Promise<void>
  onSweepSubsidy: (to: string, rawAmount: string) => Promise<void>
  onSweepExpiredBaseReward: (to: string) => Promise<void>
  onRecoverToken: (tokenAddress: string, rawAmount: string) => Promise<void>
  onGrantOperatorRole: (account: string) => Promise<void>
}