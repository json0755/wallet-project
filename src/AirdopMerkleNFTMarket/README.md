# AirdropMerkleNFTMarket 项目

这是一个基于 Foundry 框架开发的去中心化 NFT 市场，支持基于 Merkle 树的白名单验证和批量交易功能。

## 项目概述

### 核心功能
1. **Merkle 树白名单验证** - 验证用户是否在预设的白名单中
2. **白名单折扣** - 白名单用户享受 50% 的购买折扣
3. **Permit 授权** - 支持 EIP-2612 permit 功能的代币授权
4. **Multicall 批量交易** - 使用 delegatecall 方式批量执行 permit 和购买操作
5. **NFT 市场** - 完整的 NFT 上架、下架、购买功能

### 技术特点
- 使用 Foundry 作为开发框架
- 支持 EIP-2612 Permit 授权
- 基于 Merkle 树的高效白名单验证
- Multicall 模式支持原子性批量操作
- 完整的测试覆盖和部署脚本

## 项目结构

```
src/AirdopMerkleNFTMarket/
├── AirdopMerkleNFTMarket.sol    # 主合约
├── PermitToken.sol              # 支持 Permit 的 ERC20 代币
├── AirdropNFT.sol               # ERC721 NFT 合约
├── MerkleProof.sol              # Merkle 树验证库
├── Multicall.sol                # Multicall 抽象合约
├── MulticallHelper.sol          # Multicall 辅助工具
├── MerkleTreeBuilder.js         # Merkle 树构建工具
└── README.md                    # 项目文档

test/
└── AirdopMerkleNFTMarket.t.sol  # 完整测试用例

script/
└── DeployAirdopMerkleNFTMarket.s.sol  # 部署脚本
```

## 合约详解

### 1. AirdopMerkleNFTMarket.sol
主合约，集成了所有核心功能：

**状态变量：**
- `token`: ERC20 代币合约地址
- `nft`: ERC721 NFT 合约地址
- `merkleRoot`: Merkle 树根哈希
- `listings`: NFT 上架信息映射
- `hasClaimed`: 用户领取状态映射

**核心函数：**
- `permitPrePay()`: 使用 permit 进行代币授权
- `claimNFT()`: 白名单用户领取 NFT（50% 折扣）
- `buyNFT()`: 普通用户购买 NFT（原价）
- `listNFT()` / `delistNFT()`: NFT 上架/下架
- `multicall()`: 批量执行多个函数调用

### 2. PermitToken.sol
支持 EIP-2612 Permit 功能的 ERC20 代币：
- 标准 ERC20 功能
- Permit 离线授权
- 铸造和批量铸造功能

### 3. AirdropNFT.sol
ERC721 NFT 合约：
- 标准 ERC721 功能
- 铸造和批量铸造
- 市场合约权限管理

### 4. MerkleProof.sol
Merkle 树验证库：
- 单个证明验证
- 批量证明验证
- 高效的哈希计算

### 5. Multicall.sol
抽象合约，提供批量调用功能：
- `multicall()`: 批量执行，失败时回滚
- `tryMulticall()`: 批量执行，允许部分失败
- `multicallWithGasLimit()`: 带 Gas 限制的批量执行

### 6. MulticallHelper.sol
辅助工具，用于创建批量调用数据：
- 编码各种函数调用
- 创建常用的批量操作组合
- 简化前端集成

## 使用流程

### 1. 部署合约
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key

# 部署到本地网络
forge script script/DeployAirdopMerkleNFTMarket.s.sol --rpc-url http://localhost:8545 --broadcast

# 部署到测试网
forge script script/DeployAirdopMerkleNFTMarket.s.sol --rpc-url $RPC_URL --broadcast --verify
```

### 2. 构建 Merkle 树
```javascript
// 使用 MerkleTreeBuilder.js
const { MerkleTreeBuilder } = require('./src/AirdopMerkleNFTMarket/MerkleTreeBuilder.js');

