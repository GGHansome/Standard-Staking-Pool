import { App } from 'antd'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { Address } from 'viem'
import { stakingPoolAbi } from '../../../contracts/stakingPoolAbi'
import { RewardActionsCard } from '../components/RewardActionsCard'
import { TransactionStatusAlert } from '../components/TransactionStatusAlert'
import type { TokenView } from '../types'
import { getErrorMessage } from '../utils/contract'

type RewardActionsContainerProps = {
  poolAddress: Address
  rewardToken: TokenView
  isConnected: boolean
  isPoolPaused: boolean
  stakedBalance: bigint
  earnedRewards: bigint
}

export function RewardActionsContainer({
  poolAddress,
  rewardToken,
  isConnected,
  isPoolPaused,
  stakedBalance,
  earnedRewards,
}: RewardActionsContainerProps) {
  const { message } = App.useApp()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })
  const disabled = !isConnected || write.isPending || receipt.isLoading

  const claimReward = async () => {
    try {
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'getReward',
      })
      message.success('领取收益已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  const exit = async () => {
    try {
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'exit',
      })
      message.success('一键退出已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  return (
    <>
      <TransactionStatusAlert
        hash={write.data}
        error={write.error ? getErrorMessage(write.error) : undefined}
        isConfirming={receipt.isLoading}
        isConfirmed={receipt.isSuccess}
      />
      <RewardActionsCard
        rewardTokenSymbol={rewardToken.symbol}
        isPaused={isPoolPaused}
        disabled={disabled}
        claimDisabled={earnedRewards === 0n}
        exitDisabled={stakedBalance === 0n && earnedRewards === 0n}
        onClaim={claimReward}
        onExit={exit}
      />
    </>
  )
}
