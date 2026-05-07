import { formatUnits, parseUnits } from 'viem'

export const REWARD_RATE_PRECISION = 18
export const SECONDS_PER_YEAR = 31_536_000

export function formatTokenAmount(
  value: bigint,
  decimals: number,
  maxFractionDigits = 4,
): string {
  const raw = formatUnits(value, decimals)
  const numeric = Number(raw)

  if (!Number.isFinite(numeric)) {
    return raw
  }

  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: maxFractionDigits,
  }).format(numeric)
}

export function formatAddress(address?: string): string {
  if (!address) {
    return '--'
  }

  return `${address.slice(0, 6)}...${address.slice(-4)}`
}

export function parseTokenAmount(value: string, decimals: number): bigint {
  const normalized = value.trim()
  if (!normalized) {
    throw new Error('请输入数量')
  }

  const parsed = parseUnits(normalized, decimals)
  if (parsed <= 0n) {
    throw new Error('数量必须大于 0')
  }

  return parsed
}

export function parsePositiveBigInt(value: string): bigint {
  const normalized = value.trim()
  if (!/^\d+$/.test(normalized)) {
    throw new Error('请输入正整数')
  }

  const parsed = BigInt(normalized)
  if (parsed <= 0n) {
    throw new Error('数值必须大于 0')
  }

  return parsed
}

export function formatApr(apr?: number): string {
  if (!Number.isFinite(apr)) {
    return '--'
  }

  return `${apr!.toFixed(2)}%`
}

export function formatCountdown(periodFinish: bigint): string {
  const finishMs = Number(periodFinish) * 1000
  if (!Number.isFinite(finishMs) || finishMs <= Date.now()) {
    return '已结束'
  }

  const totalSeconds = Math.floor((finishMs - Date.now()) / 1000)
  const days = Math.floor(totalSeconds / 86_400)
  const hours = Math.floor((totalSeconds % 86_400) / 3_600)
  const minutes = Math.floor((totalSeconds % 3_600) / 60)

  return `${days}天 ${hours}小时 ${minutes}分钟`
}
