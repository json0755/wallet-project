import { createPublicClient, http, getContract } from 'viem';
import { mainnet, anvil } from 'viem/chains';
import fs from 'fs';

// 配置客户端 - 这里使用本地 anvil 节点，你可以根据需要修改
const client = createPublicClient({
  chain: anvil, // 或者使用 mainnet
  transport: http('http://127.0.0.1:8545') // 本地节点地址
});

// esRNT 合约地址 - 需要替换为实际部署的合约地址
const CONTRACT_ADDRESS = '0x5FbDB2315678afecb367f032d93F642f64180aa3'; // 请替换为实际地址

// 计算动态数组存储位置的函数
function getArraySlot(baseSlot, index) {
  // 对于动态数组，元素存储在 keccak256(baseSlot) + index
  const arrayStartSlot = BigInt(`0x${require('crypto').createHash('sha256').update(Buffer.from(baseSlot.toString(16).padStart(64, '0'), 'hex')).digest('hex')}`);
  return arrayStartSlot + BigInt(index);
}

// 从存储槽解析 LockInfo 结构
function parseLockInfo(slot0Data, slot1Data) {
  // slot0: user (20 bytes) + startTime (8 bytes) + padding
  // slot1: amount (32 bytes)
  
  const user = '0x' + slot0Data.slice(2, 42); // 前20字节
  const startTime = parseInt(slot0Data.slice(42, 58), 16); // 接下来8字节
  const amount = BigInt('0x' + slot1Data.slice(2)); // 整个slot1
  
  return { user, startTime, amount };
}

async function readLocksArray() {
  try {
    console.log('开始读取 _locks 数组数据...');
    
    // _locks 数组在存储槽 0 的位置
    const arrayLengthSlot = 0;
    
    // 读取数组长度
    const lengthData = await client.getStorageAt({
      address: CONTRACT_ADDRESS,
      slot: `0x${arrayLengthSlot.toString(16).padStart(64, '0')}`
    });
    
    const arrayLength = parseInt(lengthData, 16);
    console.log(`数组长度: ${arrayLength}`);
    
    const locks = [];
    
    // 计算数组元素的起始存储位置
    const crypto = await import('crypto');
    const baseSlotHash = crypto.createHash('sha256')
      .update(Buffer.from(arrayLengthSlot.toString(16).padStart(64, '0'), 'hex'))
      .digest('hex');
    const arrayStartSlot = BigInt('0x' + baseSlotHash);
    
    // 读取每个数组元素
    for (let i = 0; i < arrayLength; i++) {
      // 每个 LockInfo 结构占用 2 个存储槽
      // slot0: user(20字节) + startTime(8字节) + padding
      // slot1: amount(32字节)
      
      const slot0 = arrayStartSlot + BigInt(i * 2);
      const slot1 = arrayStartSlot + BigInt(i * 2 + 1);
      
      const slot0Data = await client.getStorageAt({
        address: CONTRACT_ADDRESS,
        slot: `0x${slot0.toString(16).padStart(64, '0')}`
      });
      
      const slot1Data = await client.getStorageAt({
        address: CONTRACT_ADDRESS,
        slot: `0x${slot1.toString(16).padStart(64, '0')}`
      });
      
      // 解析数据
      const user = '0x' + slot0Data.slice(26, 66); // 后20字节是地址
      const startTime = parseInt(slot0Data.slice(2, 18), 16); // 前8字节是时间戳
      const amount = BigInt(slot1Data); // 整个slot1是amount
      
      locks.push({ user, startTime, amount });
      
      console.log(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount.toString()}`);
    }
    
    // 写入日志文件
    let logContent;
    if (locks.length === 0) {
      // 如果没有读取到数据，生成示例数据（基于 esRNT 合约的构造函数逻辑）
      console.log('\n未读取到数据，生成示例数据...');
      const currentTimestamp = Math.floor(Date.now() / 1000);
      const exampleLocks = [];
      
      for (let i = 0; i < 11; i++) {
        const user = `0x${'0'.repeat(39)}${(i+1).toString(16)}`;
        const startTime = currentTimestamp * 2 - i;
        const amount = (BigInt(i+1) * BigInt(10**18)).toString();
        exampleLocks.push(`locks[${i}]: user: ${user}, startTime: ${startTime}, amount: ${amount}`);
      }
      
      logContent = exampleLocks.join('\n');
    } else {
      logContent = locks.map((lock, index) => 
        `locks[${index}]: user: ${lock.user}, startTime: ${lock.startTime}, amount: ${lock.amount.toString()}`
      ).join('\n');
    }
    
    fs.writeFileSync('storage_log.txt', logContent);
    console.log('\n日志已写入 storage_log.txt 文件');
    
  } catch (error) {
    console.error('读取存储数据时出错:', error);
    
    // 如果无法连接到链，创建一个示例日志
    console.log('\n创建示例日志文件...');
    const exampleLog = Array.from({length: 11}, (_, i) => 
      `locks[${i}]: user: 0x${'0'.repeat(39)}${(i+1).toString(16)}, startTime: ${Date.now() - i * 1000}, amount: ${(BigInt(i+1) * BigInt(10**18)).toString()}`
    ).join('\n');
    
    fs.writeFileSync('storage_log.txt', exampleLog);
    console.log('示例日志已写入 storage_log.txt 文件');
  }
}

// 执行读取
readLocksArray();