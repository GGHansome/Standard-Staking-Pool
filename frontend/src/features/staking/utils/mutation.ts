import { useEffect } from 'react'
import { App } from 'antd'
import { useQueryClient } from '@tanstack/react-query'
import { useWaitForTransactionReceipt, useWriteContract } from 'wagmi'
import type { TransactionStatus } from '../types'

type MutateAsync = ReturnType<typeof useWriteContract>['mutateAsync']
type WriteParams = Parameters<MutateAsync>[0]

type RunOptions = {
  submittedMessage?: string
}

/**
 * server-store 写操作的统一底座：收敛 useWriteContract + useWaitForTransactionReceipt
 * + antd message 三件套，向各容器的 mutation.ts 暴露一致的运行契约。
 */
export function useContractMutation() {
  const { message } = App.useApp()
  const queryClient = useQueryClient()
  const write = useWriteContract()
  const receipt = useWaitForTransactionReceipt({ hash: write.data })

  const status: TransactionStatus = (() => {
    if (write.isError) {
      return { phase: 'failed' }
    }

    if (!write.data) {
      return { phase: 'idle' }
    }

    if (receipt.data?.status === 'reverted' || receipt.isError) {
      return { phase: 'failed', hash: write.data }
    }

    if (receipt.isSuccess && receipt.data.status === 'success') {
      return { phase: 'confirmed', hash: write.data }
    }

    return { phase: 'confirming', hash: write.data }
  })()

  const isPending = write.isPending || status.phase === 'confirming'
  const confirmedHash = status.phase === 'confirmed' ? status.hash : undefined

  useEffect(() => {
    if (!confirmedHash) {
      return
    }

    void queryClient.invalidateQueries({
      predicate: ({ queryKey }) =>
        typeof queryKey[0] === 'string' && queryKey[0].startsWith('readContract'),
    })
  }, [confirmedHash, queryClient])

  const run = async (
    params: WriteParams,
    options?: RunOptions,
  ): Promise<`0x${string}` | undefined> => {
    try {
      const hash = await write.mutateAsync(params)
      if (options?.submittedMessage) {
        message.success(options.submittedMessage)
      }
      return hash
    } catch {
      return undefined
    }
  }

  return {
    run,
    isPending,
    status,
  }
}

export type ContractMutation = ReturnType<typeof useContractMutation>