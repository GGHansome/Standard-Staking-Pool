import { App } from 'antd'
import { isAddress, zeroAddress, type Address } from 'viem'
import { erc20Abi } from '../../../../../contracts/erc20Abi'
import { stakingPoolV2Abi } from '../../../../../contracts/stakingPoolV2Abi'
import type { TokenView } from '../../../types'
import { useContractMutation } from '../../../utils/mutation'
import { parseTokenAmount } from '../../../utils/format'
import type { StakePayload } from '../../../components/StakeForm'

type UseStakeMutationArgs = {
  poolAddress: Address
  stakingToken: TokenView
}

/**
 * 质押 mutation：把表单输入（人类可读金额 / 锁仓秒数 / 邀请人地址）转换为合约入参，
 * 暴露 approve 与 stake 两个写动作。
 */
export function useStakeMutation({ poolAddress, stakingToken }: UseStakeMutationArgs) {
  const { message } = App.useApp()
  const mutation = useContractMutation()

  const approve = async (amount: string) => {
    if (!stakingToken.address) {
      message.error('质押代币地址尚未读取成功')
      return
    }

    const parsed = parseTokenAmount(amount, stakingToken.decimals)
    await mutation.run(
      {
        address: stakingToken.address,
        abi: erc20Abi,
        functionName: 'approve',
        args: [poolAddress, parsed],
      },
      { submittedMessage: '授权质押代币已提交，等待链上确认' },
    )
  }

  const stake = async ({ amount, lockDuration, inviter }: StakePayload) => {
    const parsed = parseTokenAmount(amount, stakingToken.decimals)

    if (stakingToken.allowance < parsed) {
      message.warning('质押代币授权不足，请先授权质押代币')
      return
    }

    const lock = BigInt(lockDuration || '0')

    let inviterAddress: Address = zeroAddress
    if (inviter) {
      if (!isAddress(inviter)) {
        message.error('邀请人地址无效')
        return
      }
      inviterAddress = inviter
    }

    await mutation.run(
      {
        address: poolAddress,
        abi: stakingPoolV2Abi,
        functionName: 'stake',
        args: [parsed, lock, inviterAddress],
      },
      { submittedMessage: '质押已提交，等待链上确认' },
    )
  }

  return { mutation, approve, stake }
}