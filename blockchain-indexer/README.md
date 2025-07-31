# 区块链数据索引器 - 本地Anvil版本

基于以太坊的ERC20转账数据索引与查询系统，专为本地Anvil测试网络优化。

## 🚀 快速开始

### 1. 启动本地区块链网络

```bash
# 启动 Anvil 本地网络
anvil
```

Anvil 将在 `http://localhost:8545` 启动，Chain ID 为 `31337`。

### 2. 安装依赖

```bash
# 安装后端依赖
npm install

# 安装前端依赖
cd frontend && npm install
```

### 3. 配置环境

项目已预配置本地Anvil网络设置：
- RPC URL: `http://localhost:8545`
- Chain ID: `31337`
- 起始区块: `0` (创世区块)
- 批处理大小: `100`
- 索引间隔: `10秒`

### 4. 部署测试Token合约 (可选)

如果需要测试真实的ERC20转账，可以部署测试Token：

```bash
# 使用 Foundry 部署测试合约
forge create --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 src/BaseERC20.sol:BaseERC20
```

### 5. 启动服务

```bash
# 启动后端服务
npm run dev

# 在新终端启动前端
cd frontend
npm start
```

前端应用将在 `http://localhost:3000` 启动，后端API在 `http://localhost:3001`。

## 📊 API 接口

### 基础信息
- 后端服务: `http://localhost:3001`
- 前端应用: `http://localhost:3000`

### 主要接口

#### 1. 获取地址交易记录
```http
GET /api/transactions/:address?page=1&limit=50
```

#### 2. 获取地址交易统计
```http
GET /api/transactions/:address/summary
```

#### 3. 获取支持的Token列表
```http
GET /api/tokens
```

#### 4. 获取系统统计
```http
GET /api/stats
```

#### 5. 健康检查
```http
GET /health
```

## 🔧 配置说明

### 环境变量

| 变量名 | 默认值 | 说明 |
|--------|--------|------|
| `PORT` | `3001` | 后端服务端口 |
| `RPC_URL` | `http://localhost:8545` | Anvil RPC地址 |
| `CHAIN_ID` | `31337` | Anvil网络ID |
| `START_BLOCK` | `0` | 索引起始区块 |
| `BATCH_SIZE` | `100` | 批处理大小 |
| `INDEXER_INTERVAL` | `10000` | 索引间隔(毫秒) |

### 测试Token地址

默认配置的测试Token地址（Anvil确定性部署）：
- TEST1: `0x5FbDB2315678afecb367f032d93F642f64180aa3`
- TEST2: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
- TEST3: `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0`

## 🧪 测试流程

### 1. 生成测试数据

```bash
# 使用 Anvil 预设账户进行转账测试
cast send 0x5FbDB2315678afecb367f032d93F642f64180aa3 "transfer(address,uint256)" 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 1000000000000000000 --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### 2. 查询索引数据

```bash
# 查询地址交易记录
curl "http://localhost:3001/api/transactions/0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"

# 查看系统统计
curl "http://localhost:3001/api/stats"
```

## 📁 项目结构

```
blockchain-indexer/
├── backend/                 # 后端服务
│   ├── database/           # 数据库模块
│   │   └── sqlite.js       # SQLite操作
│   ├── indexer/            # 区块链索引器
│   │   └── ethIndexer.js   # 以太坊事件索引
│   ├── routes/             # API路由
│   │   └── transactions.js # 交易查询接口
│   └── server.js           # 服务器入口
├── frontend/               # 前端应用
│   ├── src/                # React源码
│   └── package.json        # 前端依赖
├── .env                    # 环境配置
├── .env.example            # 配置模板
└── package.json            # 后端依赖
```

## 🔍 功能特性

### 后端功能
- ✅ **本地网络优化**: 专为Anvil本地网络配置
- ✅ **实时索引**: 自动监听新的Transfer事件
- ✅ **历史数据**: 从创世区块开始完整索引
- ✅ **高性能查询**: SQLite数据库优化索引
- ✅ **RESTful API**: 标准化接口设计
- ✅ **分页支持**: 大数据量友好查询
- ✅ **错误处理**: 完善的异常处理机制
- ✅ **开发友好**: 详细日志和调试信息

### 前端功能
- 🎨 **现代化UI**: 基于Material-UI的响应式设计
- 💼 **钱包集成**: MetaMask连接和Anvil网络自动切换
- 📊 **数据可视化**: 实时统计图表和交易列表
- 🔍 **智能搜索**: 地址搜索和交易记录查询
- 📱 **移动友好**: 适配各种屏幕尺寸
- 🔔 **实时通知**: Toast提示和状态反馈
- ⚡ **快速导航**: 直观的页面布局和导航
- 🛡️ **网络验证**: 自动检测和提示网络状态

## 🐛 故障排除

### 常见问题

#### 后端问题
1. **连接失败**: 确保Anvil正在运行
   ```bash
   anvil
   ```

2. **端口冲突**: 修改`.env`中的`PORT`配置

3. **数据库错误**: 删除`backend/data/transactions.db`重新初始化

4. **Token地址错误**: 部署新合约后更新`TARGET_TOKENS`配置

#### 前端问题
1. **钱包连接失败**: 确保已安装MetaMask浏览器扩展

2. **网络切换失败**: 确保Anvil节点正在运行在正确端口

3. **API请求失败**: 检查后端服务是否在3001端口运行

4. **页面空白**: 检查浏览器控制台错误信息

### 调试模式

```bash
# 启用详细日志
NODE_ENV=development npm run dev
```

## 📝 开发说明

- 数据库文件: `backend/data/transactions.db`
- 日志级别: 开发模式下显示详细信息
- 热重载: 使用nodemon自动重启
- 网络验证: 自动检查Chain ID匹配

---

🔗 **本地Anvil网络专用版本** - 快速开发和测试区块链数据索引功能