import { useMemo, useState } from 'react'
import { useQuery } from '@tanstack/react-query'
import { useConnection, useReadContract, useReadContracts, useWatchBlocks } from 'wagmi'
import { zeroAddress, zeroHash, type Address } from 'viem'
import { appConfig } from '../../../../../config/contracts'
import { erc20Abi } from '../../../../../contracts/erc20Abi'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import type {
  LockTier,
  PenaltyView,
  PoolView,
  RewardScheduleView,
  RoleQueryStatus,
  RoleView,
  SubsidyView,
  TokenView,
  UserView,
} from '../../../types'
import { readAt } from '../../../utils/contract'
import { REWARD_RATE_PRECISION, SECONDS_PER_YEAR } from '../../../utils/format'

type CoingeckoPrices = Record<string, { usd?: number }>

const fallbackPoolAddress = appConfig.stakingPoolAddress ?? zeroAddress

function fetchTokenPrices(ids: string[]) {
  return async (): Promise<CoingeckoPrices> => {
    const response = await fetch(
      `https://api.coingecko.com/api/v3/simple/price?ids=${ids.join(',')}&vs_currencies=usd`,
    )

    if (!response.ok) {
      throw new Error('CoinGecko 价格请求失败')
    }

    return (await response.json()) as CoingeckoPrices
  }
}

function resolveTokenUsdPrice(
  localPrice: number | undefined,
  coingeckoId: string,
  prices?: CoingeckoPrices,
) {
  return localPrice ?? prices?.[coingeckoId]?.usd
}

export type DashboardData = {
  poolAddress?: Address
  hasPoolAddress: boolean
  chainTimestamp?: bigint
  stakingToken: TokenView
  rewardToken: TokenView
  pool: PoolView
  user: UserView
  role: RoleView
}

/**
 * 顶层共享 selector：读取池级概览、双币元数据/余额/授权、用户角色，
 * 转换为各子容器透传所需的展示模型。子容器读取细分数据（仓位、推荐等）由其各自 selector 负责。
 */
