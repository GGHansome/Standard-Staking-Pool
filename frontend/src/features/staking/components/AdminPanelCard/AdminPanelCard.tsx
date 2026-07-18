import { PauseCircleOutlined, PlayCircleOutlined } from '@ant-design/icons'
import {
  Alert,
  Button,
  Card,
  Col,
  Form,
  Input,
  Row,
  Space,
  Statistic,
  Tag,
  Typography,
} from 'antd'
import { formatBps, formatTokenAmount } from '../../utils/format'
import type { AdminPanelCardProps } from './interface'

type TreasuryFormValues = { treasury: string }
type SweepSubsidyFormValues = { to: string; rawAmount: string }
type SweepExpiredFormValues = { to: string }
type RecoverFormValues = { tokenAddress: string; rawAmount: string }
type OperatorFormValues = { account: string }

export function AdminPanelCard({
  isPaused,
  disabled,
  subsidy,
  penalty,
  baseRewardReserve,
  maxSweepableSubsidy,
  rewardTokenSymbol,
  rewardTokenDecimals,
  onPause,
  onUnpause,
  onSetTreasury,
  onSweepSubsidy,
  onSweepExpiredBaseReward,
  onRecoverToken,
  onGrantOperatorRole,
}: AdminPanelCardProps) {
  const [treasuryForm] = Form.useForm<TreasuryFormValues>()
  const [sweepSubsidyForm] = Form.useForm<SweepSubsidyFormValues>()
  const [sweepExpiredForm] = Form.useForm<SweepExpiredFormValues>()
  const [recoverForm] = Form.useForm<RecoverFormValues>()
  const [operatorForm] = Form.useForm<OperatorFormValues>()

  const setTreasury = async () => {
    const values = await treasuryForm.validateFields()
    await onSetTreasury(values.treasury)
  }

  const sweepSubsidy = async () => {
    const values = await sweepSubsidyForm.validateFields()
    await onSweepSubsidy(values.to, values.rawAmount)
  }

  const sweepExpired = async () => {
    const values = await sweepExpiredForm.validateFields()
    await onSweepExpiredBaseReward(values.to)
  }

  const recover = async () => {
    const values = await recoverForm.validateFields()
    await onRecoverToken(values.tokenAddress, values.rawAmount)
  }

  const grantOperatorRole = async () => {
    const values = await operatorForm.validateFields()
    await onGrantOperatorRole(values.account)
  }

  return (
    <Card
      title="Admin 管理面板"
      extra={<Tag color={isPaused ? 'red' : 'green'}>{isPaused ? '已暂停' : '运行中'}</Tag>}
    >
      <Space direction="vertical" size={24} style={{ width: '100%' }}>
        <Typography.Title level={5} style={{ margin: 0 }}>
          资金与风险概览
        </Typography.Title>
        <Row gutter={[16, 20]}>
          <Col xs={24} sm={12} lg={8} xl={4}>
            <Statistic
              title="基础奖励储备"
              value={formatTokenAmount(baseRewardReserve, rewardTokenDecimals)}
              suffix={rewardTokenSymbol}
            />
          </Col>
          <Col xs={24} sm={12} lg={8} xl={4}>
            <Statistic
              title="补贴储备"
              value={formatTokenAmount(subsidy.subsidyReserve, rewardTokenDecimals)}
              suffix={rewardTokenSymbol}
            />
          </Col>
          <Col xs={24} sm={12} lg={8} xl={4}>
            <Statistic
              title="已确认补贴负债"
              value={formatTokenAmount(subsidy.totalPendingSubsidy, rewardTokenDecimals)}
              suffix={rewardTokenSymbol}
            />
          </Col>
          <Col xs={24} sm={12} lg={8} xl={4}>
            <Statistic
              title="可清扫补贴上限"
              value={formatTokenAmount(maxSweepableSubsidy, rewardTokenDecimals)}
              suffix={rewardTokenSymbol}
            />
          </Col>
          <Col xs={24} sm={12} lg={8} xl={4}>
            <Statistic
              title="未结算最大补贴负债"
              value={formatTokenAmount(subsidy.unsettledMaxSubsidyLiability, rewardTokenDecimals)}
              suffix={rewardTokenSymbol}
            />
          </Col>
          <Col xs={24} sm={12} lg={8} xl={4}>
            <Statistic title="提前退出罚金率" value={formatBps(penalty.penaltyRate)} />
          </Col>
        </Row>

        <Card size="small" title="池控制">
          <Row align="middle" justify="space-between" gutter={[16, 16]}>
            <Col flex="auto">
              <Typography.Text type="secondary">
                {isPaused
                  ? '合约当前已暂停，可恢复受暂停限制的操作。'
                  : '紧急情况下可暂停质押、奖励注入和补贴清扫。'}
              </Typography.Text>
            </Col>
            <Col>
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
            </Col>
          </Row>
        </Card>

        <Typography.Title level={5} style={{ margin: 0 }}>
          资金管理
        </Typography.Title>
        <Row gutter={[16, 16]} align="stretch">
          <Col xs={24} lg={12} xl={8}>
            <Card size="small" title="金库配置" style={{ height: '100%' }}>
              <Typography.Text type="secondary">当前金库地址</Typography.Text>
              <Typography.Paragraph
                copyable
                ellipsis={{ rows: 1, tooltip: penalty.treasury }}
                style={{ margin: '4px 0 16px' }}
              >
                {penalty.treasury}
              </Typography.Paragraph>
              <Form form={treasuryForm} layout="vertical">
                <Form.Item
                  label="新金库地址"
                  name="treasury"
                  rules={[{ required: true, message: '请输入金库地址' }]}
                >
                  <Input placeholder="0x..." disabled={disabled} />
                </Form.Item>
                <Button
                  type="primary"
                  disabled={disabled}
                  onClick={() => void setTreasury()}
                >
                  更新金库地址
                </Button>
              </Form>
            </Card>
          </Col>

          <Col xs={24} lg={12} xl={8}>
            <Card size="small" title="补贴清扫" style={{ height: '100%' }}>
              <Typography.Paragraph type="secondary">
                仅可转出超过当前与最大潜在负债后的可清扫余额。
              </Typography.Paragraph>
              <Form form={sweepSubsidyForm} layout="vertical">
                <Form.Item
                  label="接收地址"
                  name="to"
                  rules={[{ required: true, message: '请输入接收地址' }]}
                >
                  <Input placeholder="0x..." disabled={disabled} />
                </Form.Item>
                <Form.Item
                  label="清扫数量（最小单位）"
                  name="rawAmount"
                  rules={[{ required: true, message: '请输入最小单位数量' }]}
                >
                  <Input
                    inputMode="numeric"
                    placeholder="1000000000000000000"
                    disabled={disabled}
                  />
                </Form.Item>
                <Button disabled={disabled} onClick={() => void sweepSubsidy()}>
                  清扫沉淀补贴
                </Button>
              </Form>
            </Card>
          </Col>

          <Col xs={24} lg={12} xl={8}>
            <Card size="small" title="过期奖励回收" style={{ height: '100%' }}>
              <Alert
                showIcon
                type="warning"
                message="仅奖励周期结束且池内无活跃质押时可执行"
                style={{ marginBottom: 16 }}
              />
              <Form form={sweepExpiredForm} layout="vertical">
                <Form.Item
                  label="接收地址"
                  name="to"
                  rules={[{ required: true, message: '请输入接收地址' }]}
                >
                  <Input placeholder="0x..." disabled={disabled} />
                </Form.Item>
                <Button danger disabled={disabled} onClick={() => void sweepExpired()}>
                  回收过期基础奖励
                </Button>
              </Form>
            </Card>
          </Col>
        </Row>

        <Typography.Title level={5} style={{ margin: 0 }}>
          权限与资产救援
        </Typography.Title>
        <Row gutter={[16, 16]} align="stretch">
          <Col xs={24} lg={12}>
            <Card size="small" title="Operator 权限" style={{ height: '100%' }}>
              <Typography.Paragraph type="secondary">
                授权目标地址注入新的基础奖励并补足补贴储备。
              </Typography.Paragraph>
              <Form form={operatorForm} layout="vertical">
                <Form.Item
                  label="Operator 钱包地址"
                  name="account"
                  rules={[{ required: true, message: '请输入要添加的 Operator 地址' }]}
                >
                  <Input placeholder="0x..." disabled={disabled} />
                </Form.Item>
                <Button
                  type="primary"
                  disabled={disabled}
                  onClick={() => void grantOperatorRole()}
                >
                  添加 Operator
                </Button>
              </Form>
            </Card>
          </Col>

          <Col xs={24} lg={12}>
            <Card size="small" title="误转 ERC20 救援" style={{ height: '100%' }}>
              <Alert
                showIcon
                type="warning"
                message="质押代币与奖励代币不可通过此入口回收"
                style={{ marginBottom: 16 }}
              />
              <Form form={recoverForm} layout="vertical">
                <Form.Item
                  label="误转 ERC20 地址"
                  name="tokenAddress"
                  rules={[{ required: true, message: '请输入代币地址' }]}
                >
                  <Input placeholder="0x..." disabled={disabled} />
                </Form.Item>
                <Form.Item
                  label="救援数量（最小单位）"
                  name="rawAmount"
                  rules={[{ required: true, message: '请输入最小单位数量' }]}
                >
                  <Input
                    inputMode="numeric"
                    placeholder="1000000000000000000"
                    disabled={disabled}
                  />
                </Form.Item>
                <Button danger disabled={disabled} onClick={() => void recover()}>
                  救援误转代币
                </Button>
              </Form>
            </Card>
          </Col>
        </Row>
      </Space>
    </Card>
  )
}