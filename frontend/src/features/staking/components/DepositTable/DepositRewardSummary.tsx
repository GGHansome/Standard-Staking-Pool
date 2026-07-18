import { CheckCircleOutlined, LockOutlined } from '@ant-design/icons'
import { Space, Tag, Tooltip, Typography } from 'antd'
import type { DepositItem } from '../../types'
import { formatTokenAmount } from '../../utils/format'

type DepositRewardSummaryProps = {
  deposit: DepositItem
  rewardTokenSymbol: string
  rewardTokenDecimals: number
}

type BoostStatus = {
  label: string
  color?: string
  icon?: React.ReactNode
}

const getBoostStatus = (deposit: DepositItem): BoostStatus => {
  if (deposit.boostRate === 0n) {
    return { label: '活期无加成' }
  }
  if (deposit.boostClaimable) {
    return { label: '可领取', color: 'green', icon: <CheckCircleOutlined /> }
  }
  if (deposit.boostForfeitable) {
    return { label: '锁定中', color: 'gold', icon: <LockOutlined /> }
  }
  if (deposit.boostSettled) {
    return { label: '已结算' }
  }
  return { label: '已解锁', color: 'green', icon: <CheckCircleOutlined /> }
}

export function DepositRewardSummary({
  deposit,
  rewardTokenSymbol,
  rewardTokenDecimals,
}: DepositRewardSummaryProps) {
  const formatReward = (amount: bigint) => formatTokenAmount(amount, rewardTokenDecimals)
  const totalGenerated =
    deposit.baseReward + deposit.inviteeBoostReward + deposit.pendingBoostReward
  const boostStatus = getBoostStatus(deposit)

  const rewardItems = [
    {
      key: 'base',
      label: '基础奖励',
      amount: deposit.baseReward,
      color: 'blue',
      description: '基础质押产生的奖励，可随时领取。',
    },
    {
      key: 'invitee',
      label: '自身推荐补贴',
      amount: deposit.inviteeBoostReward,
      color: 'cyan',
      description: '设置有效邀请人后，此仓位额外获得的推荐补贴，可随时领取。',
    },
  ] as const

  return (
    <Space direction="vertical" size={4} style={{ minWidth: 270 }}>
      <Space size={8} wrap>
        <Typography.Text strong style={{ color: '#1677ff', fontVariantNumeric: 'tabular-nums' }}>
          {formatReward(deposit.totalClaimable)} {rewardTokenSymbol}
        </Typography.Text>
        <Typography.Text type="secondary" style={{ fontSize: 12 }}>
          当前可领取 · 已产生 {formatReward(totalGenerated)} {rewardTokenSymbol}
        </Typography.Text>
      </Space>

      <Space size={[4, 4]} wrap>
        {rewardItems.map((item) => (
          <Tooltip key={item.key} title={item.description}>
            <Tag bordered={false} color={item.color} style={{ marginInlineEnd: 0 }}>
              {item.label} {formatReward(item.amount)}
            </Tag>
          </Tooltip>
        ))}
        <Tooltip title="锁仓加成会持续累计，到期后才可领取；提前退出会全部作废。">
          <Tag bordered={false} color="purple" style={{ marginInlineEnd: 0 }}>
            锁仓加成 {formatReward(deposit.pendingBoostReward)}
          </Tag>
        </Tooltip>
        <Tag bordered={false} color={boostStatus.color} icon={boostStatus.icon} style={{ marginInlineEnd: 0 }}>
          {boostStatus.label}
        </Tag>
      </Space>
    </Space>
  )
}