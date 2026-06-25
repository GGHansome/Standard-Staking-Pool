// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/IAccessControl.sol";
import "./errors.sol";
import "./events.sol";
import "./types.sol";

/// @title IStakingPoolV2
/// @notice 质押池 V2 的统一外部接口，覆盖权限、查询、质押、领取、退出、奖励注入和管理操作。
interface IStakingPoolV2 is IAccessControl, IStakingPoolV2Types, IStakingPoolV2Events, IStakingPoolV2Errors {
    /// @notice 奖励注入操作员角色。
    /// @return 操作员角色标识。
    function OPERATOR_ROLE() external view returns (bytes32);

    /// @notice 比例计算基准，10000 表示 100%。
    /// @return BPS 基准值。
    function BPS() external view returns (uint256);

    /// @notice 单个用户最多允许保留的活跃质押仓位数量。
    /// @return 活跃仓位数量上限。
    function MAX_ACTIVE_DEPOSITS() external view returns (uint256);

    /// @notice 最多允许配置的锁仓档位数量。
    /// @return 锁仓档位数量上限。
    function MAX_LOCK_TIERS() external view returns (uint256);

    /// @notice 用户质押资产地址。
    /// @return 质押资产地址。
    function stakingToken() external view returns (address);

    /// @notice 奖励资产地址。
    /// @return 奖励资产地址。
    function rewardToken() external view returns (address);

    /// @notice 当前池内总质押本金。
    /// @return 总质押本金数量。
    function totalSupply() external view returns (uint256);

    /// @notice 当前合约是否处于暂停状态。
    /// @return 暂停状态。
    function paused() external view returns (bool);

    /// @notice 查询单笔质押仓位详情。
    /// @param depositId 仓位编号。
    /// @return deposit 仓位视图数据。
    function getDeposit(uint256 depositId) external view returns (DepositView memory deposit);

    /// @notice 查询用户当前活跃仓位编号列表。
    /// @param user 用户地址。
    /// @return depositIds 活跃仓位编号列表。
    function getActiveDepositIds(address user) external view returns (uint256[] memory depositIds);

    /// @notice 查询用户当前活跃仓位详情列表。
    /// @param user 用户地址。
    /// @return deposits 活跃仓位视图列表。
    function getUserDeposits(address user) external view returns (DepositView[] memory deposits);

    /// @notice 查询用户当前仍在池内的质押本金。
    /// @param user 用户地址。
    /// @return amount 用户质押本金数量。
    function totalStakedOf(address user) external view returns (uint256 amount);

    /// @notice 查询用户当前可领取的全部奖励。
    /// @param user 用户地址。
    /// @return amount 可领取奖励总额。
    function earned(address user) external view returns (uint256 amount);

    /// @notice 查询单笔仓位当前奖励拆分。
    /// @param depositId 仓位编号。
    /// @return reward 仓位奖励视图。
    function earnedByDeposit(uint256 depositId) external view returns (DepositRewardView memory reward);

    /// @notice 查询用户当前可领取的推荐奖励。
    /// @param user 用户地址。
    /// @return amount 可领取推荐奖励数量。
    function claimableReferralReward(address user) external view returns (uint256 amount);

    /// @notice 查询用户绑定的直接邀请人。
    /// @param user 用户地址。
    /// @return inviter 直接邀请人地址。
    function inviterOf(address user) external view returns (address inviter);

    /// @notice 查询用户是否已经完成邀请关系选择。
    /// @param user 用户地址。
    /// @return settled 是否已经设置邀请人或明确选择无邀请人。
    function hasSetInviter(address user) external view returns (bool settled);

    /// @notice 查询用户的三级上级邀请关系。
    /// @param user 用户地址。
    /// @return level1 一级邀请人地址。
    /// @return level2 二级邀请人地址。
    /// @return level3 三级邀请人地址。
    function getUpline(address user) external view returns (address level1, address level2, address level3);

    /// @notice 查询锁仓档位配置。
    /// @return durations 锁仓期限列表。
    /// @return boosts 与锁仓期限一一对应的加成比例列表，按 BPS 计价。
    function getLockTiers() external view returns (uint256[] memory durations, uint256[] memory boosts);

    /// @notice 查询推荐奖励配置。
    /// @return inviteeBoost 被邀请人自身获得的奖励加成比例，按 BPS 计价。
    /// @return level1 一级邀请人奖励比例，按 BPS 计价。
    /// @return level2 二级邀请人奖励比例，按 BPS 计价。
    /// @return level3 三级邀请人奖励比例，按 BPS 计价。
    function getReferralRates()
        external
        view
        returns (uint256 inviteeBoost, uint256 level1, uint256 level2, uint256 level3);

