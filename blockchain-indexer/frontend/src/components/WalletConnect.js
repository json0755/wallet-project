import React from 'react';
import { Button, Box, Typography, Chip } from '@mui/material';
import { AccountBalanceWallet, Link, LinkOff } from '@mui/icons-material';
import { useWallet } from '../contexts/WalletContext';

const WalletConnect = () => {
  const {
    account,
    chainId,
    isConnecting,
    isConnected,
    isAnvilNetwork,
    connectWallet,
    disconnectWallet,
    switchToAnvilNetwork,
  } = useWallet();

  // 格式化地址显示
  const formatAddress = (address) => {
    if (!address) return '';
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // 获取网络状态颜色
  const getNetworkChipColor = () => {
    if (!isConnected) return 'default';
    return isAnvilNetwork ? 'success' : 'warning';
  };

  // 获取网络显示文本
  const getNetworkText = () => {
    if (!isConnected) return '未连接';
    if (isAnvilNetwork) return 'Anvil本地网络';
    return `Chain ID: ${chainId}`;
  };

  if (!isConnected) {
    return (
      <Button
        variant="contained"
        startIcon={<AccountBalanceWallet />}
        onClick={connectWallet}
        disabled={isConnecting}
        sx={{
          borderRadius: '20px',
          textTransform: 'none',
          fontWeight: 600,
        }}
      >
        {isConnecting ? '连接中...' : '连接钱包'}
      </Button>
    );
  }

  return (
    <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
      {/* 网络状态指示器 */}
      <Chip
        icon={isAnvilNetwork ? <Link /> : <LinkOff />}
        label={getNetworkText()}
        color={getNetworkChipColor()}
        size="small"
        onClick={!isAnvilNetwork ? switchToAnvilNetwork : undefined}
        sx={{
          cursor: !isAnvilNetwork ? 'pointer' : 'default',
          '&:hover': {
            backgroundColor: !isAnvilNetwork ? 'warning.light' : undefined,
          },
        }}
      />

      {/* 账户信息 */}
      <Box sx={{ display: 'flex', flexDirection: 'column', alignItems: 'flex-end' }}>
        <Typography variant="body2" sx={{ fontWeight: 600 }}>
          {formatAddress(account)}
        </Typography>
        <Button
          size="small"
          onClick={disconnectWallet}
          sx={{
            minWidth: 'auto',
            padding: '2px 8px',
            fontSize: '0.75rem',
            textTransform: 'none',
            color: 'text.secondary',
          }}
        >
          断开连接
        </Button>
      </Box>
    </Box>
  );
};

export default WalletConnect;