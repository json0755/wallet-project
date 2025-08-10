# Meme Token Factory

一个基于以太坊的Meme代币工厂合约，使用最小代理模式（EIP-1167）实现低成本代币部署，并集成Uniswap V2流动性功能。

## 🚀 新功能特性

### 1. 费用与流动性优化
- **费用调整**: 将平台费用从1%提升至5%
- **自动流动性**: 5%的ETH费用自动储备用于流动性添加
- **流动性管理**: 通过Uniswap V2Router自动添加MyToken/ETH流动性
- **价格锚定**: 首次添加流动性时以mint价格作为初始价格

### 2. 智能购买功能
- **价格比较**: `buyMeme()`函数自动比较Uniswap价格与铸造价格
- **优化购买**: 仅在Uniswap价格优于设定起始价格时执行购买
- **价格检测**: 集成Uniswap价格检测逻辑，确保最优交易

### 3. Sepolia测试网集成
- **Uniswap V2Router**: `0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98`
- **Uniswap V2Factory**: `0xB7f907f7A9eBC822a80BD25E224be42Ce0A698A0`
- **WETH合约**: `0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14`
- **兼容性**: 完全兼容anvil fork Sepolia的本地测试环境

### 4. 增强的安全性
- **暂停机制**: 合约暂停功能，紧急情况下可暂停所有操作
- **重入保护**: 所有关键函数都有重入攻击保护
- **权限管理**: 严格的权限控制和所有权管理
- **紧急提取**: 所有者可紧急提取滞留资金

## 📋 核心功能

### MemeFactory 工厂合约
- 使用最小代理模式部署代币，降低gas成本
- 统一管理所有创建的代币信息
- 实现5%平台费用分配机制
- 集成Uniswap V2流动性添加功能
- 提供代币购买价格比较功能

### MemeToken 代币合约
- 标准ERC20代币实现
- 支持批量铸造和供应量上限
- 代理友好的初始化机制
- 流动性专用铸造函数

## 🛠 部署和使用

### 环境要求
- Foundry框架
- Node.js (可选，用于前端集成)
- Sepolia测试网RPC端点

### 快速开始

1. **克隆项目**
```bash
git clone <repository-url>
cd Meme
```

2. **安装依赖**
```bash
forge install
```

3. **编译合约**
```bash
forge build
```

4. **运行测试**
```bash
forge test
```

### 部署脚本

#### 基础部署
```bash
# 设置环境变量
export PRIVATE_KEY=your_private_key
export RPC_URL=https://sepolia.infura.io/v3/your_key

# 部署工厂合约
forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --broadcast
```

#### 完整部署和初始化
```bash
# 可选：自定义代币参数
export TOKEN_SYMBOL="MYMEME"
export TOKEN_TOTAL_SUPPLY=2000000000000000000000000  # 2M tokens
export TOKEN_PER_MINT=5000000000000000000000       # 5K tokens
export TOKEN_PRICE=2000000000000000               # 0.002 ETH

# 部署并创建示例代币
forge script script/DeployAndInit.s.sol:DeployAndInitScript --rpc-url $RPC_URL --broadcast
```

### 本地测试（Anvil Fork）
```bash
# 启动本地Sepolia分叉
anvil --fork-url https://sepolia.infura.io/v3/your_key

# 在新终端中部署
export RPC_URL=http://localhost:8545
forge script script/DeployAndInit.s.sol:DeployAndInitScript --rpc-url $RPC_URL --broadcast
```

## 📖 API 参考

### MemeFactory 主要函数

#### `deployMeme(string symbol, uint256 totalSupply, uint256 perMint, uint256 price)`
部署新的Meme代币
- `symbol`: 代币符号
- `totalSupply`: 最大总供应量
- `perMint`: 每次铸造数量
- `price`: 每个代币价格（wei）

#### `mintMeme(address tokenAddr) payable`
铸造代币（需要支付费用）
- 自动分配5%平台费用到储备金
- 95%费用分配给代币创建者

#### `buyMeme(address tokenAddr) payable`
从Uniswap购买代币（价格优化）
- 自动比较Uniswap价格与铸造价格
- 仅在Uniswap价格更优时执行

#### `addLiquidity(address tokenAddr)`
添加流动性到Uniswap
- 使用储备的ETH和新铸造的代币
- LP代币发送给代币创建者

#### `getTokenInfo(address tokenAddr)`
获取代币详细信息
- 返回：符号、供应量、价格、创建者、当前供应量、铸造状态、流动性状态

#### `calculateMintCost(address tokenAddr)`
计算铸造费用
- 返回：总费用、平台费用、创建者费用

#### `getReserves(address tokenAddr)`
获取储备金信息
- 返回：ETH储备金数量

### 管理员函数

#### `togglePause()`
切换合约暂停状态（仅所有者）

#### `emergencyWithdraw()`
紧急提取合约余额（仅所有者）

## 🔧 费用机制

### 铸造费用分配（5%平台费）
```
总费用 = perMint × price
平台费 = 总费用 × 5% → 储备金（用于流动性）
创建者费 = 总费用 × 95% → 直接转账给创建者
```

### 流动性添加机制
1. 储备金累积到足够数量
2. 计算所需代币数量（基于mint价格）
3. 铸造相应数量的代币
4. 通过Uniswap Router添加流动性
5. LP代币发送给代币创建者

## 🧪 测试

### 运行完整测试套件
```bash
forge test -vv
```

### 运行特定测试
```bash
# 测试部署功能
forge test --match-test testDeployMeme -vv

# 测试铸造功能
forge test --match-test testMintMeme -vv

# 测试费用计算
forge test --match-test testCalculateMintCost -vv
```

### Gas报告
```bash
forge test --gas-report
```

## 🔒 安全考虑

### 已实现的安全措施
- **重入保护**: 使用OpenZeppelin的ReentrancyGuard
- **权限控制**: 基于Ownable的访问控制
- **参数验证**: 所有输入参数的完整性检查
- **溢出保护**: Solidity 0.8+的内置溢出检查
- **暂停机制**: 紧急情况下的合约暂停功能

### 注意事项
- 代币创建者需要信任工厂合约的实现
- 流动性添加是不可逆的操作
- 平台费用比例是固定的（5%）
- Uniswap价格可能受到滑点影响

## 📄 许可证

MIT License - 详见 [LICENSE](LICENSE) 文件

## 🤝 贡献

欢迎提交Issue和Pull Request来改进项目！

## 📞 联系方式

如有问题或建议，请通过以下方式联系：
- GitHub Issues
- 项目维护者邮箱

---

**免责声明**: 本项目仅用于教育和测试目的。在主网部署前请进行充分的安全审计。
