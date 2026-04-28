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
- 运营团队需先向质押合约授权 (`Approve`) 额度，随后调用 `notifyRewardAmount(uint256 reward)` 注入新的资金 `R_new`。
- **强制内部划转**：合约内部首行逻辑必须通过 `SafeERC20.safeTransferFrom(msg.sender, address(this), reward)` 将代币从调用者钱包原子化扣除。严禁“先手动转账，再调用 notify 进行余额差值校验”的非原子化设计，以避免资金被恶意干扰或管理员误操作导致资金滞留。
- **如果当前奖励周期已结束**：新的奖励速率 `RewardRate = R_new / RewardsDuration`。
- **如果当前奖励周期未结束（还有剩余未发放奖励 `R_left`）**：
  - 合约会将剩余未发放的 `R_left` 与新注入的 `R_new` 合并。
  - 新的奖励速率 `RewardRate = (R_left + R_new) / RewardsDuration`。
  - **核心效果**：这会将新老奖励混合，并在一个新的完整周期（如 7 天）内重新平滑释放，使得短线投机资金无法瞬间榨干红利。

### 2.3 空窗期奖励归属 (Reward Leakage)
当奖励周期已开启，但池内总质押量 `totalSupply == 0` 时：
- **流失机制**：该时间段内按 `RewardRate` 释放的奖励将被视为自然流失。
- **资金归属**：流失的奖励将**永久滞留**在合约的账本外余额中，不参与后续的奖励重新分配，也不能被第一个进入矿池的质押者独吞（严防套利）。这种机制变相实现了奖励代币的通缩销毁，对代币的长期价值形成支撑。

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

V1 阶段由于不涉及复杂的 DAO 投票，权限采用简化的多角色模型，但必须防范单点作恶风险。
**技术选型**：合约层面将直接继承并使用 OpenZeppelin 的 `AccessControl` 库进行角色管理，并结合 `Pausable` 库实现紧急暂停功能。

### 4.1 超级管理员 (DEFAULT_ADMIN_ROLE)
- **身份要求**：必须由项目的多重签名钱包（Multi-Sig，例如 3/5 门限）控制。
- **生命周期与转移**：
  - **初始分配**：在合约部署的**构造函数**中，将 `DEFAULT_ADMIN_ROLE` 授予指定的地址（如多签钱包），而不是默认给部署者，防止权限滞留。
  - **权限转移**：Admin 的更换通过 `AccessControl` 的 `grantRole` 和 `revokeRole` 实现，触发 `RoleGranted` / `RoleRevoked` 事件。
- **特权操作 1 - 设置奖励周期**：调用 `setRewardsDuration`。**业务边界限制**：该操作只能在当前发奖周期完全结束后才能调用，防止在进行中途恶意篡改导致收益计算错乱。
- **特权操作 2 - 紧急暂停 (Pause/Unpause)**：调用 `pause()` 和 `unpause()`。当监控到合约出现异常或前端遭受到大规模攻击时，暂停合约。
- **特权操作 3 - 逃生舱 (Recover ERC20)**：如果用户误操作将不支持的代币打入了该合约，Admin 有权将其提走并退还给用户。
  - **红线限制（绝对隔离）**：代码层面必须直接判断传入的代币地址，**严禁 Admin 调用此方法提取 `Staking Token` 或 `Reward Token`**。
  - **单币池原则**：即便是同币池（`stakingToken == rewardToken`）或者空窗期流失的奖励，为了防止特权账户滥用或复杂的记账漏洞，系统**拒绝任何救援核心资产**的操作，误打入或流失的核心资产将永远留存在合约中。

### 4.2 普通管理员 (OPERATOR_ROLE)
- **角色定位**：负责定期高频向池内打入奖励资金。可以由运营团队的自动化脚本（Bot）或热钱包控制。
- **生命周期**：
  - **初始分配**：构造函数中可传入初始 Operator 地址并授予 `OPERATOR_ROLE`，也可留空后续由 Admin 添加。
  - **更换/增删**：仅拥有 `DEFAULT_ADMIN_ROLE` 的超级管理员，才能调用 `grantRole` 和 `revokeRole` 增加、替换或移除 Operator。天然支持多个 Operator 并存。
- **权限**：仅能调用 `notifyRewardAmount` 向池内注入奖励资金，并触发新的发奖周期。**注：默认情况下，超级管理员若无 `OPERATOR_ROLE` 也无法直接调用此方法，必须先为自己授予该角色，以保证严格的权限隔离。**
- **限制**：无法转移资金，无法修改核心参数。

### 4.3 零值操作限制 (Zero-Value Validation)
为防止无意义的日志事件污染、Gas 空耗以及除以零漏洞，系统对核心状态变更操作进行严格的前置阻断：
- **操作对象**：`stake(amount)`, `withdraw(amount)`, `notifyRewardAmount(reward)`, `setRewardsDuration(duration)`。
- **强制约束**：以上所有函数的首行必须包含 `require(value > 0, "Must be greater than 0")`，若输入参数为 0 则直接 Revert 交易。不允许用 0 值来强行触发前置结算（若用户只希望结算奖励而不变更本金，应显式调用无参的 `getReward()` 方法）。

---

## 5. 异常处理与安全熔断机制 (Risk Management)

