// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

/**
 * @title TestDeploy Script
 * @dev 简化的测试部署脚本，不需要环境变量
 */
contract TestDeployScript is Script {
    function run() external {
        // 开始广播交易
        vm.startBroadcast();
        
        // 部署 MemeFactory
        MemeFactory factory = new MemeFactory();
        
        console.log("=== Meme Token Factory Deployment Test ===");
        console.log("Factory deployed at:", address(factory));
        console.log("Factory owner:", factory.owner());
        console.log("Platform fee: 500 basis points (5%)");
        console.log("Uniswap V2 Router: 0x86dcd3293C53Cf8EFd7303B57beb2a3F671dDE98 (Sepolia)");
        console.log("Uniswap V2 Factory: 0xB7f907f7A9eBC822a80BD25E224be42Ce0A698A0 (Sepolia)");
        console.log("WETH Address: 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14 (Sepolia)");
        console.log("Contract paused:", factory.paused());
        
        // 部署一个测试代币
        address tokenAddr = factory.deployMeme(
            "TEST",
            1000000 * 10**18,  // 1M total supply
            1000 * 10**18,     // 1K per mint
            0.001 ether        // 0.001 ETH per token
        );
        
        console.log("\n=== Test Token Deployed ===");
        console.log("Token address:", tokenAddr);
        
        // 获取代币信息
        (
            string memory symbol,
            uint256 totalSupply,
            uint256 perMint,
            uint256 price,
            address creator,
            uint256 currentSupply,
            bool canMint,
            bool liquidityAdded
        ) = factory.getTokenInfo(tokenAddr);
        
        console.log("Symbol:", symbol);
        console.log("Total Supply:", totalSupply);
        console.log("Per Mint:", perMint);
        console.log("Price:", price, "wei");
        console.log("Creator:", creator);
        console.log("Current Supply:", currentSupply);
        console.log("Can Mint:", canMint);
        console.log("Liquidity Added:", liquidityAdded);
        
        // 计算铸造成本
        (uint256 totalCost, uint256 platformFee, uint256 creatorFee) = factory.calculateMintCost(tokenAddr);
        console.log("\n=== Mint Cost Calculation ===");
        console.log("Total Cost:", totalCost, "wei");
        console.log("Platform Fee (5%):", platformFee, "wei");
        console.log("Creator Fee (95%):", creatorFee, "wei");
        
        console.log("\n=== Factory Statistics ===");
        console.log("Total Tokens Count:", factory.getAllTokensCount());
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Test Complete ===");
        console.log("All contracts deployed and configured successfully!");
    }
}