    /// @notice 查询提前退出罚金配置。
    /// @return penaltyRate 提前退出罚金比例，按 BPS 计价。
    /// @return treasury 罚金接收金库地址。
    function getPenaltyConfig() external view returns (uint256 penaltyRate, address treasury);

    /// @notice 查询补贴储备和补贴负债配置。
    /// @return config 补贴配置视图。
    function getSubsidyConfig() external view returns (SubsidyConfigView memory config);

    /// @notice 查询当前奖励周期状态。
    /// @return schedule 奖励周期视图。
    function getRewardSchedule() external view returns (RewardScheduleView memory schedule);

    /// @notice 查询当前是否处于有效奖励周期内。
    /// @return active 奖励周期是否激活。
    function isRewardPeriodActive() external view returns (bool active);

    /// @notice 查询当前全局单位质押奖励。
    /// @return 当前单位质押奖励。
    function rewardPerToken() external view returns (uint256);

    /// @notice 查询当前奖励计算适用的最后时间点。
    /// @return timestamp 当前区块时间和奖励周期结束时间之间的较小值。
    function lastTimeRewardApplicable() external view returns (uint256 timestamp);

    /// @notice 查询基础奖励储备余额。
    /// @return 基础奖励储备数量。
    function baseRewardReserve() external view returns (uint256);

    /// @notice 查询当前奖励周期尚未释放的基础奖励。
    /// @return 剩余基础奖励数量。
    function remainingBaseReward() external view returns (uint256);

    /// @notice 查询补贴储备余额。
    /// @return 补贴储备数量。
    function subsidyReserve() external view returns (uint256);

    /// @notice 查询已归集但尚未支付的补贴奖励总额。
    /// @return 已归集补贴奖励数量。
    function totalPendingSubsidy() external view returns (uint256);

    /// @notice 查询尚未通过实际结算冲销的最大补贴负债。
    /// @return 未结算最大补贴负债。
    function unsettledMaxSubsidyLiability() external view returns (uint256);

    /// @notice 查询当前最多可被管理员清扫的补贴余额。
    /// @return 可清扫补贴数量。
    function maxSweepableSubsidy() external view returns (uint256);

    /// @notice 创建一笔质押仓位。
    /// @param amount 质押本金数量。
    /// @param lockDuration 锁仓期限；为 0 表示非锁仓质押。
    /// @param inviter 邀请人地址；零地址表示不绑定邀请人。
    /// @return depositId 新创建的仓位编号。
    function stake(uint256 amount, uint256 lockDuration, address inviter) external returns (uint256 depositId);

    /// @notice 领取调用者当前全部可领取奖励。
    function claimAll() external;

    /// @notice 退出调用者的一笔质押仓位并领取相关奖励。
    /// @param depositId 仓位编号。
    function withdraw(uint256 depositId) external;

    /// @notice 批量退出调用者的多笔质押仓位并领取相关奖励。
    /// @param depositIds 仓位编号列表。
    function withdrawMultiple(uint256[] calldata depositIds) external;

    /// @notice 退出调用者的全部活跃质押仓位并领取相关奖励。
    function exit() external;

    /// @notice 注入新的基础奖励并按最大补贴比例补足补贴储备。
    /// @param baseRewardAmount 注入的基础奖励数量。
    function notifyRewardAmount(uint256 baseRewardAmount) external;

    /// @notice 更新提前退出罚金接收金库。
    /// @param treasury 新金库地址。
    function setTreasury(address treasury) external;

    /// @notice 清扫当前可释放的补贴余额。
    /// @param to 接收地址。
    /// @param amount 清扫数量。
    function sweepSubsidy(address to, uint256 amount) external;

    /// @notice 回收奖励周期结束且空池后的全部剩余基础奖励。
    /// @param to 接收地址。
    function sweepExpiredBaseReward(address to) external;

    /// @notice 暂停用户质押、奖励注入和补贴清扫等受控操作。
    function pause() external;

    /// @notice 恢复被暂停的受控操作。
    function unpause() external;

    /// @notice 救援误转入合约的非核心 ERC20 资产。
    /// @param token 被救援的 ERC20 地址。
    /// @param amount 救援数量。
    function recoverERC20(address token, uint256 amount) external;
}