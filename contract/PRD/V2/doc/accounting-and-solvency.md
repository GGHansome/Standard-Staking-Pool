# V2 资金账本与偿付约束

## 1. 文档职责

本文档是 V2 资金桶、累计量、补贴负债、取整规则和偿付公式的唯一事实来源。产品行为见 [`product-spec.md`](./product-spec.md)，状态变更入口见 [`architecture.md`](./architecture.md)，公共查询接口见 [`interface-reference.md`](./interface-reference.md)。

## 2. 设计目标

V2 同时支付基础奖励和三类平台额外补贴。基础奖励由固定奖池按水位线释放；额外补贴取决于用户锁仓和推荐关系，实际支出动态变化。

为避免额外补贴超发，系统采用：

- 基础奖池与补贴备付金双池；
- 本金、基础奖励、补贴三类逻辑资金桶；
- 历史注入与历史已消化基础奖励累计量；
- 已确认补贴负债与未结算最大补贴负债双重覆盖。

## 3. 逻辑资金桶

### 3.1 用户本金桶（Principal Pool）

所有活跃仓位的本金，链上口径为：

\[
totalSupply = \sum activeDeposit.amount
\]

本金只能通过 `stake` 进入，通过 `withdraw`、`withdrawMultiple` 或 `exit` 退出；提前解锁时，一部分本金先形成罚金处理中间余额并转入 Treasury。

### 3.2 基础奖池（Base Reward Pool）

由 `notifyRewardAmount` 实际注入，并进入基础水位线释放曲线。其当前未支付余额由 `baseRewardReserve` 独立维护。

`baseRewardReserve` 不是 `remainingBaseReward()`：

- `baseRewardReserve` 覆盖尚未释放、已经归属但尚未支付，以及周期结束后仍未回收的基础奖励；
- `remainingBaseReward()` 只展示当前周期尚未释放的调度余额。

不得遍历所有仓位反推 `baseRewardReserve`，也不得从合约 Token 总余额反推。

### 3.3 补贴备付金池（Subsidy Reserve）

`subsidyReserve` 是合约当前实际持有、专用于支付以下补贴的现金余额：

- 锁仓加速奖励；
- 自身推荐补贴；
- 三级推荐返佣。

补贴补缴与历史预算沉淀会增加可用现金，补贴支付和管理员安全提取会减少现金。

### 3.4 Treasury

Treasury 接收提前解锁本金罚金。罚金不自动进入基础奖池或补贴备付金；需要重新奖励时，运营方必须通过新的 `notifyRewardAmount` 注入。

## 4. 累计量与补贴负债

### 4.1 历史注入基础奖励累计

`injectedBaseCumulative` 表示历史累计已经纳入基础释放预算的实际新增基础奖励：

- 每次 `notifyRewardAmount` 按本次 `actualBaseReward` 单调增加；
- 续奖时的 `leftoverBaseReward` 已经在历史注入中计数，不重复增加；
- 基础奖励支付、空窗流失或过期回收都不减少该累计量。

### 4.2 历史已消化基础奖励累计

`settledBaseCumulative` 表示已经完成归属或已经确认不再归属任何用户的基础奖励，包含：

- 仓位本次新结算的基础奖励；
- `totalSupply == 0` 期间确认自然流失的基础奖励；
- 奖励周期结束且空池后回收的剩余基础奖励。

该变量单调增加。基础奖励从 `pendingBaseReward` 支付给用户时不再次增加，避免重复消化。

### 4.3 已确认补贴负债

`totalPendingSubsidy` 表示已经计提但尚未支付的补贴总额：

\[
totalPendingSubsidy =
\sum pendingInviteeBoostReward +
\sum pendingBoostReward +
\sum referralRewards
\]

前两项按所有活跃仓位汇总，第三项按所有用户级返佣账本汇总。

<a id="未结算最大补贴负债"></a>

### 4.4 未结算最大补贴负债

`unsettledMaxSubsidyLiability` 覆盖已经预留、但尚未通过用户结算、空窗流失或过期回收消化的最大理论补贴预算：

\[
unsettledMaxSubsidyLiability =
\left\lfloor\frac{injectedBaseCumulative \times maxSubsidyRate}{BPS}\right\rfloor -
\left\lfloor\frac{settledBaseCumulative \times maxSubsidyRate}{BPS}\right\rfloor
\]

