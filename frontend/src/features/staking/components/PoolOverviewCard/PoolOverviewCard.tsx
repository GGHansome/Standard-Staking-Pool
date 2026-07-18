import { Card, Col, Descriptions, Divider, Row, Statistic, Table, Tag } from 'antd'
import {
  formatAddress,
  formatApr,
  formatBps,
  formatCountdown,
  formatDuration,
  formatRewardAmount,
  formatRewardRate,
  formatTokenAmount,
} from '../../utils/format'
import type { PoolOverviewCardProps } from './interface'

export function PoolOverviewCard({
  isPaused,
  isRewardPeriodActive,
  totalSupply,
  rewardsDuration,
  periodFinish,
  chainTimestamp,
  apr,
  rewardPerSecond,
  lockTiers,
  subsidy,
  penalty,
  stakingTokenAddress,
  stakingTokenSymbol,
  stakingTokenDecimals,
  stakingTokenUsdPrice,
  rewardTokenAddress,
  rewardTokenSymbol,
  rewardTokenDecimals,
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
          <Statistic
            title="奖励剩余时间"
            value={formatCountdown(periodFinish, chainTimestamp)}
          />
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
        <Col xs={24} md={8}>
          <Statistic
            title="锁仓质押开放"
            value={isRewardPeriodActive ? '是' : '否'}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="提前退出罚金率" value={formatBps(penalty.penaltyRate)} />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="最大补贴率" value={formatBps(subsidy.maxSubsidyRate)} />
        </Col>
      </Row>

      <Divider titlePlacement="left">锁仓档位</Divider>
      <Table<{ key: string; duration: bigint; boostRate: bigint }>
        size="small"
        pagination={false}
        dataSource={lockTiers.map((tier, index) => ({
          key: String(index),
          duration: tier.duration,
          boostRate: tier.boostRate,
        }))}
        columns={[
          {
            title: '锁仓期限',
            dataIndex: 'duration',
            render: (value: bigint) => formatDuration(value),
          },
          {
            title: '加成比例',
            dataIndex: 'boostRate',
            render: (value: bigint) => formatBps(value),
          },
        ]}
        locale={{ emptyText: '未配置锁仓档位（仅支持活期）' }}
      />

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
        <Descriptions.Item label="补贴储备">
          {formatTokenAmount(subsidy.subsidyReserve, rewardTokenDecimals)} {rewardTokenSymbol}
        </Descriptions.Item>
        <Descriptions.Item label="罚金金库">{formatAddress(penalty.treasury)}</Descriptions.Item>
      </Descriptions>
    </Card>
  )
}