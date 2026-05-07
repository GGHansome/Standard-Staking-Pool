import { BaseError } from 'wagmi'

type ReadResult = {
  status?: string
  result?: unknown
}

export function readAt<T>(data: readonly unknown[] | undefined, index: number, fallback: T): T {
  const item = data?.[index] as ReadResult | undefined
  return item?.status === 'success' && item.result !== undefined ? (item.result as T) : fallback
}

export function getErrorMessage(error: unknown): string {
  if (error instanceof BaseError) {
    return error.shortMessage || error.message
  }

  if (error instanceof Error) {
    return error.message
  }

  return '交易执行失败'
}