const whitelist = [
    '0x70997970C51812dc3A010C7d01b50e0d17dc79C8',
    '0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC',
    // ... 更多地址
];

const builder = new MerkleTreeBuilder(whitelist);
const root = builder.getRoot();
const proof = builder.getProof('0x70997970C51812dc3A010C7d01b50e0d17dc79C8');
```

### 3. 白名单用户使用 Multicall 购买 NFT

**步骤 1: 创建 Permit 签名**
```javascript
// 前端代码示例
const permitData = {
    owner: userAddress,
    spender: marketAddress,
    value: discountedPrice,
    deadline: Math.floor(Date.now() / 1000) + 3600, // 1小时后过期
};

const signature = await signPermit(permitData);
```

**步骤 2: 创建 Multicall 数据**
```solidity
// 使用 MulticallHelper
MulticallHelper.PermitData memory permitData = MulticallHelper.PermitData({
    owner: msg.sender,
    spender: address(this),
    value: discountedPrice,
    deadline: deadline,
    v: v,
    r: r,
    s: s
});

bytes[] memory calls = helper.createPermitAndClaimData(
    permitData,
    tokenId,
    merkleProof
);
```

**步骤 3: 执行 Multicall**
```solidity
// 一次性执行 permit 和 claimNFT
market.multicall(calls);
```

## 测试

### 运行所有测试
```bash
forge test
```

### 运行特定测试
```bash
# 测试 Multicall 功能
forge test --match-test testMulticallPermitAndClaim

# 测试白名单验证
forge test --match-test testVerifyWhitelist

# 测试折扣购买
forge test --match-test testClaimNFTWithWhitelist
```

### 测试覆盖率
```bash
forge coverage
```

## 主要测试用例

1. **基础功能测试**
   - 合约部署验证
   - NFT 上架/下架
   - 白名单验证

2. **购买流程测试**
   - 白名单用户折扣购买
   - 普通用户正常购买
   - Permit 授权功能

3. **Multicall 测试**
   - Permit + ClaimNFT 批量执行
   - 原子性验证

4. **边界条件测试**
   - 重复领取防护
   - 无效 Merkle 证明
   - 权限验证

## 安全考虑

### 1. 重入攻击防护
- 使用 `ReentrancyGuard` 修饰符
- 遵循 Checks-Effects-Interactions 模式

### 2. 权限控制
- 使用 `Ownable` 进行管理员权限控制
- NFT 转移权限验证

### 3. 输入验证
- Merkle 证明验证
- 地址和数值有效性检查

### 4. 状态管理
- 防止重复领取
- NFT 状态同步

## Gas 优化

1. **批量操作**: 使用 Multicall 减少交易次数
2. **存储优化**: 合理设计存储布局
3. **事件日志**: 使用事件记录重要状态变化
4. **Merkle 树**: 高效的白名单验证方式

## 扩展功能

### 可能的扩展方向
1. **动态定价**: 基于时间或需求的动态价格调整
2. **多级折扣**: 不同等级的白名单用户享受不同折扣
3. **拍卖机制**: 支持英式拍卖或荷兰式拍卖
4. **版税分配**: 支持创作者版税自动分配
5. **跨链支持**: 支持多链部署和跨链交易

## 故障排除

### 常见问题

1. **Permit 签名失败**
   - 检查 deadline 是否过期
   - 验证签名参数是否正确
   - 确认 nonce 值是否匹配

2. **Merkle 证明验证失败**
   - 确认地址在白名单中
   - 检查证明路径是否正确
   - 验证 Merkle 根是否更新

3. **NFT 转移失败**
   - 检查 NFT 所有权
   - 确认市场合约授权
   - 验证 NFT 是否已上架

### 调试技巧

1. 使用 `console.log` 进行调试
2. 检查事件日志获取详细信息
3. 使用 `forge test -vvv` 获取详细测试输出

## 许可证

MIT License - 详见 LICENSE 文件

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

## 联系方式

如有问题或建议，请通过以下方式联系：
- GitHub Issues
- 邮箱：[your-email@example.com]