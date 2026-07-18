import { useEffect } from 'react'
import { App } from 'antd'
import type { TransactionStatusAlertProps } from './interface'

export function TransactionStatusAlert({ status }: TransactionStatusAlertProps) {
  const { message } = App.useApp()

  useEffect(() => {
    const key = 'transaction-status'

    if (status.phase === 'confirming') {
      message.open({ key, type: 'loading', content: '交易确认中', duration: 0 })
      return
    }

    if (status.phase === 'failed') {
      message.open({
        key,
        type: 'error',
        content: '交易执行失败，请检查授权、余额或合约限制',
        duration: 4,
      })
      return
    }

    if (status.phase === 'confirmed') {
      message.open({ key, type: 'success', content: '交易已确认', duration: 3 })
    }
  }, [message, status.phase])

  return null
}