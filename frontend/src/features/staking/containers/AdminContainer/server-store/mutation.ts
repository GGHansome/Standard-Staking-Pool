import { App } from 'antd'
import { isAddress, type Address } from 'viem'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import { useContractMutation } from '../../../utils/mutation'

type UseAdminMutationArgs = {
  poolAddress: Address
  operatorRole: `0x${string}`
}

function toBigint(raw: string): bigint | undefined {
  try {
    return BigInt(raw)
  } catch {
    return undefined
  }
}

/**
 * 管理 mutation：暂停/恢复、设置国库、清扫补贴/过期基础奖励、回收误转代币、授予运营角色。
 * V2 移除了 setRewardsDuration（周期构造期固定）。金额按原始最小单位入参，地址做合法性校验。
 */
export function useAdminMutation({ poolAddress, operatorRole }: UseAdminMutationArgs) {
  const { message } = App.useApp()
  const mutation = useContractMutation()

  const pause = async () => {
    await mutation.run(
      { address: poolAddress, abi: stakingPoolV2Abi, functionName: 'pause', args: [] },
      { submittedMessage: '暂停已提交，等待链上确认' },
    )
  }

  const unpause = async () => {
    await mutation.run(
      { address: poolAddress, abi: stakingPoolV2Abi, functionName: 'unpause', args: [] },
      { submittedMessage: '恢复已提交，等待链上确认' },
    )
  }

  const setTreasury = async (treasury: string) => {
    if (!isAddress(treasury)) {
      message.error('国库地址无效')
      return
    }
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'setTreasury',
        args: [treasury],
      },
      { submittedMessage: '设置国库已提交，等待链上确认' },
    )
  }

  const sweepSubsidy = async (to: string, rawAmount: string) => {
    if (!isAddress(to)) {
      message.error('接收地址无效')
      return
    }
    const amount = toBigint(rawAmount)
    if (amount === undefined) {
      message.error('清扫金额无效')
      return
    }
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'sweepSubsidy',
        args: [to, amount],
      },
      { submittedMessage: '清扫补贴已提交，等待链上确认' },
    )
  }

  const sweepExpiredBaseReward = async (to: string) => {
    if (!isAddress(to)) {
      message.error('接收地址无效')
      return
    }
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'sweepExpiredBaseReward',
        args: [to],
      },
      { submittedMessage: '清扫过期基础奖励已提交，等待链上确认' },
    )
  }

  const recoverToken = async (tokenAddress: string, rawAmount: string) => {
    if (!isAddress(tokenAddress)) {
      message.error('代币地址无效')
      return
    }
    const amount = toBigint(rawAmount)
    if (amount === undefined) {
      message.error('回收金额无效')
      return
    }
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'recoverERC20',
        args: [tokenAddress, amount],
      },
      { submittedMessage: '回收代币已提交，等待链上确认' },
    )
  }

  const grantOperatorRole = async (account: string) => {
    if (!isAddress(account)) {
      message.error('授予地址无效')
      return
    }
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'grantRole',
        args: [operatorRole, account],
      },
      { submittedMessage: '授予运营角色已提交，等待链上确认' },
    )
  }

  return {
    mutation,
    pause,
    unpause,
    setTreasury,
    sweepSubsidy,
    sweepExpiredBaseReward,
    recoverToken,
    grantOperatorRole,
  }
}