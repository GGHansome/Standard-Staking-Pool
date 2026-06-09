# 产品需求文档 (PRD) - V2 锁仓推荐质押池 (V2 Staking Pool with Lock-up & Referral)

## 1. 产品概述 (Product Overview)

### 1.1 业务背景
在 V1 标准双币质押收益池（无锁仓、随存随取）基础上，V2 面向更精细的运营需求，引入锁仓和链上推荐激励能力。V2 主要解决两个问题：一是活期质押难以形成长期资金留存，二是缺少原生的链上推荐增长机制。

因此，V2 在 V1 水位线架构之上，引入**锁仓奖励加速（Lock-up Boost）**、**提前解锁惩罚（Early Unlock Penalty）**和**三级推荐返佣（3-Level Referral）**三大模块。

### 1.2 核心目标
1. **长期留存**：通过“锁仓时间越长、奖励加速比例越高”的规则，鼓励用户长期质押；通过“提前解锁扣除本金”的惩罚机制，增加提前退出成本，提升 TVL 稳定性。
2. **推荐增长**：通过内置的链上三级推荐返佣与用户自身推荐补贴，激励社区成员主动推广项目，降低获客成本。
3. **资金预算约束**：通过“强制补贴备付金（Subsidy Reserve）”机制，使系统额外奖励支出具有可计算的理论上限，降低奖励超发和合约偿付风险。

### 1.3 适用场景
本合约作为部署时可配置、运行期规则固定的质押激励基础设施，适合以下场景：
- **平台币 / 社区代币质押激励**：适用于平台币或社区代币的长期质押、锁仓激励与推荐增长。
- **新币挖矿 / Launchpool**：通过推荐机制辅助新项目冷启动，提升真实参与地址数量。
- **联合营销 (Partner Airdrops)**：支持项目方之间进行用户增长合作，并为有效推广者提供链上激励。

V2 支持两种部署模式：**异币池**（`stakingToken != rewardToken`）和**同币池**（`stakingToken == rewardToken`）。同币池下本金、基础奖励、补贴备付金和罚金处理中间余额可能共用同一 ERC20 余额，但合约必须通过独立逻辑账本维护归属，不能仅依赖 `balanceOf` 判断可提取额度。

---

## 2. 核心术语与账户模型 (Terminology & Accounting Model)

本节先统一 V2 的奖励口径和账本口径。后续机制、流程和安全边界均以本节术语为准。

### 2.1 奖励类型
- **基础奖励（Base Reward）**：由基础奖池按 V1 水位线模型释放，并按用户当前质押份额分配的奖励。所有额外补贴都以基础奖励作为计算基准。
- **锁仓加速奖励（Lock Boost Reward）**：锁仓期内按 `boostRate` 基于基础奖励额外计算的补贴。到期前仅记账；到期并完成水位线切分后，可通过 `claimAll` 或关闭仓位领取。
- **自身推荐补贴（Invitee Boost Reward）**：用户首次质押时绑定了有效邀请人后，该用户自身基于基础奖励额外获得的补贴。
- **推荐返佣（Referral Reward）**：用户的上三级邀请人基于该用户基础奖励获得的返佣。
- **罚金（Penalty）**：用户提前解锁时，从提取本金中按 `penaltyRate` 扣除并转入 Treasury 的金额。

### 2.2 奖励周期状态
- **有效基础奖励释放周期（`isRewardPeriodActive()`）**：当且仅当 `rewardRate > 0 && block.timestamp < periodFinish` 时返回 `true`。该状态是新建锁仓仓位是否开放的唯一判断依据，不影响历史锁仓仓位。

### 2.3 资金账户
V2 的资金账户采用逻辑资金桶模型。异币池中，本金桶与奖励相关资金桶天然分布在不同 ERC20 资产上；同币池中，多个资金桶共用同一个 ERC20 余额，但账本上仍必须独立维护，不得通过合约总余额反推出某一资金桶的可用额度。

- **用户本金桶（Principal Pool）**：所有活跃仓位的本金余额，对应全局 `totalSupply` 和各 `DepositRecord.amount` 汇总。
- **基础奖池（Base Reward Pool）**：由 `notifyRewardAmount` 注入，并进入基础水位线模型按周期平滑释放；其未支付余额对应全局账本变量 `baseRewardReserve`。
- **补贴备付金池（Subsidy Reserve）**：合约当前实际持有、专用于支付锁仓加速奖励、自身推荐补贴和推荐返佣的补贴资金余额。该变量采用现金口径：补缴和沉淀回收会增加余额，补贴实际支付或管理员安全提取会减少余额。
- **已确认补贴负债（`totalPendingSubsidy`）**：系统当前已确认但尚未支付的补贴负债总额。该变量用于约束补贴备付金的滚动抵扣和安全提取。
- **未结算最大补贴负债（`unsettledMaxSubsidyLiability`）**：系统已经为基础奖励预留、但尚未被用户 `updateReward` 实际结算消化的最大理论补贴预算。该变量覆盖“已释放但用户尚未交互确认”的懒结算缺口，以及“尚未释放”的未来潜在补贴负债；已因空窗无人质押而自然流失的基础奖励不再产生补贴预算占用。
- **Treasury**：接收提前解锁罚金的项目方金库地址。

### 2.4 仓位账本
V2 不再使用 V1 的“单账户总余额”模型。用户每次存入资金，合约都会生成一个独立的质押凭证（Deposit Record），即使是相同的锁仓期限，也不合并。

每个 `DepositRecord` 至少包含以下字段：
- `owner`: 仓位归属用户地址
- `amount`: 本金金额
- `unlockTime`: 到期时间戳
- `boostRate`: 该仓位选择的锁仓档位对应的锁仓加速比例。该字段是仓位属性，用于避免结算时反复回查锁仓档位数组。
- `rewardPerTokenPaid`: 该凭证的独立水位线，用于计算该笔资金产生的基础奖励
- `rewardPerTokenAtUnlock`: 该凭证在 `unlockTime` 时刻的全局水位线缓存。
- `boostSettled`: 该仓位是否已经完成到期切分，活期仓位可在创建时直接置为 `true` 不再执行二分查找。
- `pendingBaseReward`: 该凭证累积的未领基础奖励
- `pendingInviteeBoostReward`: 该凭证累积的未领自身推荐补贴
- `pendingBoostReward`: 该凭证累积的未领锁仓加速奖励。

由于每个合约实例代表一个固定规则活动池，自身推荐补贴比例、三级推荐返佣比例和罚金率均为池级固定参数，不需要在每个 `DepositRecord` 中重复保存。仓位账本只保存与单笔仓位自身选择直接相关的字段，以及独立水位线和未领奖励余额。

---

## 3. 核心机制 (Core Mechanisms)

### 3.1 基础水位线奖励
V2 继承 V1 的基础水位线模型。基础奖励由基础奖池按 `rewardRate` 线性释放，并按用户仓位本金占全局 `totalSupply` 的比例分配。

后续所有额外补贴（锁仓加速奖励、自身推荐补贴、推荐返佣）均严格基于该仓位产生的基础奖励进行独立乘法计算，不互相叠加，不产生复利。

### 3.2 锁仓与奖励加速
用户在质押资金时，必须选择一个锁仓档位。
- **锁仓承诺换取奖励加速**：用户从质押生效后，其产生的基础奖励会按所选档位对应的“奖励加速比例”计算额外奖励（例如：活期 0%，30 天 10%，180 天 50%）。
- **独立到期时间**：用户的单笔质押将被单独记录到期时间（`unlockTime`）。
- **到期降级规则 (Post-Maturity Downgrade)**：当某笔仓位到达 `unlockTime` 后，若用户未主动提取本金，该本金将继续留在池内参与基础水位线分配（继续产生基础奖励），但不再产生额外的锁仓加速奖励。用户若想继续享受锁仓加速，需要先 Withdraw 再重新 Stake。

### 3.3 锁仓到期降级的数学实现
为使仓位在 `unlockTime` 后自动降级为活期奖励，合约需要在用户未来任意一次结算时还原 `unlockTime` 对应的全局水位线 `rewardPerToken`。

