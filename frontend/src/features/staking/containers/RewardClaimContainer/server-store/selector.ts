import { useConnection, useReadContracts } from 'wagmi'
import { zeroAddress } from 'viem'
import { appConfig } from '../../../../../config/contracts'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import { readAt } from '../../../utils/contract'

const fallbackPoolAddress = appConfig.stakingPoolAddress ?? zeroAddress

export type RewardClaimData = {
  earnedRewards: bigint
  claimableReferral: bigint
}

/**
 * 领取 selector：可领取总额 = earned(user)（基础+锁仓加成+受邀加成）
 * 与 claimableReferralReward(user)（三级返佣）两路来源合并展示。
 */
export function useRewardClaimSelector(): RewardClaimData {
  const connection = useConnection()
  const account = connection.address ?? zeroAddress
  const enabled = Boolean(appConfig.stakingPoolAddress && connection.address)

  const read = useReadContracts({
    contracts: [
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'earned',
        args: [account],
      },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'claimableReferralReward',
        args: [account],
      },
    ] as const,
    query: { enabled, refetchInterval: 8_000 },
  })

  return {
    earnedRewards: readAt<bigint>(read.data, 0, 0n),
    claimableReferral: readAt<bigint>(read.data, 1, 0n),
  }
}