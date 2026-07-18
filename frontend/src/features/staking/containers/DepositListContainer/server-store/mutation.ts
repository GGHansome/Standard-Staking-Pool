import { App } from 'antd'
import type { Address } from 'viem'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import { useContractMutation } from '../../../utils/mutation'

type UseDepositMutationArgs = {
  poolAddress: Address
}

/**
 * 仓位 mutation：暴露单仓位提取 / 批量提取 / 一键退出三个写动作。
 * exit 会清算用户全部活跃仓位并领取奖励；withdraw 系列按 depositId 精确退出。
 */
export function useDepositMutation({ poolAddress }: UseDepositMutationArgs) {
  const { message } = App.useApp()
  const mutation = useContractMutation()

  const withdraw = async (depositId: bigint) => {
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'withdraw',
        args: [depositId],
      },
      { submittedMessage: '提取已提交，等待链上确认' },
    )
  }

  const withdrawMultiple = async (depositIds: bigint[]) => {
    if (depositIds.length === 0) {
      message.warning('请先勾选要提取的仓位')
      return
    }

    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'withdrawMultiple',
        args: [depositIds],
      },
      { submittedMessage: '批量提取已提交，等待链上确认' },
    )
  }

  const exit = async () => {
    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'exit',
        args: [],
      },
      { submittedMessage: '一键退出已提交，等待链上确认' },
    )
  }

  return { mutation, withdraw, withdrawMultiple, exit }
}