本系统采用 **历史水位线快照 + 二分查找 + 线性插值**：
1. **全局快照 (Global Checkpoints)**：系统维护 `rewardHistory`，每条快照至少包含 `[time, rewardPerToken, periodFinish]`。`time` 必须使用真实 `block.timestamp`；`periodFinish` 用于插值时处理奖励周期结束边界。
2. **快照写入时机**：`rewardHistory` 只在会改变后续全局奖励曲线的入口写入或覆盖，包括 `stake`、`withdraw` / `withdrawMultiple`、`notifyRewardAmount`。`claimAll` 不改变 `totalSupply`、`rewardRate` 或 `periodFinish`，不得仅因结算奖励而写入快照。`notifyRewardAmount` 应先使用`updateReward`结算到当前区块，随后在新释放曲线生效后写入或覆盖 `time = block.timestamp` 的快照；该快照的 `rewardPerToken` 表示旧曲线截至该时刻结算后的水位线，`periodFinish` 表示从该时刻起向后生效的新奖励周期结束时间。
3. **同区块压缩优化 (Same-block Compression)**：若最后一条快照的 `time == block.timestamp`，直接覆盖其 `rewardPerToken` 与 `periodFinish`，不新增数组长度。覆盖后记录应代表该区块最后一次状态变更后的奖励曲线。
4. **到期切分触发时机**：`updateReward` 逐仓结算时，若仓位满足 `boostRate > 0 && !boostSettled && block.timestamp >= unlockTime`，则计算并缓存 `rewardPerTokenAtUnlock`，再将 `boostSettled` 置为 `true`。到期切分不改变全局奖励曲线，不应为此强制写入快照。
5. **二分查找定位 (Binary Search)**：首次跨越到期点时，系统在 `rewardHistory` 中定位 `time <= unlockTime` 的最后一条快照 `cp1`，以及右侧快照 `cp2`。若命中 `time == unlockTime`，直接返回该水位线。若不存在右侧真实快照，说明从 `cp1` 到当前结算时刻之间没有新的真实曲线折点；此时使用虚拟当前节点作为 `cp2`，仅参与本次到期切分计算，不写入 `rewardHistory`。若当前入口本身会改变全局奖励曲线（如 `stake`、`withdraw / withdrawMultiple`、`notifyRewardAmount`），应在外层状态变更完成后按快照写入规则另行写入或覆盖真实快照；该真实快照的写入原因是全局曲线变化，而不是到期切分。
6. **统一插值计算 (Clamped Linear Interpolation)**：相邻真实快照之间，`totalSupply` 与 `rewardRate` 不变，因此 `rewardPerToken` 线性增长。插值时按 `cp1.periodFinish` 截断时间，避免把奖励结束后的零释放区间摊入锁仓期。
   $$ effectiveUnlockTime = min(unlockTime, cp1.periodFinish) $$
   $$ effectiveCp2Time = min(cp2.time, cp1.periodFinish) $$
   $$ rewardPerTokenAtUnlock = cp1.reward + \frac{(cp2.reward - cp1.reward) \times (effectiveUnlockTime - cp1.time)}{(effectiveCp2Time - cp1.time)} $$
   若 `effectiveCp2Time <= cp1.time`，表示该区间从 `cp1` 起已经没有奖励继续释放，直接返回 `cp1.reward`。

缓存 `rewardPerTokenAtUnlock` 后，仓位奖励可被分为两段：锁仓期内享受锁仓加速，到期后仅计算基础活期奖励。`boostSettled` 表示切分是否完成，`rewardPerTokenAtUnlock` 只保存水位线数值，不承担状态标记语义。该设计将每个仓位的二分查找限制为首次跨越到期点时的一次，后续 `claimAll` 和 `withdraw` 可复用同一结果。

### 3.4 提前解锁惩罚
- **提前退出通道**：即便用户选择了锁仓，仍可在到期前强制取出本金，以满足极端情况下的流动性需求。
- **惩罚规则**：作为提前退出成本，智能合约将扣除用户提取本金的一定比例（如 20%）作为罚金。同时，采用“锁仓加速奖励到期解锁”机制：用户提前解锁时，其未到期的锁仓加速奖励将全部作废清零，而基础奖励不受影响。
- **罚金流向**：扣除的本金罚金将统一实时转入合约配置的 Treasury。项目方可自由决定该笔罚金的用途：若希望将其分给其他质押者，运营团队可定期将 Treasury 中的罚金作为奖励，通过 `notifyRewardAmount` 重新注入质押池，实现平滑发放；若希望通缩，则可直接提取销毁。

### 3.5 三级推荐系统
系统采用平台额外补贴机制（Protocol-funded Subsidy），不从下级本金或基础奖励中扣除推荐返佣。

- **终身一次性绑定机制**：用户在生命周期中的首次质押时，系统会永久锁定其邀请关系状态。
- **有效邀请人**：邀请人必须已完成首次质押绑定（`hasSetInviter[inviter] == true`），且非零、非本人、向上 3 级不成环。满足条件时永久绑定该上级。
- **无上级状态**：若未填写邀请人（直接质押），则该账户被永久标记为“无上级”。系统冷启动阶段的首批用户在尚不存在已完成首次质押绑定的邀请人时，也只能以“无上级”身份完成首次质押。
- **绑定边界**：一旦完成首次质押，该用户的邀请关系即被永久固化。后续无论其追加质押，还是提取全部资金后再次质押，均无法再修改或补填邀请人。
- **自身推荐补贴**：填写了有效邀请人的新用户，其个人基础奖励将额外获得一笔补贴（如 +5%）。
- **上级推荐返佣**：用户的上三级邀请人将分别获得该用户基础奖励一定比例的返佣（如一级 10%，二级 5%，三级 2%）。

---

## 4. 经济模型与偿付约束 (Economic Model & Solvency)

V2 的核心设计难点是协调“固定基础奖池（水位线）”与“动态额外补贴”。奖励侧采用“基础奖池 + 补贴备付金池（Subsidy Reserve）”双池架构，为额外补贴设置明确预算上限；全局资产账本仍按本金、基础奖励和额外补贴拆分为三类逻辑资金桶。

### 4.1 基础奖池与补贴备付金账本不变量
V2 必须将本金、基础奖励和额外补贴拆分为互不挪用的逻辑资金桶：

- **用户本金桶**：覆盖所有活跃仓位的本金，对应 `totalSupply`。
- **基础奖池桶**：覆盖基础水位线模型下已注入但尚未释放、已释放但尚未领取的基础奖励。
- **补贴备付金桶**：覆盖所有平台额外补贴，包括锁仓加速奖励、自身推荐补贴和推荐返佣，对应 `subsidyReserve`。

异币池中，本金桶由 `stakingToken` 余额覆盖，基础奖池桶和补贴备付金桶由 `rewardToken` 余额覆盖。同币池中，上述资金桶共用同一 ERC20 余额，但仍必须通过独立账本变量表达归属，安全提取或救援逻辑不得直接以 `balanceOf(address(this))` 作为可提取余额。

基础奖池未支付余额必须通过独立全局账本变量 `baseRewardReserve` 维护，不得等同于 `remainingBaseReward()`，也不得通过遍历所有仓位的待领奖励反推。`baseRewardReserve` 表示合约当前仍需覆盖的基础奖励余额，其状态变化规则如下：

- `notifyRewardAmount(baseRewardAmount)` 将新的基础奖励实际转入合约并纳入释放曲线时，`baseRewardReserve += baseRewardAmount`。续奖时上一期 `leftoverBase` 只是重新进入新的释放曲线，不重复增加 `baseRewardReserve`。
- `updateReward` 只将基础奖励结算进仓位 `pendingBaseReward`，不发生 token 支付，因此不得减少 `baseRewardReserve`。
- `claimAll`、`withdraw`、`withdrawMultiple` 实际支付基础奖励时，`baseRewardReserve` 按本次支付的基础奖励金额等额减少。
- `totalSupply == 0` 空窗期间基础奖励自然流失，并且通过全局奖励账本同步确认流失金额时，`baseRewardReserve` 按本次确认流失的基础奖励金额等额减少。

因此，下文“基础奖池未支付余额”均指 `baseRewardReserve`。该变量是资产余额覆盖不变量的链上校验口径，`remainingBaseReward()` 仅用于前端展示当前周期尚未释放的基础奖励，不能用于偿付校验。

任意时刻必须满足以下账本不变量：

