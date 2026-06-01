# 产品需求文档 (PRD) - V2 锁仓推荐质押池 (V2 Staking Pool with Lock-up & Referral)

## 1. 产品概述 (Product Overview)

### 1.1 业务背景
在 V1 标准双币质押收益池（无锁仓、随存随取）基础上，V2 面向更精细的运营需求，引入锁仓和链上推荐激励能力。V2 主要解决两个问题：一是活期质押难以形成长期资金留存，二是缺少原生的链上推荐增长机制。

因此，V2 在 V1 的底层水位线架构之上，引入**锁仓奖励加速（Lock-up Boost）**、**提前解锁惩罚（Early Unlock Penalty）**以及**三级推荐返佣（3-Level Referral）**三大核心功能模块。

### 1.2 核心目标
1. **长期留存**：通过“锁仓时间越长、奖励加速比例越高”的规则，鼓励用户长期质押；通过“提前解锁扣除本金”的惩罚机制，增加提前退出成本，提升 TVL 稳定性。
2. **推荐增长**：通过内置的链上三级推荐返佣与用户自身推荐补贴，激励社区成员主动推广项目，降低获客成本。
3. **资金预算约束**：通过“强制补贴备付金（Subsidy Reserve）”机制，使系统额外奖励支出具有可计算的理论上限，降低奖励超发和合约偿付风险。

### 1.3 适用场景
本合约作为可配置的质押激励基础设施，适合以下场景：
- **单币质押与分红**：适用于平台币或社区代币的长期质押、锁仓激励与推荐增长。
- **新币挖矿 / Launchpool**：通过推荐机制辅助新项目冷启动，提升真实参与地址数量。
- **联合营销 (Partner Airdrops)**：支持项目方之间进行用户增长合作，并为有效推广者提供链上激励。

---

## 2. 核心术语与账户模型 (Terminology & Accounting Model)

本节先统一 V2 的奖励口径和账本口径。后续机制、流程和安全边界均以本节术语为准。

### 2.1 奖励类型
- **基础奖励（Base Reward）**：由基础奖池按 V1 水位线模型释放，并按用户当前质押份额分配的奖励。所有额外补贴都以基础奖励作为计算基准。
- **锁仓加速奖励（Lock Boost Reward）**：锁仓期内，仓位根据 `boostRate` 基于基础奖励额外计算的补贴。该奖励在锁仓到期前仅记账，不随日常 Claim 发放；仓位到期并完成到期水位线切分后，已解锁的锁仓加速奖励可通过 `claimAll` 或关闭仓位时领取。
- **自身推荐补贴（Invitee Boost Reward）**：用户首次质押时绑定了有效邀请人后，该用户自身基于基础奖励额外获得的补贴。
- **推荐返佣（Referral Reward）**：用户的上三级邀请人基于该用户基础奖励获得的返佣。
- **罚金（Penalty）**：用户提前解锁时，从提取本金中按 `penaltyRate` 扣除并转入 Treasury 的金额。

### 2.2 资金账户
- **基础奖池（Base Reward Pool）**：由 `notifyRewardAmount` 注入，并进入基础水位线模型按周期平滑释放。
- **补贴备付金池（Subsidy Reserve）**：合约当前实际持有、专用于支付锁仓加速奖励、自身推荐补贴和推荐返佣的补贴资金余额。该变量采用现金口径：补缴和沉淀回收会增加余额，补贴实际支付或管理员安全提取会减少余额。
- **已确认补贴负债（`totalPendingSubsidy`）**：系统当前已确认但尚未支付的补贴负债总额。该变量用于约束补贴备付金的滚动抵扣和安全提取。
- **Treasury**：接收提前解锁罚金的项目方金库地址。

### 2.3 仓位账本
V2 不再使用 V1 的“单账户总余额”模型。用户每次存入资金，合约都会生成一个独立的质押凭证（Deposit Record），即使是相同的锁仓期限，也不合并。

每个 `DepositRecord` 至少包含以下字段：
- `owner`: 仓位归属用户地址
- `amount`: 本金金额
- `unlockTime`: 到期时间戳
- `boostRate`: 锁仓加速比例快照
- `penaltyRate`: 违约罚金率快照
- `inviteeBoostRate`: 自身推荐补贴比例快照（绑定上级时才有值）
- `level1Rate, level2Rate, level3Rate`: 上三级推荐返佣比例快照
- `rewardPerTokenPaid`: 该凭证的独立水位线，用于计算该笔资金产生的基础奖励
- `rewardPerTokenAtUnlock`: 该凭证在 `unlockTime` 时刻的全局水位线缓存。仓位首次在 `updateReward` 中跨越到期点时，通过历史水位线快照二分查找并插值计算后写入；后续结算、`claimAll`、`withdraw` 和视图函数可直接复用该缓存，避免同一仓位到期后反复执行二分查找。
- `pendingBaseReward`: 该凭证累积的未领基础奖励
- `pendingInviteeBoostReward`: 该凭证累积的未领自身推荐补贴
- `pendingBoostReward`: 该凭证累积的未领锁仓加速奖励。仓位到期前该余额仅作为未解锁负债记账，不能通过 `claimAll` 发放；仓位到期并完成 `rewardPerTokenAtUnlock` 切分后，该余额转为已解锁可领补贴，可通过 `claimAll` 或关闭仓位时领取。

这种全参数快照设计支持用户分批次、多档位存入资金，并避免全局比例修改导致历史未结算奖励计算错位，以及复杂比例拆分带来的精度丢失问题。

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
为了实现“锁仓到期（`unlockTime`）后自动降级为活期奖励”，系统需要解决一个核心工程问题：如果用户在到期时没有进行任何链上交互，智能合约如何在用户未来任意一次结算（如 `claimAll` 或 `withdraw`）时，精确得知 `unlockTime` 那一刻的全局水位线（`rewardPerToken`）？

