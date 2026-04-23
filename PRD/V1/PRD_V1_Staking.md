# 产品需求文档 (PRD) - V1 标准双币质押收益池 (Standard Dual-Token Staking Pool)

## 1. 产品概述 (Product Overview)

### 1.1 业务背景
为了激励社区长期持有平台代币并减少二级市场的流通盘抛压，本项目计划推出 V1 版本的去中心化质押收益合约（Staking Pool）。
本期 V1 采用经典的**无锁仓随存随取模型（Flexible Staking）**，依托成熟的 Synthetix 奖励分发算法（水位线模型），确保海量用户高频交互时收益计算的精确性与低 Gas 消耗。合约在架构设计上天然支持质押与奖励为不同的代币，为后续 V2 多奖励代币池 (Multi-Reward) 和 V3 锁仓加速机制打下坚实的智能合约底层基础。

### 1.2 核心目标
1. **降低流通量 (TVL 捕获)**：通过提供有竞争力的动态 APR（年化收益率），吸引持有者将代币存入智能合约中。
2. **平滑的通胀释放**：确保运营团队可以精确控制奖励代币的释放速率，避免奖励被瞬间套利抽干。
3. **资金安全绝对底线**：在任何极端情况（前端宕机、奖励池枯竭、遭遇黑客尝试利用重入漏洞）下，必须保证用户**本金的安全**以及随时全额提退的能力。

### 1.3 核心资产定义 (Tokenomics)
- **质押代币 (Staking Token)**：任意指定的 ERC20 代币（例如平台币 `$STK` 或 DEX 的流动性 LP Token）。
- **奖励代币 (Reward Token)**：任意指定的 ERC20 代币（例如稳定币 `$USDC` 或治理代币 `$REWARD`）。在智能合约架构层面，质押代币与奖励代币被完全解耦，既支持“同币复投”，也完美支持“异币挖矿”。
- **奖励来源**：由项目方运营金库（Treasury）定期向质押池注入。

---

## 2. 产品机制与经济模型 (Product Mechanics & Economics)

### 2.1 动态收益计算模型 (The Water-Level Model)
收益计算不采用固定利率，而是采用**动态份额瓜分机制**：
- **全局变量定义**：
  - `RewardRate` (奖励发放速率)：每秒向整个奖池释放的代币数量。
  - `RewardsDuration` (奖励周期)：单次注入奖励的持续时间（例如 7 天 = 604800 秒）。
  - `TotalSupply` (总锁仓量)：当前资金池内的所有质押代币总和。
- **收益分配逻辑**：每秒释放的奖励由全体质押者按其**当前质押量占总锁仓量的比例**进行分配。
  - *经济学表现*：当池内总质押量（TVL）较低时，早期参与者将获得极高的 APR；随着更多资金涌入，APR 会被自然摊薄，达到市场博弈的动态平衡。

### 2.2 奖励注入与延期平滑机制 (Reward Notification & Smoothing)
为防止“巨鲸（大资金）”在运营团队注入奖励的前一秒冲入池子抢夺高额奖励，随后立刻撤资（即“三明治抢矿攻击”），系统设计了**奖励周期展期机制**：
- 运营团队调用 `notifyRewardAmount(uint256 reward)` 注入新的资金 `R_new`。
- **如果当前奖励周期已结束**：新的奖励速率 `RewardRate = R_new / RewardsDuration`。
- **如果当前奖励周期未结束（还有剩余未发放奖励 `R_left`）**：
  - 合约会将剩余未发放的 `R_left` 与新注入的 `R_new` 合并。
  - 新的奖励速率 `RewardRate = (R_left + R_new) / RewardsDuration`。
  - **核心效果**：这会将新老奖励混合，并在一个新的完整周期（如 7 天）内重新平滑释放，使得短线投机资金无法瞬间榨干红利。

---

## 3. 用户操作流程图 (User Flows)

### 3.1 资金存入 (Stake)
1. **授权 (Approve)**：用户在前端向质押合约授权转移指定数量的 `$STK`。
2. **结算 (UpdateReward)**：**前置触发**，结算并记录用户在本次操作前已经产生的历史未领奖励。
3. **入池 (Transfer)**：合约通过 `SafeERC20.safeTransferFrom` 将代币从用户钱包扣款至合约地址。
4. **记账**：增加用户的 `balance` 和全局的 `totalSupply`。

### 3.2 提取本金 (Withdraw)
1. **参数校验**：检查用户请求提取的金额必须 $\le$ 其当前质押余额。
2. **结算 (UpdateReward)**：**前置触发**，结算直至提取这一秒为止的最新历史收益。
3. **出池 (Transfer)**：合约通过 `SafeERC20.safeTransfer` 将指定本金退还至用户钱包。
4. **记账**：扣减用户的 `balance` 和全局的 `totalSupply`。

