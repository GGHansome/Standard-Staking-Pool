# 修改日志 (Changelog)

**2026-06-24**

**src/V2/staking.sol**
- **修复最大补贴负债分段取整尾差**：新增 `injectedBaseCumulative` 与 `settledBaseCumulative` 两个基础奖励累计口径，将 `unsettledMaxSubsidyLiability` 收敛为 `floor(injectedBaseCumulative * maxSubsidyRate / BPS) - floor(settledBaseCumulative * maxSubsidyRate / BPS)`，避免注入侧按总额取整、结算侧按仓位分段取整导致 1 wei 幽灵负债永久占用补贴备付金。

**test/V2/staking.p0.t.sol**
- **补充分段取整尾差回归测试**：新增 `test_AccrueReward_CumulativeLiabilityClearsSegmentedFloorDust`，覆盖 `3 wei` 基础奖励按 `50%` 最大补贴率预留 `1 wei`，再由三个仓位各自结算 `1 wei` 时，最终 `unsettledMaxSubsidyLiability` 必须归零，且沉淀补贴可通过 `maxSweepableSubsidy()` 完整释放。

**test/V2/TEST_LIST_V2_Staking.md**
- **同步分段取整尾差测试清单**：在基础奖励与补贴计提分组中补充 `test_AccrueReward_CumulativeLiabilityClearsSegmentedFloorDust`。

**2026-06-23**

**PRD/V2/PRD_V2_Staking.md**
- **统一活跃仓位上限口径**：将第 7.1 节中的 `MAX_ACTIVE_DEPOSITS = 50` 从示例表述调整为本版本固定安全参数，明确该值不是部署期可配置参数；如需采用其他上限，应修改源码、重新编译并同步测试验收口径。
- **明确推荐模块一键关闭语义**：当 `inviteeBoost == 0 && level1 == 0 && level2 == 0 && level3 == 0` 时，推荐模块完全关闭；`stake` 必须忽略传入的 `inviter` 参数，不校验、不绑定、不写入 `hasSetInviter`，也不抛出推荐绑定相关事件。
- **补充 V2 rewardRate 对外精度口径**：对齐 V1 文档。

**src/V2/staking.sol**
- **统一活跃仓位数量上限**：将 `MAX_ACTIVE_DEPOSITS` 从 `30` 调整为 `50`，与当前 PRD 口径和测试验收值保持一致。
- **实现推荐模块全关闭短路**：当 `inviteeBoost`、`level1`、`level2`、`level3` 全为 0 时，`stake` 阶段跳过邀请关系处理，允许前端继续传入任意 `inviter` 参数但不产生校验、绑定或推荐事件，使活动池退化为无推荐模块的纯质押池。
- **补齐奖励与补贴负债事件覆盖**：被邀请人自身加成归集时新增 `InviteeBoostRewardAccrued`，三级推荐奖励实际进入邀请人待领取余额时新增逐级 `ReferralRewardAccrued`；`unsettledMaxSubsidyLiability` 在用户结算消化最大理论补贴预算、空窗自然流失释放补贴预算时同步抛出 `UnsettledMaxSubsidyLiabilityUpdated`。链下索引器可以按奖励类型和补贴预算消化过程还原账本变化。
- **修复锁仓到期切分被零奖励早返回跳过的问题**：根因是锁仓到期状态迁移与基础奖励归集耦合在同一段流程中，旧实现会在 `delta == 0` 或 `baseReward == 0` 时提前返回，导致已经到期的锁仓仓位没有缓存 `rewardPerTokenAtUnlock`，`boostSettled` 也不会置为 `true`。修复后，仓位奖励结算会先执行锁仓到期切分，再处理零基础奖励早返回；`earned` / `earnedByDeposit` 也会在只读上下文中用虚拟当前快照计算到期但尚未落盘的锁仓加成展示值，保证视图结果与下一次 `claimAll` / `withdraw` 的实际结算一致。
- **收敛锁仓加成可领判定为单一状态来源**：删除独立的 `_isBoostClaimable`，将 `_claimDepositReward` 的锁仓加成支付条件收敛为 `pendingBoostReward > 0 && boostSettled`。锁仓加成是否可领统一以 `boostSettled` 为准，避免“状态未落盘但靠时间判断已付款”导致的仓位状态机与资金支付不一致。
- **拆清仓位级退出与用户级推荐返佣边界**：`withdraw` / `withdrawMultiple` 不再顺带领取调用者的用户级推荐返佣，只结清被关闭仓位的本金、罚金和仓位级奖励；用户级推荐返佣继续通过 `claimAll` / `exit` 领取。
- **exit退出时写入历史记录限制**：当用户通过 `exit()` 领取奖励并退出仓位的时候，不存在活跃仓位将视作为单纯的奖励领取操作，此时不更改全局水位线，也就不需要进行 `_writeRewardCheckpoint()` 操作