1. **资产余额覆盖不变量**：异币池中，`stakingToken` 余额必须覆盖 `totalSupply` 及罚金处理中间余额，`rewardToken` 余额必须覆盖 `baseRewardReserve` 与 `subsidyReserve`；同币池中，单一 token 余额必须同时覆盖 `totalSupply`、`baseRewardReserve`、`subsidyReserve` 及罚金处理中间余额。
2. `subsidyReserve >= totalPendingSubsidy`，确保所有已确认但尚未支付的补贴负债都有补贴现金兜底。
3. `subsidyReserve >= totalPendingSubsidy + unsettledMaxSubsidyLiability`，确保已确认补贴负债和所有尚未结算消化的最大理论补贴预算均有补贴现金兜底。
4. `availableSubsidy = subsidyReserve - totalPendingSubsidy - unsettledMaxSubsidyLiability`，仅该差额可被本活动后续追加奖励滚动复用或在满足安全边界时被管理员提取。
5. `totalPendingSubsidy = Σ(pendingInviteeBoostReward) + Σ(pendingBoostReward) + Σ(referralRewards)`，其中前两项按所有活跃仓位汇总，第三项按所有用户级推荐返佣账本汇总。

补贴账本的状态变更规则如下：

- **补贴计提**：`updateReward` 新增自身推荐补贴、锁仓加速奖励或推荐返佣时，`totalPendingSubsidy` 等额增加，`subsidyReserve` 不变。
- **未结算预算消化**：`updateReward` 按仓位结算新增基础奖励时，必须按该段基础奖励对应的最大理论补贴预算扣减 `unsettledMaxSubsidyLiability`。该扣减只允许发生在用户/仓位实际结算时，不得随时间自动下降。
- **空窗预算释放**：若奖励周期运行期间 `totalSupply == 0`，该时间段对应的基础奖励按 V1 逻辑自然流失，不会形成任何用户基础奖励或额外补贴；合约在全局水位线更新时应按该段流失基础奖励对应的最大理论补贴预算扣减 `unsettledMaxSubsidyLiability`。
- **补贴支付**：`claimAll` 支付自身推荐补贴、推荐返佣和已到期仓位的已解锁锁仓加速奖励，或 `withdraw` / `withdrawMultiple` 在关闭仓位前支付该仓位尚未领取的自身推荐补贴、到期锁仓加速奖励时，`totalPendingSubsidy` 与 `subsidyReserve` 必须按实际支付的补贴金额等额减少。
- **补贴作废**：用户提前解锁导致未解锁锁仓加速奖励作废时，只减少 `totalPendingSubsidy`，不减少 `subsidyReserve`；该部分资金重新成为可用备付金。
- **备付金补缴或提取**：`notifyRewardAmount` 补缴时增加 `subsidyReserve`，并按本次纳入释放曲线的基础奖励增加 `unsettledMaxSubsidyLiability`；`sweepSubsidy` 必须先执行全局奖励账本同步，再计算可提取额度。若同步阶段确认存在 `totalSupply == 0` 的空窗奖励自然流失，应按空窗预算释放规则扣减 `unsettledMaxSubsidyLiability`；提取阶段只按 `amount` 减少 `subsidyReserve`，且不得破坏上述不变量。

对应状态转移表如下：

| 操作场景 | 触发入口 | `subsidyReserve` 变化 | `totalPendingSubsidy` 变化 | `unsettledMaxSubsidyLiability` 变化 | 说明 |
| --- | --- | --- | --- | --- | --- |
| 补贴备付金补缴 | `notifyRewardAmount` | `+= subsidyCharged` | 不变 | `+= requiredSubsidy`（本次新增基础奖励对应的理论最大补贴预算，不等于实际补缴额） | 管理员为新进入释放曲线的基础奖励补足理论最大补贴预算。 |
| 补贴计提与预算消化 | `updateReward` | 不变 | `+= 新增补贴金额` | `-= 本次新增基础奖励对应的最大理论补贴预算` | 自身推荐补贴、锁仓加速奖励、推荐返佣从潜在支出转为已确认补贴负债；未实际产生的最大预算差额转为沉淀备付金。 |
| 空窗奖励自然流失 | `updateReward` / 全局水位线更新入口 | 不变 | 不变 | `-= 流失基础奖励对应的最大理论补贴预算` | `totalSupply == 0` 期间基础奖励不归属任何用户，也不会产生额外补贴，对应预留预算可释放为沉淀备付金。 |
| 日常补贴支付 | `claimAll` | `-= 已支付补贴金额` | `-= 已支付补贴金额` | 不变 | 支付 `pendingInviteeBoostReward`、`referralRewards`，以及已到期仓位中已解锁的 `pendingBoostReward`；基础奖励支付不影响补贴账本变量。 |
| 关闭仓位前补贴支付 | `withdraw` / `withdrawMultiple` | `-= 已支付补贴金额` | `-= 已支付补贴金额` | 不变 | 关闭仓位前支付该仓位尚未领取的 `pendingInviteeBoostReward`；若仓位已到期且仍有未领取 `pendingBoostReward`，同时支付该余额。 |
| 提前解锁补贴作废 | `withdraw` / `withdrawMultiple` | 不变 | `-= 作废的 pendingBoostReward` | 不变 | 未解锁锁仓加速奖励不再支付，补贴现金未离开合约，重新成为可用备付金。 |
| 沉淀备付金提取 | `sweepSubsidy` | 提取阶段 `-= amount` | 不变 | 同步阶段可能因空窗预算释放扣减；提取阶段不变 | 执行前先同步全局奖励账本，再按同步后的 `maxSweepableSubsidy()` 校验并提取沉淀资金。 |

### 4.2 最大理论补贴率
系统在配置阶段必须计算最大理论额外支出比例：
- 假设极端情况：所有用户都有完整的上三级邀请关系、全部填写了有效邀请人，且全部选择最长锁仓期限。
- **最大补贴率**：`maxSubsidyRate = inviteeBoost + level1 + level2 + level3 + max(boosts[])`。若锁仓档位为空，`max(boosts[])` 按 0 处理。
- **部署上限**：`MAX_SUBSIDY_RATE` 由构造函数传入并作为 immutable 配置保存，表示本活动池允许的最大额外补贴预算上限。该上限同样采用 BPS 精度；构造函数必须校验 `maxSubsidyRate <= MAX_SUBSIDY_RATE`。部署后 `MAX_SUBSIDY_RATE` 与 `maxSubsidyRate` 均不可修改。
- 示例配置下，自身推荐补贴 (5%) + 一级返佣 (10%) + 二级返佣 (5%) + 三级返佣 (2%) + 最长锁仓加速奖励 (如 180 天的 50%) = **72%**。
- 在该配置下，系统需要支付的额外补贴理论上限为基础奖励的 72%。因此，包含基础奖励在内的总奖励预算上限为基础奖池的 172%。

### 4.3 奖励注入与备付金滚动
管理员调用 `notifyRewardAmount(baseRewardAmount)` 注入新奖励时，系统同步计算补贴备付金。

1. **首次注入（强制预留）**：若首次注入 5000 个代币作为基础奖励，合约按最大补贴率（如 72%）额外扣除 3600 个代币存入 `subsidyReserve`，管理员合计支付 8600 个代币。
2. **后续追加（同活动续奖与备付金滚动）**：同一活动池允许管理员在活动规则不变的前提下继续注入基础奖励，用于延长或平滑当前活动的奖励释放。后续追加时，系统需要同时区分“奖励释放曲线口径”和“补贴预算新增口径”：
   - **新释放曲线的基础奖励总额**：`rewardCurveBase = baseRewardAmount (本次新注入) + leftoverBase (上一期未发完的剩余基础奖励)`。该值用于计算新的 `rewardRate`，确保上一期未释放完的基础奖励与本次新增基础奖励一起进入新的线性释放周期。
   - **本次新增补贴预算的基础奖励额**：`newSubsidyBase = baseRewardAmount`。
   - **本次新增所需的理论最大备付金**：`requiredSubsidy = floor(newSubsidyBase * maxSubsidyRate / BPS)`，舍入规则见第 6.5 节。
   - **当前可用的剩余备付金**：`availableSubsidy = subsidyReserve  - totalPendingSubsidy - unsettledMaxSubsidyLiability`，定义见第 4.1 节。该值必须同时扣除已确认补贴负债和未结算最大补贴负债，确保历史用户尚未 `claimAll` 或尚未触发 `updateReward` 的补贴预算不被本活动后续追加奖励挪用。
   - **最终需补缴金额**：`subsidyCharged = requiredSubsidy > availableSubsidy ? requiredSubsidy - availableSubsidy : 0`。若 `subsidyCharged > 0`，从管理员钱包额外扣除该金额并存入 `subsidyReserve`；否则直接使用池内沉淀备付金。
   - **记录未结算最大补贴负债**：无论本次是否需要额外补缴，`requiredSubsidy` 都必须加入 `unsettledMaxSubsidyLiability`，表示本次新注入的基础奖励在被用户实际结算前，对补贴备付金仍构成最大理论潜在负债。

