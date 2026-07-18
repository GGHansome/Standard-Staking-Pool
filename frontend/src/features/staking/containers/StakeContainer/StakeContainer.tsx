import { StakeForm } from '../../components/StakeForm'
import { TransactionStatusAlert } from '../../components/TransactionStatusAlert'
import { useStakeSelector } from './server-store/selector'
import { useStakeMutation } from './server-store/mutation'
import type { StakeContainerProps } from './interface'

export function StakeContainer({
  poolAddress,
  stakingToken,
  isConnected,
  isPoolPaused,
  isRewardPeriodActive,
}: StakeContainerProps) {
  const { lockTiers, hasSetInviter, boundInviter } = useStakeSelector()
  const { mutation, approve, stake } = useStakeMutation({ poolAddress, stakingToken })

  const disabled = !isConnected || mutation.isPending

  return (
    <>
      <TransactionStatusAlert status={mutation.status} />
      <StakeForm
        tokenSymbol={stakingToken.symbol}
        lockTiers={lockTiers}
        isRewardPeriodActive={isRewardPeriodActive}
        hasSetInviter={hasSetInviter}
        boundInviter={boundInviter}
        disabled={disabled}
        stakeDisabled={isPoolPaused}
        onApprove={approve}
        onStake={stake}
      />
    </>
  )
}