**test/V2/staking.p0.t.sol**
- **补齐 PRD 回归覆盖**：新增/更新测试覆盖奖励类型事件、`unsettledMaxSubsidyLiability` 扣减事件、锁仓到期零增量切分、到期未落盘仓位的只读展示口径，以及 `withdraw` / `withdrawMultiple` 不领取用户级推荐返佣的资金流边界。
- **补强只读视图与实付一致性回归**：新增 `test_PRD_EarnedMatchesNextClaimAllPayoutBeforeSettlementWithInviter` 和 `test_PRD_EarnedByDepositMatureBoostMatchesNextClaimAllPayout`，锁定 `earned(user)` / `earnedByDeposit(depositId)` 在未触发状态结算时必须与下一次 `claimAll` 实际支付金额一致。
- **补齐补贴负债和奖励速率口径测试**：新增 `test_NotifyRewardAmount_EmitsUnsettledLiabilityIncrease` 覆盖未结算最大补贴负债增加事件。
- **补齐 exit 空仓位快照边界测试**：新增 `test_Exit_WithOnlyReferralRewardDoesNotWriteCheckpoint`，覆盖仅领取用户级推荐返佣、不关闭任何活跃仓位时不得写入 `RewardCheckpointWritten`。
- **补充推荐模块关闭回归测试**：新增 `test_Referral_DisabledReferralIgnoresInvalidInviterAndDoesNotBind`，覆盖推荐费率全 0 时 `stake` 忽略无效或自身 `inviter`，且不写入邀请关系状态。

**test/V2/TEST_LIST_V2_Staking.md**
- **同步测试清单描述**：更新新增和调整过的 P0 用例说明，使测试计划与当前合约行为、PRD 边界和测试实现保持一致。

**2026-06-10**

**PRD/V2/PRD_V2_Staking.md**
- **统一仓位级奖励支付事件口径（对应章节：5.2、8.4）**：将 `BaseRewardPaid` 与 `InviteeBoostRewardPaid` 调整为携带 `depositId` 的仓位级事件，与 `LockBoostRewardPaid`、各类 `Accrued` 事件保持一致；`ReferralRewardPaid` 继续表示用户级推荐返佣总量，`RewardPaid` 仅作为本次 ERC20 聚合转账总额事件。
- **补充基础奖池未支付余额账本口径（对应章节：2.3、4.1、8.3）**：明确基础奖池未支付余额由独立全局变量 `baseRewardReserve` 维护，并规定其在基础奖励注入、基础奖励结算、基础奖励支付和空窗奖励自然流失确认时的增减规则；`baseRewardReserve()` 作为链上校验口径对外暴露，`remainingBaseReward()` 仅用于展示当前周期尚未释放的基础奖励，不得作为偿付校验口径。
- **精简并统一补贴、罚金与快照口径（对应章节：4.3、4.4、5.2、5.3、6.5、7.3）**：统一 `notifyRewardAmount` 的入参名称为 `baseRewardAmount`，补充 `subsidyCharged` 的差额计算；将自身推荐补贴统一为 `inviteeBoost` 口径，并把提前解锁罚金改为 `floor(amount * penaltyRate / BPS)`；同时压缩 `maxSubsidyBudgetDelta` 的重复说明，统一饱和扣减和 `claimAll` 表达。

