import { Alert, Layout, Space, Tag, Typography } from 'antd'
import type { ReactNode } from 'react'

type DashboardLayoutProps = {
  isPaused: boolean
  configWarnings: string[]
  children: ReactNode
}

export function DashboardLayout({ isPaused, configWarnings, children }: DashboardLayoutProps) {
  return (
    <Layout className="app-layout">
      <Layout.Header className="app-header">
        <Typography.Title level={3} style={{ margin: 0 }}>
          Standard Staking Pool
        </Typography.Title>
        <Tag color={isPaused ? 'red' : 'green'}>{isPaused ? 'Paused' : 'Active'}</Tag>
      </Layout.Header>
      <Layout.Content className="app-content">
        <Space direction="vertical" size="large" style={{ width: '100%' }}>
          {configWarnings.map((warning) => (
            <Alert key={warning} showIcon type="warning" message={warning} />
          ))}
          {children}
        </Space>
      </Layout.Content>
    </Layout>
  )
}
