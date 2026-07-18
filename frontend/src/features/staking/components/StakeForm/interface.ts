import type { LockTier } from '../../types'

export type StakeFormValues = {
  amount: string
  lockDuration?: string
  inviter?: string
}

export type StakePayload = {
  amount: string
  lockDuration: string
  inviter: string
}

export type StakeFormProps = {
  tokenSymbol: string
  lockTiers: LockTier[]
  isRewardPeriodActive: boolean
  hasSetInviter: boolean
  boundInviter?: string
  disabled?: boolean
  approveDisabled?: boolean
  stakeDisabled?: boolean
  onApprove: (amount: string) => Promise<void>
  onStake: (payload: StakePayload) => Promise<void>
}