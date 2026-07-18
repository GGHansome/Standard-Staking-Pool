import { RewardClaimCard } from '../../components/RewardClaimCard'
import { TransactionStatusAlert } from '../../components/TransactionStatusAlert'
import { useRewardClaimSelector } from './server-store/selector'
import { useRewardClaimMutation } from './server-store/mutation'
import type { RewardClaimContainerProps } from './interface'

export function RewardClaimContainer({
  poolAddress,
  rewardToken,
  isConnected,
  isPaused,
}: RewardClaimContainerProps) {
  const { earnedRewards, claimableReferral } = useRewardClaimSelector()
  const { mutation, claim } = useRewardClaimMutation({ poolAddress })

  const disabled = !isConnected || mutation.isPending
  const claimDisabled = isPaused || earnedRewards + claimableReferral === 0n

  return (
    <>
      <TransactionStatusAlert status={mutation.status} />
      <RewardClaimCard
        rewardTokenSymbol={rewardToken.symbol}
        rewardTokenDecimals={rewardToken.decimals}
        earnedRewards={earnedRewards}
        claimableReferral={claimableReferral}
        isPaused={isPaused}
        disabled={disabled}
        claimDisabled={claimDisabled}
        onClaim={claim}
      />
    </>
  )
}