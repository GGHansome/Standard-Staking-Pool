import { App } from 'antd'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import { isAddress, type Address } from 'viem'
import { stakingPoolAbi } from '../../../contracts/stakingPoolAbi'
import { AdminPanelCard } from '../components/AdminPanelCard'
import { TransactionStatusAlert } from '../components/TransactionStatusAlert'
import { getErrorMessage } from '../utils/contract'
import { parsePositiveBigInt } from '../utils/format'

type AdminContainerProps = {
  poolAddress: Address
  isPoolPaused: boolean
}

export function AdminContainer({ poolAddress, isPoolPaused }: AdminContainerProps) {
  const { message } = App.useApp()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })
  const disabled = write.isPending || receipt.isLoading

  const pause = async () => {
    try {
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'pause',
      })
      message.success('暂停合约已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  const unpause = async () => {
    try {
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'unpause',
      })
      message.success('解除暂停已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  const setRewardsDuration = async (seconds: string) => {
    try {
      const duration = parsePositiveBigInt(seconds)
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'setRewardsDuration',
        args: [duration],
      })
      message.success('设置奖励周期已提交，等待链上确认')
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  const recoverToken = async (tokenAddress: string, rawAmount: string) => {
    try {
      if (!isAddress(tokenAddress)) {
        throw new Error('请输入有效的 ERC20 地址')
      }

      const amount = parsePositiveBigInt(rawAmount)
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'recoverERC20',
        args: [tokenAddress, amount],
      })
      message.success('救援误转代币已提交，等待链上确认')
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
      <AdminPanelCard
        isPaused={isPoolPaused}
        disabled={disabled}
        onPause={pause}
        onUnpause={unpause}
        onSetRewardsDuration={setRewardsDuration}
        onRecoverToken={recoverToken}
      />
    </>
  )
}
