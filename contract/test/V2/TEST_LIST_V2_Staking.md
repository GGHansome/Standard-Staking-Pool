# V2 StakingPool 测试用例清单（三档落地版）

> 目标文件：`contract/src/V2/staking.sol`
>
> 参考文档：`contract/PRD/V2/PRD_V2_Staking.md`
>
> 目的：把 V2 测试范围从“最大覆盖清单”收敛成可落地的三档测试计划，优先覆盖资金安全、权限边界、奖励账本、锁仓、推荐、补贴和 PRD 一致性。

## 分档原则

- **P0 必写**：直接影响资金安全、账本正确性、权限边界、用户核心流程。缺失会导致合约不可上线。
- **P1 建议写**：提升覆盖质量，适合在 P0 稳定后补齐。多数可以合并到流程测试里，不需要拆得过细。
- **P2 可选 / 审计覆盖**：低风险、低变化、更多是接口表面或审计 checklist。除非追求高覆盖率或审计要求，否则不建议优先写。

# P0 必写测试

## 1. 部署参数与初始化

- `test_Constructor_RevertWhenCoreAddressIsZero`：覆盖 `stakingToken`、`rewardToken`、`admin`、`treasury` 任一为零地址时部署失败。
- `test_Constructor_AllowsOperatorZeroAndDoesNotGrantRole`：operator 为零地址时允许部署，但不应给零地址授予操作员权限。
- `test_Constructor_RevertWhenRewardsDurationIsZero`：奖励周期为 0 时部署失败。
- `test_Constructor_RevertWhenPenaltyRateGreaterThanBps`：罚金率超过 10000 BPS 时部署失败。
- `test_Constructor_RevertWhenLockTierLengthMismatch`：锁仓期限数组和 boost 数组长度不一致时部署失败。
- `test_Constructor_RevertWhenTooManyLockTiers`：锁仓档位数量超过上限时部署失败。
- `test_Constructor_RevertWhenInvalidLockTier`：覆盖锁仓期限为 0、boost 为 0、重复期限三类无效档位。
- `test_Constructor_RevertWhenMaxSubsidyRateExceedsCap`：理论最大补贴率超过部署上限时失败。
- `test_Constructor_InitializesCoreConfigAndRoles`：部署后核心 token、treasury、周期、推荐比例、罚金率、锁仓档位和角色正确。
- `test_Constructor_InitializesAccountingStateToZero`：部署后 `totalSupply`、奖励周期、基础奖池、补贴池、补贴负债均为 0。

## 2. 权限与暂停

- `test_AccessControl_OnlyOperatorCanNotifyRewardAmount`：只有 operator 可以注入奖励，非 operator 调用失败。
- `test_AccessControl_OnlyAdminCanSetTreasury`：只有 admin 可以更新 treasury。
- `test_AccessControl_OnlyAdminCanSweepSubsidy`：只有 admin 可以清扫可释放补贴。
- `test_AccessControl_OnlyAdminCanPauseAndUnpause`：只有 admin 可以暂停和恢复合约。
- `test_AccessControl_OnlyAdminCanRecoverERC20`：只有 admin 可以救援非核心 ERC20。
- `test_Pause_BlocksStakeNotifyAndSweep`：暂停后阻止 `stake`、`notifyRewardAmount`、`sweepSubsidy`。
- `test_Pause_AllowsClaimWithdrawExitAndAdminRecovery`：暂停后仍允许用户领取、退出，也允许必要管理操作。

## 3. 奖励注入与奖励周期

