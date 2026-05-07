import type { Address } from 'viem'

export type WalletConnectorOption = {
  id: string
  name: string
}

export type TokenView = {
  address?: Address
  symbol: string
  decimals: number
  balance: bigint
  allowance: bigint
  usdPrice?: number
}

export type PoolView = {
  totalSupply: bigint
  rewardRate: bigint
  rewardsDuration: bigint
  periodFinish: bigint
  paused: boolean
  apr?: number
  rewardPerSecond?: number
}

export type UserView = {
  address?: Address
  isConnected: boolean
  chainId?: number
  stakedBalance: bigint
  earnedRewards: bigint
}

export type RoleView = {
  isAdmin: boolean
  isOperator: boolean
}
