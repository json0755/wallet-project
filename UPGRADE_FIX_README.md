# NFT Market 升级脚本修复说明

## 修复的问题

### 1. 升级模式不匹配（关键问题）

**原问题：**
- `NFTMarketV1.sol` 继承了 `UUPSUpgradeable`，使用UUPS升级模式
- `UpgradeMarket.s.sol` 脚本使用 `TransparentUpgradeableProxy` 和 `ProxyAdmin`，这是透明代理升级模式
- 两种升级模式不兼容，导致升级失败

**修复方案：**
- 移除对 `TransparentUpgradeableProxy` 和 `ProxyAdmin` 的依赖
- 改用UUPS升级模式，直接调用代理合约的 `upgradeToAndCall` 函数
- 简化升级流程，匹配 `NFTMarketV1` 的升级架构

### 2. NFTMarketV2 代码逻辑问题

**签名验证不完整：**
- 原 `LISTING_PARAMS_TYPEHASH` 缺少 `nftContract` 参数
- 修复：在类型哈希中包含NFT合约地址，防止跨合约签名重放攻击

**授权检查优化：**
- 改进了NFT授权验证的错误信息
- 确保完整的授权检查逻辑

## 修复后的文件

### 1. UpgradeMarket.s.sol

**主要变更：**
```solidity
// 移除透明代理相关导入
- import "@openzeppelin/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
- import "@openzeppelin/contracts/proxy/transparent/ProxyAdmin.sol";

// 添加UUPS相关导入
+ import "../src/upgrade/NFTMarketV1.sol";
+ import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";

// 移除ProxyAdmin相关代码
- address public proxyAdmin;
- ProxyAdmin admin = ProxyAdmin(proxyAdmin);
- admin.upgradeAndCall(...);

// 使用UUPS升级模式
+ NFTMarketV1 proxyAsV1 = NFTMarketV1(marketProxy);
+ proxyAsV1.upgradeToAndCall(address(marketV2Implementation), initV2Data);
```

**环境变量变更：**
- 移除 `PROXY_ADMIN_ADDRESS` 要求
- 只需要 `MARKET_PROXY_ADDRESS` 和 `PRIVATE_KEY`

### 2. NFTMarketV2.sol

**签名验证修复：**
```solidity
// 修复类型哈希定义
- "ListingParams(uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"
+ "ListingParams(address nftContract,uint256 tokenId,uint256 price,uint256 nonce,uint256 deadline)"

// 修复结构化数据哈希构建
bytes32 structHash = keccak256(
    abi.encode(
        LISTING_PARAMS_TYPEHASH,
+       nftContract,  // 添加NFT合约地址
        params.tokenId,
        params.price,
        params.nonce,
        params.deadline
    )
);
```

## 使用方法

### 1. 设置环境变量

```bash
# 设置私钥
export PRIVATE_KEY="your_private_key_here"

# 设置市场代理地址（从 nft-deployment-addresses.txt 获取）
export MARKET_PROXY_ADDRESS="0x15EA5A9eb2C4679dee0b39c51a2AdF76427eBA6C"

# 设置RPC URL
export RPC_URL="https://sepolia.infura.io/v3/your_project_id"
```

### 2. 运行升级脚本

**方法一：使用环境变量**
```bash
forge script script/UpgradeMarket.s.sol:UpgradeMarket --rpc-url $RPC_URL --broadcast --verify -vvvv
```

**方法二：使用文件地址（需要修改脚本）**
```bash
# 调用 runWithFileAddresses 函数
forge script script/UpgradeMarket.s.sol:UpgradeMarket --sig "runWithFileAddresses()" --rpc-url $RPC_URL --broadcast --verify -vvvv
```

**方法三：使用测试脚本**
```bash
./test-upgrade.sh
```

### 3. 验证升级结果

升级成功后，脚本会：
1. 输出升级信息到控制台
2. 验证V2功能（Domain Separator、nonce等）
3. 保存升级信息到 `market-upgrade-info.txt`

## 重要注意事项

1. **权限要求：** 执行升级的账户必须是NFTMarketV1合约的owner
2. **网络配置：** 确保RPC_URL指向正确的网络
3. **地址验证：** 升级前请确认 `MARKET_PROXY_ADDRESS` 是正确的代理合约地址
4. **Gas费用：** 升级操作需要消耗一定的gas费用

## 安全改进

1. **防重放攻击：** 签名验证现在包含NFT合约地址，防止跨合约重放
2. **完整授权检查：** 确保NFT授权验证的完整性
3. **UUPS升级安全：** 只有合约owner可以执行升级操作

## 故障排除

如果升级失败，请检查：
1. 环境变量是否正确设置
2. 执行账户是否为合约owner
3. 代理合约地址是否正确
4. 网络连接是否正常
5. Gas费用是否充足