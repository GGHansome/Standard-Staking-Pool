import { useConnection, useReadContracts } from 'wagmi'
import { zeroAddress, type Address } from 'viem'
import { appConfig } from '../../../../../config/contracts'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import type { LockTier } from '../../../types'
import { readAt } from '../../../utils/contract'

const fallbackPoolAddress = appConfig.stakingPoolAddress ?? zeroAddress

export type StakeSelectorData = {
  lockTiers: LockTier[]
  hasSetInviter: boolean
  boundInviter: Address
}

/**
 * 质押表单 selector：读取锁仓档位与当前用户的邀请绑定态，
 * 把 getLockTiers 的并行数组转换为 { duration, boostRate } 档位列表供下拉选择。
 */
export function useStakeSelector(): StakeSelectorData {
  const connection = useConnection()
  const account = connection.address ?? zeroAddress

  const read = useReadContracts({
    contracts: [
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'getLockTiers' },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'hasSetInviter',
        args: [account],
      },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'inviterOf',
        args: [account],
      },
    ] as const,
    query: {
      enabled: Boolean(appConfig.stakingPoolAddress),
      refetchInterval: 15_000,
    },
  })

  const tiersTuple = readAt<readonly [readonly bigint[], readonly bigint[]]>(read.data, 0, [[], []])
  const [durations, boosts] = tiersTuple
  const lockTiers: LockTier[] = durations.map((duration, index) => ({
    duration,
    boostRate: boosts[index] ?? 0n,
  }))

  return {
    lockTiers,
    hasSetInviter: readAt<boolean>(read.data, 1, false),
    boundInviter: readAt<Address>(read.data, 2, zeroAddress),
  }
}