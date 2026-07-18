import { useConnect, useDisconnect } from 'wagmi'

/**
 * 钱包连接/断开的 mutation：封装 wagmi connector 选择与连接动作，
 * 向展示组件暴露纯回调与连接器列表。
 */
export function useWalletMutation() {
  const { connectors, connectAsync, isPending } = useConnect()
  const { disconnectAsync } = useDisconnect()

  const connect = async (connectorId: string) => {
    const connector = connectors.find((item) => item.id === connectorId)
    if (!connector) {
      throw new Error('未找到钱包连接器')
    }

    await connectAsync({ connector })
  }

  const disconnect = async () => {
    await disconnectAsync()
  }

  return {
    connectors: connectors.map((connector) => ({ id: connector.id, name: connector.name })),
    isPending,
    connect,
    disconnect,
  }
}