该公式支持同一活动内多次基础奖励注入的平滑过渡，并避免对上一期 `leftoverBase` 重复计提补贴预算。沉淀备付金能否复用，取决于扣除 `totalPendingSubsidy` 与 `unsettledMaxSubsidyLiability` 后是否仍有余额。

首次 `notifyRewardAmount` 前，用户可提前 `stake` 建立活期仓位，但不能选择锁仓档位。锁仓档位仅在 `isRewardPeriodActive() == true` 时开放；首次注入前和周期间空窗均只允许活期质押。若 `notifyRewardAmount` 时 `totalSupply == 0`，奖励周期仍按 V1 逻辑立即启动；空池期间 `rewardPerToken` 不增长，已释放奖励视为自然流失。

### 4.4 补贴负债与未结算预算记账
为保证补贴偿付能力，合约必须维护 `totalPendingSubsidy` 与 `unsettledMaxSubsidyLiability` 两个全局变量。前者表示已确认但尚未支付的补贴负债；后者表示已按最大补贴率预留、但尚未被 `updateReward` 结算消化的理论补贴预算。

`updateReward` 实际产生补贴时，补贴金额累加至 `totalPendingSubsidy`；`claimAll` 或 `withdraw` / `withdrawMultiple` 支付补贴时，`totalPendingSubsidy` 与 `subsidyReserve` 等额扣减；提前违约导致锁仓加速奖励作废时，仅扣减 `totalPendingSubsidy`。

`unsettledMaxSubsidyLiability` 的核心规则是“注入时增加，用户结算或空窗流失时减少，不因有 TVL 的正常时间流逝自动下降”：

1. `notifyRewardAmount` 将新的基础奖励纳入释放曲线时，按该批基础奖励对应的最大理论补贴率计算 `requiredSubsidy`，并将其加入 `unsettledMaxSubsidyLiability`。
2. `updateReward` 逐仓结算时，先计算该仓位本次新增的基础奖励，再按 `maxSubsidyBudgetDelta = floor(新增基础奖励 * maxSubsidyRate / BPS)` 计算该段最大理论补贴预算，并从 `unsettledMaxSubsidyLiability` 中饱和扣减。该扣减只对应本次新结算出的基础奖励，不得重复扣减已经进入 `pendingBaseReward` 的历史基础奖励；实际扣减金额为 `min(maxSubsidyBudgetDelta, unsettledMaxSubsidyLiability)`，防止舍入尾差或极端状态导致 underflow。
3. 若全局水位线更新时发现上一段时间内 `totalSupply == 0`，该段时间对应的基础奖励按空窗奖励自然流失处理。由于该部分基础奖励不会被任何仓位结算，也不会产生补贴，合约应按自然流失的基础奖励额计算 `maxSubsidyBudgetDelta = floor(自然流失的基础奖励额 * maxSubsidyRate / BPS)`，并从 `unsettledMaxSubsidyLiability` 中饱和扣减。该逻辑应位于 `updateReward` 的全局账本同步阶段；`stake`、`withdraw` / `withdrawMultiple`、`notifyRewardAmount`、`claimAll` 以及 `sweepSubsidy` 触发全局同步时均可执行该扣减。
4. 同一次 `updateReward` 中，实际产生的自身推荐补贴、锁仓加速奖励和推荐返佣按池级固定比例及仓位记录的 `boostRate` 分别向下取整后加入 `totalPendingSubsidy`。若真实补贴低于最大理论预算，差额留在 `subsidyReserve` 中，并在 `totalPendingSubsidy + unsettledMaxSubsidyLiability` 均覆盖后成为可安全复用或提取的沉淀备付金。
5. 部署完成后 `maxSubsidyRate` 与 `MAX_SUBSIDY_RATE` 均不可修改；同一活动内后续 `notifyRewardAmount` 仍使用部署时确定的 `maxSubsidyRate` 计算新增预算。

### 4.5 沉淀备付金与安全提取
由于并非所有仓位都会触发最大补贴率，备付金池可能产生沉淀资金。管理员可通过 `sweepSubsidy` 提取，但必须满足安全边界：

**`maxSweepableSubsidy` 最大可提取金额 = `subsidyReserve` 当前实际补贴备付金余额 - `totalPendingSubsidy` (已确认负债) - `unsettledMaxSubsidyLiability` (未结算最大补贴负债)**

`sweepSubsidy` 的安全边界只能来自上述逻辑账本公式，不能来自 `rewardToken.balanceOf(address(this))` 或同币池总余额。执行时必须先进行一次等价于 `updateReward(address(0))` 的全局奖励账本同步，再使用同步后的 `maxSweepableSubsidy()` 校验 `amount`。

全局同步阶段只允许按第 4.4 节规则推进基础奖励水位线状态，并在 `totalSupply == 0` 的空窗场景下释放对应的 `unsettledMaxSubsidyLiability`。同步完成后的提取阶段只能按 `amount` 扣减 `subsidyReserve` 后转出；不得修改 `totalSupply`、`pendingBaseReward`、`totalPendingSubsidy`，也不得在空窗预算释放之外额外修改 `unsettledMaxSubsidyLiability`。同币池中也只能提取账本确认的沉淀补贴备付金。

其中，`unsettledMaxSubsidyLiability` 同时覆盖两类尚未确认真实补贴金额的潜在负债：

1. **已释放但未结算的懒结算缺口**：基础奖励已经通过时间释放，但用户或仓位尚未触发 `updateReward`，因此对应的自身推荐补贴、锁仓加速奖励和推荐返佣尚未计入 `totalPendingSubsidy`。
2. **尚未释放的未来潜在负债**：当前和后续奖励释放过程中，未来仍可能产生的最大理论补贴。

已在 `totalSupply == 0` 空窗期间自然流失、且已完成全局水位线更新确认的基础奖励，不再属于上述潜在负债范围。

因此，`maxSweepableSubsidy()` 不依赖 `remainingBaseReward()` 随时间下降释放额度；只有用户交互完成补贴结算，或空窗奖励自然流失并完成预算扣减后，未使用预算才会释放为沉淀备付金。只读调用 `maxSweepableSubsidy()` 不修改状态，但当 `totalSupply == 0` 时，应在只读上下文中按第 4.4 节空窗预算释放规则临时计算同步后的可提取额度。`sweepSubsidy` 和 `notifyRewardAmount` 等写入口必须先完成全局同步，再使用同步后的账本值执行校验。

---

## 5. 用户流程与状态变更 (User Flows)

### 5.1 资金存入与邀请绑定 (Stake)
1. 前端获取用户的锁仓选择（如 90 天）及邀请人地址（如 `inviterAddress`）。
2. 合约校验当前质押选择。若用户选择 `duration > 0` 的锁仓档位，则必须满足 `isRewardPeriodActive() == true`，否则必须 revert；活期仓位 `duration == 0` 不受该限制，首次奖励注入前与周期间空窗均可创建。
3. 合约前置触发 `updateReward`，结算历史奖励。
4. **记录绑定关系（终身一次性）**：合约通过 `hasSetInviter` 判断是否首次质押。首次质押时，若 `inviterAddress` 满足第 3.5 节“有效邀请人”定义，则记录该邀请人；若传入 `address(0)`，则记录为“无上级”；若传入非零但无效地址，则必须 revert。完成后将 `hasSetInviter[msg.sender]` 设为 `true`。非首次质押时，直接忽略邀请人参数。
5. **生成独立质押凭证**：
   - 扣除用户本金存入合约。
   - 分配一个全局自增的 `depositId` 作为该笔质押的唯一键。
   - 按第 2.4 节记录仓位字段。创建时 `rewardPerTokenAtUnlock` 初始化为 0；锁仓加速仓位的 `boostSettled` 初始化为 `false`，活期或无加速仓位可初始化为 `true` 或按 `boostRate == 0` 短路处理。
