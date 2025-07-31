const express = require('express');
const { getTransactionsByAddress } = require('../database/sqlite');
const { ethers } = require('ethers');

const router = express.Router();

/**
 * 验证以太坊地址格式
 * @param {string} address - 地址字符串
 * @returns {boolean} 是否为有效地址
 */
function isValidAddress(address) {
  try {
    return ethers.isAddress(address);
  } catch {
    return false;
  }
}

/**
 * 验证分页参数
 * @param {string} page - 页码
 * @param {string} limit - 每页数量
 * @returns {object} 验证后的分页参数
 */
function validatePagination(page, limit) {
  const pageNum = parseInt(page) || 1;
  const limitNum = parseInt(limit) || 50;
  
  return {
    page: Math.max(1, pageNum),
    limit: Math.min(Math.max(1, limitNum), 100) // 限制最大100条
  };
}

/**
 * GET /api/transactions/:address
 * 获取指定地址的交易记录
 */
router.get('/transactions/:address', async (req, res) => {
  try {
    const { address } = req.params;
    const { page, limit } = req.query;
    
    // 验证地址格式
    if (!isValidAddress(address)) {
      return res.status(400).json({
        error: 'Invalid address format',
        message: '请提供有效的以太坊地址'
      });
    }
    
    // 验证分页参数
    const pagination = validatePagination(page, limit);
    
    console.log(`📊 查询地址 ${address} 的交易记录 (页码: ${pagination.page}, 每页: ${pagination.limit})`);
    
    // 查询数据库
    const result = await getTransactionsByAddress(address, pagination.page, pagination.limit);
    
    // 格式化响应数据
    const formattedTransactions = result.transactions.map(tx => ({
      txHash: tx.txHash,
      from: tx.fromAddress,
      to: tx.toAddress,
      amount: tx.amount,
      timestamp: tx.timestamp,
      blockNumber: tx.blockNumber,
      tokenAddress: tx.tokenAddress,
      // 判断交易方向
      direction: tx.fromAddress.toLowerCase() === address.toLowerCase() ? 'out' : 'in'
    }));
    
    const response = {
      address: address,
      transactions: formattedTransactions,
      pagination: result.pagination,
      summary: {
        totalTransactions: result.pagination.total,
        currentPage: result.pagination.page,
        totalPages: result.pagination.totalPages
      }
    };
    
    res.json(response);
    
  } catch (error) {
    console.error('❌ 查询交易记录失败:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: '查询交易记录时发生错误'
    });
  }
});

/**
 * GET /api/transactions/:address/summary
 * 获取地址交易统计摘要
 */
router.get('/transactions/:address/summary', async (req, res) => {
  try {
    const { address } = req.params;
    
    // 验证地址格式
    if (!isValidAddress(address)) {
      return res.status(400).json({
        error: 'Invalid address format',
        message: '请提供有效的以太坊地址'
      });
    }
    
    // 获取第一页数据来计算统计信息
    const result = await getTransactionsByAddress(address, 1, 100);
    
    let totalIn = 0;
    let totalOut = 0;
    let inCount = 0;
    let outCount = 0;
    
    result.transactions.forEach(tx => {
      const amount = BigInt(tx.amount);
      if (tx.fromAddress.toLowerCase() === address.toLowerCase()) {
        totalOut += Number(amount);
        outCount++;
      } else {
        totalIn += Number(amount);
        inCount++;
      }
    });
    
    const summary = {
      address: address,
      totalTransactions: result.pagination.total,
      incoming: {
        count: inCount,
        totalAmount: totalIn.toString()
      },
      outgoing: {
        count: outCount,
        totalAmount: totalOut.toString()
      },
      lastUpdated: new Date().toISOString()
    };
    
    res.json(summary);
    
  } catch (error) {
    console.error('❌ 查询交易统计失败:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: '查询交易统计时发生错误'
    });
  }
});

/**
 * GET /api/tokens
 * 获取支持的Token列表
 */
router.get('/tokens', (req, res) => {
  const supportedTokens = [
    {
      address: '0x5FbDB2315678afecb367f032d93F642f64180aa3',
      symbol: 'TEST1',
      name: 'Test Token 1',
      decimals: 18
    },
    {
      address: '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512',
      symbol: 'TEST2',
      name: 'Test Token 2',
      decimals: 18
    },
    {
      address: '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0',
      symbol: 'TEST3',
      name: 'Test Token 3',
      decimals: 18
    }
  ];
  
  res.json({
    tokens: supportedTokens,
    count: supportedTokens.length
  });
});

/**
 * GET /api/stats
 * 获取系统统计信息
 */
router.get('/stats', async (req, res) => {
  try {
    const { getDatabase } = require('../database/sqlite');
    const db = getDatabase();
    
    // 获取统计信息
    const stats = await new Promise((resolve, reject) => {
      const queries = [
        'SELECT COUNT(*) as totalTransactions FROM transfers',
        'SELECT COUNT(DISTINCT from_address) as uniqueFromAddresses FROM transfers',
        'SELECT COUNT(DISTINCT to_address) as uniqueToAddresses FROM transfers',
        'SELECT MIN(block_number) as earliestBlock, MAX(block_number) as latestBlock FROM transfers'
      ];
      
      const results = {};
      let completed = 0;
      
      db.get(queries[0], (err, row) => {
        if (err) reject(err);
        results.totalTransactions = row.totalTransactions;
        if (++completed === 4) resolve(results);
      });
      
      db.get(queries[1], (err, row) => {
        if (err) reject(err);
        results.uniqueFromAddresses = row.uniqueFromAddresses;
        if (++completed === 4) resolve(results);
      });
      
      db.get(queries[2], (err, row) => {
        if (err) reject(err);
        results.uniqueToAddresses = row.uniqueToAddresses;
        if (++completed === 4) resolve(results);
      });
      
      db.get(queries[3], (err, row) => {
        if (err) reject(err);
        results.earliestBlock = row.earliestBlock;
        results.latestBlock = row.latestBlock;
        if (++completed === 4) resolve(results);
      });
    });
    
    res.json({
      ...stats,
      indexedBlocks: stats.latestBlock - stats.earliestBlock + 1,
      lastUpdated: new Date().toISOString()
    });
    
  } catch (error) {
    console.error('❌ 获取统计信息失败:', error);
    res.status(500).json({
      error: 'Internal server error',
      message: '获取统计信息时发生错误'
    });
  }
});

module.exports = router;