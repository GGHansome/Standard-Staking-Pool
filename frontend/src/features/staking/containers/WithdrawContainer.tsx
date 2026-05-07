import { App } from 'antd'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { Address } from 'viem'
import { stakingPoolAbi } from '../../../contracts/stakingPoolAbi'
import { AmountActionCard } from '../components/common/AmountActionCard'
import { TransactionStatusAlert } from '../components/TransactionStatusAlert'
import type { TokenView } from '../types'
import { getErrorMessage } from '../utils/contract'
import { parseTokenAmount } from '../utils/format'

type WithdrawContainerProps = {
  poolAddress: Address
  stakingToken: TokenView
  isConnected: boolean
  stakedBalance: bigint
}

export function WithdrawContainer({
  poolAddress,
  stakingToken,
  isConnected,
  stakedBalance,
}: WithdrawContainerProps) {
  const { message } = App.useApp()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })
  const disabled = !isConnected || write.isPending || receipt.isLoading

  const withdraw = async (amount: string) => {
    try {
      const parsed = parseTokenAmount(amount, stakingToken.decimals)
      await write.mutateAsync({
        address: poolAddress,
        abi: stakingPoolAbi,
        functionName: 'withdraw',
        args: [parsed],
      })
      message.success('提取本金已提交，等待链上确认')
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
        title="提取本金"
        tokenSymbol={stakingToken.symbol}
        primaryLabel="提取"
        disabled={disabled}
        primaryDisabled={stakedBalance === 0n}
        onPrimary={withdraw}
      />
    </>
  )
}