6. 增加全局 `totalSupply`，并在结算完成后写入或覆盖当前区块的 `rewardHistory` 快照，使该快照成为后续奖励曲线按新 `totalSupply` 计算的真实折点。

### 5.2 领取奖励与返佣分发 (Claim Reward)
V2 将奖励划分为“仓位奖励”和“推荐返佣”两条线。仓位奖励记录在 `DepositRecord` 中，推荐返佣记录在用户级账本 `referralRewards` 中，确保用户提取全部本金后仍可领取历史返佣。

1. 合约前置触发 `updateReward`，遍历该用户的所有活跃仓位进行结算。`claimAll` 不改变 `totalSupply`、`rewardRate` 或 `periodFinish`，因此本入口不得仅因执行 `updateReward` 而写入 `rewardHistory`。
2. 计算每个仓位产生的基础奖励。
3. 计算并记账额外补贴：
   - **锁仓加速奖励**：每次结算基础奖励时，同步计算锁仓期内的加速奖励。若 `boostRate == 0` 或 `boostSettled == true`，本次新增基础奖励不再产生锁仓加速奖励。若仍处于锁仓期，则按 `floor(新增基础奖励 * boostRate / BPS)` 累加到 `pendingBoostReward`。若本次首次跨越 `unlockTime`，则按第 3.3 节完成到期切分，只对锁仓期内对应的基础奖励计入加速奖励，并将 `boostSettled` 置为 `true`。
   - **自身推荐补贴**：每次结算基础奖励时，若该仓位所属用户绑定了有效邀请人且池级 `inviteeBoost > 0`，则计算 `floor(新增基础奖励 * inviteeBoost / BPS)`，并单独计入该仓位的 `pendingInviteeBoostReward` 中，不得混入 `pendingBaseReward`。
   - **推荐返佣**：依据池级固定的 `level1, level2, level3`，按第 6.5 节舍入规则分别计算向上三级的返佣，并累加到各级上级的用户级账本 `referralRewards[上级地址]` 中。
4. 将本次实际补贴计入 `totalPendingSubsidy`，并按本次新增基础奖励对应的最大理论补贴预算扣减 `unsettledMaxSubsidyLiability`。自身推荐补贴和推荐返佣可日常领取；锁仓加速奖励到期前仅记账，完成 `boostSettled` 切分后才可通过 `claimAll()` 领取。
5. **结算与发放**：主动领奖接口仅提供 `claimAll()`。调用时，合约汇总所有活跃仓位的 `pendingBaseReward`、`pendingInviteeBoostReward`、已解锁 `pendingBoostReward` 以及用户级 `referralRewards`，一次性转账并清零对应余额。基础奖励不影响 `subsidyReserve`；补贴支付必须等额扣减 `totalPendingSubsidy` 和 `subsidyReserve`。

### 5.3 提取本金 (Withdraw)
单笔质押凭证（Deposit Record）必须全额提取，不支持部分提取。若用户需要资金灵活性，应在存入时拆分为多笔质押，以降低状态机复杂度和精度风险。

接口设计：
- `withdraw(uint256 depositId)`：用于精确提取某一笔特定仓位。
- `withdrawMultiple(uint256[] calldata depositIds)`：用于前端实现“一键提取多个/所有活期仓位”等聚合操作，节省用户多次签名的交互成本。

`withdrawMultiple` 失败策略：
- **整体原子性**：批量提取必须采用全有或全无策略。任一 `depositId` 无效、非调用者所有、已提取、重复传入或不满足内部校验时，整笔交易必须 revert，避免出现部分成功导致前端状态和链上状态不一致。
- **重复 ID 拦截**：同一批次中不得重复传入相同 `depositId`。实现上可通过逐个校验仓位 `amount > 0` 并在处理后立即标记/移除来防止重复消费；若检测到重复 ID，必须 revert。
- **长度限制**：`depositIds.length` 必须大于 0，且不得超过 `MAX_ACTIVE_DEPOSITS` 或单独定义的批量上限，防止用户构造超长数组导致 Out of Gas。
- **统一结算**：批量提取开始前应先对调用者执行一次 `updateReward`，结算所有活跃仓位截至当前区块的奖励，再逐笔处理本金、罚金、奖励支付和锁仓加速奖励解锁/作废。
- **聚合转账**：为降低 Gas 和减少外部调用，批量提取过程中应先在内存中累计 `principalToUser`、`penaltyToTreasury`、`baseRewardToUser`、`inviteeBoostToUser` 和 `unlockedBoostToUser`，完成全部状态更新后再分别执行必要的 `safeTransfer`。
- **事件逐笔记录**：即使转账聚合执行，也必须为每个被提取的 `depositId` 抛出独立事件，便于链下索引器按仓位统计。

单笔提取执行逻辑：
1. 根据 `depositId` 读取仓位并执行基础校验：`owner != address(0)` 确认仓位存在，`owner == msg.sender` 确认仓位归属调用者，`amount > 0` 确认仓位尚未关闭；随后校验该笔存款的 `unlockTime`。
2. **关闭前奖励结清**：在销毁仓位并从 `activeDepositIds` 移除前，必须结清该凭证内所有已结算的仓位级可领奖励，包括 `pendingBaseReward`、`pendingInviteeBoostReward`，以及已解锁的 `pendingBoostReward`。支付完成后清零对应 pending 字段，补贴支付同步扣减 `totalPendingSubsidy` 和 `subsidyReserve`，禁止把未领奖励残留在已关闭仓位中。
3. **分支 A：正常到期提取**：退还全额本金。若凭证内仍有未领取的已解锁锁仓加速奖励，则关闭仓位时一并支付；若此前已通过 `claimAll` 领取，则不得重复支付。
4. **分支 B：提前违约提取**：
   - 读取池级固定 `penaltyRate`（假设 20%）。
   - 按 `floor(amount * penaltyRate / BPS)` 扣除罚金，并实时转入 Treasury。
   - 退还扣除罚金后的剩余本金给用户。
   - 直接清零作废其在该笔资金上产生的未解锁锁仓加速奖励。该作废金额只扣减 `totalPendingSubsidy`，不扣减 `subsidyReserve`；基础奖励和自身推荐补贴不受提前违约影响，必须按第 2 步在关闭前正常发放。
5. 销毁该笔质押凭证（`amount = 0`），扣减 `totalSupply`，从 `activeDepositIds` 中移除该仓位，并在结算完成后写入或覆盖当前区块的 `rewardHistory` 快照，使该快照成为后续奖励曲线按新 `totalSupply` 计算的真实折点。

---

## 6. 配置、权限与精度规范 (Configuration & Access Control)

### 6.1 角色权限
继承 V1 的权限架构，V2 同样区分超级管理员（Super Admin / Owner）与普通管理员（Normal Admin / Operator）：
- **超级管理员**：负责核心资产与系统级安全配置，如设置 Treasury 地址、分配普通管理员权限。
- **普通管理员**：负责活动奖励注入 `notifyRewardAmount` 等日常运营动作。

### 6.2 部署固定配置
V2 将每个合约实例视为一个独立活动池。所有涉及经济承诺的配置（奖励周期、锁仓档位、推荐返佣比例、自身推荐补贴比例、最大额外补贴预算上限、罚金率）必须在部署时通过构造函数一次性声明，并在合约生命周期内不可修改，以保证预算、偿付上限、用户承诺和前端展示口径一致。

### 6.3 活动固定配置与仓位字段
部署时确定的全局配置构成本活动池的固定活动规则。由于经济参数不可修改，历史仓位和新仓位在同一活动池内不会因为运营调参而出现不同补贴口径。

### 6.4 隐式开关规则
为兼顾合约简洁性、Gas 成本和复用性，V2 对推荐比例、罚金率等数值型配置采用“0 即关闭（0 means disabled）”；锁仓加速模块由 `durations[]` 与 `boosts[]` 成对定义，关闭方式以空档位配置为准。

#### 锁仓加速模块
- **配置来源**：构造函数参数 `durations[]` 与 `boosts[]`
- **开启**：配置多档位，如 `[30, 90]`, `[10%, 30%]`。
- **一键关闭**：部署时传入空档位配置，即 `durations = []` 且 `boosts = []`。系统仅允许创建活期仓位，并跳过锁仓、加速和提前解锁判断，退化为纯活期 V1。