- `test_NotifyRewardAmount_RevertWhenAmountZero`：基础奖励注入数量为 0 时失败。
- `test_NotifyRewardAmount_RevertWhenRewardTransferIsNotExact`：奖励 token 实际到账少于请求数量时失败，覆盖 fee-on-transfer 风险。
- `test_NotifyRewardAmount_StartsNewRewardPeriod`：首次注入后设置 `rewardRate`、`lastUpdateTime`、`periodFinish`。
- `test_NotifyRewardAmount_IncreasesBaseReserveAndSubsidyLiability`：注入后增加 `baseRewardReserve`、`subsidyReserve`、`unsettledMaxSubsidyLiability`。
- `test_NotifyRewardAmount_EmitsUnsettledLiabilityIncrease`：注入新增基础奖励并增加最大补贴预算时，应抛出 `UnsettledMaxSubsidyLiabilityUpdated` 事件。
- `test_NotifyRewardAmount_UsesSweepableSubsidyBeforeChargingMore`：新周期优先复用沉淀补贴，只补缴缺口。
- `test_NotifyRewardAmount_CarriesLeftoverWhenPeriodActive`：周期未结束时续奖应把剩余基础奖励并入新释放曲线。
- `test_NotifyRewardAmount_LeftoverDoesNotIncreaseBaseReserveAgain`：续奖时上一期 `leftoverBase` 重新进入释放曲线，不应再次增加 `baseRewardReserve`。
- `test_NotifyRewardAmount_SubsidyBudgetChargedOnNewBaseOnly`：续奖时新增补贴预算只按本次注入额 `newSubsidyBase` 计提，不对 `leftoverBase` 重复计提。
- `test_RewardSchedule_IsActiveOnlyBeforePeriodFinish`：`isRewardPeriodActive` 只在 `rewardRate > 0 && now < periodFinish` 时为 true。
- `test_RemainingBaseReward_ReturnsExpectedValueDuringAndAfterPeriod`：周期内剩余基础奖励线性减少，结束后为 0。

## 4. 水位线与空窗奖励

- `test_RewardPerToken_IncreasesLinearlyWhenSupplyPositive`：有质押本金时，单位奖励按时间和本金份额线性增长。
- `test_RewardPerToken_DoesNotIncreaseWhenSupplyZero`：总质押为 0 时水位线不增长。
- `test_RewardPerToken_DoesNotIncreaseAfterPeriodFinish`：奖励周期结束后水位线不再增长。
- `test_UpdateReward_WhenSupplyZeroBurnsBaseReserveAndReleasesSubsidyBudget`：空窗期间释放的基础奖励自然流失，并释放对应最大补贴预算。
- `test_UpdateReward_WhenSupplyZeroDoesNotCreateUserRewardsOrPendingSubsidy`：空窗期间没有用户本金承接奖励，不应产生用户基础奖励或已确认补贴负债。
- `test_UpdateReward_DoesNotAccrueWhenRewardRoundsToZero`：极小奖励向下取整为 0 时不应产生错误账本变化。

## 5. 质押与仓位账本

- `test_Stake_CreatesFlexibleDeposit`：创建活期仓位，验证本金、总供应、用户仓位列表、仓位水位线、`boostSettled`。
- `test_Stake_CreatesLockedDepositWhenRewardPeriodActive`：有效奖励周期内创建锁仓仓位，验证 `unlockTime`、`boostRate`、`boostSettled=false`。
- `test_Stake_RevertWhenAmountZero`：质押金额为 0 时失败。
- `test_Stake_RevertWhenTransferIsNotExact`：质押资产实际到账少于请求数量时失败。
- `test_Stake_RevertWhenInvalidLockDuration`：非 0 且未配置的锁仓期限失败。
- `test_Stake_RevertWhenLockedStakeNotActive`：奖励周期未 active、刚好结束、结束后都不能创建锁仓仓位。
- `test_Stake_AllowsFlexibleStakeWhenRewardPeriodInactive`：奖励周期未 active 时仍允许活期质押。
- `test_Stake_RevertWhenActiveDepositLimitReached`：单用户活跃仓位数量达到上限后不能继续创建。
- `test_Stake_RevertDoesNotPersistInviterStateOrPartialAccounting`：质押流程中途失败时，邀请关系、本金、总供应、仓位列表都不应留下部分状态。
- `test_Stake_WritesOrReplacesRewardCheckpoint`：质押改变总供应，应写入快照；同时间戳内覆盖最后一条。

## 6. 邀请关系绑定

- `test_Referral_FirstStakeWithZeroInviterLocksNoInviter`：首次质押传零地址时永久记录无上级。
- `test_Referral_FirstStakeWithValidInviterBindsInviter`：首次质押传有效邀请人时绑定直接上级。
- `test_Referral_SubsequentStakeCannotChangeInviter`：首次质押后无法修改或补填邀请关系。
- `test_Referral_RevertWhenInviterIsSelfOrUnset`：邀请人不能是自己，且必须已完成首次质押状态。
- `test_Referral_RevertWhenCycleDetectedWithinThreeLevels`：三级链路内形成循环时失败。
- `test_Referral_GetUplineReturnsThreeLevels`：三级上级查询返回直接、二级、三级上级，超过三级不展示。
- `test_Referral_DisabledReferralIgnoresInvalidInviterAndDoesNotBind`：推荐费率全为 0 时，`stake` 应完全忽略 `inviter` 参数；即使传入自己或未绑定用户也不应失败，且不写入 `hasSetInviter` / `inviterOf`。

