import { App } from 'antd'
import { useConnect, useConnection, useDisconnect } from 'wagmi'
import { WalletPanel } from '../components/WalletPanel'
import { getErrorMessage } from '../utils/contract'

export function WalletContainer() {
  const { message } = App.useApp()
  const connection = useConnection()
  const { connectors, connectAsync, isPending } = useConnect()
  const { disconnectAsync } = useDisconnect()

  const connectWallet = async (connectorId: string) => {
    const connector = connectors.find((item) => item.id === connectorId)
    if (!connector) {
      message.error('未找到钱包连接器')
      return
    }

    try {
      await connectAsync({ connector })
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
      connectors={connectors.map((connector) => ({
        id: connector.id,
        name: connector.name,
      }))}
      onConnect={connectWallet}
      onDisconnect={disconnectAsync}
    />
  )
}
