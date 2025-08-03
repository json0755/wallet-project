export const CONTRACTS = {
  EIP2612_TOKEN: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512' as `0x${string}`,
  TOKEN_BANK: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0' as `0x${string}`,
  PERMIT2: '0x000000000022D473030F116dDEE9F6B43aC78BA3' as `0x${string}`
};

export const NETWORKS = {
  ANVIL: {
    id: 31337,
    name: 'Anvil',
    rpcUrl: 'http://127.0.0.1:8545',
    nativeCurrency: {
      name: 'Ether',
      symbol: 'ETH',
      decimals: 18
    }
  }
};

// Default configurations
export const DEFAULT_NETWORK = NETWORKS.ANVIL;
export const DEFAULT_CONTRACTS = CONTRACTS;