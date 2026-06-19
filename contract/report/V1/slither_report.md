**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [incorrect-equality](#incorrect-equality) (1 results) (Medium)
 - [timestamp](#timestamp) (2 results) (Low)
 - [naming-convention](#naming-convention) (2 results) (Informational)
 - [unindexed-event-address](#unindexed-event-address) (1 results) (Informational)
 - [immutable-states](#immutable-states) (2 results) (Optimization)
## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-0
[StakingPool.rewardPerToken()](src/staking.sol#L96-L105) uses a dangerous strict equality:
	- [totalSupply == 0](src/staking.sol#L98)

src/staking.sol#L96-L105


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-1
[StakingPool.notifyRewardAmount(uint256)](src/staking.sol#L183-L211) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp > periodFinish](src/staking.sol#L201)

src/staking.sol#L183-L211


 - [ ] ID-2
[StakingPool.setRewardsDuration(uint256)](src/staking.sol#L213-L225) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp < periodFinish](src/staking.sol#L220)

src/staking.sol#L213-L225


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-3
Parameter [StakingPool.setRewardsDuration(uint256)._rewardsDuration](src/staking.sol#L214) is not in mixedCase

src/staking.sol#L214


 - [ ] ID-4
Function [IStakingPool.OPERATOR_ROLE()](src/interface.sol#L35) is not in mixedCase

src/interface.sol#L35


## unindexed-event-address
Impact: Informational
Confidence: High
 - [ ] ID-5
Event [IStakingPool.Recovered(address,uint256)](src/interface.sol#L19) has address parameters but no indexed parameters

src/interface.sol#L19


## immutable-states
Impact: Optimization
Confidence: High
 - [ ] ID-6
[StakingPool.stakingToken](src/staking.sol#L20) should be immutable 

src/staking.sol#L20


 - [ ] ID-7
[StakingPool.rewardToken](src/staking.sol#L21) should be immutable 

src/staking.sol#L21


