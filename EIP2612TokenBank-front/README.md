# EIP2612 Token Bank Frontend

基于 Permit2 的无Gas授权存款系统前端应用。

## 功能特性

- 🚀 **Permit2 存款**: 一键签名存款，无需预先授权，节省Gas费用
- 📝 **标准存款**: 传统的授权+存款方式
- 💰 **余额查看**: 实时显示Token余额、银行余额和Permit2授权额度
- 🔗 **钱包连接**: 支持MetaMask等主流钱包
- 🎨 **美观界面**: 基于Ant Design的现代化UI设计

## 技术栈

- **前端框架**: Next.js 14 + React 18
- **UI组件库**: Ant Design
- **样式**: Tailwind CSS
- **区块链交互**: Wagmi + Ethers.js
- **类型检查**: TypeScript

## 合约地址 (Anvil本地网络)

- **EIP2612 Token**: `0xe7f1725E7734CE288F8367e1Bb143E90bb3F0512`
- **Token Bank**: `0x9fE46736679d2D9a65F0992F2272dE9f3c7fa6e0`
- **Permit2**: `0x000000000022D473030F116dDEE9F6B43aC78BA3`

## 安装和运行

### 1. 安装依赖

```bash
npm install
```

### 2. 启动开发服务器

```bash
npm run dev
```

### 3. 访问应用

打开浏览器访问 [http://localhost:3000](http://localhost:3000)

## 使用说明

### 前置条件

1. 确保本地Anvil网络正在运行 (`anvil`)
2. 在钱包中添加Anvil网络配置:
   - 网络名称: Anvil
   - RPC URL: http://127.0.0.1:8545
   - 链ID: 31337
   - 货币符号: ETH

### 操作流程

1. **连接钱包**: 点击"连接钱包"按钮连接MetaMask
2. **查看余额**: 连接后自动显示Token余额、银行余额等信息
3. **存款操作**:
   - **Permit2存款**: 输入金额后点击"Permit2存款"，只需一次签名即可完成存款
   - **标准存款**: 输入金额后点击"标准存款"，需要先授权再存款（两次交易）

## 项目结构

```
src/
├── abi/                 # 合约ABI文件
│   ├── EIP2612Token.ts
│   ├── EIP2612TokenBank.ts
│   ├── Permit2.ts
│   └── index.ts
├── app/                 # Next.js应用页面
│   ├── globals.css
│   ├── layout.tsx
│   └── page.tsx
├── config/              # 配置文件
│   ├── contracts.ts     # 合约地址配置
│   └── wagmi.ts         # Wagmi配置
├── types/               # TypeScript类型定义
│   └── global.d.ts
└── utils/               # 工具函数
    └── ethers.ts        # Ethers.js工具函数
```

## 开发说明

### Permit2 签名流程

1. 创建PermitSingle数据结构
2. 使用EIP-712标准进行签名
3. 调用合约的`depositWithPermit2`方法

### 主要工具函数

- `createPermit2Signature`: 创建Permit2签名
- `createTokenContract`: 创建Token合约实例
- `createTokenBankContract`: 创建TokenBank合约实例
- `createPermit2Contract`: 创建Permit2合约实例

## 注意事项

1. 确保Anvil网络正在运行
2. 确保钱包已连接到正确的网络
3. 确保账户有足够的ETH支付Gas费用
4. 确保账户有足够的Token余额进行存款

## 故障排除

### 常见问题

1. **钱包连接失败**: 检查MetaMask是否已安装并解锁
2. **交易失败**: 检查网络连接和Gas费用设置
3. **余额不更新**: 刷新页面或重新连接钱包

### 开发调试

```bash
# 检查代码格式
npm run lint

# 构建项目
npm run build

# 启动生产服务器
npm start
```