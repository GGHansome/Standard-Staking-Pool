import { useState } from 'react'
import { Button, Card, Popconfirm, Space, Table, Tag, Tooltip, Typography } from 'antd'
import type { ColumnsType } from 'antd/es/table'
import { formatBps, formatTokenAmount, formatUnlockTime, isMatured } from '../../utils/format'
import type { DepositItem } from '../../types'
import { DepositRewardSummary } from './DepositRewardSummary'
import type { DepositTableProps } from './interface'

export function DepositTable({
  deposits,
  chainTimestamp,
  loading,
  disabled,
  penaltyRate,
  rewardTokenSymbol,
  rewardTokenDecimals,
  stakingTokenSymbol,
  stakingTokenDecimals,
  onWithdraw,
  onWithdrawMultiple,
  onExit,
}: DepositTableProps) {
  const [selectedKeys, setSelectedKeys] = useState<bigint[]>([])

  const columns: ColumnsType<DepositItem> = [
    {
      title: '仓位 ID',
      dataIndex: 'depositId',
      render: (value: bigint) => `#${value.toString()}`,
    },
    {
      title: '本金',
      dataIndex: 'amount',
      render: (value: bigint) =>
        `${formatTokenAmount(value, stakingTokenDecimals)} ${stakingTokenSymbol}`,
    },
    {
      title: '锁仓加成',
      dataIndex: 'boostRate',
      render: (value: bigint) => (value > 0n ? formatBps(value) : '活期'),
    },
    {
      title: '到期时间',
      dataIndex: 'unlockTime',
      render: (value: bigint) => {
        const matured =
          chainTimestamp === undefined ? undefined : isMatured(value, chainTimestamp)
        return (
          <Space>
            <span>{formatUnlockTime(value, chainTimestamp)}</span>
            {value > 0n ? (
              <Tag color={matured === undefined ? 'default' : matured ? 'green' : 'orange'}>
                {matured === undefined ? '同步中' : matured ? '可正常退出' : '锁仓中'}
              </Tag>
            ) : null}
          </Space>
        )
      },
    },
    {
      title: '仓位奖励',
      key: 'rewards',
      width: 320,
      render: (_, record) => (
        <DepositRewardSummary
          deposit={record}
          rewardTokenSymbol={rewardTokenSymbol}
          rewardTokenDecimals={rewardTokenDecimals}
        />
      ),
    },
    {
      title: '操作',
      key: 'action',
      render: (_, record) => {
        if (chainTimestamp === undefined) {
          return (
            <Button size="small" disabled>
              时间同步中
            </Button>
          )
        }

        const matured = isMatured(record.unlockTime, chainTimestamp)
        if (matured) {
          return (
            <Button
              size="small"
              disabled={disabled}
              onClick={() => void onWithdraw(record.depositId)}
            >
              退出
            </Button>
          )
        }

        return (
          <Popconfirm
            title="提前退出未到期仓位"
            description={
              <span>
                将扣除本金 {formatBps(penaltyRate)} 作为罚金
                {record.boostForfeitable ? '，且未解锁的锁仓加成奖励将被全部作废' : ''}。是否继续？
              </span>
            }
            okText="确认提前退出"
            cancelText="取消"
            onConfirm={() => void onWithdraw(record.depositId)}
          >
            <Tooltip title="未到期，提前退出会被罚金并作废锁仓加成">
              <Button size="small" danger disabled={disabled}>
                提前退出
              </Button>
            </Tooltip>
          </Popconfirm>
        )
      },
    },
  ]

  const selectedDeposits = deposits.filter((item) => selectedKeys.includes(item.depositId))
  const exitDisabled = disabled || chainTimestamp === undefined
  const hasImmatureInSelection =
    chainTimestamp !== undefined &&
    selectedDeposits.some((item) => !isMatured(item.unlockTime, chainTimestamp))

  return (
    <Card
      title="我的质押仓位"
      extra={
        <Popconfirm
          title="一键退出全部仓位"
          description="将退出所有活跃仓位并领取奖励；未到期仓位会被罚金并作废锁仓加成。"
          okText="确认退出全部"
          cancelText="取消"
          onConfirm={() => void onExit()}
          disabled={exitDisabled || deposits.length === 0}
        >
          <Button danger disabled={exitDisabled || deposits.length === 0}>
            一键退出全部
          </Button>
        </Popconfirm>
      }
    >
      <Space direction="vertical" size="middle" style={{ width: '100%' }}>
        <Space wrap>
          <Popconfirm
            title="批量退出所选仓位"
            description={
              hasImmatureInSelection
                ? '所选包含未到期仓位，提前退出会被罚金并作废锁仓加成。是否继续？'
                : '退出所选仓位并领取奖励。'
            }
            okText="确认批量退出"
            cancelText="取消"
            disabled={exitDisabled || selectedKeys.length === 0}
            onConfirm={async () => {
              await onWithdrawMultiple(selectedKeys)
              setSelectedKeys([])
            }}
          >
            <Button disabled={exitDisabled || selectedKeys.length === 0}>
              批量退出所选 ({selectedKeys.length})
            </Button>
          </Popconfirm>
          {deposits.length === 0 ? (
            <Typography.Text type="secondary">暂无活跃仓位</Typography.Text>
          ) : null}
        </Space>

        <Table<DepositItem>
          rowKey={(record) => record.depositId.toString()}
          loading={loading}
          dataSource={deposits}
          columns={columns}
          pagination={false}
          size="small"
          rowSelection={{
            selectedRowKeys: selectedKeys.map((key) => key.toString()),
            onChange: (keys) => setSelectedKeys(keys.map((key) => BigInt(key as string))),
          }}
        />
      </Space>
    </Card>
  )
}