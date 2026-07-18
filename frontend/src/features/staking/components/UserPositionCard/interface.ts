export type UserPositionCardProps = {
  stakingTokenSymbol: string
  stakingTokenDecimals: number
  stakingWalletBalance: bigint
  stakingAllowance: bigint
  totalStaked: bigint
  activeDepositCount: number
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  earnedRewards: bigint
  claimableReferral: bigint
}