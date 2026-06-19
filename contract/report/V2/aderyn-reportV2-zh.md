# Aderyn 分析报告 V2（中文阅读版）

本报告由 [Aderyn](https://github.com/Cyfrin/aderyn) 生成。Aderyn 是 Cyfrin 提供的 Solidity 静态分析工具。本报告只能作为发现潜在安全问题的辅助材料，不能替代人工审计或安全复核，也不应作为唯一判断依据。

# 目录

- [概览](#概览)
  - [文件概览](#文件概览)
  - [文件明细](#文件明细)
  - [问题概览](#问题概览)
- [低危问题](#低危问题)
  - [L-1：中心化风险](#l-1中心化风险)
  - [L-2：循环内存在高成本操作](#l-2循环内存在高成本操作)
  - [L-3：除法和乘法顺序不当](#l-3除法和乘法顺序不当)
  - [L-4：大数字字面量](#l-4大数字字面量)
  - [L-5：循环内包含 `require` / `revert`](#l-5循环内包含-require--revert)
  - [L-6：状态变量可改为 immutable](#l-6状态变量可改为-immutable)
  - [L-7：未缓存 storage 数组长度](#l-7未缓存-storage-数组长度)
  - [L-8：未检查返回值](#l-8未检查返回值)
  - [L-9：局部变量未显式初始化](#l-9局部变量未显式初始化)

# 概览

## 文件概览

| 项目 | 值 |
| --- | --- |
| `.sol` 文件数量 | 1 |
| 总 nSLOC | 790 |

## 文件明细

| 文件路径 | nSLOC |
| --- | --- |
| `src/V2/staking.sol` | 790 |
| **总计** | **790** |

## 问题概览

| 类别 | 数量 |
| --- | --- |
| 高危 | 0 |
| 低危 | 9 |

# 低危问题

## L-1：中心化风险

合约中存在拥有特权的管理员或操作员角色。这些角色可以执行管理任务，因此系统需要信任这些角色不会恶意更新配置或转移资金。

发现 7 处：

- `src/V2/staking.sol#L18`：`StakingPool` 继承了 `AccessControl`，存在角色权限模型。
- `src/V2/staking.sol#L517`：`notifyRewardAmount` 受 `OPERATOR_ROLE` 控制。
- `src/V2/staking.sol#L554`：`setTreasury` 受 `DEFAULT_ADMIN_ROLE` 控制。
- `src/V2/staking.sol#L566`：`sweepSubsidy` 受 `DEFAULT_ADMIN_ROLE` 控制。
- `src/V2/staking.sol#L582`：`pause` 受 `DEFAULT_ADMIN_ROLE` 控制。
- `src/V2/staking.sol#L587`：`unpause` 受 `DEFAULT_ADMIN_ROLE` 控制。
- `src/V2/staking.sol#L592`：`recoverERC20` 受 `DEFAULT_ADMIN_ROLE` 控制。

## L-2：循环内存在高成本操作

循环中执行 `SSTORE` 等写入 storage 的操作会增加 gas 成本。更优做法通常是先在本地变量中累计结果，循环结束后再一次性写回。

发现 4 处循环入口：

- `src/V2/staking.sol#L490`：`withdrawMultiple` 相关循环。
- `src/V2/staking.sol#L502`：`exit` 相关循环。
- `src/V2/staking.sol#L629`：奖励更新相关循环。
- `src/V2/staking.sol#L640`：批量领取相关循环。

## L-3：除法和乘法顺序不当

Solidity 使用整数运算，先除后乘可能造成精度损失。通常应尽量先乘后除，或使用精度安全的计算方式。

发现 1 处：

- `src/V2/staking.sol#L892`：`boostReward` 计算中先除以 `PRECISION`，随后再乘以 boost 比例，可能产生精度损失。

## L-4：大数字字面量

较大的 10 的倍数字面量可以使用科学计数法表达，例如 `1e18`。这类问题主要是可读性和风格提示。

发现 1 处：

- `src/V2/staking.sol#L29`：`BPS = 10_000`。

## L-5：循环内包含 `require` / `revert`

循环中如果某个元素触发 `require` 或 `revert`，整笔交易都会失败。对于批量处理场景，更稳健的设计通常是跳过失败项，并在结果中返回失败列表。

发现 4 处循环入口：

- `src/V2/staking.sol#L490`：批量 withdraw 的循环。
- `src/V2/staking.sol#L502`：exit 的循环。
- `src/V2/staking.sol#L1147`：校验 depositIds 的循环。
- `src/V2/staking.sol#L1148`：校验重复 depositId 的嵌套循环。

## L-6：状态变量可改为 immutable

如果状态变量只在构造阶段写入，之后不再变化，可以考虑使用 `immutable` 以降低 gas 成本。

发现 2 处：

- `src/V2/staking.sol#L116`：`durations`。
- `src/V2/staking.sol#L119`：`boosts`。

注意：这里是数组类型，是否能直接改为 `immutable` 需要结合 Solidity 对动态数组 immutable 的支持和当前存储设计判断，不能机械修改。

## L-7：未缓存 storage 数组长度

循环条件中反复读取 storage 数组的 `.length` 成本较高。可以先把长度缓存到本地变量，再在循环中复用。

发现 1 处：

- `src/V2/staking.sol#L940`：循环条件使用 `durations.length`。

## L-8：未检查返回值

某些函数存在返回值，但调用方没有使用或检查该返回值。建议确认返回值是否有语义，如果有，应显式处理。

发现 3 处：

- `src/V2/staking.sol#L211`：`_grantRole(DEFAULT_ADMIN_ROLE, params.admin)`。
- `src/V2/staking.sol#L213`：`_grantRole(OPERATOR_ROLE, params.operator)`。
- `src/V2/staking.sol#L527`：`_pullExact(rewardToken, msg.sender, subsidyCharged)`。

## L-9：局部变量未显式初始化

局部变量如果依赖默认零值，建议显式初始化，提升可读性并减少静态分析噪音。

发现 9 处：

- `src/V2/staking.sol#L185`：循环变量 `i`。
- `src/V2/staking.sol#L194`：循环变量 `j`。
- `src/V2/staking.sol#L302`：循环变量 `i`。
- `src/V2/staking.sol#L490`：循环变量 `i`。
- `src/V2/staking.sol#L502`：循环变量 `i`。
- `src/V2/staking.sol#L629`：循环变量 `i`。
- `src/V2/staking.sol#L640`：循环变量 `i`。
- `src/V2/staking.sol#L940`：循环变量 `i`。
- `src/V2/staking.sol#L1147`：循环变量 `i`。

# 阅读结论

Aderyn 未报告高危问题，主要集中在：

- 权限集中带来的治理信任问题。
- 批量循环中的 gas 成本和失败传播问题。
- 奖励计算中的先除后乘精度损失风险。
- 若干风格类或静态分析噪音问题。

需要优先人工复核的是：`L-1` 权限边界、`L-3` 奖励精度、`L-5` 批量操作失败模型。