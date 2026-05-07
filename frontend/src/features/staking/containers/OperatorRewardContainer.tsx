import { App } from 'antd'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { Address } from 'viem'
import { erc20Abi, stakingPoolAbi } from '../../../contracts/stakingPoolAbi'
import { AmountActionCard } from '../components/common/AmountActionCard'
import { TransactionStatusAlert } from '../components/TransactionStatusAlert'
import type { TokenView } from '../types'
import { getErrorMessage } from '../utils/contract'
import { parseTokenAmount } from '../utils/format'

type OperatorRewardContainerProps = {
  poolAddress: Address
  rewardToken: TokenView
  isPoolPaused: boolean
}

export function OperatorRewardContainer({
  poolAddress,
  rewardToken,
  isPoolPaused,
}: OperatorRewardContainerProps) {
  const { message } = App.useApp()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })
  const disabled = write.isPending || receipt.isLoading

  const approveReward = async (amount: string) => {
    if (!rewardToken.address) {
      message.error('奖励代币地址尚未读取成功')
      return
    }

    try {
      const parsed = parseTokenAmount(amount, rewardToken.decimals)
      await write.mutateAsync({
        address: rewardToken.address,
        abi: erc20Abi,
        functionName: 'approve',
        args: [poolAddress, parsed],
      })
      message.success('授权奖励代币已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  const notifyReward = async (amount: string) => {
    try {
      const parsed = parseTokenAmount(amount, rewardToken.decimals)
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'notifyRewardAmount',
        args: [parsed],
      })
      message.success('注入奖励已提交，等待链上确认')
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
      <AmountActionCard
        title="Operator 奖励注入"
        tokenSymbol={rewardToken.symbol}
        secondaryLabel="授权奖励代币"
        primaryLabel="注入奖励"
        disabled={disabled}
        primaryDisabled={isPoolPaused}
        onSecondary={approveReward}
        onPrimary={notifyReward}
      />
    </>
  )
}
