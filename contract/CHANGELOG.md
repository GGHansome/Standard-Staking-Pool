# 修改日志 (Changelog)

**2026-06-01**

**PRD/V2/PRD_V2_Staking.md**
- **补全 V2 前端与索引器所需视图接口（对应章节：7.1、8.3）**：按仓位与奖励、推荐关系、配置聚合、奖励周期与资金账本四类补充查询能力，新增 `inviterOf`、`hasSetInviter`、`getUpline`、`getLockTiers`、`getReferralRates`、`getPenaltyConfig`、`getSubsidyConfig`、`MAX_ACTIVE_DEPOSITS`、`getRewardSchedule`、`remainingBaseReward`、`totalStakedOf` 和 `getUserDeposits` 等接口要求；同时明确活跃仓位数量上限必须对前端和索引器可查询。
- **补充配置修改时机的业务与偿付原因（对应章节：6.2）**：明确即使仓位已保存参数快照，仍禁止锁仓档位、推荐返佣比例和罚金率在奖励周期中修改。`boostRate` 与返佣比例会影响本周期最大理论补贴率和 `subsidyReserve` 预扣口径，周期中调高可能破坏 `subsidyReserve >= totalPendingSubsidy`；罚金率虽不影响补贴偿付，但属于用户退出成本，应保持同一周期内营销与前端展示口径一致。
- **明确 `setTreasury` 的周期与暂停规则（对应章节：6.4、7.6、8.2）**：`setTreasury` 不受奖励周期限制，因为 Treasury 地址不进入仓位快照、奖励账本、补贴备付金或最大理论补贴率计算；暂停状态下仍允许超级管理员调用，用于在 Treasury 地址错误、失效或存在风险时不恢复其它高风险入口即可完成修复。
- **调整锁仓加速奖励的切分、领取与展示口径（对应章节：2.1、2.3、3.3、4.1、4.4、5.2、5.3、7.10、8.1、8.3）**：`DepositRecord` 新增 `rewardPerTokenAtUnlock` 缓存字段，明确 `updateReward` 在仓位首次跨越 `unlockTime` 时执行历史水位线二分查找与插值切分，并将锁仓期内 boost 持续记入 `pendingBoostReward`，解决“持续记账”与到期切分之间的口径冲突；仓位到期后已解锁 boost 可通过 `claimAll` 领取，无需先 withdraw，未到期 boost 仍仅记账且提前提取时作废；同步明确 `earned(user)` 包含已到期未领取的锁仓加速奖励，`earnedByDeposit(depositId)` 需区分未到期记账态与已到期可领取态。
- **补全仓位归属与关闭状态语义（对应章节：2.3、5.1、5.3、8.3）**：`DepositRecord` 新增 `owner` 字段，支持 `getDeposit(depositId)`、`withdraw(depositId)` 和 `withdrawMultiple(depositIds)` 基于全局 `depositId` 进行 O(1) 归属查询与权限校验；仓位关闭状态不单独存储 `closed`，统一由 `owner != address(0) && amount == 0` 推导，避免多状态源不同步。

**2026-05-31**

**PRD/V2/PRD_V2_Staking.md**
- **明确有效邀请人业务定义（对应章节：3.5、5.1、7.4）**：有效邀请人必须是已完成首次质押绑定的系统参与者（`hasSetInviter[inviter] == true`），同时满足非零、非本人、向上 3 级不成环；首次质押传入非零但无效邀请人时必须 revert，冷启动阶段首批用户只能以“无上级”身份完成首次质押。
- **补充历史水位线快照边界（对应章节：3.3、7.10）**：明确 `rewardHistory` 快照需记录 `block.timestamp`、`rewardPerToken` 与 `periodFinish`，并统一使用带 `periodFinish` 截断的插值公式处理奖励周期边界；同时说明正常到期提取前必须先 `updateReward` 写入当前时间快照，因此即使到期后长期无人交互，当前交易也会补上 `cp2`。
- **明确 `withdraw` 关闭前奖励结清规则（对应章节：4.1、4.4、5.3、8.1）**：`withdraw` / `withdrawMultiple` 在销毁仓位并移出 `activeDepositIds` 前，必须结清该仓位的 `pendingBaseReward` 和 `pendingInviteeBoostReward`；到期仓位同时支付 `pendingBoostReward`，提前违约仓位仅作废未解锁锁仓加速奖励，避免仓位关闭后 `claimAll()` 不再遍历导致奖励无法领取。
- **补充补贴账本状态转移表（对应章节：4.1）**：用表格明确 `notifyRewardAmount`、`updateReward`、`claimAll`、`withdraw` / `withdrawMultiple`、`sweepSubsidy` 对 `subsidyReserve` 和 `totalPendingSubsidy` 的影响，降低后续实现时对“支付、作废、提取”三类动作的理解歧义。

**2026-05-30**

**PRD/V2/PRD_V2_Staking.md**
- **明确补贴备付金账本口径（对应章节：2.2、4.1、4.3、4.5、8.3）**：将 `subsidyReserve` 定义为合约当前实际持有的补贴备付金余额，而不是历史累计预留额度，避免 `availableSubsidy = subsidyReserve - totalPendingSubsidy` 在实现时出现歧义。
- **补充双池账本不变量（对应章节：4.1）**：新增基础奖池与补贴备付金互不挪用的约束，并明确 `totalPendingSubsidy = Σ(pendingInviteeBoostReward) + Σ(pendingBoostReward) + Σ(referralRewards)`，便于后续实现和测试对账。
- **拆分自身推荐补贴账本（对应章节：2.3、5.2、8.3）**：在 `DepositRecord` 中新增 `pendingInviteeBoostReward`，不再将自身推荐补贴混入 `pendingBaseReward`，确保 `claimAll()` 能准确区分基础奖励和补贴支付。
- **明确补贴支付与作废规则（对应章节：4.1、4.4、5.2、5.3）**：补贴实际支付时同步扣减 `totalPendingSubsidy` 和 `subsidyReserve`；提前解锁导致锁仓加速奖励作废时仅扣减 `totalPendingSubsidy`，原因是补贴资金未离开合约，应重新成为可用备付金。
- **移除"是否支持同币池"二选一描述（对应章节：7.8）**统一为 `recoverERC20` 不得提取核心资产。
