'use client';

import React from 'react';
import { WagmiProvider } from 'wagmi';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { ConfigProvider } from 'antd';
import { config } from '../config/wagmi';
import './globals.css';

const queryClient = new QueryClient();

export default function RootLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <html lang="zh">
      <head>
        <title>EIP2612 Token Bank</title>
        <meta name="description" content="基于 Permit2 的无Gas授权存款系统" />
        <meta name="viewport" content="width=device-width, initial-scale=1" />
      </head>
      <body className="bg-gray-50">
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            <ConfigProvider
              theme={{
                token: {
                  colorPrimary: '#1890ff',
                },
              }}
            >
              {children}
            </ConfigProvider>
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}