### 3.3 领取收益 (Claim Reward)
1. **结算 (UpdateReward)**：**前置触发**，更新用户的可领收益总额。
2. **清零**：将用户内部账本中的 `rewards[account]` 余额清零（防重入攻击的核心步骤）。
3. **发放 (Transfer)**：将奖励代币打入用户钱包。
*(注：为提升体验，提供 `exit()` 一键退出功能，即依次执行全额 `withdraw` 和 `getReward`)*

---

## 4. 权限控制与治理边界 (Governance & Access Control)

V1 阶段由于不涉及复杂的 DAO 投票，权限采用简化的双角色模型，但必须防范单点作恶风险。

### 4.1 普通管理员 (Operator)
- **权限**：仅能调用 `notifyRewardAmount` 向池内注入奖励资金，并触发新的发奖周期。
- **限制**：无法转移资金，无法修改核心参数，可以由运营团队的自动化脚本（Bot）控制。

### 4.2 超级管理员 (Owner / Admin)
- **身份要求**：必须由项目的多重签名钱包（Multi-Sig，例如 3/5 门限）控制。
- **特权操作 1 - 设置奖励周期**：调用 `setRewardsDuration`。**业务边界限制**：该操作只能在当前发奖周期完全结束后才能调用，防止在进行中途恶意篡改导致收益计算错乱。
- **特权操作 2 - 紧急暂停 (Pause/Unpause)**：当监控到合约出现异常或前端遭受到大规模攻击时，暂停合约。
- **特权操作 3 - 逃生舱 (Recover ERC20)**：如果用户误操作将不支持的代币（如 USDC, WETH）打入了该合约，Owner 有权将其提走并退还给用户。
  - **红线限制**：代码层面必须严格禁止 Owner 提取 **质押代币 (Staking Token)** 本金，也必须禁止提取 **当前周期内尚未发放完的奖励代币**。

---

## 5. 异常处理与安全熔断机制 (Risk Management)

### 5.1 精度丢失与除零异常
- **业务场景**：在极端情况下（如池内只有 1 wei 的极小资金，或者时间极短），计算 `RewardPerToken` 会出现除以总供应量的情况。
- **应对策略**：合约内部强制使用先乘后除原则，乘数放大至 $10^{18}$ 精度处理。

### 5.2 奖励池余额不足 (Reward Insolvency)
- **业务场景**：理论上，管理员应当在调用 `notifyRewardAmount(X)` 之前，确保合约内真实的 Reward Token 余额 $\ge X$。如果管理员手误少打了钱，会导致后期用户领奖时 `transfer` 失败而交易 Revert。
- **应对策略**：在 `notifyRewardAmount` 函数内部，必须加入强校验机制：`require(rewardRate * rewardsDuration <= rewardToken.balanceOf(address(this)), "Reward amount too high");`。

### 5.3 暂停状态下的降级体验 (Paused State Behaviors)
- **业务场景**：合约触发 `pause()` 进入紧急暂停状态。
- **应对策略**：
  - 阻断：禁止任何新的 `stake()` 资金进入。
  - 放行：**必须允许**用户执行 `withdraw()` 撤出本金，以及 `getReward()` 提取已结算的历史收益。保障用户的“最后撤离权”。

### 5.4 防范假充值与恶意代币
- **业务场景**：针对部分非标准的 ERC20 代币（例如转账时不返回布尔值，或者有转账抽水/通缩机制的代币）。
- **应对策略**：所有代币交互强制包裹 OpenZeppelin 的 `SafeERC20` 库。本期 V1 不支持自带通缩机制（Fee-on-transfer）的代币，若未来需要支持，需在 PRD V2 中增加通过计算转账前后余额差值（Balance Delta）来确认实际到账金额的逻辑。

---

## 6. 数据支持与前端依赖 (Integration Requirements)

为支持前端 DApp 界面与数据分析面板的开发，智能合约需暴露以下接口和事件：

### 6.1 前端核心视图 (View Functions)
1. `totalSupply()`：用于计算当前矿池的总 TVL。
2. `rewardRate()`：用于前端实时计算并展示当前的全局 APR：$APR = (rewardRate \times 31536000 / totalSupply) \times 100\%$。
3. `earned(address)`：用于在用户仪表盘实时跳动展示“未领取收益”的数字。
4. `balanceOf(address)`：用于展示“我的质押金额”。

### 6.2 链上事件追踪 (Events)
必须抛出完整的日志事件，以供 The Graph 或后端索引器统计分析：
- `Staked(address indexed user, uint256 amount)`
- `Withdrawn(address indexed user, uint256 amount)`
- `RewardPaid(address indexed user, uint256 reward)`
- `RewardAdded(uint256 reward)`
