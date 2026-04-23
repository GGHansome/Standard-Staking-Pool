// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IStakingPool
 * @dev V1 标准双币质押收益池接口 (Standard Dual-Token Staking Pool)
 * 采用无锁仓随存随取模型（Flexible Staking），依托水位线模型进行奖励分发。
 */
interface IStakingPool {
    /* ============ 事件 (Events) ============ */

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);

    /* ============ 视图函数 (View Functions) ============ */

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
     */
    function rewardPerToken() external view returns (uint256);

    /**
     * @notice 适用的最新奖励时间（当前时间或奖励周期结束时间，取较小值）
     */
    function lastTimeRewardApplicable() external view returns (uint256);

    /* ============ 用户操作函数 (User Mutative Functions) ============ */

    /**
     * @notice 质押代币入池
     * @param amount 质押数量
     */
    function stake(uint256 amount) external;

    /**
     * @notice 提取本金出池
     * @param amount 提取数量
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice 领取已累积的奖励代币
     */
    function getReward() external;

    /**
     * @notice 一键退出：提取所有本金并领取所有奖励
     */
    function exit() external;

    /* ============ 管理员/运营操作 (Admin/Operator Functions) ============ */

    /**
     * @notice 注入新的奖励并触发新的发奖周期 (仅限 Operator/Owner 调用)
     * @param reward 注入的奖励代币数量
     */
    function notifyRewardAmount(uint256 reward) external;

    /**
     * @notice 设置奖励周期 (仅限 Owner 调用)
     * @param _rewardsDuration 新的奖励周期持续时间（秒）
     * @dev 只能在当前发奖周期完全结束后才能调用
     */
    function setRewardsDuration(uint256 _rewardsDuration) external;

    /**
     * @notice 逃生舱：提取用户误打入的错误 ERC20 代币 (仅限 Owner 调用)
     * @param tokenAddress 错误代币的地址
     * @param tokenAmount 提取的数量
     * @dev 严格禁止提取质押代币 (Staking Token) 以及尚未发放完的奖励代币
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
