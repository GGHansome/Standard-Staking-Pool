import { createConfig, http, injected } from 'wagmi'
import { defineChain } from 'viem'
import { appConfig } from './contracts'

export const configuredChain = defineChain({
  id: appConfig.chainId,
  name: appConfig.chainName,
  nativeCurrency: {
    name: 'Ether',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: {
    default: {
      http: [appConfig.rpcUrl],
    },
  },
})

export const wagmiConfig = createConfig({
  chains: [configuredChain],
  connectors: [injected()],
  transports: {
    [configuredChain.id]: http(appConfig.rpcUrl),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof wagmiConfig
  }
}
