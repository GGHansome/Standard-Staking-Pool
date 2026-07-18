import { Alert, Button, Card, Form, Input, Space, Statistic } from 'antd'
import { calculateRequiredRewardAllowance } from '../../utils/contract'
import { formatBps, formatTokenAmount, parseTokenAmount } from '../../utils/format'
import type { OperatorRewardCardProps } from './interface'

type NotifyFormValues = {
  amount: string
}

export function OperatorRewardCard({
  rewardTokenSymbol,
  rewardTokenDecimals,
  rewardTokenAllowance,
  subsidy,
  maxSweepableSubsidy,
  injectedBaseCumulative,
  disabled,
  approveDisabled,
  notifyDisabled,
  onApprove,
  onNotify,
}: OperatorRewardCardProps) {
  const [form] = Form.useForm<NotifyFormValues>()
  const amount = Form.useWatch('amount', form) ?? ''
  const requiredAllowance = (() => {
    try {
      const baseRewardAmount = parseTokenAmount(amount, rewardTokenDecimals)
      return calculateRequiredRewardAllowance({
        baseRewardAmount,
        injectedBaseCumulative,
        maxSubsidyRate: subsidy.maxSubsidyRate,
        maxSweepableSubsidy,
      })
    } catch {
      return undefined
    }
  })()
  const allowanceHint = (() => {
    if (!requiredAllowance) {
      return '输入基础奖励后显示本次所需授权额度'
    }

    const gap =
      requiredAllowance.total > rewardTokenAllowance
        ? requiredAllowance.total - rewardTokenAllowance
        : 0n
    const amountLabel = (value: bigint) =>
      `${formatTokenAmount(value, rewardTokenDecimals)} ${rewardTokenSymbol}`

    return [
      `本次需授权 ${amountLabel(requiredAllowance.total)}`,
      `其中补贴补缴 ${amountLabel(requiredAllowance.subsidyTopUp)}`,
      gap > 0n ? `尚缺 ${amountLabel(gap)}` : '当前额度已足够',
    ].join('；')
  })()

  const approve = async () => {
    const values = await form.validateFields()
    await onApprove(values.amount)
  }

  const notify = async () => {
    const values = await form.validateFields()
    await onNotify(values.amount)
  }

  return (
    <Card title="Operator 奖励注入">
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Alert
          showIcon
          type="info"
          message={`注入基础奖励时，系统会按最大补贴率 ${formatBps(subsidy.maxSubsidyRate)} 自动补足补贴备付金，需确保授权额度覆盖基础奖励与补贴补缴之和。`}
        />
        <Space size="large" wrap>
          <Statistic
            title="当前授权额度"
            value={`${formatTokenAmount(rewardTokenAllowance, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
          <Statistic
            title="补贴储备"
            value={`${formatTokenAmount(subsidy.subsidyReserve, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
          <Statistic
            title="已确认补贴负债"
            value={`${formatTokenAmount(subsidy.totalPendingSubsidy, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
          <Statistic
            title="未结算最大补贴负债"
            value={`${formatTokenAmount(subsidy.unsettledMaxSubsidyLiability, rewardTokenDecimals)} ${rewardTokenSymbol}`}
          />
        </Space>
        <Form form={form} layout="vertical">
          <Form.Item
            label={`基础奖励数量 (${rewardTokenSymbol})`}
            name="amount"
            extra={allowanceHint}
            rules={[{ required: true, message: '请输入注入数量' }]}
          >
            <Input inputMode="decimal" placeholder="0.0" disabled={disabled} />
          </Form.Item>
          <Space wrap>
            <Button disabled={disabled || approveDisabled} onClick={() => void approve()}>
              授权奖励代币
            </Button>
            <Button
              type="primary"
              disabled={disabled || notifyDisabled}
              onClick={() => void notify()}
            >
              注入奖励
            </Button>
          </Space>
        </Form>
      </Space>
    </Card>
  )
}