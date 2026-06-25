// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/StdInvariant.sol";
import "./staking.base.t.sol";

contract V2StakingInvariantHandler is Test {
    StakingPool internal pool;
    MockERC20 internal stakingToken;
    MockERC20 internal rewardToken;
    MockERC20 internal otherToken;

    address internal admin;
    address internal operator;
    address[] internal actors;
    uint256[] internal allDepositIds;

    uint256 internal highestObservedRewardPerToken;
    bool internal unsettledLiabilityChangeStayedInAllowedScope = true;
    bool internal rewardPerTokenStayedMonotonic = true;

    struct ActionSnapshot {
        uint256 unsettledMaxSubsidyLiability;
        uint256 rewardPerToken;
        uint256 totalSupply;
        uint256 lastUpdateTime;
        uint256 lastTimeRewardApplicable;
    }

    uint256 internal constant SHORT_LOCK = 30 days;
    uint256 internal constant LONG_LOCK = 90 days;

    constructor(
        StakingPool pool_,
        MockERC20 stakingToken_,
        MockERC20 rewardToken_,
        MockERC20 otherToken_,
        address admin_,
        address operator_,
        address[] memory actors_
    ) {
        pool = pool_;
        stakingToken = stakingToken_;
        rewardToken = rewardToken_;
        otherToken = otherToken_;
        admin = admin_;
        operator = operator_;
        actors = actors_;
        highestObservedRewardPerToken = pool_.rewardPerToken();
    }

    function stake(uint256 actorSeed, uint256 amountSeed, uint256 lockSeed, uint256 inviterSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, 1 wei, 1_000 ether);
        uint256 lockDuration = _lockDuration(lockSeed);
        address inviter = _inviter(actor, inviterSeed);

        vm.prank(actor);
        try pool.stake(amount, lockDuration, inviter) returns (uint256 depositId) {
            allDepositIds.push(depositId);
        } catch {}
        _afterAction(snapshot, false, true);
    }

    function claim(uint256 actorSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        vm.prank(_actor(actorSeed));
        try pool.claimAll() {} catch {}
        _afterAction(snapshot, false, true);
    }

    function withdraw(uint256 actorSeed, uint256 activeSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        address actor = _actor(actorSeed);
        uint256[] memory activeIds = pool.getActiveDepositIds(actor);
        if (activeIds.length == 0) {
            _afterAction(snapshot, false, false);
            return;
        }

        uint256 depositId = activeIds[bound(activeSeed, 0, activeIds.length - 1)];
        vm.prank(actor);
        try pool.withdraw(depositId) {} catch {}
        _afterAction(snapshot, false, true);
    }

    function exit(uint256 actorSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        vm.prank(_actor(actorSeed));
        try pool.exit() {} catch {}
        _afterAction(snapshot, false, true);
    }

    function notifyRewardAmount(uint256 amountSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        uint256 amount = bound(amountSeed, 1 wei, 10_000 ether);
        vm.prank(operator);
        try pool.notifyRewardAmount(amount) {} catch {}
        _afterAction(snapshot, true, true);
    }

    function sweepSubsidy(uint256 amountSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        uint256 sweepable = pool.maxSweepableSubsidy();
        if (sweepable == 0) {
            _afterAction(snapshot, false, false);
            return;
        }

        uint256 amount = bound(amountSeed, 1 wei, sweepable);
        vm.prank(admin);
        try pool.sweepSubsidy(admin, amount) {} catch {}
        _afterAction(snapshot, false, false);
    }

    function recoverOtherToken(uint256 amountSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        uint256 recoverable = otherToken.balanceOf(address(pool));
        if (recoverable == 0) {
            _afterAction(snapshot, false, false);
            return;
        }

        uint256 amount = bound(amountSeed, 1 wei, recoverable);
        vm.prank(admin);
        try pool.recoverERC20(address(otherToken), amount) {} catch {}
        _afterAction(snapshot, false, false);
    }

    function warp(uint256 secondsSeed) external {
        ActionSnapshot memory snapshot = _beforeAction();
        vm.warp(block.timestamp + bound(secondsSeed, 0, 30 days));
        _afterAction(snapshot, false, false);
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }

    function depositCount() external view returns (uint256) {
        return allDepositIds.length;
    }

    function depositIdAt(uint256 index) external view returns (uint256) {
        return allDepositIds[index];
    }

    function unsettledLiabilityChangesStayedAllowed() external view returns (bool) {
        return unsettledLiabilityChangeStayedInAllowedScope;
    }

    function rewardPerTokenObservationsStayedMonotonic() external view returns (bool) {
        return rewardPerTokenStayedMonotonic;
    }

    function highestRewardPerTokenObserved() external view returns (uint256) {
        return highestObservedRewardPerToken;
    }

    function _beforeAction() internal view returns (ActionSnapshot memory snapshot) {
        snapshot = ActionSnapshot({
            unsettledMaxSubsidyLiability: pool.unsettledMaxSubsidyLiability(),
            rewardPerToken: pool.rewardPerToken(),
            totalSupply: pool.totalSupply(),
            lastUpdateTime: pool.lastUpdateTime(),
            lastTimeRewardApplicable: pool.lastTimeRewardApplicable()
        });
    }

    function _afterAction(
        ActionSnapshot memory snapshot,
        bool mayIncreaseUnsettledLiability,
        bool mayDecreaseUnsettledLiability
    ) internal {
        uint256 currentUnsettledLiability = pool.unsettledMaxSubsidyLiability();
        if (currentUnsettledLiability != snapshot.unsettledMaxSubsidyLiability) {
            bool increased = currentUnsettledLiability > snapshot.unsettledMaxSubsidyLiability;
            bool emptyPoolAttritionWindow = snapshot.totalSupply == 0
                && snapshot.lastTimeRewardApplicable > snapshot.lastUpdateTime;
            if (increased) {
                unsettledLiabilityChangeStayedInAllowedScope =
                    unsettledLiabilityChangeStayedInAllowedScope && mayIncreaseUnsettledLiability;
            } else {
                unsettledLiabilityChangeStayedInAllowedScope = unsettledLiabilityChangeStayedInAllowedScope
                    && (mayDecreaseUnsettledLiability || emptyPoolAttritionWindow || mayIncreaseUnsettledLiability);
            }
        }

        uint256 currentRewardPerToken = pool.rewardPerToken();
        if (currentRewardPerToken < snapshot.rewardPerToken || currentRewardPerToken < highestObservedRewardPerToken) {
            rewardPerTokenStayedMonotonic = false;
        }
        if (currentRewardPerToken > highestObservedRewardPerToken) {
            highestObservedRewardPerToken = currentRewardPerToken;
        }
    }

    function _actor(uint256 seed) internal view returns (address) {
        return actors[seed % actors.length];
    }

    function _inviter(address actor, uint256 seed) internal view returns (address) {
        if (seed % 4 == 0) return address(0);
        address inviter = _actor(seed / 4);
        return inviter == actor ? address(0) : inviter;
    }

    function _lockDuration(uint256 seed) internal pure returns (uint256) {
        uint256 option = seed % 3;
        if (option == 1) return SHORT_LOCK;
        if (option == 2) return LONG_LOCK;
        return 0;
    }
}

