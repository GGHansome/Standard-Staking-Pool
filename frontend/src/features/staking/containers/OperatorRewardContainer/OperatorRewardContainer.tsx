import { OperatorRewardCard } from '../../components/OperatorRewardCard'
import { TransactionStatusAlert } from '../../components/TransactionStatusAlert'
import { useOperatorMutation } from './server-store/mutation'
import type { OperatorRewardContainerProps } from './interface'

export function OperatorRewardContainer({
  poolAddress,
  rewardToken,
  subsidy,
  maxSweepableSubsidy,
  injectedBaseCumulative,
  isConnected,
  isPaused,
}: OperatorRewardContainerProps) {
  const { mutation, approve, notify } = useOperatorMutation({
    poolAddress,
    rewardToken,
    maxSubsidyRate: subsidy.maxSubsidyRate,
    maxSweepableSubsidy,
    injectedBaseCumulative,
  })

  const disabled = !isConnected || mutation.isPending

  return (
    <>
      <TransactionStatusAlert status={mutation.status} />
      <OperatorRewardCard
        rewardTokenSymbol={rewardToken.symbol}
        rewardTokenDecimals={rewardToken.decimals}
        rewardTokenAllowance={rewardToken.allowance}
        subsidy={subsidy}
        maxSweepableSubsidy={maxSweepableSubsidy}
        injectedBaseCumulative={injectedBaseCumulative}
        disabled={disabled}
        approveDisabled={disabled}
        notifyDisabled={disabled || isPaused}
        onApprove={approve}
        onNotify={notify}
      />
    </>
  )
}