## 7. 基础奖励与补贴计提

- `test_AccrueReward_SingleUserReceivesBaseReward`：单用户按时间获得基础奖励。
- `test_AccrueReward_MultipleUsersShareByPrincipalAndTime`：多用户不同金额、不同时间入池时按份额分配。
- `test_AccrueReward_NewDepositDoesNotReceivePastRewards`：新仓位不获得创建前已释放奖励。
- `test_AccrueReward_ClosedDepositStopsReceivingFutureRewards`：关闭仓位不再获得未来奖励。
- `test_AccrueReward_UpdatesDepositWatermarkAndPendingBase`：结算后仓位水位线和待领取基础奖励更新。
- `test_AccrueReward_ReducesUnsettledLiabilityByMaxSubsidyDelta`：基础奖励实际结算后冲减对应最大理论补贴预算，并抛出未结算最大补贴负债更新事件。
- `test_AccrueReward_CumulativeLiabilityClearsSegmentedFloorDust`：累计量口径应消除分段取整尾差；`3 wei` 基础奖励按 `50%` 最大补贴率预留 `1 wei` 后，由三个仓位各结算 `1 wei`，最终未结算最大补贴负债必须归零，沉淀补贴可完整清扫。
- `test_AccrueReward_EmptyPoolNaturalAttritionEmitsUnsettledLiabilityUpdate`：空窗自然流失释放最大补贴预算时，应抛出未结算最大补贴负债更新事件。
- `test_AccrueReward_TotalPendingSubsidyTracksActualSubsidies`：已确认补贴负债等于实际计提的自身补贴、锁仓补贴和推荐返佣。

## 8. 推荐补贴与三级返佣

- `test_ReferralReward_NoUplineAccruesNoReferralReward`：无上级用户产生基础奖励时不产生推荐返佣。
- `test_ReferralReward_AccruesLevel1Level2Level3`：三级上级分别按配置比例获得推荐返佣。
- `test_ReferralReward_AccrualEmitsRewardTypeEvents`：自身推荐补贴和三级推荐返佣计提时，应按奖励类型抛出独立事件。
- `test_ReferralReward_DoesNotAccrueBeyondLevel3`：四级及以上不获得返佣。
- `test_ReferralReward_ZeroLevelRateStopsExpectedLevel`：某一级比例为 0 时，对应层级不产生返佣。
- `test_ReferralReward_ClaimableReferralRewardUpdatesAfterAccrualAndClaim`：推荐返佣计提后可查询，领取后清零。
- `test_PRD_InviteeBoostOnlyAccruesForUsersWithValidInviter`：PRD 一致性：只有绑定有效邀请人的用户才应获得自身推荐补贴。
- `test_PRD_UserWithoutInviterDoesNotReceiveInviteeBoost`：PRD 一致性：无邀请人的用户不应获得自身推荐补贴。

## 9. 锁仓 boost 与到期切分

- `test_LockBoost_AccruesBeforeUnlockButIsNotClaimable`：锁仓未到期时产生 boost pending，但不可领取。
- `test_LockBoost_SettlesAtUnlockAndBecomesClaimable`：到期后首次结算完成切分，boost 可领取。
- `test_LockBoost_ExactUnlockTimestampIsMatureNotEarly`：刚好到 `unlockTime` 时按已到期处理，不应收提前退出罚金，也不应罚没 boost。
- `test_LockBoost_DoesNotAccrueAfterUnlock`：到期后的基础奖励不再产生锁仓 boost。
- `test_LockBoost_BaseRewardContinuesAfterUnlock`：到期后本金仍继续参与基础奖励分配。
- `test_LockBoost_UsesRewardPerTokenAtUnlockInterpolation`：到期点位于快照之间时使用线性插值计算 boost 截止水位线。
- `test_LockBoost_ClampsInterpolationAtPeriodFinish`：到期晚于奖励结束时按 `periodFinish` 截断。
- `test_LockBoost_ResumesAfterCrossPeriodNotifyBeforeUnlock`：锁仓期跨越旧周期结束，若到期前续奖，剩余锁仓期应继续按仓位 `boostRate` 计提加速奖励。
- `test_PRD_EarnedByDepositAfterUnlockBeforeStateUpdateShowsClaimableBoost`：PRD 一致性：只读查询到期但未交互仓位时，应使用虚拟当前快照临时展示可领取 boost。
- `test_PRD_EarnedByDepositMatureBoostMatchesNextClaimAllPayout`：PRD 一致性：到期但未状态结算仓位的 `earnedByDeposit` mature boost 展示值，应等于下一次 `claimAll` 实际支付的锁仓加速奖励。
- `test_LockBoost_MaturitySettlementRunsWhenRewardDeltaIsZero`：锁仓到期时即使本次基础奖励增量为 0，也应完成到期切分并开放已累计 boost。

