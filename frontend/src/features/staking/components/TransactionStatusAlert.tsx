import { useEffect } from 'react'
import { App } from 'antd'
import type { Hash } from 'viem'

type TransactionReceiptStatus = 'success' | 'reverted'

type TransactionStatusAlertProps = {
  hash?: Hash
  isConfirming: boolean
  isConfirmed: boolean
  receiptStatus?: TransactionReceiptStatus
}

export function TransactionStatusAlert({
  hash,
  isConfirming,
  isConfirmed,
  receiptStatus,
}: TransactionStatusAlertProps) {
  const { message } = App.useApp()

  useEffect(() => {
    const key = 'transaction-status'

    if (!hash) {
      return
    }

    if (isConfirming) {
      message.open({
        key,
        type: 'loading',
        content: '交易确认中',
        duration: 0,
      })
      return
    }

    if (receiptStatus === 'reverted') {
      message.open({
        key,
        type: 'error',
        content: '交易执行失败，请检查授权、余额或合约限制',
        duration: 4,
      })
      return
    }

    if (isConfirmed && receiptStatus === 'success') {
      message.open({
        key,
        type: 'success',
        content: '交易已确认',
        duration: 3,
      })
    }
  }, [hash, isConfirmed, isConfirming, message, receiptStatus])

  return null
}