**2026-06-09**

**PRD/V2/PRD_V2_Staking.md**
- **补充构造函数比例边界与部署期补贴上限（对应章节：4.2、4.4、6.2、7.2、7.10、8.2、8.3、8.4）**：明确 `maxSubsidyRate = inviteeBoost + level1 + level2 + level3 + max(boosts[])`，并新增由构造函数传入且部署后 immutable 的 `MAX_SUBSIDY_RATE` 作为聚合补贴预算上限，防止部署配置超出活动预算上限或误配置；构造函数必须校验 `maxSubsidyRate <= MAX_SUBSIDY_RATE`，补贴实际预扣和未结算预算仍使用 `maxSubsidyRate`。同步补充 `penaltyRate <= BPS`，允许 `penaltyRate == BPS` 表示提前解锁罚没全部本金，但禁止超过 100% 导致罚金超过本金；`getSubsidyConfig()` 与 `ActivityConfigured` 需暴露 `MAX_SUBSIDY_RATE` 以便前端和管理员核对部署配置。

**2026-06-08**

**PRD/V2/PRD_V2_Staking.md**
- **明确 `sweepSubsidy` 前置同步空窗预算释放（对应章节：4.1、4.4、4.5、8.2、8.3）**：`sweepSubsidy` 执行时必须先进行全局奖励账本同步，再按同步后的 `maxSweepableSubsidy()` 校验可提取额度；若同步阶段确认 `totalSupply == 0` 空窗期间基础奖励自然流失，则按同一 `maxSubsidyBudgetDelta` 口径饱和扣减 `unsettledMaxSubsidyLiability`。提取阶段只扣减 `subsidyReserve`，不得在空窗预算释放之外额外修改补贴负债账本；视图函数 `maxSweepableSubsidy()` 不修改状态，但在 `totalSupply == 0` 时应只读临时计算空窗预算释放后的可提取额度。
- **明确 V2 不提供 checkpoint 裁剪机制（对应章节：7.11）**：补充说明 `rewardHistory` 的长期增长仅通过写入时机约束、同区块覆盖和 `claimAll` 不落盘三项规则控制；V2 不按时间或仓位状态删除历史快照，长期运行产生的存储成本属于为保持结算逻辑简单、确定和低攻击面而接受的设计代价。
- **统一补贴预算与计提的舍入规则（对应章节：4.3、4.4、6.5）**：明确 `requiredSubsidy`、`maxSubsidyBudgetDelta` 以及自身推荐补贴、锁仓加速奖励、推荐返佣等实际补贴计提均按 `floor(amount * rate / BPS)` 向下取整；扣减 `unsettledMaxSubsidyLiability` 时必须使用 `min(maxSubsidyBudgetDelta, unsettledMaxSubsidyLiability)` 做饱和扣减，避免舍入尾差或极端状态导致 underflow。

**2026-06-07**

