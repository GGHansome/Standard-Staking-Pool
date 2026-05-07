import { CheckCircleOutlined, ClockCircleOutlined } from '@ant-design/icons'
import { Alert } from 'antd'
import type { Hash } from 'viem'

type TransactionStatusAlertProps = {
  hash?: Hash
  error?: string
  isConfirming: boolean
  isConfirmed: boolean
}

export function TransactionStatusAlert({
  hash,
  error,
  isConfirming,
  isConfirmed,
}: TransactionStatusAlertProps) {
  if (!hash && !error) {
    return null
  }

  return (
    <Alert
      showIcon
      type={error ? 'error' : isConfirmed ? 'success' : 'info'}
      icon={isConfirmed ? <CheckCircleOutlined /> : <ClockCircleOutlined />}
      message={
        error
          ? error
          : isConfirming
            ? '交易确认中'
            : isConfirmed
              ? '交易已确认'
              : '交易已提交'
      }
      description={hash ? `交易哈希：${hash}` : undefined}
    />
  )
}
