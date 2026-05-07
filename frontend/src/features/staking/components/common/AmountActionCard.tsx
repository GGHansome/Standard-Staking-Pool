import { Button, Card, Form, Input, Space } from 'antd'

type AmountFormValues = {
  amount: string
}

type AmountActionCardProps = {
  title: string
  tokenSymbol: string
  primaryLabel: string
  secondaryLabel?: string
  disabled?: boolean
  primaryDisabled?: boolean
  secondaryDisabled?: boolean
  onPrimary: (amount: string) => Promise<void>
  onSecondary?: (amount: string) => Promise<void>
}

export function AmountActionCard({
  title,
  tokenSymbol,
  primaryLabel,
  secondaryLabel,
  disabled,
  primaryDisabled,
  secondaryDisabled,
  onPrimary,
  onSecondary,
}: AmountActionCardProps) {
  const [form] = Form.useForm<AmountFormValues>()

  const submit = async (handler: (amount: string) => Promise<void>) => {
    const values = await form.validateFields()
    await handler(values.amount)
  }

  return (
    <Card title={title}>
      <Form form={form} layout="vertical">
        <Form.Item
          label={`数量 (${tokenSymbol})`}
          name="amount"
          rules={[{ required: true, message: '请输入数量' }]}
        >
          <Input inputMode="decimal" placeholder="0.0" disabled={disabled} />
        </Form.Item>
        <Space wrap>
          {secondaryLabel && onSecondary ? (
            <Button
              disabled={disabled || secondaryDisabled}
              onClick={() => void submit(onSecondary)}
            >
              {secondaryLabel}
            </Button>
          ) : null}
          <Button
            type="primary"
            disabled={disabled || primaryDisabled}
            onClick={() => void submit(onPrimary)}
          >
            {primaryLabel}
          </Button>
        </Space>
      </Form>
    </Card>
  )
}