#### 三级推荐模块
- **配置来源**：构造函数参数 `inviteeBoost, level1, level2, level3`
- **开启**：正常配置如 `5%, 10%, 5%, 2%`。
- **灵活降级**：若只需一级推荐，配置为 `5%, 10%, 0, 0`。合约执行时遇到 `level2 == 0`，直接跳过后续层级计算。
- **一键关闭**：配置为 `0, 0, 0, 0`。系统关闭推荐逻辑。

#### 提前解锁惩罚模块
- **配置来源**：构造函数参数 `penaltyRate`
- **一键关闭**：部署时将参数设置为 `0`。即使用户提前提取，也不扣除本金。
- **上限约束**：`penaltyRate` 必须满足 `penaltyRate <= BPS`。当 `penaltyRate == BPS` 时，提前解锁罚金等于全部本金，用户本金退还额为 0；不得配置为超过 100%，避免罚金超过本金导致提前退出分支不可执行。

#### 锁仓、加速与罚金组合语义
为避免“锁仓模块关闭”和“罚金模块关闭”之间产生二义性，V2 对锁仓档位、加速比例和罚金率的组合语义作如下约束：

- **活期档位**：`duration == 0` 表示活期仓位。活期仓位没有锁仓到期语义，`unlockTime` 统一记为 0，`boostRate` 必须为 0；任何时候提取都不视为提前解锁，也不得产生罚金。
- **锁仓档位**：`duration > 0` 表示锁仓仓位。该仓位在 `block.timestamp < unlockTime` 时提取属于提前解锁；是否扣罚取决于池级固定 `penaltyRate`。
- **加速关闭但锁仓存在**：不允许配置 `duration > 0` 且 `boostRate == 0` 的锁仓档位。若没有额外锁仓加速，则不应要求用户承担锁仓约束，避免“无收益但有锁定/罚金”的不公平组合。
- **锁仓模块关闭**：当锁仓档位配置为空时，系统仅允许创建活期仓位，`boostRate = 0`，`unlockTime = 0`，并跳过锁仓加速和提前解锁判断。
- **罚金模块关闭**：`penaltyRate == 0` 仅表示提前解锁不扣本金，不代表锁仓模块关闭。用户仍需要等到到期后才能领取锁仓加速奖励；若提前提取，则未解锁的锁仓加速奖励仍按规则作废。
- **配置校验**：构造函数必须校验 `durations.length == boosts.length`，档位数量不超过上限，`durations` 不重复，且所有 `duration > 0` 的档位必须满足 `boostRate > 0`。活期档位可由系统隐式支持，不要求管理员显式配置。
- **补贴预算上限校验**：构造函数必须按第 4.2 节计算 `maxSubsidyRate`，并校验 `maxSubsidyRate <= MAX_SUBSIDY_RATE`。`inviteeBoost`、`level1`、`level2`、`level3` 与 `boosts[]` 不设置单项上限；其部署安全边界由聚合后的 `MAX_SUBSIDY_RATE` 约束。

#### Treasury 金库地址
- **配置接口**：`setTreasury(address _treasury)`
- **说明**：用于接收用户提前解锁时扣除的违约罚金。该地址必须为非零有效地址。
- **修改时机**：`setTreasury` 不受第 6.2 节部署固定配置限制，可在活动进行中调用。Treasury 地址不写入仓位字段，不参与基础奖励、补贴备付金或最大理论补贴率计算；罚金始终在用户提前提取发生时转入当时配置的 Treasury。

### 6.5 精度规范
- **Basis Point（基点）精度**：智能合约中不支持浮点数，因此本 PRD 中涉及的所有百分比（如锁仓加速比例 `boosts`、推荐补贴与返佣比例 `inviteeBoost / level1 / level2 / level3`、罚金率 `penaltyRate` 等）在合约底层均采用万分位（Basis Point, BPS）精度标准。
- **换算关系**：`10000` 代表 `100%`，`1000` 代表 `10%`，`500` 代表 `5%`，`1` 代表 `0.01%`。
- **补贴舍入规则**：所有按比例计算的补贴相关金额均采用向下取整，即 `floor(amount * rate / BPS)`。该规则统一适用于 `notifyRewardAmount` 中的 `requiredSubsidy`、`updateReward` 中的 `maxSubsidyBudgetDelta`，以及实际计提到 `pendingInviteeBoostReward`、`pendingBoostReward`、`referralRewards` 的自身推荐补贴、锁仓加速奖励和推荐返佣。不得对实际补贴支付使用向上取整，避免 BPS 精度尾差导致支付金额超过已按相同口径预留的最大理论预算。
- **负债饱和扣减**：扣减 `unsettledMaxSubsidyLiability` 时必须使用饱和扣减语义，实际扣减金额为 `min(maxSubsidyBudgetDelta, unsettledMaxSubsidyLiability)`；当计算出的预算释放额大于当前未结算负债余额时，将 `unsettledMaxSubsidyLiability` 置为 0，不得发生 underflow。

---

## 7. 安全边界与异常处理 (Risk Management)

### 7.1 活跃仓位数量限制
为防止大量微小仓位导致 `updateReward` 遍历时 Out of Gas，合约必须引入双数组分离机制。仅将 `amount > 0` 的仓位 ID 存入 `activeDepositIds`，并限制最大长度（如 `MAX_ACTIVE_DEPOSITS = 50`）。该上限必须通过视图接口暴露，便于前端提示。

当仓位被提取（`amount = 0`）时，采用 `Swap and Pop` 算法将其从活跃数组中以 O(1) 复杂度移除。

### 7.2 补贴资金偿付保护
由于采用了前置强制预扣机制，`subsidyReserve` 按第 4.2 节计算的 `maxSubsidyRate` 预留资金，用于覆盖已确认补贴负债和当前周期潜在补贴支出。`MAX_SUBSIDY_RATE` 仅作为部署期聚合上限校验，不替代实际备付金计算中的 `maxSubsidyRate`。

### 7.3 链上 Gas 与 DOS 防御
三级推荐的计算仅包含数次简单的乘法和判断。通过“费率 0 短路跳出”设计，避免无意义计算。

上级推荐返佣必须采用纯记账而非直接转账。这样既将转账成本延后至上级主动 `claimAll`，也可避免上级地址异常导致下级领取奖励交易被回滚（DOS 攻击）。

### 7.4 邀请关系安全边界
- **有效邀请人校验**：仅在首次质押时处理邀请关系。有效邀请人定义见第 3.5 节；首次质押传入 `address(0)` 则永久标记为“无上级”，传入非零但无效地址必须 revert。非首次质押时直接忽略邀请人参数。
- **女巫攻击（小号套利）**：用户可能使用自己的小号作为邀请人。由于补贴的发放严格依赖于真实资金质押产生的基础奖励，即使使用小号，系统也获得了真实的 TVL 增长，在经济模型上属于可接受的博弈结果。
- **环形邀请验证边界**：为防止无限层级遍历导致 Out of Gas，合约在绑定邀请人时，只需向上追溯验证 3 级。只要 `msg.sender` 不在这 3 个直接上级的地址中，即视为合法。超过 3 级的环形嵌套在经济模型上无法套取额外奖励，无需消耗 Gas 进行全链路防御。

### 7.5 锁仓期超出剩余奖励周期
- **业务场景**：用户选择 90 天锁仓，但当前池子的奖励周期（`periodFinish`）只剩 80 天。
- **合约处理**：若创建时 `isRewardPeriodActive() == true`，合约不因“锁仓期超过剩余奖励周期”额外拦截。奖励按秒结算：当前周期结束后若未追加基础奖励，则后续阶段奖励为 0；若到期前追加奖励，则剩余锁仓期继续按仓位 `boostRate` 计算锁仓加速奖励。
- **前端建议**：若检测到 `锁仓期 > 剩余奖励周期`，前端应提示用户超出部分可能无奖励，且新活动池规则不会自动适用于当前仓位；提示不应阻断正常业务。

### 7.6 非奖励释放期活期质押与空窗奖励
- **非奖励释放期仅允许活期质押**：首次注入前和周期间空窗，`isRewardPeriodActive() == false`。用户可以 `stake`，但只能创建活期仓位；若当前没有基础奖励释放，则不会产生基础奖励或补贴。
- **非奖励释放期禁止新锁仓**：用户选择任何 `duration > 0` 的锁仓档位时，合约必须校验 `isRewardPeriodActive() == true`；不满足时 revert。历史锁仓仓位不受该开放状态影响。
- **空窗奖励自然流失**：管理员调用 `notifyRewardAmount` 后，奖励周期按 V1 逻辑立即启动。若奖励释放期间 `totalSupply == 0`，合约不得让 `rewardPerToken` 增长，也不得将空池期间的奖励在后续首个用户质押时一次性归属给该用户；该段无人质押期间对应的奖励视为自然流失。

