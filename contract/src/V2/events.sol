// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IStakingPoolV2Events
/// @notice 定义质押池 V2 在质押、退出、奖励、补贴和治理操作中抛出的事件。
interface IStakingPoolV2Events {
    /// @notice 用户创建一笔质押仓位。
    /// @param user 质押用户地址。
    /// @param depositId 新创建的质押仓位编号。
    /// @param amount 实际进入池子的质押本金数量。
    /// @param lockDuration 本次质押选择的锁仓期限；为 0 表示非锁仓质押。
    /// @param unlockTime 锁仓到期时间；为 0 表示非锁仓质押。
    /// @param boostRate 本次仓位适用的锁仓加成比例，按 BPS 计价。
    event Staked(
        address indexed user,
        uint256 indexed depositId,
        uint256 amount,
        uint256 lockDuration,
        uint256 unlockTime,
        uint256 boostRate
    );

    /// @notice 用户正常退出一笔已到期或非锁仓仓位。
    /// @param user 退出用户地址。
    /// @param depositId 被退出的质押仓位编号。
    /// @param principalReturned 返还给用户的质押本金数量。
    event Withdrawn(address indexed user, uint256 indexed depositId, uint256 principalReturned);

    /// @notice 用户提前退出一笔未到期锁仓仓位。
    /// @param user 退出用户地址。
    /// @param depositId 被提前退出的质押仓位编号。
    /// @param principalReturned 扣除罚金后返还给用户的质押本金数量。
    /// @param penaltyAmount 转入金库的提前退出罚金数量。
    /// @param forfeitedBoostReward 因提前退出被罚没的锁仓加成奖励数量。
    event EarlyWithdrawn(
        address indexed user,
        uint256 indexed depositId,
        uint256 principalReturned,
        uint256 penaltyAmount,
        uint256 forfeitedBoostReward
    );

    /// @notice 一笔质押仓位被关闭。
    /// @param user 仓位所有者地址。
    /// @param depositId 被关闭的质押仓位编号。
    event DepositClosed(address indexed user, uint256 indexed depositId);

    /// @notice 用户成功绑定邀请人。
    /// @param user 被邀请用户地址。
    /// @param inviter 邀请人地址。
    event InviterBound(address indexed user, address indexed inviter);

    /// @notice 用户首次质押时选择不绑定邀请人。
    /// @param user 未绑定邀请人的用户地址。
    event NoInviterSet(address indexed user);

    /// @notice 单笔仓位归集基础奖励。
    /// @param user 仓位所有者地址。
    /// @param depositId 仓位编号。
    /// @param amount 本次归集的基础奖励数量。
    event BaseRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 单笔仓位归集锁仓加成奖励。
    /// @param user 仓位所有者地址。
    /// @param depositId 仓位编号。
    /// @param amount 本次归集的锁仓加成奖励数量。
    event LockBoostRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 单笔仓位归集被邀请人加成奖励。
    /// @param user 仓位所有者地址。
    /// @param depositId 仓位编号。
    /// @param amount 本次归集的被邀请人加成奖励数量。
    event InviteeBoostRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 邀请人归集一笔下级质押产生的推荐奖励。
    /// @param inviter 获得推荐奖励的邀请人地址。
    /// @param invitee 产生奖励来源的被邀请用户地址。
    /// @param level 推荐层级。
    /// @param sourceDepositId 产生奖励来源的质押仓位编号。
    /// @param amount 本次归集的推荐奖励数量。
    event ReferralRewardAccrued(
        address indexed inviter,
        address indexed invitee,
        uint8 indexed level,
        uint256 sourceDepositId,
        uint256 amount
    );

