import { App } from 'antd'
import { useConnection } from 'wagmi'
import { WalletPanel } from '../../components/WalletPanel'
import { getErrorMessage } from '../../utils/contract'
import { useWalletMutation } from './server-store/mutation'

export function WalletContainer() {
  const { message } = App.useApp()
  const connection = useConnection()
  const { connectors, isPending, connect, disconnect } = useWalletMutation()

  const connectWallet = async (connectorId: string) => {
    try {
      await connect(connectorId)
    } catch (error) {
      message.error(getErrorMessage(error))
    }
  }

  return (
    <WalletPanel
      address={connection.address}
      chainId={connection.chainId}
      isConnected={connection.isConnected}
      isPending={isPending}
      connectors={connectors}
      onConnect={connectWallet}
      onDisconnect={disconnect}
    />
  )
}