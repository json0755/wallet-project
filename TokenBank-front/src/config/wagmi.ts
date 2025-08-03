import { http, createConfig } from 'wagmi';
import { injected, metaMask } from 'wagmi/connectors';
import { defineChain } from 'viem';

// Define Anvil chain
export const anvil = defineChain({
  id: 31337,
  name: 'Anvil',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: {
      http: ['http://127.0.0.1:8545'],
    },
  },
});

// Create wagmi config
export const config = createConfig({
  chains: [anvil],
  connectors: [
    injected(),
    metaMask(),
  ],
  transports: {
    [anvil.id]: http(),
  },
});