### 5.1 精度丢失与除零异常
- **业务场景**：在极端情况下（如池内只有 1 wei 的极小资金，或者时间极短），计算 `RewardPerToken` 会出现除以总供应量的情况。
- **应对策略**：合约内部强制使用先乘后除原则，乘数放大至 $10^{18}$ 精度处理。同时，结合 `4.3 零值操作限制`，从入口处彻底杜绝除以零的隐患。

### 5.2 暂停状态下的降级体验 (Paused State Behaviors)
- **业务场景**：合约触发 `pause()` 进入紧急暂停状态。
- **应对策略（黑白名单明确边界）**：
  - 🚫 **阻断 (Revert)**：
    - `stake()`：禁止任何新的资金进入。
    - `notifyRewardAmount()`：禁止注入新奖励，避免账本由于暂停时间过长而发生错乱。
    - `setRewardsDuration()`：锁定核心配置。
  - ✅ **放行 (Allow)**：
    - `withdraw()` / `getReward()` / **`exit()`**：必须放行。`exit()` 组合了前两者，这是用户的“最后撤离权”，保证极端情况（如黑客攻击或前端宕机）下用户也能全额拿回本金和已结算的历史收益。
    - `recoverERC20()`：必须放行。暂停状态往往就是为了修复异常或挽救打错的资金，该特权接口需保持可用。

### 5.3 防范假充值与恶意代币
- **业务场景**：针对部分非标准的 ERC20 代币（例如转账时不返回布尔值，或者有转账抽水/通缩机制的代币）。
- **应对策略**：所有代币交互强制包裹 OpenZeppelin 的 `SafeERC20` 库。本期 V1 不支持自带通缩机制（Fee-on-transfer）的代币，若未来需要支持，需在 PRD V2 中增加通过计算转账前后余额差值（Balance Delta）来确认实际到账金额的逻辑。

---

## 6. 数据支持与前端依赖 (Integration Requirements)

为支持前端 DApp 界面与数据分析面板的开发，智能合约需暴露以下接口和事件：

### 6.1 前端核心视图 (View Functions)
1. `stakingToken()`：获取质押代币的合约地址，用于前端读取代币精度和符号。
2. `rewardToken()`：获取奖励代币的合约地址，用于前端读取代币精度和符号。
3. `totalSupply()`：用于计算当前矿池的总 TVL。
4. `rewardRate()`：用于前端实时计算并展示当前的全局 APR。
5. `earned(address)`：用于在用户仪表盘实时跳动展示“未领取收益”的数字。
6. `balanceOf(address)`：用于展示“我的质押金额”。
7. `periodFinish()`：当前奖励周期的结束时间戳，前端可用于展示发奖倒计时。
8. `lastUpdateTime()`：最近一次全局奖励更新的时间戳。
9. `paused()`：查询合约当前是否处于暂停状态，前端可据此置灰“质押”按钮。

### 6.2 前端 APR 计算与展示规范 (Frontend APR Calculation)
**核心原则**：智能合约仅负责精确的代币数量发放，**绝对不负责**由于价格波动引起的 APR 计算。前端（或后端索引器）需读取合约状态并结合外部预言机报价自行计算并展示 APR。

#### 6.2.1 标准异币挖矿 APR 公式
当质押代币与奖励代币不同且市值不同时，必须引入 USD 价格进行换算，公式如下：
$$APR = \frac{(rewardRate \times 31536000 \times \text{RewardTokenUSDPrice})}{\text{totalSupply} \times \text{StakingTokenUSDPrice}} \times 100\%$$
- **价格数据源**：前端统一通过调用 **CoinGecko API** 获取实时的 `StakingTokenUSDPrice` 和 `RewardTokenUSDPrice`。
- **精度对齐 (Decimals)**：在代入公式计算前，前端必须先根据各自代币的 `decimals()` 将链上读取的原始 `rewardRate` 和 `totalSupply` 转换为人类可读数量（例如将 $10^{18}$ wei 转换为 1 ETH）。

#### 6.2.2 质押 LP Token 的特殊价格计算
如果 V1 池指定的 `Staking Token` 是 DEX（如 Uniswap V2/V3、PancakeSwap）的流动性凭证 LP Token，前端无法直接从 CoinGecko 查到该 LP 的现价，必须通过公式推导 LP 价格：
$$\text{LP\_Price} = \frac{(\text{ReserveA} \times \text{PriceA}) + (\text{ReserveB} \times \text{PriceB})}{\text{LP\_TotalSupply}}$$
*(注：前端需额外请求该 DEX 的 Factory/Pair 合约，获取底层池子中代币 A 和代币 B 的总储备量 `ReserveA` 和 `ReserveB`，以及该 LP 的总发行量 `LP_TotalSupply`。)*

#### 6.2.3 零值与异常展示处理
- **`totalSupply == 0` 降级**：当池子刚建立尚无资金进入时，分母为 0。前端在检测到此状态时，**必须拦截计算以避免 `Infinity` 或 `NaN` 报错**，UI 界面统一优雅降级显示为 **`--`**（或由运营配置的一个固定“初始预期 APR”），等待首笔资金进入。

### 6.2 链上事件追踪 (Events)
必须抛出完整的日志事件，以供 The Graph 或后端索引器统计分析：
- `Staked(address indexed user, uint256 amount)`
- `Withdrawn(address indexed user, uint256 amount)`
- `RewardPaid(address indexed user, uint256 reward)`
- `RewardAdded(uint256 reward)`
