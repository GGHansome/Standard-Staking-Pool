import { App } from 'antd'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { Address } from 'viem'
import { erc20Abi, stakingPoolAbi } from '../../../contracts/stakingPoolAbi'
import { AmountActionCard } from '../components/common/AmountActionCard'
import { TransactionStatusAlert } from '../components/TransactionStatusAlert'
import type { TokenView } from '../types'
import { getErrorMessage } from '../utils/contract'
import { parseTokenAmount } from '../utils/format'

type StakeContainerProps = {
  poolAddress: Address
  stakingToken: TokenView
  isConnected: boolean
  isPoolPaused: boolean
}

export function StakeContainer({
  poolAddress,
  stakingToken,
  isConnected,
  isPoolPaused,
}: StakeContainerProps) {
  const { message } = App.useApp()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })
  const disabled = !isConnected || write.isPending || receipt.isLoading

  const approveStake = async (amount: string) => {
    if (!stakingToken.address) {
      message.error('质押代币地址尚未读取成功')
      return
    }

    try {
      const parsed = parseTokenAmount(amount, stakingToken.decimals)
      await write.mutateAsync({
        address: stakingToken.address,
        abi: erc20Abi,
        functionName: 'approve',
        args: [poolAddress, parsed],
      })
      message.success('授权质押代币已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  const stake = async (amount: string) => {
    try {
      const parsed = parseTokenAmount(amount, stakingToken.decimals)
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'stake',
        args: [parsed],
      })
      message.success('质押已提交，等待链上确认')
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
        title="质押"
        tokenSymbol={stakingToken.symbol}
        secondaryLabel="先授权"
        primaryLabel="质押入池"
        disabled={disabled}
        primaryDisabled={isPoolPaused}
        onSecondary={approveStake}
        onPrimary={stake}
      />
    </>
  )
}
