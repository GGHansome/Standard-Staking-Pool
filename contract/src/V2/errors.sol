// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

/// @title IStakingPoolV2Errors
/// @notice 定义质押池 V2 在参数校验、权限边界、资产覆盖和业务状态中使用的自定义错误。
interface IStakingPoolV2Errors {
    /// @notice 金额参数必须大于 0。
    error AmountMustBeGreaterThanZero();

    /// @notice 地址参数不能为零地址。
    error AddressCannotBeZero();

    /// @notice 奖励周期时长不能为 0。
    error RewardsDurationCannotBeZero();

    /// @notice 注入的基础奖励数量不能为 0。
    error RewardAmountCannotBeZero();

    /// @notice 注入的基础奖励太小，无法形成有效释放速率。
    error RewardAmountTooSmall();

    /// @notice 指定的质押仓位不存在。
    error DepositDoesNotExist();

    /// @notice 调用者不是指定质押仓位的所有者。
    error NotDepositOwner();

    /// @notice 指定质押仓位已经关闭。
    error DepositAlreadyClosed();

    /// @notice 用户活跃质押仓位数量超过上限。
    error TooManyActiveDeposits();

    /// @notice 批量操作的仓位列表不能为空。
    error EmptyDepositIds();

    /// @notice 批量操作的仓位数量超过上限。
    error TooManyDepositIds();

    /// @notice 批量操作的仓位列表中存在重复仓位编号。
    error DuplicateDepositId();

    /// @notice 锁仓期限不是已配置的有效档位。
    error InvalidLockDuration();

    /// @notice 当前奖励周期未激活，不能创建锁仓质押。
    error LockStakingNotActive();

    /// @notice 邀请人无效。
    error InvalidInviter();

    /// @notice 三级返佣比例未构成从 L1 开始的连续前缀（出现 L2>0 而 L1==0，或 L3>0 而 L2==0）。
    error InvalidReferralRateConfig();

    /// @notice 锁仓期限列表和加成列表长度不一致。
    error LockTierLengthMismatch();

    /// @notice 锁仓档位数量超过上限。
    error TooManyLockTiers();

    /// @notice 锁仓期限配置重复。
    error DuplicateLockDuration();

    /// @notice 锁仓加成比例不能为 0。
    error LockBoostRateCannotBeZero();

    /// @notice 提前退出罚金比例超过允许上限。
    error PenaltyRateTooHigh();

    /// @notice 当前配置计算出的最大补贴比例超过部署上限。
    error MaxSubsidyRateExceeded();

    /// @notice 补贴储备不足以覆盖已归集补贴和未结算最大补贴负债。
    error InsufficientSubsidyReserve();

    /// @notice 可清扫补贴余额不足。
    error InsufficientSweepableSubsidy();

    /// @notice 奖励周期仍处于激活状态。
    error RewardPeriodStillActive();

    /// @notice 池内仍存在活跃质押本金。
    error ActiveStakesExist();

    /// @notice 合约资产余额不足以覆盖质押本金、基础奖励和补贴储备。
    error InsufficientAssetCoverage();

    /// @notice 不能通过救援接口提取质押资产或奖励资产。
    error CannotRecoverCoreToken();

    /// @notice 不支持转账扣费或到账数量不等于请求数量的 ERC20。
    error FeeOnTransferNotSupported();
}