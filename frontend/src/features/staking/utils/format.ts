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

function formatReadableNumber(value: number, maxFractionDigits = 8): string {
  return new Intl.NumberFormat('en-US', {
    maximumFractionDigits: maxFractionDigits,
  }).format(value)
}

export function formatRewardAmount(value?: number, symbol = ''): string {
  if (!Number.isFinite(value)) {
    return '--'
  }

  return `${formatReadableNumber(value!)} ${symbol}`.trim()
}

export function formatRewardRate(value?: number, symbol = ''): string {
  if (!Number.isFinite(value)) {
    return '--'
  }

  return `${formatReadableNumber(value!)} ${symbol}/秒`.trim()
}

export function formatCountdown(periodFinish: bigint, chainTimestamp?: bigint): string {
  if (chainTimestamp === undefined) {
    return '--'
  }
  if (periodFinish <= chainTimestamp) {
    return '已结束'
  }

  const totalSeconds = Number(periodFinish - chainTimestamp)
  if (!Number.isFinite(totalSeconds)) {
    return '--'
  }

  const days = Math.floor(totalSeconds / 86_400)
  const hours = Math.floor((totalSeconds % 86_400) / 3_600)
  const minutes = Math.floor((totalSeconds % 3_600) / 60)

  return `${days}天 ${hours}小时 ${minutes}分钟`
}

export const BPS_BASE = 10_000

export function formatBps(value: bigint, maxFractionDigits = 2): string {
  const percent = Number(value) / 100
  if (!Number.isFinite(percent)) {
    return '--'
  }

  return `${new Intl.NumberFormat('en-US', { maximumFractionDigits: maxFractionDigits }).format(percent)}%`
}

export function formatDuration(seconds: bigint): string {
  const total = Number(seconds)
  if (!Number.isFinite(total) || total <= 0) {
    return '活期'
  }

  const days = Math.floor(total / 86_400)
  if (days > 0) {
    return `${days} 天`
  }

  const hours = Math.floor(total / 3_600)
  if (hours > 0) {
    return `${hours} 小时`
  }

  return `${Math.floor(total / 60)} 分钟`
}

export function formatUnlockTime(unlockTime: bigint, chainTimestamp?: bigint): string {
  if (unlockTime === 0n) {
    return '活期'
  }

  const unlockMs = Number(unlockTime) * 1000
  const label = new Date(unlockMs).toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
  })

  return chainTimestamp !== undefined && isMatured(unlockTime, chainTimestamp)
    ? `${label}（已到期）`
    : label
}

export function isMatured(unlockTime: bigint, chainTimestamp: bigint): boolean {
  return unlockTime === 0n || unlockTime <= chainTimestamp
}
