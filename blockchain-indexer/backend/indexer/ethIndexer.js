const { ethers } = require('ethers');
const { insertTransfers, getLatestBlockNumber } = require('../database/sqlite');

// ERC20 Transfer事件的ABI
const ERC20_TRANSFER_ABI = [
  'event Transfer(address indexed from, address indexed to, uint256 value)'
];

// 配置参数
const CONFIG = {
  RPC_URL: process.env.RPC_URL || 'http://localhost:8545',
  CHAIN_ID: process.env.CHAIN_ID || '31337',
  TARGET_TOKENS: process.env.TARGET_TOKENS ? process.env.TARGET_TOKENS.split(',') : [
    '0x5FbDB2315678afecb367f032d93F642f64180aa3', // 本地测试Token 1
    '0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512', // 本地测试Token 2
    '0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0'  // 本地测试Token 3
  ],
  BATCH_SIZE: parseInt(process.env.BATCH_SIZE) || 100,
  START_BLOCK: parseInt(process.env.START_BLOCK) || 0, // 从创世区块开始
  INDEXER_INTERVAL: parseInt(process.env.INDEXER_INTERVAL) || 10000 // 10秒
};

let provider = null;
let isIndexing = false;

/**
 * 初始化以太坊提供者
 */
async function initProvider() {
  try {
    provider = new ethers.JsonRpcProvider(CONFIG.RPC_URL);
    
    // 验证网络连接
    const network = await provider.getNetwork();
    console.log(`✅ 以太坊节点连接已建立: ${CONFIG.RPC_URL}`);
    console.log(`📊 网络信息: Chain ID ${network.chainId}, Name: ${network.name || 'anvil'}`);
    
    // 验证是否为预期的本地网络
    if (network.chainId.toString() !== CONFIG.CHAIN_ID) {
      console.warn(`⚠️  警告: 当前网络 Chain ID (${network.chainId}) 与配置不匹配 (${CONFIG.CHAIN_ID})`);
    }
    
    return provider;
  } catch (error) {
    console.error('❌ 以太坊节点连接失败:', error.message);
    console.error('💡 请确保 Anvil 节点正在运行: anvil');
    throw error;
  }
}

/**
 * 获取指定区块范围内的Transfer事件
 * @param {string} tokenAddress - Token合约地址
 * @param {number} fromBlock - 起始区块
 * @param {number} toBlock - 结束区块
 */
async function getTransferEvents(tokenAddress, fromBlock, toBlock) {
  try {
    const contract = new ethers.Contract(tokenAddress, ERC20_TRANSFER_ABI, provider);
    
    // 创建Transfer事件过滤器
    const filter = contract.filters.Transfer();
    filter.fromBlock = fromBlock;
    filter.toBlock = toBlock;
    filter.address = tokenAddress;

    console.log(`🔍 扫描 ${tokenAddress} 区块 ${fromBlock}-${toBlock} 的Transfer事件...`);
    
    const events = await provider.getLogs(filter);
    
    const transfers = [];
    for (const event of events) {
      try {
        // 解析事件数据
        const parsedLog = contract.interface.parseLog({
          topics: event.topics,
          data: event.data
        });

        // 获取区块信息以获取时间戳
        const block = await provider.getBlock(event.blockNumber);
        
        const transfer = {
          txHash: event.transactionHash,
          from: parsedLog.args.from,
          to: parsedLog.args.to,
          amount: parsedLog.args.value.toString(),
          timestamp: block.timestamp,
          blockNumber: event.blockNumber,
          tokenAddress: tokenAddress
        };
        
        transfers.push(transfer);
      } catch (parseError) {
        console.error('❌ 解析事件失败:', parseError.message);
      }
    }
    
    console.log(`📊 找到 ${transfers.length} 个Transfer事件`);
    return transfers;
  } catch (error) {
    console.error(`❌ 获取Transfer事件失败 (${tokenAddress}):`, error.message);
    return [];
  }
}

/**
 * 索引指定Token的历史数据
 * @param {string} tokenAddress - Token合约地址
 * @param {number} startBlock - 起始区块
 * @param {number} endBlock - 结束区块
 */
