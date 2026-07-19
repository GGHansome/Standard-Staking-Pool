# V2 锁仓推荐质押池监控规格

## 1. 文档职责

本文档定义 V2 运行期间需要观察的事件、状态、不变量和异常条件。事件完整签名由 [`interface-reference.md`](./interface-reference.md) 负责；资金公式由 [`accounting-and-solvency.md`](./accounting-and-solvency.md) 负责；本文档只说明这些信号如何用于确认系统行为。

现有 V2 功能基线没有确定：

- 监控系统与索引器实现；
- 采样频率、确认区块数和数值告警阈值；
- 告警接收人、值班责任人和升级路径；
- 事故确认后的应急操作流程。

因此本文档只记录可以从链上证明的硬性不变量、异常条件和待运营确认项，不编造运行参数。

## 2. 观测目标

监控需要回答：

1. 用户本金、基础奖励和补贴现金是否仍覆盖对应账本；
2. 补贴备付金是否同时覆盖已确认负债与未结算最大理论负债；
3. 奖励注入、结算、支付、作废和回收是否按同一账本口径推进；
4. 仓位、推荐关系和奖励归属是否产生了可重建的事件；
5. 管理员权限、Treasury 和暂停状态是否发生变化；
6. 历史快照是否只在真实奖励曲线折点写入；
7. 前端与索引器是否能从视图函数得到与下一次结算一致的状态。

## 3. 链上观测来源

### 3.1 资金与调度视图

持续对账所需状态：

- `totalSupply()`；
- `baseRewardReserve()`；
- `injectedBaseCumulative()`；
- `settledBaseCumulative()`；
- `remainingBaseReward()`；
- `subsidyReserve()`；
- `totalPendingSubsidy()`；
- `unsettledMaxSubsidyLiability()`；
- `maxSweepableSubsidy()`；
- `getRewardSchedule()`；
- `getSubsidyConfig()`；
- `isRewardPeriodActive()`；
- `stakingToken.balanceOf(pool)` 与 `rewardToken.balanceOf(pool)`。

### 3.2 仓位与推荐视图

用于账户级重建和抽样核对：

- `getDeposit(depositId)`；
- `getActiveDepositIds(user)`；
- `getUserDeposits(user)`；
- `totalStakedOf(user)`；
- `earned(user)`；
- `earnedByDeposit(depositId)`；
- `claimableReferralReward(user)`；
- `hasSetInviter(user)`；
- `inviterOf(user)`；
- `getUpline(user)`；
- `MAX_ACTIVE_DEPOSITS()`。

### 3.3 配置视图

用于确认部署承诺和前端展示：

- `getLockTiers()`；
- `getReferralRates()`；
- `getPenaltyConfig()`；
- `getSubsidyConfig()`；
- AccessControl 角色 getter。

## 4. 硬性不变量

以下条件一旦不成立即代表账本或实现错误，不需要依赖历史业务基线判断。

### 4.1 资产余额覆盖

异币池：

\[
stakingToken.balanceOf(pool) \ge totalSupply
\]

\[
rewardToken.balanceOf(pool) \ge baseRewardReserve + subsidyReserve
\]

同币池：

\[
token.balanceOf(pool) \ge totalSupply + baseRewardReserve + subsidyReserve
\]

交易内罚金处理中间余额不会稳定存在于块后状态；若监控基于交易 trace，还应将该中间归属纳入单次调用核对。

### 4.2 补贴偿付覆盖

\[
subsidyReserve \ge totalPendingSubsidy
\]

\[
subsidyReserve \ge totalPendingSubsidy + unsettledMaxSubsidyLiability
\]

### 4.3 累计负债恒等式

\[
unsettledMaxSubsidyLiability =
\left\lfloor\frac{injectedBaseCumulative \times maxSubsidyRate}{BPS}\right\rfloor -
\left\lfloor\frac{settledBaseCumulative \times maxSubsidyRate}{BPS}\right\rfloor
\]

### 4.4 安全提取恒等式

\[
maxSweepableSubsidy =
subsidyReserve - totalPendingSubsidy - unsettledMaxSubsidyLiability
\]

`totalSupply == 0` 时，链上只读函数应返回临时投影全局同步后的值。离线对账必须使用相同空窗投影口径，不能把未同步的持久化变量直接与视图返回值判为冲突。

### 4.5 仓位汇总

- `totalSupply` 应等于全部活跃 `DepositRecord.amount` 汇总；
- `totalStakedOf(user)` 应等于该用户活跃仓位本金汇总；
- 每个用户活跃仓位数不得超过 `MAX_ACTIVE_DEPOSITS = 50`；
- `getActiveDepositIds(user)` 中每个仓位必须 `owner == user && amount > 0`；
- 已关闭仓位应保留非零 `owner` 且 `amount == 0`，并从活跃 ID 数组移除。

