import React from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Tabs, Tab, Box, Paper } from '@mui/material';
import { Home, List, BarChart } from '@mui/icons-material';

const Navigation = () => {
  const location = useLocation();
  const navigate = useNavigate();

  // 根据当前路径确定选中的tab
  const getCurrentTab = () => {
    switch (location.pathname) {
      case '/':
        return 0;
      case '/transactions':
        return 1;
      case '/stats':
        return 2;
      default:
        return 0;
    }
  };

  const handleTabChange = (event, newValue) => {
    switch (newValue) {
      case 0:
        navigate('/');
        break;
      case 1:
        navigate('/transactions');
        break;
      case 2:
        navigate('/stats');
        break;
      default:
        navigate('/');
    }
  };

  return (
    <Paper elevation={1} sx={{ borderRadius: 0 }}>
      <Box sx={{ borderBottom: 1, borderColor: 'divider' }}>
        <Tabs
          value={getCurrentTab()}
          onChange={handleTabChange}
          centered
          sx={{
            '& .MuiTab-root': {
              textTransform: 'none',
              fontWeight: 600,
              fontSize: '1rem',
              minHeight: 64,
            },
          }}
        >
          <Tab
            icon={<Home />}
            label="首页"
            iconPosition="start"
            sx={{ gap: 1 }}
          />
          <Tab
            icon={<List />}
            label="交易记录"
            iconPosition="start"
            sx={{ gap: 1 }}
          />
          <Tab
            icon={<BarChart />}
            label="统计数据"
            iconPosition="start"
            sx={{ gap: 1 }}
          />
        </Tabs>
      </Box>
    </Paper>
  );
};

export default Navigation;