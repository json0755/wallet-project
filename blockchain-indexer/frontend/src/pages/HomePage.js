import React, { useState, useEffect } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  Grid,
  Button,
  Alert,
  CircularProgress,
  Chip,
} from '@mui/material';
import {
  AccountBalanceWallet,
  TrendingUp,
  Storage,
  Speed,
  Refresh,
} from '@mui/icons-material';
import { useWallet } from '../contexts/WalletContext';
import api from '../utils/api';

const HomePage = () => {
  const { isConnected, isAnvilNetwork, account } = useWallet();
  const [stats, setStats] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  // 获取系统统计数据
  const fetchStats = async () => {
    try {
      setLoading(true);
      setError(null);
      const response = await api.get('/api/stats');
      setStats(response.data);
    } catch (err) {
      console.error('获取统计数据失败:', err);
      setError('获取统计数据失败，请检查后端服务是否正常运行');
    } finally {
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  const StatCard = ({ title, value, icon, color = 'primary' }) => (
    <Card elevation={2}>
      <CardContent>
        <Box sx={{ display: 'flex', alignItems: 'center', mb: 2 }}>
          <Box
            sx={{
              p: 1,
              borderRadius: 2,
              backgroundColor: `${color}.light`,
              color: `${color}.contrastText`,
              mr: 2,
            }}
          >
            {icon}
          </Box>
          <Typography variant="h6" component="div">
            {title}
          </Typography>
        </Box>
        <Typography variant="h4" component="div" sx={{ fontWeight: 'bold' }}>
          {value}
        </Typography>
      </CardContent>
    </Card>
  );

  return (
    <Box>
      {/* 页面标题 */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          🏠 区块链数据索引器
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          实时索引Anvil本地网络的ERC20 Transfer事件
        </Typography>
      </Box>

      {/* 网络状态提示 */}
      <Box sx={{ mb: 3 }}>
        {!isConnected ? (
          <Alert severity="info" sx={{ mb: 2 }}>
            <Typography variant="body1">
              请连接MetaMask钱包以获得完整功能体验
            </Typography>
          </Alert>
        ) : !isAnvilNetwork ? (
          <Alert severity="warning" sx={{ mb: 2 }}>
            <Typography variant="body1">
              请切换到Anvil本地网络 (Chain ID: 31337) 以使用完整功能
            </Typography>
          </Alert>
        ) : (
          <Alert severity="success" sx={{ mb: 2 }}>
            <Box sx={{ display: 'flex', alignItems: 'center', gap: 1 }}>
              <Typography variant="body1">
                已连接到Anvil本地网络
              </Typography>
              <Chip
                label={`账户: ${account?.slice(0, 6)}...${account?.slice(-4)}`}
                size="small"
                color="success"
                variant="outlined"
              />
            </Box>
          </Alert>
        )}
      </Box>

      {/* 统计数据卡片 */}
      <Box sx={{ mb: 4 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', mb: 3 }}>
          <Typography variant="h5" component="h2">
            📊 系统统计
          </Typography>
          <Button
            startIcon={<Refresh />}
            onClick={fetchStats}
            disabled={loading}
            variant="outlined"
            size="small"
          >
            刷新数据
          </Button>
        </Box>

        {loading ? (
          <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
            <CircularProgress />
          </Box>
        ) : error ? (
          <Alert severity="error">
            {error}
          </Alert>
        ) : (
          <Grid container spacing={3}>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="总交易数"
                value={stats?.totalTransactions?.toLocaleString() || '0'}
                icon={<TrendingUp />}
                color="primary"
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="已索引区块"
                value={`${stats?.startBlock || 0} - ${stats?.endBlock || 0}`}
                icon={<Storage />}
                color="secondary"
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="支持代币"
                value={stats?.supportedTokens || '3'}
                icon={<AccountBalanceWallet />}
                color="success"
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="索引状态"
                value={stats?.indexerStatus || '运行中'}
                icon={<Speed />}
                color="info"
              />
            </Grid>
          </Grid>
        )}
      </Box>

      {/* 功能介绍 */}
      <Card elevation={1}>
        <CardContent>
          <Typography variant="h6" gutterBottom>
            🚀 主要功能
          </Typography>
          <Grid container spacing={2}>
            <Grid item xs={12} md={4}>
              <Box sx={{ p: 2 }}>
                <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                  📡 实时数据索引
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  自动监听Anvil网络上的ERC20 Transfer事件，实时更新交易数据
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={12} md={4}>
              <Box sx={{ p: 2 }}>
                <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                  🔍 交易查询
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  支持按地址查询交易记录，提供分页和筛选功能
                </Typography>
              </Box>
            </Grid>
            <Grid item xs={12} md={4}>
              <Box sx={{ p: 2 }}>
                <Typography variant="subtitle1" gutterBottom sx={{ fontWeight: 'bold' }}>
                  💼 钱包集成
                </Typography>
                <Typography variant="body2" color="text.secondary">
                  集成MetaMask钱包，支持网络切换和消息签名
                </Typography>
              </Box>
            </Grid>
          </Grid>
        </CardContent>
      </Card>
    </Box>
  );
};

export default HomePage;