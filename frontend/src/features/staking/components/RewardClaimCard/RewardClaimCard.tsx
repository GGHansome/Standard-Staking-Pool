import { Alert, Button, Card, Space, Statistic } from 'antd'
import { formatTokenAmount } from '../../utils/format'
import type { RewardClaimCardProps } from './interface'

export function RewardClaimCard({
  rewardTokenSymbol,
  rewardTokenDecimals,
  earnedRewards,
  claimableReferral,
  isPaused,
  disabled,
  claimDisabled,
  onClaim,
}: RewardClaimCardProps) {
  const total = earnedRewards + claimableReferral

  return (
    <Card title="领取奖励">
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Space size="large" wrap>
          <Statistic
            title="仓位收益"
            value={`${formatTokenAmount(earnedRewards, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
          <Statistic
            title="推荐返佣"
            value={`${formatTokenAmount(claimableReferral, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
          <Statistic
            title="合计可领取"
            value={`${formatTokenAmount(total, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
        </Space>
        <Space wrap>
          <Button type="primary" disabled={disabled || claimDisabled} onClick={() => void onClaim()}>
            一键领取全部 {rewardTokenSymbol}
          </Button>
        </Space>
        {isPaused ? (
          <Alert
            showIcon
            type="warning"
            message="合约暂停中：禁止新增质押，但领取与退出仍可使用。"
          />
        ) : null}
      </Space>
    </Card>
  )
}