本系统采用 **历史水位线快照 + 二分查找 + 线性插值** 的机制处理该问题：
1. **全局快照 (Global Checkpoints)**：系统维护全局数组 `rewardHistory`，每条快照至少包含 `[time, rewardPerToken, periodFinish]`。其中 `time` 必须使用真实区块时间 `block.timestamp`，不得使用被 `periodFinish` 截断后的 `lastTimeRewardApplicable()`；`periodFinish` 为该快照时间点之后生效的奖励周期结束时间快照，用于后续插值时处理周期自然结束边界。
2. **快照写入时机**：所有会触发全局水位线更新或改变未来奖励曲线的入口，都必须写入或覆盖当前区块的快照，包括 `stake`、`withdraw` / `withdrawMultiple`、`claimAll`、`notifyRewardAmount` 等。对于 `notifyRewardAmount`，应先通过 `updateReward` 使用旧的 `rewardRate` 与 `periodFinish` 结算截至当前区块的 `rewardPerTokenStored`；在新的 `rewardRate` 与 `periodFinish` 生效后，必须再写入或覆盖同一条 `time = block.timestamp` 的快照，使该快照同时保留“旧周期结算后的水位线”和“新周期向后生效的 `periodFinish`”，从而让该时间点成为“旧周期结束 / 新周期开始”的真实折点。
3. **同区块压缩优化 (Same-block Compression)**：为控制数组增长并节省 Gas，在写入快照时，若检测到 `rewardHistory` 最后一条记录的 `time == block.timestamp`，则直接覆盖原记录的 `rewardPerToken` 与 `periodFinish`，不新增数组长度。覆盖后的记录必须代表该区块内最后一次状态变更后、对未来奖励曲线生效的状态。
4. **到期切分触发时机**：`updateReward` 在逐仓结算时，若发现某笔仓位本次结算首次跨越 `unlockTime`，必须先把当前 `block.timestamp` 写入 `rewardHistory`，再计算并缓存该仓位的 `rewardPerTokenAtUnlock`。因此，即使仓位到期后长期无人交互，用户未来第一次触发 `updateReward` 的入口（包括 `claimAll`、`withdraw` / `withdrawMultiple`、`exit` 等）都会补上一条当前时间快照；在 `block.timestamp >= unlockTime` 的正常结算场景下，二分查找总能找到 `unlockTime` 右侧或等于右侧的 `cp2`。
5. **二分查找定位 (Binary Search)**：当某笔仓位首次跨越到期点、需要计算 `rewardPerTokenAtUnlock` 时，系统在 `rewardHistory` 数组中通过二分查找定位 `time <= unlockTime` 的最后一条快照作为 `cp1`，并定位其后一条 `time >= unlockTime` 的快照作为 `cp2`。若存在 `time == unlockTime` 的快照，则直接返回该快照的 `rewardPerToken`，无需插值。
6. **统一插值计算 (Clamped Linear Interpolation)**：相邻两个真实快照之间，`totalSupply` 与 `rewardRate` 不会发生变化；若发生变化，对应入口必须先写入新的真实快照。因此在同一奖励周期内，`rewardPerToken` 按时间线性增长。实现时应统一使用带 `periodFinish` 截断的插值公式：若 `periodFinish` 不在 `cp1.time` 与 `cp2.time` 之间，该公式会自然退化为普通线性插值；若 `periodFinish` 落在两点之间，则相当于将 `periodFinish` 作为虚拟 checkpoint，避免把奖励结束后的零释放区间错误地线性摊入锁仓期。
   $$ effectiveUnlockTime = min(unlockTime, cp1.periodFinish) $$
   $$ effectiveCp2Time = min(cp2.time, cp1.periodFinish) $$
   $$ rewardPerTokenAtUnlock = cp1.reward + \frac{(cp2.reward - cp1.reward) \times (effectiveUnlockTime - cp1.time)}{(effectiveCp2Time - cp1.time)} $$
   若 `effectiveCp2Time <= cp1.time`，表示该区间从 `cp1` 起已经没有奖励继续释放，直接返回 `cp1.reward`。

通过求得并缓存 `rewardPerTokenAtUnlock`，系统可将该仓位的奖励分段：锁仓期内（使用存入时的水位线到 `rewardPerTokenAtUnlock` 的差值计算）享受锁仓加速；到期后的时间段（使用最新的 `rewardPerToken` 减去 `rewardPerTokenAtUnlock`）仅计算基础活期奖励。该缓存字段的目的不是改变用户收益，而是将同一仓位的二分查找成本限制为首次跨越到期点时的一次；之后 `claimAll` 可直接判断仓位是否已到期并支付已解锁的 `pendingBoostReward`，`withdraw` 也可复用同一结果，避免重复计算和账本口径分叉。

### 3.4 提前解锁惩罚
- **提前退出通道**：即便用户选择了锁仓，仍可在到期前强制取出本金，以满足极端情况下的流动性需求。
- **惩罚规则**：作为提前退出成本，智能合约将扣除用户提取本金的一定比例（如 20%）作为罚金。同时，采用“锁仓加速奖励到期解锁”机制：用户提前解锁时，其未到期的锁仓加速奖励将全部作废清零，而基础奖励不受影响。
- **罚金流向**：扣除的本金罚金将统一实时转入合约配置的 Treasury。项目方可自由决定该笔罚金的用途：若希望将其分给其他质押者，运营团队可定期将 Treasury 中的罚金作为奖励，通过 `notifyRewardAmount` 重新注入质押池，实现平滑发放；若希望通缩，则可直接提取销毁。

### 3.5 三级推荐系统
系统采用平台额外补贴机制（Protocol-funded Subsidy），避免直接从下级本金或基础奖励中扣除推荐返佣。

- **终身一次性绑定机制**：用户在生命周期中的首次质押时，系统会永久锁定其邀请关系状态。
- **有效邀请人**：有效邀请人必须是已经完成首次质押绑定的系统参与者，即 `hasSetInviter[inviter] == true`；同时邀请人地址必须为非零地址、不能是用户本人，并且向上追溯 3 级不得形成环。若填写的邀请人满足上述条件，则永久绑定该上级。
- **无上级状态**：若未填写邀请人（直接质押），则该账户被永久标记为“无上级”。系统冷启动阶段的首批用户在尚不存在已完成首次质押绑定的邀请人时，也只能以“无上级”身份完成首次质押。
- **绑定边界**：一旦完成首次质押，该用户的邀请关系即被永久固化。后续无论其追加质押，还是提取全部资金后再次质押，均无法再修改或补填邀请人。
- **自身推荐补贴**：填写了有效邀请人的新用户，其个人基础奖励将额外获得一笔补贴（如 +5%）。
- **上级推荐返佣**：用户的上三级邀请人将分别获得该用户基础奖励一定比例的返佣（如一级 10%，二级 5%，三级 2%）。

---

## 4. 经济模型与偿付约束 (Economic Model & Solvency)

