// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./staking.base.t.sol";

contract V2StakingPoolP1Test is V2StakingPoolBase {
    // ------------------------------------------------------------------
    // P1：质押、仓位和快照补充
    // ------------------------------------------------------------------

    function test_Stake_AllowsRestakeAfterWithdrawBelowLimit() public {
        uint256 firstDepositId = _stake(user1, 1 ether, 0, address(0));
        _withdraw(user1, firstDepositId);

        uint256 secondDepositId = _stake(user1, 2 ether, 0, address(0));

        assertEq(pool.totalStakedOf(user1), 2 ether);
        _assertActiveIds(user1, _single(secondDepositId));
    }

    function test_Stake_ActiveDepositLimitIsPerUser() public {
        for (uint256 i; i < pool.MAX_ACTIVE_DEPOSITS(); ++i) {
            _stake(user1, 1 ether, 0, address(0));
        }

        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.TooManyActiveDeposits.selector);
        pool.stake(1 ether, 0, address(0));

        uint256 user2DepositId = _stake(user2, 1 ether, 0, address(0));
        _assertActiveIds(user2, _single(user2DepositId));
    }

    function test_Stake_CheckpointReplacedWithinSameTimestampAndAppendedLater() public {
        vm.expectEmit(true, false, false, true, address(pool));
        emit RewardCheckpointWritten(block.timestamp, 0, 0, 0, false);
        _stake(user1, 1 ether, 0, address(0));

        vm.expectEmit(true, false, false, true, address(pool));
        emit RewardCheckpointWritten(block.timestamp, 0, 0, 0, true);
        _stake(user2, 1 ether, 0, address(0));

        vm.warp(block.timestamp + 1);
        vm.expectEmit(true, false, false, true, address(pool));
        emit RewardCheckpointWritten(block.timestamp, 0, 0, 1, false);
        _stake(user3, 1 ether, 0, address(0));
    }

    function test_GetUserDeposits_ReturnsOnlyActiveDeposits() public {
        uint256 d1 = _stake(user1, 10 ether, 0, address(0));
        uint256 d2 = _stake(user1, 20 ether, 0, address(0));
        uint256 d3 = _stake(user1, 30 ether, 0, address(0));
        _withdraw(user1, d2);

        IStakingPoolV2Types.DepositView[] memory deposits = pool.getUserDeposits(user1);

        assertEq(deposits.length, 2);
        assertEq(pool.getDeposit(d1).amount, 10 ether);
        assertEq(pool.getDeposit(d2).amount, 0);
        assertEq(pool.getDeposit(d3).amount, 30 ether);
    }

    function test_GetDeposit_DistinguishesNonexistentActiveAndClosed() public {
        uint256 depositId = _stake(user1, 10 ether, 0, address(0));
        IStakingPoolV2Types.DepositView memory activeDeposit = pool.getDeposit(depositId);
        assertEq(activeDeposit.owner, user1);
        assertEq(activeDeposit.amount, 10 ether);

        _withdraw(user1, depositId);
        IStakingPoolV2Types.DepositView memory closedDeposit = pool.getDeposit(depositId);
        assertEq(closedDeposit.owner, user1);
        assertEq(closedDeposit.amount, 0);

        vm.expectRevert(IStakingPoolV2Errors.DepositDoesNotExist.selector);
        pool.earnedByDeposit(depositId + 1);
    }

    function test_LockBoost_BoundariesOneSecondBeforeAtAndAfterUnlock() public {
        _notify(1_000 ether);
        uint256 depositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        uint256 unlockTime = pool.getDeposit(depositId).unlockTime;

        vm.warp(unlockTime - 1);
        IStakingPoolV2Types.DepositRewardView memory beforeUnlock = pool.earnedByDeposit(depositId);
        assertFalse(beforeUnlock.boostClaimable);
        assertTrue(beforeUnlock.boostForfeitable);

        vm.warp(unlockTime);
        IStakingPoolV2Types.DepositRewardView memory atUnlock = pool.earnedByDeposit(depositId);
        assertTrue(atUnlock.boostClaimable);
        assertFalse(atUnlock.boostForfeitable);

        vm.warp(unlockTime + 1);
        IStakingPoolV2Types.DepositRewardView memory afterUnlock = pool.earnedByDeposit(depositId);
        assertTrue(afterUnlock.boostClaimable);
        assertFalse(afterUnlock.boostForfeitable);
    }

    function test_LockBoost_SecondPostUnlockUpdateDoesNotRecalculateUnlockPoint() public {
        _notify(1_000 ether);
        uint256 depositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(pool.getDeposit(depositId).unlockTime);
        _stake(user1, 1 ether, 0, address(0));
        uint256 rewardPerTokenAtUnlock = pool.getDeposit(depositId).rewardPerTokenAtUnlock;

        vm.warp(block.timestamp + 1 days);
        _claim(user1);

        assertEq(pool.getDeposit(depositId).rewardPerTokenAtUnlock, rewardPerTokenAtUnlock);
        assertTrue(pool.getDeposit(depositId).boostSettled);
    }

    function test_Withdraw_ActiveListRemovalHandlesFirstMiddleLast() public {
        uint256 d1 = _stake(user1, 10 ether, 0, address(0));
        uint256 d2 = _stake(user1, 20 ether, 0, address(0));
        uint256 d3 = _stake(user1, 30 ether, 0, address(0));
        uint256 d4 = _stake(user1, 40 ether, 0, address(0));

        _withdraw(user1, d1);
        _assertActiveIds(user1, _triple(d2, d3, d4));
        _withdraw(user1, d3);
        _assertActiveIds(user1, _pair(d2, d4));
        _withdraw(user1, d4);
        _assertActiveIds(user1, _single(d2));
    }

    function test_WithdrawMultiple_HandlesIdsOrderDifferentFromActiveListOrder() public {
        uint256 d1 = _stake(user1, 10 ether, 0, address(0));
        uint256 d2 = _stake(user1, 20 ether, 0, address(0));
        uint256 d3 = _stake(user1, 30 ether, 0, address(0));

        _withdrawMultiple(user1, _pair(d3, d1));

        _assertActiveIds(user1, _single(d2));
        assertEq(pool.totalStakedOf(user1), 20 ether);
    }

    function test_ClaimAll_WithNoRewardsDoesNothing() public {
        uint256 rewardBefore = rewardToken.balanceOf(user1);
        uint256 baseReserveBefore = pool.baseRewardReserve();
        uint256 subsidyReserveBefore = pool.subsidyReserve();

        _claim(user1);

        assertEq(rewardToken.balanceOf(user1), rewardBefore);
        assertEq(pool.baseRewardReserve(), baseReserveBefore);
        assertEq(pool.subsidyReserve(), subsidyReserveBefore);
    }

    function test_ClaimAll_LeavesUnclaimableBoostPendingAcrossDeposits() public {
        _notify(1_000 ether);
        uint256 matureDepositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        uint256 immatureDepositId = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(pool.getDeposit(matureDepositId).unlockTime);
        _stake(user1, 1 ether, 0, address(0));
        uint256 immatureBoostBefore = pool.getDeposit(immatureDepositId).pendingBoostReward;

        _claim(user1);

        assertEq(pool.getDeposit(matureDepositId).pendingBoostReward, 0);
        assertEq(pool.getDeposit(immatureDepositId).pendingBoostReward, immatureBoostBefore);
        assertGt(immatureBoostBefore, 0);
    }

    function test_MaxSweepableSubsidy_IncreasesAfterUnusedBudgetConsumed() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        uint256 beforeSettle = pool.maxSweepableSubsidy();

        _stake(user1, 1 ether, 0, address(0));

        assertGt(pool.maxSweepableSubsidy(), beforeSettle);
    }

    function test_MaxSweepableSubsidy_IncreasesAfterBoostForfeited() public {
        _notify(1_000 ether);
        uint256 depositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        uint256 beforeWithdraw = pool.maxSweepableSubsidy();

        _withdraw(user1, depositId);

        assertGt(pool.maxSweepableSubsidy(), beforeWithdraw);
    }

    function test_SweepSubsidy_AllowsPartialAndFullSweepableAmount() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        uint256 sweepable = pool.maxSweepableSubsidy();

        vm.prank(admin);
        pool.sweepSubsidy(receiver, sweepable / 2);
        uint256 remainingSweepable = pool.maxSweepableSubsidy();
        vm.prank(admin);
        pool.sweepSubsidy(receiver, remainingSweepable);

        assertEq(pool.maxSweepableSubsidy(), 0);
        assertEq(rewardToken.balanceOf(receiver), sweepable);
    }

    function test_SameTokenPool_EarlyPenaltyDoesNotBreakCoverage() public {
        MockERC20 sameToken = new MockERC20("Same", "SAME", 18);
        StakingPool samePool = _deployDefault(address(sameToken), address(sameToken));
        sameToken.mint(user1, 1_000 ether);
        vm.prank(user1);
        sameToken.approve(address(samePool), type(uint256).max);
        sameToken.mint(operator, 10_000 ether);
        vm.prank(operator);
        sameToken.approve(address(samePool), type(uint256).max);
        vm.prank(operator);
        samePool.notifyRewardAmount(1_000 ether);
        vm.prank(user1);
        uint256 depositId = samePool.stake(100 ether, SHORT_LOCK, address(0));

        vm.prank(user1);
        samePool.withdraw(depositId);

        assertGe(
            sameToken.balanceOf(address(samePool)),
            samePool.totalSupply() + samePool.baseRewardReserve() + samePool.subsidyReserve()
        );
    }

    function test_Flow_ZeroSupplyAttritionThenSweepThenNewNotify() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        uint256 sweepable = pool.maxSweepableSubsidy();
        vm.prank(admin);
        pool.sweepSubsidy(receiver, sweepable);

        vm.prank(operator);
        pool.notifyRewardAmount(500 ether);

        assertEq(pool.maxSweepableSubsidy(), 0);
        assertApproxEqAbs(pool.baseRewardReserve(), 500 ether, 1 wei);
        assertApproxEqAbs(pool.subsidyReserve(), (500 ether * MAX_SUBSIDY_CAP) / BPS, 1 wei);
    }

    function test_Flow_ExitMixedFlexibleMatureAndEarlyLockedDeposits() public {
        _notify(1_000 ether);
        _stake(user1, 100 ether, 0, address(0));
        _stake(user1, 100 ether, SHORT_LOCK, address(0));
        _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(block.timestamp + SHORT_LOCK);

        _exit(user1);

        assertEq(pool.totalStakedOf(user1), 0);
        assertEq(pool.getActiveDepositIds(user1).length, 0);
        assertGt(stakingToken.balanceOf(treasury), 0);
    }
}