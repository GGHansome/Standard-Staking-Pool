// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/IAccessControl.sol";

/**
 * @title IStakingPool
 * @notice V1 标准双币质押收益池接口。
 * @dev 采用无锁仓随存随取模型（Flexible Staking），依托水位线模型进行奖励分发。
 *      实现继承 OpenZeppelin AccessControl，因此还会产生 RoleGranted、RoleRevoked、
 *      RoleAdminChanged 事件；实现继承 Pausable，因此还会产生 Paused、Unpaused 事件。
 */
interface IStakingPool is IAccessControl {
    /* ============ 事件 (Events) ============ */

    /// @notice 用户质押本金入池。
    /// @param user 执行质押的钱包地址。
    /// @param amount 记入用户本金账本的质押数量。
    event Staked(address indexed user, uint256 amount);

    /// @notice 用户提取质押本金。
    /// @param user 执行提现的钱包地址。
    /// @param amount 从用户本金账本扣减并转出的数量。
    event Withdrawn(address indexed user, uint256 amount);

    /// @notice 用户领取已结算奖励。
    /// @param user 领取奖励的钱包地址。
    /// @param reward 实际发放的奖励数量。
    event RewardPaid(address indexed user, uint256 reward);

    /// @notice Operator 注入新奖励并开启或刷新奖励周期。
    /// @param reward 本次注入并纳入发放计划的奖励数量。
    event RewardAdded(uint256 reward);

    /// @notice Admin 更新奖励周期长度。
    /// @param newDuration 新的奖励周期持续时间，单位为秒。
    event RewardsDurationUpdated(uint256 newDuration);

    /// @notice Admin 救援误转入的非核心 ERC20。
    /// @param token 被救援的 ERC20 地址。
    /// @param amount 救援转出的数量。
    event Recovered(address indexed token, uint256 amount);

    /// @notice 入参数量为 0。
    error AmountMustBeGreaterThanZero();

    /// @notice 入参地址为零地址。
    error AddressCannotBeZero();

    /// @notice 尚未设置奖励周期或奖励周期被设置为 0。
    error RewardsDurationCannotBeZero();

    /// @notice 注入奖励数量为 0。
    error RewardAmountCannotBeZero();

    /// @notice 用户本金余额不足以完成提现。
    error InsufficientBalance();

    /// @notice 禁止通过 recoverERC20 提取质押代币或奖励代币。
    error CannotRecoverStakingOrRewardTokens();

    /// @notice 当前奖励周期尚未结束，不能修改奖励周期长度。
    error RewardsDurationCannotBeSetBeforeCurrentPeriodEnds();

    /// @notice V1 不支持 fee-on-transfer 等实际到账数量与传入数量不一致的代币。
    error FeeOnTransferNotSupported();

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
     * @dev V1 仅支持标准 ERC20。若实际到账数量与 amount 不一致，将 revert FeeOnTransferNotSupported。
     */
    function stake(uint256 amount) external;

    /**
     * @notice 提取本金出池
     * @param amount 提取数量 (必须大于 0)
     * @dev 提现不受暂停状态限制，以保证用户最后撤离权。
     */
    function withdraw(uint256 amount) external;

    /**
     * @notice 领取已累积的奖励代币
     * @dev 领取不受暂停状态限制；若当前无奖励则直接返回，不触发事件。
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
     * @dev 触发 OpenZeppelin Paused 事件。
     */
    function pause() external;

    /**
     * @notice 解除紧急暂停 (仅限 Admin 调用)
     * @dev 触发 OpenZeppelin Unpaused 事件。
     */
    function unpause() external;

    /**
     * @notice 注入新的奖励并触发新的发奖周期 (仅限 Operator 调用)
     * @param reward 注入的奖励代币数量 (必须大于 0)
     * @dev V1 仅支持标准 ERC20。若实际到账数量与 reward 不一致，将 revert FeeOnTransferNotSupported。
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
     * @dev 严格禁止提取质押代币 (Staking Token) 和奖励代币 (Reward Token)；
     *      暂停状态下仍可调用，便于应急救援误转资产。
     */
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external;
}