V2 的核心设计难点在于如何协调“固定基础奖池（水位线）”与“按用户关系动态产生的额外补贴”。本产品采用“基础奖池 + 补贴备付金池（Subsidy Reserve）”双池架构，使额外补贴支出具备明确的预算上限。

### 4.1 基础奖池与补贴备付金账本不变量
V2 必须将基础奖励和额外补贴拆分为两个互不挪用的资金桶：

- **基础奖池桶**：覆盖基础水位线模型下已注入但尚未释放、已释放但尚未领取的基础奖励。
- **补贴备付金桶**：覆盖所有平台额外补贴，包括锁仓加速奖励、自身推荐补贴和推荐返佣，对应 `subsidyReserve`。

任意时刻必须满足以下账本不变量：

1. `subsidyReserve >= totalPendingSubsidy`，确保所有已确认但尚未支付的补贴负债都有补贴现金兜底。
2. `availableSubsidy = subsidyReserve - totalPendingSubsidy`，仅该差额可被后续周期滚动复用或在满足安全边界时被管理员提取。
3. `totalPendingSubsidy = Σ(pendingInviteeBoostReward) + Σ(pendingBoostReward) + Σ(referralRewards)`，其中前两项按所有活跃仓位汇总，第三项按所有用户级推荐返佣账本汇总。

补贴账本的状态变更规则如下：

- **补贴计提**：`updateReward` 新增自身推荐补贴、锁仓加速奖励或推荐返佣时，`totalPendingSubsidy` 等额增加，`subsidyReserve` 不变。
- **补贴支付**：`claimAll` 支付自身推荐补贴、推荐返佣和已到期仓位的已解锁锁仓加速奖励，或 `withdraw` / `withdrawMultiple` 在关闭仓位前支付该仓位尚未领取的自身推荐补贴、到期锁仓加速奖励时，`totalPendingSubsidy` 与 `subsidyReserve` 必须按实际支付的补贴金额等额减少。
- **补贴作废**：用户提前解锁导致未解锁锁仓加速奖励作废时，只减少 `totalPendingSubsidy`，不减少 `subsidyReserve`；该部分资金重新成为可用备付金。
- **备付金补缴或提取**：`notifyRewardAmount` 补缴时增加 `subsidyReserve`；`sweepSubsidy` 提取时减少 `subsidyReserve`，且不得破坏上述不变量。

对应状态转移表如下：

| 操作场景 | 触发入口 | `subsidyReserve` 变化 | `totalPendingSubsidy` 变化 | 说明 |
| --- | --- | --- | --- | --- |
| 补贴备付金补缴 | `notifyRewardAmount` | `+= subsidyCharged` | 不变 | 管理员为新周期补足理论最大补贴预算。 |
| 补贴计提 | `updateReward` | 不变 | `+= 新增补贴金额` | 自身推荐补贴、锁仓加速奖励、推荐返佣从潜在支出转为已确认补贴负债。 |
| 日常补贴支付 | `claimAll` | `-= 已支付补贴金额` | `-= 已支付补贴金额` | 支付 `pendingInviteeBoostReward`、`referralRewards`，以及已到期仓位中已解锁的 `pendingBoostReward`；基础奖励支付不影响这两个补贴账本变量。 |
| 关闭仓位前补贴支付 | `withdraw` / `withdrawMultiple` | `-= 已支付补贴金额` | `-= 已支付补贴金额` | 关闭仓位前支付该仓位尚未领取的 `pendingInviteeBoostReward`；若仓位已到期且仍有未领取 `pendingBoostReward`，同时支付该余额。 |
| 提前解锁补贴作废 | `withdraw` / `withdrawMultiple` | 不变 | `-= 作废的 pendingBoostReward` | 未解锁锁仓加速奖励不再支付，补贴现金未离开合约，重新成为可用备付金。 |
| 沉淀备付金提取 | `sweepSubsidy` | `-= amount` | 不变 | 仅允许提取 `maxSweepableSubsidy()` 范围内的沉淀资金。 |

### 4.2 最大理论补贴率
系统在配置阶段必须计算最大理论额外支出比例：
- 假设极端情况：所有用户都有完整的上三级邀请关系、全部填写了有效邀请人，且全部选择最长锁仓期限。
- **最大补贴率** = 自身推荐补贴 (5%) + 一级返佣 (10%) + 二级返佣 (5%) + 三级返佣 (2%) + 最长锁仓加速奖励 (如 180 天的 50%) = **72%**。
- 在该配置下，系统需要支付的额外补贴理论上限为基础奖励的 72%。因此，包含基础奖励在内的总奖励预算上限为基础奖池的 172%。

### 4.3 奖励注入与备付金滚动
当管理员调用 `notifyRewardAmount(newAmount)` 注入新奖励时，系统将执行补贴备付金计算。

1. **首次注入（强制预留）**：若是合约上线后的首次注入，假设注入 5000 个代币作为基础奖励，合约会自动计算最大补贴率（如 72%），并从管理员钱包总共扣除 8600 个代币。其中 5000 进入基础水位线，另外 3600 作为补贴备付金存入 `subsidyReserve`。
2. **后续追加（备付金滚动与平滑发放）**：当开启第二期及后续周期时，系统将执行滚动抵扣：
   - **计算新周期总基础奖池**：`newTotalBase = newAmount (本次新注入) + leftoverBase (上一期未发完的剩余基础奖励)`
   - **计算新周期所需的理论最大备付金**：`requiredSubsidy = newTotalBase * 极限补贴率 (如 72%)`
   - **计算当前可用的剩余备付金**：`availableSubsidy = subsidyReserve (当前实际补贴备付金余额) - totalPendingSubsidy (已确认未领取的补贴负债)`  
     注：必须扣除已确认补贴负债，确保历史用户尚未 Claim 的补贴不被新周期挪用。
   - **计算最终需补缴金额**：若 `requiredSubsidy > availableSubsidy`，则从管理员钱包额外扣除差额并存入 `subsidyReserve`；若资金充足，则无需额外补缴，直接使用池内沉淀备付金。

通过该公式，可以实现不同周期奖励的平滑过渡，并将未触发极端情况而沉淀的备付金自动抵扣到下一期，降低项目方资金占用。

### 4.4 补贴负债记账
为保证补贴偿付能力，合约必须维护一个全局状态变量 `totalPendingSubsidy`。

