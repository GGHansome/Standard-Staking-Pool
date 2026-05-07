import { Alert, Button, Card, Space } from 'antd'

type RewardActionsCardProps = {
  rewardTokenSymbol: string
  isPaused: boolean
  disabled: boolean
  claimDisabled: boolean
  exitDisabled: boolean
  onClaim: () => Promise<void>
  onExit: () => Promise<void>
}

export function RewardActionsCard({
  rewardTokenSymbol,
  isPaused,
  disabled,
  claimDisabled,
  exitDisabled,
  onClaim,
  onExit,
}: RewardActionsCardProps) {
  return (
    <Card title="收益与退出">
      <Space wrap>
        <Button
          type="primary"
          disabled={disabled || claimDisabled}
          onClick={() => void onClaim()}
        >
          领取 {rewardTokenSymbol}
        </Button>
        <Button danger disabled={disabled || exitDisabled} onClick={() => void onExit()}>
          一键退出
        </Button>
        {isPaused ? (
          <Alert
            showIcon
            type="warning"
            message="合约暂停中：禁止新增质押，但提取、领取和一键退出仍可使用。"
          />
        ) : null}
      </Space>
    </Card>
  )
}