它同时覆盖：

1. **已释放但未懒结算的缺口**：用户尚未交互，因此真实补贴还未进入 `totalPendingSubsidy`；
2. **尚未释放的未来潜在负债**：当前调度后续仍可能按最大补贴率产生的补贴。

有 TVL 时，正常时间流逝不会自动降低该负债；只有基础奖励被用户实际结算，或被确认为空窗流失、过期回收时，才增加 `settledBaseCumulative` 并释放对应预算。

## 5. 最大理论补贴率

部署时计算：

\[
maxSubsidyRate = inviteeBoost + level1 + level2 + level3 + \max(boosts[])
\]

锁仓档位为空时，`max(boosts[])` 按 0 处理。

该上限假设：

- 所有用户都绑定有效邀请人；
- 所有用户都有完整的上三级邀请链；
- 所有用户都选择最高锁仓加速比例。

构造函数必须校验：

\[
maxSubsidyRate \le maxSubsidyRateCap
\]

`maxSubsidyRate` 与 `maxSubsidyRateCap` 都采用 BPS 精度，部署后不可修改。各单项比例不另设独立上限，统一由聚合上限约束。

示例：自身推荐补贴 5%、三级返佣 10% / 5% / 2%、最高锁仓加速 50%，则：

\[
maxSubsidyRate = 5\% + 10\% + 5\% + 2\% + 50\% = 72\%
\]

基础奖励为 100% 时，总奖励预算理论上限为 172%。

## 6. 核心不变量

任意时刻都必须满足：

### 6.1 资产余额覆盖

异币池：

\[
stakingToken.balanceOf(pool) \ge totalSupply + penaltyInTransit
\]

\[
rewardToken.balanceOf(pool) \ge baseRewardReserve + subsidyReserve
\]

同币池：

\[
token.balanceOf(pool) \ge
totalSupply + baseRewardReserve + subsidyReserve + penaltyInTransit
\]

`penaltyInTransit` 表示单次状态转换中尚未转入 Treasury 的罚金处理中间余额；实现可以通过原子状态更新与转账使其不跨交易持久化，但不能在计算覆盖额度时忽略。

### 6.2 补贴负债覆盖

\[
subsidyReserve \ge totalPendingSubsidy
\]

以及更强的不变量：

\[
subsidyReserve \ge
totalPendingSubsidy + unsettledMaxSubsidyLiability
\]

### 6.3 安全可提取额度

\[
maxSweepableSubsidy() =
subsidyReserve - totalPendingSubsidy - unsettledMaxSubsidyLiability
\]

只有该差额可以被同一活动后续奖励注入滚动复用，或由管理员通过 `sweepSubsidy` 提取。

## 7. 基础奖池状态变化

### 7.1 奖励注入

每次实际注入新的基础奖励：

\[
baseRewardReserve \mathrel{+}= actualBaseReward
\]

续奖时，旧周期 `leftoverBaseReward` 只重新进入释放曲线，不重复增加 `baseRewardReserve`。

### 7.2 用户结算

`updateReward` 只把基础奖励从未结算状态转为仓位 `pendingBaseReward`，没有 Token 支付，因此不减少 `baseRewardReserve`。

### 7.3 用户支付

`claimAll`、`withdraw`、`withdrawMultiple` 或 `exit` 实际支付基础奖励时：

\[
baseRewardReserve \mathrel{-}= baseRewardPaid
\]

### 7.4 空窗自然流失

全局同步确认 `totalSupply == 0` 区间的基础奖励自然流失时：

\[
baseRewardReserve \mathrel{-}= lostBaseReward
\]

\[
settledBaseCumulative \mathrel{+}= lostBaseReward
\]

然后按累计公式重算 `unsettledMaxSubsidyLiability`。

### 7.5 过期基础奖励回收

奖励周期结束且 `totalSupply == 0` 后，`sweepExpiredBaseReward(to)` 一次性回收全部 `baseRewardReserve`：

\[
expiredAmount = baseRewardReserve
\]

\[
baseRewardReserve = 0
\]

\[
settledBaseCumulative \mathrel{+}= expiredAmount
\]

回收后重算 `unsettledMaxSubsidyLiability`。该入口不改变 `subsidyReserve` 或 `totalPendingSubsidy`。