### 4.6 补贴负债汇总

离线索引完整时：

\[
totalPendingSubsidy =
\sum pendingInviteeBoostReward +
\sum pendingBoostReward +
\sum referralRewards
\]

该核对依赖完整仓位与用户级返佣索引，不能只用单个账户抽样替代全局证明。

### 4.7 推荐关系

- `hasSetInviter == false` 时不应存在非零 `inviterOf`；
- `hasSetInviter == true` 时，`inviterOf == address(0)` 表示永久无上级，否则表示永久有效绑定；
- `InviterBound` 或 `NoInviterSet` 对每个用户最多出现一次；
- 现有 V2 不允许邀请关系改写。

## 5. 事件目录与用途

完整参数与 indexed 字段见 [`interface-reference.md`](./interface-reference.md)。

### 5.1 活动配置与权限

- `ActivityConfigured`：建立活动固定配置基线。监控应记录部署时的奖励周期、推荐比例、补贴率上限和罚金率。
- `TreasuryUpdated`：检测罚金接收地址变化；暂停期间也可能发生。
- `RoleGranted` / `RoleRevoked`：检测超级管理员和普通管理员权限变化。
- `Paused` / `Unpaused`：标记入口可用性变化；暂停不代表奖励时间停止。

### 5.2 仓位生命周期

- `Staked`：创建仓位并增加本金。
- `Withdrawn`：记录正常关闭及用户收到的本金。
- `EarlyWithdrawn`：记录提前关闭、本金退还、罚金和作废锁仓加速奖励。
- `DepositClosed`：确认指定 `depositId` 生命周期结束。
- `InviterBound` / `NoInviterSet`：确认首次质押时邀请状态永久定型。

索引器应能从 `Staked` 与关闭事件重建活跃仓位集合和 `totalSupply` 变化。批量提取即使聚合转账，也必须逐仓产生事件。

### 5.3 奖励计提

- `BaseRewardAccrued`：仓位新归属基础奖励。
- `LockBoostRewardAccrued`：仓位新归属锁仓加速奖励。
- `InviteeBoostRewardAccrued`：仓位新归属自身推荐补贴。
- `ReferralRewardAccrued`：指定下级仓位为某级上级产生返佣。
- `LockBoostRewardForfeited`：提前解锁作废未解锁锁仓加速奖励。

这些事件用于重建 pending 状态和解释 `totalPendingSubsidy` 变化。若实现将累计负债重算上提到一次交易末尾，事件消费方应以交易最终状态对账，不假设每个仓位事件后都立即出现一次全局负债更新。

### 5.4 奖励支付

- `BaseRewardPaid`；
- `InviteeBoostRewardPaid`；
- `ReferralRewardPaid`；
- `LockBoostRewardPaid`。

奖励事件按类型拆分，是链下统计的事实来源。`RewardPaid` 只作为聚合兼容事件保留，不能单独用于拆分基础奖励与三类补贴，也不能与拆分事件重复累计。

### 5.5 奖励注入与账本

- `RewardAdded`：记录本次新增基础奖励、理论补贴需求和实际补缴金额。
- `SubsidyReserved`：记录补贴现金进入备付金。
- `UnsettledMaxSubsidyLiabilityUpdated`：记录潜在负债重算结果。
- `RewardCheckpointWritten`：记录快照新增或同时间戳覆盖。
- `SubsidySwept`：记录沉淀补贴提取。
- `ExpiredBaseRewardSwept`：记录周期结束空池后的基础奖励回收。
- `PenaltyPaid`：记录提前解锁罚金流向。
- `Recovered`：记录非核心误转资产救援。

## 6. 状态变化核对

### 6.1 RewardAdded 后

应核对：

- `baseRewardReserve` 增加本次实际新增基础奖励；
- `injectedBaseCumulative` 增加同一实际新增金额，不包含 leftover；
- `subsidyReserve` 只增加 `subsidyCharged`；
- 新 `rewardRate > 0`；
- `periodFinish` 更新到新完整周期终点；
- 补贴覆盖不变量成立；
- 同一时间戳最后一条快照代表新曲线。

### 6.2 用户奖励结算后

应核对：

- 新基础奖励进入对应仓位 pending；
- 各补贴按类型进入仓位或用户级 pending；
- `totalPendingSubsidy` 增加新增补贴总额；
- `settledBaseCumulative` 只增加本次新结算的基础奖励；
- `baseRewardReserve` 在尚未支付时不减少；
- `unsettledMaxSubsidyLiability` 按累计公式重算。

### 6.3 ClaimAll 后

应核对：

