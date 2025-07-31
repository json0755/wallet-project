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
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Chip,
  LinearProgress,
} from '@mui/material';
import {
  Refresh,
  TrendingUp,
  Storage,
  Speed,
  AccountBalanceWallet,
  Timeline,
  DataUsage,
} from '@mui/icons-material';
import api from '../utils/api';
import moment from 'moment';

const StatsPage = () => {
  const [stats, setStats] = useState(null);
  const [tokens, setTokens] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [refreshing, setRefreshing] = useState(false);

  // 获取统计数据
  const fetchStats = async () => {
    try {
      setRefreshing(true);
      setError(null);
      
      const [statsResponse, tokensResponse] = await Promise.all([
        api.get('/api/stats'),
        api.get('/api/tokens'),
      ]);
      
      setStats(statsResponse.data);
      setTokens(tokensResponse.data);
    } catch (err) {
      console.error('获取统计数据失败:', err);
      setError('获取统计数据失败，请检查后端服务是否正常运行');
    } finally {
      setLoading(false);
      setRefreshing(false);
    }
  };

  useEffect(() => {
    fetchStats();
  }, []);

  // 格式化地址显示
  const formatAddress = (address) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // 计算索引进度
  const getIndexingProgress = () => {
    if (!stats || !stats.latestBlock || !stats.endBlock) return 0;
    const progress = (stats.endBlock / stats.latestBlock) * 100;
    return Math.min(progress, 100);
  };

  const StatCard = ({ title, value, subtitle, icon, color = 'primary', progress }) => (
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
          <Box sx={{ flexGrow: 1 }}>
            <Typography variant="h6" component="div">
              {title}
            </Typography>
            {subtitle && (
              <Typography variant="body2" color="text.secondary">
                {subtitle}
              </Typography>
            )}
          </Box>
        </Box>
        <Typography variant="h4" component="div" sx={{ fontWeight: 'bold', mb: 1 }}>
          {value}
        </Typography>
        {progress !== undefined && (
          <Box sx={{ mt: 2 }}>
            <LinearProgress
              variant="determinate"
              value={progress}
              sx={{ height: 8, borderRadius: 4 }}
            />
            <Typography variant="body2" color="text.secondary" sx={{ mt: 1 }}>
              进度: {progress.toFixed(1)}%
            </Typography>
          </Box>
        )}
      </CardContent>
    </Card>
  );

  if (loading) {
    return (
      <Box sx={{ display: 'flex', justifyContent: 'center', alignItems: 'center', minHeight: 400 }}>
        <CircularProgress size={60} />
      </Box>
    );
  }

  return (
    <Box>
      {/* 页面标题 */}
      <Box sx={{ mb: 4 }}>
        <Box sx={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <Box>
            <Typography variant="h4" component="h1" gutterBottom>
              📊 统计数据
            </Typography>
            <Typography variant="subtitle1" color="text.secondary">
              系统运行状态和数据统计信息
            </Typography>
          </Box>
          <Button
            startIcon={<Refresh />}
            onClick={fetchStats}
            disabled={refreshing}
            variant="outlined"
            size="large"
          >
            {refreshing ? '刷新中...' : '刷新数据'}
          </Button>
        </Box>
      </Box>

      {/* 错误提示 */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {stats && (
        <>
          {/* 主要统计数据 */}
          <Grid container spacing={3} sx={{ mb: 4 }}>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="总交易数"
                value={stats.totalTransactions?.toLocaleString() || '0'}
                subtitle="已索引的ERC20转账"
                icon={<TrendingUp />}
                color="primary"
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="区块范围"
                value={`${stats.startBlock || 0} - ${stats.endBlock || 0}`}
                subtitle={`最新区块: ${stats.latestBlock || 'N/A'}`}
                icon={<Storage />}
                color="secondary"
                progress={getIndexingProgress()}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="支持代币"
                value={stats.supportedTokens || tokens.length}
                subtitle="监控的ERC20代币"
                icon={<AccountBalanceWallet />}
                color="success"
              />
            </Grid>
            <Grid item xs={12} sm={6} md={3}>
              <StatCard
                title="索引状态"
                value={stats.indexerStatus || '运行中'}
                subtitle={`更新时间: ${moment().format('HH:mm:ss')}`}
                icon={<Speed />}
                color="info"
              />
            </Grid>
          </Grid>

          {/* 系统信息 */}
          <Grid container spacing={3} sx={{ mb: 4 }}>
            <Grid item xs={12} md={6}>
              <Card elevation={2}>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <Timeline sx={{ mr: 2, color: 'primary.main' }} />
                    <Typography variant="h6">
                      索引进度详情
                    </Typography>
                  </Box>
                  <Box sx={{ space: 2 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        起始区块:
                      </Typography>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                        #{stats.startBlock || 0}
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        当前区块:
                      </Typography>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                        #{stats.endBlock || 0}
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        最新区块:
                      </Typography>
                      <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                        #{stats.latestBlock || 'N/A'}
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        索引进度:
                      </Typography>
                      <Chip
                        label={`${getIndexingProgress().toFixed(1)}%`}
                        color={getIndexingProgress() >= 100 ? 'success' : 'warning'}
                        size="small"
                      />
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
            
            <Grid item xs={12} md={6}>
              <Card elevation={2}>
                <CardContent>
                  <Box sx={{ display: 'flex', alignItems: 'center', mb: 3 }}>
                    <DataUsage sx={{ mr: 2, color: 'secondary.main' }} />
                    <Typography variant="h6">
                      数据库信息
                    </Typography>
                  </Box>
                  <Box sx={{ space: 2 }}>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        数据库类型:
                      </Typography>
                      <Typography variant="body2">
                        SQLite
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        表记录数:
                      </Typography>
                      <Typography variant="body2">
                        {stats.totalTransactions?.toLocaleString() || '0'}
                      </Typography>
                    </Box>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        索引状态:
                      </Typography>
                      <Chip
                        label={stats.indexerStatus || '运行中'}
                        color="success"
                        size="small"
                      />
                    </Box>
                    <Box sx={{ display: 'flex', justifyContent: 'space-between', mb: 2 }}>
                      <Typography variant="body2" color="text.secondary">
                        网络:
                      </Typography>
                      <Typography variant="body2">
                        Anvil (Chain ID: 31337)
                      </Typography>
                    </Box>
                  </Box>
                </CardContent>
              </Card>
            </Grid>
          </Grid>

          {/* 支持的代币列表 */}
          <Card elevation={2}>
            <CardContent>
              <Typography variant="h6" gutterBottom sx={{ mb: 3 }}>
                🪙 监控的ERC20代币
              </Typography>
              {tokens.length > 0 ? (
                <TableContainer component={Paper} elevation={0}>
                  <Table>
                    <TableHead>
                      <TableRow sx={{ backgroundColor: 'grey.50' }}>
                        <TableCell>代币名称</TableCell>
                        <TableCell>代币符号</TableCell>
                        <TableCell>合约地址</TableCell>
                        <TableCell>精度</TableCell>
                        <TableCell>状态</TableCell>
                      </TableRow>
                    </TableHead>
                    <TableBody>
                      {tokens.map((token, index) => (
                        <TableRow key={index} hover>
                          <TableCell>
                            <Typography variant="body2" sx={{ fontWeight: 'bold' }}>
                              {token.name || `测试代币 ${index + 1}`}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Chip
                              label={token.symbol || `TEST${index + 1}`}
                              size="small"
                              variant="outlined"
                            />
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                              {formatAddress(token.address)}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Typography variant="body2">
                              {token.decimals || 18}
                            </Typography>
                          </TableCell>
                          <TableCell>
                            <Chip
                              label="监控中"
                              color="success"
                              size="small"
                            />
                          </TableCell>
                        </TableRow>
                      ))}
                    </TableBody>
                  </Table>
                </TableContainer>
              ) : (
                <Alert severity="info">
                  暂无代币数据，请检查后端配置
                </Alert>
              )}
            </CardContent>
          </Card>
        </>
      )}
    </Box>
  );
};

export default StatsPage;