每次触发 `updateReward` 时，若用户实际产生了补贴（如自身推荐补贴、锁仓加速奖励或上级推荐返佣），则将该金额累加至 `totalPendingSubsidy`。当用户通过 `claimAll` 领取补贴（包括已到期仓位的已解锁锁仓加速奖励），或通过 `withdraw` / `withdrawMultiple` 在关闭仓位前领取该仓位尚未领取的自身推荐补贴、到期锁仓加速奖励时，从 `totalPendingSubsidy` 与 `subsidyReserve` 中等额扣减；当因提前违约导致锁仓加速奖励作废时，仅从 `totalPendingSubsidy` 中等额扣减，`subsidyReserve` 不减少。

该变量代表系统当前已确认但尚未支付的补贴负债总额。

### 4.5 沉淀备付金与安全提取
由于现实中并非所有仓位都会触发最大补贴率，备付金池中可能产生未使用的沉淀备付金。管理员可以通过 `sweepSubsidy` 提取这些资金，但必须受到安全边界限制：

**`maxSweepable`最大可提取金额 = `subsidyReserve` 当前实际补贴备付金余额 - `totalPendingSubsidy` (已确认负债) - `本周期剩余的理论最大潜在负债`**

其中，本周期剩余的理论最大潜在负债 = 尚未释放的基础奖励 * 72%。

通过该公式，确保管理员提取沉淀备付金时，不会影响用户已确认补贴和当前周期的潜在补贴偿付能力。

---

## 5. 用户流程与状态变更 (User Flows)

### 5.1 资金存入与邀请绑定 (Stake)
1. 前端获取用户的锁仓选择（如 90 天）及邀请人地址（如 `inviterAddress`）。
2. 合约前置触发 `updateReward`，结算历史奖励。
3. **记录绑定关系（终身一次性）**：合约检查该用户是否为首次质押（通过独立的状态标记 `hasSetInviter` 判断，而非仓位数量）。若是首次，且传入的 `inviterAddress` 满足第 3.5 节“有效邀请人”定义，则记录该邀请人；若首次质押传入 `address(0)`，则记录为“无上级”；若首次质押传入非零但无效的邀请人地址，则必须 revert，避免用户在不知情情况下被永久绑定到错误状态。完成上述处理后，将 `hasSetInviter[msg.sender]` 设为 `true`。若非首次，则直接忽略传入的邀请人参数。
4. **生成独立质押凭证**：
   - 扣除用户本金存入合约。
   - 分配一个全局自增的 `depositId` 作为该笔质押的唯一键。
   - 按第 2.3 节记录该仓位的归属用户、本金、到期时间、水位线和全部参数快照。
5. 增加全局 `totalSupply`，更新水位线。

### 5.2 领取奖励与返佣分发 (Claim Reward)
V2 将奖励划分为“仓位奖励”和“推荐返佣”两条线。仓位奖励记录在各个独立的 `DepositRecord` 中，而推荐返佣记录在独立于仓位之外的用户级返佣账本（`referralRewards`）中，确保即使用户提取了所有本金，依然可以领取下级历史贡献产生的返佣。

1. 合约前置触发 `updateReward`，遍历该用户的所有活跃仓位进行结算。
2. 计算每个仓位产生的基础奖励。
3. 计算并记账额外补贴：
   - **锁仓加速奖励**：每次结算基础奖励时，同步计算并记账锁仓期内产生的加速奖励。若本次结算区间完全早于 `unlockTime`，则按 `新增锁仓加速奖励 = 新增基础奖励 * boostRate` 累加到该笔质押凭证的 `pendingBoostReward`。若本次结算区间首次跨越 `unlockTime`，则必须先按第 3.3 节计算并缓存 `rewardPerTokenAtUnlock`，只将“上次结算水位线至 `rewardPerTokenAtUnlock`”对应的基础奖励乘以 `boostRate` 后累加到 `pendingBoostReward`，并将该仓位后续奖励降级为活期基础奖励。若仓位已经完成到期切分，则后续基础奖励不再产生锁仓加速奖励。通过该规则，`pendingBoostReward` 会在 `updateReward` 中持续、准确记账，不会把锁仓加速奖励拖延到 `withdraw` 时才临时计算。
   - **自身推荐补贴**：每次结算基础奖励时，若该仓位快照了 `inviteeBoostRate`，则计算 `新增自身推荐补贴 = 新增基础奖励 * inviteeBoostRate`，并单独计入该仓位的 `pendingInviteeBoostReward` 中，不得混入 `pendingBaseReward`。
   - **推荐返佣**：依据该仓位内部的快照 `level1Rate, level2Rate, level3Rate`，分别计算向上三级的返佣，并累加到各级上级的用户级账本 `referralRewards[上级地址]` 中。
4. 将本次实际产生的补贴金额计入 `totalPendingSubsidy` 负债。自身推荐补贴和推荐返佣在日常 Claim 时可领取；锁仓加速奖励在到期前仅确认为负债并记入 `pendingBoostReward`，不随日常 Claim 发放。仓位到期并完成 `rewardPerTokenAtUnlock` 切分后，该 `pendingBoostReward` 已经停止累积并转为已解锁可领余额，可在 `claimAll()` 中领取，无需用户先关闭仓位。
5. **结算与发放**：主动领奖接口仅提供 `claimAll()`。调用时，合约将汇总所有活跃仓位的 `pendingBaseReward`、`pendingInviteeBoostReward`、已到期仓位的已解锁 `pendingBoostReward`，以及用户级账本的 `referralRewards`，并一次性转账给用户。转账完成后，将已发放的 `pendingBaseReward`、`pendingInviteeBoostReward`、已解锁 `pendingBoostReward` 和 `referralRewards` 清零。其中 `pendingBaseReward` 属于基础奖池支付，不影响 `subsidyReserve`；`pendingInviteeBoostReward`、已解锁 `pendingBoostReward` 和 `referralRewards` 属于补贴支付，必须按实际支付金额等额扣减 `totalPendingSubsidy` 和 `subsidyReserve`。

### 5.3 提取本金 (Withdraw)
单笔质押凭证（Deposit Record）必须全额提取，不支持部分提取。若用户需要资金灵活性，建议在存入时自行拆分为多笔小额质押，以降低合约状态机复杂度与防范精度丢失漏洞。

接口设计：
- `withdraw(uint256 depositId)`：用于精确提取某一笔特定仓位。
- `withdrawMultiple(uint256[] calldata depositIds)`：用于前端实现“一键提取多个/所有活期仓位”等聚合操作，节省用户多次签名的交互成本。

