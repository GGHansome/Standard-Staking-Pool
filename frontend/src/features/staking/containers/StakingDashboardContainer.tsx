import { useMemo } from 'react'
import { useQuery } from '@tanstack/react-query'
import { Alert, Col, Row } from 'antd'
import { useConnection, useReadContract, useReadContracts } from 'wagmi'
import { zeroAddress, zeroHash, type Address } from 'viem'
import { appConfig, missingConfigMessages } from '../../../config/contracts'
import { erc20Abi, stakingPoolAbi } from '../../../contracts/stakingPoolAbi'
import { DashboardLayout } from '../components/layout/DashboardLayout'
import { PoolOverviewCard } from '../components/PoolOverviewCard'
import { UserPositionCard } from '../components/UserPositionCard'
import type { PoolView, TokenView, UserView } from '../types'
import { readAt } from '../utils/contract'
import { REWARD_RATE_PRECISION, SECONDS_PER_YEAR } from '../utils/format'
import { AdminContainer } from './AdminContainer'
import { OperatorRewardContainer } from './OperatorRewardContainer'
import { RewardActionsContainer } from './RewardActionsContainer'
import { StakeContainer } from './StakeContainer'
import { WalletContainer } from './WalletContainer'
import { WithdrawContainer } from './WithdrawContainer'

type CoingeckoPrices = Record<string, { usd?: number }>

const fallbackPoolAddress = appConfig.stakingPoolAddress ?? zeroAddress

function readPoolAddress(): Address | undefined {
  return appConfig.stakingPoolAddress
}

function fetchTokenPrices() {
  const stakingId = appConfig.stakingTokenCoingeckoId
  const rewardId = appConfig.rewardTokenCoingeckoId

  return async (): Promise<CoingeckoPrices> => {
    const ids = [stakingId, rewardId].join(',')
    const response = await fetch(
      `https://api.coingecko.com/api/v3/simple/price?ids=${ids}&vs_currencies=usd`,
    )

    if (!response.ok) {
      throw new Error('CoinGecko 价格请求失败')
    }

    return (await response.json()) as CoingeckoPrices
  }
}