**PRD/V2/PRD_V2_Staking.md**
- **解耦 `rewardHistory` 写入与 `updateReward` 结算（对应章节：3.3、5.1、5.2、5.3、7.11）**：明确 `rewardHistory` 只在 `stake`、`withdraw` / `withdrawMultiple`、`notifyRewardAmount` 等会改变后续全局奖励曲线的真实折点写入或同区块覆盖，`claimAll` 不得仅因调用 `updateReward` 写入快照；锁仓到期切分若找不到右侧真实快照，应使用已结算到当前区块的虚拟当前节点参与插值，不落盘写入，从而减少高频领取和纯到期结算导致的快照增长。
- **新增锁仓到期切分状态 `boostSettled`（对应章节：2.4、3.3、5.1、5.2、5.3、8.3）**：在 `DepositRecord` 中新增独立状态标记 `boostSettled`，用于表示仓位是否已经完成到期切分，明确不得用 `rewardPerTokenAtUnlock == 0` 推导切分状态。`updateReward` 仅在 `boostRate > 0 && !boostSettled && block.timestamp >= unlockTime` 时执行一次历史水位线二分查找并缓存 `rewardPerTokenAtUnlock`，随后置 `boostSettled = true`；后续结算、`claimAll`、`withdraw` 和视图展示统一基于 `boostSettled` 判断锁仓加速奖励是否已解锁可领，避免重复二分和状态语义歧义。
- **澄清锁仓模块关闭入口与非法档位校验（对应章节：6.4）**：锁仓加速模块的唯一关闭方式调整为部署时传入空档位配置 `durations = []` 且 `boosts = []`；非空档位配置中任一 `duration > 0 && boostRate == 0` 均属于非法配置，必须在构造函数中 revert，避免“全 0 boost 关闭模块”和“锁仓档位必须有正 boost”之间产生冲突。

**2026-06-06**

**PRD/V2/PRD_V2_Staking.md**
- **明确支持同币池与异币池并补齐同币偿付边界（对应章节：1.3、2.3、4.1、4.5、7.8、7.9）**：将“单币质押与分红”调整为更准确的平台币 / 社区代币质押激励表述，并明确 V2 同时支持 `stakingToken != rewardToken` 的异币池和 `stakingToken == rewardToken` 的同币池。同币池下本金、基础奖励、补贴备付金和罚金处理中间余额可共用同一 ERC20 余额，但必须通过独立逻辑资金桶维护归属；`sweepSubsidy` 只能按 `maxSweepableSubsidy()` 的账本边界提取沉淀补贴，不能以合约总余额反推可提额度；同时补充同币池下核心资产救援限制、标准 ERC20 到账校验和 `recoverERC20` / `sweepSubsidy` 的安全模型区别。
- **固化单活动池经济参数与仓位字段口径（对应章节：1.3、2.4、6.2、6.3、6.4、7.10、8.2、8.4）**：明确 V2 合约实例是“部署时可配置、运行期规则固定”的独立活动池；奖励周期、锁仓档位、推荐补贴与返佣比例、罚金率等经济参数必须通过构造函数一次性声明并在合约生命周期内不可修改。由于池级经济参数不再运行期变化，`DepositRecord` 不再保存 `penaltyRate`、`inviteeBoost` 和三级返佣比例快照，只保留与单笔仓位选择直接相关的 `boostRate` 以及独立水位线、未领奖励字段。
- **新增有效基础奖励释放周期作为锁仓开放唯一判断（对应章节：2.2、4.3、5.1、7.5、7.6、8.3）**：定义 `isRewardPeriodActive()`，当且仅当 `rewardRate > 0 && block.timestamp < periodFinish` 时返回 `true`；新建锁仓仓位必须满足 `isRewardPeriodActive() == true`，活期仓位 `duration == 0` 不受该限制。首次基础奖励注入前、两次奖励周期之间的空窗期均只允许活期质押；历史锁仓仓位不受当前开放状态影响。锁仓期限允许超过剩余奖励周期，但前提是创建该仓位时处于有效基础奖励释放周期。
- **明确空池奖励按 V1 逻辑自然流失（对应章节：4.1、4.3、4.4、4.5、7.6）**：`notifyRewardAmount` 注入基础奖励后立即启动释放周期，不等待首个有效仓位进入，也不采用空池暂停机制。奖励释放期间若 `totalSupply == 0`，`rewardPerToken` 不增长，空池期间基础奖励不得在后续首个质押者进入时补分配；该段基础奖励视为自然流失，并在全局水位线更新时同步释放其对应的最大理论补贴预算。
- **同步固定配置后的管理员接口、暂停规则与事件规范（对应章节：6.4、7.7、8.2、8.3、8.4）**：管理员接口移除 `setRewardsDuration`、`setLockTiers`、`setReferralRates`、`setPenaltyRate` 等运行期经济参数修改入口，仅保留 `notifyRewardAmount`、`setTreasury`、`sweepSubsidy`、暂停和救援接口；暂停状态下阻断范围收敛为 `stake`、`notifyRewardAmount`、`sweepSubsidy`，`setTreasury` 仍可用于紧急修复。视图层新增 `isRewardPeriodActive()`，并明确 `getLockTiers()` 只表示配置档位、不表示当前锁仓开放状态；事件层新增 `ActivityConfigured`，移除运行期经济参数更新事件。