## 8. 奖励注入与备付金滚动

### 8.1 新释放曲线

管理员调用 `notifyRewardAmount(baseRewardAmount)` 后，以实际到账的 `actualBaseReward` 记账。

若旧周期已经结束：

\[
rewardCurveBase = actualBaseReward
\]

若旧周期仍在运行：

\[
leftoverBaseReward = remainingBaseReward()
\]

\[
rewardCurveBase = actualBaseReward + leftoverBaseReward
\]

新释放速率基于 `rewardCurveBase` 和 `rewardsDuration` 计算。`leftoverBaseReward` 已在旧注入中预留补贴，不能重复计入新增补贴预算。

若新的调度总额无法形成非零 `rewardRate`，必须回退，避免基础奖励进入合约后无法通过水位线释放。

### 8.2 累计注入预算

更新前：

\[
prevInjectedBudget =
\left\lfloor\frac{injectedBaseCumulative \times maxSubsidyRate}{BPS}\right\rfloor
\]

更新累计量：

\[
injectedBaseCumulative \mathrel{+}= actualBaseReward
\]

本次新增最大理论补贴预算：

\[
requiredSubsidy =
\left\lfloor\frac{injectedBaseCumulative \times maxSubsidyRate}{BPS}\right\rfloor -
prevInjectedBudget
\]

该公式先对累计量取整，再求预算增量，避免多次小额注入逐笔向下取整造成预算不足。

### 8.3 使用沉淀备付金

全局同步后取得：

\[
sweepable = maxSweepableSubsidy()
\]

本次需要管理员额外补缴：

\[
subsidyCharged =
\begin{cases}
requiredSubsidy - sweepable, & requiredSubsidy > sweepable \\
0, & requiredSubsidy \le sweepable
\end{cases}
\]

若 `subsidyCharged > 0`，从管理员钱包额外扣款并增加 `subsidyReserve`；否则使用活动池已有沉淀备付金，不发生补贴 Token 转入。

无论是否需要补缴，都必须按更新后的 `injectedBaseCumulative` 与当前 `settledBaseCumulative` 重算 `unsettledMaxSubsidyLiability`。

### 8.4 首次注入示例

基础奖励实际注入 5000，`maxSubsidyRate = 72%`：

- `requiredSubsidy = 3600`；
- 没有历史沉淀时 `subsidyCharged = 3600`；
- 管理员合计转入 8600，其中 5000 归属基础奖池，3600 归属补贴备付金。

## 9. 补贴计提、支付与作废

### 9.1 计提

逐仓结算新增基础奖励时，各补贴独立计算：

\[
inviteeBoostReward =
\left\lfloor\frac{newBaseReward \times inviteeBoost}{BPS}\right\rfloor
\]

\[
lockBoostReward =
\left\lfloor\frac{lockedBaseReward \times boostRate}{BPS}\right\rfloor
\]

\[
referralReward_i =
\left\lfloor\frac{newBaseReward \times level_i}{BPS}\right\rfloor
\]

新增补贴进入对应 pending 账本，同时：

\[
totalPendingSubsidy \mathrel{+}= newPendingSubsidy
\]

`subsidyReserve` 不变，因为尚未发生 Token 支付。

同一次结算还要把本次新归属的基础奖励加入 `settledBaseCumulative`，并统一重算 `unsettledMaxSubsidyLiability`。已经存在于 `pendingBaseReward` 的历史金额不得再次消化。

### 9.2 支付

`claimAll` 或关闭仓位实际支付补贴时：

\[
totalPendingSubsidy \mathrel{-}= paidSubsidy
\]

\[
subsidyReserve \mathrel{-}= paidSubsidy
\]

基础奖励支付只减少 `baseRewardReserve`，不减少补贴账本。

### 9.3 提前解锁作废

提前关闭锁仓仓位时，未解锁的 `pendingBoostReward` 作废：

\[
totalPendingSubsidy \mathrel{-}= forfeitedBoostReward
\]

`subsidyReserve` 不减少，因为现金未离开合约。作废金额在覆盖其余负债后成为可安全复用或提取的沉淀备付金。

## 10. 状态转移表