contract V2StakingPoolInvariantTest is StdInvariant, V2StakingPoolBase {
    V2StakingInvariantHandler internal handler;

    function setUp() public override {
        super.setUp();

        address[] memory actors = new address[](5);
        actors[0] = user1;
        actors[1] = user2;
        actors[2] = user3;
        actors[3] = user4;
        actors[4] = user5;

        handler = new V2StakingInvariantHandler(
            pool, stakingToken, rewardToken, otherToken, admin, operator, actors
        );
        targetContract(address(handler));
    }

    function invariant_TotalSupplyEqualsTrackedActivePrincipal() public view {
        uint256 trackedPrincipal;

        for (uint256 i; i < handler.actorCount(); ++i) {
            address actor = handler.actorAt(i);
            uint256[] memory activeIds = pool.getActiveDepositIds(actor);
            assertLe(activeIds.length, pool.MAX_ACTIVE_DEPOSITS());

            uint256 userPrincipal;
            for (uint256 j; j < activeIds.length; ++j) {
                IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(activeIds[j]);
                assertEq(deposit.owner, actor);
                assertGt(deposit.amount, 0);
                userPrincipal += deposit.amount;
            }

            assertEq(pool.totalStakedOf(actor), userPrincipal);
            trackedPrincipal += userPrincipal;
        }

        assertEq(pool.totalSupply(), trackedPrincipal);
    }

    function invariant_DistinctTokenBalancesCoverAccountingReserves() public view {
        assertGe(stakingToken.balanceOf(address(pool)), pool.totalSupply());
        assertGe(rewardToken.balanceOf(address(pool)), pool.baseRewardReserve() + pool.subsidyReserve());
    }

    function invariant_SubsidySweepableNeverExceedsReserve() public view {
        assertLe(pool.maxSweepableSubsidy(), pool.subsidyReserve());
        assertLe(pool.totalPendingSubsidy(), pool.subsidyReserve());
    }

    function invariant_SubsidyReserveCoversPendingAndUnsettledLiability() public view {
        IStakingPoolV2Types.SubsidyConfigView memory config = pool.getSubsidyConfig();
        assertGe(config.subsidyReserve, config.totalPendingSubsidy + config.unsettledMaxSubsidyLiability);
    }

    function invariant_TotalPendingSubsidyMatchesAllPendingSubsidies() public view {
        assertEq(pool.totalPendingSubsidy(), _trackedPendingSubsidy());
    }

    function invariant_UnsettledLiabilityOnlyChangesOnNotifySettleOrAttrition() public view {
        assertTrue(handler.unsettledLiabilityChangesStayedAllowed());
    }

    function invariant_ActiveDepositIdsHaveNoDuplicates() public view {
        for (uint256 i; i < handler.actorCount(); ++i) {
            _assertActiveDepositIdsHaveNoDuplicates(handler.actorAt(i));
        }
    }

    function invariant_RewardPerTokenNeverDecreases() public view {
        assertTrue(handler.rewardPerTokenObservationsStayedMonotonic());
        assertGe(pool.rewardPerToken(), handler.highestRewardPerTokenObserved());
    }

    function invariant_KnownClosedDepositsAreNotActive() public view {
        uint256 depositCount = handler.depositCount();
        for (uint256 i; i < depositCount; ++i) {
            uint256 depositId = handler.depositIdAt(i);
            IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(depositId);
            if (deposit.amount == 0) {
                _assertDepositIdNotActive(deposit.owner, depositId);
            }
        }
    }

    function _trackedPendingSubsidy() internal view returns (uint256 total) {
        uint256 depositCount = handler.depositCount();
        for (uint256 i; i < depositCount; ++i) {
            IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(handler.depositIdAt(i));
            total += deposit.pendingInviteeBoostReward + deposit.pendingBoostReward;
        }

        for (uint256 i; i < handler.actorCount(); ++i) {
            total += pool.claimableReferralReward(handler.actorAt(i));
        }
    }

    function _assertActiveDepositIdsHaveNoDuplicates(address owner) internal view {
        uint256[] memory activeIds = pool.getActiveDepositIds(owner);
        for (uint256 i; i < activeIds.length; ++i) {
            for (uint256 j = i + 1; j < activeIds.length; ++j) {
                assertTrue(activeIds[i] != activeIds[j]);
            }
        }
    }

    function _assertDepositIdNotActive(address owner, uint256 depositId) internal view {
        uint256[] memory activeIds = pool.getActiveDepositIds(owner);
        for (uint256 i; i < activeIds.length; ++i) {
            assertTrue(activeIds[i] != depositId);
        }
    }
}