**2026-06-04**

**PRD/V2/PRD_V2_Staking.md**
- **修正懒结算模型下 `sweepSubsidy` 的偿付边界（对应章节：2.3、4.1、4.3、4.4、4.5、5.2、8.3、8.4）**：新增 `unsettledMaxSubsidyLiability` 作为未结算最大补贴负债，覆盖已释放但用户尚未触发 `updateReward` 的补贴缺口和未来尚未释放的潜在补贴；`maxSweepableSubsidy()` 改为按 `subsidyReserve - totalPendingSubsidy - unsettledMaxSubsidyLiability` 计算，避免 `remainingBaseReward()` 随时间下降导致管理员提前提走尚需偿付用户历史补贴的备付金；同步明确续期时只对本次新注入基础奖励新增未结算最大补贴预算，避免重复计提上一期 `leftoverBase`。

**2026-06-01**

**PRD/V2/PRD_V2_Staking.md**
- **补全 V2 前端与索引器所需视图接口（对应章节：7.1、8.3）**：按仓位与奖励、推荐关系、配置聚合、奖励周期与资金账本四类补充查询能力，新增 `inviterOf`、`hasSetInviter`、`getUpline`、`getLockTiers`、`getReferralRates`、`getPenaltyConfig`、`getSubsidyConfig`、`MAX_ACTIVE_DEPOSITS`、`getRewardSchedule`、`remainingBaseReward`、`totalStakedOf` 和 `getUserDeposits` 等接口要求；同时明确活跃仓位数量上限必须对前端和索引器可查询。
- **补充配置修改时机的业务与偿付原因（对应章节：6.2）**：明确即使仓位已保存参数快照，仍禁止锁仓档位、推荐返佣比例和罚金率在奖励周期中修改。`boostRate` 与返佣比例会影响本周期最大理论补贴率和 `subsidyReserve` 预扣口径，周期中调高可能破坏 `subsidyReserve >= totalPendingSubsidy`；罚金率虽不影响补贴偿付，但属于用户退出成本，应保持同一周期内营销与前端展示口径一致。
- **明确 `setTreasury` 的周期与暂停规则（对应章节：6.4、7.7、8.2）**：`setTreasury` 不受奖励周期限制，因为 Treasury 地址不进入仓位快照、奖励账本、补贴备付金或最大理论补贴率计算；暂停状态下仍允许超级管理员调用，用于在 Treasury 地址错误、失效或存在风险时不恢复其它高风险入口即可完成修复。
- **调整锁仓加速奖励的切分、领取与展示口径（对应章节：2.1、2.3、3.3、4.1、4.4、5.2、5.3、7.11、8.1、8.3）**：`DepositRecord` 新增 `rewardPerTokenAtUnlock` 缓存字段，明确 `updateReward` 在仓位首次跨越 `unlockTime` 时执行历史水位线二分查找与插值切分，并将锁仓期内 boost 持续记入 `pendingBoostReward`，解决“持续记账”与到期切分之间的口径冲突；仓位到期后已解锁 boost 可通过 `claimAll` 领取，无需先 withdraw，未到期 boost 仍仅记账且提前提取时作废；同步明确 `earned(user)` 包含已到期未领取的锁仓加速奖励，`earnedByDeposit(depositId)` 需区分未到期记账态与已到期可领取态。
- **补全仓位归属与关闭状态语义（对应章节：2.3、5.1、5.3、8.3）**：`DepositRecord` 新增 `owner` 字段，支持 `getDeposit(depositId)`、`withdraw(depositId)` 和 `withdrawMultiple(depositIds)` 基于全局 `depositId` 进行 O(1) 归属查询与权限校验；仓位关闭状态不单独存储 `closed`，统一由 `owner != address(0) && amount == 0` 推导，避免多状态源不同步。