    /// @notice 用户提前退出时罚没锁仓加成奖励。
    /// @param user 仓位所有者地址。
    /// @param depositId 仓位编号。
    /// @param amount 被罚没的锁仓加成奖励数量。
    event LockBoostRewardForfeited(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 向用户支付单笔仓位的基础奖励。
    /// @param user 收款用户地址。
    /// @param depositId 仓位编号。
    /// @param amount 支付的基础奖励数量。
    event BaseRewardPaid(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 向用户支付单笔仓位的被邀请人加成奖励。
    /// @param user 收款用户地址。
    /// @param depositId 仓位编号。
    /// @param amount 支付的被邀请人加成奖励数量。
    event InviteeBoostRewardPaid(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 向用户支付推荐奖励。
    /// @param user 收款用户地址。
    /// @param amount 支付的推荐奖励数量。
    event ReferralRewardPaid(address indexed user, uint256 amount);

    /// @notice 向用户支付单笔仓位的锁仓加成奖励。
    /// @param user 收款用户地址。
    /// @param depositId 仓位编号。
    /// @param amount 支付的锁仓加成奖励数量。
    event LockBoostRewardPaid(address indexed user, uint256 indexed depositId, uint256 amount);

    /// @notice 向用户完成一次奖励支付。
    /// @param user 收款用户地址。
    /// @param totalAmount 本次支付的奖励总额。
    event RewardPaid(address indexed user, uint256 totalAmount);

    /// @notice 活动核心参数完成初始化配置。
    /// @param rewardsDuration 单个奖励周期持续时间。
    /// @param inviteeBoost 被邀请人自身获得的奖励加成比例，按 BPS 计价。
    /// @param level1 一级邀请人奖励比例，按 BPS 计价。
    /// @param level2 二级邀请人奖励比例，按 BPS 计价。
    /// @param level3 三级邀请人奖励比例，按 BPS 计价。
    /// @param maxSubsidyRate 当前配置下理论最大补贴比例，按 BPS 计价。
    /// @param maxSubsidyRateCap 部署时允许的最大补贴比例上限，按 BPS 计价。
    /// @param penaltyRate 提前退出罚金比例，按 BPS 计价。
    event ActivityConfigured(
        uint256 rewardsDuration,
        uint256 inviteeBoost,
        uint256 level1,
        uint256 level2,
        uint256 level3,
        uint256 maxSubsidyRate,
        uint256 maxSubsidyRateCap,
        uint256 penaltyRate
    );

    /// @notice 锁仓档位完成初始化配置。
    /// @param durations 锁仓期限列表。
    /// @param boosts 与锁仓期限一一对应的加成比例列表，按 BPS 计价。
    event LockTiersConfigured(uint256[] durations, uint256[] boosts);

    /// @notice 操作员注入新的基础奖励并同步补贴预算。
    /// @param baseRewardAmount 实际注入的基础奖励数量。
    /// @param subsidyRequired 按最大补贴比例计算出的理论补贴需求。
    /// @param subsidyCharged 本次额外收取并进入补贴储备的数量。
    event RewardAdded(uint256 baseRewardAmount, uint256 subsidyRequired, uint256 subsidyCharged);

    /// @notice 写入一条全局奖励快照。
    /// @param time 快照时间。
    /// @param rewardPerToken 快照时刻的单位质押奖励。
    /// @param periodFinish 快照所属奖励周期的结束时间。
    /// @param index 快照在历史数组中的索引。
    /// @param replaced 是否替换了同一区块时间内的上一条快照。
    event RewardCheckpointWritten(
        uint256 indexed time,
        uint256 rewardPerToken,
        uint256 periodFinish,
        uint256 index,
        bool replaced
    );

    /// @notice 新增补贴储备。
    /// @param amount 本次进入补贴储备的数量。
    event SubsidyReserved(uint256 amount);

    /// @notice 未结算最大补贴负债被更新。
    /// @param newValue 更新后的未结算最大补贴负债。
    event UnsettledMaxSubsidyLiabilityUpdated(uint256 newValue);

    /// @notice 管理员清扫可释放的补贴余额。
    /// @param to 补贴余额接收地址。
    /// @param amount 清扫数量。
    event SubsidySwept(address indexed to, uint256 amount);

    /// @notice 管理员回收奖励周期结束且空池后的剩余基础奖励。
    /// @param to 基础奖励接收地址。
    /// @param amount 回收数量。
    event ExpiredBaseRewardSwept(address indexed to, uint256 amount);

    /// @notice 用户提前退出罚金被支付至金库。
    /// @param user 支付罚金的用户地址。
    /// @param depositId 产生罚金的仓位编号。
    /// @param treasury 罚金接收金库地址。
    /// @param amount 罚金数量。
    event PenaltyPaid(address indexed user, uint256 indexed depositId, address indexed treasury, uint256 amount);

    /// @notice 金库地址被更新。
    /// @param treasury 新金库地址。
    event TreasuryUpdated(address indexed treasury);

    /// @notice 管理员救援非核心 ERC20 资产。
    /// @param token 被救援的 ERC20 地址。
    /// @param amount 救援数量。
    event Recovered(address indexed token, uint256 amount);
}