export function useDashboardData(): DashboardData {
  const connection = useConnection()
  const account = connection.address ?? zeroAddress
  const poolAddress = appConfig.stakingPoolAddress
  const hasPoolAddress = Boolean(poolAddress)
  const [chainTimestamp, setChainTimestamp] = useState<bigint>()

  useWatchBlocks({
    enabled: hasPoolAddress,
    emitOnBegin: true,
    onBlock: (block) => setChainTimestamp(block.timestamp),
  })

  const poolRead = useReadContracts({
    contracts: [
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'stakingToken' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'rewardToken' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'totalSupply' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'paused' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'isRewardPeriodActive' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'getRewardSchedule' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'getSubsidyConfig' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'getPenaltyConfig' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'baseRewardReserve' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'remainingBaseReward' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'maxSweepableSubsidy' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'OPERATOR_ROLE' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'DEFAULT_ADMIN_ROLE' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'getLockTiers' },
      { address: fallbackPoolAddress, abi: stakingPoolV2Abi, functionName: 'injectedBaseCumulative' },
    ] as const,
    query: { enabled: hasPoolAddress, refetchInterval: 12_000 },
  })

  const stakingTokenAddress = readAt<Address | undefined>(poolRead.data, 0, undefined)
  const rewardTokenAddress = readAt<Address | undefined>(poolRead.data, 1, undefined)
  const totalSupply = readAt<bigint>(poolRead.data, 2, 0n)
  const paused = readAt<boolean>(poolRead.data, 3, false)
  const isRewardPeriodActive = readAt<boolean>(poolRead.data, 4, false)

  const emptySchedule: RewardScheduleView = {
    rewardsDuration: 0n,
    periodFinish: 0n,
    rewardRate: 0n,
    lastUpdateTime: 0n,
    rewardPerTokenStored: 0n,
  }
  const schedule = readAt<RewardScheduleView>(poolRead.data, 5, emptySchedule)

  const emptySubsidy: SubsidyView = {
    maxSubsidyRate: 0n,
    maxSubsidyRateCap: 0n,
    subsidyReserve: 0n,
    totalPendingSubsidy: 0n,
    unsettledMaxSubsidyLiability: 0n,
  }
  const subsidy = readAt<SubsidyView>(poolRead.data, 6, emptySubsidy)

  const penaltyTuple = readAt<readonly [bigint, Address]>(poolRead.data, 7, [0n, zeroAddress])
  const penalty: PenaltyView = {
    penaltyRate: penaltyTuple[0],
    treasury: penaltyTuple[1],
  }

  const baseRewardReserve = readAt<bigint>(poolRead.data, 8, 0n)
  const remainingBaseReward = readAt<bigint>(poolRead.data, 9, 0n)
  const maxSweepableSubsidy = readAt<bigint>(poolRead.data, 10, 0n)
  const operatorRoleResult = poolRead.data?.[11]
  const defaultAdminRoleResult = poolRead.data?.[12]
  const roleIdsReady =
    operatorRoleResult?.status === 'success' && defaultAdminRoleResult?.status === 'success'
  const roleIdsFailed =
    poolRead.isError ||
    operatorRoleResult?.status === 'failure' ||
    defaultAdminRoleResult?.status === 'failure'
  const operatorRole = readAt<`0x${string}`>(poolRead.data, 11, zeroHash)
  const defaultAdminRole = readAt<`0x${string}`>(poolRead.data, 12, zeroHash)

  const lockTiersTuple = readAt<readonly [readonly bigint[], readonly bigint[]]>(
    poolRead.data,
    13,
    [[], []],
  )
  const [lockDurations, lockBoosts] = lockTiersTuple
  const lockTiers: LockTier[] = lockDurations.map((duration, index) => ({
    duration,
    boostRate: lockBoosts[index] ?? 0n,
  }))
  const injectedBaseCumulative = readAt<bigint>(poolRead.data, 14, 0n)

  const tokenRead = useReadContracts({
    contracts: [
      { address: stakingTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'symbol' },
      { address: stakingTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'decimals' },
      {
        address: stakingTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [account],
      },
      {
        address: stakingTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [account, fallbackPoolAddress],
      },
      { address: rewardTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'symbol' },
      { address: rewardTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'decimals' },
      {
        address: rewardTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [account],
      },
      {
        address: rewardTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [account, fallbackPoolAddress],
      },
    ] as const,
    query: {
      enabled: Boolean(stakingTokenAddress && rewardTokenAddress),
      refetchInterval: 12_000,
    },
  })

  const userRead = useReadContracts({
    contracts: [
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'totalStakedOf',
        args: [account],
      },
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
      {
        address: fallbackPoolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'getActiveDepositIds',
        args: [account],
      },
    ] as const,
    query: {
      enabled: Boolean(hasPoolAddress && connection.address),
      refetchInterval: 8_000,
    },
  })

  const adminRoleRead = useReadContract({
    address: fallbackPoolAddress,
    abi: stakingPoolV2Abi,
    functionName: 'hasRole',
    args: [defaultAdminRole, account],
    query: {
      enabled: Boolean(hasPoolAddress && connection.address && roleIdsReady),
      refetchInterval: 15_000,
    },
  })

  const operatorRoleRead = useReadContract({
    address: fallbackPoolAddress,
    abi: stakingPoolV2Abi,
    functionName: 'hasRole',
    args: [operatorRole, account],
    query: {
      enabled: Boolean(hasPoolAddress && connection.address && roleIdsReady),
      refetchInterval: 15_000,
    },
  })

  const coingeckoPriceIds = [
    appConfig.stakingTokenUsdPrice === undefined ? appConfig.stakingTokenCoingeckoId : '',
    appConfig.rewardTokenUsdPrice === undefined ? appConfig.rewardTokenCoingeckoId : '',
  ].filter(Boolean)

  const priceQuery = useQuery({
    queryKey: ['coingecko-prices', coingeckoPriceIds],
    enabled: coingeckoPriceIds.length > 0,
    staleTime: 60_000,
    refetchInterval: 60_000,
    queryFn: fetchTokenPrices(coingeckoPriceIds),
  })

  const stakingDecimals = readAt<number>(tokenRead.data, 1, 18)
  const rewardDecimals = readAt<number>(tokenRead.data, 5, 18)
  const stakingUsdPrice = resolveTokenUsdPrice(
    appConfig.stakingTokenUsdPrice,
    appConfig.stakingTokenCoingeckoId,
    priceQuery.data,
  )
  const rewardUsdPrice = resolveTokenUsdPrice(
    appConfig.rewardTokenUsdPrice,
    appConfig.rewardTokenCoingeckoId,
    priceQuery.data,
  )

  const rewardPerSecond = useMemo(() => {
    const value = Number(schedule.rewardRate) / 10 ** (rewardDecimals + REWARD_RATE_PRECISION)
    return Number.isFinite(value) ? value : undefined
  }, [rewardDecimals, schedule.rewardRate])

  const apr = useMemo(() => {
    const totalSupplyReadable = Number(totalSupply) / 10 ** stakingDecimals

    if (!rewardPerSecond || !stakingUsdPrice || !rewardUsdPrice || totalSupplyReadable <= 0) {
      return undefined
    }

    return (
      ((rewardPerSecond * SECONDS_PER_YEAR * rewardUsdPrice) /
        (totalSupplyReadable * stakingUsdPrice)) *
      100
    )
  }, [rewardPerSecond, rewardUsdPrice, stakingDecimals, stakingUsdPrice, totalSupply])

  const stakingToken: TokenView = {
    address: stakingTokenAddress,
    symbol: readAt<string>(tokenRead.data, 0, 'STK'),
    decimals: stakingDecimals,
    balance: readAt<bigint>(tokenRead.data, 2, 0n),
    allowance: readAt<bigint>(tokenRead.data, 3, 0n),
    usdPrice: stakingUsdPrice,
  }

  const rewardToken: TokenView = {
    address: rewardTokenAddress,
    symbol: readAt<string>(tokenRead.data, 4, 'RWD'),
    decimals: rewardDecimals,
    balance: readAt<bigint>(tokenRead.data, 6, 0n),
    allowance: readAt<bigint>(tokenRead.data, 7, 0n),
    usdPrice: rewardUsdPrice,
  }

  const pool: PoolView = {
    totalSupply,
    paused,
    isRewardPeriodActive,
    schedule,
    subsidy,
    penalty,
    lockTiers,
    baseRewardReserve,
    remainingBaseReward,
    maxSweepableSubsidy,
    injectedBaseCumulative,
    apr,
    rewardPerSecond,
  }

  const activeDepositIds = readAt<readonly bigint[]>(userRead.data, 3, [])

  const user: UserView = {
    address: connection.address,
    isConnected: connection.isConnected,
    chainId: connection.chainId,
    totalStaked: readAt<bigint>(userRead.data, 0, 0n),
    earnedRewards: readAt<bigint>(userRead.data, 1, 0n),
    claimableReferral: readAt<bigint>(userRead.data, 2, 0n),
    activeDepositCount: activeDepositIds.length,
  }

  const roleStatus: RoleQueryStatus = !connection.address
    ? 'idle'
    : roleIdsFailed || adminRoleRead.isError || operatorRoleRead.isError
      ? 'error'
      : roleIdsReady && adminRoleRead.isSuccess && operatorRoleRead.isSuccess
        ? 'ready'
        : 'loading'

  const role: RoleView = {
    status: roleStatus,
    isAdmin: roleStatus === 'ready' && Boolean(adminRoleRead.data),
    isOperator: roleStatus === 'ready' && Boolean(operatorRoleRead.data),
    operatorRole,
    defaultAdminRole,
  }

  return {
    poolAddress,
    hasPoolAddress,
    chainTimestamp,
    stakingToken,
    rewardToken,
    pool,
    user,
    role,
  }
}