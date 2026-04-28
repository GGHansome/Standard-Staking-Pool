# 修改日志 (Changelog)

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

**src/interface.sol**
- **接口自文档化继承**：`IStakingPool` 接口现直接继承 OpenZeppelin 的 `IAccessControl`，向前端和外部合约显式暴露 `grantRole` 和 `revokeRole` 等标准权限管理方法。
- 新增资产查询接口：`stakingToken()`, `rewardToken()`。
- 新增时间周期查询接口：`periodFinish()`, `lastUpdateTime()`。
- 新增暂停状态查询接口：`paused()`。
- 新增暂停管理接口：`pause()`, `unpause()`。