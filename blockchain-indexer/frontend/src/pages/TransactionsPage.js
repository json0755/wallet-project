import React, { useState } from 'react';
import {
  Box,
  Typography,
  Card,
  CardContent,
  TextField,
  Button,
  Table,
  TableBody,
  TableCell,
  TableContainer,
  TableHead,
  TableRow,
  Paper,
  Pagination,
  Alert,
  CircularProgress,
  Chip,
  InputAdornment,
  IconButton,
} from '@mui/material';
import {
  Search,
  Clear,
  OpenInNew,
  TrendingUp,
  TrendingDown,
} from '@mui/icons-material';
import { useWallet } from '../contexts/WalletContext';
import api from '../utils/api';
import moment from 'moment';

const TransactionsPage = () => {
  const { account, isConnected } = useWallet();
  const [searchAddress, setSearchAddress] = useState('');
  const [transactions, setTransactions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(0);
  const [summary, setSummary] = useState(null);
  const pageSize = 10;

  // 搜索交易记录
  const searchTransactions = async (address, pageNum = 1) => {
    if (!address || !address.match(/^0x[a-fA-F0-9]{40}$/)) {
      setError('请输入有效的以太坊地址');
      return;
    }

    try {
      setLoading(true);
      setError(null);
      
      // 获取交易记录
      const response = await api.get(`/api/transactions/${address}`, {
        params: {
          page: pageNum,
          limit: pageSize,
        },
      });
      
      setTransactions(response.data.transactions);
      setTotalPages(Math.ceil(response.data.total / pageSize));
      setPage(pageNum);
      
      // 获取交易摘要
      const summaryResponse = await api.get(`/api/transactions/${address}/summary`);
      setSummary(summaryResponse.data);
      
    } catch (err) {
      console.error('搜索交易失败:', err);
      if (err.response?.status === 404) {
        setError('未找到该地址的交易记录');
      } else {
        setError('搜索失败，请检查网络连接或后端服务');
      }
      setTransactions([]);
      setSummary(null);
    } finally {
      setLoading(false);
    }
  };

  // 处理搜索
  const handleSearch = () => {
    if (searchAddress.trim()) {
      searchTransactions(searchAddress.trim(), 1);
    }
  };

  // 处理分页
  const handlePageChange = (event, newPage) => {
    if (searchAddress.trim()) {
      searchTransactions(searchAddress.trim(), newPage);
    }
  };

  // 清空搜索
  const handleClear = () => {
    setSearchAddress('');
    setTransactions([]);
    setSummary(null);
    setError(null);
    setPage(1);
    setTotalPages(0);
  };

  // 使用当前连接的账户搜索
  const searchMyTransactions = () => {
    if (account) {
      setSearchAddress(account);
      searchTransactions(account, 1);
    }
  };

  // 格式化地址显示
  const formatAddress = (address) => {
    return `${address.slice(0, 6)}...${address.slice(-4)}`;
  };

  // 格式化金额显示
  const formatAmount = (amount) => {
    const value = parseFloat(amount);
    if (value === 0) return '0';
    if (value < 0.0001) return value.toExponential(2);
    return value.toLocaleString(undefined, { maximumFractionDigits: 6 });
  };

  // 判断交易类型（发送/接收）
  const getTransactionType = (tx, address) => {
    const lowerAddress = address.toLowerCase();
    if (tx.from_address.toLowerCase() === lowerAddress) {
      return 'sent';
    } else if (tx.to_address.toLowerCase() === lowerAddress) {
      return 'received';
    }
    return 'unknown';
  };

  return (
    <Box>
      {/* 页面标题 */}
      <Box sx={{ mb: 4 }}>
        <Typography variant="h4" component="h1" gutterBottom>
          📋 交易记录查询
        </Typography>
        <Typography variant="subtitle1" color="text.secondary">
          查询指定地址的ERC20代币转账记录
        </Typography>
      </Box>

      {/* 搜索区域 */}
      <Card elevation={2} sx={{ mb: 3 }}>
        <CardContent>
          <Box sx={{ display: 'flex', gap: 2, alignItems: 'flex-start' }}>
            <TextField
              fullWidth
              label="以太坊地址"
              placeholder="输入要查询的以太坊地址 (0x...)"
              value={searchAddress}
              onChange={(e) => setSearchAddress(e.target.value)}
              onKeyPress={(e) => e.key === 'Enter' && handleSearch()}
              InputProps={{
                startAdornment: (
                  <InputAdornment position="start">
                    <Search />
                  </InputAdornment>
                ),
                endAdornment: searchAddress && (
                  <InputAdornment position="end">
                    <IconButton onClick={handleClear} size="small">
                      <Clear />
                    </IconButton>
                  </InputAdornment>
                ),
              }}
            />
            <Button
              variant="contained"
              onClick={handleSearch}
              disabled={loading || !searchAddress.trim()}
              sx={{ minWidth: 100 }}
            >
              搜索
            </Button>
            {isConnected && account && (
              <Button
                variant="outlined"
                onClick={searchMyTransactions}
                disabled={loading}
                sx={{ minWidth: 120 }}
              >
                查询我的交易
              </Button>
            )}
          </Box>
        </CardContent>
      </Card>

      {/* 错误提示 */}
      {error && (
        <Alert severity="error" sx={{ mb: 3 }}>
          {error}
        </Alert>
      )}

      {/* 交易摘要 */}
      {summary && (
        <Card elevation={1} sx={{ mb: 3 }}>
          <CardContent>
            <Typography variant="h6" gutterBottom>
              📊 交易摘要
            </Typography>
            <Box sx={{ display: 'flex', gap: 3, flexWrap: 'wrap' }}>
              <Chip
                icon={<TrendingUp />}
                label={`总交易数: ${summary.totalTransactions}`}
                color="primary"
                variant="outlined"
              />
              <Chip
                icon={<TrendingUp />}
                label={`发送交易: ${summary.sentTransactions}`}
                color="error"
                variant="outlined"
              />
              <Chip
                icon={<TrendingDown />}
                label={`接收交易: ${summary.receivedTransactions}`}
                color="success"
                variant="outlined"
              />
            </Box>
          </CardContent>
        </Card>
      )}

      {/* 加载状态 */}
      {loading && (
        <Box sx={{ display: 'flex', justifyContent: 'center', py: 4 }}>
          <CircularProgress />
        </Box>
      )}

      {/* 交易列表 */}
      {!loading && transactions.length > 0 && (
        <Card elevation={2}>
          <CardContent sx={{ p: 0 }}>
            <TableContainer component={Paper} elevation={0}>
              <Table>
                <TableHead>
                  <TableRow sx={{ backgroundColor: 'grey.50' }}>
                    <TableCell>交易哈希</TableCell>
                    <TableCell>类型</TableCell>
                    <TableCell>发送方</TableCell>
                    <TableCell>接收方</TableCell>
                    <TableCell align="right">金额</TableCell>
                    <TableCell>代币地址</TableCell>
                    <TableCell>时间</TableCell>
                    <TableCell>操作</TableCell>
                  </TableRow>
                </TableHead>
                <TableBody>
                  {transactions.map((tx, index) => {
                    const txType = getTransactionType(tx, searchAddress);
                    return (
                      <TableRow key={index} hover>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                            {formatAddress(tx.transaction_hash)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Chip
                            size="small"
                            label={txType === 'sent' ? '发送' : '接收'}
                            color={txType === 'sent' ? 'error' : 'success'}
                            variant="outlined"
                          />
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                            {formatAddress(tx.from_address)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                            {formatAddress(tx.to_address)}
                          </Typography>
                        </TableCell>
                        <TableCell align="right">
                          <Typography variant="body2" sx={{ fontWeight: 'bold' }}>
                            {formatAmount(tx.amount)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2" sx={{ fontFamily: 'monospace' }}>
                            {formatAddress(tx.token_address)}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <Typography variant="body2">
                            {moment(tx.timestamp).format('MM-DD HH:mm:ss')}
                          </Typography>
                        </TableCell>
                        <TableCell>
                          <IconButton
                            size="small"
                            onClick={() => window.open(`#/tx/${tx.transaction_hash}`, '_blank')}
                          >
                            <OpenInNew fontSize="small" />
                          </IconButton>
                        </TableCell>
                      </TableRow>
                    );
                  })}
                </TableBody>
              </Table>
            </TableContainer>
            
            {/* 分页 */}
            {totalPages > 1 && (
              <Box sx={{ display: 'flex', justifyContent: 'center', p: 3 }}>
                <Pagination
                  count={totalPages}
                  page={page}
                  onChange={handlePageChange}
                  color="primary"
                  showFirstButton
                  showLastButton
                />
              </Box>
            )}
          </CardContent>
        </Card>
      )}

      {/* 无数据提示 */}
      {!loading && !error && transactions.length === 0 && searchAddress && (
        <Card elevation={1}>
          <CardContent sx={{ textAlign: 'center', py: 6 }}>
            <Typography variant="h6" color="text.secondary" gutterBottom>
              📭 暂无交易记录
            </Typography>
            <Typography variant="body2" color="text.secondary">
              该地址暂无ERC20代币转账记录，或者数据还在索引中
            </Typography>
          </CardContent>
        </Card>
      )}
    </Box>
  );
};

export default TransactionsPage;