## 10. claimAll 领取奖励

- `test_EarnedAndEarnedByDeposit_ReturnExpectedClaimableBreakdown`：领取前只读查询应正确拆分基础奖励、自身补贴、推荐返佣、可领取 boost 和不可领取 boost。
- `test_PRD_EarnedMatchesNextClaimAllPayoutBeforeSettlementWithInviter`：PRD 一致性：用户有邀请人且尚未触发状态结算时，`earned(user)` 应等于下一次 `claimAll` 对该用户的实际支付金额。
- `test_ClaimAll_PaysBaseInviteeBoostReferralAndMatureBoost`：一次领取基础奖励、自身补贴、推荐返佣、已到期 boost。
- `test_ClaimAll_DoesNotPayUnmaturedBoost`：未到期 boost 不应被支付。
- `test_ClaimAll_ReducesBaseReserveSubsidyReserveAndPendingSubsidy`：支付后基础奖池、补贴备付金、已确认补贴负债正确扣减。
- `test_ClaimAll_ClearsClaimedPendingRewards`：已支付的仓位 pending 和用户级推荐返佣清零。
- `test_ClaimAll_CannotDoublePay`：重复领取不能重复支付。
- `test_PRD_ClaimAllDoesNotWriteRewardCheckpoint`：PRD 一致性：领取奖励不改变总供应或奖励曲线，不应写入快照。

## 11. withdraw 单仓位退出

- `test_Withdraw_RevertWhenDepositMissingClosedOrNotOwner`：不存在、已关闭、非 owner 三类退出失败。
- `test_Withdraw_FlexibleDepositReturnsFullPrincipalAndCloses`：活期仓位退出返还本金并关闭仓位。
- `test_Withdraw_MatureLockedDepositReturnsFullPrincipalAndPaysRewards`：已到期锁仓退出返还本金并支付可领取奖励。
- `test_Withdraw_EarlyLockedDepositAppliesPenaltyAndPaysTreasury`：未到期锁仓提前退出扣罚金并转给 treasury。
- `test_Withdraw_EarlyLockedDepositForfeitsUnmaturedBoost`：提前退出罚没未到期 boost，减少 `totalPendingSubsidy` 但不减少 `subsidyReserve`。
- `test_Withdraw_PaysBaseInviteeAndReferralRewards`：退出时支付该仓位基础奖励和自身推荐补贴，并保证该仓位产生的上级推荐返佣可由上级单独领取。
- `test_ReferralReward_WithdrawDoesNotClaimUserLevelReferralReward`：`withdraw` 只关闭指定仓位，不应顺带领取调用者的用户级推荐返佣。
- `test_Withdraw_RemovesDepositFromActiveListAndUpdatesTotals`：退出后活跃列表、用户本金、总供应正确更新。
- `test_Withdraw_WritesRewardCheckpoint`：退出改变总供应，应写入奖励快照。

## 12. withdrawMultiple 与 exit

