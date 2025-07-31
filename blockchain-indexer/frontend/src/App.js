import React from 'react';
import { Routes, Route } from 'react-router-dom';
import { Container, AppBar, Toolbar, Typography, Box } from '@mui/material';
import { WalletProvider } from './contexts/WalletContext';
import HomePage from './pages/HomePage';
import TransactionsPage from './pages/TransactionsPage';
import StatsPage from './pages/StatsPage';
import WalletConnect from './components/WalletConnect';
import Navigation from './components/Navigation';
import './App.css';

function App() {
  return (
    <WalletProvider>
      <div className="App">
        {/* 顶部导航栏 */}
        <AppBar position="static" elevation={2}>
          <Toolbar>
            <Typography variant="h6" component="div" sx={{ flexGrow: 1 }}>
              🔗 区块链数据索引器
            </Typography>
            <WalletConnect />
          </Toolbar>
        </AppBar>

        {/* 导航菜单 */}
        <Navigation />

        {/* 主要内容区域 */}
        <Container maxWidth="lg" sx={{ mt: 4, mb: 4 }}>
          <Routes>
            <Route path="/" element={<HomePage />} />
            <Route path="/transactions" element={<TransactionsPage />} />
            <Route path="/stats" element={<StatsPage />} />
          </Routes>
        </Container>

        {/* 页脚 */}
        <Box
          component="footer"
          sx={{
            py: 3,
            px: 2,
            mt: 'auto',
            backgroundColor: (theme) =>
              theme.palette.mode === 'light'
                ? theme.palette.grey[200]
                : theme.palette.grey[800],
          }}
        >
          <Container maxWidth="sm">
            <Typography variant="body2" color="text.secondary" align="center">
              {'© '}
              {new Date().getFullYear()}
              {' 区块链数据索引器 - 基于以太坊的ERC20转账数据分析工具'}
            </Typography>
          </Container>
        </Box>
      </div>
    </WalletProvider>
  );
}

export default App;