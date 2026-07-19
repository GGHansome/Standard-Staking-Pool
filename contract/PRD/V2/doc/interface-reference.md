# V2 锁仓推荐质押池接口参考

## 1. 文档职责

本文档集中维护 V2 的公共调用面、视图语义和事件签名。产品行为见 [`product-spec.md`](./product-spec.md)，内部执行顺序见 [`architecture.md`](./architecture.md)，资金口径见 [`accounting-and-solvency.md`](./accounting-and-solvency.md)。

本文档只整理原始 V2 PRD 已经确立的接口，不新增函数、参数或事件。

## 2. 通用约定

- 所有比例采用 BPS，`10000 == 100%`。
- `rewardRate` 使用 `PRECISION = 1e18` 放大。
- 单笔仓位由全局唯一 `depositId` 标识。
- 仓位不存在：`owner == address(0)`。
- 仓位活跃：`owner != address(0) && amount > 0`。
- 仓位已关闭：`owner != address(0) && amount == 0`。
- `inviterOf(user) == address(0)` 必须结合 `hasSetInviter(user)` 解读。
- 用户主动领奖只提供 `claimAll()`；仓位关闭时按仓位结清对应奖励。

## 3. 构造参数

构造函数必须一次性接收并校验本活动池固定配置，包括但不限于：

- `stakingToken`；
- `rewardToken`；
- `rewardsDuration`；
- 锁仓档位 `durations[] / boosts[]`；
- `inviteeBoost`；
- `level1 / level2 / level3`；
- `maxSubsidyRateCap`；
- `penaltyRate`；
- `treasury`；
- 管理员地址。