### 7.7 暂停状态下的行为
V2 继承 V1 的 `Pausable` 安全模型，并明确暂停状态下的黑白名单：

- **阻断**：`stake`、`notifyRewardAmount`、`sweepSubsidy` 必须在暂停状态下 revert。
- **放行**：`withdraw`、`withdrawMultiple`、`claimAll`、`exit`、`recoverERC20` 必须在暂停状态下可用，保障用户取回本金和已结算奖励，并允许管理员救援非核心误转资产。
- **Treasury 修复例外**：`setTreasury` 在暂停状态下仍允许超级管理员调用，以便在不恢复其他入口的前提下修复罚金接收地址；该操作不触及用户本金、奖励账本或补贴偿付账本。
- **暂停不停止奖励状态机**：暂停只限制新增质押、续期注入和沉淀备付金提取，不冻结时间、不修改奖励周期，也不改变仓位到期时间。奖励仍按既有水位线规则累计，用户仍可通过 `claimAll` 领取可领奖励。
- **退出权优先**：`exit` 在用户没有活跃仓位但存在可领奖励或推荐返佣时，不得因零本金提取而失败。

### 7.8 代币兼容性
V2 仅支持标准 ERC20 余额语义，不支持 fee-on-transfer、rebasing、黑名单冻结、回调型或其他会改变实际到账/实际支付语义的代币。

- `stake`、`notifyRewardAmount` 以及补贴备付金扣款必须通过转账前后余额差校验实际到账数量。
- 在同币池中，`stake` 和 `notifyRewardAmount` 都会改变同一个 ERC20 余额；每次 `safeTransferFrom` 前后必须就地记录余额差，并将差额只归属到本次入口对应的资金桶。不得复用全局余额快照或通过交易结束后的总余额反推单个资金桶到账金额。
- 若实际到账数量与用户或管理员传入数量不一致，必须 revert `FeeOnTransferNotSupported()`。
- V2 不做 `actual received` 记账，也不对非标准 ERC20 做偿付能力适配。

### 7.9 核心资产救援限制
`recoverERC20` 仅用于救援误转入合约的非核心资产，不得提取以下资产：

- `stakingToken`
- `rewardToken`
- 任何与本金、基础奖池、补贴备付金、已确认补贴负债、罚金处理中间余额相关的核心资产余额

`recoverERC20` 与 `sweepSubsidy` 使用不同安全模型：前者通过资产黑名单禁止救援核心资产；后者仅用于按第 4.5 节边界提取沉淀补贴备付金。同币池中，`recoverERC20` 对核心 token 必须完全不可用；沉淀补贴只能通过 `sweepSubsidy` 提取。

### 7.10 零值与地址校验
为防止无意义事件、Gas 空耗和除零风险，以下入口必须拒绝零值或零地址：

- `stake(amount)`、`notifyRewardAmount(baseRewardAmount)`、`recoverERC20(token, amount)` 中的金额必须大于 0。
- 构造函数中的 `rewardsDuration` 必须大于 0；锁仓档位、推荐返佣比例、自身推荐补贴比例、`MAX_SUBSIDY_RATE` 和罚金率必须满足第 6.4 节约束。若 `MAX_SUBSIDY_RATE == 0`，则只能部署 `maxSubsidyRate == 0` 的无额外补贴活动池。
- `stakingToken`、`rewardToken`、`admin`、`treasury` 等核心地址必须为非零地址。
- 地址为零时使用地址类错误，数量为零时使用数量类错误，避免错误语义混淆。

### 7.11 历史快照边界
`rewardHistory` 的线性插值必须考虑奖励周期边界。若 `periodFinish` 落在两个快照点之间，计算 `rewardPerTokenAtUnlock` 时必须按快照中的 `periodFinish` 截断时间，避免把奖励结束后的零释放区间摊入锁仓期。

历史快照查找还必须覆盖以下异常边界：

- **无右侧真实快照 / `unlockTime` 晚于最后一条快照**：表示最后一条真实快照后没有新的曲线折点。此时使用虚拟当前节点作为 `cp2`；写路径基于本次已结算的 `rewardPerTokenStored` 构造，只读函数按当前 `rewardPerToken()` 临时构造。虚拟节点不写入 `rewardHistory`。
- **`unlockTime` 早于或等于第一条快照**：返回第一条快照的 `rewardPerToken`。正常锁仓仓位不应触发该分支，因为质押创建时已经写入了 `stakeTime <= unlockTime` 的快照。
- **数组长度不足**：若 `rewardHistory` 为空，说明系统尚未发生任何有效水位线初始化，返回当前 `rewardPerTokenStored`；若只有一条快照，则返回该快照的 `rewardPerToken`。
- **同时间戳命中**：若二分查找直接命中 `time == unlockTime` 的快照，直接返回该快照水位线，不执行除法插值，避免 `cp2.time == cp1.time` 导致除零。

V2 不提供 checkpoint 裁剪机制。`rewardHistory` 的增长仅通过写入时机约束、同区块覆盖和 `claimAll` 不落盘三项规则控制：只有真实改变后续全局奖励曲线的入口才写入快照；同一区块内多次改变全局奖励曲线时覆盖最后一条快照；`claimAll` 仅结算用户奖励，不写入新的历史快照。长期运行产生的 `rewardHistory` 存储成本属于 V2 为保持结算逻辑简单、确定和低攻击面所接受的设计代价。

---

## 8. 核心接口与事件 (Interfaces & Events)

### 8.1 用户接口
- `stake(uint256 amount, uint256 lockDuration, address inviter)`：创建新的独立仓位，并在首次质押时绑定邀请关系。
- `claimAll()`：领取调用者所有活跃仓位的可领基础奖励、自身推荐补贴、已到期仓位的已解锁锁仓加速奖励，以及用户级推荐返佣。不领取未到期的锁仓加速奖励。
- `withdraw(uint256 depositId)`：全额提取指定仓位本金，并在关闭仓位前结清该仓位的基础奖励和自身推荐补贴；若已到期，同时领取该仓位尚未通过 `claimAll` 领取的锁仓加速奖励；若提前提取，则按规则扣罚并作废未解锁锁仓加速奖励。
- `withdrawMultiple(uint256[] calldata depositIds)`：按第 5.3 节策略批量提取多个仓位。
- `exit()`：批量提取调用者全部活跃仓位，并领取全部可领奖励。

### 8.2 部署参数与管理员接口
合约构造函数必须一次性接收并校验本活动池的固定配置，包括但不限于 `stakingToken`、`rewardToken`、`rewardsDuration`、锁仓档位 `durations[] / boosts[]`、推荐补贴与返佣比例 `inviteeBoost / level1 / level2 / level3`、`MAX_SUBSIDY_RATE`、`penaltyRate`、`treasury`、管理员地址等。部署完成后，上述经济参数不可修改；若需要不同规则，应部署新的活动池。

- `notifyRewardAmount(uint256 baseRewardAmount)`：注入基础奖励，并按最大理论补贴率扣取或滚动补贴备付金。
- `setTreasury(address treasury)`：设置罚金接收地址，不受部署固定配置限制；暂停状态下仍允许超级管理员调用，用于紧急修复 Treasury 地址。
- `sweepSubsidy(address to, uint256 amount)`：先同步全局奖励账本，再提取安全范围内的沉淀补贴备付金。
- `pause()` / `unpause()`：暂停或恢复合约。
- `recoverERC20(address token, uint256 amount)`：救援非核心误转资产。

### 8.3 视图接口

V2 视图接口必须同时服务前端产品展示、链下索引器对账和管理员运营面板。除 Solidity 自动生成的 public getter 外，合约应提供聚合 getter，避免前端和索引器为了展示完整产品状态进行大量重复 RPC 或依赖硬编码配置。

