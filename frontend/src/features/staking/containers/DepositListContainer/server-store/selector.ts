import { useConnection, useReadContract, useReadContracts } from 'wagmi'
import { zeroAddress, type Address } from 'viem'
import { appConfig } from '../../../../../config/contracts'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import type { DepositItem } from '../../../types'
import { readAt } from '../../../utils/contract'

const fallbackPoolAddress = appConfig.stakingPoolAddress ?? zeroAddress

type DepositViewTuple = {
  owner: Address
  amount: bigint
  unlockTime: bigint
  boostRate: bigint
  rewardPerTokenPaid: bigint
  rewardPerTokenAtUnlock: bigint
  boostSettled: boolean
  pendingBaseReward: bigint
  pendingInviteeBoostReward: bigint
  pendingBoostReward: bigint
}

type DepositRewardTuple = {
  baseReward: bigint
  inviteeBoostReward: bigint
  pendingBoostReward: bigint
  claimableBoostReward: bigint
  totalClaimable: bigint
  boostClaimable: boolean
  boostForfeitable: boolean
}

export type DepositListData = {
  deposits: DepositItem[]
  isLoading: boolean
}

/**
 * 仓位列表 selector：
 *  1) getActiveDepositIds(user) 取活跃仓位编号（getUserDeposits 不带 id，无法回关联）；
 *  2) 对每个 id 并行读取 getDeposit + earnedByDeposit；
 *  3) 合并为带 depositId 的 DepositItem[]。
 */
export function useDepositListSelector(): DepositListData {
  const connection = useConnection()
  const account = connection.address ?? zeroAddress
  const enabled = Boolean(appConfig.stakingPoolAddress && connection.address)

  const idsRead = useReadContract({
    address: fallbackPoolAddress,
    abi: stakingPoolV2Abi,
    functionName: 'getActiveDepositIds',
    args: [account],
    query: { enabled, refetchInterval: 8_000 },
  })

  const depositIds = (idsRead.data ?? []) as readonly bigint[]

  const detailContracts = depositIds.flatMap((depositId) => [
    {
      address: fallbackPoolAddress,
      abi: stakingPoolV2Abi,
      functionName: 'getDeposit',
      args: [depositId],
    },
    {
      address: fallbackPoolAddress,
      abi: stakingPoolV2Abi,
      functionName: 'earnedByDeposit',
      args: [depositId],
    },
  ]) as unknown[]

  const detailRead = useReadContracts({
    contracts: detailContracts as never,
    query: { enabled: enabled && depositIds.length > 0, refetchInterval: 8_000 },
  })

  // 动态生成的 contracts 会让 wagmi 的 data 推导出超深联合类型（TS2589），
  // 这里按运行时已知形状收敛为通用结果数组，交由 readAt 做逐项安全取值。
  const detailData = detailRead.data as readonly unknown[] | undefined

  const deposits: DepositItem[] = depositIds.map((depositId, index) => {
    const view = readAt<DepositViewTuple | undefined>(detailData, index * 2, undefined)
    const reward = readAt<DepositRewardTuple | undefined>(detailData, index * 2 + 1, undefined)

    return {
      depositId,
      owner: view?.owner ?? zeroAddress,
      amount: view?.amount ?? 0n,
      unlockTime: view?.unlockTime ?? 0n,
      boostRate: view?.boostRate ?? 0n,
      boostSettled: view?.boostSettled ?? false,
      baseReward: reward?.baseReward ?? 0n,
      inviteeBoostReward: reward?.inviteeBoostReward ?? 0n,
      pendingBoostReward: reward?.pendingBoostReward ?? 0n,
      claimableBoostReward: reward?.claimableBoostReward ?? 0n,
      totalClaimable: reward?.totalClaimable ?? 0n,
      boostClaimable: reward?.boostClaimable ?? false,
      boostForfeitable: reward?.boostForfeitable ?? false,
    }
  })

  return {
    deposits,
    isLoading: idsRead.isLoading || detailRead.isLoading,
  }
}