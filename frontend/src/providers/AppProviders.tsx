import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { App as AntdApp, ConfigProvider, theme } from 'antd'
import type { ReactNode } from 'react'
import { WagmiProvider } from 'wagmi'
import { wagmiConfig } from '../config/wagmi'

const queryClient = new QueryClient()

type AppProvidersProps = {
  children: ReactNode
}

export function AppProviders({ children }: AppProvidersProps) {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <ConfigProvider
          theme={{
            algorithm: theme.defaultAlgorithm,
            token: {
              borderRadius: 12,
              colorPrimary: '#1677ff',
              fontFamily:
                'Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
            },
          }}
        >
          <AntdApp>{children}</AntdApp>
        </ConfigProvider>
      </QueryClientProvider>
    </WagmiProvider>
  )
}
