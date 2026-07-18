import { DepositTable } from '../../components/DepositTable'
import { TransactionStatusAlert } from '../../components/TransactionStatusAlert'
import { useDepositListSelector } from './server-store/selector'
import { useDepositMutation } from './server-store/mutation'
import type { DepositListContainerProps } from './interface'

export function DepositListContainer({
  poolAddress,
  chainTimestamp,
  stakingToken,
  rewardToken,
  penaltyRate,
  isConnected,
}: DepositListContainerProps) {
  const { deposits, isLoading } = useDepositListSelector()
  const { mutation, withdraw, withdrawMultiple, exit } = useDepositMutation({ poolAddress })

  const disabled = !isConnected || mutation.isPending

  return (
    <>
      <TransactionStatusAlert status={mutation.status} />
      <DepositTable
        deposits={deposits}
        chainTimestamp={chainTimestamp}
        loading={isLoading}
        disabled={disabled}
        penaltyRate={penaltyRate}
        rewardTokenSymbol={rewardToken.symbol}
        rewardTokenDecimals={rewardToken.decimals}
        stakingTokenSymbol={stakingToken.symbol}
        stakingTokenDecimals={stakingToken.decimals}
        onWithdraw={withdraw}
        onWithdrawMultiple={withdrawMultiple}
        onExit={exit}
      />
    </>
  )
}