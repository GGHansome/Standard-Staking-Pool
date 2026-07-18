import { Card, Col, Row, Statistic } from 'antd'
import { formatTokenAmount } from '../../utils/format'
import type { UserPositionCardProps } from './interface'

export function UserPositionCard({
  stakingTokenSymbol,
  stakingTokenDecimals,
  stakingWalletBalance,
  stakingAllowance,
  totalStaked,
  activeDepositCount,
  rewardTokenSymbol,
  rewardTokenDecimals,
  earnedRewards,
  claimableReferral,
}: UserPositionCardProps) {
  return (
    <Card title="我的仓位">
      <Row gutter={[16, 16]}>
        <Col xs={24} md={8}>
          <Statistic
            title="钱包质押币余额"
            value={`${formatTokenAmount(stakingWalletBalance, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic
            title="已授权质押币"
            value={`${formatTokenAmount(stakingAllowance, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic
            title={`我的质押 (${activeDepositCount} 笔仓位)`}
            value={`${formatTokenAmount(totalStaked, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic
            title="可领取仓位收益"
            value={`${formatTokenAmount(earnedRewards, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic
            title="可领取推荐返佣"
            value={`${formatTokenAmount(claimableReferral, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
        </Col>
      </Row>
    </Card>
  )
}