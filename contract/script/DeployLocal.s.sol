// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/V2/staking.sol";
import "../src/V2/types.sol";
import "../test/mocks/MockERC20.sol";

/**
 * @title DeployLocal
 * @notice 在 anvil 等本地 EVM 上一键部署 StakingPool V2 及其测试用 ERC20。
 *
 * @dev 行为：
 *      1. 部署两个 MockERC20 作为 staking / reward token；
 *      2. 用 ConstructorParams 一次性完成 V2 初始化（资产 / 角色 / 奖励周期 / 三级推荐 / 罚金 / 锁仓档位），
 *         admin 与 operator 都设为部署者，treasury 也指向部署者，方便单钱包体验全部角色；
 *      3. 给 anvil 默认账户 0..9 各 mint 一份 staking 与 reward 代币；
 *      4. 用部署者钱包给 pool 预先 approve reward token，前端 notifyRewardAmount 不再需要单独发授权交易；
 *      5. 在控制台打印关键地址，可直接复制到 frontend/.env。
 *
 * @dev V2 的奖励周期在构造期固定（已无 setRewardsDuration），故全部初始化集中在构造函数。
 * @dev 仅用于本地开发，绝对不要在主网或公共测试网执行。
 *
 * 用法：
 *   anvil
 *   cd contract
 *   forge script script/DeployLocal.s.sol \
 *       --rpc-url http://127.0.0.1:8545 \
 *       --broadcast \
 *       --private-key "0x0000"
 */
contract DeployLocal is Script {
    /// @notice 奖励周期，前端默认假设 7 天。
    uint256 public constant REWARDS_DURATION = 90 days;

    /// @notice 被邀请人自身加成比例（BPS），5% = 500。
    uint256 public constant INVITEE_BOOST = 500;
    /// @notice 一级邀请人返佣比例（BPS），3% = 300。
    uint256 public constant LEVEL1_RATE = 300;
    /// @notice 二级邀请人返佣比例（BPS），2% = 200。
    uint256 public constant LEVEL2_RATE = 200;
    /// @notice 三级邀请人返佣比例（BPS），1% = 100。
    uint256 public constant LEVEL3_RATE = 100;
    /// @notice 提前退出罚金比例（BPS），10% = 1000。
    uint256 public constant PENALTY_RATE = 1_000;

    /// @notice 最大补贴比例上限（BPS）。须 >= 推荐比例之和 + 最大锁仓加成 = 500+300+200+100+5000 = 6100，取 7000 留余量。
    uint256 public constant MAX_SUBSIDY_RATE_CAP = 7_000;

    /// @notice 给每个 anvil 默认账户 mint 的 staking token 数量。
    uint256 public constant STAKING_TOKEN_MINT = 1_000_000 ether;

    /// @notice 给每个 anvil 默认账户 mint 的 reward token 数量；运营做 notifyRewardAmount 需要足量储备。
    uint256 public constant REWARD_TOKEN_MINT = 10_000_000 ether;

    /// @dev anvil 默认派发的 10 个测试账户地址。
    address[10] private ANVIL_ACCOUNTS = [
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
        0x70997970C51812dc3A010C7d01b50e0d17dc79C8,
        0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC,
        0x90F79bf6EB2c4f870365E785982E1f101E93b906,
        0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
        0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc,
        0x976EA74026E726554dB657fA54763abd0C3a0aa9,
        0x14dC79964da2C08b23698B3D3cc7Ca32193d9955,
        0x23618e81E3f5cdF7f54C3d65f7FBc0aBf5B21E8f,
        0xa0Ee7A142d267C1f36714E4a8F75612F20a79720
    ];

    function run() external {
        vm.startBroadcast();

        address deployer = msg.sender;

        MockERC20 stakingToken = new MockERC20("Mock Staking Token", "STK", 18);
        MockERC20 rewardToken = new MockERC20("Mock Reward Token", "RWD", 18);

        // 示例锁仓档位：7 天 +10%、30 天 +20%、60 天 +50%（活期 0% 由空档隐式表达，stake 时传 lockDuration=0）。
        uint256[] memory durations = new uint256[](3);
        uint256[] memory boosts = new uint256[](3);
        durations[0] = 7 days;
        boosts[0] = 1_000;
        durations[1] = 30 days;
        boosts[1] = 2_000;
        durations[2] = 60 days;
        boosts[2] = 5_000;

        StakingPoolTypes.ConstructorParams memory params = StakingPoolTypes.ConstructorParams({
            stakingToken: address(stakingToken),
            rewardToken: address(rewardToken),
            admin: deployer,
            operator: 0x0000000000000000000000000000000000000000,
            treasury: deployer,
            rewardsDuration: REWARDS_DURATION,
            inviteeBoost: INVITEE_BOOST,
            level1: LEVEL1_RATE,
            level2: LEVEL2_RATE,
            level3: LEVEL3_RATE,
            penaltyRate: PENALTY_RATE,
            maxSubsidyRateCap: MAX_SUBSIDY_RATE_CAP,
            durations: durations,
            boosts: boosts
        });

        StakingPool pool = new StakingPool(params);

        for (uint256 i = 0; i < ANVIL_ACCOUNTS.length; i++) {
            stakingToken.mint(ANVIL_ACCOUNTS[i], STAKING_TOKEN_MINT);
            rewardToken.mint(ANVIL_ACCOUNTS[i], REWARD_TOKEN_MINT);
        }

        rewardToken.approve(address(pool), type(uint256).max);

        vm.stopBroadcast();

        console.log("================ Deployment Result ================");
        console.log("Deployer / Admin / Operator / Treasury :", deployer);
        console.log("StakingPool                 :", address(pool));
        console.log("StakingToken (STK)          :", address(stakingToken));
        console.log("RewardToken  (RWD)          :", address(rewardToken));
        console.log("Rewards duration (seconds)  :", REWARDS_DURATION);
        console.log("Lock tier #1 (7d   boost bps):", boosts[0]);
        console.log("Lock tier #2 (30d  boost bps):", boosts[1]);
        console.log("Lock tier #3 (60d  boost bps):", boosts[2]);
        console.log("===================================================");
        console.log("Copy into frontend/.env :");
        console.log("VITE_STAKING_POOL_ADDRESS=", address(pool));
    }
}