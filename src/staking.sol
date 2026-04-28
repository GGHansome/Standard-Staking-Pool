// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./interface.sol";

contract StakingPool is IStakingPool {
    address public stakingToken;
    address public rewardToken;
    
    constructor(address _stakingToken, address _rewardToken, address _admin, address _operator) {
        stakingToken = _stakingToken;
        rewardToken = _rewardToken;
    }
}
