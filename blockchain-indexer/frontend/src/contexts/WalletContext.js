import React, { createContext, useContext, useState, useEffect } from 'react';
import { BrowserProvider } from 'ethers';
import { toast } from 'react-toastify';

const ANVIL_NETWORK = {
  chainId: '0x7A69', // 31337 in hex
  chainName: 'Anvil Local Network',
  nativeCurrency: {
    name: 'Ethereum',
    symbol: 'ETH',
    decimals: 18,
  },
  rpcUrls: ['http://localhost:8545'],
  blockExplorerUrls: null,
};

const WalletContext = createContext();

export const useWallet = () => {
  const context = useContext(WalletContext);
  if (!context) {
    throw new Error('useWallet must be used within a WalletProvider');
  }
  return context;
};

export const WalletProvider = ({ children }) => {
  const [account, setAccount] = useState(null);
  const [provider, setProvider] = useState(null);
  const [signer, setSigner] = useState(null);
  const [chainId, setChainId] = useState(null);
  const [isConnecting, setIsConnecting] = useState(false);
  const [isConnected, setIsConnected] = useState(false);

  // 检查MetaMask是否安装
  const isMetaMaskInstalled = () => {
    return typeof window !== 'undefined' && typeof window.ethereum !== 'undefined';
  };

  // 连接钱包
  const connectWallet = async () => {
    if (!isMetaMaskInstalled()) {
      toast.error('请安装MetaMask钱包');
      return;
    }

    setIsConnecting(true);
    try {
      // 请求账户访问权限
      const accounts = await window.ethereum.request({
        method: 'eth_requestAccounts',
      });

      if (accounts.length > 0) {
            const provider = new BrowserProvider(window.ethereum);
            const signer = await provider.getSigner();
            const network = await provider.getNetwork();

        setProvider(provider);
            setSigner(signer);
        setAccount(accounts[0]);
        setChainId(Number(network.chainId));
        setIsConnected(true);

        // 检查是否连接到正确的网络
        if (Number(network.chainId) !== 31337) {
          toast.warning('请切换到Anvil本地网络 (Chain ID: 31337)');
          await switchToAnvilNetwork();
        } else {
          toast.success('钱包连接成功！');
        }
      }
    } catch (error) {
      console.error('连接钱包失败:', error);
      if (error.code === 4001) {
        toast.error('用户拒绝连接钱包');
      } else {
        toast.error('连接钱包失败，请重试');
      }
    } finally {
      setIsConnecting(false);
    }
  };

  // 断开钱包连接
  const disconnectWallet = () => {
    setAccount(null);
    setProvider(null);
    setSigner(null);
    setChainId(null);
    setIsConnected(false);
    toast.info('钱包已断开连接');
  };

  // 切换到Anvil网络
  const switchToAnvilNetwork = async () => {
    if (!isMetaMaskInstalled()) {
      toast.error('请安装MetaMask钱包');
      return;
    }

    try {
      // 尝试切换到Anvil网络
      await window.ethereum.request({
        method: 'wallet_switchEthereumChain',
        params: [{ chainId: ANVIL_NETWORK.chainId }],
      });
      toast.success('已切换到Anvil本地网络');
    } catch (switchError) {
      // 如果网络不存在，则添加网络
      if (switchError.code === 4902) {
        try {
          await window.ethereum.request({
            method: 'wallet_addEthereumChain',
            params: [ANVIL_NETWORK],
          });
          toast.success('Anvil网络添加成功');
        } catch (addError) {
          console.error('添加网络失败:', addError);
          toast.error('添加Anvil网络失败');
        }
      } else {
        console.error('切换网络失败:', switchError);
        toast.error('切换网络失败');
      }
    }
  };

  // 签名消息
  const signMessage = async (message) => {
    if (!signer) {
      toast.error('请先连接钱包');
      return null;
    }

    try {
      const signature = await signer.signMessage(message);
      toast.success('消息签名成功');
      return signature;
    } catch (error) {
      console.error('签名失败:', error);
      if (error.code === 4001) {
        toast.error('用户拒绝签名');
      } else {
        toast.error('签名失败，请重试');
      }
      return null;
    }
  };

  // 监听账户变化
  useEffect(() => {
    if (!isMetaMaskInstalled()) return;

    const handleAccountsChanged = (accounts) => {
      if (accounts.length === 0) {
        disconnectWallet();
      } else if (accounts[0] !== account) {
        setAccount(accounts[0]);
        toast.info('账户已切换');
      }
    };

    const handleChainChanged = (chainId) => {
      const newChainId = parseInt(chainId, 16);
      setChainId(newChainId);
      
      if (newChainId !== 31337) {
        toast.warning('请切换到Anvil本地网络 (Chain ID: 31337)');
      } else {
        toast.success('已连接到Anvil本地网络');
      }
    };

    const handleDisconnect = () => {
      disconnectWallet();
    };

    window.ethereum.on('accountsChanged', handleAccountsChanged);
    window.ethereum.on('chainChanged', handleChainChanged);
    window.ethereum.on('disconnect', handleDisconnect);

    return () => {
      if (window.ethereum.removeListener) {
        window.ethereum.removeListener('accountsChanged', handleAccountsChanged);
        window.ethereum.removeListener('chainChanged', handleChainChanged);
        window.ethereum.removeListener('disconnect', handleDisconnect);
      }
    };
  }, [account]);

  // 检查是否已连接
  useEffect(() => {
    const checkConnection = async () => {
      if (!isMetaMaskInstalled()) return;

      try {
        const accounts = await window.ethereum.request({
          method: 'eth_accounts',
        });

        if (accounts.length > 0) {
          const provider = new BrowserProvider(window.ethereum);
          const signer = await provider.getSigner();
          const network = await provider.getNetwork();

          setProvider(provider);
          setSigner(signer);
          setAccount(accounts[0]);
          setChainId(Number(network.chainId));
          setIsConnected(true);
        }
      } catch (error) {
        console.error('检查连接状态失败:', error);
      }
    };

    checkConnection();
  }, []);

  const value = {
    account,
    provider,
    signer,
    chainId,
    isConnecting,
    isConnected,
    isMetaMaskInstalled,
    connectWallet,
    disconnectWallet,
    switchToAnvilNetwork,
    signMessage,
    isAnvilNetwork: chainId === 31337,
  };

  return (
    <WalletContext.Provider value={value}>
      {children}
    </WalletContext.Provider>
  );
};

export default WalletContext;