- `test_WithdrawMultiple_RevertWhenIdsEmptyTooManyDuplicateOrInvalid`：批量退出空数组、超长数组、重复 ID、非法 ID 都失败。
- `test_WithdrawMultiple_WithdrawsMixedDepositsAndAggregatesAccounting`：批量退出活期、已到期锁仓、未到期锁仓，汇总本金、罚金和奖励。
- `test_WithdrawMultiple_RemovesOnlySpecifiedDeposits`：只移除指定仓位，未指定仓位保持活跃。
- `test_WithdrawMultiple_EmitsPerDepositEvents`：即使转账聚合执行，也应为每个被退出的 `depositId` 抛出独立事件，供链下索引器按仓位统计。
- `test_ReferralReward_WithdrawMultipleDoesNotClaimUserLevelReferralReward`：`withdrawMultiple` 只关闭指定仓位集合，不应顺带领取调用者的用户级推荐返佣。
- `test_Exit_WithNoDepositsStillClaimsReferralReward`：无活跃仓位但有推荐返佣时，`exit` 仍可领取。
- `test_Exit_WithOnlyReferralRewardDoesNotWriteCheckpoint`：仅领取用户级推荐返佣、不关闭任何活跃仓位时，`exit` 不应写入 `RewardCheckpointWritten`。
- `test_Exit_WithdrawsAllActiveDepositsAndDoesNotAffectOthers`：退出调用者全部仓位，不影响其他用户。
- `test_Exit_DoesNotSkipDepositsWhenActiveListShrinksDuringLoop`：实现风险：遍历退出时不应因为列表缩短跳过仓位。

## 13. 补贴清扫与资产覆盖

- `test_MaxSweepableSubsidy_ReturnsReserveMinusPendingAndUnsettled`：可清扫补贴等于补贴储备减已确认和未结算负债。
- `test_MaxSweepableSubsidy_AccountsForZeroSupplyAttritionInView`：只读查询应考虑空窗自然流失释放的补贴预算。
- `test_SweepSubsidy_RevertWhenToZeroAmountZeroOrExceedsSweepable`：清扫接收人零地址、金额 0、超额清扫都失败。
- `test_SweepSubsidy_ReducesReserveAndTransfersRewardToken`：清扫成功后补贴储备减少并转出奖励 token。
- `test_SweepSubsidy_SyncsZeroSupplyAttritionBeforeSweep`：清扫前应先同步空窗自然流失，释放可清扫补贴并更新相关负债。
- `test_SweepSubsidy_DoesNotBreakSubsidyCoverage`：清扫后仍满足补贴储备覆盖已确认补贴和未结算负债。
- `test_AssetCoverage_DistinctTokensCoversPrincipalBaseAndSubsidy`：异币池中质押资产覆盖本金，奖励资产覆盖基础奖励和补贴。
- `test_AssetCoverage_SameTokenCoversPrincipalBaseAndSubsidyTogether`：同币池中单一 token 余额覆盖本金、基础奖励和补贴总和。
- `test_AssetCoverage_RevertWhenCoverageIsBroken`：人为破坏余额覆盖后，受保护入口应失败。

## 14. Treasury 与 Recover

- `test_SetTreasury_RevertWhenNewTreasuryZero`：新 treasury 为零地址时失败。
- `test_SetTreasury_UpdatesTreasuryForFuturePenalties`：更新后未来提前退出罚金进入新 treasury。
- `test_RecoverERC20_RevertWhenTokenZeroAmountZeroOrCoreToken`：救援零地址、金额 0、质押资产、奖励资产都失败。
- `test_RecoverERC20_TransfersNonCoreTokenToAdmin`：非核心 ERC20 可被 admin 救援，不影响核心账本。

## 15. P0 流程集成

- `test_Flow_FlexibleStakeNotifyClaimWithdraw`：活期质押、注入奖励、领取、退出的完整路径。
- `test_Flow_LockedStakeMatureClaimAndWithdraw`：锁仓质押、到期、领取 boost、退出的完整路径。
- `test_Flow_LockedStakeEarlyWithdrawForfeitsBoostAndPaysPenalty`：锁仓提前退出、罚金和 boost 罚没完整路径。
- `test_Flow_ThreeLevelReferralAccrueAndClaim`：三级推荐链、返佣计提、各上级领取完整路径。
- `test_Flow_MultipleUsersDifferentEntryAndExitTimes`：多用户不同时间入池和退出，验证奖励份额正确。
- `test_Flow_SameTokenPoolNotifyStakeClaimWithdraw`：同币池完整路径，验证逻辑资金桶不会互相挪用。

---

# P1 建议写测试

## 1. 部署和配置补充

