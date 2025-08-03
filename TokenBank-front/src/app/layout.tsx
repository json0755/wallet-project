'use client'

import React from 'react'
import { ConfigProvider } from 'antd'
import { WagmiProvider } from 'wagmi'
import { QueryClient, QueryClientProvider } from '@tanstack/react-query'
import { config } from '../config/wagmi'
import './globals.css'

const queryClient = new QueryClient()

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh">
      <body>
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            <ConfigProvider
              theme={{
                token: {
                  colorPrimary: '#1677ff',
                  borderRadius: 8,
                },
              }}
            >
              {children}
            </ConfigProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  )
}