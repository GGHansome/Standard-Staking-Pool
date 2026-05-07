import { DisconnectOutlined, WalletOutlined } from '@ant-design/icons'
import { Button, Card, Space, Tag, Typography } from 'antd'
import type { Address } from 'viem'
import type { WalletConnectorOption } from '../types'
import { formatAddress } from '../utils/format'

type WalletPanelProps = {
  address?: Address
  chainId?: number
  isConnected: boolean
  isPending: boolean
  connectors: WalletConnectorOption[]
  onConnect: (connectorId: string) => Promise<void>
  onDisconnect: () => Promise<void>
}

export function WalletPanel({
  address,
  chainId,
  isConnected,
  isPending,
  connectors,
  onConnect,
  onDisconnect,
}: WalletPanelProps) {
  return (
    <Card>
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Space align="center" wrap>
          <WalletOutlined />
          <Typography.Text strong>
            {isConnected ? formatAddress(address) : '未连接钱包'}
          </Typography.Text>
          {chainId ? <Tag color="blue">Chain {chainId}</Tag> : null}
        </Space>
        {isConnected ? (
          <Button
            icon={<DisconnectOutlined />}
            onClick={() => void onDisconnect()}
            disabled={isPending}
          >
            断开连接
          </Button>
        ) : (
          <Space wrap>
            {connectors.map((connector) => (
              <Button
                key={connector.id}
                type="primary"
                icon={<WalletOutlined />}
                onClick={() => void onConnect(connector.id)}
                loading={isPending}
              >
                连接 {connector.name}
              </Button>
            ))}
          </Space>
        )}
      </Space>
    </Card>
  )
}