- 可领的仓位级 pending 和用户级推荐返佣被清零；
- 未到期锁仓加速奖励仍留在仓位；
- `baseRewardReserve` 减少实际支付基础奖励；
- `subsidyReserve` 与 `totalPendingSubsidy` 等额减少实际支付补贴；
- `totalSupply` 不变；
- 不出现仅由 `claimAll` 触发的 `RewardCheckpointWritten`。

### 6.4 正常关闭后

应核对：

- 用户收到全额本金；
- 仓位内基础奖励、自身推荐补贴和已解锁锁仓加速奖励结清；
- `amount == 0`，仓位从活跃数组移除；
- `totalSupply` 按本金减少；
- 关闭后写入或覆盖新的奖励曲线快照。

### 6.5 提前关闭后

应核对：

- `principalReturned + penaltyAmount == 原仓位 amount`；
- `PenaltyPaid` 的 Treasury 等于交易执行时配置；
- 基础奖励和自身推荐补贴正常支付；
- 未解锁锁仓加速奖励清零并产生作废事件；
- `totalPendingSubsidy` 减少作废金额，`subsidyReserve` 不因作废减少。

### 6.6 SubsidySwept 后

应核对：

- 提取金额不超过调用前完成全局同步后的 `maxSweepableSubsidy()`；
- `subsidyReserve` 只减少提取金额；
- `totalPendingSubsidy` 不变；
- 提取后两项补贴覆盖不变量仍成立。

### 6.7 ExpiredBaseRewardSwept 后

应核对：

- 交易发生在 `block.timestamp >= periodFinish` 且 `totalSupply == 0`；
- 全部 `baseRewardReserve` 被一次性回收并归零；
- `settledBaseCumulative` 增加同额；
- `subsidyReserve` 和 `totalPendingSubsidy` 不变；
- 潜在补贴负债按累计公式降低。

## 7. 快照观测

`RewardCheckpointWritten` 应只与以下入口对应：

- `stake`；
- `withdraw` / `withdrawMultiple`；
- `notifyRewardAmount`。

观察规则：

- `claimAll` 不应单独产生快照事件；
- 到期切分不应单独产生快照事件；
- 同一 `block.timestamp` 多次改变曲线时，最后一条记录应标记为覆盖并保持数组索引不增长；
- 快照 `time` 使用真实区块时间；
- 快照 `periodFinish` 表示从该节点向后生效的周期结束时间。

## 8. 异常条件

以下情况应视为明确异常并进入人工核查：

- 任一资金覆盖或补贴覆盖不变量不成立；
- 链上 `unsettledMaxSubsidyLiability` 与累计公式不一致；
- `maxSweepableSubsidy()` 与三项账本差额不一致，且差异不能由空池只读投影解释；
- `settledBaseCumulative > injectedBaseCumulative`；
- `baseRewardReserve`、`subsidyReserve` 或 `totalPendingSubsidy` 的变化无法由对应交易与事件解释；
- 同一用户出现第二次邀请绑定事件或 `inviterOf` 被改写；
- 活跃仓位超过 50，或关闭仓位仍留在活跃数组；
- `claimAll` 导致 `totalSupply` 变化或写入新的历史快照；
- 暂停状态下成功执行了应阻断入口，或用户退出入口被暂停阻断；
- `Recovered` 的 Token 是 `stakingToken` 或 `rewardToken`；
- `RewardPaid` 与按类型支付事件被重复计入链下奖励总额。

## 9. 前端与索引器展示检查

- `isRewardPeriodActive() == false` 时，前端只能提交活期 `duration == 0`；
- 锁仓期超过当前周期剩余时间时提示“超出部分可能无奖励”，但不阻断；
- `inviterOf == address(0)` 时结合 `hasSetInviter` 区分未首次质押与永久无上级；
- `earned` 不包含未解锁锁仓加速奖励；
- `earnedByDeposit` 应区分未到期待解锁与已到期可领状态；
- `rewardRate` 展示真实每秒速率前先除以 `1e18`；
- `remainingBaseReward` 仅用于周期展示，不作为偿付状态；
- 用户接近 50 个活跃仓位时提前提示创建上限。

## 10. 待运营确认

上线前需要由项目责任人补充，但当前文档不自行决定：

- 各链确认策略和索引回滚处理；
- 状态轮询频率和事件延迟容忍度；
- 除硬性不变量外的预警阈值，例如备付金余量、仓位数量和 Gas 成本趋势；
- 告警接收人、升级责任人和可执行止损权限；
- Treasury、角色和暂停变更的审批与复核流程；
- 异常确认后的应急流程、用户沟通和恢复验证。

在这些事项确认前，本文档属于链上可观测性规格，不代表完整生产监控与应急体系。