| 场景 | 入口 | `baseRewardReserve` | `subsidyReserve` | `totalPendingSubsidy` | `unsettledMaxSubsidyLiability` |
| --- | --- | --- | --- | --- | --- |
| 新增基础奖励与补贴补缴 | `notifyRewardAmount` | `+= actualBaseReward` | `+= subsidyCharged` | 不变 | 增加 `injectedBaseCumulative` 后重算 |
| 仓位基础奖励与补贴计提 | `updateReward` | 不变 | 不变 | `+= 新增补贴` | 增加 `settledBaseCumulative` 后重算 |
| 空窗奖励自然流失 | 全局账本同步 | `-= 流失基础奖励` | 不变 | 不变 | 增加 `settledBaseCumulative` 后重算 |
| 基础奖励支付 | `claimAll` / 关闭仓位 | `-= 已支付基础奖励` | 不变 | 不变 | 不变 |
| 补贴支付 | `claimAll` / 关闭仓位 | 不变 | `-= 已支付补贴` | `-= 已支付补贴` | 不变 |
| 提前解锁补贴作废 | 关闭仓位 | 不变 | 不变 | `-= 作废锁仓加速奖励` | 不变 |
| 沉淀补贴提取 | `sweepSubsidy` | 不变 | `-= amount` | 不变 | 同步阶段可因空窗流失重算，提取阶段不变 |
| 过期基础奖励回收 | `sweepExpiredBaseReward` | 归零 | 不变 | 不变 | 增加 `settledBaseCumulative` 后重算 |

## 11. 沉淀补贴安全提取

`sweepSubsidy(to, amount)` 执行前必须先进行等价于 `updateReward(address(0))` 的全局同步，再使用同步后的：

\[
maxSweepableSubsidy =
subsidyReserve - totalPendingSubsidy - unsettledMaxSubsidyLiability
\]

提取阶段只允许：

- `subsidyReserve -= amount`；
- 向 `to` 转出 `amount`。

不得在提取阶段修改：

- `totalSupply`；
- 任一 `pendingBaseReward`；
- `totalPendingSubsidy`；
- `unsettledMaxSubsidyLiability`。

唯一例外是提取前的全局同步可以确认 `totalSupply == 0` 的空窗流失，并通过增加 `settledBaseCumulative` 重算潜在负债。

`maxSweepableSubsidy()` 是只读函数。若当前 `totalSupply == 0`，它必须在只读上下文中临时投影空窗同步后的 `settledBaseCumulative` 和 `unsettledMaxSubsidyLiability`，不修改链上状态。

不得使用以下值替代安全提取公式：

- `rewardToken.balanceOf(address(this))`；
- 同币池 Token 总余额；
- `remainingBaseReward()`。

## 12. 精度与舍入

### 12.1 BPS

所有比例使用 BPS：

- `BPS = 10000` 代表 100%；
- `1000` 代表 10%；
- `500` 代表 5%；
- `1` 代表 0.01%。

### 12.2 奖励速率

`rewardRate` 使用 `PRECISION = 1e18` 放大存储与返回。真实每秒基础奖励为：

\[
actualRewardRatePerSecond = \frac{rewardRate}{10^{18}}
\]

### 12.3 补贴取整

仓位和用户实际补贴按每次新增基础奖励分别向下取整：

\[
\left\lfloor\frac{amount \times rate}{BPS}\right\rfloor
\]

全局最大补贴预算不允许按每次注入、每个仓位或每段自然流失分别取整后累加。必须分别对 `injectedBaseCumulative` 与 `settledBaseCumulative` 按最大补贴率取整，再计算差额。

该累计口径消除分段取整尾差，避免 1 wei 级幽灵补贴负债长期占用 `subsidyReserve`。

## 13. 只读对账口径

- `baseRewardReserve()`：基础奖池未支付余额，是资产覆盖校验口径。
- `remainingBaseReward()`：当前周期尚未释放的展示值，不是偿付校验口径。
- `injectedBaseCumulative()`：注入侧累计量。
- `settledBaseCumulative()`：消化侧累计量。
- `subsidyReserve()`：补贴现金余额。
- `totalPendingSubsidy()`：已确认补贴负债。
- `unsettledMaxSubsidyLiability()`：尚未消化的最大理论补贴预算。
- `maxSweepableSubsidy()`：扣除两类负债后的安全可提取额度。

前端、索引器和运营面板应同时读取这些逻辑账本，不得仅以 Token `balanceOf` 判断偿付能力。