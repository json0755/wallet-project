# 区块链数据索引器 - 前端应用

这是一个基于React的前端应用，用于展示和查询Anvil本地网络上的ERC20代币转账数据。

## 🚀 功能特性

### 💼 钱包集成
- **MetaMask连接**: 支持MetaMask钱包连接和断开
- **网络检测**: 自动检测当前网络，提示切换到Anvil本地网络
- **网络切换**: 一键切换到Anvil网络 (Chain ID: 31337)
- **账户监听**: 实时监听账户和网络变化

### 📊 数据展示
- **实时统计**: 显示总交易数、索引区块范围、支持代币等统计信息
- **交易查询**: 支持按地址查询ERC20转账记录
- **分页浏览**: 支持大量数据的分页显示
- **交易分类**: 区分发送和接收交易，提供直观的视觉标识

### 🎨 用户界面
- **Material-UI设计**: 现代化的UI组件和主题
- **响应式布局**: 适配桌面和移动设备
- **实时通知**: 使用Toast提示用户操作结果
- **加载状态**: 优雅的加载动画和错误处理

## 🛠️ 技术栈

- **React 18**: 前端框架
- **Material-UI v5**: UI组件库
- **React Router v6**: 路由管理
- **Ethers.js v6**: 以太坊交互库
- **Axios**: HTTP客户端
- **React Toastify**: 通知组件
- **Moment.js**: 时间处理

## 📦 安装和运行

### 前置要求
- Node.js >= 16.0.0
- npm 或 yarn
- 已启动的Anvil本地网络
- 已运行的后端API服务

### 安装依赖
```bash
cd frontend
npm install
```

### 启动开发服务器
```bash
npm start
```

应用将在 http://localhost:3000 启动，并自动代理API请求到 http://localhost:3001

### 构建生产版本
```bash
npm run build
```

## 🔧 配置说明

### 网络配置
前端应用已预配置为连接Anvil本地网络：
- **Chain ID**: 31337
- **RPC URL**: http://localhost:8545
- **网络名称**: Anvil Local Network

### API代理
开发环境下，前端会自动将API请求代理到后端服务器：
```json
{
  "proxy": "http://localhost:3001"
}
```

## 📱 页面功能

### 🏠 首页 (`/`)
- 系统概览和统计数据
- 网络连接状态显示
- 功能介绍和快速导航

### 📋 交易记录 (`/transactions`)
- 地址搜索功能
- 交易列表展示
- 分页浏览支持
- 交易摘要统计
- "查询我的交易"快捷功能

### 📊 统计数据 (`/stats`)
- 详细的系统统计信息
- 索引进度显示
- 支持的代币列表
- 数据库状态信息

## 🔌 钱包使用指南

### 连接MetaMask
1. 确保已安装MetaMask浏览器扩展
2. 点击右上角"连接钱包"按钮
3. 在MetaMask中确认连接请求

### 切换到Anvil网络
1. 连接钱包后，如果不在正确网络，会显示警告
2. 点击网络状态芯片或按提示操作
3. 系统会自动添加Anvil网络配置

### 查询交易记录
1. 在交易记录页面输入以太坊地址
2. 或者连接钱包后点击"查询我的交易"
3. 浏览分页结果，查看交易详情

## 🎯 开发指南

### 项目结构
```
src/
├── components/          # 可复用组件
│   ├── WalletConnect.js # 钱包连接组件
│   └── Navigation.js    # 导航组件
├── contexts/            # React Context
│   └── WalletContext.js # 钱包状态管理
├── pages/              # 页面组件
│   ├── HomePage.js     # 首页
│   ├── TransactionsPage.js # 交易记录页
│   └── StatsPage.js    # 统计页面
├── App.js              # 主应用组件
├── index.js            # 应用入口
└── index.css           # 全局样式
```

### 添加新功能
1. 在相应目录创建新组件
2. 更新路由配置（如需要）
3. 添加必要的API调用
4. 更新导航菜单（如需要）

### 样式定制
- 修改 `src/index.js` 中的Material-UI主题配置
- 在 `src/App.css` 中添加自定义CSS
- 使用Material-UI的sx属性进行组件级样式定制

## 🐛 故障排除

### 常见问题

**1. 钱包连接失败**
- 确保已安装MetaMask
- 检查浏览器是否阻止了弹窗
- 尝试刷新页面重新连接

**2. 网络切换失败**
- 确保Anvil节点正在运行
- 检查RPC URL是否正确 (http://localhost:8545)
- 手动在MetaMask中添加网络

**3. API请求失败**
- 确保后端服务正在运行 (http://localhost:3001)
- 检查浏览器控制台的错误信息
- 验证代理配置是否正确

**4. 数据不显示**
- 确保后端已开始索引数据
- 检查Anvil网络上是否有ERC20转账交易
- 验证代币地址配置是否正确

### 调试技巧
- 打开浏览器开发者工具查看控制台日志
- 检查Network标签页的API请求状态
- 使用React Developer Tools检查组件状态

## 📄 许可证

MIT License