#### 仓位与奖励视图
- `getDeposit(uint256 depositId)`：返回单个仓位详情，必须包含 `owner`；仓位是否已关闭可由 `owner != address(0) && amount == 0` 推导，调用方可据此区分不存在、活跃和已关闭仓位。
- `getActiveDepositIds(address user)`：返回用户当前活跃仓位 ID。
- `getUserDeposits(address user)`：批量返回用户当前所有活跃仓位详情，供前端一次性渲染“我的仓位”列表；返回内容应与 `getDeposit` 的单仓位结构保持一致。
- `totalStakedOf(address user)`：返回用户当前所有活跃仓位本金合计，供前端展示“我的总质押”与索引器进行账户级汇总校验。
- `earned(address user)`：返回用户当前可通过 `claimAll` 领取的总奖励，包含基础奖励、自身推荐补贴、用户级推荐返佣，以及 `boostSettled == true` 仓位中已解锁但尚未领取的锁仓加速奖励；不包含未到期或尚未完成到期切分的锁仓加速奖励。若只读查询时锁仓仓位满足 `boostRate > 0 && !boostSettled && block.timestamp >= unlockTime`，视图函数不得修改状态，应按第 7.11 节使用虚拟当前快照临时计算 `rewardPerTokenAtUnlock` 和展示值。
- `earnedByDeposit(uint256 depositId)`：返回指定仓位的基础奖励、自身推荐补贴和锁仓加速奖励拆分。锁仓加速奖励应区分“未到期仅记账、提前提取将作废”和“已完成 `boostSettled`、可通过 `claimAll` 或 `withdraw` 领取”的展示状态。若只读查询时锁仓仓位满足 `boostRate > 0 && !boostSettled && block.timestamp >= unlockTime`，也应在只读上下文中临时计算 `rewardPerTokenAtUnlock`，保证前端展示与下一次 `claimAll` / `withdraw` 的实际结算口径一致。
- `claimableReferralReward(address user)`：返回用户级推荐返佣余额。

#### 推荐关系视图
- `inviterOf(address user)`：返回用户已绑定的直接邀请人地址。若返回 `address(0)`，调用方必须结合 `hasSetInviter(user)` 判断该用户是尚未首次质押，还是已经永久选择“无上级”。
- `hasSetInviter(address user)`：返回用户是否已经完成首次质押时的邀请关系状态锁定。该状态一旦为 `true`，前端不得再允许用户补填或修改邀请人。
- `getUpline(address user)`：一次性返回用户当前绑定链路上的上三级地址 `(level1, level2, level3)`；不存在的层级返回 `address(0)`。该接口用于前端展示推荐链路，也便于索引器按固定深度校验三级推荐关系。

#### 配置聚合视图
- `getLockTiers()`：返回本活动池配置的锁仓档位 `durations[]` 与 `boosts[]`。该接口只表示可用档位配置，不表示当前时间点锁仓档位已经开放；前端应结合 `isRewardPeriodActive()` 判断是否允许用户选择 `duration > 0`。活期档位可由前端按第 6.4 节规则隐式展示，不要求必须出现在返回数组中。
- `getReferralRates()`：返回当前自身推荐补贴和三级返佣比例 `(inviteeBoost, level1, level2, level3)`，所有比例均采用 BPS 精度。
- `getPenaltyConfig()`：返回当前提前解锁罚金率与 Treasury 地址 `(penaltyRate, treasury)`，供前端展示退出成本和管理员面板核对罚金流向。
- `getSubsidyConfig()`：返回当前最大理论补贴率、部署期最大额外补贴预算上限、补贴备付金余额、已确认补贴负债和未结算最大补贴负债 `(maxSubsidyRate, MAX_SUBSIDY_RATE, subsidyReserve, totalPendingSubsidy, unsettledMaxSubsidyLiability)`，用于展示系统偿付状态和管理员补贴预算。
- `MAX_ACTIVE_DEPOSITS()`：返回单个用户允许持有的最大活跃仓位数量，供前端在用户接近或达到上限时提前提示。

#### 奖励周期与资金账本视图
- `getRewardSchedule()`：返回当前奖励周期状态 `(rewardsDuration, periodFinish, rewardRate, lastUpdateTime, rewardPerTokenStored)`，供前端展示剩余周期、APR 估算与索引器对账。
- `isRewardPeriodActive()`：返回当前是否处于有效基础奖励释放周期，定义见第 2.2 节。该函数返回 `false` 时，`stake` 仍可创建活期仓位，但任何 `duration > 0` 的锁仓选择都必须 revert。
- `baseRewardReserve()`：返回基础奖池未支付余额，作为第 4.1 节资产余额覆盖不变量的链上校验口径。
- `remainingBaseReward()`：返回当前周期尚未释放的基础奖励余额，即 `rewardRate * (periodFinish - block.timestamp)` 在未结束周期内对应的未释放数量；若当前周期已结束则返回 0。该值仅用于前端展示奖励周期剩余额度，不得单独作为 `maxSweepableSubsidy()` 的安全提取依据。
- `subsidyReserve()`：返回合约当前实际持有的补贴备付金余额。
- `totalPendingSubsidy()`：返回已确认补贴负债。
- `unsettledMaxSubsidyLiability()`：返回尚未被用户 `updateReward` 结算消化的最大理论补贴负债，用于覆盖已释放未结算的懒结算缺口和未来尚未释放的潜在补贴。
- `maxSweepableSubsidy()`：返回当前可安全提取的沉淀备付金上限。该视图函数不修改状态；若当前 `totalSupply == 0`，应按第 4.4 节规则在只读上下文中临时计算空窗奖励自然流失对应的 `maxSubsidyBudgetDelta`，并以临时扣减后的 `unsettledMaxSubsidyLiability` 计算返回值。

### 8.4 事件规范
所有会影响用户资产、奖励归属、推荐关系或核心配置的状态变更都必须抛出事件。为便于链下统计，奖励类事件必须按奖励类型拆分，不得只抛出一个聚合奖励事件。

用户与仓位事件：
- `Staked(address indexed user, uint256 indexed depositId, uint256 amount, uint256 lockDuration, uint256 unlockTime, uint256 boostRate)`
- `Withdrawn(address indexed user, uint256 indexed depositId, uint256 principalReturned)`
- `EarlyWithdrawn(address indexed user, uint256 indexed depositId, uint256 principalReturned, uint256 penaltyAmount, uint256 forfeitedBoostReward)`
- `DepositClosed(address indexed user, uint256 indexed depositId)`
- `InviterBound(address indexed user, address indexed inviter)`
- `NoInviterSet(address indexed user)`

奖励记账事件：
- `BaseRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount)`
- `LockBoostRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount)`
- `InviteeBoostRewardAccrued(address indexed user, uint256 indexed depositId, uint256 amount)`
- `ReferralRewardAccrued(address indexed inviter, address indexed invitee, uint8 indexed level, uint256 sourceDepositId, uint256 amount)`
- `LockBoostRewardForfeited(address indexed user, uint256 indexed depositId, uint256 amount)`

奖励支付事件：
- `BaseRewardPaid(address indexed user, uint256 amount)`
- `InviteeBoostRewardPaid(address indexed user, uint256 amount)`
- `ReferralRewardPaid(address indexed user, uint256 amount)`
- `LockBoostRewardPaid(address indexed user, uint256 indexed depositId, uint256 amount)`
- `RewardPaid(address indexed user, uint256 totalAmount)`：聚合支付事件，可作为兼容性事件保留，但链下统计不得仅依赖该事件。

资金与配置事件：
- `ActivityConfigured(uint256 rewardsDuration, uint256 inviteeBoost, uint256 level1, uint256 level2, uint256 level3, uint256 maxSubsidyRate, uint256 MAX_SUBSIDY_RATE, uint256 penaltyRate)`：部署时记录本活动池固定规则。锁仓档位可通过独立字段或配套事件记录。
- `RewardAdded(uint256 baseRewardAmount, uint256 subsidyRequired, uint256 subsidyCharged)`
- `SubsidyReserved(uint256 amount)`
- `UnsettledMaxSubsidyLiabilityUpdated(uint256 newValue)`
- `SubsidySwept(address indexed to, uint256 amount)`
- `PenaltyPaid(address indexed user, uint256 indexed depositId, address indexed treasury, uint256 amount)`
- `TreasuryUpdated(address indexed treasury)`
- `Recovered(address indexed token, uint256 amount)`
- `Paused(address account)` / `Unpaused(address account)`：继承自 OpenZeppelin `Pausable`
- `RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)` / `RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)`：继承自 OpenZeppelin `AccessControl`
