# 修改日志 (Changelog)

**2026-05-07**

**PRD/V1/PRD_V1_Staking.md**
- **补充完整事件列表**：在 PRD 中补全了合约实际会触发的所有事件，包括继承自 `AccessControl` 与 `Pausable` 的 `RoleGranted`、`RoleRevoked`、`RoleAdminChanged`、`Paused`、`Unpaused` 事件，确保前端和索引服务接入时不遗漏。
- **4.3 零值操作限制**：将 `recoverERC20` 加入零值校验操作对象列表，并新增“错误类型语义”规范，明确要求数量为零时必须使用 `AmountMustBeGreaterThanZero()` 等对应业务零值错误，避免抛出不准确的地址错误。
- **5.3 防范假充值与恶意代币**：
  - 明确 V1 仅支持标准 ERC20，不支持自带通缩机制（Fee-on-transfer）、rebasing 等非标准代币。
  - 新增“部署/配置层约束”，要求目标代币存在非标准行为时不允许创建或配置该池。
  - 新增“合约层兜底”策略，强制要求 `stake()` 与 `notifyRewardAmount()` 必须通过转账前后余额差校验实际到账数量，不一致时 revert `FeeOnTransferNotSupported()`。
- **6.3 链上事件追踪**：补充了完整的事件列表，新增 `RewardsDurationUpdated`、`Recovered`，以及继承自 OpenZeppelin 的 `RoleGranted`、`RoleRevoked`、`RoleAdminChanged`、`Paused`、`Unpaused` 事件。并明确要求前端和后端索引服务必须一并接入这些集成依赖事件。

**test/staking.test.sol**
- 新增 `test_MultipleUsersStakingAtDifferentTimesSplitRewardsPrecisely`：覆盖多用户按时间错峰质押后的精确奖励分配，验证 `1500/500` 类分配结果。
- 新增 `test_SameTokenPoolPaysRewardsWithoutTouchingPrincipal`：覆盖 `stakingToken == rewardToken` 同币池的正常发奖，并验证用户提现本金不受奖励支付影响。
- 新增 `test_SameTokenPoolKeepsLeakedRewardsAndPrincipalWithdrawable`：覆盖同币池空窗期奖励泄漏场景，并验证用户本金仍可完整提现。
- 新增 `test_ExitOnlyClaimsRewardWhenPrincipalIsZero`：覆盖用户本金为 0 但仍有已结算奖励时，`exit()` 只执行 `getReward()` 的场景。
- 新增 `test_NotifyRewardAmountAtPeriodFinishStartsFreshPeriod`：覆盖 `notifyRewardAmount()` 在 `block.timestamp == periodFinish` 时开启新周期的边界行为。
- 新增 `test_SetRewardsDurationBoundaryAroundPeriodFinish`：覆盖 `setRewardsDuration()` 在周期结束前一秒、正好结束、结束后一秒的边界行为。
- 新增 `test_GrantAndRevokeOperatorRoleTakesEffectImmediately`：覆盖 `grantRole/revokeRole` 后 Operator 权限实时生效和失效。
- 新增 `test_PauseUnpauseRewardsDurationRecoveredAndRoleEvents`：覆盖 `Paused/Unpaused`、`RewardsDurationUpdated`、`Recovered`、`RoleGranted/RoleRevoked` 事件。
- 新增 `test_DifferentDecimalsStakeAndRewardTokensDistributeCorrectly`：覆盖 staking token 为 6 decimals、reward token 为 18 decimals 的奖励分配场景。
- 新增 `test_AccountingInvariantsHoldForStandardStakingToken`：覆盖 `sum(userInfo.balance) == totalSupply`，以及标准 staking token 场景下 `stakingToken.balanceOf(pool) >= totalSupply`。
- 新增 `test_StandardRewardTokenSolvencyCoversEarnedAndRemainingRewards`：覆盖标准 reward token 场景下，未领取奖励加剩余周期奖励不超过合约可用 reward token 余额。

**src/staking.sol**
- `constructor`：移除对 `_operator == address(0)` 的强制 revert 校验，改为 `if (_operator != address(0))` 授权，允许初始 Operator 留空后续由 Admin 添加。
- `stake` 函数：增加 `actualAmount != amount` 时的 `FeeOnTransferNotSupported()` 阻断校验，防止因通缩代币导致实际到账为 0 时仍成功执行并发出错误事件。
- `notifyRewardAmount` 函数：增加 `actualReward != reward` 时的 `FeeOnTransferNotSupported()` 阻断校验，防止 fee-on-transfer 代币导致合约记录的奖励债务大于实际收到的代币余额。
- `recoverERC20` 函数：将 `tokenAmount == 0` 时的 revert 错误类型从 `AddressCannotBeZero()` 更正为 `AmountMustBeGreaterThanZero()`。
- 全局：补充完整的 NatSpec 注释（`@notice`, `@param`, `@return` 等），提升代码可读性。