- `test_Constructor_AllowsBoundaryPenaltyRates`：罚金率 0 和 10000 BPS 都允许部署。
- `test_Constructor_AllowsEmptyAndMaxLockTiers`：空锁仓档位和最大锁仓档位数量都能正确部署。
- `test_Constructor_ComputesMaxSubsidyRateWithLargestBoostTier`：最大补贴率应取推荐补贴加最大锁仓 boost 的理论上限。
- `test_Views_ReturnConfiguredLockReferralPenaltyAndSubsidyConfig`：合并验证锁仓、推荐、罚金、补贴配置 getter。

## 2. 奖励周期和水位线补充

- `test_NotifyRewardAmount_EmitsExpectedFundingEvents`：注入奖励时抛出补贴、负债更新、奖励注入和快照事件。
- `test_RewardSchedule_BoundariesAtOneSecondBeforeAtAndAfterFinish`：周期结束前、结束时、结束后三个时间点行为正确。
- `test_RewardPerToken_HandlesOneWeiAndLargeTotalSupply`：覆盖极小和极大总供应的取整表现。
- `test_RemainingBaseReward_DoesNotDriveSolvencyChecks`：`remainingBaseReward` 只用于展示，不作为资金覆盖依据。

## 3. 质押和仓位补充

- `test_Stake_AllowsRestakeAfterWithdrawBelowLimit`：退出一个仓位后可再次创建仓位。
- `test_Stake_ActiveDepositLimitIsPerUser`：仓位上限按用户独立计算。
- `test_PRD_MaxActiveDepositsLimitIsSharedByPrdGetterAndFrontendCopy`：PRD、合约 getter、测试断言和前端提示文案应使用同一个确定上限值 `50`，避免展示和链上限制漂移。
- `test_Stake_CheckpointReplacedWithinSameTimestampAndAppendedLater`：同时间戳覆盖快照，不同时间戳追加快照。
- `test_GetUserDeposits_ReturnsOnlyActiveDeposits`：用户仓位列表只返回活跃仓位。
- `test_GetDeposit_DistinguishesNonexistentActiveAndClosed`：`getDeposit` 应可通过 `owner != 0 && amount == 0` 推导已关闭仓位，区分不存在、活跃、已关闭三态。

## 4. 推荐系统补充

- `test_Referral_ColdStartUserCanStakeWithoutInviter`：冷启动阶段首个用户可以无邀请人质押。
- `test_Referral_LevelRatesZeroSkipExpectedRewards`：一级、二级、三级比例为 0 时对应返佣处理正确。
- `test_Referral_ReferralRewardsRemainAfterInviteeWithdraws`：被邀请人退出后，已计提返佣仍归上级。
- `test_PRD_ReferralRewardAccruedEventsAreEmittedForEachLevel`：PRD 一致性：每一级推荐返佣计提应有事件。
- `test_PRD_InviteeBoostRewardAccruedEventIsEmitted`：PRD 一致性：自身补贴计提应有事件。

## 5. 锁仓和快照补充

- `test_LockBoost_BoundariesOneSecondBeforeAtAndAfterUnlock`：锁仓到期前、到期时、到期后三个时间点行为正确。
- `test_LockBoost_UnlockBeforeFirstCheckpointUsesFirstCheckpoint`：到期点早于第一条快照时返回第一条快照水位线。
- `test_LockBoost_UnlockAtCheckpointUsesExactRewardPerToken`：到期点命中快照时使用精确快照。
- `test_LockBoost_UnlockAfterLastCheckpointUsesVirtualCurrentCheckpoint`：到期点晚于最后快照时使用虚拟当前节点。
- `test_LockBoost_SecondPostUnlockUpdateDoesNotRecalculateUnlockPoint`：到期切分只发生一次，后续复用缓存。

## 6. 领取和退出补充

- `test_ClaimAll_WithNoRewardsDoesNothing`：没有奖励时调用不转账、不改变核心账本。
- `test_ClaimAll_LeavesUnclaimableBoostPendingAcrossDeposits`：多仓位中未到期 boost 保持 pending。
- `test_Withdraw_PenaltyRateZeroAndBpsBoundaries`：提前退出在 0% 和 100% 罚金率下行为正确。
- `test_Withdraw_ActiveListRemovalHandlesFirstMiddleLast`：退出第一个、中间、最后仓位时列表和索引正确。
- `test_WithdrawMultiple_HandlesIdsOrderDifferentFromActiveListOrder`：批量退出传入顺序与活跃列表不同也正确。