export function StakingDashboardContainer() {
  const connection = useConnection()
  const poolAddress = readPoolAddress()
  const hasPoolAddress = Boolean(poolAddress)

  const poolRead = useReadContracts({
    contracts: [
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'stakingToken' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'rewardToken' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'totalSupply' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'rewardRate' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'rewardsDuration' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'periodFinish' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'paused' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'OPERATOR_ROLE' },
      { address: fallbackPoolAddress, abi: stakingPoolAbi, functionName: 'DEFAULT_ADMIN_ROLE' },
    ] as const,
    query: {
      enabled: hasPoolAddress,
      refetchInterval: 12_000,
    },
  })

  const stakingTokenAddress = readAt<Address | undefined>(poolRead.data, 0, undefined)
  const rewardTokenAddress = readAt<Address | undefined>(poolRead.data, 1, undefined)
  const totalSupply = readAt<bigint>(poolRead.data, 2, 0n)
  const rewardRate = readAt<bigint>(poolRead.data, 3, 0n)
  const rewardsDuration = readAt<bigint>(poolRead.data, 4, 0n)
  const periodFinish = readAt<bigint>(poolRead.data, 5, 0n)
  const paused = readAt<boolean>(poolRead.data, 6, false)
  const operatorRole = readAt<`0x${string}`>(poolRead.data, 7, zeroHash)
  const defaultAdminRole = readAt<`0x${string}`>(poolRead.data, 8, zeroHash)

  const tokenRead = useReadContracts({
    contracts: [
      { address: stakingTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'symbol' },
      { address: stakingTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'decimals' },
      {
        address: stakingTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [connection.address ?? zeroAddress],
      },
      {
        address: stakingTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [connection.address ?? zeroAddress, fallbackPoolAddress],
      },
      { address: rewardTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'symbol' },
      { address: rewardTokenAddress ?? zeroAddress, abi: erc20Abi, functionName: 'decimals' },
      {
        address: rewardTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'balanceOf',
        args: [connection.address ?? zeroAddress],
      },
      {
        address: rewardTokenAddress ?? zeroAddress,
        abi: erc20Abi,
        functionName: 'allowance',
        args: [connection.address ?? zeroAddress, fallbackPoolAddress],
      },
    ] as const,
    query: {
      enabled: Boolean(stakingTokenAddress && rewardTokenAddress),
      refetchInterval: 12_000,
    },
  })

  const userStakeRead = useReadContracts({
    contracts: [
      {
        address: fallbackPoolAddress,
        abi: stakingPoolAbi,
        functionName: 'balanceOf',
        args: [connection.address ?? zeroAddress],
      },
      {
        address: fallbackPoolAddress,
        abi: stakingPoolAbi,
        functionName: 'earned',
        args: [connection.address ?? zeroAddress],
      },
    ] as const,
    query: {
      enabled: Boolean(hasPoolAddress && connection.address),
      refetchInterval: 8_000,
    },
  })

  const adminRoleRead = useReadContract({
    address: fallbackPoolAddress,
    abi: stakingPoolAbi,
    functionName: 'hasRole',
    args: [defaultAdminRole, connection.address ?? zeroAddress],
    query: {
      enabled: Boolean(hasPoolAddress && connection.address),
      refetchInterval: 15_000,
    },
  })

  const operatorRoleRead = useReadContract({
    address: fallbackPoolAddress,
    abi: stakingPoolAbi,
    functionName: 'hasRole',
    args: [operatorRole, connection.address ?? zeroAddress],
    query: {
      enabled: Boolean(hasPoolAddress && connection.address),
      refetchInterval: 15_000,
    },
  })

  const priceQuery = useQuery({
    queryKey: [
      'coingecko-prices',
      appConfig.stakingTokenCoingeckoId,
      appConfig.rewardTokenCoingeckoId,
    ],
    enabled: Boolean(appConfig.stakingTokenCoingeckoId && appConfig.rewardTokenCoingeckoId),
    staleTime: 60_000,
    refetchInterval: 60_000,
    queryFn: fetchTokenPrices(),
  })

  const stakingDecimals = readAt<number>(tokenRead.data, 1, 18)
  const rewardDecimals = readAt<number>(tokenRead.data, 5, 18)

  const rewardPerSecond = useMemo(() => {
    const value = Number(rewardRate) / 10 ** (rewardDecimals + REWARD_RATE_PRECISION)
    return Number.isFinite(value) ? value : undefined
  }, [rewardDecimals, rewardRate])

  const apr = useMemo(() => {
    const stakingPrice = priceQuery.data?.[appConfig.stakingTokenCoingeckoId]?.usd
    const rewardPrice = priceQuery.data?.[appConfig.rewardTokenCoingeckoId]?.usd
    const totalSupplyReadable = Number(totalSupply) / 10 ** stakingDecimals

    if (!rewardPerSecond || !stakingPrice || !rewardPrice || totalSupplyReadable <= 0) {
      return undefined
    }

    return ((rewardPerSecond * SECONDS_PER_YEAR * rewardPrice) / (totalSupplyReadable * stakingPrice)) * 100
  }, [priceQuery.data, rewardPerSecond, stakingDecimals, totalSupply])

  const stakingToken: TokenView = {
    address: stakingTokenAddress,
    symbol: readAt<string>(tokenRead.data, 0, 'STK'),
    decimals: stakingDecimals,
    balance: readAt<bigint>(tokenRead.data, 2, 0n),
    allowance: readAt<bigint>(tokenRead.data, 3, 0n),
    usdPrice: priceQuery.data?.[appConfig.stakingTokenCoingeckoId]?.usd,
  }

  const rewardToken: TokenView = {
    address: rewardTokenAddress,
    symbol: readAt<string>(tokenRead.data, 4, 'REWARD'),
    decimals: rewardDecimals,
    balance: readAt<bigint>(tokenRead.data, 6, 0n),
    allowance: readAt<bigint>(tokenRead.data, 7, 0n),
    usdPrice: priceQuery.data?.[appConfig.rewardTokenCoingeckoId]?.usd,
  }

  const pool: PoolView = {
    totalSupply,
    rewardRate,
    rewardsDuration,
    periodFinish,
    paused,
    apr,
    rewardPerSecond,
  }

  const wallet: UserView = {
    address: connection.address,
    isConnected: connection.isConnected,
    chainId: connection.chainId,
    stakedBalance: readAt<bigint>(userStakeRead.data, 0, 0n),
    earnedRewards: readAt<bigint>(userStakeRead.data, 1, 0n),
  }

  return (
    <DashboardLayout isPaused={paused} configWarnings={missingConfigMessages}>
      <WalletContainer />
      {!poolAddress ? (
        <Alert showIcon type="warning" message="配置质押池地址后，合约交互功能才会启用。" />
      ) : (
        <>
          <PoolOverviewCard
            isPaused={pool.paused}
            totalSupply={pool.totalSupply}
            rewardRate={pool.rewardRate}
            rewardsDuration={pool.rewardsDuration}
            periodFinish={pool.periodFinish}
            apr={pool.apr}
            rewardPerSecond={pool.rewardPerSecond}
            stakingTokenAddress={stakingToken.address}
            stakingTokenSymbol={stakingToken.symbol}
            stakingTokenDecimals={stakingToken.decimals}
            stakingTokenUsdPrice={stakingToken.usdPrice}
            rewardTokenAddress={rewardToken.address}
            rewardTokenSymbol={rewardToken.symbol}
            rewardTokenUsdPrice={rewardToken.usdPrice}
          />
          <UserPositionCard
            stakingTokenSymbol={stakingToken.symbol}
            stakingTokenDecimals={stakingToken.decimals}
            stakingWalletBalance={stakingToken.balance}
            stakingAllowance={stakingToken.allowance}
            stakedBalance={wallet.stakedBalance}
            rewardTokenSymbol={rewardToken.symbol}
            rewardTokenDecimals={rewardToken.decimals}
            earnedRewards={wallet.earnedRewards}
          />
          <Row gutter={[16, 16]}>
            <Col xs={24} lg={12}>
              <StakeContainer
                poolAddress={poolAddress}
                stakingToken={stakingToken}
                isConnected={wallet.isConnected}
                isPoolPaused={pool.paused}
              />
            </Col>
            <Col xs={24} lg={12}>
              <WithdrawContainer
                poolAddress={poolAddress}
                stakingToken={stakingToken}
                isConnected={wallet.isConnected}
                stakedBalance={wallet.stakedBalance}
              />
            </Col>
            <Col span={24}>
              <RewardActionsContainer
                poolAddress={poolAddress}
                rewardToken={rewardToken}
                isConnected={wallet.isConnected}
                isPoolPaused={pool.paused}
                stakedBalance={wallet.stakedBalance}
                earnedRewards={wallet.earnedRewards}
              />
            </Col>
          </Row>
          {operatorRoleRead.data ? (
            <OperatorRewardContainer
              poolAddress={poolAddress}
              rewardToken={rewardToken}
              isPoolPaused={pool.paused}
            />
          ) : null}
          {adminRoleRead.data ? (
            <AdminContainer poolAddress={poolAddress} isPoolPaused={pool.paused} />
          ) : null}
        </>
      )}
    </DashboardLayout>
  )
}
