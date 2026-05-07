// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../src/staking.sol";
import "../src/interface.sol";
import "./mocks/MockERC20.sol";

contract FeeOnTransferMockERC20 is MockERC20 {
    uint256 public immutable feeBps;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint256 _feeBps
    ) MockERC20(_name, _symbol, _decimals) {
        feeBps = _feeBps;
    }

    function transfer(
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 received = amount - fee;

        require(
            balanceOf[msg.sender] >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += received;
        totalSupply -= fee;
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 received = amount - fee;

        require(
            balanceOf[from] >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        require(
            allowance[from][msg.sender] >= amount,
            "ERC20: insufficient allowance"
        );
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += received;
        totalSupply -= fee;
        return true;
    }
}

contract V1DeploymentConfigPolicy {
    function validatePoolTokens(
        address _stakingToken,
        address _rewardToken,
        bool stakingTokenIsFeeOnTransfer,
        bool rewardTokenIsFeeOnTransfer
    ) external pure {
        if (_stakingToken == address(0) || _rewardToken == address(0)) {
            revert IStakingPool.AddressCannotBeZero();
        }
        if (stakingTokenIsFeeOnTransfer || rewardTokenIsFeeOnTransfer) {
            revert IStakingPool.FeeOnTransferNotSupported();
        }
    }
}

contract StakingPoolTest is Test {
    StakingPool public pool;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    MockERC20 public usdc;

    address public admin = address(this);
    address public operator = address(this);
    address public user1 = address(0x111);
    address public user2 = address(0x222);

    // Events to test
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address indexed token, uint256 amount);
    event RoleAdminChanged(
        bytes32 indexed role,
        bytes32 indexed previousAdminRole,
        bytes32 indexed newAdminRole
    );
    event RoleGranted(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevoked(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event Paused(address account);
    event Unpaused(address account);

    function setUp() public {
        stakingToken = new MockERC20("Staking Token", "STK", 18);
        rewardToken = new MockERC20("Reward Token", "REWARD", 18);
        usdc = new MockERC20("USDC", "USDC", 18);

        pool = new StakingPool(
            address(stakingToken),
            address(rewardToken),
            admin,
            operator
        );

        // Mint initial tokens
        stakingToken.mint(user1, 1000 ether);
        stakingToken.mint(user2, 1000 ether);
        rewardToken.mint(operator, 100000 ether);
        usdc.mint(user1, 1000 ether);

        // Operator approves pool to take reward tokens
        rewardToken.approve(address(pool), type(uint256).max);

        // Users approve pool
        vm.startPrank(user1);
        stakingToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        vm.startPrank(user2);
        stakingToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();

        // Initialize reward duration
        pool.setRewardsDuration(7 days);
    }

    // ------------------------------------------------------------------
    // 0. Constructor & Views (构造与视图)
    // ------------------------------------------------------------------
    function test_RevertWhen_ConstructorWithRequiredZeroAddress() public {
        vm.expectRevert(IStakingPool.AddressCannotBeZero.selector);
        new StakingPool(address(0), address(rewardToken), admin, operator);

        vm.expectRevert(IStakingPool.AddressCannotBeZero.selector);
        new StakingPool(address(stakingToken), address(0), admin, operator);

        vm.expectRevert(IStakingPool.AddressCannotBeZero.selector);
        new StakingPool(
            address(stakingToken),
            address(rewardToken),
            address(0),
            operator
        );
    }

    function test_ConstructorAllowsZeroOperator() public {
        StakingPool newPool = new StakingPool(
            address(stakingToken),
            address(rewardToken),
            admin,
            address(0)
        );

        assertFalse(newPool.hasRole(newPool.OPERATOR_ROLE(), address(0)));
    }

    function test_RevertWhen_BalanceOfZeroAddress() public {
        vm.expectRevert(IStakingPool.AddressCannotBeZero.selector);
        pool.balanceOf(address(0));
    }

    function test_RevertWhen_EarnedZeroAddress() public {
        vm.expectRevert(IStakingPool.AddressCannotBeZero.selector);
        pool.earned(address(0));
    }

    function test_RevertWhen_RecoverZeroAddressOrZeroAmount() public {
        vm.expectRevert(IStakingPool.AddressCannotBeZero.selector);
        pool.recoverERC20(address(0), 100 ether);

        vm.expectRevert(IStakingPool.AmountMustBeGreaterThanZero.selector);
        pool.recoverERC20(address(usdc), 0);
    }

    function test_ViewFunctions_RewardPerTokenAndLastTimeRewardApplicable()
        public
        view
    {
        pool.rewardPerToken();
        pool.lastTimeRewardApplicable();
    }

    // ------------------------------------------------------------------
    // 1. Staking (资金存入)
    // ------------------------------------------------------------------
    function test_UserSuccessfullyStakesTokensForFirstTime() public {
        // Given user has 100 STK in wallet and approved, and 0 staked
        assertEq(stakingToken.balanceOf(user1), 1000 ether);
        assertEq(pool.balanceOf(user1), 0);

        // When user calls stake with 100 STK
        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit Staked(user1, 100 ether);
        pool.stake(100 ether);
        vm.stopPrank();

        // Then staked balance should increase to 100
        assertEq(pool.balanceOf(user1), 100 ether);
        // And total supply of pool should increase by 100
        assertEq(pool.totalSupply(), 100 ether);
        // User's STK balance should decrease
        assertEq(stakingToken.balanceOf(user1), 900 ether);
        assertEq(stakingToken.balanceOf(address(pool)), 100 ether);
    }

    function test_UserStakesAdditionalTokensAndTriggersRewardSettlement()
        public
    {
        // Start a reward period first to have rewards
        pool.notifyRewardAmount(7000 ether); // 7000 REWARD for 7 days -> 1000/day

        // Given a user has already staked 100 STK
        vm.prank(user1);
        pool.stake(100 ether);

        // Advance time to accumulate rewards
        vm.warp(block.timestamp + 1 days);
        uint256 pendingRewardBefore = pool.earned(user1);

        vm.prank(user1);
        pool.stake(50 ether);

        // Then user's staked balance should become 150
        assertEq(pool.balanceOf(user1), 150 ether);
        // And total supply increases to 150
        assertEq(pool.totalSupply(), 150 ether);

        // And pending rewards should be saved and accessible
        assertEq(pool.earned(user1), pendingRewardBefore);
    }

    function test_RevertWhen_UserAttemptsToStake0Tokens() public {
        vm.prank(user1);
        vm.expectRevert(IStakingPool.AmountMustBeGreaterThanZero.selector);
        pool.stake(0);
    }

    // ------------------------------------------------------------------
    // 2. Withdrawing (提取本金)
    // ------------------------------------------------------------------
    function test_UserSuccessfullyWithdrawsPortionOfStakedTokens() public {
        vm.prank(user1);
        pool.stake(100 ether);

        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit Withdrawn(user1, 40 ether);
        pool.withdraw(40 ether);
        vm.stopPrank();

        assertEq(pool.balanceOf(user1), 60 ether);
        assertEq(pool.totalSupply(), 60 ether);
        // Staking balance returns to wallet
        assertEq(stakingToken.balanceOf(user1), 940 ether);
    }

    function test_RevertWhen_UserAttemptsToWithdrawMoreThanStakedBalance()
        public
    {
        vm.prank(user1);
        pool.stake(100 ether);

        vm.prank(user1);
        vm.expectRevert(IStakingPool.InsufficientBalance.selector);
        pool.withdraw(150 ether);
    }

    function test_RevertWhen_UserAttemptsToWithdraw0Tokens() public {
        vm.prank(user1);
        pool.stake(100 ether);

        vm.prank(user1);
        vm.expectRevert(IStakingPool.AmountMustBeGreaterThanZero.selector);
        pool.withdraw(0);
    }

    // ------------------------------------------------------------------
    // 3. Claiming Rewards (领取收益)
    // ------------------------------------------------------------------
    function test_UserSuccessfullyClaimsAccumulatedRewards() public {
        pool.notifyRewardAmount(7000 ether);

        vm.prank(user1);
        pool.stake(100 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 earned = pool.earned(user1);

        vm.startPrank(user1);
        vm.expectEmit(true, false, false, true);
        emit RewardPaid(user1, earned);
        pool.getReward();
        vm.stopPrank();

        assertEq(pool.earned(user1), 0);
        assertEq(rewardToken.balanceOf(user1), earned);
    }

    // ------------------------------------------------------------------
    // 4. Exiting (一键退出)
    // ------------------------------------------------------------------
    function test_UserUsesExitFunctionToWithdrawAllAndClaimRewards() public {
        pool.notifyRewardAmount(7000 ether);

        vm.prank(user1);
        pool.stake(100 ether);

        vm.warp(block.timestamp + 1 days);
        uint256 earnedBeforeExit = pool.earned(user1);

        vm.prank(user1);
        pool.exit();

        assertEq(pool.balanceOf(user1), 0);
        assertEq(pool.earned(user1), 0);
        assertEq(stakingToken.balanceOf(user1), 1000 ether);
        assertEq(rewardToken.balanceOf(user1), earnedBeforeExit);
    }

    function test_ExitOnlyClaimsRewardWhenPrincipalIsZero() public {
        vm.prank(user1);
        pool.stake(100 ether);
        pool.notifyRewardAmount(7000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user1);
        pool.withdraw(100 ether);

        uint256 settledReward = pool.earned(user1);
        assertEq(pool.balanceOf(user1), 0);
        assertGt(settledReward, 0);

        vm.prank(user1);
        pool.exit();

        assertEq(pool.earned(user1), 0);
        assertEq(rewardToken.balanceOf(user1), settledReward);
    }

    // ------------------------------------------------------------------
    // 5. Operator Reward Injection (运营注入奖励)
    // ------------------------------------------------------------------
    function test_OperatorStartsNewRewardPeriod() public {
        // Contract must hold at least 7000 REWARD
        vm.expectEmit(false, false, false, true);
        emit RewardAdded(7000 ether);
        pool.notifyRewardAmount(7000 ether);

        assertEq(pool.rewardRate(), (uint256(7000 ether) * 1e18) / 7 days);
    }

    function test_NotifyRewardAmountAtPeriodFinishStartsFreshPeriod() public {
        pool.notifyRewardAmount(7000 ether);

        uint256 firstPeriodFinish = pool.periodFinish();
        vm.warp(firstPeriodFinish);

        pool.notifyRewardAmount(14000 ether);

        assertEq(pool.periodFinish(), firstPeriodFinish + 7 days);
        assertEq(pool.rewardRate(), (uint256(14000 ether) * 1e18) / 7 days);
    }

    function test_OperatorInjectsRewardsBeforeCurrentPeriodEnds_RewardSmoothing()
        public
    {
        pool.notifyRewardAmount(7000 ether);

        // Fast forward 4 days (3 days remaining)
        vm.warp(block.timestamp + 4 days);

        // Remaining reward is for 3 days = 3000 REWARD
        // Operator injects 4000 more
        pool.notifyRewardAmount(4000 ether);

        // The new rate should be (3000 + 4000) / 7 days = 1000 REWARD/day
        assertApproxEqAbs(
            pool.rewardRate(),
            (uint256(7000 ether) * 1e18) / 7 days,
            1e14
        );
    }

    function test_RevertWhen_OperatorAttemptsToInjectRewardsWithoutSufficientApprovalOrBalance()
        public
    {
        // Reset operator approval to 1000 REWARD
        rewardToken.approve(address(pool), 1000 ether);

        vm.expectRevert(); // "ERC20: insufficient allowance"
        pool.notifyRewardAmount(5000 ether);
    }

    function test_RevertWhen_OperatorAttemptsToInject0Rewards() public {
        vm.expectRevert(IStakingPool.RewardAmountCannotBeZero.selector);
        pool.notifyRewardAmount(0);
    }

    function test_RevertWhen_OperatorAttemptsToInjectRewardsWhenDurationIsNotSet()
        public
    {
        // Create a new pool where duration is initially 0
        StakingPool newPool = new StakingPool(
            address(stakingToken),
            address(rewardToken),
            admin,
            operator
        );
        
        vm.expectRevert(IStakingPool.RewardsDurationCannotBeZero.selector);
        newPool.notifyRewardAmount(1000 ether);
    }

    // ------------------------------------------------------------------
    // 6. Reward Leakage (空窗期奖励归属)
    // ------------------------------------------------------------------
    function test_RewardsLeakAndPermanentlyStayInContractWhenTotalSupplyIsZero()
        public
    {
        pool.notifyRewardAmount(7000 ether);
        
        assertEq(pool.totalSupply(), 0);

        // 1 day passes, 1000 REWARD leaks
        vm.warp(block.timestamp + 1 days);

        // User stakes
        vm.prank(user1);
        pool.stake(100 ether);

        // 1 more day passes
        vm.warp(block.timestamp + 1 days);

        // User should only get rewards for the 2nd day (approx 1000)
        assertApproxEqAbs(pool.earned(user1), 1000 ether, 1e16);
        
        // Fast forward to end of reward period
        vm.warp(block.timestamp + 10 days);
        
        // User claims
        vm.prank(user1);
        pool.getReward();
        
        // The leaked 1000 REWARD should still be in the contract and unreachable
        uint256 expectedLeaked = 1000 ether;
        assertGe(rewardToken.balanceOf(address(pool)), expectedLeaked);
    }

    function test_MultipleUsersStakingAtDifferentTimesSplitRewardsPrecisely()
        public
    {
        pool.setRewardsDuration(2 days);

        vm.prank(user1);
        pool.stake(100 ether);

        pool.notifyRewardAmount(2000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user2);
        pool.stake(100 ether);

        vm.warp(block.timestamp + 1 days);

        assertApproxEqAbs(pool.earned(user1), 1500 ether, 1e12);
        assertApproxEqAbs(pool.earned(user2), 500 ether, 1e12);
    }

    function test_SameTokenPoolPaysRewardsWithoutTouchingPrincipal() public {
        MockERC20 sameToken = new MockERC20("Same Token", "SAME", 18);
        StakingPool samePool = new StakingPool(
            address(sameToken),
            address(sameToken),
            admin,
            operator
        );

        sameToken.mint(user1, 100 ether);
        sameToken.mint(operator, 1000 ether);
        sameToken.approve(address(samePool), type(uint256).max);
        samePool.setRewardsDuration(1 days);

        vm.startPrank(user1);
        sameToken.approve(address(samePool), type(uint256).max);
        samePool.stake(100 ether);
        vm.stopPrank();

        samePool.notifyRewardAmount(1000 ether);
        vm.warp(block.timestamp + 1 days);

        uint256 earned = samePool.earned(user1);
        uint256 availableRewardBalance = sameToken.balanceOf(
            address(samePool)
        ) - samePool.totalSupply();
        uint256 remainingRewards = (samePool.rewardRate() *
            (samePool.periodFinish() - block.timestamp)) / 1e18;

        assertApproxEqAbs(earned, 1000 ether, 1e12);
        assertGe(availableRewardBalance, earned + remainingRewards);

        vm.prank(user1);
        samePool.getReward();

        vm.prank(user1);
        samePool.withdraw(100 ether);

        assertEq(samePool.balanceOf(user1), 0);
        assertApproxEqAbs(sameToken.balanceOf(user1), 1100 ether, 1e12);
        assertApproxEqAbs(sameToken.balanceOf(address(samePool)), 0, 1e12);
    }

    function test_SameTokenPoolKeepsLeakedRewardsAndPrincipalWithdrawable()
        public
    {
        MockERC20 sameToken = new MockERC20("Same Token", "SAME", 18);
        StakingPool samePool = new StakingPool(
            address(sameToken),
            address(sameToken),
            admin,
            operator
        );

        sameToken.mint(user1, 100 ether);
        sameToken.mint(operator, 2000 ether);
        sameToken.approve(address(samePool), type(uint256).max);
        samePool.setRewardsDuration(2 days);
        samePool.notifyRewardAmount(2000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user1);
        sameToken.approve(address(samePool), type(uint256).max);
        samePool.stake(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        uint256 earned = samePool.earned(user1);
        assertApproxEqAbs(earned, 1000 ether, 1e12);

        vm.prank(user1);
        samePool.getReward();

        vm.prank(user1);
        samePool.withdraw(100 ether);

        assertApproxEqAbs(sameToken.balanceOf(user1), 1100 ether, 1e12);
        assertApproxEqAbs(
            sameToken.balanceOf(address(samePool)),
            1000 ether,
            1e12
        );
    }

    // ------------------------------------------------------------------
    // 7. Admin Privileges & Risk Management (管理员特权与风控)
    // ------------------------------------------------------------------
    function test_GracefulDegradationDuringEmergencyPause() public {
        vm.prank(user1);
        pool.stake(100 ether);

        pool.pause();
        assertTrue(pool.paused());

        // Stake should revert
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        pool.stake(50 ether);

        // notifyRewardAmount should revert
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        pool.notifyRewardAmount(1000 ether);

        // setRewardsDuration should revert
        vm.expectRevert(abi.encodeWithSignature("EnforcedPause()"));
        pool.setRewardsDuration(14 days);

        // Withdraw should succeed
        vm.prank(user1);
        pool.withdraw(50 ether);
        assertEq(pool.balanceOf(user1), 50 ether);

        // GetReward should succeed
        vm.prank(user1);
        pool.getReward();
        
        pool.unpause();
        assertFalse(pool.paused());
        vm.prank(user1);
        pool.stake(10 ether);
        pool.pause();
        
        vm.prank(user1);
        pool.exit();
        assertEq(pool.balanceOf(user1), 0);
    }

    function test_PauseUnpauseRewardsDurationRecoveredAndRoleEvents() public {
        address newOperator = address(0x333);

        vm.expectEmit(true, true, true, true);
        emit RoleGranted(pool.OPERATOR_ROLE(), newOperator, admin);
        pool.grantRole(pool.OPERATOR_ROLE(), newOperator);

        vm.expectEmit(true, true, true, true);
        emit RoleRevoked(pool.OPERATOR_ROLE(), newOperator, admin);
        pool.revokeRole(pool.OPERATOR_ROLE(), newOperator);

        vm.expectEmit(false, false, false, true);
        emit RewardsDurationUpdated(14 days);
        pool.setRewardsDuration(14 days);

        vm.expectEmit(false, false, false, true);
        emit Paused(admin);
        pool.pause();

        vm.prank(user1);
        usdc.transfer(address(pool), 100 ether);

        vm.expectEmit(true, false, false, true);
        emit Recovered(address(usdc), 100 ether);
        pool.recoverERC20(address(usdc), 100 ether);

        vm.expectEmit(false, false, false, true);
        emit Unpaused(admin);
        pool.unpause();
    }

    function test_ConstructorEmitsAccessControlRoleAdminChangedEvent() public {
        bytes32 operatorRole = keccak256("OPERATOR_ROLE");

        vm.expectEmit(true, true, true, true);
        emit RoleGranted(bytes32(0), admin, admin);
        vm.expectEmit(true, true, true, true);
        emit RoleGranted(operatorRole, operator, admin);
        vm.expectEmit(true, true, true, true);
        emit RoleAdminChanged(operatorRole, bytes32(0), bytes32(0));

        new StakingPool(
            address(stakingToken),
            address(rewardToken),
            admin,
            operator
        );
    }

    function test_AdminRescuesAccidentallyTransferredTokens() public {
        // User accidentally transfers USDC
        vm.prank(user1);
        usdc.transfer(address(pool), 100 ether);

        assertEq(usdc.balanceOf(address(pool)), 100 ether);
        uint256 operatorUsdcBefore = usdc.balanceOf(operator);

        pool.recoverERC20(address(usdc), 100 ether);

        assertEq(usdc.balanceOf(address(pool)), 0);
        assertEq(usdc.balanceOf(operator), operatorUsdcBefore + 100 ether);
    }

    function test_RevertWhen_RecoverUnsupportedTokenBalanceIsInsufficient()
        public
    {
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        pool.recoverERC20(address(usdc), 1 ether);
    }

    function test_RevertWhen_AdminAttemptsToRescueStakingOrRewardTokens()
        public
    {
        // STK is protected
        vm.expectRevert(
            IStakingPool.CannotRecoverStakingOrRewardTokens.selector
        );
        pool.recoverERC20(address(stakingToken), 10 ether);

        // REWARD is protected
        vm.expectRevert(
            IStakingPool.CannotRecoverStakingOrRewardTokens.selector
        );
        pool.recoverERC20(address(rewardToken), 10 ether);
    }

    function test_RevertWhen_AdminAttemptsToSetRewardDurationTo0() public {
        vm.expectRevert(IStakingPool.RewardsDurationCannotBeZero.selector);
        pool.setRewardsDuration(0);
    }

    function test_RevertWhen_AdminAttemptsToChangeRewardDurationWhilePeriodIsActive()
        public
    {
        pool.notifyRewardAmount(7000 ether); // Starts an active period

        vm.expectRevert(
            IStakingPool
                .RewardsDurationCannotBeSetBeforeCurrentPeriodEnds
                .selector
        );
        pool.setRewardsDuration(14 days);
    }

    function test_SetRewardsDurationBoundaryAroundPeriodFinish() public {
        pool.notifyRewardAmount(7000 ether);
        uint256 finish = pool.periodFinish();

        vm.warp(finish - 1);
        vm.expectRevert(
            IStakingPool
                .RewardsDurationCannotBeSetBeforeCurrentPeriodEnds
                .selector
        );
        pool.setRewardsDuration(14 days);

        vm.warp(finish);
        vm.expectEmit(false, false, false, true);
        emit RewardsDurationUpdated(14 days);
        pool.setRewardsDuration(14 days);
        assertEq(pool.rewardsDuration(), 14 days);

        vm.warp(finish + 1);
        vm.expectEmit(false, false, false, true);
        emit RewardsDurationUpdated(21 days);
        pool.setRewardsDuration(21 days);
        assertEq(pool.rewardsDuration(), 21 days);
    }

    // ------------------------------------------------------------------
    // 8. Access Control & Roles (权限控制)
    // ------------------------------------------------------------------
    function test_RevertWhen_NonOperatorCallsNotifyRewardAmount() public {
        vm.prank(user1);
        vm.expectRevert(); // OpenZeppelin AccessControl error
        pool.notifyRewardAmount(1000 ether);
    }

    function test_RevertWhen_NonAdminCallsAdminFunctions() public {
        vm.startPrank(user1);
        
        vm.expectRevert();
        pool.setRewardsDuration(14 days);

        vm.expectRevert();
        pool.pause();

        vm.expectRevert();
        pool.recoverERC20(address(usdc), 100 ether);

        vm.stopPrank();
    }

    function test_AdminCannotCallNotifyRewardAmountUnlessGrantedOperatorRole()
        public
    {
        // Assume `admin` currently has DEFAULT_ADMIN_ROLE in setUp
        // Let's create a new admin to test pure admin role without operator
        address newAdmin = address(0x999);
        pool.grantRole(pool.DEFAULT_ADMIN_ROLE(), newAdmin);

        vm.startPrank(newAdmin);
        
        // Should revert because newAdmin doesn't have OPERATOR_ROLE
        vm.expectRevert();
        pool.notifyRewardAmount(1000 ether);

        // Admin grants OPERATOR_ROLE to themselves
        pool.grantRole(pool.OPERATOR_ROLE(), newAdmin);

        // Now they have the role. The call might revert due to no token approval, but not due to AccessControl
        // We will just test that it reverts with "ERC20: transfer amount exceeds balance" or similar instead of AccessControl
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        pool.notifyRewardAmount(1000 ether);

        vm.stopPrank();
    }

    function test_GrantAndRevokeOperatorRoleTakesEffectImmediately() public {
        address newOperator = address(0x333);
        rewardToken.mint(newOperator, 1000 ether);

        vm.startPrank(newOperator);
        rewardToken.approve(address(pool), type(uint256).max);
        vm.expectRevert();
        pool.notifyRewardAmount(100 ether);
        vm.stopPrank();

        pool.grantRole(pool.OPERATOR_ROLE(), newOperator);

        vm.prank(newOperator);
        pool.notifyRewardAmount(100 ether);

        pool.revokeRole(pool.OPERATOR_ROLE(), newOperator);

        vm.prank(newOperator);
        vm.expectRevert();
        pool.notifyRewardAmount(100 ether);
    }

    function test_DifferentDecimalsStakeAndRewardTokensDistributeCorrectly()
        public
    {
        MockERC20 stakingToken6 = new MockERC20("USDC Stake", "sUSDC", 6);
        MockERC20 rewardToken18 = new MockERC20("Reward Token", "RWD", 18);
        StakingPool decimalPool = new StakingPool(
            address(stakingToken6),
            address(rewardToken18),
            admin,
            operator
        );

        stakingToken6.mint(user1, 1000 * 1e6);
        rewardToken18.mint(operator, 2000 ether);
        rewardToken18.approve(address(decimalPool), type(uint256).max);
        decimalPool.setRewardsDuration(2 days);

        vm.startPrank(user1);
        stakingToken6.approve(address(decimalPool), type(uint256).max);
        decimalPool.stake(100 * 1e6);
        vm.stopPrank();

        decimalPool.notifyRewardAmount(2000 ether);
        vm.warp(block.timestamp + 2 days);

        assertEq(decimalPool.balanceOf(user1), 100 * 1e6);
        assertApproxEqAbs(decimalPool.earned(user1), 2000 ether, 1e12);
    }

    function test_AccountingInvariantsHoldForStandardStakingToken() public {
        vm.prank(user1);
        pool.stake(100 ether);

        vm.prank(user2);
        pool.stake(250 ether);

        vm.prank(user1);
        pool.withdraw(40 ether);

        uint256 summedUserBalances = pool.balanceOf(user1) +
            pool.balanceOf(user2);

        assertEq(summedUserBalances, pool.totalSupply());
        assertGe(stakingToken.balanceOf(address(pool)), pool.totalSupply());
    }

    function test_StandardRewardTokenSolvencyCoversEarnedAndRemainingRewards()
        public
    {
        vm.prank(user1);
        pool.stake(100 ether);

        pool.notifyRewardAmount(7000 ether);

        vm.warp(block.timestamp + 1 days);

        vm.prank(user2);
        pool.stake(100 ether);

        vm.warp(block.timestamp + 1 days);

        uint256 unpaidRewards = pool.earned(user1) + pool.earned(user2);
        uint256 remainingRewards = (pool.rewardRate() *
            (pool.periodFinish() - block.timestamp)) / 1e18;

        assertGe(
            rewardToken.balanceOf(address(pool)),
            unpaidRewards + remainingRewards
        );
    }

    function test_DeploymentConfigRejectsFeeOnTransferTokensForV1() public {
        V1DeploymentConfigPolicy policy = new V1DeploymentConfigPolicy();

        policy.validatePoolTokens(
            address(stakingToken),
            address(rewardToken),
            false,
            false
        );

        vm.expectRevert(IStakingPool.FeeOnTransferNotSupported.selector);
        policy.validatePoolTokens(
            address(stakingToken),
            address(rewardToken),
            true,
            false
        );

        vm.expectRevert(IStakingPool.FeeOnTransferNotSupported.selector);
        policy.validatePoolTokens(
            address(stakingToken),
            address(rewardToken),
            false,
            true
        );
    }

    function test_RevertWhen_FeeOnTransferStakingTokenIsUsedAtRuntime() public {
        FeeOnTransferMockERC20 feeStakingToken = new FeeOnTransferMockERC20(
            "Fee Stake",
            "FSTK",
            18,
            100
        );
        StakingPool feePool = new StakingPool(
            address(feeStakingToken),
            address(rewardToken),
            admin,
            operator
        );

        feeStakingToken.mint(user1, 100 ether);
        feePool.setRewardsDuration(7 days);

        vm.startPrank(user1);
        feeStakingToken.approve(address(feePool), type(uint256).max);
        vm.expectRevert(IStakingPool.FeeOnTransferNotSupported.selector);
        feePool.stake(100 ether);
        vm.stopPrank();
    }

    function test_RevertWhen_FeeOnTransferRewardTokenIsUsedAtRuntime() public {
        FeeOnTransferMockERC20 feeRewardToken = new FeeOnTransferMockERC20(
            "Fee Reward",
            "FRWD",
            18,
            100
        );
        StakingPool feePool = new StakingPool(
            address(stakingToken),
            address(feeRewardToken),
            admin,
            operator
        );

        feeRewardToken.mint(operator, 1000 ether);
        feeRewardToken.approve(address(feePool), type(uint256).max);
        feePool.setRewardsDuration(7 days);

        vm.expectRevert(IStakingPool.FeeOnTransferNotSupported.selector);
        feePool.notifyRewardAmount(1000 ether);
    }
}