## 7. 补贴和资产覆盖补充

- `test_MaxSweepableSubsidy_IncreasesAfterUnusedBudgetConsumed`：用户实际结算后，未使用补贴预算变成可清扫。
- `test_MaxSweepableSubsidy_IncreasesAfterBoostForfeited`：提前退出罚没 boost 后，对应补贴变成可清扫。
- `test_SweepSubsidy_AllowsPartialAndFullSweepableAmount`：部分清扫和刚好清扫上限都成功。
- `test_SameTokenPool_EarlyPenaltyDoesNotBreakCoverage`：同币池提前退出罚金转出后不破坏剩余账本覆盖。

## 8. P1 流程集成

- `test_Flow_NotifyDuringActivePeriodThenUsersClaimCorrectly`：周期内续奖后多用户奖励仍正确。
- `test_Flow_ZeroSupplyAttritionThenSweepThenNewNotify`：空窗自然流失、清扫沉淀补贴、再次注入奖励状态正确。
- `test_Flow_ExitMixedFlexibleMatureAndEarlyLockedDeposits`：`exit` 同时处理活期、已到期锁仓、未到期锁仓。
- `test_Flow_UplineExitClaimsOwnReferralRewards`：上级退出自己仓位时同时领取自己的推荐返佣。

---

# P2 可选 / 审计覆盖测试

## 1. 常量和接口表面

- `test_Constants_ReturnExpectedValues`：合并验证 `BPS`、`MAX_ACTIVE_DEPOSITS`、`MAX_LOCK_TIERS`、`OPERATOR_ROLE`。低价值，除非外部强依赖常量。
- `test_SupportsInterface_ReturnsExpectedValues`：验证 V2 接口和 AccessControl 接口支持情况。通常不是资金风险点。

## 2. Getter 初始值和展示类查询

- `test_Views_InitialStateReturnsExpectedZeros`：合并验证初始 reward schedule、subsidy config、earned 等为 0。
- `test_Views_RevertWhenUserAddressIsZero`：合并验证用户地址类 getter 传零地址时统一失败。
- `test_Views_EarnedByDepositFlagsBeforeAndAfterUnlock`：细化验证 `boostClaimable`、`boostForfeitable` 展示字段。
- `test_Views_ClaimableReferralRewardZeroAndNonZero`：单独覆盖推荐奖励视图从 0 到非 0 再归 0。
- `test_Views_HarnessRewardPerTokenAtReturnsStoredWhenNoHistory`：测试环境直接覆盖无奖励快照时 `_rewardPerTokenAt` 返回当前存储水位线。
- `test_Views_HarnessRewardPerTokenAtBeforeFirstCheckpoint`：测试环境直接覆盖目标时间早于第一条快照时返回第一条快照水位线。
- `test_Views_HarnessRewardPerTokenAtBetweenInactiveCheckpointsReturnsPreviousValue`：测试环境直接覆盖两个无有效奖励区间快照之间查询时返回左侧快照值。
- `test_Views_HarnessRewardPerTokenAtMiddleCheckpointReturnsCheckpointValue`：测试环境直接覆盖目标时间精确命中奖励历史中间快照时返回该快照值。
- `test_Views_LastTimeRewardApplicableReturnsMinNowAndPeriodFinish`：直接验证 `lastTimeRewardApplicable` 在初始、周期内、周期后分别返回 `min(now, periodFinish)`。

## 3. 事件字段细查

- `test_Events_StakedWithdrawnEarlyWithdrawnAndDepositClosedFields`：合并检查用户资产相关事件字段。
- `test_Events_RewardAccruedAndPaidFields`：合并检查奖励计提和支付事件字段。
- `test_Events_AdminAndFundingFields`：合并检查配置、注资、补贴、救援事件字段。

## 4. ERC20 异常细节

- `test_Token_RevertingTransferFromBubblesUp`：token `transferFrom` revert 时入口整体失败。
- `test_Token_RevertingTransferBubblesUp`：token `transfer` revert 时领取、退出、清扫或救援失败。
- `test_Reentrancy_StakeWithdrawClaimAreGuarded`：通过恶意 token 在转账回调中重入 `stake`、`withdraw`、`claimAll` 等入口应被 `nonReentrant` 拦截。
- `test_RecoverERC20_DoesNotChangeAnyCoreAccounting`：救援非核心 token 后核心账本完全不变。

