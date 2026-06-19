// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Test.sol";
import "../../src/V2/staking.sol";
import "../../src/V2/interface.sol";
import "../mocks/MockERC20.sol";

contract FeeOnTransferMockERC20 is MockERC20 {
    uint256 public immutable feeBps;

    constructor(string memory name_, string memory symbol_, uint8 decimals_, uint256 feeBps_)
        MockERC20(name_, symbol_, decimals_)
    {
        feeBps = feeBps_;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 received = amount - fee;
        require(balanceOf[msg.sender] >= amount, "ERC20: transfer amount exceeds balance");
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += received;
        totalSupply -= fee;
        emit Transfer(msg.sender, to, received);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        uint256 fee = (amount * feeBps) / 10_000;
        uint256 received = amount - fee;
        require(balanceOf[from] >= amount, "ERC20: transfer amount exceeds balance");
        require(allowance[from][msg.sender] >= amount, "ERC20: insufficient allowance");
        allowance[from][msg.sender] -= amount;
        balanceOf[from] -= amount;
        balanceOf[to] += received;
        totalSupply -= fee;
        emit Transfer(from, to, received);
        return true;
    }
}

contract RevertingMockERC20 is MockERC20 {
    bool public revertTransfer;
    bool public revertTransferFrom;

    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockERC20(name_, symbol_, decimals_) {}

    function setRevertTransfer(bool value) external {
        revertTransfer = value;
    }

    function setRevertTransferFrom(bool value) external {
        revertTransferFrom = value;
    }

    function transfer(address to, uint256 amount) public override returns (bool) {
        if (revertTransfer) revert("TRANSFER_REVERTED");
        return super.transfer(to, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        if (revertTransferFrom) revert("TRANSFER_FROM_REVERTED");
        return super.transferFrom(from, to, amount);
    }
}

contract BalanceMutableMockERC20 is MockERC20 {
    constructor(string memory name_, string memory symbol_, uint8 decimals_) MockERC20(name_, symbol_, decimals_) {}

    function burnFrom(address from, uint256 amount) external {
        require(balanceOf[from] >= amount, "ERC20: burn amount exceeds balance");
        balanceOf[from] -= amount;
        totalSupply -= amount;
        emit Transfer(from, address(0), amount);
    }
}

contract V2StakingPoolHarness is StakingPool {
    constructor(ConstructorParams memory params) StakingPool(params) {}

    function exposedAssertAssetCoverage() external view {
        _assertAssetCoverage();
    }

    function exposedRemoveActiveDeposit(address user, uint256 depositId) external {
        _removeActiveDeposit(user, depositId);
    }

    function exposedRewardPerTokenAt(uint256 targetTime) external view returns (uint256) {
        return _rewardPerTokenAt(targetTime);
    }

    function exposedSettleInviter(address user, address inviter) external {
        _settleInviter(user, inviter);
    }

    function setInviterState(address user, address inviter, bool hasSet) external {
        inviterOf[user] = inviter;
        hasSetInviter[user] = hasSet;
    }
}

abstract contract V2StakingPoolBase is Test {
    uint256 internal constant BPS = 10_000;
    uint256 internal constant REWARDS_DURATION = 10 days;
    uint256 internal constant INVITEE_BOOST = 500;
    uint256 internal constant LEVEL1 = 1_000;
    uint256 internal constant LEVEL2 = 500;
    uint256 internal constant LEVEL3 = 200;
    uint256 internal constant PENALTY_RATE = 2_000;
    uint256 internal constant MAX_SUBSIDY_CAP = 5_200;
    uint256 internal constant SHORT_LOCK = 30 days;
    uint256 internal constant LONG_LOCK = 90 days;
    uint256 internal constant SHORT_BOOST = 1_000;
    uint256 internal constant LONG_BOOST = 3_000;
    uint256 internal constant ROUNDING_TOLERANCE = 1e12;

    bytes4 internal constant ACCESS_DENIED = bytes4(keccak256("AccessControlUnauthorizedAccount(address,bytes32)"));
    bytes4 internal constant ENFORCED_PAUSE = bytes4(keccak256("EnforcedPause()"));

    StakingPool internal pool;
    MockERC20 internal stakingToken;
    MockERC20 internal rewardToken;
    MockERC20 internal otherToken;

    address internal admin = address(0xA11CE);
    address internal operator = address(0x0A0A);
    address internal treasury = address(0x7777);
    address internal user1 = address(0x1111);
    address internal user2 = address(0x2222);
    address internal user3 = address(0x3333);
    address internal user4 = address(0x4444);
    address internal user5 = address(0x5555);
    address internal receiver = address(0x9999);

    event RewardCheckpointWritten(uint256 indexed time, uint256 rewardPerToken, uint256 periodFinish, uint256 index, bool replaced);
    event Withdrawn(address indexed user, uint256 indexed depositId, uint256 principalReturned);
    event DepositClosed(address indexed user, uint256 indexed depositId);
    event BaseRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount);
    event LockBoostRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount);
    event InviteeBoostRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount);
    event ReferralRewardAccrued(
        address indexed inviter,
        address indexed invitee,
        uint8 indexed level,
        uint256 sourceDepositId,
        uint256 amount
    );
    event Recovered(address indexed token, uint256 amount);

    function setUp() public virtual {
        vm.warp(100 days);
        stakingToken = new MockERC20("Stake", "STK", 18);
        rewardToken = new MockERC20("Reward", "RWD", 18);
        otherToken = new MockERC20("Other", "OTR", 18);
        pool = _deployDefault(address(stakingToken), address(rewardToken), operator, treasury);
        _fundAndApproveDefault(pool, stakingToken, rewardToken);
    }

    function _deployDefault(address stakingToken_, address rewardToken_) internal returns (StakingPool deployed) {
        deployed = _deployDefault(stakingToken_, rewardToken_, operator, treasury);
    }

    function _deployDefault(
        address stakingToken_,
        address rewardToken_,
        address operator_,
        address treasury_
    ) internal returns (StakingPool deployed) {
        StakingPoolTypes.ConstructorParams memory params = _defaultParams(stakingToken_, rewardToken_);
        params.operator = operator_;
        params.treasury = treasury_;
        deployed = new StakingPool(params);
    }

    function _defaultParams(address stakingToken_, address rewardToken_)
        internal
        view
        returns (StakingPoolTypes.ConstructorParams memory params)
    {
        uint256[] memory durations = new uint256[](2);
        durations[0] = SHORT_LOCK;
        durations[1] = LONG_LOCK;
        uint256[] memory boosts = new uint256[](2);
        boosts[0] = SHORT_BOOST;
        boosts[1] = LONG_BOOST;
        params = StakingPoolTypes.ConstructorParams({
            stakingToken: stakingToken_,
            rewardToken: rewardToken_,
            admin: admin,
            operator: operator,
            treasury: treasury,
            rewardsDuration: REWARDS_DURATION,
            inviteeBoost: INVITEE_BOOST,
            level1: LEVEL1,
            level2: LEVEL2,
            level3: LEVEL3,
            penaltyRate: PENALTY_RATE,
            maxSubsidyRateCap: MAX_SUBSIDY_CAP,
            durations: durations,
            boosts: boosts
        });
    }

    function _deployWithParams(StakingPoolTypes.ConstructorParams memory params) internal returns (StakingPool deployed) {
        deployed = new StakingPool(params);
    }

    function _emptyUintArray() internal pure returns (uint256[] memory values) {
        values = new uint256[](0);
    }

    function _oneLockTier(uint256 duration, uint256 boost)
        internal
        pure
        returns (uint256[] memory durations, uint256[] memory boosts)
    {
        durations = new uint256[](1);
        durations[0] = duration;
        boosts = new uint256[](1);
        boosts[0] = boost;
    }

    function _fundAndApproveDefault(StakingPool target, MockERC20 stakeToken, MockERC20 rewToken) internal {
        address[5] memory users = [user1, user2, user3, user4, user5];
        for (uint256 i; i < users.length; ++i) {
            stakeToken.mint(users[i], 1_000_000 ether);
            vm.prank(users[i]);
            stakeToken.approve(address(target), type(uint256).max);
        }
        rewToken.mint(operator, 10_000_000 ether);
        vm.prank(operator);
        rewToken.approve(address(target), type(uint256).max);
        otherToken.mint(address(target), 1_000 ether);
    }

    function _notify(uint256 amount) internal {
        vm.prank(operator);
        pool.notifyRewardAmount(amount);
    }

    function _stake(address user, uint256 amount, uint256 lockDuration, address inviter) internal returns (uint256 depositId) {
        vm.prank(user);
        depositId = pool.stake(amount, lockDuration, inviter);
    }

    function _claim(address user) internal {
        vm.prank(user);
        pool.claimAll();
    }

    function _withdraw(address user, uint256 depositId) internal {
        vm.prank(user);
        pool.withdraw(depositId);
    }

    function _withdrawMultiple(address user, uint256[] memory ids) internal {
        vm.prank(user);
        pool.withdrawMultiple(ids);
    }

    function _exit(address user) internal {
        vm.prank(user);
        pool.exit();
    }

    function _expectedSubsidy(uint256 baseAmount) internal pure returns (uint256) {
        return (baseAmount * MAX_SUBSIDY_CAP) / BPS;
    }

    function _expectedReward(uint256 baseAmount, uint256 elapsed, uint256 principal, uint256 supply)
        internal
        pure
        returns (uint256)
    {
        return (baseAmount * elapsed * principal) / REWARDS_DURATION / supply;
    }

    function _assertActiveIds(address user, uint256[] memory expected) internal view {
        uint256[] memory actual = pool.getActiveDepositIds(user);
        assertEq(actual.length, expected.length, "active id length");
        for (uint256 i; i < expected.length; ++i) {
            bool found;
            for (uint256 j; j < actual.length; ++j) {
                if (actual[j] == expected[i]) found = true;
            }
            assertTrue(found, "active id missing");
        }
    }

    function _expectAccessDenied(address account, bytes32 role) internal {
        vm.expectRevert(abi.encodeWithSelector(ACCESS_DENIED, account, role));
    }

    function _single(uint256 value) internal pure returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = value;
    }

    function _pair(uint256 first, uint256 second) internal pure returns (uint256[] memory values) {
        values = new uint256[](2);
        values[0] = first;
        values[1] = second;
    }

    function _triple(uint256 first, uint256 second, uint256 third) internal pure returns (uint256[] memory values) {
        values = new uint256[](3);
        values[0] = first;
        values[1] = second;
        values[2] = third;
    }
}