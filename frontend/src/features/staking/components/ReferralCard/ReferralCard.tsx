import { Card, Col, Descriptions, Row, Statistic, Tag } from 'antd'
import { zeroAddress } from 'viem'
import { formatAddress, formatBps, formatTokenAmount } from '../../utils/format'
import type { ReferralCardProps } from './interface'

export function ReferralCard({ referral, rewardTokenSymbol, rewardTokenDecimals }: ReferralCardProps) {
  const { inviter, hasSetInviter, upline, rates, claimable } = referral
  const hasInviter = hasSetInviter && inviter !== zeroAddress

  return (
    <Card
      title="推荐关系"
      extra={
        hasSetInviter ? (
          <Tag color={hasInviter ? 'blue' : 'default'}>
            {hasInviter ? '已绑定邀请人' : '无上级'}
          </Tag>
        ) : (
          <Tag color="orange">未绑定（首次质押可填邀请人）</Tag>
        )
      }
    >
      <Row gutter={[16, 16]}>
        <Col xs={24} md={8}>
          <Statistic title="直接邀请人" value={hasInviter ? formatAddress(inviter) : '--'} />
        </Col>
        <Col xs={24} md={8}>
          <Statistic
            title="可领取推荐返佣"
            value={`${formatTokenAmount(claimable, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
        </Col>
        <Col xs={24} md={8}>
          <Statistic title="自身推荐补贴" value={formatBps(rates.inviteeBoost)} />
        </Col>
      </Row>

      <Descriptions size="small" column={{ xs: 1, md: 2 }} style={{ marginTop: 16 }}>
        <Descriptions.Item label={`一级返佣 (${formatBps(rates.level1)})`}>
          {formatAddress(upline[0])}
        </Descriptions.Item>
        <Descriptions.Item label={`二级返佣 (${formatBps(rates.level2)})`}>
          {formatAddress(upline[1])}
        </Descriptions.Item>
        <Descriptions.Item label={`三级返佣 (${formatBps(rates.level3)})`}>
          {formatAddress(upline[2])}
        </Descriptions.Item>
      </Descriptions>
    </Card>
  )
}