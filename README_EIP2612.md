# EIP2612 TokenBank 部署和测试指南

本指南介绍如何部署和测试 EIP2612Token、EIP2612TokenBank 和 Permit2 合约的完整功能。

## 📋 概述

本项目包含以下核心合约：
- **EIP2612Token**: 支持 EIP2612 permit 功能的 ERC20 代币
- **EIP2612TokenBank**: 基于 ERC4626 的代币金库，支持 permit 存取款
- **Permit2**: 高级签名转账合约，支持批量操作和精细权限控制

## 🚀 快速开始

### 1. 环境准备

```bash
# 启动本地 Anvil 节点
anvil --host 0.0.0.0 --port 8545
```

### 2. 一键部署和测试

```bash
# 运行一体化脚本（包含部署、配置和测试）
./deploy_eip2612_tokenbank.sh

# 或使用npm脚本
npm run deploy-eip2612
```

脚本会自动完成：
- 编译所有合约
- 部署 Permit2、EIP2612Token 和 EIP2612TokenBank
- 设置测试账户和初始代币分发
- 进行基本功能验证
- 运行高级功能测试

## 🔧 账户配置

### 预设账户地址

| 角色 | 地址 | 初始代币余额 |
|------|------|-------------|
| Admin | `0xf39fd6e51aad88f6f4ce6ab8827279cfffb92266` | 975,000 tokens |
| User1 | `0x70997970c51812dc3a010c7d01b50e0d17dc79c8` | 10,000 tokens |
| User2 | `0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc` | 5,000 tokens |
| User3 | `0x90f79bf6eb2c4f870365e785982e1f101e93b906` | 2,000 tokens |

### 私钥（仅用于测试）

```bash
ADMIN_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
USER1_PRIVATE_KEY="0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d"
USER2_PRIVATE_KEY="0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a"
USER3_PRIVATE_KEY="0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6"
```

## 📝 签名生成工具

脚本内置了签名生成功能，部署完成后会自动演示各种签名操作：

### EIP2612 Permit 签名

```bash
# 脚本内置函数，自动生成 ERC20 token permit 签名
# 示例：User2 授权 User3 转移 1000 个代币
generate_eip2612_permit $TOKEN_ADDRESS $USER2_PRIVATE_KEY $USER3_ADDRESS 1000000000000000000000
```

### Vault Permit 签名

```bash
# 脚本内置函数，自动生成 vault permit 签名
# 示例：User1 授权 User3 转移 500 个 vault 份额
generate_vault_permit $TOKENBANK_ADDRESS $USER1_PRIVATE_KEY $USER3_ADDRESS 500000000000000000000
```

### Permit2 签名

```bash
# 脚本内置函数，自动生成 Permit2 转账签名
# 示例：User2 通过 Permit2 转移 800 个代币给 User3
generate_permit2_signature $PERMIT2_ADDRESS $USER2_PRIVATE_KEY $TOKEN_ADDRESS 800000000000000000000 $USER3_ADDRESS
```

## 🔍 功能特性

### EIP2612 Token 功能

- ✅ 标准 ERC20 功能
- ✅ EIP2612 permit 无 gas 授权
- ✅ 域分离器和 nonce 管理
- ✅ 签名验证和重放攻击防护

### TokenBank (ERC4626) 功能

- ✅ 代币存取款
- ✅ 份额铸造和销毁
- ✅ Permit 授权存取款
- ✅ 资产和份额转换

### Permit2 功能

- ✅ 签名转账
- ✅ 批量转账
- ✅ 精细权限控制
- ✅ Nonce 位图管理

## 💡 使用场景

### 1. 无 Gas 授权

用户可以通过签名进行代币授权，无需支付 gas 费用：

```solidity
// 用户签名 permit
token.permit(owner, spender, value, deadline, v, r, s);

// 第三方代表用户执行转账
token.transferFrom(owner, recipient, amount);
```

### 2. 批量操作

使用 Permit2 进行多代币批量转账：

```solidity
// 批量转账多个代币
PermitTransferFrom[] memory permits = ...;
SignatureTransferDetails[] memory transfers = ...;
permit2.permitTransferFrom(permits, transfers, owner, signature);
```

### 3. Vault 集成

结合 permit 进行无缝存取款：

```solidity
// 授权 + 存款一步完成
vault.permit(owner, vault, shares, deadline, v, r, s);
vault.deposit(assets, receiver);
```

## 🧪 测试用例

### 基础功能测试

1. **代币分发**: 验证初始代币分配
2. **Vault 存取**: 测试基本存取款功能
3. **授权机制**: 验证 approve/allowance 工作正常

### 高级功能测试

1. **EIP2612 Permit**: 测试无 gas 授权
2. **Vault Permit**: 测试 vault 份额授权
3. **Permit2 转账**: 测试高级签名转账
4. **批量操作**: 测试多代币批量转账

## 📁 文件结构

```
├── src/tokenbank/
│   ├── EIP2612Token.sol          # EIP2612 代币合约
│   ├── EIP2612TokenBank.sol      # ERC4626 金库合约
│   └── Permit2.sol               # Permit2 转账合约
├── script/
│   └── DeployEIP2612TokenBank.s.sol  # Foundry 部署脚本
├── deploy_eip2612_tokenbank.sh   # 一体化部署和测试脚本
└── README_EIP2612.md             # 本文档
```

## 🔗 相关资源

- [EIP-2612: permit – 712-signed approvals](https://eips.ethereum.org/EIPS/eip-2612)
- [ERC-4626: Tokenized Vault Standard](https://eips.ethereum.org/EIPS/eip-4626)
- [Permit2 Documentation](https://docs.uniswap.org/contracts/permit2/overview)
- [Foundry Documentation](https://book.getfoundry.sh/)

## ⚠️ 注意事项

1. **安全性**: 本项目仅用于学习和测试，请勿在生产环境中使用测试私钥
2. **签名验证**: 在生产环境中，务必验证所有签名的有效性和安全性
3. **权限管理**: 合理设置代币授权额度，避免过度授权
4. **Gas 优化**: 在实际使用中，考虑 gas 成本优化

## 🤝 贡献

欢迎提交 Issue 和 Pull Request 来改进本项目！

## 📄 许可证

MIT License