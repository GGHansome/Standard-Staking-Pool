Feature: V1 Standard Dual-Token Staking Pool
  As a DeFi user and protocol operator
  I want a secure, flexible staking pool with dynamic rewards
  So that I can earn yield on my tokens without lock-ups, and the protocol can incentivize liquidity

  Background:
    Given a deployed Staking Pool contract
    And the staking token is "STK"
    And the reward token is "REWARD"
    And the reward duration is 7 days

  # ------------------------------------------------------------------
  # 1. Staking (资金存入)
  # ------------------------------------------------------------------
  Scenario: User successfully stakes tokens for the first time
    Given a user has 100 STK in their wallet
    And the user has approved the Staking Pool to spend 100 STK
    And the user currently has 0 staked balance
    When the user calls "stake" with 100 STK
    Then the user's staked balance should increase to 100
    And the total supply of the pool should increase by 100
    And a "Staked" event should be emitted for the user with amount 100

  Scenario: User stakes additional tokens and triggers reward settlement
    Given a user has already staked 100 STK
    And the user has accumulated 5 REWARD in pending rewards
    When the user calls "stake" with an additional 50 STK
    Then the user's pending reward balance should be updated to 5 REWARD
    And the user's staked balance should become 150
    And the total supply of the pool should increase by 50

  Scenario: User attempts to stake 0 tokens
    Given a user has 100 STK in their wallet
    When the user calls "stake" with 0 STK
    Then the transaction should revert
    And the error message should indicate "Must be greater than 0"

  # ------------------------------------------------------------------
  # 2. Withdrawing (提取本金)
  # ------------------------------------------------------------------
  Scenario: User successfully withdraws a portion of their staked tokens
    Given a user has a staked balance of 100 STK
    When the user calls "withdraw" with 40 STK
    Then the user's staked balance should decrease to 60
    And the total supply of the pool should decrease by 40
    And the user's wallet should receive 40 STK
    And a "Withdrawn" event should be emitted for the user with amount 40

  Scenario: User attempts to withdraw more than their staked balance
    Given a user has a staked balance of 100 STK
    When the user attempts to call "withdraw" with 150 STK
    Then the transaction should revert
    And the error message should indicate insufficient balance

  Scenario: User attempts to withdraw 0 tokens
    Given a user has a staked balance of 100 STK
    When the user attempts to call "withdraw" with 0 STK
    Then the transaction should revert
    And the error message should indicate "Must be greater than 0"

  # ------------------------------------------------------------------
  # 3. Claiming Rewards (领取收益)
  # ------------------------------------------------------------------
  Scenario: User successfully claims accumulated rewards
    Given a user has 10 REWARD in pending rewards
    When the user calls "getReward"
    Then the user's pending reward balance should be reset to 0
    And the user's wallet should receive 10 REWARD
    And a "RewardPaid" event should be emitted for the user with amount 10

  # ------------------------------------------------------------------
  # 4. Exiting (一键退出)
  # ------------------------------------------------------------------
  Scenario: User uses the exit function to withdraw all and claim rewards
    Given a user has a staked balance of 100 STK
    And the user has accumulated 10 REWARD in pending rewards
    When the user calls "exit"
    Then the user's staked balance should become 0
    And the user's pending reward balance should become 0
    And the user's wallet should receive 100 STK and 10 REWARD

  # ------------------------------------------------------------------
  # 5. Operator Reward Injection (运营注入奖励)
  # ------------------------------------------------------------------
  Scenario: Operator starts a new reward period
    Given there is no active reward period
    And the operator has 7000 REWARD in their wallet
    And the operator has approved the Staking Pool to spend 7000 REWARD
    When the operator calls "notifyRewardAmount" with 7000 REWARD
    Then the reward rate should be set to 7000 divided by the reward duration
    And a new reward period should start
    And a "RewardAdded" event should be emitted with amount 7000

  Scenario: Operator injects rewards before the current period ends (Reward Smoothing)
    Given the current reward period has 3 days remaining
    And there are 3000 REWARD left undistributed in the current period
    And the operator has approved the Staking Pool to spend at least 4000 REWARD
    When the operator calls "notifyRewardAmount" with 4000 REWARD
    Then the new reward rate should be calculated based on the sum of 3000 and 4000 (total 7000)
    And the reward duration should be reset to a full 7 days

  Scenario: Operator attempts to inject rewards without sufficient approval or balance
    Given the operator has only approved 1000 REWARD
    When the operator attempts to call "notifyRewardAmount" with 5000 REWARD
    Then the transaction should revert
    And the error message should relate to ERC20 insufficient allowance or balance

  Scenario: Operator attempts to inject 0 rewards
    Given the operator is authorized
    When the operator attempts to call "notifyRewardAmount" with 0 REWARD
    Then the transaction should revert
    And the error message should indicate "Must be greater than 0"

  # ------------------------------------------------------------------
  # 6. Reward Leakage (空窗期奖励归属)
  # ------------------------------------------------------------------
  Scenario: Rewards leak and permanently stay in contract when total supply is zero
    Given a reward period is active with a reward rate of 1 REWARD per second
    And the total supply of the pool is 0
    When 10 seconds pass
    Then 10 REWARD should be considered leaked
    And the leaked REWARD should permanently remain in the contract
    And the leaked REWARD cannot be claimed by the next staker

  # ------------------------------------------------------------------
  # 7. Admin Privileges & Risk Management (管理员特权与风控)
  # ------------------------------------------------------------------
  Scenario: Graceful degradation during emergency pause
    Given the contract is in a "Paused" state
    When a user attempts to call "stake"
    Then the transaction should revert
    When an operator attempts to call "notifyRewardAmount"
    Then the transaction should revert
    When an admin attempts to call "setRewardsDuration"
    Then the transaction should revert
    When a user attempts to call "withdraw" or "getReward" or "exit"
    Then the transaction should succeed
    When the admin attempts to call the rescue function for an unsupported ERC20
    Then the transaction should succeed

  Scenario: Admin rescues accidentally transferred tokens
    Given a user accidentally transferred 100 USDC to the contract
    When the admin calls the rescue function for USDC
    Then the admin should successfully receive 100 USDC
    When the admin attempts to call the rescue function for STK or REWARD
    Then the transaction should revert to protect core assets

  Scenario: Admin attempts to set reward duration to 0
    Given the current reward period has ended
    When the admin attempts to call "setRewardsDuration" with 0
    Then the transaction should revert
    And the error message should indicate "Must be greater than 0"

  # ------------------------------------------------------------------
  # 8. Access Control & Roles (权限控制)
  # ------------------------------------------------------------------
  Scenario: Non-operator attempts to call notifyRewardAmount
    Given a user does not have the OPERATOR_ROLE
    When the user attempts to call "notifyRewardAmount"
    Then the transaction should revert
    And the error message should relate to AccessControl

  Scenario: Non-admin attempts to call admin functions
    Given a user does not have the DEFAULT_ADMIN_ROLE
    When the user attempts to call "setRewardsDuration", "pause", or "recoverERC20"
    Then the transaction should revert
    And the error message should relate to AccessControl

  Scenario: Admin cannot call notifyRewardAmount unless granted operator role
    Given an admin has the DEFAULT_ADMIN_ROLE but not the OPERATOR_ROLE
    When the admin attempts to call "notifyRewardAmount"
    Then the transaction should revert
    And the error message should relate to AccessControl
    When the admin grants the OPERATOR_ROLE to themselves
    And the admin attempts to call "notifyRewardAmount" again
    Then the transaction should not revert due to AccessControl