**Berfore**

**PRD/V1/PRD_V1_Staking.md**
- **明确权限生命周期**：详细说明了 `DEFAULT_ADMIN_ROLE` 和 `OPERATOR_ROLE` 的初始分配、权限转移机制，以及严格的权限隔离原则（Admin 需授权给自己才能调用 `notifyRewardAmount`）。
- **明确紧急暂停机制的边界**：清晰界定了 `pause()` 状态下的降级体验，阻断 `stake`, `notifyRewardAmount`, `setRewardsDuration` 操作，但**必须放行**用户的最后撤离权 `withdraw`, `getReward`, `exit`，以及紧急救援接口 `recoverERC20`。
- **明确前端 APR 计算规范 (解耦)**：新增 `6.2 前端 APR 计算与展示规范` 节，明确规定合约端不负责 APR 计算。前端需结合 **CoinGecko API** 获取 USD 价格进行异币挖矿和 LP Token 的 APR 换算，并定义了 `totalSupply == 0` 时的降级展示方案（显示为 `--`）。
- 明确权限管理技术选型：使用 OpenZeppelin 的 `AccessControl` 和 `Pausable` 库。
- 完善角色定义：细化 Admin 和 Operator 权限，增加 Admin 的暂停/解除暂停特权。
- 补充前端视图接口：增加 `stakingToken()`, `rewardToken()`, `periodFinish()`, `lastUpdateTime()`, `paused()` 的说明。
- 变更奖励注入机制：废弃两步走方案，强制在 `notifyRewardAmount` 内部首行使用 `safeTransferFrom` 原子化扣除代币，并删除了相关的“余额不足”异常处理章节。
- 明确空窗期奖励归属：新增 2.3 节，规定 `totalSupply == 0` 时释放的奖励永久滞留合约（变相通缩销毁）。
- 绝对隔离逃生舱权限：完善 4.2 节特权操作，明确规定代码层面必须强行阻断 `recoverERC20` 提取 `stakingToken` 和 `rewardToken`，拒绝一切核心资产的救援。（原因：若允许救援同币/核心资产，需额外增加两个全局状态变量 `historicalNotified`（历史总注入奖励）和 `historicalClaimed`（历史总提取奖励）来精确分离“用户本金+待领奖励”与“可提取流失资产”。这不仅增加了系统复杂度和充提操作的 Gas 消耗，更会因“官方拥有提取核心资产的特权后门”而引发被 Rug Pull 的担忧，严重削弱社区信任度。）
- 增加零值操作限制：新增 4.3 节，强制要求所有状态变更函数（`stake`, `withdraw`, `notifyRewardAmount`, `setRewardsDuration`）的输入值必须大于 0，防止无效事件污染和 Gas 空耗。

- **完善 `notifyRewardAmount` 描述**：明确要求通过本函数原子化 `safeTransferFrom` 注入奖励，禁止手动转账后 notify，避免牺牲 CEI 规范或漏掉旧周期收益结算。
- **完善 `exit` 逻辑细节**：明确 `exit()` 必须在用户本金 `balance > 0` 时才调用内部 `withdraw`，否则仅执行 `getReward`，避免因 `withdraw(0)` 触发零值校验而导致 `exit` 失败。

**src/interface.sol**
- **接口自文档化继承**：`IStakingPool` 接口现直接继承 OpenZeppelin 的 `IAccessControl`，向前端和外部合约显式暴露 `grantRole` 和 `revokeRole` 等标准权限管理方法。
- 新增资产查询接口：`stakingToken()`, `rewardToken()`。
- 新增时间周期查询接口：`periodFinish()`, `lastUpdateTime()`。
- 新增暂停状态查询接口：`paused()`。
- 新增暂停管理接口：`pause()`, `unpause()`。

- **暴露角色常量标识符**：在 `IStakingPool` 接口中显式声明了 `OPERATOR_ROLE() external view returns (bytes32)`，以便前端或外部合约能够获取该角色的 `bytes32` 标识符，从而正确调用继承自 `IAccessControl` 的 `hasRole/grantRole/revokeRole` 方法。