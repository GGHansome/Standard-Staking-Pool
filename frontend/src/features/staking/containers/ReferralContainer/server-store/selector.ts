import { useConnection, useReadContracts } from 'wagmi'
import { zeroAddress, type Address } from 'viem'
import { appConfig } from '../../../../../config/contracts'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import type { ReferralRates, ReferralView } from '../../../types'
import { readAt } from '../../../utils/contract'

const fallbackPoolAddress = appConfig.stakingPoolAddress ?? zeroAddress

const emptyRates: ReferralRates = {
  inviteeBoost: 0n,
  level1: 0n,
  level2: 0n,
  level3: 0n,
}

/**
 * 推荐 selector：组装三级上线地址、绑定态、全局返佣比例、当前可领返佣，
 * 合并为 ReferralView 供推荐卡片展示。返佣比例为全局配置（与用户无关），
 * 上线/绑定/可领则按当前账户读取。
 */
export function useReferralSelector(): ReferralView {
  const connection = useConnection()
  const account = connection.address ?? zeroAddress
  const enabled = Boolean(appConfig.stakingPoolAddress && connection.address)

  const read = useReadContracts({
    contracts: [
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'getUpline',
        args: [account],
      },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'getReferralRates' },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'inviterOf',
        args: [account],
      },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'hasSetInviter',
        args: [account],
      },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'claimableReferralReward',
        args: [account],
      },
    ] as const,
    query: { enabled, refetchInterval: 12_000 },
  })

  const uplineTuple = readAt<readonly [Address, Address, Address]>(read.data, 0, [
    zeroAddress,
    zeroAddress,
    zeroAddress,
  ])

  const ratesTuple = readAt<readonly [bigint, bigint, bigint, bigint]>(read.data, 1, [
    0n,
    0n,
    0n,
    0n,
  ])
  const rates: ReferralRates = ratesTuple
    ? {
        inviteeBoost: ratesTuple[0],
        level1: ratesTuple[1],
        level2: ratesTuple[2],
        level3: ratesTuple[3],
      }
    : emptyRates

  return {
    inviter: readAt<Address>(read.data, 2, zeroAddress),
    hasSetInviter: readAt<boolean>(read.data, 3, false),
    upline: [uplineTuple[0], uplineTuple[1], uplineTuple[2]],
    rates,
    claimable: readAt<bigint>(read.data, 4, 0n),
  }
}