`withdrawMultiple` 失败策略：
- **整体原子性**：批量提取必须采用全有或全无策略。任一 `depositId` 无效、非调用者所有、已提取、重复传入或不满足内部校验时，整笔交易必须 revert，避免出现部分成功导致前端状态和链上状态不一致。
- **重复 ID 拦截**：同一批次中不得重复传入相同 `depositId`。实现上可通过逐个校验仓位 `amount > 0` 并在处理后立即标记/移除来防止重复消费；若检测到重复 ID，必须 revert。
- **长度限制**：`depositIds.length` 必须大于 0，且不得超过 `MAX_ACTIVE_DEPOSITS` 或单独定义的批量上限，防止用户构造超长数组导致 Out of Gas。
- **统一结算**：批量提取开始前应先对调用者执行一次 `updateReward`，结算所有活跃仓位截至当前区块的奖励，然后逐笔处理该仓位的本金、罚金、基础奖励、自身推荐补贴和锁仓加速奖励的解锁/作废。
- **聚合转账**：为降低 Gas 和减少外部调用，批量提取过程中应先在内存中累计 `principalToUser`、`penaltyToTreasury`、`baseRewardToUser`、`inviteeBoostToUser` 和 `unlockedBoostToUser`，完成全部状态更新后再分别执行必要的 `safeTransfer`。
- **事件逐笔记录**：即使转账聚合执行，也必须为每个被提取的 `depositId` 抛出独立事件，便于链下索引器按仓位统计。

单笔提取执行逻辑：
1. 根据 `depositId` 读取仓位并执行基础校验：`owner != address(0)` 确认仓位存在，`owner == msg.sender` 确认仓位归属调用者，`amount > 0` 确认仓位尚未关闭；随后校验该笔存款的 `unlockTime`。
2. **关闭前奖励结清**：在销毁仓位并从 `activeDepositIds` 移除前，必须一次性结清该笔凭证内所有已结算的仓位级可领奖励，包括 `pendingBaseReward` 和 `pendingInviteeBoostReward`。若仓位已到期且仍存在尚未通过 `claimAll` 领取的已解锁 `pendingBoostReward`，也必须在关闭前一并支付。其中 `pendingBaseReward` 从基础奖池支付，不影响 `subsidyReserve`；`pendingInviteeBoostReward` 和已解锁 `pendingBoostReward` 属于补贴支付，必须按实际支付金额等额扣减 `totalPendingSubsidy` 和 `subsidyReserve`。支付完成后清零对应 pending 字段，禁止把未领奖励残留在已关闭仓位中。
3. **分支 A：正常到期提取**：正常退还全额本金。由于到期切分已在 `updateReward` 中完成，若该笔凭证内仍有未领取的已解锁锁仓加速奖励，则在关闭仓位时支付；若用户此前已通过 `claimAll` 领取过该笔 boost，则 `pendingBoostReward == 0`，不得重复支付。
4. **分支 B：提前违约提取**：
   - 校验该笔质押凭证中记录的快照 `penaltyRate`（假设 20%）。
   - 扣除 `Amount * 20%` 作为罚金处理，并实时转入 Treasury。
   - 退还剩余 80% 本金给用户。
   - 直接清零作废其在该笔资金上产生的未解锁锁仓加速奖励。该作废金额只扣减 `totalPendingSubsidy`，不扣减 `subsidyReserve`；基础奖励和自身推荐补贴不受提前违约影响，必须按第 2 步在关闭前正常发放。
5. 销毁该笔质押凭证（`amount = 0`），扣减 `totalSupply`，从 `activeDepositIds` 中移除该仓位，并更新全局水位线。

---

## 6. 配置、权限与精度规范 (Configuration & Access Control)

### 6.1 角色权限
继承 V1 的权限架构，V2 同样区分超级管理员（Super Admin / Owner）与普通管理员（Normal Admin / Operator）：
- **超级管理员**：负责核心资产与系统级安全配置，如设置 Treasury 地址、提前解锁罚金率、分配普通管理员权限。
- **普通管理员**：负责日常运营策略配置，如设置锁仓档位、推荐返佣比例、注入奖励 `notifyRewardAmount`。

### 6.2 修改时机限制
为了保护用户权益，所有涉及奖励比例和罚金的配置（锁仓档位、推荐返佣比例、罚金率）必须在当前奖励周期结束（或尚未开始）时才能进行修改。一旦奖励周期正在进行中（`block.timestamp < periodFinish`），合约将锁定这些修改接口（`revert` 拒绝修改）。

即使第 6.3 节已经要求仓位保存参数快照，仍必须禁止上述配置在奖励周期中修改。原因是：`boostRate` 与推荐返佣比例直接决定本周期最大理论补贴率和 `subsidyReserve` 的预扣金额，周期中调高会使新仓位按更高比例产生补贴负债，而本周期备付金仍按旧比例预留，可能破坏 `subsidyReserve >= totalPendingSubsidy` 的偿付不变量；罚金率虽然不影响补贴偿付，但同样属于用户退出成本参数，应避免同一奖励周期内新老用户使用不同营销与退出规则。该限制的目的不是解决历史仓位计算问题，而是保证单一奖励周期内预算、偿付上限和前端展示口径保持一致。

### 6.3 参数快照与解耦
当管理员在周期结束后修改了全局配置并开启新周期时，所有修改（包括推荐返佣比例、自身推荐补贴、锁仓加速比例等）仅对修改之后存入的新仓位生效。

已存入的历史仓位在其 `DepositRecord` 中拥有独立的参数快照，将继续按照其存入时约定的原比例计算后续奖励与返佣，不会受到新配置的影响。该机制用于实现新老仓位解耦，保障历史仓位的规则稳定性。

### 6.4 隐式开关规则
为保证合约简洁性、Gas 成本和复用性，V2 采用“0 即关闭（0 means disabled）”的隐式降级短路逻辑。

#### 锁仓加速模块
- **配置接口**：`setLockTiers(uint256[] durations, uint256[] boosts)`
- **开启**：配置多档位，如 `[30, 90]`, `[10%, 30%]`。
- **一键关闭**：管理员传入空数组 `[]`，或将所有 `boosts` 设为 `0`。合约读取到 0，则短路跳过锁仓时间记录与锁仓加速奖励计算，退化为纯活期 V1。

