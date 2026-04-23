// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/staking.sol";
import "../src/interface.sol";

// Simple ERC20 mock for testing
contract MockERC20 {
    string public name;
    string public symbol;
    uint8 public decimals = 18;
    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
    }

    function mint(address to, uint256 amount) public {
        balanceOf[to] += amount;
        totalSupply += amount;
    }

    function transfer(address to, uint256 amount) public returns (bool) {
        require(balanceOf[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        return true;
    }

    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(balanceOf[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowance[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += amount;
        return true;
    }
}

contract StakingPoolTest is Test {
    StakingPool public pool;
    MockERC20 public stakingToken;
    MockERC20 public rewardToken;
    MockERC20 public usdc;

    address public operator = address(this);
    address public user1 = address(0x111);
    address public user2 = address(0x222);

    // Events to test
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 reward);

    function setUp() public {
        stakingToken = new MockERC20("Staking Token", "STK");
        rewardToken = new MockERC20("Reward Token", "REWARD");
        usdc = new MockERC20("USDC", "USDC");

        pool = new StakingPool(address(stakingToken), address(rewardToken));

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

    function test_UserStakesAdditionalTokensAndTriggersRewardSettlement() public {
        // Start a reward period first to have rewards
        rewardToken.transfer(address(pool), 7000 ether);
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

    function test_RevertWhen_UserAttemptsToWithdrawMoreThanStakedBalance() public {
        vm.prank(user1);
        pool.stake(100 ether);

        vm.prank(user1);
        vm.expectRevert(); // Should indicate insufficient balance
        pool.withdraw(150 ether);
    }

    // ------------------------------------------------------------------
    // 3. Claiming Rewards (领取收益)
    // ------------------------------------------------------------------
    function test_UserSuccessfullyClaimsAccumulatedRewards() public {
        rewardToken.transfer(address(pool), 7000 ether);
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
        rewardToken.transfer(address(pool), 7000 ether);
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

    // ------------------------------------------------------------------
    // 5. Operator Reward Injection (运营注入奖励)
    // ------------------------------------------------------------------
    function test_OperatorStartsNewRewardPeriod() public {
        // Contract must hold at least 7000 REWARD
        rewardToken.transfer(address(pool), 7000 ether);

        vm.expectEmit(false, false, false, true);
        emit RewardAdded(7000 ether);
        pool.notifyRewardAmount(7000 ether);

        assertEq(pool.rewardRate(), uint256(7000 ether) / 7 days);
    }

    function test_OperatorInjectsRewardsBeforeCurrentPeriodEnds_RewardSmoothing() public {
        rewardToken.transfer(address(pool), 7000 ether);
        pool.notifyRewardAmount(7000 ether);

        // Fast forward 4 days (3 days remaining)
        vm.warp(block.timestamp + 4 days);

        // Remaining reward is for 3 days = 3000 REWARD
        // Operator injects 4000 more
        rewardToken.transfer(address(pool), 4000 ether);
        pool.notifyRewardAmount(4000 ether);

        // The new rate should be (3000 + 4000) / 7 days = 1000 REWARD/day
        assertEq(pool.rewardRate(), uint256(7000 ether) / 7 days);
    }

    function test_RevertWhen_OperatorAttemptsToInjectRewardsWithoutSufficientBalance() public {
        // Contract has 1000 REWARD
        rewardToken.transfer(address(pool), 1000 ether);

        vm.expectRevert("Reward amount too high");
        pool.notifyRewardAmount(5000 ether);
    }

    // ------------------------------------------------------------------
    // 6. Admin Privileges & Risk Management (管理员特权与风控)
    // ------------------------------------------------------------------
    function test_GracefulDegradationDuringEmergencyPause() public {
        vm.prank(user1);
        pool.stake(100 ether);

        pool.pause();

        // Stake should revert
        vm.prank(user1);
        vm.expectRevert("Paused");
        pool.stake(50 ether);

        // Withdraw should succeed
        vm.prank(user1);
        pool.withdraw(50 ether);
        assertEq(pool.balanceOf(user1), 50 ether);

        // GetReward should succeed
        vm.prank(user1);
        pool.getReward();
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

    function test_RevertWhen_AdminAttemptsToRescueStakingOrRewardTokens() public {
        // STK is protected
        vm.expectRevert();
        pool.recoverERC20(address(stakingToken), 10 ether);

        // REWARD is protected
        vm.expectRevert();
        pool.recoverERC20(address(rewardToken), 10 ether);
    }
}
