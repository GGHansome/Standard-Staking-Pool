import { isAddress, type Address } from 'viem'

const DEFAULT_CHAIN_ID = 31_337
const DEFAULT_CHAIN_NAME = 'Anvil'
const DEFAULT_RPC_URL = 'http://127.0.0.1:8545'

function readString(key: string): string {
  return import.meta.env[key]?.trim() ?? ''
}

function readChainId(): number {
  const value = Number(readString('VITE_CHAIN_ID'))
  return Number.isInteger(value) && value > 0 ? value : DEFAULT_CHAIN_ID
}

function readAddress(key: string): Address | undefined {
  const value = readString(key)
  return isAddress(value) ? value : undefined
}

export const appConfig = {
  chainId: readChainId(),
  chainName: readString('VITE_CHAIN_NAME') || DEFAULT_CHAIN_NAME,
  rpcUrl: readString('VITE_RPC_URL') || DEFAULT_RPC_URL,
  stakingPoolAddress: readAddress('VITE_STAKING_POOL_ADDRESS'),
  stakingTokenCoingeckoId: readString('VITE_STAKING_TOKEN_COINGECKO_ID'),
  rewardTokenCoingeckoId: readString('VITE_REWARD_TOKEN_COINGECKO_ID'),
}

export const missingConfigMessages = [
  !appConfig.stakingPoolAddress ? '请在 .env 中配置 VITE_STAKING_POOL_ADDRESS。' : '',
].filter(Boolean)
