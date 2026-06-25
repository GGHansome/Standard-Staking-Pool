// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./interface.sol";
import "./types.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

/**
 * @title StakingPool
 * @notice V2 锁仓推荐质押池框架。
 * @dev 当前文件按 IStakingPoolV2 搭建存储、权限、视图和入口骨架；具体奖励结算、补贴预算、快照插值由后续开发补齐。
 */
contract StakingPool is StakingPoolTypes, IStakingPoolV2, AccessControl, Pausable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    // ---------------------------------------------------------------------
    // Constants
    // ---------------------------------------------------------------------

    /// @notice 奖励注入操作员角色。
    bytes32 public constant override OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    /// @notice 比例计算基准，10000 表示 100%。
    uint256 public constant override BPS = 10_000;

    /// @notice 单个用户最多允许保留的活跃质押仓位数量。
    uint256 public constant override MAX_ACTIVE_DEPOSITS = 50;

    /// @notice 最多允许配置的锁仓档位数量。
    uint256 public constant override MAX_LOCK_TIERS = 10;

    /// @notice 奖励累积计算精度。
    uint256 private constant PRECISION = 1e18;

    // ---------------------------------------------------------------------
    // Immutable configuration
    // ---------------------------------------------------------------------

    /// @notice 用户质押资产地址。
    address public immutable override stakingToken;

    /// @notice 奖励资产地址。
    address public immutable override rewardToken;

    /// @notice 单个奖励周期持续时间。
    uint256 public immutable rewardsDuration;

    /// @notice 当前配置下理论最大补贴比例，按 BPS 计价。
    uint256 public immutable maxSubsidyRate;

    /// @notice 部署时允许的最大补贴比例上限，按 BPS 计价。
    uint256 public immutable maxSubsidyRateCap;

    /// @notice 被邀请人自身获得的奖励加成比例，按 BPS 计价。
    uint256 public immutable inviteeBoost;

    /// @notice 一级邀请人奖励比例，按 BPS 计价。
    uint256 public immutable level1;

    /// @notice 二级邀请人奖励比例，按 BPS 计价。
    uint256 public immutable level2;

    /// @notice 三级邀请人奖励比例，按 BPS 计价。
    uint256 public immutable level3;

    /// @notice 提前退出罚金比例，按 BPS 计价。
    uint256 public immutable penaltyRate;

    // ---------------------------------------------------------------------
    // Reward and subsidy state
    // ---------------------------------------------------------------------

    /// @notice 当前池内总质押本金。
    uint256 public override totalSupply;

    /// @notice 当前奖励周期结束时间。
    uint256 public periodFinish;

    /// @notice 最近一次全局奖励状态更新时间。
    uint256 public lastUpdateTime;

    /// @notice 已存储的全局单位质押奖励。
    uint256 public rewardPerTokenStored;

    /// @notice 当前基础奖励释放速率。
    uint256 public rewardRate;

    /// @notice 当前基础奖励储备余额。
    uint256 public override baseRewardReserve;

    /// @notice 当前补贴储备余额。
    uint256 public override subsidyReserve;

    /// @notice 已经归集但尚未支付的补贴奖励总额。
    uint256 public override totalPendingSubsidy;

    /// @notice 尚未通过实际结算冲销的最大补贴负债。
    /// @dev 恒等于 floor(injectedBaseCumulative · maxSubsidyRate / BPS) - floor(settledBaseCumulative · maxSubsidyRate / BPS)。
    uint256 public override unsettledMaxSubsidyLiability;

    /// @notice 历史累计注入的基础奖励总额，单调递增。
    uint256 public injectedBaseCumulative;

    /// @notice 历史累计已消化的基础奖励总额（仓位归集 + 空池自然衰减 + 过期回收），单调递增。
    uint256 public settledBaseCumulative;

    // ---------------------------------------------------------------------
    // Pool state
    // ---------------------------------------------------------------------

    /// @notice 提前退出罚金接收金库地址。
    address public treasury;

    /// @notice 下一笔质押仓位编号。
    uint256 public nextDepositId = 1;

    /// @notice 可选锁仓期限列表。
    uint256[] private durations;

    /// @notice 与锁仓期限一一对应的加成比例列表，按 BPS 计价。
    uint256[] private boosts;

    /// @notice 全局单位质押奖励历史快照。
    RewardCheckpoint[] private rewardHistory;

    /// @notice 仓位编号到仓位记录的映射。
    mapping(uint256 => DepositRecord) private deposits;

    /// @notice 用户地址到当前活跃仓位编号列表的映射。
    mapping(address => uint256[]) private activeDepositIds;

    /// @notice 用户地址到当前质押本金总额的映射。
    mapping(address => uint256) private userTotalStaked;

    /// @notice 用户地址到直接邀请人地址的映射。
    mapping(address => address) public override inviterOf;

    /// @notice 用户地址到邀请关系选择状态的映射。
    mapping(address => bool) public override hasSetInviter;

    /// @notice 用户地址到待领取推荐奖励的映射。
    mapping(address => uint256) private referralRewards;

    /// @notice 仓位编号在用户活跃仓位列表中的索引加一。
    mapping(uint256 => uint256) private activeDepositIndexPlusOne;

    // ---------------------------------------------------------------------
    // Constructor
    // ---------------------------------------------------------------------

    /// @notice 部署质押池并初始化资产、角色、奖励周期、推荐比例、罚金比例和锁仓档位。
    /// @param params 部署所需的完整配置参数。
    constructor(ConstructorParams memory params) {
        if (
            params.stakingToken == address(0) ||
            params.rewardToken == address(0) ||
            params.admin == address(0) ||
            params.treasury == address(0)
        ) {
            revert AddressCannotBeZero();
        }
        if (params.rewardsDuration == 0) {
            revert RewardsDurationCannotBeZero();
        }
        if (params.penaltyRate > BPS) {
            revert PenaltyRateTooHigh();
        }
        if (params.durations.length != params.boosts.length) {
            revert LockTierLengthMismatch();
        }
        if (params.durations.length > MAX_LOCK_TIERS) {
            revert TooManyLockTiers();
        }

        stakingToken = params.stakingToken;
        rewardToken = params.rewardToken;
        treasury = params.treasury;
        rewardsDuration = params.rewardsDuration;
        inviteeBoost = params.inviteeBoost;
        level1 = params.level1;
        level2 = params.level2;
        level3 = params.level3;
        penaltyRate = params.penaltyRate;
        maxSubsidyRateCap = params.maxSubsidyRateCap;

        uint256 computedMaxSubsidyRate = params.inviteeBoost + params.level1 + params.level2 + params.level3;
        uint256 lockTierCount = params.durations.length;
        for (uint256 i = 0; i < lockTierCount; ++i) {
            uint256 duration = params.durations[i];
            uint256 boost = params.boosts[i];
            if (duration == 0) {
                revert InvalidLockDuration();
            }
            if (boost == 0) {
                revert LockBoostRateCannotBeZero();
            }
            for (uint256 j = 0; j < i; ++j) {
                if (params.durations[j] == duration) {
                    revert DuplicateLockDuration();
                }
            }
            durations.push(duration);
            boosts.push(boost);
            computedMaxSubsidyRate = Math.max(
                computedMaxSubsidyRate,
                params.inviteeBoost + params.level1 + params.level2 + params.level3 + boost
            );
        }
        if (computedMaxSubsidyRate > params.maxSubsidyRateCap) {
            revert MaxSubsidyRateExceeded();
        }
        maxSubsidyRate = computedMaxSubsidyRate;

        _grantRole(DEFAULT_ADMIN_ROLE, params.admin);
        if (params.operator != address(0)) {
            _grantRole(OPERATOR_ROLE, params.operator);
        }
        _setRoleAdmin(OPERATOR_ROLE, DEFAULT_ADMIN_ROLE);

        emit ActivityConfigured(
            params.rewardsDuration,
            params.inviteeBoost,
            params.level1,
            params.level2,
            params.level3,
            computedMaxSubsidyRate,
            params.maxSubsidyRateCap,
            params.penaltyRate
        );
        emit LockTiersConfigured(params.durations, params.boosts);
    }

    // ---------------------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------------------

    /// @notice 在业务操作前同步全局奖励状态，并在需要时同步指定账户的仓位奖励。
    /// @param account 需要同步仓位奖励的账户；零地址表示只同步全局状态。
    modifier updateReward(address account) {
        _updateReward(account);
        _;
    }

    /// @notice 在业务操作完成后校验本金、基础奖励和补贴储备仍被资产余额覆盖。
    modifier assertAssetCoverage() {
        _;
        _assertAssetCoverage();
    }

    // ---------------------------------------------------------------------
    // Interface and read models
    // ---------------------------------------------------------------------

    /// @notice 查询合约是否支持指定接口。
    /// @param interfaceId 接口标识。
    /// @return 是否支持该接口。
    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return interfaceId == type(IStakingPoolV2).interfaceId || super.supportsInterface(interfaceId);
    }

    /// @inheritdoc IStakingPoolV2
    function paused() public view override(IStakingPoolV2, Pausable) returns (bool) {
        return super.paused();
    }

    /// @inheritdoc IStakingPoolV2
    function getDeposit(uint256 depositId) external view override returns (DepositView memory deposit) {
        deposit = _toDepositView(deposits[depositId]);
    }

    /// @inheritdoc IStakingPoolV2
    function getActiveDepositIds(address user) external view override returns (uint256[] memory depositIds) {
        if (user == address(0)) {
            revert AddressCannotBeZero();
        }
        depositIds = activeDepositIds[user];
    }

    /// @inheritdoc IStakingPoolV2
    function getUserDeposits(address user) external view override returns (DepositView[] memory userDeposits) {
        if (user == address(0)) {
            revert AddressCannotBeZero();
        }
        uint256[] storage ids = activeDepositIds[user];
        userDeposits = new DepositView[](ids.length);
        for (uint256 i = 0; i < ids.length; ++i) {
            userDeposits[i] = _toDepositView(deposits[ids[i]]);
        }
    }

    /// @inheritdoc IStakingPoolV2
    function totalStakedOf(address user) external view override returns (uint256 amount) {
        if (user == address(0)) {
            revert AddressCannotBeZero();
        }
        amount = userTotalStaked[user];
    }

    /// @inheritdoc IStakingPoolV2
    function earned(address user) public view override returns (uint256 amount) {
        if (user == address(0)) {
            revert AddressCannotBeZero();
        }
        uint256[] storage ids = activeDepositIds[user];
        for (uint256 i = 0; i < ids.length; ++i) {
            DepositRewardView memory reward = _earnedByDeposit(deposits[ids[i]]);
            amount += reward.totalClaimable;
        }
        amount += referralRewards[user];
    }

    /// @inheritdoc IStakingPoolV2
    function earnedByDeposit(uint256 depositId) external view override returns (DepositRewardView memory reward) {
        DepositRecord storage deposit = deposits[depositId];
        if (deposit.owner == address(0)) {
            revert DepositDoesNotExist();
        }
        reward = _earnedByDeposit(deposit);
    }

    /// @inheritdoc IStakingPoolV2
    function claimableReferralReward(address user) external view override returns (uint256 amount) {
        if (user == address(0)) {
            revert AddressCannotBeZero();
        }
        amount = referralRewards[user];
    }

    /// @inheritdoc IStakingPoolV2
    function getUpline(address user) public view override returns (address, address, address) {
        if (user == address(0)) {
            revert AddressCannotBeZero();
        }
        address upline1 = inviterOf[user];
        address upline2 = inviterOf[upline1];
        address upline3 = inviterOf[upline2];
        return (upline1, upline2, upline3);
    }

    /// @inheritdoc IStakingPoolV2
    function getLockTiers() external view override returns (uint256[] memory, uint256[] memory) {
        return (durations, boosts);
    }

    /// @inheritdoc IStakingPoolV2
    function getReferralRates() external view override returns (uint256, uint256, uint256, uint256) {
        return (inviteeBoost, level1, level2, level3);
    }

    /// @inheritdoc IStakingPoolV2
    function getPenaltyConfig() external view override returns (uint256 configuredPenaltyRate, address configuredTreasury) {
        configuredPenaltyRate = penaltyRate;
        configuredTreasury = treasury;
    }

    /// @inheritdoc IStakingPoolV2
    function getSubsidyConfig() external view override returns (SubsidyConfigView memory config) {
        config = SubsidyConfigView({
            maxSubsidyRate: maxSubsidyRate,
            maxSubsidyRateCap: maxSubsidyRateCap,
            subsidyReserve: subsidyReserve,
            totalPendingSubsidy: totalPendingSubsidy,
            unsettledMaxSubsidyLiability: unsettledMaxSubsidyLiability
        });
    }

    /// @inheritdoc IStakingPoolV2
    function getRewardSchedule() external view override returns (RewardScheduleView memory schedule) {
        schedule = RewardScheduleView({
            rewardsDuration: rewardsDuration,
            periodFinish: periodFinish,
            rewardRate: rewardRate,
            lastUpdateTime: lastUpdateTime,
            rewardPerTokenStored: rewardPerTokenStored
        });
    }

    /// @inheritdoc IStakingPoolV2
    function isRewardPeriodActive() public view override returns (bool active) {
        active = rewardRate > 0 && block.timestamp < periodFinish;
    }

    /// @inheritdoc IStakingPoolV2
    function rewardPerToken() public view override returns (uint256) {
        if (totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (rewardRate * (lastTimeRewardApplicable() - lastUpdateTime)) / totalSupply;
    }

    /// @inheritdoc IStakingPoolV2
    function lastTimeRewardApplicable() public view override returns (uint256 timestamp) {
        timestamp = Math.min(block.timestamp, periodFinish);
    }

    /// @inheritdoc IStakingPoolV2
    function remainingBaseReward() public view override returns (uint256) {
        if (block.timestamp >= periodFinish) {
            return 0;
        }
        return (rewardRate * (periodFinish - block.timestamp)) / PRECISION;
    }

    /// @inheritdoc IStakingPoolV2
    function maxSweepableSubsidy() public view override returns (uint256) {
        uint256 syncedUnsettledLiability = unsettledMaxSubsidyLiability;
        uint256 applicableTime = lastTimeRewardApplicable();
        if (totalSupply == 0 && applicableTime > lastUpdateTime) {
            uint256 naturalAttritionReward = Math.mulDiv(rewardRate, applicableTime - lastUpdateTime, PRECISION);
            uint256 consumedBase = Math.min(naturalAttritionReward, baseRewardReserve);
            uint256 projectedSettled = settledBaseCumulative + consumedBase;
            syncedUnsettledLiability = _proportionalBpsReward(injectedBaseCumulative, maxSubsidyRate)
                - _proportionalBpsReward(projectedSettled, maxSubsidyRate);
        }

        uint256 liability = totalPendingSubsidy + syncedUnsettledLiability;
        if (subsidyReserve <= liability) {
            return 0;
        }
        return subsidyReserve - liability;
    }

    // ---------------------------------------------------------------------
    // User actions
    // ---------------------------------------------------------------------

    /// @inheritdoc IStakingPoolV2
    function stake(
        uint256 amount,
        uint256 lockDuration,
        address inviter
    ) external override nonReentrant whenNotPaused updateReward(msg.sender) assertAssetCoverage returns (uint256 depositId) {
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (activeDepositIds[msg.sender].length >= MAX_ACTIVE_DEPOSITS) {
            revert TooManyActiveDeposits();
        }

        uint256 boostRate = _boostRateOf(lockDuration);
        if (lockDuration > 0 && !isRewardPeriodActive()) {
            revert LockStakingNotActive();
        }
        _settleInviter(msg.sender, inviter);

        uint256 actualAmount = _pullExact(stakingToken, msg.sender, amount);
        depositId = nextDepositId++;
        uint256 unlockTime = lockDuration == 0 ? 0 : block.timestamp + lockDuration;

        deposits[depositId] = DepositRecord({
            owner: msg.sender,
            amount: actualAmount,
            unlockTime: unlockTime,
            boostRate: boostRate,
            rewardPerTokenPaid: rewardPerTokenStored,
            rewardPerTokenAtUnlock: 0,
            boostSettled: lockDuration == 0,
            pendingBaseReward: 0,
            pendingInviteeBoostReward: 0,
            pendingBoostReward: 0
        });
        activeDepositIds[msg.sender].push(depositId);
        activeDepositIndexPlusOne[depositId] = activeDepositIds[msg.sender].length;
        userTotalStaked[msg.sender] += actualAmount;
        totalSupply += actualAmount;

        _writeRewardCheckpoint();
        emit Staked(msg.sender, depositId, actualAmount, lockDuration, unlockTime, boostRate);
    }

    /// @inheritdoc IStakingPoolV2
    function claimAll() external override nonReentrant updateReward(msg.sender) assertAssetCoverage {
        _claimAll(msg.sender);
    }

    /// @inheritdoc IStakingPoolV2
    function withdraw(uint256 depositId) external override nonReentrant updateReward(msg.sender) assertAssetCoverage {
        WithdrawAccounting memory accounting = _withdrawDepositToAccounting(msg.sender, depositId);
        _writeRewardCheckpoint();
        _payWithdrawAccounting(msg.sender, accounting);
    }

    /// @inheritdoc IStakingPoolV2
    function withdrawMultiple(uint256[] calldata depositIds) external override nonReentrant updateReward(msg.sender) assertAssetCoverage {
        if (depositIds.length == 0) {
            revert EmptyDepositIds();
        }
        if (depositIds.length > MAX_ACTIVE_DEPOSITS) {
            revert TooManyDepositIds();
        }
        _validateNoDuplicates(depositIds);

        WithdrawAccounting memory accounting = WithdrawAccounting({principalReturned: 0, penaltyAmount: 0, rewardPaid: 0});
        for (uint256 i = 0; i < depositIds.length; ++i) {
            _mergeWithdrawAccounting(accounting, _withdrawDepositToAccounting(msg.sender, depositIds[i]));
        }
        _writeRewardCheckpoint();
        _payWithdrawAccounting(msg.sender, accounting);
    }

    /// @inheritdoc IStakingPoolV2
    function exit() external override nonReentrant updateReward(msg.sender) assertAssetCoverage {
        uint256[] memory ids = activeDepositIds[msg.sender];
        WithdrawAccounting memory accounting = WithdrawAccounting({principalReturned: 0, penaltyAmount: 0, rewardPaid: 0});
        for (uint256 i = 0; i < ids.length; ++i) {
            _mergeWithdrawAccounting(accounting, _withdrawDepositToAccounting(msg.sender, ids[i]));
        }
        accounting.rewardPaid += _claimReferralReward(msg.sender);
        if (ids.length > 0) {
            _writeRewardCheckpoint();
        }
        _payWithdrawAccounting(msg.sender, accounting);
    }

    // ---------------------------------------------------------------------
    // Operator actions
    // ---------------------------------------------------------------------

    /// @inheritdoc IStakingPoolV2
    function notifyRewardAmount(
        uint256 baseRewardAmount
    ) external override nonReentrant onlyRole(OPERATOR_ROLE) whenNotPaused updateReward(address(0)) assertAssetCoverage {
        if (baseRewardAmount == 0) {
            revert RewardAmountCannotBeZero();
        }
        uint256 actualBaseReward = _pullExact(rewardToken, msg.sender, baseRewardAmount);
        uint256 prevInjectedBudget = _proportionalBpsReward(injectedBaseCumulative, maxSubsidyRate);
        injectedBaseCumulative += actualBaseReward;
        uint256 requiredSubsidy = _proportionalBpsReward(injectedBaseCumulative, maxSubsidyRate) - prevInjectedBudget;
        uint256 sweepable = maxSweepableSubsidy();
        uint256 subsidyCharged = 0;
        if (requiredSubsidy > sweepable) {
            subsidyCharged = requiredSubsidy - sweepable;
            _pullExact(rewardToken, msg.sender, subsidyCharged);
            subsidyReserve += subsidyCharged;
            emit SubsidyReserved(subsidyCharged);
        }

        uint256 nextRewardRate;
        if (block.timestamp >= periodFinish) {
            nextRewardRate = Math.mulDiv(actualBaseReward, PRECISION, rewardsDuration);
        } else {
            uint256 leftoverBaseReward = remainingBaseReward();
            nextRewardRate = Math.mulDiv(actualBaseReward + leftoverBaseReward, PRECISION, rewardsDuration);
        }
        if (nextRewardRate == 0) {
            revert RewardAmountTooSmall();
        }

        baseRewardReserve += actualBaseReward;
        _syncUnsettledMaxSubsidyLiability();

        rewardRate = nextRewardRate;
        lastUpdateTime = block.timestamp;
        periodFinish = block.timestamp + rewardsDuration;

        _writeRewardCheckpoint();
        emit RewardAdded(actualBaseReward, requiredSubsidy, subsidyCharged);
    }

    // ---------------------------------------------------------------------
    // Admin actions
    // ---------------------------------------------------------------------

    /// @inheritdoc IStakingPoolV2
    function setTreasury(address newTreasury) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newTreasury == address(0)) {
            revert AddressCannotBeZero();
        }
        treasury = newTreasury;
        emit TreasuryUpdated(newTreasury);
    }

    /// @inheritdoc IStakingPoolV2
    function sweepSubsidy(
        address to,
        uint256 amount
    ) external override nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused updateReward(address(0)) assertAssetCoverage {
        if (to == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (amount > maxSweepableSubsidy()) {
            revert InsufficientSweepableSubsidy();
        }
        subsidyReserve -= amount;
        IERC20(rewardToken).safeTransfer(to, amount);
        emit SubsidySwept(to, amount);
    }

    /// @inheritdoc IStakingPoolV2
    function sweepExpiredBaseReward(
        address to
    ) external override nonReentrant onlyRole(DEFAULT_ADMIN_ROLE) whenNotPaused updateReward(address(0)) assertAssetCoverage {
        if (to == address(0)) {
            revert AddressCannotBeZero();
        }
        if (block.timestamp < periodFinish) {
            revert RewardPeriodStillActive();
        }
        if (totalSupply != 0) {
            revert ActiveStakesExist();
        }

        uint256 amount = baseRewardReserve;
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }

        baseRewardReserve = 0;
        settledBaseCumulative += amount;
        _syncUnsettledMaxSubsidyLiability();
        IERC20(rewardToken).safeTransfer(to, amount);
        emit ExpiredBaseRewardSwept(to, amount);
    }

    /// @inheritdoc IStakingPoolV2
    function pause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    /// @inheritdoc IStakingPoolV2
    function unpause() external override onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    /// @inheritdoc IStakingPoolV2
    function recoverERC20(address token, uint256 amount) external override onlyRole(DEFAULT_ADMIN_ROLE) {
        if (token == address(0)) {
            revert AddressCannotBeZero();
        }
        if (amount == 0) {
            revert AmountMustBeGreaterThanZero();
        }
        if (token == stakingToken || token == rewardToken) {
            revert CannotRecoverCoreToken();
        }
        IERC20(token).safeTransfer(msg.sender, amount);
        emit Recovered(token, amount);
    }

    // ---------------------------------------------------------------------
    // Reward settlement
    // ---------------------------------------------------------------------

    /// @notice 同步全局奖励状态，并在指定账户非零时归集其所有活跃仓位奖励。
    /// @param account 需要同步仓位奖励的账户；零地址表示只同步全局状态。
    function _updateReward(address account) internal {
        uint256 applicableTime = lastTimeRewardApplicable();
        if (totalSupply == 0 && applicableTime > lastUpdateTime) {
            uint256 naturalAttritionReward = Math.mulDiv(rewardRate, applicableTime - lastUpdateTime, PRECISION);
            uint256 consumedBase = Math.min(naturalAttritionReward, baseRewardReserve);
            baseRewardReserve -= consumedBase;
            if (consumedBase > 0) {
                settledBaseCumulative += consumedBase;
                _syncUnsettledMaxSubsidyLiability();
            }
        }

        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = applicableTime;

        if (account == address(0)) {
            return;
        }

        uint256[] storage ids = activeDepositIds[account];
        for (uint256 i = 0; i < ids.length; ++i) {
            _accrueDepositReward(deposits[ids[i]], ids[i]);
        }
    }

    /// @notice 领取用户所有活跃仓位奖励和推荐奖励。
    /// @param user 领取奖励的用户地址。
    function _claimAll(address user) internal {
        uint256 totalPaid = 0;

        uint256[] storage ids = activeDepositIds[user];
        for (uint256 i = 0; i < ids.length; ++i) {
            uint256 depositId = ids[i];
            totalPaid += _claimDepositReward(user, depositId, deposits[depositId]);
        }

        totalPaid += _claimReferralReward(user);
        if (totalPaid > 0) {
            IERC20(rewardToken).safeTransfer(user, totalPaid);
            emit RewardPaid(user, totalPaid);
        }
    }

    /// @notice 领取单笔仓位中当前可支付的基础奖励、被邀请人加成和锁仓加成。
    /// @param user 领取奖励的用户地址。
    /// @param depositId 仓位编号。
    /// @param deposit 仓位内部记录。
    /// @return paid 本次实际支付的奖励总额。
    function _claimDepositReward(
        address user,
        uint256 depositId,
        DepositRecord storage deposit
    ) internal returns (uint256 paid) {
        uint256 depositBasePaid = deposit.pendingBaseReward;
        if (depositBasePaid > 0) {
            deposit.pendingBaseReward = 0;
            baseRewardReserve -= depositBasePaid;
            emit BaseRewardPaid(user, depositId, depositBasePaid);
            paid += depositBasePaid;
        }

        uint256 depositInviteeBoostPaid = deposit.pendingInviteeBoostReward;
        if (depositInviteeBoostPaid > 0) {
            deposit.pendingInviteeBoostReward = 0;
            subsidyReserve -= depositInviteeBoostPaid;
            totalPendingSubsidy -= depositInviteeBoostPaid;
            emit InviteeBoostRewardPaid(user, depositId, depositInviteeBoostPaid);
            paid += depositInviteeBoostPaid;
        }

        if (deposit.pendingBoostReward > 0 && deposit.boostSettled) {
            uint256 depositBoostPaid = deposit.pendingBoostReward;
            deposit.pendingBoostReward = 0;
            subsidyReserve -= depositBoostPaid;
            totalPendingSubsidy -= depositBoostPaid;
            emit LockBoostRewardPaid(user, depositId, depositBoostPaid);
            paid += depositBoostPaid;
        }
    }

    /// @notice 领取用户当前待领取推荐奖励。
    /// @param user 领取推荐奖励的用户地址。
    /// @return paid 本次实际支付的推荐奖励数量。
    function _claimReferralReward(address user) internal returns (uint256 paid) {
        paid = referralRewards[user];
        if (paid == 0) {
            return 0;
        }

        referralRewards[user] = 0;
        subsidyReserve -= paid;
        totalPendingSubsidy -= paid;
        emit ReferralRewardPaid(user, paid);
    }

    // ---------------------------------------------------------------------
    // Withdrawal accounting
    // ---------------------------------------------------------------------

    /// @notice 关闭单笔仓位并生成退出支付记账结果。
    /// @param user 发起退出的用户地址。
    /// @param depositId 仓位编号。
    /// @return accounting 本次退出产生的本金、罚金和奖励支付结果。
    function _withdrawDepositToAccounting(
        address user,
        uint256 depositId
    ) internal returns (WithdrawAccounting memory accounting) {
        DepositRecord storage deposit = deposits[depositId];
        if (deposit.owner == address(0)) {
            revert DepositDoesNotExist();
        }
        if (deposit.owner != user) {
            revert NotDepositOwner();
        }
        if (deposit.amount == 0) {
            revert DepositAlreadyClosed();
        }

        uint256 principal = deposit.amount;
        uint256 forfeitedBoostReward = 0;

        deposit.amount = 0;
        userTotalStaked[user] -= principal;
        totalSupply -= principal;

        if (deposit.unlockTime > block.timestamp) {
            accounting.penaltyAmount = (principal * penaltyRate) / BPS;
            accounting.principalReturned = principal - accounting.penaltyAmount;
            forfeitedBoostReward = deposit.pendingBoostReward;
            if (forfeitedBoostReward > 0) {
                deposit.pendingBoostReward = 0;
                totalPendingSubsidy -= forfeitedBoostReward;
                emit LockBoostRewardForfeited(user, depositId, forfeitedBoostReward);
            }
            emit EarlyWithdrawn(user, depositId, accounting.principalReturned, accounting.penaltyAmount, forfeitedBoostReward);
        } else {
            accounting.principalReturned = principal;
            emit Withdrawn(user, depositId, accounting.principalReturned);
        }

        accounting.rewardPaid = _claimDepositReward(user, depositId, deposit);

        _removeActiveDeposit(user, depositId);

        if (accounting.penaltyAmount > 0) {
            emit PenaltyPaid(user, depositId, treasury, accounting.penaltyAmount);
        }
        emit DepositClosed(user, depositId);
    }

    /// @notice 将一笔退出记账结果合并到汇总结果中。
    /// @param target 汇总目标。
    /// @param source 待合并的单笔结果。
    function _mergeWithdrawAccounting(
        WithdrawAccounting memory target,
        WithdrawAccounting memory source
    ) internal pure {
        target.principalReturned += source.principalReturned;
        target.penaltyAmount += source.penaltyAmount;
        target.rewardPaid += source.rewardPaid;
    }

    /// @notice 按退出记账结果向用户和金库完成资产支付。
    /// @param user 退出用户地址。
    /// @param accounting 已汇总的退出支付结果。
    function _payWithdrawAccounting(address user, WithdrawAccounting memory accounting) internal {
        if (accounting.principalReturned > 0) {
            IERC20(stakingToken).safeTransfer(user, accounting.principalReturned);
        }
        if (accounting.penaltyAmount > 0) {
            IERC20(stakingToken).safeTransfer(treasury, accounting.penaltyAmount);
        }
        if (accounting.rewardPaid > 0) {
            IERC20(rewardToken).safeTransfer(user, accounting.rewardPaid);
            emit RewardPaid(user, accounting.rewardPaid);
        }
    }

    // ---------------------------------------------------------------------
    // Reward accrual
    // ---------------------------------------------------------------------

    /// @notice 将单笔仓位从上次结算点到当前全局结算点之间的奖励归集到待领取余额。
    /// @param deposit 仓位内部记录。
    /// @param depositId 仓位编号。
    function _accrueDepositReward(DepositRecord storage deposit, uint256 depositId) internal {
        if (deposit.amount == 0) {
            return;
        }

        uint256 depositRewardPerTokenPaid = deposit.rewardPerTokenPaid;
        uint256 baseReward = Math.mulDiv(deposit.amount,rewardPerTokenStored - depositRewardPerTokenPaid,PRECISION);
        uint256 boostReward = _accrueLockBoostReward(deposit, baseReward, depositRewardPerTokenPaid);

        if (baseReward == 0) {
            if (boostReward > 0) {
                totalPendingSubsidy += boostReward;
                emit LockBoostRewardAccrued(deposit.owner, depositId, boostReward);
            }
            return;
        }

        uint256 inviteeBoostReward = 0;
        if (hasSetInviter[deposit.owner] && inviterOf[deposit.owner] != address(0)) {
            inviteeBoostReward = _proportionalBpsReward(baseReward, inviteeBoost);
        }
        uint256 referralReward = _accrueReferralRewards(deposit.owner, depositId, baseReward);
        uint256 subsidyReward = inviteeBoostReward + referralReward + boostReward;

        deposit.pendingBaseReward += baseReward;
        deposit.rewardPerTokenPaid = rewardPerTokenStored;
        deposit.pendingInviteeBoostReward += inviteeBoostReward;

        totalPendingSubsidy += subsidyReward;

        settledBaseCumulative += baseReward;
        _syncUnsettledMaxSubsidyLiability();

        if (inviteeBoostReward > 0) {
            emit InviteeBoostRewardAccrued(deposit.owner, depositId, inviteeBoostReward);
        }
        if (boostReward > 0) {
            emit LockBoostRewardAccrued(deposit.owner, depositId, boostReward);
        }
        emit BaseRewardAccrued(deposit.owner, depositId, baseReward);
    }

    // ---------------------------------------------------------------------
    // Referral accrual
    // ---------------------------------------------------------------------

    /// @notice 根据用户的三级上级关系归集推荐奖励。
    /// @param user 产生奖励来源的用户地址。
    /// @param sourceDepositId 产生奖励来源的质押仓位编号。
    /// @param baseReward 本次基础奖励数量。
    /// @return referralSubsidyReward 本次归集到推荐体系的补贴奖励总额。
    function _accrueReferralRewards(
        address user,
        uint256 sourceDepositId,
        uint256 baseReward
    ) internal returns (uint256 referralSubsidyReward) {
        address uplineLevel1 = inviterOf[user];
        if (uplineLevel1 == address(0) || level1 == 0) {
            return 0;
        }

        uint256 referralReward = _proportionalBpsReward(baseReward, level1);
        referralRewards[uplineLevel1] += referralReward;
        referralSubsidyReward += referralReward;
        if (referralReward > 0) {
            emit ReferralRewardAccrued(uplineLevel1, user, 1, sourceDepositId, referralReward);
        }

        address uplineLevel2 = inviterOf[uplineLevel1];
        if (uplineLevel2 == address(0) || level2 == 0) {
            return referralSubsidyReward;
        }

        referralReward = _proportionalBpsReward(baseReward, level2);
        referralRewards[uplineLevel2] += referralReward;
        referralSubsidyReward += referralReward;
        if (referralReward > 0) {
            emit ReferralRewardAccrued(uplineLevel2, user, 2, sourceDepositId, referralReward);
        }

        address uplineLevel3 = inviterOf[uplineLevel2];
        if (uplineLevel3 == address(0) || level3 == 0) {
            return referralSubsidyReward;
        }

        referralReward = _proportionalBpsReward(baseReward, level3);
        referralRewards[uplineLevel3] += referralReward;
        referralSubsidyReward += referralReward;
        if (referralReward > 0) {
            emit ReferralRewardAccrued(uplineLevel3, user, 3, sourceDepositId, referralReward);
        }
    }

    // ---------------------------------------------------------------------
    // Lock boost accrual
    // ---------------------------------------------------------------------

    /// @notice 归集锁仓加成奖励，并在锁仓到期后以到期点快照完成加成封顶。
    /// @param deposit 仓位内部记录。
    /// @param baseReward 本次基础奖励数量。
    /// @param depositRewardPerTokenPaid 仓位本次归集前记录的单位质押奖励。
    /// @return boostReward 本次归集的锁仓加成奖励数量。
    function _accrueLockBoostReward(
        DepositRecord storage deposit,
        uint256 baseReward,
        uint256 depositRewardPerTokenPaid
    ) internal returns (uint256 boostReward) {
        if (deposit.boostRate == 0 || deposit.boostSettled) {
            return 0;
        }

        if (block.timestamp >= deposit.unlockTime) {
            uint256 rewardPerTokenAtUnlock = _rewardPerTokenAt(deposit.unlockTime);
            deposit.rewardPerTokenAtUnlock = rewardPerTokenAtUnlock;
            deposit.boostSettled = true;
            if (rewardPerTokenAtUnlock > depositRewardPerTokenPaid) {
                uint256 boostBaseReward = Math.mulDiv(
                    deposit.amount,
                    rewardPerTokenAtUnlock - depositRewardPerTokenPaid,
                    PRECISION
                );
                boostReward = _proportionalBpsReward(boostBaseReward, deposit.boostRate);
            }
        } else {
            boostReward = _proportionalBpsReward(baseReward, deposit.boostRate);
        }

        deposit.pendingBoostReward += boostReward;
    }

    // ---------------------------------------------------------------------
    // Referral binding
    // ---------------------------------------------------------------------

    /// @notice 在用户首次质押时确定邀请关系或记录无邀请人选择。
    /// @param user 被绑定邀请关系的用户地址。
    /// @param inviter 用户提交的邀请人地址。
    function _settleInviter(address user, address inviter) internal {
        if (!_isReferralEnabled()) {
            return;
        }
        if (hasSetInviter[user]) {
            return;
        }
        hasSetInviter[user] = true;
        if (inviter == address(0)) {
            emit NoInviterSet(user);
            return;
        }
        if (inviter == user || !hasSetInviter[inviter]) {
            revert InvalidInviter();
        }
        (address upline1, address upline2, address upline3) = getUpline(inviter);
        if (upline1 == user || upline2 == user || upline3 == user) {
            revert ReferralCycleDetected();
        }
        inviterOf[user] = inviter;
        emit InviterBound(user, inviter);
    }

    /// @notice 查询推荐模块是否启用。
    /// @return enabled 任意推荐费率非零时视为启用。
    function _isReferralEnabled() internal view returns (bool enabled) {
        enabled = inviteeBoost != 0 || level1 != 0 || level2 != 0 || level3 != 0;
    }

    // ---------------------------------------------------------------------
    // Lock tier and reward checkpoints
    // ---------------------------------------------------------------------

    /// @notice 查询指定锁仓期限对应的加成比例。
    /// @param lockDuration 锁仓期限；为 0 表示非锁仓。
    /// @return 对应的锁仓加成比例，按 BPS 计价。
    function _boostRateOf(uint256 lockDuration) internal view returns (uint256) {
        if (lockDuration == 0) {
            return 0;
        }
        uint256 durationCount = durations.length;
        for (uint256 i = 0; i < durationCount; ++i) {
            if (durations[i] == lockDuration) {
                return boosts[i];
            }
        }
        revert InvalidLockDuration();
    }

    /// @notice 查询或插值得到指定时间点的全局单位质押奖励。
    /// @param targetTime 目标时间点。
    /// @return 目标时间点对应的单位质押奖励。
    function _rewardPerTokenAt(uint256 targetTime) internal view returns (uint256) {
        uint256 length = rewardHistory.length;
        if (length == 0) {
            return rewardPerTokenStored;
        }

        RewardCheckpoint storage first = rewardHistory[0];
        if (targetTime <= first.time) {
            return first.rewardPerToken;
        }

        uint256 cp1Time;
        uint256 cp1Reward;
        uint256 cp1PeriodFinish;
        uint256 cp2Time;
        uint256 cp2Reward;

        RewardCheckpoint storage last = rewardHistory[length - 1];
        if (targetTime >= last.time) {
            cp2Time = lastTimeRewardApplicable();
            uint256 currentRewardPerToken = rewardPerToken();
            if (targetTime >= cp2Time) {
                return currentRewardPerToken;
            }
            cp1Time = last.time;
            cp1Reward = last.rewardPerToken;
            cp1PeriodFinish = last.periodFinish;
            cp2Reward = currentRewardPerToken;
        } else {
            uint256 low = 0;
            uint256 high = length - 1;
            while (low < high) {
                uint256 mid = (low + high + 1) / 2;
                if (rewardHistory[mid].time <= targetTime) {
                    low = mid;
                } else {
                    high = mid - 1;
                }
            }

            RewardCheckpoint storage cp1 = rewardHistory[low];
            if (targetTime == cp1.time) {
                return cp1.rewardPerToken;
            }
            RewardCheckpoint storage cp2 = rewardHistory[low + 1];
            cp1Time = cp1.time;
            cp1Reward = cp1.rewardPerToken;
            cp1PeriodFinish = cp1.periodFinish;
            cp2Time = cp2.time;
            cp2Reward = cp2.rewardPerToken;
        }

        uint256 effectiveUnlockTime = Math.min(targetTime, cp1PeriodFinish);
        uint256 effectiveCp2Time = Math.min(cp2Time, cp1PeriodFinish);
        if (effectiveCp2Time <= cp1Time) {
            return cp1Reward;
        }
        return cp1Reward
            + ((cp2Reward - cp1Reward) * (effectiveUnlockTime - cp1Time)) / (effectiveCp2Time - cp1Time);
    }

    // ---------------------------------------------------------------------
    // Internal view helpers
    // ---------------------------------------------------------------------

    /// @notice 计算单笔仓位当前奖励拆分视图。
    /// @param deposit 仓位内部记录。
    /// @return reward 仓位奖励视图。
    function _earnedByDeposit(DepositRecord storage deposit) internal view returns (DepositRewardView memory reward) {
        uint256 currentRewardPerToken = rewardPerToken();
        uint256 baseRewardDelta = 0;
        if (deposit.amount > 0 && currentRewardPerToken > deposit.rewardPerTokenPaid) {
            baseRewardDelta = Math.mulDiv(deposit.amount, currentRewardPerToken - deposit.rewardPerTokenPaid, PRECISION);
        }

        uint256 baseReward = deposit.pendingBaseReward + baseRewardDelta;
        uint256 inviteeBoostReward = deposit.pendingInviteeBoostReward;
        if (baseRewardDelta > 0 && hasSetInviter[deposit.owner] && inviterOf[deposit.owner] != address(0)) {
            inviteeBoostReward += _proportionalBpsReward(baseRewardDelta, inviteeBoost);
        }

        (uint256 pendingBoostReward, uint256 claimableBoost, bool boostClaimable) =
            _boostRewardView(deposit);

        reward = DepositRewardView({
            baseReward: baseReward,
            inviteeBoostReward: inviteeBoostReward,
            pendingBoostReward: pendingBoostReward,
            claimableBoostReward: claimableBoost,
            totalClaimable: baseReward + inviteeBoostReward + claimableBoost,
            boostClaimable: boostClaimable,
            boostForfeitable: deposit.boostRate > 0 && deposit.amount > 0 && deposit.unlockTime > block.timestamp
        });
    }

    /// @notice 计算单笔仓位只读上下文中的锁仓加成展示值。
    /// @param deposit 仓位内部记录。
    /// @return pendingBoostReward 已落盘和本次虚拟计算合并后的锁仓加成奖励。
    /// @return claimableBoostReward 当前可领取的锁仓加成奖励。
    /// @return boostClaimable 当前是否存在可领取锁仓加成奖励。
    function _boostRewardView(
        DepositRecord storage deposit
    ) internal view returns (uint256 pendingBoostReward, uint256 claimableBoostReward, bool boostClaimable) {
        pendingBoostReward = deposit.pendingBoostReward;
        if (deposit.boostRate == 0) {
            return (pendingBoostReward, 0, false);
        }

        if (deposit.boostSettled) {
            boostClaimable = pendingBoostReward > 0;
            claimableBoostReward = boostClaimable ? pendingBoostReward : 0;
            return (pendingBoostReward, claimableBoostReward, boostClaimable);
        }

        if (deposit.amount == 0) {
            return (pendingBoostReward, 0, false);
        }

        uint256 boostRewardPerToken = rewardPerToken();
        bool mature = deposit.unlockTime != 0 && block.timestamp >= deposit.unlockTime;
        if (mature) {
            boostRewardPerToken = _rewardPerTokenAt(deposit.unlockTime);
        }

        if (boostRewardPerToken > deposit.rewardPerTokenPaid) {
            uint256 boostBaseReward = Math.mulDiv(
                deposit.amount,
                boostRewardPerToken - deposit.rewardPerTokenPaid,
                PRECISION
            );
            pendingBoostReward += _proportionalBpsReward(boostBaseReward, deposit.boostRate);
        }

        if (mature) {
            boostClaimable = pendingBoostReward > 0;
            claimableBoostReward = pendingBoostReward;
        }
    }

    /// @notice 将内部仓位记录转换为对外视图。
    /// @param deposit 仓位内部记录。
    /// @return viewData 仓位视图数据。
    function _toDepositView(DepositRecord storage deposit) internal view returns (DepositView memory viewData) {
        viewData = DepositView({
            owner: deposit.owner,
            amount: deposit.amount,
            unlockTime: deposit.unlockTime,
            boostRate: deposit.boostRate,
            rewardPerTokenPaid: deposit.rewardPerTokenPaid,
            rewardPerTokenAtUnlock: deposit.rewardPerTokenAtUnlock,
            boostSettled: deposit.boostSettled,
            pendingBaseReward: deposit.pendingBaseReward,
            pendingInviteeBoostReward: deposit.pendingInviteeBoostReward,
            pendingBoostReward: deposit.pendingBoostReward
        });
    }

    /// @notice 写入当前全局单位质押奖励快照，同一时间戳内重复写入时覆盖最后一条。
    function _writeRewardCheckpoint() internal {
        RewardCheckpoint memory checkpoint = RewardCheckpoint({
            time: block.timestamp,
            rewardPerToken: rewardPerTokenStored,
            periodFinish: periodFinish
        });

        uint256 index = rewardHistory.length;
        bool replaced = false;
        if (index > 0 && rewardHistory[index - 1].time == block.timestamp) {
            index -= 1;
            rewardHistory[index] = checkpoint;
            replaced = true;
        } else {
            rewardHistory.push(checkpoint);
        }

        emit RewardCheckpointWritten(block.timestamp, rewardPerTokenStored, periodFinish, index, replaced);
    }

    // ---------------------------------------------------------------------
    // Reward math helpers
    // ---------------------------------------------------------------------

    /// @notice 计算按 BPS 比例折算的奖励数量。
    /// @param amount 基础数量。
    /// @param bps BPS 比例。
    /// @return reward 折算后的奖励数量。
    function _proportionalBpsReward(uint256 amount, uint256 bps) internal pure returns (uint256 reward) {
        reward = Math.mulDiv(amount, bps, BPS);
    }

    /// @notice 依据注入与已消化的基础奖励累计量重算最大补贴负债。
    /// @dev floor 仅作用于累计量，避免逐笔结算的 floor 尾差累积成无法释放的幽灵负债。
    function _syncUnsettledMaxSubsidyLiability() internal {
        uint256 newLiability = _proportionalBpsReward(injectedBaseCumulative, maxSubsidyRate)
            - _proportionalBpsReward(settledBaseCumulative, maxSubsidyRate);
        if (newLiability != unsettledMaxSubsidyLiability) {
            unsettledMaxSubsidyLiability = newLiability;
            emit UnsettledMaxSubsidyLiabilityUpdated(newLiability);
        }
    }

    // ---------------------------------------------------------------------
    // Token transfers and asset coverage
    // ---------------------------------------------------------------------

    /// @notice 从指定地址拉取精确数量的 ERC20，拒绝到账数量与请求数量不一致的资产。
    /// @param token ERC20 资产地址。
    /// @param from 付款地址。
    /// @param amount 请求拉取数量。
    /// @return actualAmount 实际到账数量。
    function _pullExact(address token, address from, uint256 amount) internal returns (uint256 actualAmount) {
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransferFrom(from, address(this), amount);
        actualAmount = IERC20(token).balanceOf(address(this)) - balanceBefore;
        if (actualAmount != amount) {
            revert FeeOnTransferNotSupported();
        }
    }

    /// @notice 校验合约资产余额足以覆盖当前本金、基础奖励、补贴储备和最大补贴负债要求。
    function _assertAssetCoverage() internal view {
        if (subsidyReserve < totalPendingSubsidy + unsettledMaxSubsidyLiability) {
            revert InsufficientSubsidyReserve();
        }

        uint256 requiredRewardBalance = baseRewardReserve + subsidyReserve;
        if (stakingToken == rewardToken) {
            uint256 requiredBalance = totalSupply + requiredRewardBalance;
            if (IERC20(stakingToken).balanceOf(address(this)) < requiredBalance) {
                revert InsufficientAssetCoverage();
            }
            return;
        }

        if (IERC20(stakingToken).balanceOf(address(this)) < totalSupply) {
            revert InsufficientAssetCoverage();
        }
        if (IERC20(rewardToken).balanceOf(address(this)) < requiredRewardBalance) {
            revert InsufficientAssetCoverage();
        }
    }

    // ---------------------------------------------------------------------
    // Active deposit list helpers
    // ---------------------------------------------------------------------

    /// @notice 从用户活跃仓位列表中移除指定仓位。
    /// @param user 仓位所有者地址。
    /// @param depositId 需要移除的仓位编号。
    function _removeActiveDeposit(address user, uint256 depositId) internal {
        uint256 indexPlusOne = activeDepositIndexPlusOne[depositId];
        if (indexPlusOne == 0) {
            return;
        }
        uint256 index = indexPlusOne - 1;
        uint256[] storage ids = activeDepositIds[user];
        uint256 lastId = ids[ids.length - 1];
        ids[index] = lastId;
        activeDepositIndexPlusOne[lastId] = index + 1;
        ids.pop();
        delete activeDepositIndexPlusOne[depositId];
    }

    /// @notice 校验仓位编号列表不存在重复项。
    /// @param depositIds 待校验的仓位编号列表。
    function _validateNoDuplicates(uint256[] calldata depositIds) internal pure {
        for (uint256 i = 0; i < depositIds.length; ++i) {
            for (uint256 j = i + 1; j < depositIds.length; ++j) {
                if (depositIds[i] == depositIds[j]) {
                    revert DuplicateDepositId();
                }
            }
        }
    }
}