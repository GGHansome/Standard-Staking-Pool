import { App } from 'antd'
import type { Address } from 'viem'
import { erc20Abi } from '../../../../../contracts/erc20Abi'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import type { TokenView } from '../../../types'
import { calculateRequiredRewardAllowance } from '../../../utils/contract'
import { useContractMutation } from '../../../utils/mutation'
import { parseTokenAmount } from '../../../utils/format'

type UseOperatorMutationArgs = {
  poolAddress: Address
  rewardToken: TokenView
  maxSubsidyRate: bigint
  maxSweepableSubsidy: bigint
  injectedBaseCumulative: bigint
}

/**
 * 运营注入 mutation：approve 奖励代币 + notifyRewardAmount(baseRewardAmount)。
 * 注入会按补贴配置触发对历史未结算补贴的补缴，金额转换沿用奖励代币精度。
 */
export function useOperatorMutation({
  poolAddress,
  rewardToken,
  maxSubsidyRate,
  maxSweepableSubsidy,
  injectedBaseCumulative,
}: UseOperatorMutationArgs) {
  const { message } = App.useApp()
  const mutation = useContractMutation()

  const requiredAllowanceFor = (baseRewardAmount: bigint) =>
    calculateRequiredRewardAllowance({
      baseRewardAmount,
      injectedBaseCumulative,
      maxSubsidyRate,
      maxSweepableSubsidy,
    })

  const approve = async (amount: string) => {
    if (!rewardToken.address) {
      message.error('奖励代币地址尚未读取成功')
      return
    }

    const parsed = parseTokenAmount(amount, rewardToken.decimals)
    const requiredAllowance = requiredAllowanceFor(parsed)
    await mutation.run(
      {
        address: rewardToken.address,
        abi: erc20Abi,
        functionName: 'approve',
        args: [poolAddress, requiredAllowance.total],
      },
      { submittedMessage: '授权奖励代币已提交，等待链上确认' },
    )
  }

  const notify = async (amount: string) => {
    const parsed = parseTokenAmount(amount, rewardToken.decimals)
    const requiredAllowance = requiredAllowanceFor(parsed)

    if (rewardToken.allowance < requiredAllowance.total) {
      message.warning('奖励代币授权不足，请先授权本次所需额度')
      return
    }

    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'notifyRewardAmount',
        args: [parsed],
      },
      { submittedMessage: '奖励注入已提交，等待链上确认' },
    )
  }

  return { mutation, approve, notify }
}