#### 三级推荐模块
- **配置接口**：`setReferralRates(uint256 inviteeBoost, uint256 level1, uint256 level2, uint256 level3)`
- **开启**：正常配置如 `5%, 10%, 5%, 2%`。
- **灵活降级**：若只需一级推荐，配置为 `5%, 10%, 0, 0`。合约执行时遇到 `level2 == 0`，直接 `return` 跳过后续层级计算，节省大量 Gas。
- **一键关闭**：配置为 `0, 0, 0, 0`。系统关闭推荐逻辑。

#### 提前解锁惩罚模块
- **配置接口**：`setPenaltyRate(uint256 rate)`
- **一键关闭**：参数设置为 `0`。即使用户提前提取，也不扣除本金。

#### 锁仓、加速与罚金组合语义
为避免“锁仓模块关闭”和“罚金模块关闭”之间产生二义性，V2 对锁仓档位、加速比例和罚金率的组合语义作如下约束：

- **活期档位**：`duration == 0` 表示活期仓位。活期仓位的 `unlockTime` 等于质押发生时间，`boostRate` 必须为 0，任何时候提取都不视为提前解锁，也不得产生罚金。
- **锁仓档位**：`duration > 0` 表示锁仓仓位。该仓位在 `block.timestamp < unlockTime` 时提取属于提前解锁；是否扣罚取决于仓位快照的 `penaltyRate`。
- **加速关闭但锁仓存在**：不允许配置 `duration > 0` 且 `boostRate == 0` 的锁仓档位。若没有额外锁仓加速，则不应要求用户承担锁仓约束，避免“无收益但有锁定/罚金”的不公平组合。
- **锁仓模块关闭**：当锁仓档位配置为空时，系统仅允许创建活期仓位，`boostRate = 0`，`unlockTime = block.timestamp`，并跳过锁仓加速和提前解锁判断。
- **罚金模块关闭**：`penaltyRate == 0` 仅表示提前解锁不扣本金，不代表锁仓模块关闭。用户仍需要等到到期后才能领取锁仓加速奖励；若提前提取，则未解锁的锁仓加速奖励仍按规则作废。
- **配置校验**：`setLockTiers` 必须校验 `durations.length == boosts.length`，档位数量不超过上限，`durations` 不重复，且所有 `duration > 0` 的档位必须满足 `boostRate > 0`。活期档位可由系统隐式支持，不要求管理员显式配置。

#### Treasury 金库地址
- **配置接口**：`setTreasury(address _treasury)`
- **说明**：用于接收用户提前解锁时扣除的违约罚金。该地址必须为非零有效地址。
- **修改时机**：`setTreasury` 不受第 6.2 节奖励周期限制，可在周期进行中调用。Treasury 地址不写入仓位参数快照，不参与基础奖励、补贴备付金或最大理论补贴率计算；罚金始终在用户提前提取发生时转入当时配置的 Treasury。

### 6.5 精度规范
- **Basis Point（基点）精度**：智能合约中不支持浮点数，因此本 PRD 中涉及的所有百分比（如锁仓加速比例 `boosts`、推荐返佣比例 `rates`、罚金率 `penaltyRate` 等）在合约底层均采用万分位（Basis Point, BPS）精度标准。
- **换算关系**：`10000` 代表 `100%`，`1000` 代表 `10%`，`500` 代表 `5%`，`1` 代表 `0.01%`。

---

## 7. 安全边界与异常处理 (Risk Management)

### 7.1 活跃仓位数量限制
为防止用户恶意创建大量微小仓位导致 `updateReward` 遍历时触发 Out of Gas，合约必须引入双数组分离机制。仅将 `amount > 0` 的仓位 ID 存入 `activeDepositIds` 数组，并限制该数组的最大长度（如 `MAX_ACTIVE_DEPOSITS = 50`）。该上限必须通过视图接口暴露，便于前端在用户接近或达到上限时提前提示。

当仓位被提取（`amount = 0`）时，采用 `Swap and Pop` 算法将其从活跃数组中以 O(1) 复杂度移除。

### 7.2 补贴资金偿付保护
由于采用了前置强制预扣（预留 72% 最大理论值）机制，`subsidyReserve` 按理论最大补贴率预留资金，用于覆盖已确认补贴负债和当前周期潜在补贴支出。

### 7.3 链上 Gas 与 DOS 防御
三级推荐的计算仅包含数次简单的乘法和判断。通过“费率 0 短路跳出”设计，避免无意义计算。

上级推荐返佣必须采用纯记账（更新内部未领取余额）而非直接转账的方式。这不仅将多笔转账的 Gas 成本延后至上级主动 Claim 时由其自行承担，也可防止由于上级地址异常（如恶意合约拒收代币）导致下级用户领取奖励的交易被强行回滚（DOS 攻击）。

### 7.4 邀请关系安全边界
- **有效邀请人校验**：仅在用户首次质押（`hasSetInviter[msg.sender] == false`）时，若其希望激活自身推荐补贴（如 +5%）并绑定上级，必须传入一个满足第 3.5 节定义的有效邀请人地址。该地址必须为非零地址（`!= address(0)`）、不能是自己（`!= msg.sender`）、已经完成首次质押绑定（`hasSetInviter[inviter] == true`），且向上 3 级不形成环。若首次质押传入 `address(0)`，则视为放弃补贴并永久标记为“无上级”。若首次质押传入非零但无效的邀请人地址，则必须 revert。对于非首次质押（`hasSetInviter[msg.sender] == true`），合约将直接忽略传入的邀请人参数。
- **女巫攻击（小号套利）**：用户可能使用自己的小号作为邀请人。由于补贴的发放严格依赖于真实资金质押产生的基础奖励，即使使用小号，系统也获得了真实的 TVL 增长，在经济模型上属于可接受的博弈结果。
- **环形邀请验证边界**：为防止无限层级遍历导致 Out of Gas，合约在绑定邀请人时，只需向上追溯验证 3 级。只要 `msg.sender` 不在这 3 个直接上级的地址中，即视为合法。超过 3 级的环形嵌套在经济模型上无法套取额外奖励，无需消耗 Gas 进行全链路防御。

### 7.5 锁仓期超出剩余奖励周期
- **业务场景**：用户选择 90 天锁仓，但当前池子的奖励周期（`periodFinish`）只剩 80 天。
- **合约处理**：智能合约不作任何拦截，允许正常存入。合约严格按秒结算：前 80 天正常按比例分配奖励；后 10 天若项目方未注入新资金（`rewardRate == 0`），则该阶段产生的奖励为 0。到期时间严格按 90 天执行。
- **前端建议**：前端在用户选择锁仓期限时，若检测到 `锁仓期 > 剩余奖励周期`，应在 UI 给予提示（如：“当前奖池本轮奖励将在 X 天后发放完毕，若项目方未及时续期，超出部分的锁仓时间将无法产生奖励”），保障用户知情权的同时不阻断正常业务。