部署后，上述经济参数不可修改；Treasury 是运行期可更新的安全配置。完整校验见 [`product-spec.md`](./product-spec.md#活动配置承诺)。

## 4. 用户写接口

### 4.1 `stake(uint256 amount, uint256 lockDuration, address inviter)`

创建新的独立仓位。

- `amount > 0`；
- `lockDuration == 0` 创建活期仓位；
- `lockDuration > 0` 必须匹配已配置档位且 `isRewardPeriodActive() == true`；
- 用户首次质押时处理并永久确定邀请状态；
- 非首次质押忽略 `inviter` 参数；
- 实际到账金额必须等于 `amount`；
- 成功后返回语义由 `Staked` 事件中的 `depositId` 表达。

### 4.2 `claimAll()`

领取调用者当前全部可领奖励：

- 所有活跃仓位的基础奖励；
- 所有活跃仓位的自身推荐补贴；
- 已到期并完成切分的锁仓加速奖励；
- 用户级推荐返佣。

不支付未到期或尚未完成到期切分的锁仓加速奖励。该接口不改变 `totalSupply`，也不写入 `rewardHistory`。

### 4.3 `withdraw(uint256 depositId)`

全额关闭指定仓位：

- 必须存在、属于调用者且尚未关闭；
- 关闭前结清基础奖励和自身推荐补贴；
- 已到期仓位同时结清未领取的锁仓加速奖励；
- 提前关闭按规则扣罚并作废未解锁锁仓加速奖励；
- 不支持部分提取。

### 4.4 `withdrawMultiple(uint256[] calldata depositIds)`

原子化关闭多个仓位：

- 数组长度必须大于 0，且不得超过批量上限；
- 不允许重复 ID；
- 任一 ID 无效、非调用者所有、已关闭或校验失败，整笔交易回退；
- 只对调用者执行一次统一奖励结算；
- 转账可以聚合，但每个仓位分别抛出生命周期事件。

### 4.5 `exit()`

关闭调用者全部活跃仓位，并领取全部可领奖励。没有活跃仓位但仍有可领奖励或推荐返佣时，不得因零本金提取失败。

## 5. 管理员写接口

### 5.1 `notifyRewardAmount(uint256 baseRewardAmount)`

普通管理员注入新的基础奖励，并按最大理论补贴率补缴或滚动使用补贴备付金。

- `baseRewardAmount > 0`；
- 实际到账必须等于输入；
- 新释放曲线必须形成非零 `rewardRate`；
- 旧周期未结束时，将 `remainingBaseReward()` 与本次实际新增基础奖励一起进入新完整周期；
- leftover 不重复增加累计注入量或补贴预算；
- 调用前同步旧曲线与空窗自然流失；
- 暂停时回退。

### 5.2 `setTreasury(address treasury)`

超级管理员设置罚金接收地址。

- 新地址必须非零；
- 不受部署固定经济配置限制；
- 暂停时仍允许调用；
- 不修改历史仓位、基础奖励或补贴账本。

### 5.3 `sweepSubsidy(address to, uint256 amount)`

超级管理员提取安全范围内的沉淀补贴备付金。

- 先同步全局奖励账本；
- `amount <= maxSweepableSubsidy()`；
- 只减少 `subsidyReserve`；
- 暂停时回退。

### 5.4 `sweepExpiredBaseReward(address to)`

奖励周期结束且空池后，超级管理员一次性回收全部剩余基础奖励。

- `to != address(0)`；
- `block.timestamp >= periodFinish`；
- `totalSupply == 0`；
- `baseRewardReserve > 0`；
- 不支持指定部分金额；
- 回收同步增加 `settledBaseCumulative` 并重算潜在补贴负债；
- 不修改 `subsidyReserve` 或 `totalPendingSubsidy`；
- 暂停时回退。

### 5.5 `pause()` / `unpause()`

超级管理员暂停或恢复受限制入口。暂停行为矩阵见 [`security-model.md`](./security-model.md#暂停期间退出)。

### 5.6 `recoverERC20(address token, uint256 amount)`

救援误转入合约的非核心资产。

- `amount > 0`；
- 禁止 `stakingToken`；
- 禁止 `rewardToken`；
- 同币池核心 Token 完全不可救援；
- 暂停时仍允许调用。

## 6. 仓位与奖励视图

### 6.1 `getDeposit(uint256 depositId)`

返回单个仓位详情，至少包含 `owner` 和 [`architecture.md`](./architecture.md#仓位数据模型) 定义的仓位字段。

调用方通过 `owner` 与 `amount` 区分不存在、活跃和已关闭仓位。

### 6.2 `getActiveDepositIds(address user)`

返回用户当前全部活跃仓位 ID。

### 6.3 `getUserDeposits(address user)`

批量返回用户当前全部活跃仓位详情，返回结构与 `getDeposit` 一致。

### 6.4 `totalStakedOf(address user)`

返回用户全部活跃仓位本金合计。

### 6.5 `earned(address user)`

返回用户当前可通过 `claimAll` 领取的总奖励，包含：

- 基础奖励；
- 自身推荐补贴；
- 用户级推荐返佣；
- 已解锁的锁仓加速奖励。

不包含未到期锁仓加速奖励。若仓位已经到期但链上尚未持久化 `boostSettled`，只读上下文必须通过虚拟当前快照临时完成到期切分，保证展示结果与下一次写结算一致。

### 6.6 `earnedByDeposit(uint256 depositId)`

返回指定仓位的奖励拆分：

- 基础奖励；
- 自身推荐补贴；
- 锁仓加速奖励。

锁仓加速奖励应区分：

- 未到期、只记账且提前关闭将作废；
- 已完成到期切分，可通过 `claimAll` 或关闭仓位领取。

到期但尚未持久化切分时，使用与 `earned` 相同的只读临时投影。

### 6.7 `claimableReferralReward(address user)`

返回用户级推荐返佣余额。

## 7. 推荐关系视图

### 7.1 `inviterOf(address user)`

返回直接邀请人。零地址可能表示尚未首次质押，也可能表示已经永久选择无上级，必须结合 `hasSetInviter` 判断。

### 7.2 `hasSetInviter(address user)`

返回用户是否已经在首次质押时永久确定邀请状态。为 `true` 后，前端不得允许修改或补填邀请人。

### 7.3 `getUpline(address user)`

返回上三级地址 `(level1, level2, level3)`。不存在的层级返回 `address(0)`。

## 8. 配置聚合视图

### 8.1 `getLockTiers()`

返回 `durations[]` 与 `boosts[]`。

该接口只表示活动池的可用档位，不表示当前时间锁仓已经开放。前端还必须检查 `isRewardPeriodActive()`。活期档位由前端隐式展示，不要求存在于数组中。

### 8.2 `getReferralRates()`

返回 `(inviteeBoost, level1, level2, level3)`，全部使用 BPS。

### 8.3 `getPenaltyConfig()`

返回 `(penaltyRate, treasury)`，用于展示提前退出成本和当前罚金流向。

### 8.4 `getSubsidyConfig()`

返回：

`(maxSubsidyRate, maxSubsidyRateCap, subsidyReserve, totalPendingSubsidy, unsettledMaxSubsidyLiability)`

用于前端和管理员面板展示补贴预算与偿付状态。

### 8.5 `MAX_ACTIVE_DEPOSITS()`

返回单用户最大活跃仓位数，V2 固定为 50。

## 9. 奖励周期与资金账本视图

### 9.1 `getRewardSchedule()`

返回：

`(rewardsDuration, periodFinish, rewardRate, lastUpdateTime, rewardPerTokenStored)`

`rewardRate` 已放大 `1e18`，前端计算真实每秒奖励或 APR 时必须先除以 `1e18`。

### 9.2 `isRewardPeriodActive()`

当且仅当 `rewardRate > 0 && block.timestamp < periodFinish` 返回 `true`。

返回 `false` 时，活期仓位仍可创建，任何 `duration > 0` 的新仓位必须回退。历史锁仓仓位不受影响。

### 9.3 `baseRewardReserve()`

返回基础奖池当前未支付余额，是资产覆盖不变量的链上校验口径。

### 9.4 `injectedBaseCumulative()`

返回历史累计纳入基础释放预算的实际新增基础奖励。

### 9.5 `settledBaseCumulative()`

返回历史累计已经归属用户或确认不再归属用户的基础奖励。

### 9.6 `remainingBaseReward()`

返回当前周期尚未释放的基础奖励余额。周期结束后返回 0。该值只用于调度展示，不得单独作为补贴安全提取依据。

### 9.7 `subsidyReserve()`

返回当前实际补贴备付金现金余额。

### 9.8 `totalPendingSubsidy()`

返回已确认但尚未支付的补贴负债。

### 9.9 `unsettledMaxSubsidyLiability()`

返回尚未通过用户结算、空窗流失或过期回收消化的最大理论补贴负债。精确恒等式见 [`accounting-and-solvency.md`](./accounting-and-solvency.md#未结算最大补贴负债)。

### 9.10 `maxSweepableSubsidy()`

返回当前可安全提取的沉淀补贴上限。

该函数不修改状态。`totalSupply == 0` 时，在只读上下文中临时投影空窗自然流失后的 `settledBaseCumulative` 与 `unsettledMaxSubsidyLiability`，再计算返回值。

## 10. 事件规范

所有影响用户资产、奖励归属、推荐关系或核心配置的状态变化都必须抛出事件。奖励事件按类型拆分，链下统计不得只依赖聚合事件。

### 10.1 用户与仓位

```solidity
event Staked(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount,
    uint256 lockDuration,
    uint256 unlockTime,
    uint256 boostRate
);

event Withdrawn(
    address indexed user,
    uint256 indexed depositId,
    uint256 principalReturned
);

event EarlyWithdrawn(
    address indexed user,
    uint256 indexed depositId,
    uint256 principalReturned,
    uint256 penaltyAmount,
    uint256 forfeitedBoostReward
);

event DepositClosed(address indexed user, uint256 indexed depositId);
event InviterBound(address indexed user, address indexed inviter);
event NoInviterSet(address indexed user);
```

### 10.2 奖励记账

```solidity
event BaseRewardAccrued(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);

event LockBoostRewardAccrued(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);

event InviteeBoostRewardAccrued(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);

event ReferralRewardAccrued(
    address indexed inviter,
    address indexed invitee,
    uint8 indexed level,
    uint256 sourceDepositId,
    uint256 amount
);

event LockBoostRewardForfeited(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);
```

### 10.3 奖励支付

```solidity
event BaseRewardPaid(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);

event InviteeBoostRewardPaid(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);

event ReferralRewardPaid(address indexed user, uint256 amount);

event LockBoostRewardPaid(
    address indexed user,
    uint256 indexed depositId,
    uint256 amount
);

event RewardPaid(address indexed user, uint256 totalAmount);
```

`RewardPaid` 可作为聚合兼容事件保留，但不能替代按奖励类型拆分的事件。

### 10.4 资金与配置

```solidity
event ActivityConfigured(
    uint256 rewardsDuration,
    uint256 inviteeBoost,
    uint256 level1,
    uint256 level2,
    uint256 level3,
    uint256 maxSubsidyRate,
    uint256 maxSubsidyRateCap,
    uint256 penaltyRate
);

event RewardAdded(
    uint256 baseRewardAmount,
    uint256 subsidyRequired,
    uint256 subsidyCharged
);

event RewardCheckpointWritten(
    uint256 indexed time,
    uint256 rewardPerToken,
    uint256 periodFinish,
    uint256 index,
    bool replaced
);

event SubsidyReserved(uint256 amount);
event UnsettledMaxSubsidyLiabilityUpdated(uint256 newValue);
event SubsidySwept(address indexed to, uint256 amount);
event ExpiredBaseRewardSwept(address indexed to, uint256 amount);

event PenaltyPaid(
    address indexed user,
    uint256 indexed depositId,
    address indexed treasury,
    uint256 amount
);

event TreasuryUpdated(address indexed treasury);
event Recovered(address indexed token, uint256 amount);
```

`ActivityConfigured` 记录池级固定规则。锁仓档位可通过独立字段或配套事件记录。

### 10.5 继承事件

```solidity
event Paused(address account);
event Unpaused(address account);

event RoleGranted(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
);

event RoleRevoked(
    bytes32 indexed role,
    address indexed account,
    address indexed sender
);
```

## 11. 错误语义约束

原始 V2 规格明确以下错误边界：

- 返佣比例未构成连续前缀：`InvalidReferralRateConfig`；
- 实际到账与输入不一致：`FeeOnTransferNotSupported()`；
- 地址为零使用地址类错误；
- 数量为零使用数量类错误；
- 奖励金额无法形成非零释放速率时必须回退；
- 奖励周期仍活动、池内仍有本金或没有可回收基础奖励时，`sweepExpiredBaseReward` 必须回退。

本文档不补造原始 PRD 未列出的完整错误名称集合；错误 ABI 应与合约接口源码保持同步。