## 5. 数学和取整细节

- `test_Rounding_OneWeiStakeRewardPenaltyReferralAndBoost`：1 wei 场景下奖励、罚金、返佣、boost 全部按向下取整。
- `test_Rounding_SmallRewardRateDoesNotOverpayReserve`：极小奖励释放不应导致超过储备支付。
- `test_Rounding_ReferralAndBoostDoNotExceedMaxSubsidyBudget`：推荐和 boost 实际补贴不应超过最大理论预算。

## 6. 快照细节

- `test_Checkpoint_NoWriteForPauseTreasuryRecoverAndClaim`：暂停、更新 treasury、救援、领取奖励不应写快照。
- `test_Checkpoint_ReplacedFlagTrueOnlyForSameTimestamp`：只有同时间戳覆盖时事件 `replaced` 为 true。
- `test_Checkpoint_InterpolationDegenerateIntervalReturnsLeftReward`：插值区间被周期结束截断为无长度时返回左侧快照值。

## 7. Harness 内部防御路径

- `test_HarnessReferral_RevertWhenCycleDetected`：测试环境构造异常邀请链路，直接覆盖内部环检测防御分支。
- `test_HarnessRemoveActiveDeposit_NoopsWhenDepositIsNotActive`：测试环境直接覆盖移除非活跃仓位时 no-op 返回。
- `test_HarnessAssetCoverage_RevertWhenSubsidyReserveBelowLiability`：测试环境构造补贴储备低于待覆盖负债时资产覆盖校验失败。
- `test_HarnessAssetCoverage_RevertWhenSameTokenBalanceBelowRequired`：测试环境构造同币池余额低于本金、基础奖励和补贴总需求时失败。
- `test_HarnessAssetCoverage_RevertWhenStakingBalanceBelowSupply`：测试环境构造异币池质押资产余额低于总本金时失败。

---

# Invariant / 状态机测试

Invariant 不属于 P0 单元测试，但建议在 P0 主流程稳定后写。它用于随机组合操作后持续检查账本不变量。

- `invariant_TotalSupplyEqualsTrackedActivePrincipal`：总质押始终等于已跟踪用户的活跃仓位本金之和；每个用户的质押汇总也等于其活跃仓位本金之和。
- `invariant_DistinctTokenBalancesCoverAccountingReserves`：异币池下，质押 token 余额覆盖总本金，奖励 token 余额覆盖基础奖励储备和补贴储备。
- `invariant_SubsidySweepableNeverExceedsReserve`：可清扫补贴和已确认补贴负债都不能超过补贴储备。
- `invariant_SubsidyReserveCoversPendingAndUnsettledLiability`：补贴备付金始终覆盖已确认补贴负债和未结算最大补贴负债。
- `invariant_TotalPendingSubsidyMatchesAllPendingSubsidies`：已确认补贴负债始终等于所有仓位补贴 pending 和推荐返佣余额之和。
- `invariant_UnsettledLiabilityOnlyChangesOnNotifySettleOrAttrition`：未结算最大补贴负债只在注入、用户结算或空窗流失等允许范围内变化。
- `invariant_ActiveDepositIdsHaveNoDuplicates`：任意用户活跃仓位列表中不存在重复仓位编号。
- `invariant_RewardPerTokenNeverDecreases`：全局奖励水位线不会下降。
- `invariant_KnownClosedDepositsAreNotActive`：已跟踪且关闭的仓位不会留在 owner 的活跃仓位列表里。

---

# 推荐执行顺序

1. 先完成 P0 的部署、权限、暂停、奖励注入、质押。
2. 再完成 P0 的基础奖励、推荐、锁仓 boost、领取、退出。
3. 然后补 P0 的补贴清扫、资产覆盖、同币池和核心流程集成。
4. P0 全部通过后，补 P1 的边界、快照、事件、复杂流程。
5. 最后按需要补 P2 和 invariant。

---

# 规模预估

- P0：约 70～90 个测试，适合上线前必须完成。
- P1：约 25～40 个测试，适合提升覆盖率和回归质量。
- P2：约 10～20 个测试，适合审计覆盖或追求高覆盖率。
- Invariant：约 6～8 个核心不变量即可，不要一开始就写太多。

实际落地优先目标：**先把 P0 写扎实，不追求数量，追求资金账本和状态机正确。**