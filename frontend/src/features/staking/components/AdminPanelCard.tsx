import { PauseCircleOutlined, PlayCircleOutlined } from '@ant-design/icons'
import { Button, Card, Form, Input, Space } from 'antd'

type DurationFormValues = {
  seconds: string
}

type RecoverFormValues = {
  tokenAddress: string
  rawAmount: string
}

type AdminPanelCardProps = {
  isPaused: boolean
  disabled: boolean
  onPause: () => Promise<void>
  onUnpause: () => Promise<void>
  onSetRewardsDuration: (seconds: string) => Promise<void>
  onRecoverToken: (tokenAddress: string, rawAmount: string) => Promise<void>
}

export function AdminPanelCard({
  isPaused,
  disabled,
  onPause,
  onUnpause,
  onSetRewardsDuration,
  onRecoverToken,
}: AdminPanelCardProps) {
  const [durationForm] = Form.useForm<DurationFormValues>()
  const [recoverForm] = Form.useForm<RecoverFormValues>()

  const setDuration = async () => {
    const values = await durationForm.validateFields()
    await onSetRewardsDuration(values.seconds)
  }

  const recover = async () => {
    const values = await recoverForm.validateFields()
    await onRecoverToken(values.tokenAddress, values.rawAmount)
  }

  return (
    <Card title="Admin 管理面板">
      <Space direction="vertical" size="large" style={{ width: '100%' }}>
        <Space wrap>
          {isPaused ? (
            <Button
              icon={<PlayCircleOutlined />}
              type="primary"
              disabled={disabled}
              onClick={() => void onUnpause()}
            >
              解除暂停
            </Button>
          ) : (
            <Button
              icon={<PauseCircleOutlined />}
              danger
              disabled={disabled}
              onClick={() => void onPause()}
            >
              暂停合约
            </Button>
          )}
        </Space>
        <Form form={durationForm} layout="vertical">
          <Form.Item
            label="奖励周期(秒)"
            name="seconds"
            rules={[{ required: true, message: '请输入奖励周期秒数' }]}
          >
            <Input inputMode="numeric" placeholder="604800" disabled={disabled || isPaused} />
          </Form.Item>
          <Button
            type="primary"
            disabled={disabled || isPaused}
            onClick={() => void setDuration()}
          >
            设置奖励周期
          </Button>
        </Form>
        <Form form={recoverForm} layout="vertical">
          <Form.Item
            label="误转 ERC20 地址"
            name="tokenAddress"
            rules={[{ required: true, message: '请输入代币地址' }]}
          >
            <Input placeholder="0x..." disabled={disabled} />
          </Form.Item>
          <Form.Item
            label="救援数量(最小单位)"
            name="rawAmount"
            rules={[{ required: true, message: '请输入最小单位数量' }]}
          >
            <Input inputMode="numeric" placeholder="1000000000000000000" disabled={disabled} />
          </Form.Item>
          <Button danger disabled={disabled} onClick={() => void recover()}>
            救援误转代币
          </Button>
        </Form>
      </Space>
    </Card>
  )
}
