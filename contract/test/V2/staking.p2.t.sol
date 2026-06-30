// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./staking.base.t.sol";

contract V2StakingPoolP2Test is V2StakingPoolBase {
    // ------------------------------------------------------------------
    // P2：表面、事件、异常和取整补充
    // ------------------------------------------------------------------

    function test_Constants_ReturnExpectedValues() public view {
        assertEq(pool.BPS(), BPS);
        assertEq(pool.MAX_ACTIVE_DEPOSITS(), 50);
        assertEq(pool.MAX_LOCK_TIERS(), 10);
        assertEq(pool.OPERATOR_ROLE(), keccak256("OPERATOR_ROLE"));
    }

    function test_SupportsInterface_ReturnsExpectedValues() public view {
        assertTrue(pool.supportsInterface(type(IAccessControl).interfaceId));
        assertTrue(pool.supportsInterface(type(IStakingPoolV2).interfaceId));
        assertFalse(pool.supportsInterface(0xffffffff));
    }

    function test_Views_RevertWhenUserAddressIsZero() public {
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.getActiveDepositIds(address(0));

        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.getUserDeposits(address(0));

        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.totalStakedOf(address(0));

        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.earned(address(0));

        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.claimableReferralReward(address(0));

        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.getUpline(address(0));
    }

    function test_Views_HarnessRewardPerTokenAtReturnsStoredWhenNoHistory() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));

        assertEq(harness.exposedRewardPerTokenAt(block.timestamp), 0);
    }

    function test_Views_HarnessRewardPerTokenAtBeforeFirstCheckpoint() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));
        _fundAndApproveDefault(harness, stakingToken, rewardToken);

        vm.prank(user1);
        harness.stake(100 ether, 0, address(0));

        assertEq(harness.exposedRewardPerTokenAt(block.timestamp - 1), 0);
    }

    function test_Views_HarnessRewardPerTokenAtBetweenInactiveCheckpointsReturnsPreviousValue() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));
        _fundAndApproveDefault(harness, stakingToken, rewardToken);

        uint256 firstCheckpointTime = block.timestamp;
        vm.prank(user1);
        harness.stake(100 ether, 0, address(0));
        vm.warp(firstCheckpointTime + 10);
        vm.prank(user2);
        harness.stake(100 ether, 0, address(0));

        assertEq(harness.exposedRewardPerTokenAt(firstCheckpointTime + 5), 0);
    }

    function test_Views_HarnessRewardPerTokenAtMiddleCheckpointReturnsCheckpointValue() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));
        _fundAndApproveDefault(harness, stakingToken, rewardToken);

        vm.prank(user1);
        harness.stake(100 ether, 0, address(0));
        uint256 middleCheckpointTime = block.timestamp + 10;
        vm.warp(middleCheckpointTime);
        vm.prank(user2);
        harness.stake(100 ether, 0, address(0));
        vm.warp(middleCheckpointTime + 10);
        vm.prank(user3);
        harness.stake(100 ether, 0, address(0));

        assertEq(harness.exposedRewardPerTokenAt(middleCheckpointTime), 0);
    }

    function test_Views_LastTimeRewardApplicableReturnsMinNowAndPeriodFinish() public {
        assertEq(pool.lastTimeRewardApplicable(), 0);

        uint256 startTime = block.timestamp;
        _notify(1_000 ether);
        assertEq(pool.lastTimeRewardApplicable(), startTime);

        vm.warp(startTime + 1 days);
        assertEq(pool.lastTimeRewardApplicable(), startTime + 1 days);

        vm.warp(startTime + REWARDS_DURATION + 1);
        assertEq(pool.lastTimeRewardApplicable(), startTime + REWARDS_DURATION);
    }

    function test_Views_InitialStateReturnsExpectedZeros() public view {
        IStakingPoolV2Types.RewardScheduleView memory schedule = pool.getRewardSchedule();
        IStakingPoolV2Types.SubsidyConfigView memory subsidy = pool.getSubsidyConfig();

        assertEq(schedule.periodFinish, 0);
        assertEq(schedule.rewardRate, 0);
        assertEq(schedule.lastUpdateTime, 0);
        assertEq(schedule.rewardPerTokenStored, 0);
        assertEq(subsidy.subsidyReserve, 0);
        assertEq(subsidy.totalPendingSubsidy, 0);
        assertEq(subsidy.unsettledMaxSubsidyLiability, 0);
        assertEq(pool.earned(user1), 0);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_Views_EarnedByDepositFlagsBeforeAndAfterUnlock() public {
        _notify(1_000 ether);
        uint256 depositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));

        IStakingPoolV2Types.DepositRewardView memory beforeUnlock = pool.earnedByDeposit(depositId);
        assertFalse(beforeUnlock.boostClaimable);
        assertTrue(beforeUnlock.boostForfeitable);
        assertGt(beforeUnlock.pendingBoostReward, 0);

        vm.warp(pool.getDeposit(depositId).unlockTime);
        IStakingPoolV2Types.DepositRewardView memory afterUnlock = pool.earnedByDeposit(depositId);
        assertTrue(afterUnlock.boostClaimable);
        assertFalse(afterUnlock.boostForfeitable);
    }

    function test_Views_ClaimableReferralRewardZeroAndNonZero() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        assertEq(pool.claimableReferralReward(user1), 0);

        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);
        assertGt(pool.claimableReferralReward(user1), 0);

        _claim(user1);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_Events_StakedWithdrawnEarlyWithdrawnAndDepositClosedFields() public {
        vm.expectEmit(true, true, false, true, address(pool));
        emit IStakingPoolV2Events.Staked(user1, 1, 100 ether, 0, 0, 0);
        uint256 flexibleDepositId = _stake(user1, 100 ether, 0, address(0));

        vm.expectEmit(true, true, false, true, address(pool));
        emit Withdrawn(user1, flexibleDepositId, 100 ether);
        vm.expectEmit(true, true, false, true, address(pool));
        emit DepositClosed(user1, flexibleDepositId);
        _withdraw(user1, flexibleDepositId);
    }

    function test_Events_RewardAccruedFields() public {
        _notify(1_000 ether);
        uint256 depositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);

        vm.expectEmit(true, true, false, false, address(pool));
        emit LockBoostRewardAccrued(user1, depositId, 0);
        vm.expectEmit(true, true, false, false, address(pool));
        emit BaseRewardAccrued(user1, depositId, 0);
        _stake(user1, 1 ether, 0, address(0));
    }

    function test_Events_AdminAndFundingFields() public {
        vm.expectEmit(true, false, false, true, address(pool));
        emit Recovered(address(otherToken), 1 ether);
        vm.prank(admin);
        pool.recoverERC20(address(otherToken), 1 ether);
    }

    function test_PRD_ReferralRewardsAccrueForEachLevel() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        _stake(user4, 100 ether, 0, user3);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);

        _claim(user4);

        assertGt(pool.claimableReferralReward(user3), 0);
        assertGt(pool.claimableReferralReward(user2), 0);
        assertGt(pool.claimableReferralReward(user1), 0);
    }

    function test_PRD_InviteeBoostRewardAccruesForBoundInvitee() public {
        _stake(user1, 100 ether, 0, address(0));
        uint256 depositId = _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);

        _claim(user2);

        assertGt(rewardToken.balanceOf(user2), 0);
        assertEq(pool.getDeposit(depositId).pendingInviteeBoostReward, 0);
    }

    function test_Token_RevertingTransferFromBubblesUp() public {
        RevertingMockERC20 revertingStakeToken = new RevertingMockERC20("Reverting Stake", "RSTK", 18);
        StakingPool revertingPool = _deployDefault(address(revertingStakeToken), address(rewardToken));
        revertingStakeToken.mint(user1, 100 ether);
        vm.prank(user1);
        revertingStakeToken.approve(address(revertingPool), type(uint256).max);
        revertingStakeToken.setRevertTransferFrom(true);

        vm.prank(user1);
        vm.expectRevert("TRANSFER_FROM_REVERTED");
        revertingPool.stake(1 ether, 0, address(0));
    }

    function test_Token_RevertingTransferBubblesUp() public {
        RevertingMockERC20 revertingRewardToken = new RevertingMockERC20("Reverting Reward", "RRWD", 18);
        StakingPool revertingPool = _deployDefault(address(stakingToken), address(revertingRewardToken));
        stakingToken.mint(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(revertingPool), type(uint256).max);
        revertingRewardToken.mint(operator, 10_000 ether);
        vm.prank(operator);
        revertingRewardToken.approve(address(revertingPool), type(uint256).max);

        vm.prank(user1);
        revertingPool.stake(100 ether, 0, address(0));
        vm.prank(operator);
        revertingPool.notifyRewardAmount(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        vm.prank(user1);
        revertingPool.stake(1 ether, 0, address(0));
        revertingRewardToken.setRevertTransfer(true);

        vm.prank(user1);
        vm.expectRevert("TRANSFER_REVERTED");
        revertingPool.claimAll();
    }

    function test_RecoverERC20_DoesNotChangeAnyCoreAccounting() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        uint256 totalSupplyBefore = pool.totalSupply();
        uint256 baseReserveBefore = pool.baseRewardReserve();
        uint256 subsidyReserveBefore = pool.subsidyReserve();
        uint256 pendingSubsidyBefore = pool.totalPendingSubsidy();
        uint256 unsettledBefore = pool.unsettledMaxSubsidyLiability();

        vm.prank(admin);
        pool.recoverERC20(address(otherToken), 1 ether);

        assertEq(pool.totalSupply(), totalSupplyBefore);
        assertEq(pool.baseRewardReserve(), baseReserveBefore);
        assertEq(pool.subsidyReserve(), subsidyReserveBefore);
        assertEq(pool.totalPendingSubsidy(), pendingSubsidyBefore);
        assertEq(pool.unsettledMaxSubsidyLiability(), unsettledBefore);
    }

    function test_Rounding_OneWeiStakeRewardPenaltyReferralAndBoost() public {
        _stake(user1, 1 wei, 0, address(0));
        _stake(user2, 1 wei, 0, user1);
        _notify(1 wei);
        vm.warp(block.timestamp + 1 days);

        _claim(user2);
        _claim(user1);

        assertLe(rewardToken.balanceOf(user1) + rewardToken.balanceOf(user2), 1 wei + ((1 wei * MAX_SUBSIDY_CAP) / BPS));
    }

    function test_Rounding_SmallRewardRateDoesNotOverpayReserve() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1 wei);
        vm.warp(block.timestamp + 1 days);

        _claim(user1);

        assertEq(rewardToken.balanceOf(user1), 0);
        assertEq(pool.baseRewardReserve(), 1 wei);
    }

    function test_Rounding_ReferralAndBoostDoNotExceedMaxSubsidyBudget() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        uint256 subsidyReserve = pool.subsidyReserve();
        vm.warp(block.timestamp + 1 days);

        _claim(user2);
        _claim(user1);

        assertLe((1_000 ether * MAX_SUBSIDY_CAP) / BPS - pool.subsidyReserve(), subsidyReserve);
    }

    function test_HarnessRemoveActiveDeposit_NoopsWhenDepositIsNotActive() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));

        harness.exposedRemoveActiveDeposit(user1, 999);

        assertEq(harness.getActiveDepositIds(user1).length, 0);
    }

    function test_HarnessAssetCoverage_RevertWhenSubsidyReserveBelowLiability() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));

        vm.store(address(harness), bytes32(uint256(9)), bytes32(uint256(1)));

        vm.expectRevert(IStakingPoolV2Errors.InsufficientSubsidyReserve.selector);
        harness.exposedAssertAssetCoverage();
    }

    function test_HarnessAssetCoverage_RevertWhenSameTokenBalanceBelowRequired() public {
        BalanceMutableMockERC20 sameToken = new BalanceMutableMockERC20("Mutable Same", "MSAME", 18);
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(sameToken), address(sameToken)));
        sameToken.mint(address(harness), 99 ether);

        vm.store(address(harness), bytes32(uint256(2)), bytes32(uint256(100 ether)));

        vm.expectRevert(IStakingPoolV2Errors.InsufficientAssetCoverage.selector);
        harness.exposedAssertAssetCoverage();
    }

    function test_HarnessAssetCoverage_RevertWhenStakingBalanceBelowSupply() public {
        V2StakingPoolHarness harness = new V2StakingPoolHarness(_defaultParams(address(stakingToken), address(rewardToken)));

        vm.store(address(harness), bytes32(uint256(2)), bytes32(uint256(1 ether)));

        vm.expectRevert(IStakingPoolV2Errors.InsufficientAssetCoverage.selector);
        harness.exposedAssertAssetCoverage();
    }

    function test_AssetCoverage_RevertWhenCoverageIsBroken() public {
        BalanceMutableMockERC20 mutableRewardToken = new BalanceMutableMockERC20("Mutable Reward", "MRWD", 18);
        StakingPool mutablePool = _deployDefault(address(stakingToken), address(mutableRewardToken));
        stakingToken.mint(user1, 100 ether);
        vm.prank(user1);
        stakingToken.approve(address(mutablePool), type(uint256).max);
        mutableRewardToken.mint(operator, 10_000 ether);
        vm.prank(operator);
        mutableRewardToken.approve(address(mutablePool), type(uint256).max);
        vm.prank(operator);
        mutablePool.notifyRewardAmount(1_000 ether);
        mutableRewardToken.burnFrom(address(mutablePool), 1 wei);

        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.InsufficientAssetCoverage.selector);
        mutablePool.stake(1 ether, 0, address(0));
    }
}