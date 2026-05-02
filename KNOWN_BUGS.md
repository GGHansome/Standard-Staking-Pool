# 已知问题与 Bug 记录 (Known Issues & Bugs)

## 1. 通缩型代币质押记账 Bug (已修复)
**时间:** 2026-04-30
**问题:** `stake` 函数直接使用用户传入的 `amount` 记账，未考虑通缩型代币（Fee-on-transfer tokens）的扣税机制。这会导致合约记账数量大于实际收到的代币数量，从而引发坏账。
**修复:** 改为通过计算转账前后合约的代币余额差值 (`actualAmount`) 来进行准确记账。

## 2. rewardPerToken 计算遗漏放大单位 (Bug)
**时间:** 2026-05-01
**问题:** `rewardPerToken` 函数中在计算期间累计奖励时遗漏了放大单位（如 `1e18`），可能导致精度丢失和奖励计算错误。
**状态:** 已修复

## 3. updateReward 修饰器状态更新顺序错误导致奖励丢失 (Bug)
**时间:** 2026-05-02
**问题:** `updateReward` 修饰器中，先将 `user.userRewardPerTokenPaid` 更新到了最新值，后调用 `earned(account)` 结算用户奖励。由于 `earned` 的计算逻辑依赖两者的差值，这会导致差值为 0，从而使新积累的奖励全部归零。必须先结算奖励（`earned`），再更新已支付水位线。
**状态:** 已修复

## 4. 时间戳及奖励计算未受挖矿周期 (periodFinish) 限制 (Bug)
**时间:** 2026-05-02
**问题:** 在 `updateReward` 修饰器更新 `lastUpdateTime`，以及 `rewardPerToken` 函数计算期间累计奖励时，直接使用了 `block.timestamp`。这会导致挖矿周期结束后，全局时间依然被更新，且由于时间差在增加，系统会错误地继续产生和计算奖励。应使用 `Math.min(block.timestamp, periodFinish)` （或 `lastTimeRewardApplicable()` 方法）进行限制。
**状态:** 已修复
