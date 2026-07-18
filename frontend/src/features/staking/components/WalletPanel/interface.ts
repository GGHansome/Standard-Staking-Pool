import type { Address } from 'viem'
import type { WalletConnectorOption } from '../../types'

export type WalletPanelProps = {
  address?: Address
  chainId?: number
  isConnected: boolean
  isPending: boolean
  connectors: WalletConnectorOption[]
  onConnect: (connectorId: string) => Promise<void>
  onDisconnect: () => Promise<void>
}