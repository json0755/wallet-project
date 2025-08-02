# Anvil 本地网络部署指南

本指南介绍如何在 Anvil 本地网络上部署和测试 AirdropMerkleNFTMarket 项目。

## 前置条件

确保已安装 Foundry 工具链：
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

## 启动 Anvil 本地网络

在一个终端窗口中启动 Anvil：
```bash
anvil
```

Anvil 将在 `http://127.0.0.1:8545` 上运行，并提供 10 个预配置的账户。

## 默认账户信息

- **Account 0 (Deployer)**: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
  - Private Key: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
  - 余额: 10000 ETH

- **Account 1 (Whitelist User)**: `0x70997970C51812dc3A010C7d01b50e0d17dc79C8`
  - Private Key: `0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d`
  - 余额: 10000 ETH

- **Account 2 (Normal User)**: `0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC`
  - Private Key: `0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a`
  - 余额: 10000 ETH

## 部署合约

### 方法 1: 使用部署脚本

```bash
./deploy-anvil.sh
```

### 方法 2: 手动部署

```bash
forge script script/DeployAirdopMerkleNFTMarket.s.sol:DeployAirdopMerkleNFTMarket \
    --rpc-url anvil \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast \
    --verify \
    -vvvv
```

## 运行测试

### 运行所有测试
```bash
forge test --match-path test/AirdopMerkleNFTMarket.t.sol -vv
```

### 运行特定测试
```bash
forge test --match-test testPermitPrePay -vv
forge test --match-test testMulticallPermitAndClaim -vv
```

## 配置文件说明

### foundry.toml
项目已配置了 Anvil 网络端点：
```toml
[rpc_endpoints]
anvil = "http://127.0.0.1:8545"

[etherscan]
anvil = { key = "dummy", url = "http://127.0.0.1:8545" }
```

### .env
环境变量配置：
```bash
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
RPC_URL=http://127.0.0.1:8545
CHAIN_ID=31337
```

## 合约交互示例

部署完成后，你可以使用 `cast` 命令与合约交互：

```bash
# 查看代币余额
cast call <TOKEN_ADDRESS> "balanceOf(address)" <USER_ADDRESS> --rpc-url anvil

# 查看NFT所有者
cast call <NFT_ADDRESS> "ownerOf(uint256)" 1 --rpc-url anvil

# 验证白名单
cast call <MARKET_ADDRESS> "verifyWhitelist(address,bytes32[])" <USER_ADDRESS> "[]" --rpc-url anvil
```

## 故障排除

1. **Anvil 未运行**: 确保在另一个终端中运行了 `anvil` 命令
2. **端口冲突**: 如果 8545 端口被占用，可以使用 `anvil --port 8546` 指定其他端口
3. **私钥错误**: 确保使用的是 Anvil 提供的默认私钥
4. **Gas 不足**: Anvil 默认提供充足的 ETH，通常不会遇到此问题

## 测试结果

所有 12 个测试用例均已通过：
- ✅ testBuyNFTNormal
- ✅ testClaimNFTWithWhitelist
- ✅ testDelistNFT
- ✅ testDeployment
- ✅ testGetDiscountedPrice
- ✅ testListNFT
- ✅ testMulticallPermitAndClaim
- ✅ testPermitPrePay
- ✅ testUpdateMerkleRoot
- ✅ testVerifyWhitelist
- ✅ test_RevertWhen_ClaimTwice
- ✅ test_RevertWhen_ClaimWithInvalidProof