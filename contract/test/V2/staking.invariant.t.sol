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
    }

    function stake(uint256 actorSeed, uint256 amountSeed, uint256 lockSeed, uint256 inviterSeed) external {
        address actor = _actor(actorSeed);
        uint256 amount = bound(amountSeed, 1 wei, 1_000 ether);
        uint256 lockDuration = _lockDuration(lockSeed);
        address inviter = _inviter(actor, inviterSeed);

        vm.prank(actor);
        try pool.stake(amount, lockDuration, inviter) returns (uint256 depositId) {
            allDepositIds.push(depositId);
        } catch {}
    }

    function claim(uint256 actorSeed) external {
        vm.prank(_actor(actorSeed));
        try pool.claimAll() {} catch {}
    }

    function withdraw(uint256 actorSeed, uint256 activeSeed) external {
        address actor = _actor(actorSeed);
        uint256[] memory activeIds = pool.getActiveDepositIds(actor);
        if (activeIds.length == 0) return;

        uint256 depositId = activeIds[bound(activeSeed, 0, activeIds.length - 1)];
        vm.prank(actor);
        try pool.withdraw(depositId) {} catch {}
    }

    function exit(uint256 actorSeed) external {
        vm.prank(_actor(actorSeed));
        try pool.exit() {} catch {}
    }

    function notifyRewardAmount(uint256 amountSeed) external {
        uint256 amount = bound(amountSeed, 1 wei, 10_000 ether);
        vm.prank(operator);
        try pool.notifyRewardAmount(amount) {} catch {}
    }

    function sweepSubsidy(uint256 amountSeed) external {
        uint256 sweepable = pool.maxSweepableSubsidy();
        if (sweepable == 0) return;

        uint256 amount = bound(amountSeed, 1 wei, sweepable);
        vm.prank(admin);
        try pool.sweepSubsidy(admin, amount) {} catch {}
    }

    function recoverOtherToken(uint256 amountSeed) external {
        uint256 recoverable = otherToken.balanceOf(address(pool));
        if (recoverable == 0) return;

        uint256 amount = bound(amountSeed, 1 wei, recoverable);
        vm.prank(admin);
        try pool.recoverERC20(address(otherToken), amount) {} catch {}
    }

    function warp(uint256 secondsSeed) external {
        vm.warp(block.timestamp + bound(secondsSeed, 0, 30 days));
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

    function _assertDepositIdNotActive(address owner, uint256 depositId) internal view {
        uint256[] memory activeIds = pool.getActiveDepositIds(owner);
        for (uint256 i; i < activeIds.length; ++i) {
            assertTrue(activeIds[i] != depositId);
        }
    }
}