### 7.6 暂停状态下的行为
V2 继承 V1 的 `Pausable` 安全模型，并明确暂停状态下的黑白名单：

- **阻断**：`stake`、`notifyRewardAmount`、`setRewardsDuration`、`setLockTiers`、`setReferralRates`、`setPenaltyRate`、`sweepSubsidy` 必须在暂停状态下 revert。
- **放行**：`withdraw`、`withdrawMultiple`、`claimAll`、`exit`、`recoverERC20` 必须在暂停状态下可用，保障用户在异常情况下仍可取回本金和已结算奖励，同时允许管理员救援误转入的非核心资产。
- **Treasury 修复例外**：`setTreasury` 在暂停状态下仍允许超级管理员调用。若暂停原因与 Treasury 地址错误、失效或风险地址有关，管理员必须能够在不恢复 `stake`、`notifyRewardAmount` 等入口的前提下修复罚金接收地址；该操作不触及用户本金、奖励账本或补贴偿付账本。
- **暂停不停止奖励状态机**：暂停只限制新增质押、续期注入和运营配置变更，不冻结 `block.timestamp`、不修改 `periodFinish`、不将 `rewardRate` 置零，也不改变任何仓位的 `unlockTime`。只要当前奖励周期尚未结束，基础奖励和基于基础奖励产生的补贴仍按既有水位线规则继续累计；`claimAll` 在暂停状态下放行，用户仍可领取可领奖励。
- **退出权优先**：`exit` 在用户没有活跃仓位但存在可领奖励或推荐返佣时，不得因零本金提取而失败。

### 7.7 代币兼容性
V2 仅支持标准 ERC20 余额语义，不支持 fee-on-transfer、rebasing、黑名单冻结、回调型或其他会改变实际到账/实际支付语义的代币。

- `stake`、`notifyRewardAmount` 以及补贴备付金扣款必须通过转账前后余额差校验实际到账数量。
- 若实际到账数量与用户或管理员传入数量不一致，必须 revert `FeeOnTransferNotSupported()`。
- V2 不做 `actual received` 记账，也不对非标准 ERC20 做偿付能力适配。

### 7.8 核心资产救援限制
`recoverERC20` 仅用于救援误转入合约的非核心资产，不得提取以下资产：

- `stakingToken`
- `rewardToken`
- 任何与本金、基础奖池、补贴备付金、已确认补贴负债、罚金处理中间余额相关的核心资产余额

### 7.9 零值与地址校验
为防止无意义事件、Gas 空耗和除零风险，以下入口必须拒绝零值或零地址：

- `stake(amount)`、`notifyRewardAmount(baseRewardAmount)`、`setRewardsDuration(duration)`、`recoverERC20(token, amount)` 中的金额或周期必须大于 0。
- `stakingToken`、`rewardToken`、`admin`、`treasury` 等核心地址必须为非零地址。
- 地址为零时使用地址类错误，数量为零时使用数量类错误，避免错误语义混淆。

### 7.10 历史快照边界
`rewardHistory` 的线性插值必须考虑奖励周期边界。若 `periodFinish` 落在两个快照点之间，计算 `rewardPerTokenAtUnlock` 时必须基于快照中记录的 `periodFinish` 对时间进行截断，相当于将 `periodFinish` 作为虚拟 checkpoint 参与分段，避免把奖励结束后的零释放区间错误地线性摊入锁仓期。

历史快照查找还必须覆盖以下异常边界：

- **无右侧真实快照**：仓位首次跨越到期点进行结算前必须先执行 `updateReward` 并写入当前 `block.timestamp` 快照，因此在 `block.timestamp >= unlockTime` 时，当前快照天然作为 `cp2`；若实现中仍检测到不存在 `cp2`，必须按状态机错误处理并 revert，而不是静默使用错误插值。
- **`unlockTime` 晚于最后一条快照**：仅允许发生在只读预估函数未主动写入当前快照的场景。此时应先用当前时间按 `rewardPerToken()` 逻辑构造虚拟当前快照，再执行同样的二分与插值逻辑。
- **`unlockTime` 早于或等于第一条快照**：返回第一条快照的 `rewardPerToken`。正常仓位不应触发该分支，因为质押创建时已经写入了 `stakeTime <= unlockTime` 的快照。
- **数组长度不足**：若 `rewardHistory` 为空，说明系统尚未发生任何有效水位线初始化，返回当前 `rewardPerTokenStored`；若只有一条快照，则返回该快照的 `rewardPerToken`。
- **同时间戳命中**：若二分查找直接命中 `time == unlockTime` 的快照，直接返回该快照水位线，不执行除法插值，避免 `cp2.time == cp1.time` 导致除零。

---

## 8. 核心接口与事件 (Interfaces & Events)

### 8.1 用户接口
- `stake(uint256 amount, uint256 lockDuration, address inviter)`：创建新的独立仓位，并在首次质押时绑定邀请关系。
- `claimAll()`：领取调用者所有活跃仓位的可领基础奖励、自身推荐补贴、已到期仓位的已解锁锁仓加速奖励，以及用户级推荐返佣。不领取未到期的锁仓加速奖励。
- `withdraw(uint256 depositId)`：全额提取指定仓位本金，并在关闭仓位前结清该仓位的基础奖励和自身推荐补贴；若已到期，同时领取该仓位尚未通过 `claimAll` 领取的锁仓加速奖励；若提前提取，则按规则扣罚并作废未解锁锁仓加速奖励。
- `withdrawMultiple(uint256[] calldata depositIds)`：按第 5.3 节策略批量提取多个仓位。
- `exit()`：批量提取调用者全部活跃仓位，并领取全部可领奖励。