**2026-05-31**

**PRD/V2/PRD_V2_Staking.md**
- **明确有效邀请人业务定义（对应章节：3.5、5.1、7.4）**：有效邀请人必须是已完成首次质押绑定的系统参与者（`hasSetInviter[inviter] == true`），同时满足非零、非本人、向上 3 级不成环；首次质押传入非零但无效邀请人时必须 revert，冷启动阶段首批用户只能以“无上级”身份完成首次质押。
- **补充历史水位线快照边界（对应章节：3.3、7.11）**：明确 `rewardHistory` 快照需记录 `block.timestamp`、`rewardPerToken` 与 `periodFinish`，并统一使用带 `periodFinish` 截断的插值公式处理奖励周期边界；若找不到右侧真实快照，应使用虚拟当前节点作为 `cp2` 参与本次切分，不因到期切分强制写入 `rewardHistory`。
- **明确 `withdraw` 关闭前奖励结清规则（对应章节：4.1、4.4、5.3、8.1）**：`withdraw` / `withdrawMultiple` 在销毁仓位并移出 `activeDepositIds` 前，必须结清该仓位的 `pendingBaseReward` 和 `pendingInviteeBoostReward`；到期仓位同时支付 `pendingBoostReward`，提前违约仓位仅作废未解锁锁仓加速奖励，避免仓位关闭后 `claimAll()` 不再遍历导致奖励无法领取。
- **补充补贴账本状态转移表（对应章节：4.1）**：用表格明确 `notifyRewardAmount`、`updateReward`、`claimAll`、`withdraw` / `withdrawMultiple`、`sweepSubsidy` 对 `subsidyReserve` 和 `totalPendingSubsidy` 的影响，降低后续实现时对“支付、作废、提取”三类动作的理解歧义。

**2026-05-30**

**PRD/V2/PRD_V2_Staking.md**
- **明确补贴备付金账本口径（对应章节：2.2、4.1、4.3、4.5、8.3）**：将 `subsidyReserve` 定义为合约当前实际持有的补贴备付金余额，而不是历史累计预留额度，避免 `availableSubsidy = subsidyReserve - totalPendingSubsidy` 在实现时出现歧义。
- **补充双池账本不变量（对应章节：4.1）**：新增基础奖池与补贴备付金互不挪用的约束，并明确 `totalPendingSubsidy = Σ(pendingInviteeBoostReward) + Σ(pendingBoostReward) + Σ(referralRewards)`，便于后续实现和测试对账。
- **拆分自身推荐补贴账本（对应章节：2.3、5.2、8.3）**：在 `DepositRecord` 中新增 `pendingInviteeBoostReward`，不再将自身推荐补贴混入 `pendingBaseReward`，确保 `claimAll()` 能准确区分基础奖励和补贴支付。
- **明确补贴支付与作废规则（对应章节：4.1、4.4、5.2、5.3）**：补贴实际支付时同步扣减 `totalPendingSubsidy` 和 `subsidyReserve`；提前解锁导致锁仓加速奖励作废时仅扣减 `totalPendingSubsidy`，原因是补贴资金未离开合约，应重新成为可用备付金。
- **移除"是否支持同币池"二选一描述（对应章节：7.8）**统一为 `recoverERC20` 不得提取核心资产。
