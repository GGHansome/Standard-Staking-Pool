import { Alert, Col, Empty, Row } from 'antd'
import { zeroAddress } from 'viem'
import { missingConfigMessages } from '../../../../config/contracts'
import { DashboardLayout } from '../../components/layout/DashboardLayout'
import { PoolOverviewCard } from '../../components/PoolOverviewCard'
import { UserPositionCard } from '../../components/UserPositionCard'
import { WalletContainer } from '../WalletContainer'
import { StakeContainer } from '../StakeContainer'
import { DepositListContainer } from '../DepositListContainer'
import { RewardClaimContainer } from '../RewardClaimContainer'
import { ReferralContainer } from '../ReferralContainer'
import { OperatorRewardContainer } from '../OperatorRewardContainer'
import { AdminContainer } from '../AdminContainer'
import { useDashboardData } from './server-store/selector'

export function StakingDashboardContainer() {
  const {
    poolAddress,
    hasPoolAddress,
    chainTimestamp,
    stakingToken,
    rewardToken,
    pool,
    user,
    role,
  } = useDashboardData()

  if (!hasPoolAddress || !poolAddress) {
    return (
      <DashboardLayout isPaused={false} configWarnings={missingConfigMessages}>
        <Empty description="质押池地址未配置" />
      </DashboardLayout>
    )
  }

  const isConnected = user.isConnected
  const isRolePending = isConnected && role.status === 'loading'
  const isRoleError = isConnected && role.status === 'error'
  const isManagementWallet = role.isAdmin || role.isOperator
  const hasPersonalActivity =
    user.totalStaked > 0n ||
    user.earnedRewards > 0n ||
    user.claimableReferral > 0n ||
    user.activeDepositCount > 0
  const showPublicStaking = !isConnected || (role.status === 'ready' && !isManagementWallet)
  const showPersonalPosition = showPublicStaking || (isManagementWallet && hasPersonalActivity)

  return (
    <DashboardLayout isPaused={pool.paused} configWarnings={missingConfigMessages}>
      <Row gutter={[16, 16]}>
        <Col xs={24}>
          <WalletContainer />
        </Col>

        {isRolePending && (
          <Col xs={24}>
            <Alert showIcon type="info" message="正在确认当前钱包权限" />
          </Col>
        )}

        {isRoleError && (
          <Col xs={24}>
            <Alert
              showIcon
              type="error"
              message="钱包权限读取失败"
              description="为避免误操作，交易入口已暂时隐藏。请检查网络后重试。"
            />
          </Col>
        )}

        {isManagementWallet && (
          <Col xs={24}>
            <Alert
              showIcon
              type="warning"
              message={`管理钱包模式 · ${
                role.isAdmin && role.isOperator
                  ? 'Admin / Operator'
                  : role.isAdmin
                    ? 'Admin'
                    : 'Operator'
              }`}
              description="为保持运营职责隔离，当前界面不提供新增质押和推荐操作；已有仓位与奖励仍可领取和退出。"
            />
          </Col>
        )}

        <Col xs={24} lg={showPersonalPosition ? 16 : 24}>
          <PoolOverviewCard
            isPaused={pool.paused}
            isRewardPeriodActive={pool.isRewardPeriodActive}
            totalSupply={pool.totalSupply}
            rewardsDuration={pool.schedule.rewardsDuration}
            periodFinish={pool.schedule.periodFinish}
            chainTimestamp={chainTimestamp}
            apr={pool.apr}
            rewardPerSecond={pool.rewardPerSecond}
            lockTiers={pool.lockTiers}
            subsidy={pool.subsidy}
            penalty={pool.penalty}
            stakingTokenAddress={stakingToken.address}
            stakingTokenSymbol={stakingToken.symbol}
            stakingTokenDecimals={stakingToken.decimals}
            stakingTokenUsdPrice={stakingToken.usdPrice}
            rewardTokenAddress={rewardToken.address}
            rewardTokenSymbol={rewardToken.symbol}
            rewardTokenDecimals={rewardToken.decimals}
            rewardTokenUsdPrice={rewardToken.usdPrice}
          />
        </Col>

        {showPersonalPosition && (
          <Col xs={24} lg={8}>
            <UserPositionCard
              stakingTokenSymbol={stakingToken.symbol}
              stakingTokenDecimals={stakingToken.decimals}
              stakingWalletBalance={stakingToken.balance}
              stakingAllowance={stakingToken.allowance}
              totalStaked={user.totalStaked}
              activeDepositCount={user.activeDepositCount}
              rewardTokenSymbol={rewardToken.symbol}
              rewardTokenDecimals={rewardToken.decimals}
              earnedRewards={user.earnedRewards}
              claimableReferral={user.claimableReferral}
            />
          </Col>
        )}

        {showPublicStaking && (
          <Col xs={24} lg={12}>
            <StakeContainer
              poolAddress={poolAddress}
              stakingToken={stakingToken}
              isConnected={isConnected}
              isPoolPaused={pool.paused}
              isRewardPeriodActive={pool.isRewardPeriodActive}
            />
          </Col>
        )}

        {showPersonalPosition && (
          <Col xs={24} lg={showPublicStaking ? 12 : 24}>
            <RewardClaimContainer
              poolAddress={poolAddress}
              rewardToken={rewardToken}
              isConnected={isConnected}
              isPaused={pool.paused}
            />
          </Col>
        )}

        {(showPublicStaking || user.activeDepositCount > 0) && (
          <Col xs={24}>
            <DepositListContainer
              poolAddress={poolAddress}
              chainTimestamp={chainTimestamp}
              stakingToken={stakingToken}
              rewardToken={rewardToken}
              penaltyRate={pool.penalty.penaltyRate}
              isConnected={isConnected}
            />
          </Col>
        )}

        {showPublicStaking && (
          <Col xs={24}>
            <ReferralContainer rewardToken={rewardToken} />
          </Col>
        )}

        {role.isOperator && (
          <Col xs={24} lg={12}>
            <OperatorRewardContainer
              poolAddress={poolAddress}
              rewardToken={rewardToken}
              subsidy={pool.subsidy}
              maxSweepableSubsidy={pool.maxSweepableSubsidy}
              injectedBaseCumulative={pool.injectedBaseCumulative}
              isConnected={isConnected}
              isPaused={pool.paused}
            />
          </Col>
        )}

        {role.isAdmin && (
          <Col xs={24}>
            <AdminContainer
              poolAddress={poolAddress}
              operatorRole={role.operatorRole ?? zeroAddress}
              rewardToken={rewardToken}
              subsidy={pool.subsidy}
              penalty={pool.penalty}
              baseRewardReserve={pool.baseRewardReserve}
              maxSweepableSubsidy={pool.maxSweepableSubsidy}
              isPaused={pool.paused}
              isConnected={isConnected}
            />
          </Col>
        )}
      </Row>
    </DashboardLayout>
  )
}