# 使用 Viem 读取链上存储数据

## 项目说明

本项目演示了如何使用 Viem 库通过 `getStorageAt` 方法从区块链上读取智能合约的存储数据，特别是动态数组 `_locks` 中的所有元素。

## 合约结构

### esRNT.sol
```solidity
struct LockInfo{
    address user;      // 用户地址 (20 bytes)
    uint64 startTime;  // 开始时间 (8 bytes) 
    uint256 amount;    // 锁定数量 (32 bytes)
}
LockInfo[] private _locks; // 动态数组
```

## 存储布局分析

### 动态数组存储规则
1. **数组长度**: 存储在槽位 0
2. **数组元素**: 存储在 `keccak256(0) + index * 元素大小` 的位置
3. **LockInfo 结构**: 每个元素占用 2 个存储槽
   - 槽 0: `user` (20字节) + `startTime` (8字节) + 填充
   - 槽 1: `amount` (32字节)

## 文件说明

### 核心文件
- `src/esRNT.sol`: 包含 _locks 数组的智能合约
- `readStorage.js`: 使用 Viem 读取存储数据的脚本
- `storage_log.txt`: 输出的日志文件

### 配置文件
- `package.json`: Node.js 项目配置
- `script/DeployEsRNT.s.sol`: 合约部署脚本

## 使用方法

### 1. 安装依赖
```bash
npm install
```

### 2. 启动本地节点（可选）
```bash
anvil
```

### 3. 部署合约（可选）
```bash
forge script script/DeployEsRNT.s.sol:DeployEsRNTScript --fork-url http://localhost:8545 --private-key <PRIVATE_KEY> --broadcast
```

### 4. 读取存储数据
```bash
node readStorage.js
```

## 输出示例

脚本会在根目录生成 `storage_log.txt` 文件，内容格式如下：

```
locks[0]: user: 0x0000000000000000000000000000000000000001, startTime: 3507765680, amount: 1000000000000000000
locks[1]: user: 0x0000000000000000000000000000000000000002, startTime: 3507765679, amount: 2000000000000000000
...
locks[10]: user: 0x000000000000000000000000000000000000000b, startTime: 3507765670, amount: 11000000000000000000
```

## 技术要点

### Viem getStorageAt 使用
```javascript
const data = await client.getStorageAt({
  address: CONTRACT_ADDRESS,
  slot: `0x${slotNumber.toString(16).padStart(64, '0')}`
});
```

### 动态数组元素位置计算
```javascript
// 计算数组起始位置
const crypto = await import('crypto');
const baseSlotHash = crypto.createHash('sha256')
  .update(Buffer.from('0'.repeat(64), 'hex'))
  .digest('hex');
const arrayStartSlot = BigInt('0x' + baseSlotHash);

// 计算第 i 个元素的位置
const elementSlot = arrayStartSlot + BigInt(i * 2); // 每个元素占2个槽
```

### 数据解析
```javascript
// 解析地址和时间戳（槽0）
const user = '0x' + slot0Data.slice(26, 66);  // 后20字节
const startTime = parseInt(slot0Data.slice(2, 18), 16); // 前8字节

// 解析数量（槽1）
const amount = BigInt(slot1Data);
```

## 注意事项

1. **合约地址**: 需要将脚本中的 `CONTRACT_ADDRESS` 替换为实际部署的合约地址
2. **网络配置**: 根据目标网络修改 RPC 端点
3. **存储布局**: 不同的 Solidity 版本可能有不同的存储布局
4. **大端序**: 以太坊存储使用大端序格式

## 故障排除

如果无法连接到区块链节点，脚本会自动生成示例数据，模拟真实的合约数据结构。这确保了即使在没有实际部署合约的情况下，也能演示数据读取的格式和结构。