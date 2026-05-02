// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interface.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract StakingPool is IStakingPool, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct UserInfo {
        uint256 balance; // 用户的质押本金
        uint256 userRewardPerTokenPaid; // 用户上次操作时的全局水位线
        uint256 rewards; // 已结算但尚未领取的收益
    }

    address public immutable stakingToken;
    address public immutable rewardToken;
    uint256 public periodFinish;
    uint256 public lastUpdateTime;
    uint256 public rewardsDuration;
    uint256 public rewardPerTokenStored;
    uint256 public rewardRate;
    uint256 public totalSupply;
    mapping(address => UserInfo) public userInfo;
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
    uint256 private constant PRECISION = 1e18;

    constructor(
        address _stakingToken,
        address _rewardToken,
        address _admin,
        address _operator
    ) {
        if (
            _stakingToken == address(0) ||
            _rewardToken == address(0) ||
            _admin == address(0) ||
            _operator == address(0)
        ) {
            revert AddressCannotBeZero();
        }
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(OPERATOR_ROLE, _operator);
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);
    }

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

    function paused()
        public
        view
        override(IStakingPool, Pausable)
        returns (bool)
    {
        // TODO: implement
        return super.paused();
    }

    function balanceOf(
        address account
    ) external view override returns (uint256) {
        // TODO: implement
        if (account == address(0)) {
            revert AddressCannotBeZero();
        }
        return userInfo[account].balance;
    }

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

    function lastTimeRewardApplicable() public view override returns (uint256) {
        // TODO: implement
        return Math.min(block.timestamp, periodFinish);
    }

    /* ============ 用户操作函数 (User Mutative Functions) ============ */

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

        userInfo[msg.sender].balance += actualAmount;
        totalSupply += actualAmount;
        emit Staked(msg.sender, actualAmount);
    }

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

    function exit() external override {
        // TODO: implement
        if (userInfo[msg.sender].balance > 0) {
            withdraw(userInfo[msg.sender].balance);
        }
        getReward();
    }

    /* ============ 管理员/运营操作 (Admin/Operator Functions) ============ */

    function pause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO: implement
        _pause();
    }

    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO: implement
        _unpause();
    }

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
        IERC20(rewardToken).safeTransferFrom(msg.sender, address(this), reward);
        if (block.timestamp > periodFinish) {
            rewardRate = (reward * PRECISION) / rewardsDuration;
        } else {
            uint256 remainingRewards = (rewardRate *
                (periodFinish - block.timestamp)) / PRECISION;
            rewardRate = ((remainingRewards + reward) * PRECISION) / rewardsDuration;
        }
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;
        emit RewardAdded(reward);
    }

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

    function recoverERC20(
        address tokenAddress,
        uint256 tokenAmount
    ) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        // TODO: implement
        if (tokenAddress == address(0) || tokenAmount == 0) {
            revert AddressCannotBeZero();
        }
        if (tokenAddress == stakingToken || tokenAddress == rewardToken) {
            revert CannotRecoverStakingOrRewardTokens();
        }
        IERC20(tokenAddress).safeTransfer(msg.sender, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }
}
