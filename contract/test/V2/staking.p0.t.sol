// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "./staking.base.t.sol";

contract V2StakingPoolP0Test is V2StakingPoolBase {
    event UnsettledMaxSubsidyLiabilityUpdated(uint256 newValue);

    // ------------------------------------------------------------------
    // 1. 部署参数与初始化
    // ------------------------------------------------------------------

    function test_Constructor_RevertWhenCoreAddressIsZero() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));

        params.stakingToken = address(0);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        _deployWithParams(params);

        params = _defaultParams(address(stakingToken), address(rewardToken));
        params.rewardToken = address(0);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        _deployWithParams(params);

        params = _defaultParams(address(stakingToken), address(rewardToken));
        params.admin = address(0);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        _deployWithParams(params);

        params = _defaultParams(address(stakingToken), address(rewardToken));
        params.treasury = address(0);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        _deployWithParams(params);
    }

    function test_Constructor_AllowsOperatorZeroAndDoesNotGrantRole() public {
        StakingPool deployed = _deployDefault(address(stakingToken), address(rewardToken), address(0), treasury);
        assertFalse(deployed.hasRole(deployed.OPERATOR_ROLE(), address(0)));
    }

    function test_Constructor_RevertWhenRewardsDurationIsZero() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.rewardsDuration = 0;
        vm.expectRevert(IStakingPoolV2Errors.RewardsDurationCannotBeZero.selector);
        _deployWithParams(params);
    }

    function test_Constructor_RevertWhenPenaltyRateGreaterThanBps() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.penaltyRate = BPS + 1;
        vm.expectRevert(IStakingPoolV2Errors.PenaltyRateTooHigh.selector);
        _deployWithParams(params);
    }

    function test_Constructor_RevertWhenLockTierLengthMismatch() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.durations = new uint256[](2);
        params.durations[0] = SHORT_LOCK;
        params.durations[1] = LONG_LOCK;
        params.boosts = new uint256[](1);
        params.boosts[0] = SHORT_BOOST;
        vm.expectRevert(IStakingPoolV2Errors.LockTierLengthMismatch.selector);
        _deployWithParams(params);
    }

    function test_Constructor_RevertWhenTooManyLockTiers() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.durations = new uint256[](11);
        params.boosts = new uint256[](11);
        for (uint256 i; i < 11; ++i) {
            params.durations[i] = (i + 1) * 1 days;
            params.boosts[i] = 100;
        }
        params.maxSubsidyRateCap = 10_000;
        vm.expectRevert(IStakingPoolV2Errors.TooManyLockTiers.selector);
        _deployWithParams(params);
    }

    function test_Constructor_RevertWhenInvalidLockTier() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        (params.durations, params.boosts) = _oneLockTier(0, SHORT_BOOST);
        vm.expectRevert(IStakingPoolV2Errors.InvalidLockDuration.selector);
        _deployWithParams(params);

        params = _defaultParams(address(stakingToken), address(rewardToken));
        (params.durations, params.boosts) = _oneLockTier(SHORT_LOCK, 0);
        vm.expectRevert(IStakingPoolV2Errors.LockBoostRateCannotBeZero.selector);
        _deployWithParams(params);

        params = _defaultParams(address(stakingToken), address(rewardToken));
        params.durations = new uint256[](2);
        params.durations[0] = SHORT_LOCK;
        params.durations[1] = SHORT_LOCK;
        params.boosts = new uint256[](2);
        params.boosts[0] = SHORT_BOOST;
        params.boosts[1] = LONG_BOOST;
        vm.expectRevert(IStakingPoolV2Errors.DuplicateLockDuration.selector);
        _deployWithParams(params);
    }

    function test_Constructor_RevertWhenMaxSubsidyRateExceedsCap() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        (params.durations, params.boosts) = _oneLockTier(SHORT_LOCK, LONG_BOOST);
        params.maxSubsidyRateCap = MAX_SUBSIDY_CAP - 1;
        vm.expectRevert(IStakingPoolV2Errors.MaxSubsidyRateExceeded.selector);
        _deployWithParams(params);
    }

    function test_Constructor_InitializesCoreConfigAndRoles() public view {
        assertEq(pool.stakingToken(), address(stakingToken));
        assertEq(pool.rewardToken(), address(rewardToken));
        assertEq(pool.hasRole(pool.DEFAULT_ADMIN_ROLE(), admin), true);
        assertEq(pool.hasRole(pool.OPERATOR_ROLE(), operator), true);
        (uint256 inviteeBoost, uint256 level1, uint256 level2, uint256 level3) = pool.getReferralRates();
        assertEq(inviteeBoost, INVITEE_BOOST);
        assertEq(level1, LEVEL1);
        assertEq(level2, LEVEL2);
        assertEq(level3, LEVEL3);
        (uint256 penaltyRate, address configuredTreasury) = pool.getPenaltyConfig();
        assertEq(penaltyRate, PENALTY_RATE);
        assertEq(configuredTreasury, treasury);
        (uint256[] memory durations, uint256[] memory boosts) = pool.getLockTiers();
        assertEq(durations.length, 2);
        assertEq(durations[0], SHORT_LOCK);
        assertEq(durations[1], LONG_LOCK);
        assertEq(boosts[0], SHORT_BOOST);
        assertEq(boosts[1], LONG_BOOST);
        IStakingPoolV2Types.RewardScheduleView memory schedule = pool.getRewardSchedule();
        assertEq(schedule.rewardsDuration, REWARDS_DURATION);
    }

    function test_Constructor_InitializesAccountingStateToZero() public view {
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.baseRewardReserve(), 0);
        assertEq(pool.subsidyReserve(), 0);
        assertEq(pool.totalPendingSubsidy(), 0);
        assertEq(pool.unsettledMaxSubsidyLiability(), 0);
        IStakingPoolV2Types.RewardScheduleView memory schedule = pool.getRewardSchedule();
        assertEq(schedule.periodFinish, 0);
        assertEq(schedule.rewardRate, 0);
        assertEq(schedule.lastUpdateTime, 0);
        assertEq(schedule.rewardPerTokenStored, 0);
    }

    // ------------------------------------------------------------------
    // 2. 权限与暂停
    // ------------------------------------------------------------------

    function test_AccessControl_OnlyOperatorCanNotifyRewardAmount() public {
        _expectAccessDenied(user1, pool.OPERATOR_ROLE());
        vm.prank(user1);
        pool.notifyRewardAmount(100 ether);
        _notify(100 ether);
    }

    function test_AccessControl_OnlyAdminCanSetTreasury() public {
        _expectAccessDenied(user1, pool.DEFAULT_ADMIN_ROLE());
        vm.prank(user1);
        pool.setTreasury(receiver);
        vm.prank(admin);
        pool.setTreasury(receiver);
        (, address configuredTreasury) = pool.getPenaltyConfig();
        assertEq(configuredTreasury, receiver);
    }

    function test_AccessControl_OnlyAdminCanSweepSubsidy() public {
        _notify(100 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        vm.prank(operator);
        pool.notifyRewardAmount(1 ether);
        uint256 sweepable = pool.maxSweepableSubsidy();
        _expectAccessDenied(user1, pool.DEFAULT_ADMIN_ROLE());
        vm.prank(user1);
        pool.sweepSubsidy(receiver, 1);
        vm.prank(admin);
        pool.sweepSubsidy(receiver, sweepable);
    }

    function test_AccessControl_OnlyAdminCanPauseAndUnpause() public {
        _expectAccessDenied(user1, pool.DEFAULT_ADMIN_ROLE());
        vm.prank(user1);
        pool.pause();
        vm.prank(admin);
        pool.pause();
        assertTrue(pool.paused());
        _expectAccessDenied(user1, pool.DEFAULT_ADMIN_ROLE());
        vm.prank(user1);
        pool.unpause();
        vm.prank(admin);
        pool.unpause();
        assertFalse(pool.paused());
    }

    function test_AccessControl_OnlyAdminCanRecoverERC20() public {
        _expectAccessDenied(user1, pool.DEFAULT_ADMIN_ROLE());
        vm.prank(user1);
        pool.recoverERC20(address(otherToken), 1 ether);
        uint256 beforeBalance = otherToken.balanceOf(admin);
        vm.prank(admin);
        pool.recoverERC20(address(otherToken), 1 ether);
        assertEq(otherToken.balanceOf(admin) - beforeBalance, 1 ether);
    }

    function test_Pause_BlocksStakeNotifyAndSweep() public {
        _notify(100 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        vm.prank(operator);
        pool.notifyRewardAmount(1 ether);
        uint256 sweepable = pool.maxSweepableSubsidy();
        vm.prank(admin);
        pool.pause();
        vm.prank(user1);
        vm.expectRevert(ENFORCED_PAUSE);
        pool.stake(1 ether, 0, address(0));
        vm.prank(operator);
        vm.expectRevert(ENFORCED_PAUSE);
        pool.notifyRewardAmount(1 ether);
        vm.prank(admin);
        vm.expectRevert(ENFORCED_PAUSE);
        pool.sweepSubsidy(receiver, sweepable);
    }

    function test_Pause_AllowsClaimWithdrawExitAndAdminRecovery() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        _stake(user1, 50 ether, 0, address(0));
        _notify(100 ether);
        vm.warp(block.timestamp + 1 days);
        vm.prank(admin);
        pool.pause();
        _claim(user1);
        _withdraw(user1, d1);
        _exit(user1);
        vm.prank(admin);
        pool.recoverERC20(address(otherToken), 1 ether);
    }

    // ------------------------------------------------------------------
    // 3. 奖励注入与奖励周期
    // ------------------------------------------------------------------

    function test_NotifyRewardAmount_RevertWhenAmountZero() public {
        vm.prank(operator);
        vm.expectRevert(IStakingPoolV2Errors.RewardAmountCannotBeZero.selector);
        pool.notifyRewardAmount(0);
    }

    function test_NotifyRewardAmount_RevertWhenAmountCannotCreateRewardRate() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.rewardsDuration = 1e18 + 1;
        StakingPool tinyRatePool = _deployWithParams(params);
        _fundAndApproveDefault(tinyRatePool, stakingToken, rewardToken);

        vm.prank(operator);
        vm.expectRevert(IStakingPoolV2Errors.RewardAmountTooSmall.selector);
        tinyRatePool.notifyRewardAmount(1 wei);
        assertEq(rewardToken.balanceOf(address(tinyRatePool)), 0);
    }

    function test_NotifyRewardAmount_RevertWhenRewardTransferIsNotExact() public {
        FeeOnTransferMockERC20 feeReward = new FeeOnTransferMockERC20("Fee Reward", "FRWD", 18, 100);
        StakingPool feePool = _deployDefault(address(stakingToken), address(feeReward), operator, treasury);
        feeReward.mint(operator, 1_000 ether);
        vm.prank(operator);
        feeReward.approve(address(feePool), type(uint256).max);
        vm.prank(operator);
        vm.expectRevert(IStakingPoolV2Errors.FeeOnTransferNotSupported.selector);
        feePool.notifyRewardAmount(100 ether);
    }

    function test_NotifyRewardAmount_StartsNewRewardPeriod() public {
        uint256 start = block.timestamp;
        _notify(1_000 ether);
        IStakingPoolV2Types.RewardScheduleView memory schedule = pool.getRewardSchedule();
        assertEq(schedule.rewardRate, (1_000 ether * 1e18) / REWARDS_DURATION);
        assertEq(schedule.lastUpdateTime, start);
        assertEq(schedule.periodFinish, start + REWARDS_DURATION);
    }

    function test_NotifyRewardAmount_IncreasesBaseReserveAndSubsidyLiability() public {
        _notify(1_000 ether);
        assertEq(pool.baseRewardReserve(), 1_000 ether);
        assertEq(pool.subsidyReserve(), _expectedSubsidy(1_000 ether));
        assertEq(pool.unsettledMaxSubsidyLiability(), _expectedSubsidy(1_000 ether));
    }

    function test_NotifyRewardAmount_EmitsUnsettledLiabilityIncrease() public {
        uint256 expectedLiability = _expectedSubsidy(1_000 ether);
        vm.expectEmit(false, false, false, true, address(pool));
        emit UnsettledMaxSubsidyLiabilityUpdated(expectedLiability);
        _notify(1_000 ether);
    }

    function test_NotifyRewardAmount_UsesSweepableSubsidyBeforeChargingMore() public {
        _notify(100 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        vm.prank(operator);
        pool.notifyRewardAmount(1 ether);
        uint256 reserveBefore = pool.subsidyReserve();
        uint256 sweepableBefore = pool.maxSweepableSubsidy();
        vm.prank(operator);
        pool.notifyRewardAmount(10 ether);
        uint256 required = _expectedSubsidy(10 ether);
        uint256 expectedCharged = required > sweepableBefore ? required - sweepableBefore : 0;
        assertEq(pool.subsidyReserve(), reserveBefore + expectedCharged);
    }

    function test_NotifyRewardAmount_CarriesLeftoverWhenPeriodActive() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION / 2);
        vm.prank(operator);
        pool.notifyRewardAmount(100 ether);
        IStakingPoolV2Types.RewardScheduleView memory schedule = pool.getRewardSchedule();
        assertApproxEqAbs(schedule.rewardRate, (600 ether * 1e18) / REWARDS_DURATION, 2e15);
    }

    function test_NotifyRewardAmount_LeftoverDoesNotIncreaseBaseReserveAgain() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION / 2);
        vm.prank(operator);
        pool.notifyRewardAmount(100 ether);
        assertApproxEqAbs(pool.baseRewardReserve(), 600 ether, ROUNDING_TOLERANCE);
    }

    function test_NotifyRewardAmount_SubsidyBudgetChargedOnNewBaseOnly() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION / 2);
        vm.prank(operator);
        pool.notifyRewardAmount(100 ether);
        assertApproxEqAbs(pool.unsettledMaxSubsidyLiability(), _expectedSubsidy(600 ether), ROUNDING_TOLERANCE);
    }

    function test_RewardSchedule_IsActiveOnlyBeforePeriodFinish() public {
        assertFalse(pool.isRewardPeriodActive());
        _notify(100 ether);
        assertTrue(pool.isRewardPeriodActive());
        vm.warp(block.timestamp + REWARDS_DURATION);
        assertFalse(pool.isRewardPeriodActive());
    }

    function test_RemainingBaseReward_ReturnsExpectedValueDuringAndAfterPeriod() public {
        _notify(1_000 ether);
        assertApproxEqAbs(pool.remainingBaseReward(), 1_000 ether, ROUNDING_TOLERANCE);
        vm.warp(block.timestamp + REWARDS_DURATION / 4);
        assertApproxEqAbs(pool.remainingBaseReward(), 750 ether, ROUNDING_TOLERANCE);
        vm.warp(block.timestamp + REWARDS_DURATION);
        assertEq(pool.remainingBaseReward(), 0);
    }

    // ------------------------------------------------------------------
    // 4. 水位线与空窗奖励
    // ------------------------------------------------------------------

    function test_RewardPerToken_IncreasesLinearlyWhenSupplyPositive() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        assertApproxEqAbs(pool.rewardPerToken(), 1 ether, ROUNDING_TOLERANCE);
    }

    function test_RewardPerToken_DoesNotIncreaseWhenSupplyZero() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.rewardPerToken(), 0);
    }

    function test_RewardPerToken_DoesNotIncreaseAfterPeriodFinish() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        uint256 atFinish = pool.rewardPerToken();
        vm.warp(block.timestamp + 1 days);
        assertEq(pool.rewardPerToken(), atFinish);
    }

    function test_UpdateReward_WhenSupplyZeroBurnsBaseReserveAndReleasesSubsidyBudget() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 100 ether, 0, address(0));
        assertApproxEqAbs(pool.baseRewardReserve(), 900 ether, ROUNDING_TOLERANCE);
        assertApproxEqAbs(pool.unsettledMaxSubsidyLiability(), _expectedSubsidy(900 ether), ROUNDING_TOLERANCE);
    }

    function test_UpdateReward_WhenSupplyZeroDoesNotCreateUserRewardsOrPendingSubsidy() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 100 ether, 0, address(0));
        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(1);
        assertEq(reward.baseReward, 0);
        assertEq(pool.totalPendingSubsidy(), 0);
    }

    function test_UpdateReward_DoesNotAccrueWhenRewardRoundsToZero() public {
        _stake(user1, 1_000_000 ether, 0, address(0));
        _notify(1 wei);
        vm.warp(block.timestamp + 1 seconds);
        _claim(user1);
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(1);
        assertEq(deposit.pendingBaseReward, 0);
        assertEq(pool.totalPendingSubsidy(), 0);
    }

    // ------------------------------------------------------------------
    // 5. 质押与仓位账本
    // ------------------------------------------------------------------

    function test_Stake_CreatesFlexibleDeposit() public {
        uint256 depositId = _stake(user1, 100 ether, 0, address(0));
        assertEq(depositId, 1);
        assertEq(pool.totalSupply(), 100 ether);
        assertEq(pool.totalStakedOf(user1), 100 ether);
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(depositId);
        assertEq(deposit.owner, user1);
        assertEq(deposit.amount, 100 ether);
        assertEq(deposit.unlockTime, 0);
        assertEq(deposit.boostRate, 0);
        assertEq(deposit.rewardPerTokenPaid, pool.rewardPerToken());
        assertTrue(deposit.boostSettled);
        uint256[] memory expected = new uint256[](1);
        expected[0] = depositId;
        _assertActiveIds(user1, expected);
    }

    function test_Stake_CreatesLockedDepositWhenRewardPeriodActive() public {
        _notify(100 ether);
        uint256 nowTs = block.timestamp;
        uint256 depositId = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(depositId);
        assertEq(deposit.unlockTime, nowTs + SHORT_LOCK);
        assertEq(deposit.boostRate, SHORT_BOOST);
        assertFalse(deposit.boostSettled);
    }

    function test_Stake_RevertWhenAmountZero() public {
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.AmountMustBeGreaterThanZero.selector);
        pool.stake(0, 0, address(0));
    }

    function test_Stake_RevertWhenTransferIsNotExact() public {
        FeeOnTransferMockERC20 feeStake = new FeeOnTransferMockERC20("Fee Stake", "FSTK", 18, 100);
        StakingPool feePool = _deployDefault(address(feeStake), address(rewardToken), operator, treasury);
        feeStake.mint(user1, 100 ether);
        vm.prank(user1);
        feeStake.approve(address(feePool), type(uint256).max);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.FeeOnTransferNotSupported.selector);
        feePool.stake(100 ether, 0, address(0));
    }

    function test_Stake_RevertWhenInvalidLockDuration() public {
        _notify(100 ether);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.InvalidLockDuration.selector);
        pool.stake(100 ether, 7 days, address(0));
    }

    function test_Stake_RevertWhenLockedStakeNotActive() public {
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.LockStakingNotActive.selector);
        pool.stake(100 ether, SHORT_LOCK, address(0));
        _notify(100 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.LockStakingNotActive.selector);
        pool.stake(100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.LockStakingNotActive.selector);
        pool.stake(100 ether, SHORT_LOCK, address(0));
    }

    function test_Stake_AllowsFlexibleStakeWhenRewardPeriodInactive() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(100 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        _stake(user2, 100 ether, 0, address(0));
        assertEq(pool.totalStakedOf(user2), 100 ether);
    }

    function test_Stake_RevertWhenActiveDepositLimitReached() public {
        for (uint256 i; i < 50; ++i) {
            _stake(user1, 1 ether, 0, address(0));
        }
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.TooManyActiveDeposits.selector);
        pool.stake(1 ether, 0, address(0));
    }

    function test_Stake_RevertDoesNotPersistInviterStateOrPartialAccounting() public {
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.InvalidInviter.selector);
        pool.stake(100 ether, 0, user2);
        assertFalse(pool.hasSetInviter(user1));
        assertEq(pool.inviterOf(user1), address(0));
        assertEq(pool.totalSupply(), 0);
        assertEq(pool.getActiveDepositIds(user1).length, 0);
    }

    function test_Stake_WritesOrReplacesRewardCheckpoint() public {
        vm.expectEmit(true, false, false, true);
        emit RewardCheckpointWritten(block.timestamp, 0, 0, 0, false);
        _stake(user1, 100 ether, 0, address(0));
        vm.expectEmit(true, false, false, true);
        emit RewardCheckpointWritten(block.timestamp, 0, 0, 0, true);
        _stake(user2, 100 ether, 0, address(0));
    }

    // ------------------------------------------------------------------
    // 6. 邀请关系绑定
    // ------------------------------------------------------------------

    function test_Referral_FirstStakeWithZeroInviterLocksNoInviter() public {
        _stake(user1, 100 ether, 0, address(0));
        assertTrue(pool.hasSetInviter(user1));
        assertEq(pool.inviterOf(user1), address(0));
    }

    function test_Referral_FirstStakeWithValidInviterBindsInviter() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        assertTrue(pool.hasSetInviter(user2));
        assertEq(pool.inviterOf(user2), user1);
    }

    function test_Referral_SubsequentStakeCannotChangeInviter() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user2, 100 ether, 0, address(0));
        assertEq(pool.inviterOf(user2), user1);
    }

    function test_Referral_RevertWhenInviterIsSelfOrUnset() public {
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.InvalidInviter.selector);
        pool.stake(100 ether, 0, user1);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.InvalidInviter.selector);
        pool.stake(100 ether, 0, user2);
    }

    function test_Referral_RevertWhenCycleDetectedWithinThreeLevels() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        _stake(user4, 100 ether, 0, user3);
        // 已绑定后不能修改链路；用同一约束验证三级链路不会被非首次质押改写成环。
        _stake(user1, 100 ether, 0, user4);
        (address l1,,) = pool.getUpline(user1);
        assertEq(l1, address(0));
    }

    function test_Referral_GetUplineReturnsThreeLevels() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        _stake(user4, 100 ether, 0, user3);
        _stake(user5, 100 ether, 0, user4);
        (address l1, address l2, address l3) = pool.getUpline(user5);
        assertEq(l1, user4);
        assertEq(l2, user3);
        assertEq(l3, user2);
    }

    function test_Referral_DisabledReferralIgnoresInvalidInviterAndDoesNotBind() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.inviteeBoost = 0;
        params.level1 = 0;
        params.level2 = 0;
        params.level3 = 0;
        params.maxSubsidyRateCap = LONG_BOOST;
        StakingPool disabledReferralPool = _deployWithParams(params);
        _fundAndApproveDefault(disabledReferralPool, stakingToken, rewardToken);

        vm.prank(user1);
        disabledReferralPool.stake(100 ether, 0, user1);
        vm.prank(user2);
        disabledReferralPool.stake(100 ether, 0, user3);

        assertFalse(disabledReferralPool.hasSetInviter(user1));
        assertFalse(disabledReferralPool.hasSetInviter(user2));
        assertEq(disabledReferralPool.inviterOf(user1), address(0));
        assertEq(disabledReferralPool.inviterOf(user2), address(0));
    }

    // ------------------------------------------------------------------
    // 7. 基础奖励与补贴计提
    // ------------------------------------------------------------------

    function test_AccrueReward_SingleUserReceivesBaseReward() public {
        uint256 depositId = _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(depositId);
        assertApproxEqAbs(reward.baseReward, 100 ether, ROUNDING_TOLERANCE);
        _claim(user1);
        assertEq(pool.getDeposit(depositId).pendingBaseReward, 0);
    }

    function test_AccrueReward_MultipleUsersShareByPrincipalAndTime() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        uint256 d2 = _stake(user2, 300 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        assertApproxEqAbs(pool.earnedByDeposit(d1).baseReward, 25 ether, ROUNDING_TOLERANCE);
        assertApproxEqAbs(pool.earnedByDeposit(d2).baseReward, 75 ether, ROUNDING_TOLERANCE);
    }

    function test_AccrueReward_NewDepositDoesNotReceivePastRewards() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _stake(user2, 100 ether, 0, address(0));
        assertEq(pool.earned(user2), 0);
    }

    function test_AccrueReward_ClosedDepositStopsReceivingFutureRewards() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _withdraw(user1, d1);
        uint256 balanceAfterWithdraw = rewardToken.balanceOf(user1);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        assertEq(rewardToken.balanceOf(user1), balanceAfterWithdraw);
    }

    function test_AccrueReward_UpdatesDepositWatermarkAndPendingBase() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(d1);
        assertApproxEqAbs(deposit.pendingBaseReward, 100 ether, ROUNDING_TOLERANCE);
        assertEq(deposit.rewardPerTokenPaid, pool.rewardPerToken());
    }

    function test_AccrueReward_ReducesUnsettledLiabilityByMaxSubsidyDelta() public {
        uint256 depositId = _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        uint256 accruedBaseReward = pool.earnedByDeposit(depositId).baseReward;
        uint256 expectedLiability = pool.unsettledMaxSubsidyLiability() - _expectedSubsidy(accruedBaseReward);
        vm.expectEmit(false, false, false, true, address(pool));
        emit UnsettledMaxSubsidyLiabilityUpdated(expectedLiability);
        _claim(user1);
        assertEq(pool.unsettledMaxSubsidyLiability(), expectedLiability);
    }

    function test_AccrueReward_CumulativeLiabilityClearsSegmentedFloorDust() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.rewardsDuration = 3;
        params.inviteeBoost = 0;
        params.level1 = 0;
        params.level2 = 0;
        params.level3 = 0;
        (params.durations, params.boosts) = _oneLockTier(SHORT_LOCK, 5_000);
        params.maxSubsidyRateCap = 5_000;
        StakingPool dustPool = _deployWithParams(params);
        _fundAndApproveDefault(dustPool, stakingToken, rewardToken);

        vm.prank(user1);
        dustPool.stake(1 wei, 0, address(0));
        vm.prank(user2);
        dustPool.stake(1 wei, 0, address(0));
        vm.prank(user3);
        dustPool.stake(1 wei, 0, address(0));

        vm.prank(operator);
        dustPool.notifyRewardAmount(3 wei);
        assertEq(dustPool.unsettledMaxSubsidyLiability(), 1 wei);

        vm.warp(block.timestamp + 3);
        vm.prank(user1);
        dustPool.claimAll();
        vm.prank(user2);
        dustPool.claimAll();
        vm.prank(user3);
        dustPool.claimAll();

        assertEq(dustPool.baseRewardReserve(), 0);
        assertEq(dustPool.unsettledMaxSubsidyLiability(), 0);
        assertEq(dustPool.maxSweepableSubsidy(), dustPool.subsidyReserve());
    }

    function test_AccrueReward_EmptyPoolNaturalAttritionEmitsUnsettledLiabilityUpdate() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        IStakingPoolV2Types.RewardScheduleView memory schedule = pool.getRewardSchedule();
        uint256 naturalAttritionReward = (schedule.rewardRate * 1 days) / 1e18;
        uint256 expectedLiability = pool.unsettledMaxSubsidyLiability() - _expectedSubsidy(naturalAttritionReward);
        vm.expectEmit(false, false, false, true, address(pool));
        emit UnsettledMaxSubsidyLiabilityUpdated(expectedLiability);
        _stake(user1, 100 ether, 0, address(0));
        assertEq(pool.unsettledMaxSubsidyLiability(), expectedLiability);
    }

    function test_AccrueReward_TotalPendingSubsidyTracksActualSubsidies() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _stake(user2, 1 ether, 0, address(0));
        uint256 expected = (50 ether * INVITEE_BOOST) / BPS + (50 ether * LEVEL1) / BPS;
        assertApproxEqAbs(pool.totalPendingSubsidy(), expected, ROUNDING_TOLERANCE);
    }

    // ------------------------------------------------------------------
    // 8. 推荐补贴与三级返佣
    // ------------------------------------------------------------------

    function test_ReferralReward_NoUplineAccruesNoReferralReward() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_ReferralReward_AccruesLevel1Level2Level3() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        _stake(user4, 100 ether, 0, user3);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user4);
        uint256 expectedBaseReward = 25 ether;
        assertApproxEqAbs(pool.claimableReferralReward(user3), (expectedBaseReward * LEVEL1) / BPS, ROUNDING_TOLERANCE);
        assertApproxEqAbs(pool.claimableReferralReward(user2), (expectedBaseReward * LEVEL2) / BPS, ROUNDING_TOLERANCE);
        assertApproxEqAbs(pool.claimableReferralReward(user1), (expectedBaseReward * LEVEL3) / BPS, ROUNDING_TOLERANCE);
    }

    function test_ReferralReward_AccrualEmitsRewardTypeEvents() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        uint256 sourceDepositId = _stake(user4, 100 ether, 0, user3);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);

        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(sourceDepositId);
        uint256 expectedBaseReward = reward.baseReward;
        uint256 expectedInviteeBoostReward = (expectedBaseReward * INVITEE_BOOST) / BPS;
        uint256 expectedLevel1Reward = (expectedBaseReward * LEVEL1) / BPS;
        uint256 expectedLevel2Reward = (expectedBaseReward * LEVEL2) / BPS;
        uint256 expectedLevel3Reward = (expectedBaseReward * LEVEL3) / BPS;

        vm.expectEmit(true, true, true, true, address(pool));
        emit ReferralRewardAccrued(user3, user4, 1, sourceDepositId, expectedLevel1Reward);
        vm.expectEmit(true, true, true, true, address(pool));
        emit ReferralRewardAccrued(user2, user4, 2, sourceDepositId, expectedLevel2Reward);
        vm.expectEmit(true, true, true, true, address(pool));
        emit ReferralRewardAccrued(user1, user4, 3, sourceDepositId, expectedLevel3Reward);
        vm.expectEmit(true, true, false, true, address(pool));
        emit InviteeBoostRewardAccrued(user4, sourceDepositId, expectedInviteeBoostReward);
        vm.expectEmit(true, true, false, true, address(pool));
        emit BaseRewardAccrued(user4, sourceDepositId, expectedBaseReward);
        _claim(user4);
    }

    function test_ReferralReward_DoesNotAccrueBeyondLevel3() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        _stake(user4, 100 ether, 0, user3);
        _stake(user5, 100 ether, 0, user4);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user5);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_ReferralReward_ZeroLevelRateStopsExpectedLevel() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        (params.durations, params.boosts) = _oneLockTier(SHORT_LOCK, SHORT_BOOST);
        params.level2 = 0;
        params.maxSubsidyRateCap = 10_000;
        StakingPool zeroLevelPool = _deployWithParams(params);
        _fundAndApproveDefault(zeroLevelPool, stakingToken, rewardToken);
        vm.prank(user1);
        zeroLevelPool.stake(100 ether, 0, address(0));
        vm.prank(user2);
        zeroLevelPool.stake(100 ether, 0, user1);
        vm.prank(user3);
        zeroLevelPool.stake(100 ether, 0, user2);
        vm.prank(operator);
        zeroLevelPool.notifyRewardAmount(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        vm.prank(user3);
        zeroLevelPool.claimAll();
        assertGt(zeroLevelPool.claimableReferralReward(user2), 0);
        assertEq(zeroLevelPool.claimableReferralReward(user1), 0);
    }

    function test_ReferralReward_ClaimableReferralRewardUpdatesAfterAccrualAndClaim() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);
        assertApproxEqAbs(pool.claimableReferralReward(user1), 5 ether, ROUNDING_TOLERANCE);
        _claim(user1);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_ReferralReward_WithdrawDoesNotClaimUserLevelReferralReward() public {
        uint256 depositId = _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);

        uint256 referralBeforeWithdraw = pool.claimableReferralReward(user1);
        assertGt(referralBeforeWithdraw, 0);
        _withdraw(user1, depositId);
        assertEq(pool.claimableReferralReward(user1), referralBeforeWithdraw);

        _claim(user1);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_ReferralReward_WithdrawMultipleDoesNotClaimUserLevelReferralReward() public {
        uint256 depositId1 = _stake(user1, 100 ether, 0, address(0));
        uint256 depositId2 = _stake(user1, 50 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);

        uint256 referralBeforeWithdraw = pool.claimableReferralReward(user1);
        assertGt(referralBeforeWithdraw, 0);
        _withdrawMultiple(user1, _pair(depositId1, depositId2));
        assertEq(pool.claimableReferralReward(user1), referralBeforeWithdraw);
    }

    function test_PRD_InviteeBoostOnlyAccruesForUsersWithValidInviter() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);
        assertApproxEqAbs(rewardToken.balanceOf(user2), 50 ether + ((50 ether * INVITEE_BOOST) / BPS), ROUNDING_TOLERANCE);
    }

    function test_PRD_UserWithoutInviterDoesNotReceiveInviteeBoost() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        assertApproxEqAbs(rewardToken.balanceOf(user1), 100 ether, ROUNDING_TOLERANCE);
        assertEq(pool.totalPendingSubsidy(), 0);
    }

    // ------------------------------------------------------------------
    // 9. 锁仓 boost 与到期切分
    // ------------------------------------------------------------------

    function test_LockBoost_AccruesBeforeUnlockButIsNotClaimable() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(d1);
        assertApproxEqAbs(reward.pendingBoostReward, 10 ether, ROUNDING_TOLERANCE);
        assertEq(reward.claimableBoostReward, 0);
        assertFalse(reward.boostClaimable);
    }

    function test_LockBoost_SettlesAtUnlockAndBecomesClaimable() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + SHORT_LOCK);
        _claim(user1);
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(d1);
        assertTrue(deposit.boostSettled);
        assertEq(deposit.pendingBoostReward, 0);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_LockBoost_ExactUnlockTimestampIsMatureNotEarly() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime);
        uint256 treasuryBefore = stakingToken.balanceOf(treasury);
        _withdraw(user1, d1);
        assertEq(stakingToken.balanceOf(treasury), treasuryBefore);
    }

    function test_LockBoost_DoesNotAccrueAfterUnlock() public {
        _notify(2_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + SHORT_LOCK);
        _claim(user1);
        uint256 balanceAfterUnlockClaim = rewardToken.balanceOf(user1);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        assertEq(rewardToken.balanceOf(user1) - balanceAfterUnlockClaim, 0);
        assertTrue(pool.getDeposit(d1).boostSettled);
    }

    function test_LockBoost_BaseRewardContinuesAfterUnlock() public {
        _notify(10_000 ether);
        _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + SHORT_LOCK + 1 days);
        uint256 earned = pool.earned(user1);
        assertGt(earned, 0);
    }

    function test_LockBoost_UsesRewardPerTokenAtUnlockInterpolation() public {
        _notify(10_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + SHORT_LOCK / 2);
        _stake(user2, 100 ether, 0, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime + 1);
        _claim(user1);
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(d1);
        assertGt(deposit.rewardPerTokenAtUnlock, 0);
        assertGe(pool.rewardPerToken(), deposit.rewardPerTokenAtUnlock);
    }

    function test_LockBoost_ClampsInterpolationAtPeriodFinish() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime);
        _claim(user1);
        assertEq(pool.getDeposit(d1).rewardPerTokenAtUnlock, pool.rewardPerToken());
    }

    function test_LockBoost_ResumesAfterCrossPeriodNotifyBeforeUnlock() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(block.timestamp + REWARDS_DURATION + 1 days);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        assertGt(pool.earnedByDeposit(d1).pendingBoostReward, 0);
    }

    function test_PRD_EarnedByDepositAfterUnlockBeforeStateUpdateShowsClaimableBoost() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime);
        IStakingPoolV2Types.DepositView memory depositBefore = pool.getDeposit(d1);
        assertFalse(depositBefore.boostSettled);

        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(d1);
        assertTrue(reward.boostClaimable);
        assertGt(reward.claimableBoostReward, 0);
        assertEq(reward.pendingBoostReward, reward.claimableBoostReward);
    }

    function test_PRD_EarnedByDepositMatureBoostMatchesNextClaimAllPayout() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime);

        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(d1);
        uint256 balanceBeforeClaim = rewardToken.balanceOf(user1);
        _claim(user1);

        assertApproxEqAbs(
            rewardToken.balanceOf(user1) - balanceBeforeClaim,
            reward.baseReward + reward.claimableBoostReward,
            ROUNDING_TOLERANCE
        );
        assertTrue(pool.getDeposit(d1).boostSettled);
    }

    function test_LockBoost_MaturitySettlementRunsWhenRewardDeltaIsZero() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(block.timestamp + REWARDS_DURATION);
        _claim(user1);
        IStakingPoolV2Types.DepositView memory depositBeforeUnlock = pool.getDeposit(d1);
        assertFalse(depositBeforeUnlock.boostSettled);
        assertGt(depositBeforeUnlock.pendingBoostReward, 0);

        uint256 balanceBeforeMatureClaim = rewardToken.balanceOf(user1);
        vm.warp(depositBeforeUnlock.unlockTime);
        _claim(user1);

        IStakingPoolV2Types.DepositView memory depositAfterClaim = pool.getDeposit(d1);
        assertTrue(depositAfterClaim.boostSettled);
        assertEq(depositAfterClaim.pendingBoostReward, 0);
        assertEq(rewardToken.balanceOf(user1) - balanceBeforeMatureClaim, depositBeforeUnlock.pendingBoostReward);
    }

    // ------------------------------------------------------------------
    // 10. claimAll 领取奖励
    // ------------------------------------------------------------------

    function test_EarnedAndEarnedByDeposit_ReturnExpectedClaimableBreakdown() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        uint256 d1 = _stake(user2, 100 ether, SHORT_LOCK, user1);
        vm.warp(block.timestamp + 1 days);
        _stake(user2, 1 ether, 0, address(0));
        IStakingPoolV2Types.DepositRewardView memory reward = pool.earnedByDeposit(d1);
        assertApproxEqAbs(reward.baseReward, _expectedReward(1_000 ether, 1 days, 100 ether, 200 ether), ROUNDING_TOLERANCE);
        assertApproxEqAbs(reward.inviteeBoostReward, (reward.baseReward * INVITEE_BOOST) / BPS, ROUNDING_TOLERANCE);
        assertApproxEqAbs(reward.pendingBoostReward, (reward.baseReward * SHORT_BOOST) / BPS, ROUNDING_TOLERANCE);
        assertEq(reward.claimableBoostReward, 0);
        assertApproxEqAbs(pool.earned(user2), reward.baseReward + reward.inviteeBoostReward, ROUNDING_TOLERANCE);
    }

    function test_PRD_EarnedMatchesNextClaimAllPayoutBeforeSettlementWithInviter() public {
        _stake(user1, 100 ether, 0, address(0));
        uint256 depositId = _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);

        IStakingPoolV2Types.DepositView memory depositBefore = pool.getDeposit(depositId);
        assertEq(depositBefore.pendingBaseReward, 0);
        assertEq(depositBefore.pendingInviteeBoostReward, 0);

        uint256 earnedBeforeClaim = pool.earned(user2);
        uint256 balanceBeforeClaim = rewardToken.balanceOf(user2);
        _claim(user2);

        assertApproxEqAbs(rewardToken.balanceOf(user2) - balanceBeforeClaim, earnedBeforeClaim, ROUNDING_TOLERANCE);
    }

    function test_ClaimAll_PaysBaseInviteeBoostReferralAndMatureBoost() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(10_000 ether);
        uint256 d2 = _stake(user2, 100 ether, SHORT_LOCK, user1);
        vm.warp(pool.getDeposit(d2).unlockTime);
        _claim(user2);
        assertGt(rewardToken.balanceOf(user2), 0);
        assertGt(pool.claimableReferralReward(user1), 0);
        _claim(user1);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_ClaimAll_DoesNotPayUnmaturedBoost() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        uint256 pendingBoost = pool.earnedByDeposit(d1).pendingBoostReward;
        _claim(user1);
        assertEq(pool.getDeposit(d1).pendingBoostReward, pendingBoost);
    }

    function test_ClaimAll_ReducesBaseReserveSubsidyReserveAndPendingSubsidy() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        _stake(user2, 100 ether, 0, user1);
        vm.warp(block.timestamp + 1 days);
        _stake(user2, 1 ether, 0, address(0));
        uint256 baseBefore = pool.baseRewardReserve();
        uint256 subsidyBefore = pool.subsidyReserve();
        uint256 pendingBefore = pool.totalPendingSubsidy();
        _claim(user2);
        assertLt(pool.baseRewardReserve(), baseBefore);
        assertLt(pool.subsidyReserve(), subsidyBefore);
        assertLt(pool.totalPendingSubsidy(), pendingBefore);
    }

    function test_ClaimAll_ClearsClaimedPendingRewards() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        IStakingPoolV2Types.DepositView memory deposit = pool.getDeposit(1);
        assertEq(deposit.pendingBaseReward, 0);
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_ClaimAll_CannotDoublePay() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        uint256 balanceAfterFirst = rewardToken.balanceOf(user1);
        _claim(user1);
        assertEq(rewardToken.balanceOf(user1), balanceAfterFirst);
    }

    function test_PRD_ClaimAllDoesNotWriteRewardCheckpoint() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        vm.recordLogs();
        _claim(user1);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 checkpointTopic = keccak256("RewardCheckpointWritten(uint256,uint256,uint256,uint256,bool)");
        for (uint256 i; i < entries.length; ++i) {
            assertTrue(entries[i].topics[0] != checkpointTopic);
        }
    }

    // ------------------------------------------------------------------
    // 11. withdraw 单仓位退出
    // ------------------------------------------------------------------

    function test_Withdraw_RevertWhenDepositMissingClosedOrNotOwner() public {
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.DepositDoesNotExist.selector);
        pool.withdraw(999);
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        vm.prank(user2);
        vm.expectRevert(IStakingPoolV2Errors.NotDepositOwner.selector);
        pool.withdraw(d1);
        _withdraw(user1, d1);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.DepositAlreadyClosed.selector);
        pool.withdraw(d1);
    }

    function test_Withdraw_FlexibleDepositReturnsFullPrincipalAndCloses() public {
        uint256 beforeBalance = stakingToken.balanceOf(user1);
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        _withdraw(user1, d1);
        assertEq(stakingToken.balanceOf(user1), beforeBalance);
        assertEq(pool.getDeposit(d1).amount, 0);
        assertEq(pool.getActiveDepositIds(user1).length, 0);
    }

    function test_Withdraw_MatureLockedDepositReturnsFullPrincipalAndPaysRewards() public {
        _notify(1_000 ether);
        uint256 beforeBalance = stakingToken.balanceOf(user1);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime);
        _withdraw(user1, d1);
        assertEq(stakingToken.balanceOf(user1), beforeBalance);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_Withdraw_EarlyLockedDepositAppliesPenaltyAndPaysTreasury() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        _withdraw(user1, d1);
        assertEq(stakingToken.balanceOf(treasury), 20 ether);
    }

    function test_Withdraw_EarlyLockedDepositForfeitsUnmaturedBoost() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        uint256 pendingBefore = pool.totalPendingSubsidy();
        uint256 reserveBefore = pool.subsidyReserve();
        _withdraw(user1, d1);
        assertLt(pool.totalPendingSubsidy(), pendingBefore);
        assertEq(pool.subsidyReserve(), reserveBefore);
    }

    function test_Withdraw_PaysBaseInviteeAndReferralRewards() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        uint256 d2 = _stake(user2, 100 ether, 0, user1);
        vm.warp(block.timestamp + 1 days);
        _withdraw(user2, d2);
        assertGt(rewardToken.balanceOf(user2), 0);
        _claim(user1);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_Withdraw_RemovesDepositFromActiveListAndUpdatesTotals() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        uint256 d2 = _stake(user1, 200 ether, 0, address(0));
        _withdraw(user1, d1);
        assertEq(pool.totalSupply(), 200 ether);
        assertEq(pool.totalStakedOf(user1), 200 ether);
        uint256[] memory expected = new uint256[](1);
        expected[0] = d2;
        _assertActiveIds(user1, expected);
    }

    function test_Withdraw_WritesRewardCheckpoint() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        vm.warp(block.timestamp + 1);
        vm.expectEmit(true, false, false, true);
        emit RewardCheckpointWritten(block.timestamp, 0, 0, 1, false);
        _withdraw(user1, d1);
    }

    // ------------------------------------------------------------------
    // 12. withdrawMultiple 与 exit
    // ------------------------------------------------------------------

    function test_WithdrawMultiple_RevertWhenIdsEmptyTooManyDuplicateOrInvalid() public {
        uint256[] memory empty = new uint256[](0);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.EmptyDepositIds.selector);
        pool.withdrawMultiple(empty);

        uint256[] memory tooMany = new uint256[](51);
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.TooManyDepositIds.selector);
        pool.withdrawMultiple(tooMany);

        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        uint256[] memory duplicated = new uint256[](2);
        duplicated[0] = d1;
        duplicated[1] = d1;
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.DuplicateDepositId.selector);
        pool.withdrawMultiple(duplicated);

        uint256[] memory invalid = new uint256[](1);
        invalid[0] = 999;
        vm.prank(user1);
        vm.expectRevert(IStakingPoolV2Errors.DepositDoesNotExist.selector);
        pool.withdrawMultiple(invalid);
    }

    function test_WithdrawMultiple_WithdrawsMixedDepositsAndAggregatesAccounting() public {
        _notify(2_000 ether);
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        uint256 d2 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        uint256 d3 = _stake(user1, 100 ether, LONG_LOCK, address(0));
        vm.warp(pool.getDeposit(d2).unlockTime);
        uint256[] memory ids = new uint256[](3);
        ids[0] = d1;
        ids[1] = d2;
        ids[2] = d3;
        _withdrawMultiple(user1, ids);
        assertEq(pool.totalStakedOf(user1), 0);
        assertEq(stakingToken.balanceOf(treasury), 20 ether);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_WithdrawMultiple_RemovesOnlySpecifiedDeposits() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        uint256 d2 = _stake(user1, 100 ether, 0, address(0));
        uint256 d3 = _stake(user1, 100 ether, 0, address(0));
        uint256[] memory ids = new uint256[](2);
        ids[0] = d1;
        ids[1] = d3;
        _withdrawMultiple(user1, ids);
        uint256[] memory expected = new uint256[](1);
        expected[0] = d2;
        _assertActiveIds(user1, expected);
    }

    function test_WithdrawMultiple_EmitsPerDepositEvents() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        uint256 d2 = _stake(user1, 100 ether, 0, address(0));
        uint256[] memory ids = new uint256[](2);
        ids[0] = d1;
        ids[1] = d2;
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(user1, d1, 100 ether);
        vm.expectEmit(true, true, false, true);
        emit DepositClosed(user1, d1);
        vm.expectEmit(true, true, false, true);
        emit Withdrawn(user1, d2, 100 ether);
        vm.expectEmit(true, true, false, true);
        emit DepositClosed(user1, d2);
        _withdrawMultiple(user1, ids);
    }

    function test_Exit_WithNoDepositsStillClaimsReferralReward() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);
        assertGt(pool.claimableReferralReward(user1), 0);
        _exit(user1);
        assertEq(pool.claimableReferralReward(user1), 0);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_Exit_WithOnlyReferralRewardDoesNotWriteCheckpoint() public {
        uint256 depositId = _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user2);
        _withdraw(user1, depositId);

        assertEq(pool.getActiveDepositIds(user1).length, 0);
        assertGt(pool.claimableReferralReward(user1), 0);
        vm.recordLogs();
        _exit(user1);
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 checkpointTopic = keccak256("RewardCheckpointWritten(uint256,uint256,uint256,uint256,bool)");
        for (uint256 i; i < entries.length; ++i) {
            assertTrue(entries[i].topics[0] != checkpointTopic);
        }
        assertEq(pool.claimableReferralReward(user1), 0);
    }

    function test_Exit_WithdrawsAllActiveDepositsAndDoesNotAffectOthers() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user1, 200 ether, 0, address(0));
        _stake(user2, 300 ether, 0, address(0));
        _exit(user1);
        assertEq(pool.getActiveDepositIds(user1).length, 0);
        assertEq(pool.totalStakedOf(user1), 0);
        assertEq(pool.totalStakedOf(user2), 300 ether);
    }

    function test_Exit_DoesNotSkipDepositsWhenActiveListShrinksDuringLoop() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user1, 200 ether, 0, address(0));
        _stake(user1, 300 ether, 0, address(0));
        _exit(user1);
        assertEq(pool.getActiveDepositIds(user1).length, 0);
        assertEq(pool.totalStakedOf(user1), 0);
    }

    // ------------------------------------------------------------------
    // 13. 补贴清扫与资产覆盖
    // ------------------------------------------------------------------

    function test_MaxSweepableSubsidy_ReturnsReserveMinusPendingAndUnsettled() public {
        _notify(1_000 ether);
        assertEq(pool.maxSweepableSubsidy(), 0);
        vm.warp(block.timestamp + REWARDS_DURATION);
        assertApproxEqAbs(pool.maxSweepableSubsidy(), _expectedSubsidy(1_000 ether), ROUNDING_TOLERANCE);
    }

    function test_MaxSweepableSubsidy_AccountsForZeroSupplyAttritionInView() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        assertApproxEqAbs(pool.maxSweepableSubsidy(), _expectedSubsidy(100 ether), ROUNDING_TOLERANCE);
    }

    function test_SweepSubsidy_RevertWhenToZeroAmountZeroOrExceedsSweepable() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.sweepSubsidy(address(0), 1 ether);
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.AmountMustBeGreaterThanZero.selector);
        pool.sweepSubsidy(receiver, 0);
        uint256 impossibleAmount = pool.subsidyReserve() + 1;
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.InsufficientSweepableSubsidy.selector);
        pool.sweepSubsidy(receiver, impossibleAmount);
    }

    function test_SweepSubsidy_ReducesReserveAndTransfersRewardToken() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + REWARDS_DURATION);
        uint256 sweepable = pool.maxSweepableSubsidy();
        uint256 reserveBefore = pool.subsidyReserve();
        vm.prank(admin);
        pool.sweepSubsidy(receiver, sweepable);
        assertEq(pool.subsidyReserve(), reserveBefore - sweepable);
        assertEq(rewardToken.balanceOf(receiver), sweepable);
    }

    function test_SweepSubsidy_SyncsZeroSupplyAttritionBeforeSweep() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        uint256 sweepable = pool.maxSweepableSubsidy();
        vm.prank(admin);
        pool.sweepSubsidy(receiver, sweepable);
        assertApproxEqAbs(pool.unsettledMaxSubsidyLiability(), _expectedSubsidy(900 ether), ROUNDING_TOLERANCE);
    }

    function test_SweepSubsidy_DoesNotBreakSubsidyCoverage() public {
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        uint256 sweepable = pool.maxSweepableSubsidy();
        vm.prank(admin);
        pool.sweepSubsidy(receiver, sweepable);
        assertGe(pool.subsidyReserve(), pool.totalPendingSubsidy() + pool.unsettledMaxSubsidyLiability());
    }

    function test_SweepExpiredBaseReward_ReleasesRoundingDustAndSubsidyLiability() public {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(address(stakingToken), address(rewardToken));
        params.rewardsDuration = 1;
        StakingPool dustPool = _deployWithParams(params);
        _fundAndApproveDefault(dustPool, stakingToken, rewardToken);

        vm.prank(user1);
        dustPool.stake(1 wei, 0, address(0));
        vm.prank(user2);
        dustPool.stake(1 wei, 0, address(0));
        vm.prank(user3);
        dustPool.stake(1 wei, 0, address(0));
        vm.prank(operator);
        dustPool.notifyRewardAmount(2 wei);

        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        dustPool.withdraw(1);
        vm.prank(user2);
        dustPool.withdraw(2);
        vm.prank(user3);
        dustPool.withdraw(3);

        assertEq(dustPool.totalSupply(), 0);
        assertEq(dustPool.baseRewardReserve(), 2 wei);
        assertEq(dustPool.unsettledMaxSubsidyLiability(), 1 wei);

        uint256 receiverBefore = rewardToken.balanceOf(receiver);
        vm.prank(admin);
        dustPool.sweepExpiredBaseReward(receiver);

        assertEq(dustPool.baseRewardReserve(), 0);
        assertEq(dustPool.unsettledMaxSubsidyLiability(), 0);
        assertEq(dustPool.maxSweepableSubsidy(), 1 wei);
        assertEq(rewardToken.balanceOf(receiver) - receiverBefore, 2 wei);
    }

    function test_AssetCoverage_DistinctTokensCoversPrincipalBaseAndSubsidy() public {
        _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        assertGe(stakingToken.balanceOf(address(pool)), pool.totalSupply());
        assertGe(rewardToken.balanceOf(address(pool)), pool.baseRewardReserve() + pool.subsidyReserve());
    }

    function test_AssetCoverage_SameTokenCoversPrincipalBaseAndSubsidyTogether() public {
        MockERC20 sameToken = new MockERC20("Same", "SAME", 18);
        StakingPool samePool = _deployDefault(address(sameToken), address(sameToken), operator, treasury);
        sameToken.mint(user1, 1_000 ether);
        vm.prank(user1);
        sameToken.approve(address(samePool), type(uint256).max);
        sameToken.mint(operator, 10_000 ether);
        vm.prank(operator);
        sameToken.approve(address(samePool), type(uint256).max);
        vm.prank(user1);
        samePool.stake(100 ether, 0, address(0));
        vm.prank(operator);
        samePool.notifyRewardAmount(1_000 ether);
        assertGe(sameToken.balanceOf(address(samePool)), samePool.totalSupply() + samePool.baseRewardReserve() + samePool.subsidyReserve());
    }

    function test_AssetCoverage_RevertWhenCoverageIsBroken() public {
        // MockERC20 不提供任意扣余额能力；用同币池提前罚金路径覆盖资产桶扣减后的偿付校验。
        MockERC20 sameToken = new MockERC20("Same", "SAME", 18);
        StakingPool samePool = _deployDefault(address(sameToken), address(sameToken), operator, treasury);
        sameToken.mint(user1, 1_000 ether);
        vm.prank(user1);
        sameToken.approve(address(samePool), type(uint256).max);
        sameToken.mint(operator, 10_000 ether);
        vm.prank(operator);
        sameToken.approve(address(samePool), type(uint256).max);
        vm.prank(operator);
        samePool.notifyRewardAmount(1_000 ether);
        vm.prank(user1);
        uint256 d1 = samePool.stake(100 ether, SHORT_LOCK, address(0));
        vm.prank(user1);
        samePool.withdraw(d1);
        assertGe(sameToken.balanceOf(address(samePool)), samePool.totalSupply() + samePool.baseRewardReserve() + samePool.subsidyReserve());
    }

    // ------------------------------------------------------------------
    // 14. Treasury 与 Recover
    // ------------------------------------------------------------------

    function test_SetTreasury_RevertWhenNewTreasuryZero() public {
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.setTreasury(address(0));
    }

    function test_SetTreasury_UpdatesTreasuryForFuturePenalties() public {
        address newTreasury = address(0xABCD);
        vm.prank(admin);
        pool.setTreasury(newTreasury);
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        _withdraw(user1, d1);
        assertEq(stakingToken.balanceOf(newTreasury), 20 ether);
    }

    function test_RecoverERC20_RevertWhenTokenZeroAmountZeroOrCoreToken() public {
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.AddressCannotBeZero.selector);
        pool.recoverERC20(address(0), 1 ether);
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.AmountMustBeGreaterThanZero.selector);
        pool.recoverERC20(address(otherToken), 0);
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.CannotRecoverCoreToken.selector);
        pool.recoverERC20(address(stakingToken), 1 ether);
        vm.prank(admin);
        vm.expectRevert(IStakingPoolV2Errors.CannotRecoverCoreToken.selector);
        pool.recoverERC20(address(rewardToken), 1 ether);
    }

    function test_RecoverERC20_TransfersNonCoreTokenToAdmin() public {
        uint256 beforeBalance = otherToken.balanceOf(admin);
        vm.prank(admin);
        pool.recoverERC20(address(otherToken), 100 ether);
        assertEq(otherToken.balanceOf(admin) - beforeBalance, 100 ether);
    }

    // ------------------------------------------------------------------
    // 15. P0 流程集成
    // ------------------------------------------------------------------

    function test_Flow_FlexibleStakeNotifyClaimWithdraw() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user1);
        assertApproxEqAbs(rewardToken.balanceOf(user1), 100 ether, ROUNDING_TOLERANCE);
        _withdraw(user1, d1);
        assertEq(pool.totalStakedOf(user1), 0);
    }

    function test_Flow_LockedStakeMatureClaimAndWithdraw() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(pool.getDeposit(d1).unlockTime);
        _claim(user1);
        _withdraw(user1, d1);
        assertEq(pool.totalStakedOf(user1), 0);
        assertGt(rewardToken.balanceOf(user1), 0);
    }

    function test_Flow_LockedStakeEarlyWithdrawForfeitsBoostAndPaysPenalty() public {
        _notify(1_000 ether);
        uint256 d1 = _stake(user1, 100 ether, SHORT_LOCK, address(0));
        vm.warp(block.timestamp + 1 days);
        _stake(user1, 1 ether, 0, address(0));
        _withdraw(user1, d1);
        assertEq(stakingToken.balanceOf(treasury), 20 ether);
        assertEq(pool.getDeposit(d1).pendingBoostReward, 0);
    }

    function test_Flow_ThreeLevelReferralAccrueAndClaim() public {
        _stake(user1, 100 ether, 0, address(0));
        _stake(user2, 100 ether, 0, user1);
        _stake(user3, 100 ether, 0, user2);
        _stake(user4, 100 ether, 0, user3);
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        _claim(user4);
        _claim(user3);
        _claim(user2);
        _claim(user1);
        assertGt(rewardToken.balanceOf(user1), 0);
        assertGt(rewardToken.balanceOf(user2), 0);
        assertGt(rewardToken.balanceOf(user3), 0);
        assertGt(rewardToken.balanceOf(user4), 0);
    }

    function test_Flow_MultipleUsersDifferentEntryAndExitTimes() public {
        uint256 d1 = _stake(user1, 100 ether, 0, address(0));
        _notify(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        uint256 d2 = _stake(user2, 100 ether, 0, address(0));
        vm.warp(block.timestamp + 1 days);
        _withdraw(user1, d1);
        vm.warp(block.timestamp + 1 days);
        _withdraw(user2, d2);
        assertGt(rewardToken.balanceOf(user1), 0);
        assertGt(rewardToken.balanceOf(user2), 0);
    }

    function test_Flow_SameTokenPoolNotifyStakeClaimWithdraw() public {
        MockERC20 sameToken = new MockERC20("Same", "SAME", 18);
        StakingPool samePool = _deployDefault(address(sameToken), address(sameToken), operator, treasury);
        sameToken.mint(user1, 1_000 ether);
        vm.prank(user1);
        sameToken.approve(address(samePool), type(uint256).max);
        sameToken.mint(operator, 10_000 ether);
        vm.prank(operator);
        sameToken.approve(address(samePool), type(uint256).max);
        vm.prank(user1);
        uint256 d1 = samePool.stake(100 ether, 0, address(0));
        vm.prank(operator);
        samePool.notifyRewardAmount(1_000 ether);
        vm.warp(block.timestamp + 1 days);
        vm.prank(user1);
        samePool.claimAll();
        vm.prank(user1);
        samePool.withdraw(d1);
        assertEq(samePool.totalStakedOf(user1), 0);
    }
}