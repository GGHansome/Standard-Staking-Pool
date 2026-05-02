// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IStakingPool
 * @dev V1 标准双币质押收益池接口 (Standard Dual-Token Staking Pool)
 * 采用无锁仓随存随取模型（Flexible Staking），依托水位线模型进行奖励分发。
 */
interface IStakingPool is IAccessControl {
    /* ============ 事件 (Events) ============ */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address indexed token, uint256 amount);

    error AmountMustBeGreaterThanZero();
    error AddressCannotBeZero();
    error RewardsDurationCannotBeZero();
    error RewardAmountCannotBeZero();
    error InsufficientBalance();
    error CannotRecoverStakingOrRewardTokens();
    error RewardsDurationCannotBeSetBeforeCurrentPeriodEnds();

    /* ============ 视图函数 (View Functions) ============ */

    /**
     * @notice 获取 OPERATOR_ROLE 的常量标识符
     * @dev 前端和外部合约需要此标识符来调用 hasRole/grantRole 等方法
     */
    function OPERATOR_ROLE() external view returns (bytes32);

    /**
     * @notice 获取质押代币 (Staking Token) 的合约地址
     */
    function stakingToken() external view returns (address);

    /**
     * @notice 获取奖励代币 (Reward Token) 的合约地址
     */
    function rewardToken() external view returns (address);

    /**
     * @notice 当前奖励周期的结束时间戳
     */
    function periodFinish() external view returns (uint256);

    /**
     * @notice 最近一次全局奖励更新的时间戳
     */
    function lastUpdateTime() external view returns (uint256);

    /**
     * @notice 查询合约当前是否处于暂停状态
     */
    function paused() external view returns (bool);

    /**
     * @notice 当前资金池内的总锁仓量 (TVL)
     */
    function totalSupply() external view returns (uint256);

    /**
     * @notice 查询指定用户的质押余额
     * @param account 用户地址
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @notice 奖励发放速率（每秒释放的奖励代币数量）
     * @dev 该值已被放大 1e18 倍以防止精度丢失。前端在计算真实的每秒奖励数 (Wei) 时，需将此值除以 1e18。
     */
    function rewardRate() external view returns (uint256);

    /**
     * @notice 单次注入奖励的持续时间（奖励周期）
     */
    function rewardsDuration() external view returns (uint256);

    /**
     * @notice 查询指定用户的当前未领取收益
     * @param account 用户地址
     */
    function earned(address account) external view returns (uint256);

    /**
     * @notice 每单位质押代币的累计奖励
     * @dev 该值已被放大 1e18 倍以防止精度丢失。前端在使用该值时，请注意它包含了额外的 1e18 精度缩放。
     */
    function rewardPerToken() external view returns (uint256);

    /**
     * @notice 适用的最新奖励时间（当前时间或奖励周期结束时间，取较小值）
     */
    function lastTimeRewardApplicable() external view returns (uint256);

    /* ============ 用户操作函数 (User Mutative Functions) ============ */

    /**
     * @notice 质押代币入池
     * @param amount 质押数量 (必须大于 0)
     */
    function stake(uint256 amount) external;

    /**
     * @notice 提取本金出池
     * @param amount 提取数量 (必须大于 0)
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice 领取已累积的奖励代币
     */
    function getReward() external;

    /**
     * @notice 一键退出：提取所有本金并领取所有奖励
     * @dev 仅当本金余额大于 0 时才执行 withdraw，避免零值校验失败
     */
    function exit() external;

    /* ============ 管理员/运营操作 (Admin/Operator Functions) ============ */

    /**
     * @notice 触发紧急暂停 (仅限 Admin 调用)
     */
    function pause() external;

    /**
     * @notice 解除紧急暂停 (仅限 Admin 调用)
     */
    function unpause() external;

    /**
     * @notice 注入新的奖励并触发新的发奖周期 (仅限 Operator 调用)
     * @param reward 注入的奖励代币数量 (必须大于 0)
     */
    function notifyRewardAmount(uint256 reward) external;

    /**
     * @notice 设置奖励周期 (仅限 Admin 调用)
     * @param _rewardsDuration 新的奖励周期持续时间（秒，必须大于 0）
     * @dev 只能在当前发奖周期完全结束后才能调用
     */
    function setRewardsDuration(uint256 _rewardsDuration) external;

    /**
     * @notice 逃生舱：提取用户误打入的错误 ERC20 代币 (仅限 Admin 调用)
     * @param tokenAddress 错误代币的地址
     * @param tokenAmount 提取的数量
     * @dev 严格禁止提取质押代币 (Staking Token) 以及尚未发放完的奖励代币
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
