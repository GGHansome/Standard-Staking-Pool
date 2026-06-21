import { Card, Col, Descriptions, Divider, Row, Statistic, Tag } from 'antd'
import type { Address } from 'viem'
import {
  formatAddress,
  formatApr,
  formatCountdown,
  formatRewardAmount,
  formatRewardRate,
  formatTokenAmount,
} from '../utils/format'

type PoolOverviewCardProps = {
  isPaused: boolean
  totalSupply: bigint
  rewardsDuration: bigint
  periodFinish: bigint
  apr?: number
  rewardPerSecond?: number
  stakingTokenAddress?: Address
  stakingTokenSymbol: string
  stakingTokenDecimals: number
  stakingTokenUsdPrice?: number
  rewardTokenAddress?: Address
  rewardTokenSymbol: string
  rewardTokenUsdPrice?: number
}

export function PoolOverviewCard({
  isPaused,
  totalSupply,
  rewardsDuration,
  periodFinish,
  apr,
  rewardPerSecond,
  stakingTokenAddress,
  stakingTokenSymbol,
  stakingTokenDecimals,
  stakingTokenUsdPrice,
  rewardTokenAddress,
  rewardTokenSymbol,
  rewardTokenUsdPrice,
}: PoolOverviewCardProps) {
  return (
    <Card
      title="质押池概览"
      extra={isPaused ? <Tag color="red">已暂停</Tag> : <Tag color="green">运行中</Tag>}
    >
      <Row gutter={[16, 16]}>
        <Col xs={24} md={8}>
          <Statistic
            title="总质押量"
            value={`${formatTokenAmount(totalSupply, stakingTokenDecimals)} ${stakingTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="APR" value={formatApr(apr)} />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="发奖倒计时" value={formatCountdown(periodFinish)} />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="每秒释放" value={formatRewardRate(rewardPerSecond, rewardTokenSymbol)} />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="奖励周期(秒)" value={rewardsDuration.toString()} />
        </Col>
        <Col xs={24} md={8}>
          <Statistic
            title="本周期释放"
            value={formatRewardAmount(
              rewardPerSecond === undefined ? undefined : rewardPerSecond * Number(rewardsDuration),
              rewardTokenSymbol,
            )}
          />
        </Col>
      </Row>
      <Divider />
      <Descriptions size="small" column={{ xs: 1, md: 2 }}>
        <Descriptions.Item label="质押代币">
          {stakingTokenSymbol} ({formatAddress(stakingTokenAddress)})
        </Descriptions.Item>
        <Descriptions.Item label="奖励代币">
          {rewardTokenSymbol} ({formatAddress(rewardTokenAddress)})
        </Descriptions.Item>
        <Descriptions.Item label="质押币价格">
          {stakingTokenUsdPrice ? `$${stakingTokenUsdPrice}` : '--'}
        </Descriptions.Item>
        <Descriptions.Item label="奖励币价格">
          {rewardTokenUsdPrice ? `$${rewardTokenUsdPrice}` : '--'}
        </Descriptions.Item>
      </Descriptions>
    </Card>
  )
}