### 8.2 管理员接口
- `notifyRewardAmount(uint256 baseRewardAmount)`：注入基础奖励，并按最大理论补贴率扣取或滚动补贴备付金。
- `setRewardsDuration(uint256 duration)`：设置奖励周期，仅可在当前周期结束后调用。
- `setLockTiers(uint256[] calldata durations, uint256[] calldata boosts)`：设置锁仓档位，仅可在当前周期结束后调用。
- `setReferralRates(uint256 inviteeBoost, uint256 level1, uint256 level2, uint256 level3)`：设置自身推荐补贴和三级推荐返佣比例，仅可在当前周期结束后调用。
- `setPenaltyRate(uint256 rate)`：设置提前解锁罚金率，仅可在当前周期结束后调用。
- `setTreasury(address treasury)`：设置罚金接收地址，不受奖励周期限制；暂停状态下仍允许超级管理员调用，用于紧急修复 Treasury 地址。
- `sweepSubsidy(address to, uint256 amount)`：提取安全范围内的沉淀补贴备付金。
- `pause()` / `unpause()`：暂停或恢复合约。
- `recoverERC20(address token, uint256 amount)`：救援非核心误转资产。

### 8.3 视图接口

V2 视图接口必须同时服务前端产品展示、链下索引器对账和管理员运营面板。除 Solidity 自动生成的 public getter 外，合约应提供聚合 getter，避免前端和索引器为了展示完整产品状态进行大量重复 RPC 或依赖硬编码配置。

#### 仓位与奖励视图
- `getDeposit(uint256 depositId)`：返回单个仓位详情，必须包含 `owner`；仓位是否已关闭可由 `owner != address(0) && amount == 0` 推导，调用方可据此区分不存在、活跃和已关闭仓位。
- `getActiveDepositIds(address user)`：返回用户当前活跃仓位 ID。
- `getUserDeposits(address user)`：批量返回用户当前所有活跃仓位详情，供前端一次性渲染“我的仓位”列表；返回内容应与 `getDeposit` 的单仓位结构保持一致。
- `totalStakedOf(address user)`：返回用户当前所有活跃仓位本金合计，供前端展示“我的总质押”与索引器进行账户级汇总校验。
- `earned(address user)`：返回用户当前可通过 `claimAll` 领取的总奖励，包含基础奖励、自身推荐补贴、用户级推荐返佣，以及已到期仓位中已解锁但尚未领取的锁仓加速奖励；不包含未到期的锁仓加速奖励。若只读查询时仓位已经到期但尚未在状态中写入 `rewardPerTokenAtUnlock`，视图函数不得修改状态，应按第 7.10 节使用虚拟当前快照临时计算展示值。
- `earnedByDeposit(uint256 depositId)`：返回指定仓位的基础奖励、自身推荐补贴和锁仓加速奖励拆分。锁仓加速奖励应区分“未到期仅记账、提前提取将作废”和“已到期已解锁、可通过 `claimAll` 或 `withdraw` 领取”的展示状态。若 `rewardPerTokenAtUnlock` 尚未缓存但仓位已到期，也应在只读上下文中临时计算 `rewardPerTokenAtUnlock`，保证前端展示与下一次 `claimAll` / `withdraw` 的实际结算口径一致。
- `claimableReferralReward(address user)`：返回用户级推荐返佣余额。

#### 推荐关系视图
- `inviterOf(address user)`：返回用户已绑定的直接邀请人地址。若返回 `address(0)`，调用方必须结合 `hasSetInviter(user)` 判断该用户是尚未首次质押，还是已经永久选择“无上级”。
- `hasSetInviter(address user)`：返回用户是否已经完成首次质押时的邀请关系状态锁定。该状态一旦为 `true`，前端不得再允许用户补填或修改邀请人。
- `getUpline(address user)`：一次性返回用户当前绑定链路上的上三级地址 `(level1, level2, level3)`；不存在的层级返回 `address(0)`。该接口用于前端展示推荐链路，也便于索引器按固定深度校验三级推荐关系。

#### 配置聚合视图
- `getLockTiers()`：返回当前可选锁仓档位的 `durations[]` 与 `boosts[]`。活期档位可由前端按第 6.4 节规则隐式展示，不要求必须出现在返回数组中。
- `getReferralRates()`：返回当前自身推荐补贴和三级返佣比例 `(inviteeBoost, level1, level2, level3)`，所有比例均采用 BPS 精度。
- `getPenaltyConfig()`：返回当前提前解锁罚金率与 Treasury 地址 `(penaltyRate, treasury)`，供前端展示退出成本和管理员面板核对罚金流向。
- `getSubsidyConfig()`：返回当前最大理论补贴率、补贴备付金余额和已确认补贴负债 `(maxSubsidyRate, subsidyReserve, totalPendingSubsidy)`，用于展示系统偿付状态和管理员补贴预算。
- `MAX_ACTIVE_DEPOSITS()`：返回单个用户允许持有的最大活跃仓位数量，供前端在用户接近或达到上限时提前提示。

#### 奖励周期与资金账本视图
- `getRewardSchedule()`：返回当前奖励周期状态 `(rewardsDuration, periodFinish, rewardRate, lastUpdateTime, rewardPerTokenStored)`，供前端展示剩余周期、APR 估算与索引器对账。
- `remainingBaseReward()`：返回当前周期尚未释放的基础奖励余额，即 `rewardRate * (periodFinish - block.timestamp)` 在未结束周期内对应的未释放数量；若当前周期已结束则返回 0。该值是第 4.5 节 `maxSweepableSubsidy()` 计算中“本周期剩余理论最大潜在负债”的基础。
- `subsidyReserve()`：返回合约当前实际持有的补贴备付金余额。
- `totalPendingSubsidy()`：返回已确认补贴负债。
- `maxSweepableSubsidy()`：返回当前可安全提取的沉淀备付金上限。

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
- `RewardAdded(uint256 baseRewardAmount, uint256 subsidyRequired, uint256 subsidyCharged)`
- `SubsidyReserved(uint256 amount)`
- `SubsidySwept(address indexed to, uint256 amount)`
- `PenaltyPaid(address indexed user, uint256 indexed depositId, address indexed treasury, uint256 amount)`
- `RewardsDurationUpdated(uint256 newDuration)`
- `LockTiersUpdated(uint256[] durations, uint256[] boosts)`
- `ReferralRatesUpdated(uint256 inviteeBoost, uint256 level1, uint256 level2, uint256 level3)`
- `PenaltyRateUpdated(uint256 rate)`
- `TreasuryUpdated(address indexed treasury)`
- `Recovered(address indexed token, uint256 amount)`
- `Paused(address account)` / `Unpaused(address account)`：继承自 OpenZeppelin `Pausable`
- `RoleGranted(bytes32 indexed role, address indexed account, address indexed sender)` / `RoleRevoked(bytes32 indexed role, address indexed account, address indexed sender)`：继承自 OpenZeppelin `AccessControl`