async function indexTokenHistory(tokenAddress, startBlock, endBlock) {
  console.log(`🚀 开始索引Token ${tokenAddress} 从区块 ${startBlock} 到 ${endBlock}`);
  
  let currentBlock = startBlock;
  let totalTransfers = 0;
  
  while (currentBlock <= endBlock) {
    const toBlock = Math.min(currentBlock + CONFIG.BATCH_SIZE - 1, endBlock);
    
    try {
      const transfers = await getTransferEvents(tokenAddress, currentBlock, toBlock);
      
      if (transfers.length > 0) {
        const result = await insertTransfers(transfers);
        totalTransfers += result.inserted;
      }
      
      currentBlock = toBlock + 1;
      
      // 添加延迟以避免API限制
      await new Promise(resolve => setTimeout(resolve, 100));
      
    } catch (error) {
      console.error(`❌ 索引区块 ${currentBlock}-${toBlock} 失败:`, error.message);
      currentBlock = toBlock + 1;
    }
  }
  
  console.log(`✅ Token ${tokenAddress} 索引完成，共处理 ${totalTransfers} 个转账`);
  return totalTransfers;
}

/**
 * 获取最新区块号
 */
async function getLatestBlock() {
  try {
    const blockNumber = await provider.getBlockNumber();
    return blockNumber;
  } catch (error) {
    console.error('❌ 获取最新区块号失败:', error.message);
    throw error;
  }
}

/**
 * 实时监听新的Transfer事件
 */
async function startRealTimeIndexing() {
  console.log('🔄 启动实时索引监听...');
  
  for (const tokenAddress of CONFIG.TARGET_TOKENS) {
    try {
      const contract = new ethers.Contract(tokenAddress, ERC20_TRANSFER_ABI, provider);
      
      // 监听Transfer事件
      contract.on('Transfer', async (from, to, value, event) => {
        try {
          const block = await provider.getBlock(event.blockNumber);
          
          const transfer = {
            txHash: event.transactionHash,
            from: from,
            to: to,
            amount: value.toString(),
            timestamp: block.timestamp,
            blockNumber: event.blockNumber,
            tokenAddress: tokenAddress
          };
          
          await insertTransfers([transfer]);
          console.log(`📥 实时索引新转账: ${transfer.txHash}`);
        } catch (error) {
          console.error('❌ 处理实时事件失败:', error.message);
        }
      });
      
      console.log(`👂 开始监听 ${tokenAddress} 的Transfer事件`);
    } catch (error) {
      console.error(`❌ 设置实时监听失败 (${tokenAddress}):`, error.message);
    }
  }
}

/**
 * 定期同步最新数据
 */
async function periodicSync() {
  if (isIndexing) {
    console.log('⏳ 索引正在进行中，跳过本次同步');
    return;
  }
  
  isIndexing = true;
  
  try {
    const latestChainBlock = await getLatestBlock();
    const latestDbBlock = await getLatestBlockNumber();
    
    if (latestDbBlock < latestChainBlock) {
      const startBlock = latestDbBlock + 1;
      const endBlock = Math.min(startBlock + CONFIG.BATCH_SIZE - 1, latestChainBlock);
      
      console.log(`🔄 同步区块 ${startBlock} 到 ${endBlock}`);
      
      for (const tokenAddress of CONFIG.TARGET_TOKENS) {
        await indexTokenHistory(tokenAddress, startBlock, endBlock);
      }
    } else {
      console.log('✅ 数据库已是最新状态');
    }
  } catch (error) {
    console.error('❌ 定期同步失败:', error.message);
  } finally {
    isIndexing = false;
  }
}

/**
 * 启动索引器
 */
async function startIndexer() {
  try {
    // 初始化提供者
    await initProvider();
    
    // 测试连接
    const latestBlock = await getLatestBlock();
    console.log(`📊 当前最新区块: ${latestBlock}`);
    
    // 获取数据库中的最新区块
    const dbLatestBlock = await getLatestBlockNumber();
    console.log(`📊 数据库最新区块: ${dbLatestBlock}`);
    
    // 如果数据库为空，从配置的起始区块开始索引
    if (dbLatestBlock === 0) {
      console.log('🆕 数据库为空，开始历史数据索引...');
      
      for (const tokenAddress of CONFIG.TARGET_TOKENS) {
        const endBlock = Math.min(CONFIG.START_BLOCK + CONFIG.BATCH_SIZE - 1, latestBlock);
        await indexTokenHistory(tokenAddress, CONFIG.START_BLOCK, endBlock);
      }
    }
    
    // 启动实时监听
    await startRealTimeIndexing();
    
    // 启动定期同步
    setInterval(periodicSync, CONFIG.INDEXER_INTERVAL);
    
    console.log('✅ 区块链索引器启动完成');
  } catch (error) {
    console.error('❌ 索引器启动失败:', error.message);
    throw error;
  }
}

/**
 * 停止索引器
 */
function stopIndexer() {
  if (provider) {
    provider.removeAllListeners();
    console.log('🛑 索引器已停止');
  }
}

module.exports = {
  startIndexer,
  stopIndexer,
  indexTokenHistory,
  getLatestBlock
};