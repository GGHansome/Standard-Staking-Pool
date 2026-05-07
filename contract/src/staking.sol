// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StakingPool
 * @notice V1 标准双币质押收益池，支持灵活质押、按份额线性释放奖励和紧急暂停。
 * @dev V1 仅支持标准 ERC20 余额语义。fee-on-transfer 等实际到账数量与传入数量不一致的
 *      代币会在 stake 和 notifyRewardAmount 中被 balance delta 校验拒绝。
 */
contract StakingPool is IStakingPool, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice 用户级质押和奖励水位线账本。
    struct UserInfo {
        uint256 balance; // 用户的质押本金
        uint256 userRewardPerTokenPaid; // 用户上次操作时的全局水位线
        uint256 rewards; // 已结算但尚未领取的收益
    }

    /// @notice 用户质押的 ERC20 代币地址。
    address public immutable stakingToken;

    /// @notice 用户领取的奖励 ERC20 代币地址。
    address public immutable rewardToken;

    /// @notice 当前奖励周期结束时间戳。
    uint256 public periodFinish;

    /// @notice 最近一次更新全局奖励水位线的时间戳。
    uint256 public lastUpdateTime;

    /// @notice 单次奖励注入的线性释放周期，单位为秒。
    uint256 public rewardsDuration;

    /// @notice 每单位质押代币累计奖励，按 1e18 精度放大。
    uint256 public rewardPerTokenStored;

    /// @notice 每秒奖励释放速率，按 1e18 精度放大。
    uint256 public rewardRate;

    /// @notice 当前池内总质押本金。
    uint256 public totalSupply;

    /// @notice 用户地址到质押和奖励账本的映射。
    mapping(address => UserInfo) public userInfo;

    /// @notice 可注入奖励并开启奖励周期的运营角色。
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @dev 奖励计算精度放大倍数。
    uint256 private constant PRECISION = 1e18;

    /**
     * @notice 部署质押池并初始化核心资产与权限。
     * @param _stakingToken 质押代币地址，不能为零地址。
     * @param _rewardToken 奖励代币地址，不能为零地址。
     * @param _admin 默认管理员地址，不能为零地址。
     * @param _operator 初始 Operator 地址；可为零地址，表示部署后再由 Admin 授权。
     */
    constructor(
        address _stakingToken,
        address _rewardToken,
        address _admin,
        address _operator
    ) {
        if (
            _stakingToken == address(0) ||
            _rewardToken == address(0) ||
            _admin == address(0)
        ) {
            revert AddressCannotBeZero();
        }
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        if (_operator != address(0)) {
            _grantRole(OPERATOR_ROLE, _operator);
        }
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
    }

    /**
     * @dev 在状态变更前刷新全局奖励水位线，并可选结算指定用户的未领奖励。
     * @param account 需要同步奖励账本的用户地址；传零地址时仅更新全局状态。
     */
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            userInfo[account].rewards = earned(account);
            userInfo[account].userRewardPerTokenPaid = rewardPerTokenStored;
        }
        _;
    }

    /* ============ 视图函数 (View Functions) ============ */

    /// @inheritdoc IStakingPool
    function paused()
        public
        view
        override(IStakingPool, Pausable)
        returns (bool)
    {
        // TODO: implement
        return super.paused();
    }

    /// @inheritdoc IStakingPool
    function balanceOf(
        address account
    ) external view override returns (uint256) {
        // TODO: implement
        if (account == address(0)) {
            revert AddressCannotBeZero();
        }
        return userInfo[account].balance;
    }

    /// @inheritdoc IStakingPool
    function earned(address account) public view override returns (uint256) {
        // TODO: implement
        if (account == address(0)) {
            revert AddressCannotBeZero();
        }
        return
            (userInfo[account].balance *
                (rewardPerToken() - userInfo[account].userRewardPerTokenPaid)) /
            PRECISION +
            userInfo[account].rewards;
    }

    /// @inheritdoc IStakingPool
    function rewardPerToken() public view override returns (uint256) {
        // TODO: implement
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return
            rewardPerTokenStored +
            (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime)) /
            totalSupply;
    }

    /// @inheritdoc IStakingPool
    function lastTimeRewardApplicable() public view override returns (uint256) {
        // TODO: implement
        return Math.min(block.timestamp, periodFinish);
    }

    /* ============ 用户操作函数 (User Mutative Functions) ============ */

    /// @inheritdoc IStakingPool
    function stake(
        uint256 amount
    ) external override nonReentrant whenNotPaused updateReward(msg.sender) {
        // TODO: implement
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        uint256 balanceBefore = IERC20(stakingToken).balanceOf(address(this));
        IERC20(stakingToken).safeTransferFrom(
            msg.sender,
            address(this),
            amount
        );
        uint256 actualAmount = IERC20(stakingToken).balanceOf(address(this)) -
            balanceBefore;

        if (actualAmount != amount) {
            revert FeeOnTransferNotSupported();
        }

        userInfo[msg.sender].balance += actualAmount;
        totalSupply += actualAmount;
        emit Staked(msg.sender, actualAmount);
    }

    /// @inheritdoc IStakingPool
    function withdraw(
        uint256 amount
    ) public override nonReentrant updateReward(msg.sender) {
        // TODO: implement
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (amount > userInfo[msg.sender].balance) {
            revert InsufficientBalance();
        }
        userInfo[msg.sender].balance -= amount;
        totalSupply -= amount;
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    /// @inheritdoc IStakingPool
    function getReward() public override nonReentrant updateReward(msg.sender) {
        // TODO: implement
        uint256 reward = userInfo[msg.sender].rewards;
        if (reward == 0) {
            return;
        }
        userInfo[msg.sender].rewards = 0;
        IERC20(rewardToken).safeTransfer(msg.sender, reward);
        emit RewardPaid(msg.sender, reward);
    }

    /// @inheritdoc IStakingPool
    function exit() external override {
        // TODO: implement
        if (userInfo[msg.sender].balance > 0) {
            withdraw(userInfo[msg.sender].balance);
        }
        getReward();
    }

    /* ============ 管理员/运营操作 (Admin/Operator Functions) ============ */

    /// @inheritdoc IStakingPool
    function pause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO: implement
        _pause();
    }

    /// @inheritdoc IStakingPool
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO: implement
        _unpause();
    }

    /// @inheritdoc IStakingPool
    function notifyRewardAmount(
        uint256 reward
    )
        external
        override
        nonReentrant
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        updateReward(address(0))
    {
        // TODO: implement
        if (reward == 0) {
            revert RewardAmountCannotBeZero();
        }
        if (rewardsDuration == 0) {
            revert RewardsDurationCannotBeZero();
        }

        uint256 balanceBefore = IERC20(rewardToken).balanceOf(address(this));
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), reward);
        uint256 actualReward = IERC20(rewardToken).balanceOf(address(this)) -
            balanceBefore;

        if (actualReward != reward) {
            revert FeeOnTransferNotSupported();
        }

        if (block.timestamp > periodFinish) {
            rewardRate = (reward * PRECISION) / rewardsDuration;
        } else {
            uint256 remainingRewards = (rewardRate *
                (periodFinish - block.timestamp)) / PRECISION;
            rewardRate =
                ((remainingRewards + reward) * PRECISION) /
                rewardsDuration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

    /// @inheritdoc IStakingPool
    function setRewardsDuration(
        uint256 _rewardsDuration
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused {
        // TODO: implement
        if (_rewardsDuration == 0) {
            revert RewardsDurationCannotBeZero();
        }
        if (block.timestamp < periodFinish) {
            revert RewardsDurationCannotBeSetBeforeCurrentPeriodEnds();
        }
        rewardsDuration = _rewardsDuration;
        emit RewardsDurationUpdated(_rewardsDuration);
    }

    /// @inheritdoc IStakingPool
    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO: implement
        if (tokenAddress == address(0)) {
            revert AddressCannotBeZero();
        }
        if (tokenAmount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (tokenAddress == stakingToken || tokenAddress == rewardToken) {
            revert CannotRecoverStakingOrRewardTokens();
        }
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
}
