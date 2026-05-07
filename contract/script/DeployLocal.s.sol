// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "forge-std/Script.sol";
import "../src/staking.sol";
import "../test/mocks/MockERC20.sol";

/**
 * @title DeployLocal
 * @notice 在 anvil 等本地 EVM 上一键部署 StakingPool 及其测试用 ERC20。
 *
 * @dev 行为：
 *      1. 部署两个 MockERC20 作为 staking / reward token；
 *      2. 部署 StakingPool，将 admin 与 operator 都设为部署者，方便单钱包体验全部角色；
 *      3. 调用 setRewardsDuration 完成最少初始化；
 *      4. 给 anvil 默认账户 0..9 各 mint 一份 staking 与 reward 代币；
 *      5. 用部署者钱包给 pool 预先 approve reward token，前端 notifyRewardAmount 不再需要单独发授权交易；
 *      6. 在控制台打印关键地址，可直接复制到 frontend/.env。
 *
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
    uint256 public constant REWARDS_DURATION = 7 days;

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

        StakingPool pool = new StakingPool(
            address(stakingToken),
            address(rewardToken),
            deployer,
            deployer
        );

        pool.setRewardsDuration(REWARDS_DURATION);

        for (uint256 i = 0; i < ANVIL_ACCOUNTS.length; i++) {
            stakingToken.mint(ANVIL_ACCOUNTS[i], STAKING_TOKEN_MINT);
            rewardToken.mint(ANVIL_ACCOUNTS[i], REWARD_TOKEN_MINT);
        }

        rewardToken.approve(address(pool), type(uint256).max);

        vm.stopBroadcast();

        console.log("================ Deployment Result ================");
        console.log("Deployer / Admin / Operator :", deployer);
        console.log("StakingPool                 :", address(pool));
        console.log("StakingToken (STK)          :", address(stakingToken));
        console.log("RewardToken  (RWD)          :", address(rewardToken));
        console.log("Rewards duration (seconds)  :", REWARDS_DURATION);
        console.log("===================================================");
        console.log("Copy into frontend/.env :");
        console.log("VITE_STAKING_POOL_ADDRESS=", address(pool));
    }
}
