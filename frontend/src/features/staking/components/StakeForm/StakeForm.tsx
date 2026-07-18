import { Alert, Button, Card, Form, Input, Select, Space, Typography } from 'antd'
import { formatAddress, formatBps, formatDuration } from '../../utils/format'
import type { StakeFormProps, StakeFormValues } from './interface'

export function StakeForm({
  tokenSymbol,
  lockTiers,
  isRewardPeriodActive,
  hasSetInviter,
  boundInviter,
  disabled,
  approveDisabled,
  stakeDisabled,
  onApprove,
  onStake,
}: StakeFormProps) {
  const [form] = Form.useForm<StakeFormValues>()

  const lockOptions = [
    { label: '活期（0% 加成）', value: '0' },
    ...lockTiers.map((tier) => ({
      label: `${formatDuration(tier.duration)}（${formatBps(tier.boostRate)} 加成）`,
      value: tier.duration.toString(),
    })),
  ]

  const approve = async () => {
    const values = await form.validateFields(['amount'])
    await onApprove(values.amount)
  }

  const stake = async () => {
    const values = await form.validateFields()
    await onStake({
      amount: values.amount,
      lockDuration: values.lockDuration ?? '0',
      inviter: hasSetInviter ? '' : (values.inviter ?? '').trim(),
    })
  }

  return (
    <Card title="质押">
      <Form
        form={form}
        layout="vertical"
        initialValues={{ lockDuration: '0' }}
      >
        <Form.Item
          label={`数量 (${tokenSymbol})`}
          name="amount"
          rules={[{ required: true, message: '请输入数量' }]}
        >
          <Input inputMode="decimal" placeholder="0.0" disabled={disabled} />
        </Form.Item>

        <Form.Item label="锁仓档位" name="lockDuration">
          <Select options={lockOptions} disabled={disabled} />
        </Form.Item>

        {hasSetInviter ? (
          <Form.Item label="邀请人">
            <Typography.Text type="secondary">
              {boundInviter && boundInviter !== '0x0000000000000000000000000000000000000000'
                ? `已绑定邀请人 ${formatAddress(boundInviter)}`
                : '已确认无上级，邀请关系不可再修改'}
            </Typography.Text>
          </Form.Item>
        ) : (
          <Form.Item
            label="邀请人地址（仅首次质押可填，可留空表示无上级）"
            name="inviter"
          >
            <Input placeholder="0x...（可留空）" disabled={disabled} />
          </Form.Item>
        )}

        {!isRewardPeriodActive ? (
          <Alert
            showIcon
            type="info"
            style={{ marginBottom: 16 }}
            message="当前奖励周期未激活，仅可创建活期质押，锁仓档位暂不开放。"
          />
        ) : null}

        <Space wrap>
          <Button disabled={disabled || approveDisabled} onClick={() => void approve()}>
            先授权
          </Button>
          <Button
            type="primary"
            disabled={disabled || stakeDisabled}
            onClick={() => void stake()}
          >
            质押入池
          </Button>
        </Space>
      </Form>
    </Card>
  )
}