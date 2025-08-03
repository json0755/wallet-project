'use client';

import React, { useState, useEffect } from 'react';
import { Card, Button, Input, message, Space, Typography, Divider, Row, Col, Statistic } from 'antd';
import { WalletOutlined, BankOutlined, DollarOutlined, SwapOutlined } from '@ant-design/icons';
import { useAccount, useConnect, useDisconnect } from 'wagmi';
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
  resetNonce,
  getExpiration,
  getSigDeadline,
  type PermitSingle
} from '../utils/ethers';
import { DEFAULT_CONTRACTS } from '../config/contracts';
import { config } from 'process';

const { Title, Text } = Typography;

export default function Home() {
  const { address, isConnected } = useAccount();
  const { connect, connectors, isPending } = useConnect();
  const { disconnect } = useDisconnect();

  // State
  const [loading, setLoading] = useState(false);
  const [tokenBalance, setTokenBalance] = useState('0');
  const [bankBalance, setBankBalance] = useState('0');
  const [tokenSymbol, setTokenSymbol] = useState('');
  const [tokenDecimals, setTokenDecimals] = useState(18);
  const [depositAmount, setDepositAmount] = useState('');
  const [permit2Allowance, setPermit2Allowance] = useState('0');

  // Load balances and token info
  const loadBalances = async () => {
    if (!isConnected || !address) return;

    try {
      const provider = new ethers.BrowserProvider((window as any).ethereum);
      const tokenContract = createTokenContract(provider);
      const bankContract = createTokenBankContract(provider);
      const permit2Contract = createPermit2Contract(provider);

      // Get token info
      const [symbol, decimals, balance, bankBal, allowance] = await Promise.all([
        tokenContract.symbol(),
        tokenContract.decimals(),
        tokenContract.balanceOf(address),
        bankContract.totalAssets(),
        tokenContract.allowance(address,DEFAULT_CONTRACTS.PERMIT2)
      ]);

      setTokenSymbol(symbol);
      setTokenDecimals(Number(decimals));
      setTokenBalance(formatAmount(balance.toString(), Number(decimals)));
      setBankBalance(formatAmount(bankBal.toString(), Number(decimals)));
      setPermit2Allowance(formatAmount(allowance.toString(), Number(decimals)));
    } catch (error) {
      console.error('Error loading balances:', error);
      message.error('加载余额失败');
    }
  };

  useEffect(() => {
    if (isConnected && address) {
      // Reset nonce when wallet connects
      resetNonce();
      loadBalances();
    }
  }, [isConnected, address]);

  // Handle wallet connection
  const handleConnect = async () => {
    // Prevent multiple connection attempts
    if (isPending || isConnected) {
      return;
    }

    try {
      const connector = connectors[0]; // Use first available connector
      if (connector) {
        connect({ connector });
      }
    } catch (error) {
      console.error('Connection error:', error);
      message.error('钱包连接失败');
    }
  };

  const handleDisconnect = () => {
    disconnect();
  };

  // Handle Permit2 authorization
  const handlePermit2Approve = async () => {
    if (!isConnected || !address) {
      message.error('请先连接钱包');
      return;
    }

    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const tokenContract = createTokenContract(signer);

      // Approve Permit2 contract with max amount
      message.loading('授权Permit2合约中...', 0);
      const approveTx = await tokenContract.approve(
        DEFAULT_CONTRACTS.PERMIT2,
        // ethers.MaxUint256
        parseAmount(depositAmount, tokenDecimals)
      );
      await approveTx.wait();
      message.destroy();
      message.success('Permit2授权成功!');

      // Reload balances to update permit2 allowance
      await loadBalances();
    } catch (error: any) {
      console.error('Permit2 approve error:', error);
      message.error(`Permit2授权失败: ${error.message || '未知错误'}`);
    } finally {
      setLoading(false);
    }
  };

  // Handle Permit2 deposit
  const handlePermit2Deposit = async () => {
    if (!isConnected || !address || !depositAmount) {
      message.error('请连接钱包并输入存款金额');
      return;
    }

    // Check if user has approved Permit2
    const currentAllowance = parseFloat(permit2Allowance);
    const depositAmountNum = parseFloat(depositAmount);
    
    if (currentAllowance < depositAmountNum) {
      message.info('授权额度不足，正在为您授权Permit2合约...');
      await handlePermit2Approve();
      return;
    }

    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const bankContract = createTokenBankContract(signer);
      const permit2Contract = createPermit2Contract(signer);

      const amount = parseAmount(depositAmount, tokenDecimals);
      const nonce = await getPermit2Nonce(
        provider,
        address,
        DEFAULT_CONTRACTS.EIP2612_TOKEN,
        DEFAULT_CONTRACTS.TOKEN_BANK
      );
      const expiration = getExpiration(24); // 24 hours
      const sigDeadline = getSigDeadline(30); // 30 minutes

      // Create permit data
      const permitData: PermitSingle = {
        details: {
          token: DEFAULT_CONTRACTS.EIP2612_TOKEN,
          amount: amount.toString(),
          expiration,
          nonce
        },
        spender: DEFAULT_CONTRACTS.TOKEN_BANK,
        sigDeadline
      };

      // Create signature
      const signature = await createPermit2Signature(signer, permitData);

      // Execute deposit with permit2
      const tx = await bankContract.permitDeposit2(
        amount,
        DEFAULT_CONTRACTS.TOKEN_BANK,
        amount,
        expiration,
        nonce,
        sigDeadline,
        signature
      );

      message.loading('交易处理中...', 0);
      await tx.wait();
      message.destroy();
      message.success('Permit2存款成功!');

      // Reload balances
      await loadBalances();
      setDepositAmount('');
    } catch (error: any) {
      console.error('Permit2 deposit error:', error);
      message.error(`Permit2存款失败: ${error.message || '未知错误'}`);
    } finally {
      setLoading(false);
    }
  };

  // Handle standard approve + deposit
  const handleStandardDeposit = async () => {
    if (!isConnected || !address || !depositAmount) {
      message.error('请连接钱包并输入存款金额');
      return;
    }

    setLoading(true);
    try {
      const provider = new ethers.BrowserProvider((window as any).ethereum);
      const signer = await provider.getSigner();
      const tokenContract = createTokenContract(signer);
      const bankContract = createTokenBankContract(signer);

      const amount = parseAmount(depositAmount, tokenDecimals);

      // First approve
      message.loading('授权中...', 0);
      const approveTx = await tokenContract.approve(DEFAULT_CONTRACTS.TOKEN_BANK, amount);
      await approveTx.wait();
      message.destroy();

      // Then deposit
      message.loading('存款中...', 0);
      const depositTx = await bankContract.deposit(amount, address);
      await depositTx.wait();
      message.destroy();
      message.success('标准存款成功!');

      // Reload balances
      await loadBalances();
      setDepositAmount('');
    } catch (error: any) {
      console.error('Standard deposit error:', error);
      message.error(`标准存款失败: ${error.message || '未知错误'}`);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-blue-50 to-indigo-100 p-6">
      <div className="max-w-6xl mx-auto">
        {/* Header */}
        <div className="text-center mb-8">
          <Title level={1} className="text-gray-800">
            <BankOutlined className="mr-3" />
            EIP2612 Token Bank
          </Title>
          <Text className="text-gray-600 text-lg">
            基于 Permit2 的无Gas授权存款系统
          </Text>
        </div>

        {/* Wallet Connection */}
        <Card className="mb-6 shadow-lg">
          <div className="flex justify-between items-center">
            <div>
              <Title level={4} className="mb-2">
                <WalletOutlined className="mr-2" />
                钱包连接
              </Title>
              {isConnected ? (
                <Text className="text-green-600">
                  已连接: {truncateAddress(address || '')}
                </Text>
              ) : isPending ? (
                <Text className="text-blue-600">连接中...</Text>
              ) : (
                <Text className="text-gray-500">未连接钱包</Text>
              )}
            </div>
            <div>
              {isConnected ? (
                <Button type="default" onClick={handleDisconnect}>
                  断开连接
                </Button>
              ) : (
                <Button 
                  type="primary" 
                  onClick={handleConnect}
                  loading={isPending}
                  disabled={isPending}
                >
                  {isPending ? '连接中...' : '连接钱包'}
                </Button>
              )}
            </div>
          </div>
        </Card>

        {isConnected && (
          <>
            {/* Balance Information */}
            <Row gutter={[16, 16]} className="mb-6">
              <Col xs={24} sm={8}>
                <Card className="shadow-lg">
                  <Statistic
                    title="Token 余额"
                    value={tokenBalance}
                    suffix={tokenSymbol}
                    prefix={<DollarOutlined />}
                    precision={4}
                  />
                </Card>
              </Col>
              <Col xs={24} sm={8}>
                <Card className="shadow-lg">
                  <Statistic
                    title="银行余额"
                    value={bankBalance}
                    suffix={tokenSymbol}
                    prefix={<BankOutlined />}
                    precision={4}
                  />
                </Card>
              </Col>
              <Col xs={24} sm={8}>
                <Card className="shadow-lg">
                  <Statistic
                    title="Permit2 授权额度"
                    value={permit2Allowance}
                    suffix={tokenSymbol}
                    prefix={<SwapOutlined />}
                    precision={4}
                  />
                </Card>
              </Col>
            </Row>

            {/* Deposit Section */}
            <Card title="存款操作" className="shadow-lg">
              <Space direction="vertical" size="large" className="w-full">
                <div>
                  <Text strong>存款金额</Text>
                  <Input
                    size="large"
                    placeholder={`请输入存款金额 (${tokenSymbol})`}
                    value={depositAmount}
                    onChange={(e: React.ChangeEvent<HTMLInputElement>) => setDepositAmount(e.target.value)}
                    suffix={tokenSymbol}
                    className="mt-2"
                  />
                </div>

                <Divider>存款方式</Divider>

                <Row gutter={16}>
                  <Col xs={24} sm={12}>
                    <Card 
                      title="🚀 Permit2 存款" 
                      className="border-2 border-blue-200 hover:border-blue-400 transition-colors"
                    >
                      <Text className="text-gray-600 block mb-4">
                        一键签名存款，需要先授权Permit2合约
                      </Text>
                      
                      {parseFloat(permit2Allowance) === 0 ? (
                        <>
                          <Text className="text-orange-600 block mb-3">
                            ⚠️ 需要先授权Permit2合约
                          </Text>
                          <Button
                            type="default"
                            size="large"
                            loading={loading}
                            onClick={handlePermit2Approve}
                            className="w-full mb-2"
                          >
                            授权 Permit2
                          </Button>
                        </>
                      ) : (
                        <>
                          <Text className="text-green-600 block mb-3">
                            ✅ 已授权额度: {permit2Allowance} {tokenSymbol}
                          </Text>
                          <Button
                            type="primary"
                            size="large"
                            loading={loading}
                            onClick={handlePermit2Deposit}
                            disabled={!depositAmount}
                            className="w-full"
                          >
                            Permit2 存款
                          </Button>
                        </>
                      )}
                    </Card>
                  </Col>
                  <Col xs={24} sm={12}>
                    <Card 
                      title="📝 标准存款" 
                      className="border-2 border-gray-200 hover:border-gray-400 transition-colors"
                    >
                      <Text className="text-gray-600 block mb-4">
                        传统方式：先授权再存款，需要两次交易
                      </Text>
                      <Button
                        type="default"
                        size="large"
                        loading={loading}
                        onClick={handleStandardDeposit}
                        disabled={!depositAmount}
                        className="w-full"
                      >
                        标准存款
                      </Button>
                    </Card>
                  </Col>
                </Row>
              </Space>
            </Card>

            {/* Contract Information */}
            <Card title="合约信息" className="mt-6 shadow-lg">
              <Row gutter={[16, 16]}>
                <Col xs={24} sm={8}>
                  <Text strong>EIP2612 Token:</Text>
                  <br />
                  <Text code className="text-xs">
                    {DEFAULT_CONTRACTS.EIP2612_TOKEN}
                  </Text>
                </Col>
                <Col xs={24} sm={8}>
                  <Text strong>Token Bank:</Text>
                  <br />
                  <Text code className="text-xs">
                    {DEFAULT_CONTRACTS.TOKEN_BANK}
                  </Text>
                </Col>
                <Col xs={24} sm={8}>
                  <Text strong>Permit2:</Text>
                  <br />
                  <Text code className="text-xs">
                    {DEFAULT_CONTRACTS.PERMIT2}
                  </Text>
                </Col>
              </Row>
            </Card>
          </>
        )}
      </div>
    </div>
  );
}