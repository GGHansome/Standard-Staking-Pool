import { AdminPanelCard } from '../../components/AdminPanelCard'
import { TransactionStatusAlert } from '../../components/TransactionStatusAlert'
import { useAdminMutation } from './server-store/mutation'
import type { AdminContainerProps } from './interface'

export function AdminContainer({
  poolAddress,
  operatorRole,
  rewardToken,
  subsidy,
  penalty,
  baseRewardReserve,
  maxSweepableSubsidy,
  isPaused,
  isConnected,
}: AdminContainerProps) {
  const {
    mutation,
    pause,
    unpause,
    setTreasury,
    sweepSubsidy,
    sweepExpiredBaseReward,
    recoverToken,
    grantOperatorRole,
  } = useAdminMutation({ poolAddress, operatorRole })

  const disabled = !isConnected || mutation.isPending

  return (
    <>
      <TransactionStatusAlert status={mutation.status} />
      <AdminPanelCard
        isPaused={isPaused}
        disabled={disabled}
        subsidy={subsidy}
        penalty={penalty}
        baseRewardReserve={baseRewardReserve}
        maxSweepableSubsidy={maxSweepableSubsidy}
        rewardTokenSymbol={rewardToken.symbol}
        rewardTokenDecimals={rewardToken.decimals}
        onPause={pause}
        onUnpause={unpause}
        onSetTreasury={setTreasury}
        onSweepSubsidy={sweepSubsidy}
        onSweepExpiredBaseReward={sweepExpiredBaseReward}
        onRecoverToken={recoverToken}
        onGrantOperatorRole={grantOperatorRole}
      />
    </>
  )
}