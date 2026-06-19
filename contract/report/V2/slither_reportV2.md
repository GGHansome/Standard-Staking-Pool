**THIS CHECKLIST IS NOT COMPLETE**. Use `--show-ignored-findings` to show all the results.
Summary
 - [incorrect-exp](#incorrect-exp) (1 results) (High)
 - [divide-before-multiply](#divide-before-multiply) (14 results) (Medium)
 - [incorrect-equality](#incorrect-equality) (6 results) (Medium)
 - [uninitialized-local](#uninitialized-local) (6 results) (Medium)
 - [timestamp](#timestamp) (19 results) (Low)
 - [assembly](#assembly) (24 results) (Informational)
 - [pragma](#pragma) (1 results) (Informational)
 - [costly-loop](#costly-loop) (16 results) (Informational)
 - [cyclomatic-complexity](#cyclomatic-complexity) (1 results) (Informational)
 - [solc-version](#solc-version) (4 results) (Informational)
 - [naming-convention](#naming-convention) (4 results) (Informational)
 - [too-many-digits](#too-many-digits) (1 results) (Informational)
 - [unindexed-event-address](#unindexed-event-address) (2 results) (Informational)
 - [cache-array-length](#cache-array-length) (1 results) (Optimization)
## incorrect-exp
Impact: High
Confidence: Medium
 - [ ] ID-0
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) has bitwise-xor operator ^ instead of the exponentiation operator **: 
	 - [inverse = (3 * denominator) ^ 2](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L259)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


## divide-before-multiply
Impact: Medium
Confidence: Medium
 - [ ] ID-1
[StakingPool.maxSweepableSubsidy()](src/V2/staking.sol#L402-L416) performs a multiplication on the result of a division:
	- [naturalAttritionReward = (rewardRate * (applicableTime - lastUpdateTime)) / PRECISION](src/V2/staking.sol#L406)
	- [maxSubsidyBudgetDelta = (naturalAttritionReward * maxSubsidyRate) / BPS](src/V2/staking.sol#L407)

src/V2/staking.sol#L402-L416


 - [ ] ID-2
[StakingPool._accrueDepositReward(StakingPoolTypes.DepositRecord,uint256)](src/V2/staking.sol#L794-L830) performs a multiplication on the result of a division:
	- [baseReward = (deposit.amount * delta) / PRECISION](src/V2/staking.sol#L800)
	- [maxSubsidyDelta = baseReward * maxSubsidyRate / BPS](src/V2/staking.sol#L801)

src/V2/staking.sol#L794-L830


 - [ ] ID-3
[StakingPool._accrueDepositReward(StakingPoolTypes.DepositRecord,uint256)](src/V2/staking.sol#L794-L830) performs a multiplication on the result of a division:
	- [baseReward = (deposit.amount * delta) / PRECISION](src/V2/staking.sol#L800)
	- [inviteeBoostReward = (baseReward * inviteeBoost) / BPS](src/V2/staking.sol#L811)

src/V2/staking.sol#L794-L830


 - [ ] ID-4
[StakingPool._accrueLockBoostReward(StakingPoolTypes.DepositRecord,uint256,uint256)](src/V2/staking.sol#L878-L900) performs a multiplication on the result of a division:
	- [boostReward = (deposit.amount * (rewardPerTokenAtUnlock - depositRewardPerTokenPaid)) / PRECISION * deposit.boostRate / BPS](src/V2/staking.sol#L892-L893)

src/V2/staking.sol#L878-L900


 - [ ] ID-5
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse = (3 * denominator) ^ 2](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L259)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-6
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [low = low / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L247)
	- [result = low * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L274)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-7
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse *= 2 - denominator * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L265)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-8
[Math.invMod(uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L317-L363) performs a multiplication on the result of a division:
	- [quotient = gcd / remainder](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L339)
	- [(gcd,remainder) = (remainder,gcd - remainder * quotient)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L341-L348)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L317-L363


 - [ ] ID-9
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse *= 2 - denominator * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L264)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-10
[StakingPool._updateReward(address)](src/V2/staking.sol#L612-L632) performs a multiplication on the result of a division:
	- [naturalAttritionReward = (rewardRate * (applicableTime - lastUpdateTime)) / PRECISION](src/V2/staking.sol#L615)
	- [maxSubsidyBudgetDelta = (naturalAttritionReward * maxSubsidyRate) / BPS](src/V2/staking.sol#L616)

src/V2/staking.sol#L612-L632


 - [ ] ID-11
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse *= 2 - denominator * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L266)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-12
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse *= 2 - denominator * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L267)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-13
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse *= 2 - denominator * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L263)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-14
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) performs a multiplication on the result of a division:
	- [denominator = denominator / twos](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L244)
	- [inverse *= 2 - denominator * inverse](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L268)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


## incorrect-equality
Impact: Medium
Confidence: High
 - [ ] ID-15
[StakingPool._accrueDepositReward(StakingPoolTypes.DepositRecord,uint256)](src/V2/staking.sol#L794-L830) uses a dangerous strict equality:
	- [baseReward == 0](src/V2/staking.sol#L806)

src/V2/staking.sol#L794-L830


 - [ ] ID-16
[StakingPool._accrueDepositReward(StakingPoolTypes.DepositRecord,uint256)](src/V2/staking.sol#L794-L830) uses a dangerous strict equality:
	- [delta == 0](src/V2/staking.sol#L803)

src/V2/staking.sol#L794-L830


 - [ ] ID-17
[StakingPool._claimReferralReward(address)](src/V2/staking.sol#L692-L702) uses a dangerous strict equality:
	- [paid == 0](src/V2/staking.sol#L694)

src/V2/staking.sol#L692-L702


 - [ ] ID-18
[StakingPool.rewardPerToken()](src/V2/staking.sol#L381-L386) uses a dangerous strict equality:
	- [totalSupply == 0](src/V2/staking.sol#L382)

src/V2/staking.sol#L381-L386


 - [ ] ID-19
[StakingPool._rewardPerTokenAt(uint256)](src/V2/staking.sol#L951-L1009) uses a dangerous strict equality:
	- [length == 0](src/V2/staking.sol#L953)

src/V2/staking.sol#L951-L1009


 - [ ] ID-20
[StakingPool._writeRewardCheckpoint()](src/V2/staking.sol#L1062-L1080) uses a dangerous strict equality:
	- [index > 0 && rewardHistory[index - 1].time == block.timestamp](src/V2/staking.sol#L1071)

src/V2/staking.sol#L1062-L1080


## uninitialized-local
Impact: Medium
Confidence: Medium
 - [ ] ID-21
[StakingPool._rewardPerTokenAt(uint256).low](src/V2/staking.sol#L979) is a local variable never initialized

src/V2/staking.sol#L979


 - [ ] ID-22
[StakingPool._writeRewardCheckpoint().replaced](src/V2/staking.sol#L1070) is a local variable never initialized

src/V2/staking.sol#L1070


 - [ ] ID-23
[StakingPool.withdrawMultiple(uint256[]).accounting](src/V2/staking.sol#L489) is a local variable never initialized

src/V2/staking.sol#L489


 - [ ] ID-24
[StakingPool.exit().accounting](src/V2/staking.sol#L501) is a local variable never initialized

src/V2/staking.sol#L501


 - [ ] ID-25
[StakingPool.notifyRewardAmount(uint256).subsidyCharged](src/V2/staking.sol#L524) is a local variable never initialized

src/V2/staking.sol#L524


 - [ ] ID-26
[StakingPool._claimAll(address).totalPaid](src/V2/staking.sol#L637) is a local variable never initialized

src/V2/staking.sol#L637


## timestamp
Impact: Low
Confidence: Medium
 - [ ] ID-27
[StakingPool._withdrawDepositToAccounting(address,uint256)](src/V2/staking.sol#L712-L757) uses timestamp for comparisons
	Dangerous comparisons:
	- [deposit.unlockTime > block.timestamp](src/V2/staking.sol#L734)

src/V2/staking.sol#L712-L757


 - [ ] ID-28
[StakingPool._accrueLockBoostReward(StakingPoolTypes.DepositRecord,uint256,uint256)](src/V2/staking.sol#L878-L900) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp >= deposit.unlockTime](src/V2/staking.sol#L887)
	- [rewardPerTokenAtUnlock > depositRewardPerTokenPaid](src/V2/staking.sol#L891)

src/V2/staking.sol#L878-L900


 - [ ] ID-29
[StakingPool._claimReferralReward(address)](src/V2/staking.sol#L692-L702) uses timestamp for comparisons
	Dangerous comparisons:
	- [paid == 0](src/V2/staking.sol#L694)

src/V2/staking.sol#L692-L702


 - [ ] ID-30
[StakingPool._pullExact(address,address,uint256)](src/V2/staking.sol#L1091-L1098) uses timestamp for comparisons
	Dangerous comparisons:
	- [actualAmount != amount](src/V2/staking.sol#L1095)

src/V2/staking.sol#L1091-L1098


 - [ ] ID-31
[StakingPool.isRewardPeriodActive()](src/V2/staking.sol#L376-L378) uses timestamp for comparisons
	Dangerous comparisons:
	- [active = rewardRate > 0 && block.timestamp < periodFinish](src/V2/staking.sol#L377)

src/V2/staking.sol#L376-L378


 - [ ] ID-32
[StakingPool.sweepSubsidy(address,uint256)](src/V2/staking.sol#L563-L579) uses timestamp for comparisons
	Dangerous comparisons:
	- [amount > maxSweepableSubsidy()](src/V2/staking.sol#L573)

src/V2/staking.sol#L563-L579


 - [ ] ID-33
[StakingPool._claimAll(address)](src/V2/staking.sol#L636-L650) uses timestamp for comparisons
	Dangerous comparisons:
	- [totalPaid > 0](src/V2/staking.sol#L646)

src/V2/staking.sol#L636-L650


 - [ ] ID-34
[StakingPool._assertAssetCoverage()](src/V2/staking.sol#L1101-L1121) uses timestamp for comparisons
	Dangerous comparisons:
	- [subsidyReserve < totalPendingSubsidy + unsettledMaxSubsidyLiability](src/V2/staking.sol#L1102)
	- [IERC20(stakingToken).balanceOf(address(this)) < requiredBalance](src/V2/staking.sol#L1109)
	- [IERC20(rewardToken).balanceOf(address(this)) < requiredRewardBalance](src/V2/staking.sol#L1118)

src/V2/staking.sol#L1101-L1121


 - [ ] ID-35
[StakingPool._accrueDepositReward(StakingPoolTypes.DepositRecord,uint256)](src/V2/staking.sol#L794-L830) uses timestamp for comparisons
	Dangerous comparisons:
	- [delta == 0](src/V2/staking.sol#L803)
	- [baseReward == 0](src/V2/staking.sol#L806)
	- [boostReward > 0](src/V2/staking.sol#L826)

src/V2/staking.sol#L794-L830


 - [ ] ID-36
[StakingPool._payWithdrawAccounting(address,StakingPoolTypes.WithdrawAccounting)](src/V2/staking.sol#L774-L785) uses timestamp for comparisons
	Dangerous comparisons:
	- [accounting.principalReturned > 0](src/V2/staking.sol#L775)
	- [accounting.penaltyAmount > 0](src/V2/staking.sol#L778)
	- [accounting.rewardPaid > 0](src/V2/staking.sol#L781)

src/V2/staking.sol#L774-L785


 - [ ] ID-37
[StakingPool.maxSweepableSubsidy()](src/V2/staking.sol#L402-L416) uses timestamp for comparisons
	Dangerous comparisons:
	- [totalSupply == 0 && applicableTime > lastUpdateTime](src/V2/staking.sol#L405)
	- [subsidyReserve <= liability](src/V2/staking.sol#L412)

src/V2/staking.sol#L402-L416


 - [ ] ID-38
[StakingPool._writeRewardCheckpoint()](src/V2/staking.sol#L1062-L1080) uses timestamp for comparisons
	Dangerous comparisons:
	- [index > 0 && rewardHistory[index - 1].time == block.timestamp](src/V2/staking.sol#L1071)

src/V2/staking.sol#L1062-L1080


 - [ ] ID-39
[StakingPool._isBoostClaimable(StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L1039-L1041) uses timestamp for comparisons
	Dangerous comparisons:
	- [deposit.pendingBoostReward > 0 && (deposit.boostSettled || (deposit.unlockTime != 0 && block.timestamp >= deposit.unlockTime))](src/V2/staking.sol#L1040)

src/V2/staking.sol#L1039-L1041


 - [ ] ID-40
[StakingPool.stake(uint256,uint256,address)](src/V2/staking.sol#L423-L464) uses timestamp for comparisons
	Dangerous comparisons:
	- [lockDuration > 0 && ! isRewardPeriodActive()](src/V2/staking.sol#L436)

src/V2/staking.sol#L423-L464


 - [ ] ID-41
[StakingPool.remainingBaseReward()](src/V2/staking.sol#L394-L399) uses timestamp for comparisons
	Dangerous comparisons:
	- [block.timestamp >= periodFinish](src/V2/staking.sol#L395)

src/V2/staking.sol#L394-L399


 - [ ] ID-42
[StakingPool._updateReward(address)](src/V2/staking.sol#L612-L632) uses timestamp for comparisons
	Dangerous comparisons:
	- [totalSupply == 0 && applicableTime > lastUpdateTime](src/V2/staking.sol#L614)

src/V2/staking.sol#L612-L632


 - [ ] ID-43
[StakingPool.notifyRewardAmount(uint256)](src/V2/staking.sol#L515-L547) uses timestamp for comparisons
	Dangerous comparisons:
	- [requiredSubsidy > sweepable](src/V2/staking.sol#L525)
	- [block.timestamp >= periodFinish](src/V2/staking.sol#L536)

src/V2/staking.sol#L515-L547


 - [ ] ID-44
[StakingPool._rewardPerTokenAt(uint256)](src/V2/staking.sol#L951-L1009) uses timestamp for comparisons
	Dangerous comparisons:
	- [length == 0](src/V2/staking.sol#L953)
	- [targetTime >= cp2Time](src/V2/staking.sol#L971)
	- [low < high](src/V2/staking.sol#L981)
	- [rewardHistory[mid].time <= targetTime](src/V2/staking.sol#L983)
	- [effectiveCp2Time <= cp1Time](src/V2/staking.sol#L1004)

src/V2/staking.sol#L951-L1009


 - [ ] ID-45
[StakingPool._earnedByDeposit(StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L1018-L1034) uses timestamp for comparisons
	Dangerous comparisons:
	- [reward = DepositRewardView({baseReward:baseReward,inviteeBoostReward:deposit.pendingInviteeBoostReward,pendingBoostReward:deposit.pendingBoostReward,claimableBoostReward:claimableBoost,totalClaimable:baseReward + deposit.pendingInviteeBoostReward + claimableBoost,boostClaimable:boostClaimable,boostForfeitable:deposit.boostRate > 0 && deposit.amount > 0 && deposit.unlockTime > block.timestamp})](src/V2/staking.sol#L1025-L1033)

src/V2/staking.sol#L1018-L1034


## assembly
Impact: Informational
Confidence: High
 - [ ] ID-46
[Math.tryMul(uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L73-L84) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L76-L80)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L73-L84


 - [ ] ID-47
[Math._zeroBytes(bytes)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L478-L490) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L482-L484)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L478-L490


 - [ ] ID-48
[StorageSlot.getAddressSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L66-L70) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L67-L69)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L66-L70


 - [ ] ID-49
[Math.mul512(uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L37-L46) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L41-L45)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L37-L46


 - [ ] ID-50
[Math.mulDiv(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L229-L236)
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L242-L251)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L206-L277


 - [ ] ID-51
[Math.add512(uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L25-L30) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L26-L29)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L25-L30


 - [ ] ID-52
[SafeCast.toUint(bool)](lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol#L1157-L1161) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol#L1158-L1160)

lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol#L1157-L1161


 - [ ] ID-53
[StorageSlot.getInt256Slot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L102-L106) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L103-L105)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L102-L106


 - [ ] ID-54
[Math.tryModExp(bytes,bytes,bytes)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L451-L473) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L463-L472)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L451-L473


 - [ ] ID-55
[Math.tryModExp(uint256,uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L411-L435) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L413-L434)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L411-L435


 - [ ] ID-56
[Panic.panic(uint256)](lib/openzeppelin-contracts/contracts/utils/Panic.sol#L50-L56) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/Panic.sol#L51-L55)

lib/openzeppelin-contracts/contracts/utils/Panic.sol#L50-L56


 - [ ] ID-57
[SafeERC20._safeTransfer(IERC20,address,uint256,bool)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L176-L200) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L179-L199)

lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L176-L200


 - [ ] ID-58
[StorageSlot.getBytesSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L129-L133) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L130-L132)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L129-L133


 - [ ] ID-59
[Math.log2(uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L619-L658) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L655-L657)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L619-L658


 - [ ] ID-60
[StorageSlot.getStringSlot(string)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L120-L124) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L121-L123)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L120-L124


 - [ ] ID-61
[StorageSlot.getBytes32Slot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L84-L88) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L85-L87)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L84-L88


 - [ ] ID-62
[Math.tryMod(uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L102-L110) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L105-L108)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L102-L110


 - [ ] ID-63
[StorageSlot.getBytesSlot(bytes)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L138-L142) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L139-L141)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L138-L142


 - [ ] ID-64
[Math.tryDiv(uint256,uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L89-L97) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L92-L95)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L89-L97


 - [ ] ID-65
[StorageSlot.getBooleanSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L75-L79) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L76-L78)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L75-L79


 - [ ] ID-66
[SafeERC20._safeApprove(IERC20,address,uint256,bool)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L255-L279) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L258-L278)

lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L255-L279


 - [ ] ID-67
[StorageSlot.getStringSlot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L111-L115) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L112-L114)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L111-L115


 - [ ] ID-68
[SafeERC20._safeTransferFrom(IERC20,address,address,uint256,bool)](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L212-L244) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L221-L243)

lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L212-L244


 - [ ] ID-69
[StorageSlot.getUint256Slot(bytes32)](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L93-L97) uses assembly
	- [INLINE ASM](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L94-L96)

lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L93-L97


## pragma
Impact: Informational
Confidence: High
 - [ ] ID-70
5 different versions of Solidity are used:
	- Version constraint ^0.8.20 is used by:
		-[^0.8.20](lib/openzeppelin-contracts/contracts/access/AccessControl.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/Context.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/Panic.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/Pausable.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L5)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L4)
		-[^0.8.20](lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol#L5)
	- Version constraint >=0.8.4 is used by:
		-[>=0.8.4](lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#L4)
	- Version constraint >=0.6.2 is used by:
		-[>=0.6.2](lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol#L4)
	- Version constraint >=0.4.16 is used by:
		-[>=0.4.16](lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol#L4)
		-[>=0.4.16](lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol#L4)
		-[>=0.4.16](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
		-[>=0.4.16](lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#L4)
	- Version constraint 0.8.28 is used by:
		-[0.8.28](src/V2/errors.sol#L2)
		-[0.8.28](src/V2/events.sol#L2)
		-[0.8.28](src/V2/interface.sol#L2)
		-[0.8.28](src/V2/staking.sol#L2)
		-[0.8.28](src/V2/types.sol#L2)

lib/openzeppelin-contracts/contracts/access/AccessControl.sol#L4


## costly-loop
Impact: Informational
Confidence: Medium
 - [ ] ID-71
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [totalPendingSubsidy -= depositBoostPaid](src/V2/staking.sol#L683)
	Calls stack containing the loop:
		StakingPool.exit()
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-72
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [baseRewardReserve -= depositBasePaid](src/V2/staking.sol#L665)
	Calls stack containing the loop:
		StakingPool.exit()
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-73
[StakingPool._withdrawDepositToAccounting(address,uint256)](src/V2/staking.sol#L712-L757) has costly operations inside a loop:
	- [totalPendingSubsidy -= forfeitedBoostReward](src/V2/staking.sol#L740)
	Calls stack containing the loop:
		StakingPool.exit()

src/V2/staking.sol#L712-L757


 - [ ] ID-74
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [subsidyReserve -= depositInviteeBoostPaid](src/V2/staking.sol#L673)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-75
[StakingPool._withdrawDepositToAccounting(address,uint256)](src/V2/staking.sol#L712-L757) has costly operations inside a loop:
	- [totalSupply -= principal](src/V2/staking.sol#L732)
	Calls stack containing the loop:
		StakingPool.exit()

src/V2/staking.sol#L712-L757


 - [ ] ID-76
[StakingPool._removeActiveDeposit(address,uint256)](src/V2/staking.sol#L1130-L1142) has costly operations inside a loop:
	- [delete activeDepositIndexPlusOne[depositId]](src/V2/staking.sol#L1141)
	Calls stack containing the loop:
		StakingPool.exit()
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L1130-L1142


 - [ ] ID-77
[StakingPool._withdrawDepositToAccounting(address,uint256)](src/V2/staking.sol#L712-L757) has costly operations inside a loop:
	- [totalSupply -= principal](src/V2/staking.sol#L732)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])

src/V2/staking.sol#L712-L757


 - [ ] ID-78
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [subsidyReserve -= depositInviteeBoostPaid](src/V2/staking.sol#L673)
	Calls stack containing the loop:
		StakingPool.exit()
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-79
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [subsidyReserve -= depositBoostPaid](src/V2/staking.sol#L682)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-80
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [subsidyReserve -= depositBoostPaid](src/V2/staking.sol#L682)
	Calls stack containing the loop:
		StakingPool.exit()
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-81
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [totalPendingSubsidy -= depositInviteeBoostPaid](src/V2/staking.sol#L674)
	Calls stack containing the loop:
		StakingPool.exit()
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-82
[StakingPool._withdrawDepositToAccounting(address,uint256)](src/V2/staking.sol#L712-L757) has costly operations inside a loop:
	- [totalPendingSubsidy -= forfeitedBoostReward](src/V2/staking.sol#L740)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])

src/V2/staking.sol#L712-L757


 - [ ] ID-83
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [totalPendingSubsidy -= depositInviteeBoostPaid](src/V2/staking.sol#L674)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-84
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [baseRewardReserve -= depositBasePaid](src/V2/staking.sol#L665)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-85
[StakingPool._claimDepositReward(address,uint256,StakingPoolTypes.DepositRecord)](src/V2/staking.sol#L657-L687) has costly operations inside a loop:
	- [totalPendingSubsidy -= depositBoostPaid](src/V2/staking.sol#L683)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L657-L687


 - [ ] ID-86
[StakingPool._removeActiveDeposit(address,uint256)](src/V2/staking.sol#L1130-L1142) has costly operations inside a loop:
	- [delete activeDepositIndexPlusOne[depositId]](src/V2/staking.sol#L1141)
	Calls stack containing the loop:
		StakingPool.withdrawMultiple(uint256[])
		StakingPool._withdrawDepositToAccounting(address,uint256)

src/V2/staking.sol#L1130-L1142


## cyclomatic-complexity
Impact: Informational
Confidence: High
 - [ ] ID-87
[StakingPool.constructor(StakingPoolTypes.ConstructorParams)](src/V2/staking.sol#L151-L228) has a high cyclomatic complexity (13).

src/V2/staking.sol#L151-L228


## solc-version
Impact: Informational
Confidence: High
 - [ ] ID-88
Version constraint >=0.6.2 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- NestedCalldataArrayAbiReencodingSizeValidation
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching
	- EmptyByteArrayCopy
	- DynamicArrayCleanup
	- MissingEscapingInFormatting
	- ArraySliceDynamicallyEncodedBaseType
	- ImplicitConstructorCallvalueCheck
	- TupleAssignmentMultiStackSlotComponents
	- MemoryArrayCreationOverflow.
It is used by:
	- [>=0.6.2](lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol#L4)

lib/openzeppelin-contracts/contracts/interfaces/IERC1363.sol#L4


 - [ ] ID-89
Version constraint >=0.4.16 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- DirtyBytesArrayToStorage
	- ABIDecodeTwoDimensionalArrayMemory
	- KeccakCaching
	- EmptyByteArrayCopy
	- DynamicArrayCleanup
	- ImplicitConstructorCallvalueCheck
	- TupleAssignmentMultiStackSlotComponents
	- MemoryArrayCreationOverflow
	- privateCanBeOverridden
	- SignedArrayStorageCopy
	- ABIEncoderV2StorageArrayWithMultiSlotElement
	- DynamicConstructorArgumentsClippedABIV2
	- UninitializedFunctionPointerInConstructor_0.4.x
	- IncorrectEventSignatureInLibraries_0.4.x
	- ExpExponentCleanup
	- NestedArrayFunctionCallDecoder
	- ZeroFunctionSelector.
It is used by:
	- [>=0.4.16](lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol#L4)
	- [>=0.4.16](lib/openzeppelin-contracts/contracts/interfaces/IERC20.sol#L4)
	- [>=0.4.16](lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol#L4)
	- [>=0.4.16](lib/openzeppelin-contracts/contracts/utils/introspection/IERC165.sol#L4)

lib/openzeppelin-contracts/contracts/interfaces/IERC165.sol#L4


 - [ ] ID-90
Version constraint ^0.8.20 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- VerbatimInvalidDeduplication
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess.
It is used by:
	- [^0.8.20](lib/openzeppelin-contracts/contracts/access/AccessControl.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Context.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Panic.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/Pausable.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/StorageSlot.sol#L5)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/introspection/ERC165.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L4)
	- [^0.8.20](lib/openzeppelin-contracts/contracts/utils/math/SafeCast.sol#L5)

lib/openzeppelin-contracts/contracts/access/AccessControl.sol#L4


 - [ ] ID-91
Version constraint >=0.8.4 contains known severe issues (https://solidity.readthedocs.io/en/latest/bugs.html)
	- FullInlinerNonExpressionSplitArgumentEvaluationOrder
	- MissingSideEffectsOnSelectorAccess
	- AbiReencodingHeadOverflowWithStaticArrayCleanup
	- DirtyBytesArrayToStorage
	- DataLocationChangeInInternalOverride
	- NestedCalldataArrayAbiReencodingSizeValidation
	- SignedImmutables.
It is used by:
	- [>=0.8.4](lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#L4)

lib/openzeppelin-contracts/contracts/access/IAccessControl.sol#L4


## naming-convention
Impact: Informational
Confidence: High
 - [ ] ID-92
Function [IStakingPoolV2.MAX_LOCK_TIERS()](src/V2/interface.sol#L26) is not in mixedCase

src/V2/interface.sol#L26


 - [ ] ID-93
Function [IStakingPoolV2.MAX_ACTIVE_DEPOSITS()](src/V2/interface.sol#L22) is not in mixedCase

src/V2/interface.sol#L22


 - [ ] ID-94
Function [IStakingPoolV2.OPERATOR_ROLE()](src/V2/interface.sol#L14) is not in mixedCase

src/V2/interface.sol#L14


 - [ ] ID-95
Function [IStakingPoolV2.BPS()](src/V2/interface.sol#L18) is not in mixedCase

src/V2/interface.sol#L18


## too-many-digits
Impact: Informational
Confidence: Medium
 - [ ] ID-96
[Math.log2(uint256)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L619-L658) uses literals with too many digits:
	- [r = r | byte(uint256,uint256)(x >> r,0x0000010102020202030303030303030300000000000000000000000000000000)](lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L656)

lib/openzeppelin-contracts/contracts/utils/math/Math.sol#L619-L658


## unindexed-event-address
Impact: Informational
Confidence: High
 - [ ] ID-97
Event [Pausable.Unpaused(address)](lib/openzeppelin-contracts/contracts/utils/Pausable.sol#L28) has address parameters but no indexed parameters

lib/openzeppelin-contracts/contracts/utils/Pausable.sol#L28


 - [ ] ID-98
Event [Pausable.Paused(address)](lib/openzeppelin-contracts/contracts/utils/Pausable.sol#L23) has address parameters but no indexed parameters

lib/openzeppelin-contracts/contracts/utils/Pausable.sol#L23


## cache-array-length
Impact: Optimization
Confidence: High
 - [ ] ID-99
Loop condition [i < durations.length](src/V2/staking.sol#L940) should use cached array length instead of referencing `length` member of the storage array.
 
src/V2/staking.sol#L940


