import { ReferralCard } from '../../components/ReferralCard'
import { useReferralSelector } from './server-store/selector'
import type { ReferralContainerProps } from './interface'

export function ReferralContainer({ rewardToken }: ReferralContainerProps) {
  const referral = useReferralSelector()

  return (
    <ReferralCard
      referral={referral}
      rewardTokenSymbol={rewardToken.symbol}
      rewardTokenDecimals={rewardToken.decimals}
    />
  )
}