// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IStakingPoolV2Types
/// @notice 定义质押池 V2 对外返回值和内部记账所需的数据结构。
interface IStakingPoolV2Types {
    /// @notice 单笔质押仓位的对外视图。
    /// @param owner 仓位所有者地址。
    /// @param amount 当前仍在池内的质押本金数量。
    /// @param unlockTime 锁仓到期时间；为 0 表示非锁仓质押。
    /// @param boostRate 当前仓位适用的锁仓加成比例，按 BPS 计价。
    /// @param rewardPerTokenPaid 该仓位上次结算时记录的全局单位质押奖励。
    /// @param rewardPerTokenAtUnlock 锁仓到期点对应的单位质押奖励，用于锁仓加成封顶结算。
    /// @param boostSettled 锁仓加成是否已经完成到期结算。
    /// @param pendingBaseReward 已归集但尚未领取的基础奖励。
    /// @param pendingInviteeBoostReward 已归集但尚未领取的被邀请人加成奖励。
    /// @param pendingBoostReward 已归集但尚未领取的锁仓加成奖励。
    struct DepositView {
        address owner;
        uint256 amount;
        uint256 unlockTime;
        uint256 boostRate;
        uint256 rewardPerTokenPaid;
        uint256 rewardPerTokenAtUnlock;
        bool boostSettled;
        uint256 pendingBaseReward;
        uint256 pendingInviteeBoostReward;
        uint256 pendingBoostReward;
    }

    /// @notice 单笔质押仓位的奖励拆分视图。
    /// @param baseReward 当前可归属于该仓位的基础奖励。
    /// @param inviteeBoostReward 已累计的被邀请人加成奖励。
    /// @param pendingBoostReward 已累计的锁仓加成奖励。
    /// @param claimableBoostReward 当前可领取的锁仓加成奖励。
    /// @param totalClaimable 当前可领取的奖励总额。
    /// @param boostClaimable 锁仓加成当前是否可领取。
    /// @param boostForfeitable 当前提前退出时锁仓加成是否会被罚没。
    struct DepositRewardView {
        uint256 baseReward;
        uint256 inviteeBoostReward;
        uint256 pendingBoostReward;
        uint256 claimableBoostReward;
        uint256 totalClaimable;
        bool boostClaimable;
        bool boostForfeitable;
    }

    /// @notice 当前奖励周期的对外视图。
    /// @param rewardsDuration 单个奖励周期持续时间。
    /// @param periodFinish 当前奖励周期结束时间。
    /// @param rewardRate 当前基础奖励释放速率。
    /// @param lastUpdateTime 最近一次全局奖励状态更新时间。
    /// @param rewardPerTokenStored 已存储的全局单位质押奖励。
    struct RewardScheduleView {
        uint256 rewardsDuration;
        uint256 periodFinish;
        uint256 rewardRate;
        uint256 lastUpdateTime;
        uint256 rewardPerTokenStored;
    }

    /// @notice 补贴资金池和最大补贴负债的对外视图。
    /// @param maxSubsidyRate 当前配置下理论最大补贴比例，按 BPS 计价。
    /// @param maxSubsidyRateCap 部署时允许的最大补贴比例上限，按 BPS 计价。
    /// @param subsidyReserve 当前补贴储备余额。
    /// @param totalPendingSubsidy 已经归集但尚未支付的补贴奖励。
    /// @param unsettledMaxSubsidyLiability 尚未通过实际结算冲销的最大补贴负债。
    struct SubsidyConfigView {
        uint256 maxSubsidyRate;
        uint256 maxSubsidyRateCap;
        uint256 subsidyReserve;
        uint256 totalPendingSubsidy;
        uint256 unsettledMaxSubsidyLiability;
    }
}

/// @title StakingPoolTypes
/// @notice 定义质押池 V2 内部状态流转使用的数据结构。
abstract contract StakingPoolTypes is IStakingPoolV2Types {
    /// @notice 单笔质押仓位的内部记账记录。
    /// @param owner 仓位所有者地址。
    /// @param amount 当前仍在池内的质押本金数量。
    /// @param unlockTime 锁仓到期时间；为 0 表示非锁仓质押。
    /// @param boostRate 当前仓位适用的锁仓加成比例，按 BPS 计价。
    /// @param rewardPerTokenPaid 该仓位上次结算时记录的全局单位质押奖励。
    /// @param rewardPerTokenAtUnlock 锁仓到期点对应的单位质押奖励。
    /// @param boostSettled 锁仓加成是否已经完成到期结算。
    /// @param pendingBaseReward 已归集但尚未领取的基础奖励。
    /// @param pendingInviteeBoostReward 已归集但尚未领取的被邀请人加成奖励。
    /// @param pendingBoostReward 已归集但尚未领取的锁仓加成奖励。
    struct DepositRecord {
        address owner;
        uint256 amount;
        uint256 unlockTime;
        uint256 boostRate;
        uint256 rewardPerTokenPaid;
        uint256 rewardPerTokenAtUnlock;
        bool boostSettled;
        uint256 pendingBaseReward;
        uint256 pendingInviteeBoostReward;
        uint256 pendingBoostReward;
    }

    /// @notice 全局单位质押奖励的时间快照。
    /// @param time 快照写入时间。
    /// @param rewardPerToken 快照时刻的单位质押奖励。
    /// @param periodFinish 快照所属奖励周期的结束时间。
    struct RewardCheckpoint {
        uint256 time;
        uint256 rewardPerToken;
        uint256 periodFinish;
    }

    /// @notice 退出流程中汇总的本金、罚金和奖励支付结果。
    /// @param principalReturned 需要返还给用户的质押本金。
    /// @param penaltyAmount 需要转入金库的提前退出罚金。
    /// @param rewardPaid 需要支付给用户的奖励总额。
    struct WithdrawAccounting {
        uint256 principalReturned;
        uint256 penaltyAmount;
        uint256 rewardPaid;
    }

    /// @notice 部署质押池时传入的完整配置。
    /// @param stakingToken 用户质押资产地址。
    /// @param rewardToken 奖励资产地址。
    /// @param admin 默认管理员地址。
    /// @param operator 奖励注入操作员地址，可为零地址。
    /// @param treasury 提前退出罚金接收地址。
    /// @param rewardsDuration 单个奖励周期持续时间。
    /// @param inviteeBoost 被邀请人自身获得的奖励加成比例，按 BPS 计价。
    /// @param level1 一级邀请人奖励比例，按 BPS 计价。
    /// @param level2 二级邀请人奖励比例，按 BPS 计价。
    /// @param level3 三级邀请人奖励比例，按 BPS 计价。
    /// @param penaltyRate 提前退出罚金比例，按 BPS 计价。
    /// @param maxSubsidyRateCap 允许的最大补贴比例上限，按 BPS 计价。
    /// @param durations 可选锁仓期限列表。
    /// @param boosts 与锁仓期限一一对应的加成比例列表，按 BPS 计价。
    struct ConstructorParams {
        address stakingToken;
        address rewardToken;
        address admin;
        address operator;
        address treasury;
        uint256 rewardsDuration;
        uint256 inviteeBoost;
        uint256 level1;
        uint256 level2;
        uint256 level3;
        uint256 penaltyRate;
        uint256 maxSubsidyRateCap;
        uint256[] durations;
        uint256[] boosts;
    }
}