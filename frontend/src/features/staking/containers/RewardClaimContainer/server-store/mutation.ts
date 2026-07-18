import type { Address } from 'viem'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import { useContractMutation } from '../../../utils/mutation'

type UseRewardClaimMutationArgs = {
  poolAddress: Address
}

/**
 * 领取 mutation：claimAll 一次性结算并发放全部可领取奖励
 * （基础奖励 + 锁仓加成 + 受邀加成 + 三级返佣）。
 */
export function useRewardClaimMutation({ poolAddress }: UseRewardClaimMutationArgs) {
  const mutation = useContractMutation()

  const claim = async () => {
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'claimAll',
        args: [],
      },
      { submittedMessage: '领取已提交，等待链上确认' },
    )
  }

  return { mutation, claim }
}