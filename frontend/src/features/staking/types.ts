import type { Address, Hash } from 'viem'

export type TransactionStatus =
  | { phase: 'idle' }
  | { phase: 'confirming'; hash: Hash }
  | { phase: 'confirmed'; hash: Hash }
  | { phase: 'failed'; hash?: Hash }

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

export type RewardScheduleView = {
  rewardsDuration: bigint
  periodFinish: bigint
  rewardRate: bigint
  lastUpdateTime: bigint
  rewardPerTokenStored: bigint
}

export type SubsidyView = {
  maxSubsidyRate: bigint
  maxSubsidyRateCap: bigint
  subsidyReserve: bigint
  totalPendingSubsidy: bigint
  unsettledMaxSubsidyLiability: bigint
}

export type PenaltyView = {
  penaltyRate: bigint
  treasury: Address
}

export type PoolView = {
  totalSupply: bigint
  paused: boolean
  isRewardPeriodActive: boolean
  schedule: RewardScheduleView
  subsidy: SubsidyView
  penalty: PenaltyView
  lockTiers: LockTier[]
  baseRewardReserve: bigint
  remainingBaseReward: bigint
  maxSweepableSubsidy: bigint
  injectedBaseCumulative: bigint
  apr?: number
  rewardPerSecond?: number
}

export type LockTier = {
  duration: bigint
  boostRate: bigint
}

export type DepositItem = {
  depositId: bigint
  owner: Address
  amount: bigint
  unlockTime: bigint
  boostRate: bigint
  boostSettled: boolean
  baseReward: bigint
  inviteeBoostReward: bigint
  pendingBoostReward: bigint
  claimableBoostReward: bigint
  totalClaimable: bigint
  boostClaimable: boolean
  boostForfeitable: boolean
}

export type ReferralRates = {
  inviteeBoost: bigint
  level1: bigint
  level2: bigint
  level3: bigint
}

export type ReferralView = {
  inviter: Address
  hasSetInviter: boolean
  upline: [Address, Address, Address]
  rates: ReferralRates
  claimable: bigint
}

export type UserView = {
  address?: Address
  isConnected: boolean
  chainId?: number
  totalStaked: bigint
  earnedRewards: bigint
  claimableReferral: bigint
  activeDepositCount: number
}

export type RoleQueryStatus = 'idle' | 'loading' | 'ready' | 'error'

export type RoleView = {
  status: RoleQueryStatus
  isAdmin: boolean
  isOperator: boolean
  operatorRole: `0x${string}`
  defaultAdminRole: `0x${string}`
}