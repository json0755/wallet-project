'use client';

import React, { useState, useEffect } from 'react';
import { 
  Card, 
  Button, 
  Input, 
  message, 
  Space, 
  Typography, 
  Divider, 
  Row, 
  Col, 
  Statistic, 
  Badge,
  Alert,
  Spin,
  Tooltip
} from 'antd';
import { 
  WalletOutlined, 
  BankOutlined, 
  DollarOutlined, 
  SwapOutlined,
  SafetyOutlined,
  ReloadOutlined,
  InfoCircleOutlined,
  CheckCircleOutlined,
  ExclamationCircleOutlined
} from '@ant-design/icons';
import { useAccount, useConnect, useDisconnect } from 'wagmi';
import { injected, metaMask } from 'wagmi/connectors';
import { ethers } from 'ethers';
import {
  createTokenBankContract,
  createTokenContract,
  createPermit2Contract,
  createPermit2Signature,
  formatAmount,
  parseAmount,
  truncateAddress,
  getPermit2Nonce,
  getDeadline,
  type PermitDetails,
  type PermitSingle
} from '../utils/ethers';
import { CONTRACTS } from '../config/contracts';

const { Title, Text } = Typography;

export default function Home() {
  const { address, isConnected } = useAccount();
  const { connect } = useConnect();
  const { disconnect } = useDisconnect();

  // 状态管理
  const [loading, setLoading] = useState(false);
  const [refreshing, setRefreshing] = useState(false);
  const [tokenBalance, setTokenBalance] = useState('0');
  const [bankBalance, setBankBalance] = useState('0');
  const [depositAmount, setDepositAmount] = useState('');
  const [tokenInfo, setTokenInfo] = useState({ 
    name: '', 
    symbol: '', 
    decimals: 18,
    totalSupply: '0'
  });
  const [allowances, setAllowances] = useState({
    tokenBank: '0',
    permit2: '0'
  });
  const [permit2Nonce, setPermit2Nonce] = useState(0);
  const [networkInfo, setNetworkInfo] = useState({
    chainId: 0,
    name: '',
    connected: false
  });

  // 检查网络连接
  const checkNetwork = async () => {
    try {
      if (window.ethereum) {
        const provider = new ethers.BrowserProvider(window.ethereum);
        const network = await provider.getNetwork();
        setNetworkInfo({
          chainId: Number(network.chainId),
          name: network.name,
          connected: Number(network.chainId) === 31337
        });
        
        if (Number(network.chainId) !== 31337) {
          message.warning('请切换到 Anvil 网络 (Chain ID: 31337)');
        }
      }
    } catch (error) {
      console.error('Network check failed:', error);
    }
  };

  // 加载所有数据
  const loadAllData = async () => {
    if (!isConnected || !address) return;
    
    setRefreshing(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      
      // 创建合约实例
      const tokenContract = createTokenContract(provider);
      const bankContract = createTokenBankContract(provider);
      const permit2Contract = createPermit2Contract(provider);
      
      // 并行获取所有数据
      const [
        name,
        symbol,
        decimals,
        totalSupply,
        userTokenBalance,
        userBankBalance,
        tokenBankAllowance,
        permit2AllowanceData,
        currentNonce
      ] = await Promise.all([
        tokenContract.name(),
        tokenContract.symbol(),
        tokenContract.decimals(),
        tokenContract.totalSupply(),
        tokenContract.balanceOf(address),
        bankContract.balanceOf(address),
        tokenContract.allowance(address, CONTRACTS.TOKEN_BANK),
        permit2Contract.allowance(address, CONTRACTS.EIP2612_TOKEN, CONTRACTS.TOKEN_BANK),
        getPermit2Nonce(permit2Contract, address, CONTRACTS.EIP2612_TOKEN, CONTRACTS.TOKEN_BANK)
      ]);
      
      const decimalsNum = Number(decimals);
      
      // 更新状态
      setTokenInfo({
        name,
        symbol,
        decimals: decimalsNum,
        totalSupply: formatAmount(totalSupply.toString(), decimalsNum)
      });
      
      setTokenBalance(formatAmount(userTokenBalance.toString(), decimalsNum));
      setBankBalance(formatAmount(userBankBalance.toString(), decimalsNum));
      
      setAllowances({
        tokenBank: formatAmount(tokenBankAllowance.toString(), decimalsNum),
        permit2: formatAmount(permit2AllowanceData.amount.toString(), decimalsNum)
      });
      
      setPermit2Nonce(currentNonce);
      
    } catch (error) {
      console.error('加载数据失败:', error);
      message.error('加载数据失败，请检查网络连接');
    } finally {
      setRefreshing(false);
    }
  };

  // 监听连接状态变化
  useEffect(() => {
    if (isConnected && address) {
      checkNetwork();
      loadAllData();
    }
  }, [isConnected, address]);

  // 连接钱包
  const handleConnect = async () => {
    try {
      connect({ connector: injected() });
    } catch (error) {
      console.error('钱包连接失败:', error);
      message.error('钱包连接失败');
    }
  };

  // 断开钱包
  const handleDisconnect = () => {
    disconnect();
    // 清空状态
    setTokenBalance('0');
    setBankBalance('0');
    setDepositAmount('');
    setTokenInfo({ name: '', symbol: '', decimals: 18, totalSupply: '0' });
    setAllowances({ tokenBank: '0', permit2: '0' });
    setPermit2Nonce(0);
  };

  // 授权 Permit2
  const handlePermit2Approve = async () => {
    if (!isConnected || !address) {
      message.error('请先连接钱包');
      return;
    }

    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const tokenContract = createTokenContract(signer);

      message.loading('正在授权 Permit2 合约...', 0);
      const tx = await tokenContract.approve(CONTRACTS.PERMIT2, ethers.MaxUint256);
      await tx.wait();
      
      message.destroy();
      message.success('Permit2 授权成功！');
      
      // 刷新数据
      await loadAllData();
    } catch (error: any) {
      console.error('Permit2 授权失败:', error);
      message.error(`Permit2 授权失败: ${error.message || '未知错误'}`);
    } finally {
      setLoading(false);
    }
  };

  // Permit2 签名存款
  const handlePermit2Deposit = async () => {
    if (!isConnected || !address || !depositAmount) {
      message.error('请连接钱包并输入存款金额');
      return;
    }

    const depositAmountNum = parseFloat(depositAmount);
    const permit2AllowanceNum = parseFloat(allowances.permit2);
    
    if (permit2AllowanceNum < depositAmountNum) {
      message.error('Permit2 授权额度不足，请先授权');
      return;
    }

    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const bankContract = createTokenBankContract(signer);
      const permit2Contract = createPermit2Contract(provider);

      const amount = parseAmount(depositAmount, tokenInfo.decimals);
      const deadline = getDeadline(30); // 30分钟后过期
      const sigDeadline = getDeadline(30);
      
      // 获取当前nonce
      const currentNonce = await getPermit2Nonce(
        permit2Contract, 
        address, 
        CONTRACTS.EIP2612_TOKEN, 
        CONTRACTS.TOKEN_BANK
      );

      // 创建 Permit2 签名数据
      const permitDetails: PermitDetails = {
        token: CONTRACTS.EIP2612_TOKEN,
        amount: amount.toString(),
        expiration: deadline,
        nonce: currentNonce
      };

      const signature = await createPermit2Signature(
        signer,
        permitDetails,
        CONTRACTS.TOKEN_BANK,
        sigDeadline
      );

      const permitSingle: PermitSingle = {
        details: permitDetails,
        spender: CONTRACTS.TOKEN_BANK,
        sigDeadline
      };

      message.loading('正在执行 Permit2 存款...', 0);
      const tx = await bankContract.depositWithPermit2(permitSingle, signature, amount);
      await tx.wait();
      
      message.destroy();
      message.success('Permit2 存款成功！');
      
      // 清空输入并刷新数据
      setDepositAmount('');
      await loadAllData();
    } catch (error: any) {
      console.error('Permit2 存款失败:', error);
      message.error(`Permit2 存款失败: ${error.message || '未知错误'}`);
    } finally {
      setLoading(false);
    }
  };

  // 传统授权存款
  const handleStandardDeposit = async () => {
    if (!isConnected || !address || !depositAmount) {
      message.error('请连接钱包并输入存款金额');
      return;
    }

    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider(window.ethereum);
      const signer = await provider.getSigner();
      const tokenContract = createTokenContract(signer);
      const bankContract = createTokenBankContract(signer);

      const amount = parseAmount(depositAmount, tokenInfo.decimals);

      // 检查是否需要授权
      const currentAllowance = parseAmount(allowances.tokenBank, tokenInfo.decimals);
      if (currentAllowance < amount) {
        message.loading('正在授权 TokenBank 合约...', 0);
        const approveTx = await tokenContract.approve(CONTRACTS.TOKEN_BANK, amount);
        await approveTx.wait();
        message.destroy();
      }

      message.loading('正在执行存款...', 0);
      const depositTx = await bankContract.deposit(amount, address);
      await depositTx.wait();
      
      message.destroy();
      message.success('标准存款成功！');
      
      // 清空输入并刷新数据
      setDepositAmount('');
      await loadAllData();
    } catch (error: any) {
      console.error('标准存款失败:', error);
      message.error(`标准存款失败: ${error.message || '未知错误'}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 via-indigo-50 to-purple-50 p-4">
      <div className="max-w-7xl mx-auto">
        {/* 页面标题 */}
        <div className="text-center mb-8">
          <Title level={1} className="text-gray-800 mb-2">
            <BankOutlined className="mr-3 text-blue-600" />
            EIP2612 TokenBank
          </Title>
          <Text className="text-gray-600 text-lg block mb-4">
            基于 Permit2 的无 Gas 授权存款系统
          </Text>
          
          {/* 网络状态指示器 */}
          {isConnected && (
            <Badge 
              status={networkInfo.connected ? 'success' : 'error'} 
              text={
                networkInfo.connected 
                  ? `已连接到 Anvil 网络 (${networkInfo.chainId})`
                  : `当前网络: ${networkInfo.chainId} (需要切换到 31337)`
              }
            />
          )}
        </div>

        {/* 钱包连接卡片 */}
        <Card className="mb-6 shadow-lg border-0">
          <div className="flex justify-between items-center">
            <div className="flex items-center space-x-4">
              <div className="p-3 bg-blue-100 rounded-full">
                <WalletOutlined className="text-blue-600 text-xl" />
              </div>
              <div>
                <Title level={4} className="mb-1">钱包连接</Title>
                {isConnected ? (
                  <div className="space-y-1">
                    <Text className="text-green-600 font-medium">
                      <CheckCircleOutlined className="mr-1" />
                      已连接: {truncateAddress(address || '')}
                    </Text>
                    <br />
                    <Text className="text-gray-500 text-sm">
                      网络: {networkInfo.name || 'Unknown'} ({networkInfo.chainId})
                    </Text>
                  </div>
                ) : (
                  <Text className="text-gray-500">
                    <ExclamationCircleOutlined className="mr-1" />
                    未连接钱包
                  </Text>
                )}
              </div>
            </div>
            <div className="flex space-x-2">
              {isConnected && (
                <Tooltip title="刷新数据">
                  <Button 
                    icon={<ReloadOutlined />} 
                    onClick={loadAllData}
                    loading={refreshing}
                  />
                </Tooltip>
              )}
              {isConnected ? (
                <Button type="default" onClick={handleDisconnect}>
                  断开连接
                </Button>
              ) : (
                <Button type="primary" size="large" onClick={handleConnect}>
                  连接钱包
                </Button>
              )}
            </div>
          </div>
        </Card>

        {isConnected && (
          <>
            {/* 代币信息卡片 */}
            <Card 
              title={
                <span>
                  <InfoCircleOutlined className="mr-2" />
                  代币信息
                </span>
              } 
              className="mb-6 shadow-lg border-0"
            >
              <Row gutter={[24, 16]}>
                <Col xs={24} sm={12} md={6}>
                  <Statistic
                    title="代币名称"
                    value={tokenInfo.name || '加载中...'}
                    prefix={<DollarOutlined />}
                  />
                </Col>
                <Col xs={24} sm={12} md={6}>
                  <Statistic
                    title="代币符号"
                    value={tokenInfo.symbol || '...'}
                  />
                </Col>
                <Col xs={24} sm={12} md={6}>
                  <Statistic
                    title="精度"
                    value={tokenInfo.decimals}
                  />
                </Col>
                <Col xs={24} sm={12} md={6}>
                  <Statistic
                    title="总供应量"
                    value={tokenInfo.totalSupply}
                    suffix={tokenInfo.symbol}
                    precision={2}
                  />
                </Col>
              </Row>
            </Card>

            {/* 余额信息 */}
            <Row gutter={[16, 16]} className="mb-6">
              <Col xs={24} md={8}>
                <Card className="shadow-lg border-0 h-full">
                  <Statistic
                    title="钱包余额"
                    value={tokenBalance}
                    suffix={tokenInfo.symbol}
                    prefix={<DollarOutlined className="text-green-600" />}
                    precision={4}
                    valueStyle={{ color: '#52c41a' }}
                  />
                </Card>
              </Col>
              <Col xs={24} md={8}>
                <Card className="shadow-lg border-0 h-full">
                  <Statistic
                    title="银行存款"
                    value={bankBalance}
                    suffix={tokenInfo.symbol}
                    prefix={<BankOutlined className="text-blue-600" />}
                    precision={4}
                    valueStyle={{ color: '#1890ff' }}
                  />
                </Card>
              </Col>
              <Col xs={24} md={8}>
                <Card className="shadow-lg border-0 h-full">
                  <Statistic
                    title="Permit2 授权"
                    value={allowances.permit2}
                    suffix={tokenInfo.symbol}
                    prefix={<SafetyOutlined className="text-purple-600" />}
                    precision={4}
                    valueStyle={{ color: '#722ed1' }}
                  />
                </Card>
              </Col>
            </Row>

            {/* 存款操作区域 */}
            <Card 
              title={
                <span>
                  <SwapOutlined className="mr-2" />
                  存款操作
                </span>
              } 
              className="shadow-lg border-0 mb-6"
            >
              <Space direction="vertical" size="large" className="w-full">
                {/* 存款金额输入 */}
                <div>
                  <Text strong className="block mb-2">存款金额</Text>
                  <Input
                    size="large"
                    placeholder={`请输入存款金额 (${tokenInfo.symbol})`}
                    value={depositAmount}
                    onChange={(e) => setDepositAmount(e.target.value)}
                    suffix={tokenInfo.symbol}
                    className="rounded-lg"
                  />
                  <Text className="text-gray-500 text-sm mt-1 block">
                    可用余额: {tokenBalance} {tokenInfo.symbol}
                  </Text>
                </div>

                <Divider>选择存款方式</Divider>

                {/* 存款方式选择 */}
                <Row gutter={16}>
                  <Col xs={24} lg={12}>
                    <Card 
                      className="border-2 border-blue-200 hover:border-blue-400 transition-all duration-300 hover:shadow-md"
                      bodyStyle={{ padding: '20px' }}
                    >
                      <div className="text-center mb-4">
                        <div className="p-4 bg-blue-100 rounded-full inline-block mb-3">
                          <SafetyOutlined className="text-blue-600 text-2xl" />
                        </div>
                        <Title level={4} className="mb-2">🚀 Permit2 存款</Title>
                        <Text className="text-gray-600">
                          一键签名存款，无需额外 Gas 费用
                        </Text>
                      </div>
                      
                      {parseFloat(allowances.permit2) === 0 ? (
                        <>
                          <Alert
                            message="需要先授权 Permit2 合约"
                            type="warning"
                            showIcon
                            className="mb-3"
                          />
                          <Button
                            type="primary"
                            size="large"
                            loading={loading}
                            onClick={handlePermit2Approve}
                            className="w-full rounded-lg"
                            icon={<SafetyOutlined />}
                          >
                            授权 Permit2
                          </Button>
                        </>
                      ) : (
                        <>
                          <Alert
                            message={`已授权额度: ${allowances.permit2} ${tokenInfo.symbol}`}
                            type="success"
                            showIcon
                            className="mb-3"
                          />
                          <Text className="text-gray-600 block mb-3 text-sm">
                            当前 Nonce: {permit2Nonce}
                          </Text>
                          <Button
                            type="primary"
                            size="large"
                            loading={loading}
                            onClick={handlePermit2Deposit}
                            disabled={!depositAmount || parseFloat(depositAmount) <= 0}
                            className="w-full rounded-lg"
                            icon={<SwapOutlined />}
                          >
                            Permit2 存款
                          </Button>
                        </>
                      )}
                    </Card>
                  </Col>
                  
                  <Col xs={24} lg={12}>
                    <Card 
                      className="border-2 border-gray-200 hover:border-gray-400 transition-all duration-300 hover:shadow-md"
                      bodyStyle={{ padding: '20px' }}
                    >
                      <div className="text-center mb-4">
                        <div className="p-4 bg-gray-100 rounded-full inline-block mb-3">
                          <BankOutlined className="text-gray-600 text-2xl" />
                        </div>
                        <Title level={4} className="mb-2">📝 标准存款</Title>
                        <Text className="text-gray-600">
                          传统方式：先授权再存款
                        </Text>
                      </div>
                      
                      <Alert
                        message="需要两次交易：授权 + 存款"
                        type="info"
                        showIcon
                        className="mb-3"
                      />
                      <Text className="text-gray-600 block mb-3 text-sm">
                        TokenBank 授权额度: {allowances.tokenBank} {tokenInfo.symbol}
                      </Text>
                      <Button
                        type="default"
                        size="large"
                        loading={loading}
                        onClick={handleStandardDeposit}
                        disabled={!depositAmount || parseFloat(depositAmount) <= 0}
                        className="w-full rounded-lg"
                        icon={<BankOutlined />}
                      >
                        标准存款
                      </Button>
                    </Card>
                  </Col>
                </Row>
              </Space>
            </Card>

            {/* 合约信息 */}
            <Card 
              title={
                <span>
                  <InfoCircleOutlined className="mr-2" />
                  合约地址信息
                </span>
              } 
              className="shadow-lg border-0"
            >
              <Row gutter={[16, 16]}>
                <Col xs={24} md={8}>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <Text strong className="block mb-2">EIP2612 Token</Text>
                    <Text code className="text-xs break-all">
                      {CONTRACTS.EIP2612_TOKEN}
                    </Text>
                  </div>
                </Col>
                <Col xs={24} md={8}>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <Text strong className="block mb-2">Token Bank</Text>
                    <Text code className="text-xs break-all">
                      {CONTRACTS.TOKEN_BANK}
                    </Text>
                  </div>
                </Col>
                <Col xs={24} md={8}>
                  <div className="p-4 bg-gray-50 rounded-lg">
                    <Text strong className="block mb-2">Permit2</Text>
                    <Text code className="text-xs break-all">
                      {CONTRACTS.PERMIT2}
                    </Text>
                  </div>
                </Col>
              </Row>
            </Card>
          </>
        )}
      </div>
    </div>
  );
}