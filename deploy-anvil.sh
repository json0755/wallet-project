#!/bin/bash

# 部署到Anvil本地网络的脚本

echo "Starting Anvil deployment..."

# 检查anvil是否运行
if ! curl -s http://127.0.0.1:8545 > /dev/null; then
    echo "Error: Anvil is not running. Please start anvil first with: anvil"
    exit 1
fi

echo "Anvil is running, proceeding with deployment..."

# 部署合约
forge script script/DeployAirdopMerkleNFTMarket.s.sol:DeployAirdopMerkleNFTMarket \
    --rpc-url anvil \
    --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
    --broadcast \
    --verify \
    -vvvv

echo "Deployment completed!"
echo "You can interact with the contracts using the addresses shown above."
echo "Default anvil accounts:"
echo "  Account 0: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 (Deployer)"
echo "  Account 1: 0x70997970C51812dc3A010C7d01b50e0d17dc79C8 (Whitelist User)"
echo "  Account 2: 0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC (Normal User)"