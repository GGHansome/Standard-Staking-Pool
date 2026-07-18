export type RewardClaimCardProps = {
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  earnedRewards: bigint
  claimableReferral: bigint
  isPaused: boolean
  disabled: boolean
  claimDisabled: boolean
  onClaim: () => Promise<void>
}