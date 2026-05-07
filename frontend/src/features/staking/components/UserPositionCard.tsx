import { Card, Col, Row, Statistic } from 'antd'
import { formatTokenAmount } from '../utils/format'

type UserPositionCardProps = {
  stakingTokenSymbol: string
  stakingTokenDecimals: number
  stakingWalletBalance: bigint
  stakingAllowance: bigint
  stakedBalance: bigint
  rewardTokenSymbol: string
  rewardTokenDecimals: number
  earnedRewards: bigint
}

export function UserPositionCard({
  stakingTokenSymbol,
  stakingTokenDecimals,
  stakingWalletBalance,
  stakingAllowance,
  stakedBalance,
  rewardTokenSymbol,
  rewardTokenDecimals,
  earnedRewards,
}: UserPositionCardProps) {
  return (
    <Card title="我的仓位">
      <Row gutter={[16, 16]}>
        <Col xs={24} md={6}>
          <Statistic
            title="钱包质押币余额"
            value={`${formatTokenAmount(stakingWalletBalance, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={6}>
          <Statistic
            title="已授权质押币"
            value={`${formatTokenAmount(stakingAllowance, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={6}>
          <Statistic
            title="我的质押"
            value={`${formatTokenAmount(stakedBalance, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={6}>
          <Statistic
            title="可领取收益"
            value={`${formatTokenAmount(earnedRewards, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
        </Col>
      </Row>
    </Card>
  )
}
